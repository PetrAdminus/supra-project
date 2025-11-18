module lottery_data::operators {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_UNKNOWN_LOTTERY: u64 = 3;

    public struct LegacyOperatorRecord has drop, store {
        lottery_id: u64,
        owner: option::Option<address>,
        operators: vector<address>,
    }

    struct LotteryOperatorEntry has store {
        owner: option::Option<address>,
        operators: table::Table<address, bool>,
        operator_list: vector<address>,
    }

    struct OperatorRegistrySnapshot has copy, drop, store {
        admin: address,
        lottery_ids: vector<u64>,
        entries: vector<LotteryOperatorSnapshot>,
    }

    struct LotteryOperatorSnapshot has copy, drop, store {
        lottery_id: u64,
        snapshot: OperatorSnapshot,
    }

    struct OperatorSnapshot has copy, drop, store {
        owner: option::Option<address>,
        operators: vector<address>,
    }

    struct OperatorRegistry has key {
        admin: address,
        entries: table::Table<u64, LotteryOperatorEntry>,
        lottery_ids: vector<u64>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        owner_events: event::EventHandle<OwnerUpdatedEvent>,
        grant_events: event::EventHandle<OperatorGrantedEvent>,
        revoke_events: event::EventHandle<OperatorRevokedEvent>,
        snapshot_events: event::EventHandle<OperatorSnapshotUpdatedEvent>,
    }

    #[event]
    struct AdminUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    #[event]
    struct OwnerUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        previous: option::Option<address>,
        next: option::Option<address>,
    }

    #[event]
    struct OperatorGrantedEvent has drop, store, copy {
        lottery_id: u64,
        operator: address,
        granted_by: address,
    }

    #[event]
    struct OperatorRevokedEvent has drop, store, copy {
        lottery_id: u64,
        operator: address,
        revoked_by: address,
    }

    #[event]
    struct OperatorSnapshotUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        owner: option::Option<address>,
        operators: vector<address>,
    }

    public entry fun import_existing_operator_record(caller: &signer, record: LegacyOperatorRecord)
    acquires OperatorRegistry {
        ensure_admin(caller);
        upsert_legacy_operator_record(record);
    }

    public entry fun import_existing_operator_records(
        caller: &signer,
        mut records: vector<LegacyOperatorRecord>,
    ) acquires OperatorRegistry {
        ensure_admin(caller);
        import_existing_operator_records_recursive(&mut records);
    }

    public entry fun init_registry(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<OperatorRegistry>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            OperatorRegistry {
                admin: caller_address,
                entries: table::new<u64, LotteryOperatorEntry>(),
                lottery_ids: vector::empty<u64>(),
                admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
                owner_events: account::new_event_handle<OwnerUpdatedEvent>(caller),
                grant_events: account::new_event_handle<OperatorGrantedEvent>(caller),
                revoke_events: account::new_event_handle<OperatorRevokedEvent>(caller),
                snapshot_events: account::new_event_handle<OperatorSnapshotUpdatedEvent>(caller),
            },
        );
    }

    public fun borrow_registry(addr: address): &OperatorRegistry acquires OperatorRegistry {
        borrow_global<OperatorRegistry>(addr)
    }

    public fun borrow_registry_mut(addr: address): &mut OperatorRegistry acquires OperatorRegistry {
        borrow_global_mut<OperatorRegistry>(addr)
    }

    public fun contains(registry: &OperatorRegistry, lottery_id: u64): bool {
        table::contains(&registry.entries, lottery_id)
    }

    public fun owner(registry: &OperatorRegistry, lottery_id: u64): option::Option<address> {
        assert!(table::contains(&registry.entries, lottery_id), E_UNKNOWN_LOTTERY);
        let entry = table::borrow(&registry.entries, lottery_id);
        entry.owner
    }

    public fun has_operator(registry: &OperatorRegistry, lottery_id: u64, operator: address): bool {
        if (!table::contains(&registry.entries, lottery_id)) {
            return false;
        };
        let entry = table::borrow(&registry.entries, lottery_id);
        table::contains(&entry.operators, operator)
    }

    public fun registry_snapshot(): OperatorRegistrySnapshot acquires OperatorRegistry {
        let registry = borrow_registry(@lottery);
        OperatorRegistrySnapshot {
            admin: registry.admin,
            lottery_ids: registry.lottery_ids,
            entries: build_registry_snapshots(&registry.entries, &registry.lottery_ids, 0),
        }
    }

    public fun ensure_entry(registry: &mut OperatorRegistry, lottery_id: u64) {
        if (!table::contains(&registry.entries, lottery_id)) {
            table::add(
                &mut registry.entries,
                lottery_id,
                LotteryOperatorEntry {
                    owner: option::none<address>(),
                    operators: table::new<address, bool>(),
                    operator_list: vector::empty<address>(),
                },
            );
            vector::push_back(&mut registry.lottery_ids, lottery_id);
        };
    }

    public fun grant_operator(registry: &mut OperatorRegistry, lottery_id: u64, operator: address, granted_by: address) {
        ensure_entry(registry, lottery_id);
        let entry = table::borrow_mut(&mut registry.entries, lottery_id);
        if (!table::contains(&entry.operators, operator)) {
            table::add(&mut entry.operators, operator, true);
            vector::push_back(&mut entry.operator_list, operator);
        };
        event::emit_event(
            &mut registry.grant_events,
            OperatorGrantedEvent { lottery_id, operator, granted_by },
        );
    }

    public fun revoke_operator(registry: &mut OperatorRegistry, lottery_id: u64, operator: address, revoked_by: address) {
        ensure_entry(registry, lottery_id);
        let entry = table::borrow_mut(&mut registry.entries, lottery_id);
        if (table::contains(&entry.operators, operator)) {
            table::remove(&mut entry.operators, operator);
            remove_operator(&mut entry.operator_list, operator);
        };
        event::emit_event(
            &mut registry.revoke_events,
            OperatorRevokedEvent { lottery_id, operator, revoked_by },
        );
    }

    fun remove_operator(operators: &mut vector<address>, target: address) {
        let len = vector::length(operators);
        remove_operator_from_index(operators, target, 0, len);
    }

    fun remove_operator_from_index(
        operators: &mut vector<address>,
        target: address,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let current = *vector::borrow(operators, index);
        if (current == target) {
            vector::swap_remove(operators, index);
            return;
        };
        let next_index = index + 1;
        remove_operator_from_index(operators, target, next_index, len);
    }

    public fun set_owner(registry: &mut OperatorRegistry, lottery_id: u64, new_owner: option::Option<address>) {
        ensure_entry(registry, lottery_id);
        let entry = table::borrow_mut(&mut registry.entries, lottery_id);
        let previous = entry.owner;
        entry.owner = new_owner;
        event::emit_event(
            &mut registry.owner_events,
            OwnerUpdatedEvent { lottery_id, previous, next: new_owner },
        );
    }

    public fun emit_snapshot(registry: &mut OperatorRegistry, lottery_id: u64) {
        assert!(table::contains(&registry.entries, lottery_id), E_UNKNOWN_LOTTERY);
        let entry = table::borrow(&registry.entries, lottery_id);
        event::emit_event(
            &mut registry.snapshot_events,
            OperatorSnapshotUpdatedEvent {
                lottery_id,
                owner: entry.owner,
                operators: entry.operator_list,
            },
        );
    }

    fun import_existing_operator_records_recursive(records: &mut vector<LegacyOperatorRecord>)
    acquires OperatorRegistry {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        import_existing_operator_records_recursive(records);
        upsert_legacy_operator_record(record);
    }

    fun upsert_legacy_operator_record(record: LegacyOperatorRecord) acquires OperatorRegistry {
        let LegacyOperatorRecord {
            lottery_id,
            owner,
            mut operators,
        } = record;
        let registry = borrow_registry_mut(@lottery);
        ensure_entry(registry, lottery_id);
        ensure_lottery_id_recorded(&mut registry.lottery_ids, lottery_id, 0);
        {
            let entry = table::borrow_mut(&mut registry.entries, lottery_id);
            reset_operator_entry(entry);
        };
        set_owner(registry, lottery_id, owner);
        record_legacy_operators(registry, lottery_id, &mut operators);
        emit_snapshot(registry, lottery_id);
    }

    fun record_legacy_operators(
        registry: &mut OperatorRegistry,
        lottery_id: u64,
        operators: &mut vector<address>,
    ) acquires OperatorRegistry {
        if (vector::is_empty(operators)) {
            return;
        };
        let operator = vector::pop_back(operators);
        record_legacy_operators(registry, lottery_id, operators);
        grant_operator(registry, lottery_id, operator, registry.admin);
    }

    fun reset_operator_entry(entry: &mut LotteryOperatorEntry) {
        entry.operators = table::new<address, bool>();
        entry.operator_list = vector::empty<address>();
    }

    fun ensure_lottery_id_recorded(ids: &mut vector<u64>, lottery_id: u64, index: u64) {
        if (contains_lottery_id(ids, lottery_id, index)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun contains_lottery_id(ids: &vector<u64>, lottery_id: u64, index: u64): bool {
        if (index == vector::length(ids)) {
            return false;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            return true;
        };
        contains_lottery_id(ids, lottery_id, index + 1)
    }

    fun build_registry_snapshots(
        entries: &table::Table<u64, LotteryOperatorEntry>,
        lottery_ids: &vector<u64>,
        index: u64,
    ): vector<LotteryOperatorSnapshot> {
        if (index == vector::length(lottery_ids)) {
            return vector::empty<LotteryOperatorSnapshot>();
        };

        let lottery_id = *vector::borrow(lottery_ids, index);
        let mut snapshots = build_registry_snapshots(entries, lottery_ids, index + 1);
        let entry = table::borrow(entries, lottery_id);
        vector::push_back(
            &mut snapshots,
            LotteryOperatorSnapshot {
                lottery_id,
                snapshot: OperatorSnapshot {
                    owner: entry.owner,
                    operators: entry.operator_list,
                },
            },
        );
        snapshots
    }

    fun ensure_admin(caller: &signer) acquires OperatorRegistry {
        let registry = borrow_registry(@lottery);
        if (signer::address_of(caller) != registry.admin) {
            abort E_UNAUTHORIZED;
        };
    }
}
