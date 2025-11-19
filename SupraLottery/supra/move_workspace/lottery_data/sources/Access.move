module lottery_data::access {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;

    public struct LegacyPayoutBatchCap has drop, store {
        holder: address,
        max_batch_size: u64,
        operations_budget_total: u64,
        operations_budget_used: u64,
        cooldown_secs: u64,
        last_batch_at: u64,
        last_nonce: u64,
        nonce_stride: u64,
    }

    public struct LegacyPartnerPayoutCap has drop, store {
        partner: address,
        max_total_payout: u64,
        remaining_payout: u64,
        payout_cooldown_secs: u64,
        last_payout_at: u64,
        next_nonce: u64,
        nonce_stride: u64,
        expires_at: u64,
    }

    public struct LegacyPremiumAccessCap has drop, store {
        holder: address,
        expires_at: u64,
        auto_renew: bool,
        referrer: option::Option<address>,
    }

    public struct LegacyRoleStore has drop, store {
        admin: address,
        payout_batch: option::Option<LegacyPayoutBatchCap>,
        partner_caps: vector<LegacyPartnerPayoutCap>,
        premium_caps: vector<LegacyPremiumAccessCap>,
    }

    struct PayoutBatchCap has copy, drop, store {
        holder: address,
        max_batch_size: u64,
        operations_budget_total: u64,
        operations_budget_used: u64,
        cooldown_secs: u64,
        last_batch_at: u64,
        last_nonce: u64,
        nonce_stride: u64,
    }

    struct PartnerPayoutCap has copy, drop, store {
        partner: address,
        max_total_payout: u64,
        remaining_payout: u64,
        payout_cooldown_secs: u64,
        last_payout_at: u64,
        next_nonce: u64,
        nonce_stride: u64,
        expires_at: u64,
    }

    struct PremiumAccessCap has copy, drop, store {
        holder: address,
        expires_at: u64,
        auto_renew: bool,
        referrer: option::Option<address>,
    }

    struct PartnerCapInfo has copy, drop, store {
        partner: address,
        max_total_payout: u64,
        remaining_payout: u64,
        payout_cooldown_secs: u64,
        last_payout_at: u64,
        next_nonce: u64,
        nonce_stride: u64,
        expires_at: u64,
    }

    struct PremiumCapInfo has copy, drop, store {
        holder: address,
        expires_at: u64,
        auto_renew: bool,
        referrer: option::Option<address>,
    }

    #[event]
    struct PayoutBatchCapUpdatedEvent has drop, store, copy {
        previous: option::Option<PayoutBatchCap>,
        current: option::Option<PayoutBatchCap>,
    }

    #[event]
    struct PartnerPayoutCapUpdatedEvent has drop, store, copy {
        previous: option::Option<PartnerCapInfo>,
        current: option::Option<PartnerCapInfo>,
    }

    #[event]
    struct PremiumAccessUpdatedEvent has drop, store, copy {
        previous: option::Option<PremiumCapInfo>,
        current: option::Option<PremiumCapInfo>,
    }

    struct RoleSnapshot has copy, drop, store {
        admin: address,
        payout_batch: option::Option<PayoutBatchCap>,
        partner_caps: vector<PartnerCapInfo>,
        premium_caps: vector<PremiumCapInfo>,
    }

    #[event]
    struct RoleSnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<RoleSnapshot>,
        current: RoleSnapshot,
    }

    struct RoleStore has key {
        admin: address,
        payout_batch: option::Option<PayoutBatchCap>,
        partner_caps: table::Table<address, PartnerPayoutCap>,
        partner_index: vector<address>,
        premium_caps: table::Table<address, PremiumAccessCap>,
        premium_index: vector<address>,
        payout_events: event::EventHandle<PayoutBatchCapUpdatedEvent>,
        partner_events: event::EventHandle<PartnerPayoutCapUpdatedEvent>,
        premium_events: event::EventHandle<PremiumAccessUpdatedEvent>,
        snapshot_events: event::EventHandle<RoleSnapshotUpdatedEvent>,
    }

    public entry fun init_store(caller: &signer) {
        let addr = signer::address_of(caller);
        assert!(addr == @lottery, E_NOT_AUTHORIZED);
        assert!(!exists<RoleStore>(@lottery), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            RoleStore {
                admin: addr,
                payout_batch: option::none<PayoutBatchCap>(),
                partner_caps: table::new<address, PartnerPayoutCap>(),
                partner_index: vector::empty<address>(),
                premium_caps: table::new<address, PremiumAccessCap>(),
                premium_index: vector::empty<address>(),
                payout_events: account::new_event_handle<PayoutBatchCapUpdatedEvent>(caller),
                partner_events: account::new_event_handle<PartnerPayoutCapUpdatedEvent>(caller),
                premium_events: account::new_event_handle<PremiumAccessUpdatedEvent>(caller),
                snapshot_events: account::new_event_handle<RoleSnapshotUpdatedEvent>(caller),
            },
        );
        emit_snapshot(option::none<RoleSnapshot>());
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        store.admin = new_admin;
        emit_snapshot(previous);
    }

    public entry fun import_payout_batch_cap(caller: &signer, cap: LegacyPayoutBatchCap)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        let legacy_copy = cap;
        let new_cap = PayoutBatchCap {
            holder: legacy_copy.holder,
            max_batch_size: legacy_copy.max_batch_size,
            operations_budget_total: legacy_copy.operations_budget_total,
            operations_budget_used: legacy_copy.operations_budget_used,
            cooldown_secs: legacy_copy.cooldown_secs,
            last_batch_at: legacy_copy.last_batch_at,
            last_nonce: legacy_copy.last_nonce,
            nonce_stride: legacy_copy.nonce_stride,
        };
        apply_payout_cap(store, option::some(new_cap));
        emit_snapshot(previous);
    }

    public entry fun clear_payout_batch_cap(caller: &signer) acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        apply_payout_cap(store, option::none<PayoutBatchCap>());
        emit_snapshot(previous);
    }

    public entry fun import_partner_cap(caller: &signer, cap: LegacyPartnerPayoutCap)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        upsert_partner_cap(store, cap);
        emit_snapshot(previous);
    }

    public entry fun import_partner_caps(caller: &signer, caps: vector<LegacyPartnerPayoutCap>)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        import_partner_caps_by_value(store, caps);
        emit_snapshot(previous);
    }

    public entry fun remove_partner_cap(caller: &signer, partner: address) acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        remove_partner_cap_internal(store, partner);
        emit_snapshot(previous);
    }

    public entry fun import_premium_cap(caller: &signer, cap: LegacyPremiumAccessCap)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        upsert_premium_cap(store, cap);
        emit_snapshot(previous);
    }

    public entry fun import_premium_caps(caller: &signer, caps: vector<LegacyPremiumAccessCap>)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        import_premium_caps_by_value(store, caps);
        emit_snapshot(previous);
    }

    public entry fun remove_premium_cap(caller: &signer, holder: address) acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        remove_premium_cap_internal(store, holder);
        emit_snapshot(previous);
    }

    public entry fun import_existing_role_store(caller: &signer, state: LegacyRoleStore)
    acquires RoleStore {
        ensure_admin(caller);
        let store = borrow_global_mut<RoleStore>(@lottery);
        let previous = option::some(build_snapshot_from_mut(store));
        apply_legacy_role_store(store, state);
        emit_snapshot(previous);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<RoleStore>(@lottery)
    }

    #[view]
    public fun admin(): option::Option<address> {
        if (!exists<RoleStore>(@lottery)) {
            option::none<address>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            option::some(store.admin)
        }
    }

    #[view]
    public fun payout_batch_cap(): option::Option<PayoutBatchCap> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            option::none<PayoutBatchCap>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            if (option::is_some(&store.payout_batch)) {
                let cloned = clone_option(store.payout_batch);
                option::some(option::destroy_some(cloned))
            } else {
                option::none<PayoutBatchCap>()
            }
        }
    }

    #[view]
    public fun partner_cap(partner: address): option::Option<PartnerCapInfo> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            option::none<PartnerCapInfo>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            if (!table::contains(&store.partner_caps, partner)) {
                option::none<PartnerCapInfo>()
            } else {
                let cap_ref = table::borrow(&store.partner_caps, partner);
                option::some(to_partner_info(cap_ref))
            }
        }
    }

    #[view]
    public fun premium_cap(holder: address): option::Option<PremiumCapInfo> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            option::none<PremiumCapInfo>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            if (!table::contains(&store.premium_caps, holder)) {
                option::none<PremiumCapInfo>()
            } else {
                let cap_ref = table::borrow(&store.premium_caps, holder);
                option::some(to_premium_info(cap_ref))
            }
        }
    }

    #[view]
    public fun partner_caps(): vector<PartnerCapInfo> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            vector::empty<PartnerCapInfo>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            clone_partner_caps(&store.partner_caps, &store.partner_index)
        }
    }

    #[view]
    public fun premium_caps(): vector<PremiumCapInfo> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            vector::empty<PremiumCapInfo>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            clone_premium_caps(&store.premium_caps, &store.premium_index)
        }
    }

    #[view]
    public fun snapshot(): option::Option<RoleSnapshot> acquires RoleStore {
        if (!exists<RoleStore>(@lottery)) {
            option::none<RoleSnapshot>()
        } else {
            let store = borrow_global<RoleStore>(@lottery);
            option::some(build_snapshot(store))
        }
    }

    fun ensure_admin(caller: &signer) acquires RoleStore {
        let addr = signer::address_of(caller);
        assert!(exists<RoleStore>(@lottery), E_NOT_AUTHORIZED);
        let store = borrow_global<RoleStore>(@lottery);
        assert!(store.admin == addr, E_NOT_AUTHORIZED);
    }

    fun apply_payout_cap(store: &mut RoleStore, cap: option::Option<PayoutBatchCap>) {
        let previous = clone_option(store.payout_batch);
        store.payout_batch = cap;
        event::emit_event(
            &mut store.payout_events,
            PayoutBatchCapUpdatedEvent { previous, current: clone_option(store.payout_batch) },
        );
    }

    fun upsert_partner_cap(store: &mut RoleStore, cap: LegacyPartnerPayoutCap) {
        let existing = if (table::contains(&store.partner_caps, cap.partner)) {
            let existing_ref = table::borrow(&store.partner_caps, cap.partner);
            option::some(to_partner_info(existing_ref))
        } else {
            option::none<PartnerCapInfo>()
        };
        let record = PartnerPayoutCap {
            partner: cap.partner,
            max_total_payout: cap.max_total_payout,
            remaining_payout: cap.remaining_payout,
            payout_cooldown_secs: cap.payout_cooldown_secs,
            last_payout_at: cap.last_payout_at,
            next_nonce: cap.next_nonce,
            nonce_stride: cap.nonce_stride,
            expires_at: cap.expires_at,
        };
        if (!table::contains(&store.partner_caps, cap.partner)) {
            push_unique_address(&mut store.partner_index, cap.partner);
        } else {
            let _ = table::remove(&mut store.partner_caps, cap.partner);
        };
        table::add(&mut store.partner_caps, cap.partner, record);
        let current_ref = table::borrow(&store.partner_caps, cap.partner);
        let current = option::some(to_partner_info(current_ref));
        event::emit_event(
            &mut store.partner_events,
            PartnerPayoutCapUpdatedEvent { previous: existing, current },
        );
    }

    fun import_partner_caps_by_value(store: &mut RoleStore, caps: vector<LegacyPartnerPayoutCap>) {
        if (vector::is_empty(&caps)) {
            return;
        };
        let cap = vector::pop_back(caps);
        upsert_partner_cap(store, cap);
        import_partner_caps_by_value(store, caps);
    }

    fun remove_partner_cap_internal(store: &mut RoleStore, partner: address) {
        if (!table::contains(&store.partner_caps, partner)) {
            return;
        };
        let existing_ref = table::borrow(&store.partner_caps, partner);
        let previous = option::some(to_partner_info(existing_ref));
        let _ = table::remove(&mut store.partner_caps, partner);
        remove_address(&mut store.partner_index, partner, 0);
        event::emit_event(
            &mut store.partner_events,
            PartnerPayoutCapUpdatedEvent { previous, current: option::none<PartnerCapInfo>() },
        );
    }

    fun upsert_premium_cap(store: &mut RoleStore, cap: LegacyPremiumAccessCap) {
        let existing = if (table::contains(&store.premium_caps, cap.holder)) {
            let existing_ref = table::borrow(&store.premium_caps, cap.holder);
            option::some(to_premium_info(existing_ref))
        } else {
            option::none<PremiumCapInfo>()
        };
        let record = PremiumAccessCap {
            holder: cap.holder,
            expires_at: cap.expires_at,
            auto_renew: cap.auto_renew,
            referrer: cap.referrer,
        };
        if (!table::contains(&store.premium_caps, cap.holder)) {
            push_unique_address(&mut store.premium_index, cap.holder);
        } else {
            let _ = table::remove(&mut store.premium_caps, cap.holder);
        };
        table::add(&mut store.premium_caps, cap.holder, record);
        let current_ref = table::borrow(&store.premium_caps, cap.holder);
        let current = option::some(to_premium_info(current_ref));
        event::emit_event(
            &mut store.premium_events,
            PremiumAccessUpdatedEvent { previous: existing, current },
        );
    }

    fun import_premium_caps_by_value(store: &mut RoleStore, caps: vector<LegacyPremiumAccessCap>) {
        if (vector::is_empty(&caps)) {
            return;
        };
        let cap = vector::pop_back(caps);
        upsert_premium_cap(store, cap);
        import_premium_caps_by_value(store, caps);
    }

    fun remove_premium_cap_internal(store: &mut RoleStore, holder: address) {
        if (!table::contains(&store.premium_caps, holder)) {
            return;
        };
        let existing_ref = table::borrow(&store.premium_caps, holder);
        let previous = option::some(to_premium_info(existing_ref));
        let _ = table::remove(&mut store.premium_caps, holder);
        remove_address(&mut store.premium_index, holder, 0);
        event::emit_event(
            &mut store.premium_events,
            PremiumAccessUpdatedEvent { previous, current: option::none<PremiumCapInfo>() },
        );
    }

    fun apply_legacy_role_store(store: &mut RoleStore, state: LegacyRoleStore) {
        let LegacyRoleStore {
            admin,
            payout_batch,
            partner_caps,
            premium_caps,
        } = state;
        store.admin = admin;
        apply_payout_cap_from_legacy(store, payout_batch);
        clear_partner_caps(store);
        import_partner_caps_by_value(store, partner_caps);
        clear_premium_caps(store);
        import_premium_caps_by_value(store, premium_caps);
    }

    fun apply_payout_cap_from_legacy(store: &mut RoleStore, cap: option::Option<LegacyPayoutBatchCap>) {
        if (option::is_some(&cap)) {
            let value = option::destroy_some(cap);
            import_payout_cap_from_value(store, value);
        } else {
            apply_payout_cap(store, option::none<PayoutBatchCap>());
        }
    }

    fun import_payout_cap_from_value(store: &mut RoleStore, cap: LegacyPayoutBatchCap) {
        let converted = PayoutBatchCap {
            holder: cap.holder,
            max_batch_size: cap.max_batch_size,
            operations_budget_total: cap.operations_budget_total,
            operations_budget_used: cap.operations_budget_used,
            cooldown_secs: cap.cooldown_secs,
            last_batch_at: cap.last_batch_at,
            last_nonce: cap.last_nonce,
            nonce_stride: cap.nonce_stride,
        };
        apply_payout_cap(store, option::some(converted));
    }

    fun clear_partner_caps(store: &mut RoleStore) {
        clear_partner_caps_recursive(&mut store.partner_index, &mut store.partner_caps);
    }

    fun clear_partner_caps_recursive(
        index: &mut vector<address>,
        caps: &mut table::Table<address, PartnerPayoutCap>,
    ) {
        if (vector::is_empty(index)) {
            return;
        };
        let partner = vector::pop_back(index);
        let _removed = table::remove(caps, partner);
        let _ = _removed;
        clear_partner_caps_recursive(index, caps);
    }

    fun clear_premium_caps(store: &mut RoleStore) {
        clear_premium_caps_recursive(&mut store.premium_index, &mut store.premium_caps);
    }

    fun clear_premium_caps_recursive(
        index: &mut vector<address>,
        caps: &mut table::Table<address, PremiumAccessCap>,
    ) {
        if (vector::is_empty(index)) {
            return;
        };
        let holder = vector::pop_back(index);
        let _removed = table::remove(caps, holder);
        let _ = _removed;
        clear_premium_caps_recursive(index, caps);
    }

    fun build_snapshot(store: &RoleStore): RoleSnapshot {
        RoleSnapshot {
            admin: store.admin,
            payout_batch: clone_option(store.payout_batch),
            partner_caps: clone_partner_caps(&store.partner_caps, &store.partner_index),
            premium_caps: clone_premium_caps(&store.premium_caps, &store.premium_index),
        }
    }

    fun build_snapshot_from_mut(store: &mut RoleStore): RoleSnapshot {
        build_snapshot(store)
    }

    fun emit_snapshot(previous: option::Option<RoleSnapshot>) acquires RoleStore {
        let store = borrow_global_mut<RoleStore>(@lottery);
        let current = build_snapshot_from_mut(store);
        event::emit_event(
            &mut store.snapshot_events,
            RoleSnapshotUpdatedEvent { previous, current },
        );
    }

    fun clone_option<T: copy + drop + store>(value: option::Option<T>): option::Option<T> {
        if (option::is_some(&value)) {
            let copy_value = option::destroy_some(value);
            option::some(copy_value)
        } else {
            option::none<T>()
        }
    }

    fun to_partner_info(cap: &PartnerPayoutCap): PartnerCapInfo {
        PartnerCapInfo {
            partner: cap.partner,
            max_total_payout: cap.max_total_payout,
            remaining_payout: cap.remaining_payout,
            payout_cooldown_secs: cap.payout_cooldown_secs,
            last_payout_at: cap.last_payout_at,
            next_nonce: cap.next_nonce,
            nonce_stride: cap.nonce_stride,
            expires_at: cap.expires_at,
        }
    }

    fun to_premium_info(cap: &PremiumAccessCap): PremiumCapInfo {
        PremiumCapInfo {
            holder: cap.holder,
            expires_at: cap.expires_at,
            auto_renew: cap.auto_renew,
            referrer: cap.referrer,
        }
    }

    fun clone_partner_caps(
        caps: &table::Table<address, PartnerPayoutCap>,
        index: &vector<address>,
    ): vector<PartnerCapInfo> {
        let result = vector::empty<PartnerCapInfo>();
        clone_partner_caps_recursive(caps, index, 0, &mut result);
        result
    }

    fun clone_partner_caps_recursive(
        caps: &table::Table<address, PartnerPayoutCap>,
        index: &vector<address>,
        position: u64,
        buffer: &mut vector<PartnerCapInfo>,
    ) {
        if (position >= vector::length(index)) {
            return;
        };
        let partner = *vector::borrow(index, position);
        if (table::contains(caps, partner)) {
            let cap_ref = table::borrow(caps, partner);
            vector::push_back(buffer, to_partner_info(cap_ref));
        };
        let next = position + 1;
        clone_partner_caps_recursive(caps, index, next, buffer);
    }

    fun clone_premium_caps(
        caps: &table::Table<address, PremiumAccessCap>,
        index: &vector<address>,
    ): vector<PremiumCapInfo> {
        let result = vector::empty<PremiumCapInfo>();
        clone_premium_caps_recursive(caps, index, 0, &mut result);
        result
    }

    fun clone_premium_caps_recursive(
        caps: &table::Table<address, PremiumAccessCap>,
        index: &vector<address>,
        position: u64,
        buffer: &mut vector<PremiumCapInfo>,
    ) {
        if (position >= vector::length(index)) {
            return;
        };
        let holder = *vector::borrow(index, position);
        if (table::contains(caps, holder)) {
            let cap_ref = table::borrow(caps, holder);
            vector::push_back(buffer, to_premium_info(cap_ref));
        };
        let next = position + 1;
        clone_premium_caps_recursive(caps, index, next, buffer);
    }

    fun push_unique_address(index: &mut vector<address>, addr: address) {
        if (contains_address(index, addr, 0)) {
            return;
        };
        vector::push_back(index, addr);
    }

    fun contains_address(index: &vector<address>, addr: address, position: u64): bool {
        if (position >= vector::length(index)) {
            false
        } else if (*vector::borrow(index, position) == addr) {
            true
        } else {
            let next = position + 1;
            contains_address(index, addr, next)
        }
    }

    fun remove_address(index: &mut vector<address>, addr: address, position: u64) {
        if (position >= vector::length(index)) {
            return;
        };
        if (*vector::borrow(index, position) == addr) {
            let _ = vector::remove(index, position);
            let _discard = _;
            return;
        };
        let next = position + 1;
        remove_address(index, addr, next);
    }

}
