// sources/roles.move
module lottery_multi::roles {
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;

    use lottery_multi::errors;

    const ADMIN_ADDR: address = @lottery_multi;

    pub struct PartnerCreateCap has store {
        pub allowed_event_slug: vector<u8>,
        pub allowed_series_codes: vector<vector<u8>>,
        pub allowed_primary_types: vector<u8>,
        pub allowed_tags_mask: u64,
        pub max_parallel: u64,
        pub expires_at: u64,
        pub payout_cooldown_secs: u64,
    }

    pub struct PremiumAccessCap has store {
        pub holder: address,
        pub expires_at: u64,
        pub auto_renew: bool,
        pub referrer: option::Option<address>,
    }

    pub struct PayoutBatchCap has store, drop {
        pub holder: address,
        pub max_batch_size: u64,
        pub operations_budget_total: u64,
        pub operations_budget_used: u64,
        pub cooldown_secs: u64,
        pub last_batch_at: u64,
        pub last_nonce: u64,
        pub nonce_stride: u64,
    }

    pub struct PartnerPayoutCap has store, drop {
        pub partner: address,
        pub max_total_payout: u64,
        pub remaining_payout: u64,
        pub payout_cooldown_secs: u64,
        pub last_payout_at: u64,
        pub next_nonce: u64,
        pub nonce_stride: u64,
    }

    struct RoleStore has key {
        payout_batch: option::Option<PayoutBatchCap>,
        partner_caps: table::Table<address, PartnerPayoutCap>,
    }

    public entry fun init_roles(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        assert!(!exists<RoleStore>(addr), errors::E_ALREADY_INITIALIZED);
        let store = RoleStore {
            payout_batch: option::none<PayoutBatchCap>(),
            partner_caps: table::new(),
        };
        move_to(admin, store);
    }

