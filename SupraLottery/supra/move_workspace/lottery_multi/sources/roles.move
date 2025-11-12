// sources/roles.move
module lottery_multi::roles {
    use std::event;
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;

    use lottery_multi::errors;
    use lottery_multi::tags;

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
        pub expires_at: u64,
    }

    pub struct PartnerCapInfo has copy, drop, store {
        pub partner: address,
        pub max_total_payout: u64,
        pub remaining_payout: u64,
        pub payout_cooldown_secs: u64,
        pub last_payout_at: u64,
        pub next_nonce: u64,
        pub nonce_stride: u64,
        pub expires_at: u64,
    }

    pub struct PremiumCapInfo has copy, drop, store {
        pub holder: address,
        pub expires_at: u64,
        pub auto_renew: bool,
        pub referrer: option::Option<address>,
    }

    struct RoleEvents has store {
        payout_granted: event::EventHandle<PayoutBatchCapGrantedEvent>,
        payout_revoked: event::EventHandle<PayoutBatchCapRevokedEvent>,
        partner_granted: event::EventHandle<PartnerPayoutCapGrantedEvent>,
        partner_revoked: event::EventHandle<PartnerPayoutCapRevokedEvent>,
        premium_granted: event::EventHandle<PremiumAccessGrantedEvent>,
        premium_revoked: event::EventHandle<PremiumAccessRevokedEvent>,
    }

    pub struct PayoutBatchCapGrantedEvent has copy, drop, store {
        pub holder: address,
        pub max_batch_size: u64,
        pub operations_budget_total: u64,
        pub cooldown_secs: u64,
        pub nonce_stride: u64,
    }

    pub struct PayoutBatchCapRevokedEvent has copy, drop, store {
        pub holder: address,
    }

    pub struct PartnerPayoutCapGrantedEvent has copy, drop, store {
        pub partner: address,
        pub max_total_payout: u64,
        pub payout_cooldown_secs: u64,
        pub nonce_stride: u64,
        pub expires_at: u64,
    }

    pub struct PartnerPayoutCapRevokedEvent has copy, drop, store {
        pub partner: address,
    }

    pub struct PremiumAccessGrantedEvent has copy, drop, store {
        pub holder: address,
        pub expires_at: u64,
        pub auto_renew: bool,
    }

    pub struct PremiumAccessRevokedEvent has copy, drop, store {
        pub holder: address,
    }

    struct RoleStore has key {
        payout_batch: option::Option<PayoutBatchCap>,
        partner_caps: table::Table<address, PartnerPayoutCap>,
        partner_index: vector<address>,
        premium_caps: table::Table<address, PremiumAccessCap>,
        premium_index: vector<address>,
        events: RoleEvents,
    }

    public entry fun init_roles(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        assert!(!exists<RoleStore>(addr), errors::E_ALREADY_INITIALIZED);
        let store = RoleStore {
            payout_batch: option::none<PayoutBatchCap>(),
            partner_caps: table::new(),
            partner_index: vector::empty<address>(),
            premium_caps: table::new(),
            premium_index: vector::empty<address>(),
            events: RoleEvents {
                payout_granted: event::new_event_handle<PayoutBatchCapGrantedEvent>(admin),
                payout_revoked: event::new_event_handle<PayoutBatchCapRevokedEvent>(admin),
                partner_granted: event::new_event_handle<PartnerPayoutCapGrantedEvent>(admin),
                partner_revoked: event::new_event_handle<PartnerPayoutCapRevokedEvent>(admin),
                premium_granted: event::new_event_handle<PremiumAccessGrantedEvent>(admin),
                premium_revoked: event::new_event_handle<PremiumAccessRevokedEvent>(admin),
            },
        };
        move_to(admin, store);
    }

    public entry fun set_payout_batch_cap_admin(admin: &signer, cap: PayoutBatchCap) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        if (option::is_some(&store.payout_batch)) {
            let existing = option::extract(&mut store.payout_batch);
            let holder = existing.holder;
            event::emit(
                &mut store.events.payout_revoked,
                PayoutBatchCapRevokedEvent { holder },
            );
        };
        store.payout_batch = option::some(cap);
        let holder = cap.holder;
        let max_batch_size = cap.max_batch_size;
        let operations_budget_total = cap.operations_budget_total;
        let cooldown_secs = cap.cooldown_secs;
        let nonce_stride = cap.nonce_stride;
        event::emit(
            &mut store.events.payout_granted,
            PayoutBatchCapGrantedEvent {
                holder,
                max_batch_size,
                operations_budget_total,
                cooldown_secs,
                nonce_stride,
            },
        );
    }

    public entry fun revoke_payout_batch_cap_admin(admin: &signer) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        if (!option::is_some(&store.payout_batch)) {
            abort errors::E_PAYOUT_BATCH_CAP_MISSING;
        };
        let existing = option::extract(&mut store.payout_batch);
        let holder = existing.holder;
        event::emit(
            &mut store.events.payout_revoked,
            PayoutBatchCapRevokedEvent { holder },
        );
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
            event::emit(
                &mut store.events.partner_revoked,
                PartnerPayoutCapRevokedEvent { partner },
            );
        } else {
            vector::push_back(&mut store.partner_index, partner);
        };
        table::add(&mut store.partner_caps, partner, cap);
        let payout_cooldown_secs = cap.payout_cooldown_secs;
        let max_total_payout = cap.max_total_payout;
        let nonce_stride = cap.nonce_stride;
        let expires_at = cap.expires_at;
        event::emit(
            &mut store.events.partner_granted,
            PartnerPayoutCapGrantedEvent {
                partner,
                max_total_payout,
                payout_cooldown_secs,
                nonce_stride,
                expires_at,
            },
        );
    }

    public entry fun revoke_partner_payout_cap_admin(admin: &signer, partner: address) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        if (!table::contains(&store.partner_caps, partner)) {
            abort errors::E_PARTNER_PAYOUT_CAP_MISSING;
        };
        let _ = table::remove(&mut store.partner_caps, partner);
        remove_from_index(&mut store.partner_index, partner);
        event::emit(
            &mut store.events.partner_revoked,
            PartnerPayoutCapRevokedEvent { partner },
        );
    }

    public fun borrow_payout_batch_cap_mut(): &mut PayoutBatchCap acquires RoleStore {
        let store = borrow_store_mut();
        if (!option::is_some(&store.payout_batch)) {
            abort errors::E_PAYOUT_BATCH_CAP_MISSING;
        };
        option::borrow_mut(&mut store.payout_batch)
    }

    public fun borrow_payout_batch_cap(): &PayoutBatchCap acquires RoleStore {
        let store = borrow_store();
        if (!option::is_some(&store.payout_batch)) {
            abort errors::E_PAYOUT_BATCH_CAP_MISSING;
        };
        option::borrow(&store.payout_batch)
    }

    public fun borrow_partner_payout_cap_mut(partner: address): &mut PartnerPayoutCap acquires RoleStore {
        let store = borrow_store_mut();
        if (!table::contains(&store.partner_caps, partner)) {
            abort errors::E_PARTNER_PAYOUT_CAP_MISSING;
        };
        table::borrow_mut(&mut store.partner_caps, partner)
    }

    public fun borrow_partner_payout_cap(partner: address): &PartnerPayoutCap acquires RoleStore {
        let store = borrow_store();
        if (!table::contains(&store.partner_caps, partner)) {
            abort errors::E_PARTNER_PAYOUT_CAP_MISSING;
        };
        table::borrow(&store.partner_caps, partner)
    }

    public fun borrow_premium_cap(holder: address): &PremiumAccessCap acquires RoleStore {
        let store = borrow_store();
        if (!table::contains(&store.premium_caps, holder)) {
            abort errors::E_PREMIUM_CAP_MISSING;
        };
        table::borrow(&store.premium_caps, holder)
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
        tags::validate(tags::TYPE_PARTNER, allowed_tags_mask);
        tags::assert_tag_budget(allowed_tags_mask);
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

    public entry fun grant_premium_access_admin(admin: &signer, cap: PremiumAccessCap) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let holder = cap.holder;
        let store = borrow_store_mut();
        if (table::contains(&store.premium_caps, holder)) {
            let _ = table::remove(&mut store.premium_caps, holder);
            event::emit(
                &mut store.events.premium_revoked,
                PremiumAccessRevokedEvent { holder },
            );
        } else {
            vector::push_back(&mut store.premium_index, holder);
        };
        let expires_at = cap.expires_at;
        let auto_renew = cap.auto_renew;
        table::add(&mut store.premium_caps, holder, cap);
        event::emit(
            &mut store.events.premium_granted,
            PremiumAccessGrantedEvent {
                holder,
                expires_at,
                auto_renew,
            },
        );
    }

    public entry fun revoke_premium_access_admin(admin: &signer, holder: address) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        if (!table::contains(&store.premium_caps, holder)) {
            abort errors::E_PREMIUM_CAP_MISSING;
        };
        let _ = table::remove(&mut store.premium_caps, holder);
        remove_from_index(&mut store.premium_index, holder);
        event::emit(
            &mut store.events.premium_revoked,
            PremiumAccessRevokedEvent { holder },
        );
    }

    public entry fun cleanup_expired_admin(admin: &signer, now_sec: u64) acquires RoleStore {
        assert!(signer::address_of(admin) == ADMIN_ADDR, errors::E_REGISTRY_MISSING);
        let store = borrow_store_mut();
        cleanup_partner_caps(store, now_sec);
        cleanup_premium_caps(store, now_sec);
    }

    public fun has_payout_batch_cap(): bool acquires RoleStore {
        let store = borrow_store();
        option::is_some(&store.payout_batch)
    }

    public fun has_partner_payout_cap(partner: address): bool acquires RoleStore {
        let store = borrow_store();
        table::contains(&store.partner_caps, partner)
    }

    public fun has_premium_cap(holder: address): bool acquires RoleStore {
        let store = borrow_store();
        table::contains(&store.premium_caps, holder)
    }

    public fun list_partner_caps(): vector<PartnerCapInfo> acquires RoleStore {
        let store = borrow_store();
        let mut out = vector::empty<PartnerCapInfo>();
        let mut i = 0;
        let len = vector::length(&store.partner_index);
        while (i < len) {
            let partner = *vector::borrow(&store.partner_index, i);
            if (!table::contains(&store.partner_caps, partner)) {
                i = i + 1;
                continue;
            };
            let cap_ref = table::borrow(&store.partner_caps, partner);
            vector::push_back(
                &mut out,
                PartnerCapInfo {
                    partner,
                    max_total_payout: cap_ref.max_total_payout,
                    remaining_payout: cap_ref.remaining_payout,
                    payout_cooldown_secs: cap_ref.payout_cooldown_secs,
                    last_payout_at: cap_ref.last_payout_at,
                    next_nonce: cap_ref.next_nonce,
                    nonce_stride: cap_ref.nonce_stride,
                    expires_at: cap_ref.expires_at,
                },
            );
            i = i + 1;
        };
        out
    }

    public fun list_premium_caps(): vector<PremiumCapInfo> acquires RoleStore {
        let store = borrow_store();
        let mut out = vector::empty<PremiumCapInfo>();
        let mut i = 0;
        let len = vector::length(&store.premium_index);
        while (i < len) {
            let holder = *vector::borrow(&store.premium_index, i);
            if (!table::contains(&store.premium_caps, holder)) {
                i = i + 1;
                continue;
            };
            let cap_ref = table::borrow(&store.premium_caps, holder);
            let referrer = if (option::is_some(&cap_ref.referrer)) {
                option::some(*option::borrow(&cap_ref.referrer))
            } else {
                option::none<address>()
            };
            vector::push_back(
                &mut out,
                PremiumCapInfo {
                    holder,
                    expires_at: cap_ref.expires_at,
                    auto_renew: cap_ref.auto_renew,
                    referrer,
                },
            );
            i = i + 1;
        };
        out
    }

    #[test_only]
    public fun event_counters(): (u64, u64, u64, u64, u64, u64) acquires RoleStore {
        let store = borrow_store();
        (
            event::counter(&store.events.payout_granted),
            event::counter(&store.events.payout_revoked),
            event::counter(&store.events.partner_granted),
            event::counter(&store.events.partner_revoked),
            event::counter(&store.events.premium_granted),
            event::counter(&store.events.premium_revoked),
        )
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
        expires_at: u64,
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
            expires_at,
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
        cap.expires_at == 0 || cap.expires_at >= now_sec
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
        if (cap.expires_at > 0) {
            assert!(timestamp <= cap.expires_at, errors::E_PARTNER_PAYOUT_EXPIRED);
        };
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

    fun borrow_store(): &RoleStore acquires RoleStore {
        if (!exists<RoleStore>(ADMIN_ADDR)) {
            abort errors::E_ROLES_NOT_INITIALIZED;
        };
        borrow_global<RoleStore>(ADMIN_ADDR)
    }

    fun borrow_store_mut(): &mut RoleStore acquires RoleStore {
        if (!exists<RoleStore>(ADMIN_ADDR)) {
            abort errors::E_ROLES_NOT_INITIALIZED;
        };
        borrow_global_mut<RoleStore>(ADMIN_ADDR)
    }

    fun cleanup_partner_caps(store: &mut RoleStore, now_sec: u64) {
        let mut i = 0;
        while (i < vector::length(&store.partner_index)) {
            let partner = *vector::borrow(&store.partner_index, i);
            if (!table::contains(&store.partner_caps, partner)) {
                vector::swap_remove(&mut store.partner_index, i);
                continue;
            };
            let expired = {
                let cap_ref = table::borrow(&store.partner_caps, partner);
                let expires_at = cap_ref.expires_at;
                let remaining = cap_ref.remaining_payout;
                (expires_at > 0 && now_sec > expires_at) || remaining == 0
            };
            if (expired) {
                let _ = table::remove(&mut store.partner_caps, partner);
                vector::swap_remove(&mut store.partner_index, i);
                event::emit(
                    &mut store.events.partner_revoked,
                    PartnerPayoutCapRevokedEvent { partner },
                );
            } else {
                i = i + 1;
            };
        };
    }

    fun cleanup_premium_caps(store: &mut RoleStore, now_sec: u64) {
        let mut i = 0;
        while (i < vector::length(&store.premium_index)) {
            let holder = *vector::borrow(&store.premium_index, i);
            if (!table::contains(&store.premium_caps, holder)) {
                vector::swap_remove(&mut store.premium_index, i);
                continue;
            };
            let expired = {
                let cap_ref = table::borrow(&store.premium_caps, holder);
                let expires_at = cap_ref.expires_at;
                expires_at > 0 && now_sec > expires_at
            };
            if (expired) {
                let _ = table::remove(&mut store.premium_caps, holder);
                vector::swap_remove(&mut store.premium_index, i);
                event::emit(
                    &mut store.events.premium_revoked,
                    PremiumAccessRevokedEvent { holder },
                );
            } else {
                i = i + 1;
            };
        };
    }

    fun remove_from_index(index: &mut vector<address>, target: address) {
        let mut i = 0;
        while (i < vector::length(index)) {
            if (*vector::borrow(index, i) == target) {
                vector::swap_remove(index, i);
                return;
            };
            i = i + 1;
        };
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

