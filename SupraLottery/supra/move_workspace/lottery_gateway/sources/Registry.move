module lottery_gateway::registry {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_ENTRY_EXISTS: u64 = 3;
    const E_ENTRY_MISSING: u64 = 4;
    const E_NOT_INITIALIZED: u64 = 5;

    struct LotteryCancellationSummary has copy, drop, store {
        reason_code: u8,
        canceled_ts: u64,
    }

    struct LegacyCancellationImport has copy, drop, store {
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
    }

    struct LotteryRegistryEntry has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        active: bool,
        cancellation: option::Option<LotteryCancellationSummary>,
    }

    struct LegacyLotteryRegistryEntry has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        active: bool,
        cancellation: option::Option<LotteryCancellationSummary>,
    }

    struct LegacyLotteryRegistry has copy, drop, store {
        admin: address,
        next_lottery_id: u64,
        entries: vector<LegacyLotteryRegistryEntry>,
    }

    struct LotteryRegistrySnapshot has copy, drop, store {
        admin: address,
        next_lottery_id: u64,
        total_lotteries: u64,
        entries: vector<LotteryRegistryEntry>,
    }

    #[event]
    struct LotteryRegistrySnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<LotteryRegistrySnapshot>,
        current: LotteryRegistrySnapshot,
    }

    struct LotteryRegistry has key {
        admin: address,
        next_lottery_id: u64,
        entries: table::Table<u64, LotteryRegistryEntry>,
        lottery_ids: vector<u64>,
        snapshot_events: event::EventHandle<LotteryRegistrySnapshotUpdatedEvent>,
    }

    public entry fun init(caller: &signer, admin: address) acquires LotteryRegistry {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<LotteryRegistry>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            LotteryRegistry {
                admin,
                next_lottery_id: 1,
                entries: table::new<u64, LotteryRegistryEntry>(),
                lottery_ids: vector::empty<u64>(),
                snapshot_events: account::new_event_handle<LotteryRegistrySnapshotUpdatedEvent>(caller),
            },
        );
        let registry = borrow_global_mut<LotteryRegistry>(caller_address);
        emit_snapshot(registry, option::none<LotteryRegistrySnapshot>());
    }

    public fun is_initialized(): bool {
        exists<LotteryRegistry>(@lottery)
    }

    #[view]
    public fun ready(): bool {
        if (!is_initialized() || !instances::is_initialized()) {
            return false;
        };
        let registry = borrow_global<LotteryRegistry>(@lottery);
        let max_id = max_lottery_id(&registry.lottery_ids);
        entries_match_ids(&registry.entries, &registry.lottery_ids, vector::length(&registry.lottery_ids))
            && registry.next_lottery_id > max_id
    }

    public fun set_admin(new_admin: address) acquires LotteryRegistry {
        ensure_initialized();
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let previous = option::some(build_snapshot(registry));
        registry.admin = new_admin;
        emit_snapshot(registry, previous);
    }

    public fun record_creation_from_instances(lottery_id: u64)
    acquires LotteryRegistry, instances::InstanceRegistry {
        ensure_initialized();
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        assert!(!table::contains(&registry.entries, lottery_id), E_ENTRY_EXISTS);
        let previous = option::some(build_snapshot(registry));
        let instance_registry = instances::borrow_registry(@lottery);
        let instance = instances::instance(instance_registry, lottery_id);
        add_entry(
            registry,
            lottery_id,
            instance.owner,
            instance.lottery_address,
            instance.ticket_price,
            instance.jackpot_share_bps,
            instance.active,
        );
        emit_snapshot(registry, previous);
    }

    public fun sync_entry_from_instances(lottery_id: u64)
    acquires LotteryRegistry, instances::InstanceRegistry {
        ensure_initialized();
        assert!(entry_exists(lottery_id), E_ENTRY_MISSING);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let previous = option::some(build_snapshot(registry));
        let instance_registry = instances::borrow_registry(@lottery);
        let instance = instances::instance(instance_registry, lottery_id);
        update_entry_from_instance(
            registry,
            lottery_id,
            instance.owner,
            instance.lottery_address,
            instance.ticket_price,
            instance.jackpot_share_bps,
            instance.active,
        );
        emit_snapshot(registry, previous);
    }

    public fun record_cancellation(lottery_id: u64, reason_code: u8, canceled_ts: u64)
    acquires LotteryRegistry {
        ensure_initialized();
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        apply_cancellation_update(registry, lottery_id, reason_code, canceled_ts);
    }

    public entry fun record_existing_cancellation(
        caller: &signer,
        update: LegacyCancellationImport,
    ) acquires LotteryRegistry {
        ensure_initialized();
        ensure_admin_signer(caller);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        apply_cancellation_update(registry, update.lottery_id, update.reason_code, update.canceled_ts);
    }

    public entry fun record_existing_cancellations(
        caller: &signer,
        updates: vector<LegacyCancellationImport>,
    ) acquires LotteryRegistry {
        ensure_initialized();
        ensure_admin_signer(caller);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let len = vector::length(&updates);
        record_existing_batch(registry, &updates, len);
    }

    public entry fun import_existing_entry(caller: &signer, entry: LegacyLotteryRegistryEntry)
    acquires LotteryRegistry {
        ensure_initialized();
        ensure_admin_signer(caller);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let previous = option::some(build_snapshot(registry));
        upsert_entry(registry, entry);
        emit_snapshot(registry, previous);
    }

    public entry fun import_existing_entries(caller: &signer, entries: vector<LegacyLotteryRegistryEntry>)
    acquires LotteryRegistry {
        ensure_initialized();
        ensure_admin_signer(caller);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let previous = option::some(build_snapshot(registry));
        import_entries_batch(registry, &entries, vector::length(&entries));
        emit_snapshot(registry, previous);
    }

    public entry fun import_existing_registry(caller: &signer, payload: LegacyLotteryRegistry)
    acquires LotteryRegistry {
        import_existing_registry_payload(caller, payload);
    }

    public fun import_existing_registry_payload(caller: &signer, payload: LegacyLotteryRegistry)
    acquires LotteryRegistry {
        ensure_initialized();
        ensure_admin_signer(caller);
        let registry = borrow_global_mut<LotteryRegistry>(@lottery);
        let previous = option::some(build_snapshot(registry));
        clear_registry(registry);
        registry.admin = payload.admin;
        registry.next_lottery_id = payload.next_lottery_id;
        import_entries_batch(registry, &payload.entries, vector::length(&payload.entries));
        normalize_next_lottery_id(registry);
        emit_snapshot(registry, previous);
    }

    #[view]
    public fun registry_snapshot(): option::Option<LotteryRegistrySnapshot> acquires LotteryRegistry {
        if (!exists<LotteryRegistry>(@lottery)) {
            return option::none<LotteryRegistrySnapshot>();
        };
        let registry = borrow_global<LotteryRegistry>(@lottery);
        let snapshot = build_snapshot_view(&registry);
        option::some(snapshot)
    }

    #[view]
    public fun lottery_entry(lottery_id: u64): option::Option<LotteryRegistryEntry>
    acquires LotteryRegistry {
        if (!exists<LotteryRegistry>(@lottery)) {
            return option::none<LotteryRegistryEntry>();
        };
        let registry = borrow_global<LotteryRegistry>(@lottery);
        if (!table::contains(&registry.entries, lottery_id)) {
            option::none<LotteryRegistryEntry>()
        } else {
            option::some(*table::borrow(&registry.entries, lottery_id))
        }
    }

    #[view]
    public fun lottery_ids(): vector<u64> acquires LotteryRegistry {
        if (!exists<LotteryRegistry>(@lottery)) {
            return vector::empty<u64>();
        };
        let registry = borrow_global<LotteryRegistry>(@lottery);
        clone_ids(&registry.lottery_ids)
    }

    fun ensure_initialized() {
        if (!exists<LotteryRegistry>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_admin_signer(caller: &signer) acquires LotteryRegistry {
        let registry = borrow_global<LotteryRegistry>(@lottery);
        let caller_address = signer::address_of(caller);
        assert!(caller_address == registry.admin, E_UNAUTHORIZED);
    }

    fun entry_exists(lottery_id: u64): bool acquires LotteryRegistry {
        let registry = borrow_global<LotteryRegistry>(@lottery);
        table::contains(&registry.entries, lottery_id)
    }

    fun add_entry(
        registry: &mut LotteryRegistry,
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        active: bool,
    ) {
        table::add(
            &mut registry.entries,
            lottery_id,
            LotteryRegistryEntry {
                lottery_id,
                owner,
                lottery_address,
                ticket_price,
                jackpot_share_bps,
                active,
                cancellation: option::none<LotteryCancellationSummary>(),
            },
        );
        vector::push_back(&mut registry.lottery_ids, lottery_id);
        bump_next_lottery_id(registry, lottery_id);
    }

    fun upsert_entry(registry: &mut LotteryRegistry, entry: LegacyLotteryRegistryEntry) {
        let lottery_id = entry.lottery_id;
        if (table::contains(&registry.entries, lottery_id)) {
            let existing = table::borrow_mut(&mut registry.entries, lottery_id);
            existing.owner = entry.owner;
            existing.lottery_address = entry.lottery_address;
            existing.ticket_price = entry.ticket_price;
            existing.jackpot_share_bps = entry.jackpot_share_bps;
            existing.active = entry.active;
            existing.cancellation = entry.cancellation;
            return;
        };
        if (!contains_id(&registry.lottery_ids, lottery_id, vector::length(&registry.lottery_ids))) {
            vector::push_back(&mut registry.lottery_ids, lottery_id);
        };
        table::add(&mut registry.entries, lottery_id, convert_legacy_entry(entry));
        bump_next_lottery_id(registry, lottery_id);
    }

    fun convert_legacy_entry(entry: LegacyLotteryRegistryEntry): LotteryRegistryEntry {
        LotteryRegistryEntry {
            lottery_id: entry.lottery_id,
            owner: entry.owner,
            lottery_address: entry.lottery_address,
            ticket_price: entry.ticket_price,
            jackpot_share_bps: entry.jackpot_share_bps,
            active: entry.active,
            cancellation: entry.cancellation,
        }
    }

    fun apply_cancellation_update(
        registry: &mut LotteryRegistry,
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
    ) {
        assert!(table::contains(&registry.entries, lottery_id), E_ENTRY_MISSING);
        let previous = option::some(build_snapshot(registry));
        let entry = table::borrow_mut(&mut registry.entries, lottery_id);
        entry.cancellation = option::some(LotteryCancellationSummary { reason_code, canceled_ts });
        entry.active = false;
        emit_snapshot(registry, previous);
    }

    fun record_existing_batch(
        registry: &mut LotteryRegistry,
        updates: &vector<LegacyCancellationImport>,
        remaining: u64,
    ) {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        record_existing_batch(registry, updates, next_remaining);
        let update = *vector::borrow(updates, next_remaining);
        apply_cancellation_update(registry, update.lottery_id, update.reason_code, update.canceled_ts);
    }

    fun import_entries_batch(
        registry: &mut LotteryRegistry,
        entries: &vector<LegacyLotteryRegistryEntry>,
        remaining: u64,
    ) {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        import_entries_batch(registry, entries, next_remaining);
        let entry = *vector::borrow(entries, next_remaining);
        upsert_entry(registry, entry);
    }

    fun update_entry_from_instance(
        registry: &mut LotteryRegistry,
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        active: bool,
    ) {
        let entry = table::borrow_mut(&mut registry.entries, lottery_id);
        entry.owner = owner;
        entry.lottery_address = lottery_address;
        entry.ticket_price = ticket_price;
        entry.jackpot_share_bps = jackpot_share_bps;
        entry.active = active;
    }

    fun emit_snapshot(
        registry: &mut LotteryRegistry,
        previous: option::Option<LotteryRegistrySnapshot>,
    ) {
        let current = build_snapshot(registry);
        event::emit_event(
            &mut registry.snapshot_events,
            LotteryRegistrySnapshotUpdatedEvent { previous, current },
        );
    }

    fun build_snapshot(registry: &LotteryRegistry): LotteryRegistrySnapshot {
        LotteryRegistrySnapshot {
            admin: registry.admin,
            next_lottery_id: registry.next_lottery_id,
            total_lotteries: vector::length(&registry.lottery_ids),
            entries: collect_entries(registry, &registry.lottery_ids, vector::length(&registry.lottery_ids)),
        }
    }

    fun build_snapshot_view(registry: &LotteryRegistry): LotteryRegistrySnapshot {
        build_snapshot(registry)
    }

    fun collect_entries(
        registry: &LotteryRegistry,
        ids: &vector<u64>,
        remaining: u64,
    ): vector<LotteryRegistryEntry> {
        if (remaining == 0) {
            return vector::empty<LotteryRegistryEntry>();
        };
        let next_remaining = remaining - 1;
        let mut entries = collect_entries(registry, ids, next_remaining);
        let lottery_id = *vector::borrow(ids, next_remaining);
        let entry = *table::borrow(&registry.entries, lottery_id);
        vector::push_back(&mut entries, entry);
        entries
    }

    fun clone_ids(source: &vector<u64>): vector<u64> {
        clone_ids_inner(source, vector::length(source))
    }

    fun clone_ids_inner(source: &vector<u64>, remaining: u64): vector<u64> {
        if (remaining == 0) {
            return vector::empty<u64>();
        };
        let next_remaining = remaining - 1;
        let mut ids = clone_ids_inner(source, next_remaining);
        let value = *vector::borrow(source, next_remaining);
        vector::push_back(&mut ids, value);
        ids
    }

    fun contains_id(ids: &vector<u64>, target: u64, remaining: u64): bool {
        if (remaining == 0) {
            return false;
        };
        let next_remaining = remaining - 1;
        let current = *vector::borrow(ids, next_remaining);
        if (current == target) {
            true
        } else {
            contains_id(ids, target, next_remaining)
        }
    }

    fun clear_registry(registry: &mut LotteryRegistry) {
        let ids = clone_ids(&registry.lottery_ids);
        clear_entries(registry, &ids, vector::length(&ids));
        registry.lottery_ids = vector::empty<u64>();
        registry.next_lottery_id = 1;
    }

    fun clear_entries(
        registry: &mut LotteryRegistry,
        ids: &vector<u64>,
        remaining: u64,
    ) {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        clear_entries(registry, ids, next_remaining);
        let lottery_id = *vector::borrow(ids, next_remaining);
        if (table::contains(&registry.entries, lottery_id)) {
            table::remove(&mut registry.entries, lottery_id);
        };
    }

    fun normalize_next_lottery_id(registry: &mut LotteryRegistry) {
        let highest = max_lottery_id(&registry.lottery_ids);
        let required_next = highest + 1;
        if (registry.next_lottery_id < required_next) {
            registry.next_lottery_id = required_next;
        };
    }

    fun bump_next_lottery_id(registry: &mut LotteryRegistry, lottery_id: u64) {
        let required_next = lottery_id + 1;
        if (registry.next_lottery_id < required_next) {
            registry.next_lottery_id = required_next;
        };
    }

    fun max_lottery_id(ids: &vector<u64>): u64 {
        let len = vector::length(ids);
        max_lottery_id_inner(ids, len)
    }

    fun max_lottery_id_inner(ids: &vector<u64>, remaining: u64): u64 {
        if (remaining == 0) {
            return 0;
        };
        let next_remaining = remaining - 1;
        let best = max_lottery_id_inner(ids, next_remaining);
        let value = *vector::borrow(ids, next_remaining);
        if (value > best) {
            value
        } else {
            best
        }
    }

    fun entries_match_ids(
        entries: &table::Table<u64, LotteryRegistryEntry>,
        ids: &vector<u64>,
        remaining: u64,
    ): bool {
        if (remaining == 0) {
            return true;
        };
        let next_remaining = remaining - 1;
        let previous_ok = entries_match_ids(entries, ids, next_remaining);
        let lottery_id = *vector::borrow(ids, next_remaining);
        previous_ok && table::contains(entries, lottery_id)
    }
}