    public entry fun set_payout_batch_cap_admin(admin: &signer, cap: PayoutBatchCap) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        if (option::is_some(&store.payout_batch)) {
            let _ = option::extract(&mut store.payout_batch);
        };
        store.payout_batch = option::some(cap);
    }

    public entry fun upsert_partner_payout_cap_admin(
        admin: &signer,
        partner: address,
        cap: PartnerPayoutCap,
    ) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        assert!(cap.partner == partner, errors::E_PARTNER_PAYOUT_HOLDER_MISMATCH);
        let store = borrow_store_mut();
        if (table::contains(&store.partner_caps, partner)) {
            let _ = table::remove(&mut store.partner_caps, partner);
        };
        table::add(&mut store.partner_caps, partner, cap);
    }

    public fun borrow_payout_batch_cap_mut(): &mut PayoutBatchCap acquires RoleStore {
        let store = borrow_store_mut();
        if (!option::is_some(&store.payout_batch)) {
            abort errors::E_PAYOUT_BATCH_CAP_MISSING;
        };
        option::borrow_mut(&mut store.payout_batch)
    }

    public fun borrow_partner_payout_cap_mut(partner: address): &mut PartnerPayoutCap acquires RoleStore {
        let store = borrow_store_mut();
        if (!table::contains(&store.partner_caps, partner)) {
            abort errors::E_PARTNER_PAYOUT_CAP_MISSING;
        };
        table::borrow_mut(&mut store.partner_caps, partner)
    }

    public fun new_partner_cap(
        allowed_event_slug: vector<u8>,
        allowed_series_codes: vector<vector<u8>>,
        allowed_primary_types: vector<u8>,
        allowed_tags_mask: u64,
        max_parallel: u64,
        expires_at: u64,
        payout_cooldown_secs: u64,
    ): PartnerCreateCap {
        PartnerCreateCap {
            allowed_event_slug,
            allowed_series_codes,
            allowed_primary_types,
            allowed_tags_mask,
            max_parallel,
            expires_at,
            payout_cooldown_secs,
        }
    }

    public fun new_premium_cap(
        holder: address,
        expires_at: u64,
        auto_renew: bool,
        referrer: option::Option<address>,
    ): PremiumAccessCap {
        PremiumAccessCap {
            holder,
            expires_at,
            auto_renew,
            referrer,
        }
    }

    public fun new_payout_batch_cap(
        holder: address,
        max_batch_size: u64,
        operations_budget_total: u64,
        cooldown_secs: u64,
        nonce_stride: u64,
    ): PayoutBatchCap {
        assert!(nonce_stride > 0, errors::E_PAYOUT_BATCH_NONCE);
        PayoutBatchCap {
            holder,
            max_batch_size,
            operations_budget_total,
            operations_budget_used: 0,
            cooldown_secs,
            last_batch_at: 0,
            last_nonce: 0,
            nonce_stride,
        }
    }

    public fun new_partner_payout_cap(
        partner: address,
        max_total_payout: u64,
        payout_cooldown_secs: u64,
        nonce_stride: u64,
    ): PartnerPayoutCap {
        assert!(nonce_stride > 0, errors::E_PARTNER_PAYOUT_NONCE);
        PartnerPayoutCap {
            partner,
            max_total_payout,
            remaining_payout: max_total_payout,
            payout_cooldown_secs,
            last_payout_at: 0,
            next_nonce: nonce_stride,
            nonce_stride,
        }
    }

    public fun ensure_primary_type_allowed(cap: &PartnerCreateCap, primary_type: u8) {
        let allowed = contains_u8(&cap.allowed_primary_types, primary_type);
        assert!(allowed, errors::E_PRIMARY_TYPE_NOT_ALLOWED);
    }

    public fun ensure_tags_allowed(cap: &PartnerCreateCap, tags_mask: u64) {
        let masked = tags_mask & cap.allowed_tags_mask;
        assert!(masked == tags_mask, errors::E_TAG_MASK_NOT_ALLOWED);
    }

    public fun is_premium_active(cap: &PremiumAccessCap, now_sec: u64): bool {
        cap.expires_at >= now_sec
    }

    public fun consume_payout_batch(
        cap: &mut PayoutBatchCap,
        winners_paid: u64,
        operations_paid: u64,
        timestamp: u64,
        nonce: u64,
    ) {
        assert!(cap.max_batch_size == 0 || winners_paid <= cap.max_batch_size, errors::E_PAYOUT_BATCH_TOO_LARGE);
        if (cap.cooldown_secs > 0 && cap.last_batch_at > 0) {
            let min_allowed = cap.last_batch_at + cap.cooldown_secs;
            assert!(timestamp >= min_allowed, errors::E_PAYOUT_BATCH_COOLDOWN);
        };
        if (cap.nonce_stride > 0) {
            let expected = cap.last_nonce + cap.nonce_stride;
            assert!(nonce == expected, errors::E_PAYOUT_BATCH_NONCE);
            cap.last_nonce = nonce;
        } else {
            cap.last_nonce = nonce;
        };
        let used = cap.operations_budget_used + operations_paid;
        assert!(used <= cap.operations_budget_total, errors::E_PAYOUT_OPERATIONS_BUDGET);
        cap.operations_budget_used = used;
        cap.last_batch_at = timestamp;
    }

    public fun consume_partner_payout(
        cap: &mut PartnerPayoutCap,
        amount: u64,
        timestamp: u64,
        nonce: u64,
    ) {
        assert!(amount <= cap.remaining_payout, errors::E_PARTNER_PAYOUT_BUDGET_EXCEEDED);
        if (cap.payout_cooldown_secs > 0 && cap.last_payout_at > 0) {
            let min_allowed = cap.last_payout_at + cap.payout_cooldown_secs;
            assert!(timestamp >= min_allowed, errors::E_PARTNER_PAYOUT_COOLDOWN);
        };
        let expected = cap.next_nonce;
        assert!(nonce == expected, errors::E_PARTNER_PAYOUT_NONCE);
        cap.remaining_payout = cap.remaining_payout - amount;
        cap.last_payout_at = timestamp;
        cap.next_nonce = cap.next_nonce + cap.nonce_stride;
    }

    fun borrow_store_mut(): &mut RoleStore acquires RoleStore {
        if (!exists<RoleStore>(ADMIN_ADDR)) {
            abort errors::E_ROLES_NOT_INITIALIZED;
        };
        borrow_global_mut<RoleStore>(ADMIN_ADDR)
    }

    fun contains_u8(items: &vector<u8>, value: u8): bool {
        let len = vector::length(items);
        let mut i = 0;
        while (i < len) {
            let current = *vector::borrow(items, i);
            if (current == value) {
                return true;
            };
            i = i + 1;
        };
        false
    }
}

