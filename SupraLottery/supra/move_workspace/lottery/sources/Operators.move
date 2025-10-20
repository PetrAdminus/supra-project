module lottery::operators {
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
    
    const E_ALREADY_INIT: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;
    const E_OPERATOR_EXISTS: u64 = 5;
    const E_OPERATOR_MISSING: u64 = 6;

    struct LotteryOperators has key {
        admin: address,
        entries: table::Table<u64, LotteryOperatorEntry>,
        lottery_ids: vector<u64>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        owner_events: event::EventHandle<OwnerUpdatedEvent>,
        grant_events: event::EventHandle<OperatorGrantedEvent>,
        revoke_events: event::EventHandle<OperatorRevokedEvent>,
        snapshot_events: event::EventHandle<OperatorSnapshotUpdatedEvent>,
    }

    struct LotteryOperatorEntry has store {
        owner: address,
        operators: table::Table<address, bool>,
        operator_list: vector<address>,
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

    struct OperatorSnapshot has copy, drop, store {
        owner: option::Option<address>,
        operators: vector<address>,
    }

    public entry fun init(caller: &signer) acquires LotteryOperators {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<LotteryOperators>(@lottery)) {
            abort E_ALREADY_INIT
        };
        move_to(
            caller,
            LotteryOperators {
                admin: addr,
                entries: table::new(),
                lottery_ids: vector::empty<u64>(),
                admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
                owner_events: account::new_event_handle<OwnerUpdatedEvent>(caller),
                grant_events: account::new_event_handle<OperatorGrantedEvent>(caller),
                revoke_events: account::new_event_handle<OperatorRevokedEvent>(caller),
                snapshot_events: account::new_event_handle<OperatorSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        emit_all_snapshots(state);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<LotteryOperators>(@lottery)
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires LotteryOperators {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
    }

    public entry fun set_owner(caller: &signer, lottery_id: u64, owner: address) acquires LotteryOperators {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            table::add(
                &mut state.entries,
                lottery_id,
                LotteryOperatorEntry {
                    owner,
                    operators: table::new(),
                    operator_list: vector::empty<address>(),
                },
            );
            record_lottery_id(&mut state.lottery_ids, lottery_id);
            event::emit_event(
                &mut state.owner_events,
                OwnerUpdatedEvent {
                    lottery_id,
                    previous: option::none<address>(),
                    next: option::some(owner),
                },
            );
            // state changed: emit snapshot
            emit_operator_snapshot(state, lottery_id);
        } else {
            let owner_changed = false;
            let previous_owner = owner;
            {
                let entry = table::borrow_mut(&mut state.entries, lottery_id);
                if (entry.owner != owner) {
                    owner_changed = true;
                    previous_owner = entry.owner;
                    entry.owner = owner;
                };
            };
            if (owner_changed) {
                event::emit_event(
                    &mut state.owner_events,
                    OwnerUpdatedEvent {
                        lottery_id,
                        previous: option::some(previous_owner),
                        next: option::some(owner),
                    },
                );
                // state changed: emit snapshot
                emit_operator_snapshot(state, lottery_id);
            };
        };
    }

    public entry fun grant_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires LotteryOperators {
        ensure_can_manage(caller, lottery_id);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        {
            let entry = table::borrow_mut(&mut state.entries, lottery_id);
            if (table::contains(&entry.operators, operator)) {
                abort E_OPERATOR_EXISTS
            };
            table::add(&mut entry.operators, operator, true);
            record_operator(&mut entry.operator_list, operator);
        };
        event::emit_event(
            &mut state.grant_events,
            OperatorGrantedEvent {
                lottery_id,
                operator,
                granted_by: signer::address_of(caller),
            },
        );
        emit_operator_snapshot(state, lottery_id);
    }

    public entry fun revoke_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires LotteryOperators {
        ensure_can_manage(caller, lottery_id);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        {
            let entry = table::borrow_mut(&mut state.entries, lottery_id);
            if (!table::contains(&entry.operators, operator)) {
                abort E_OPERATOR_MISSING
            };
            table::remove(&mut entry.operators, operator);
            remove_operator(&mut entry.operator_list, operator);
        };
        event::emit_event(
            &mut state.revoke_events,
            OperatorRevokedEvent {
                lottery_id,
                operator,
                revoked_by: signer::address_of(caller),
            },
        );
        emit_operator_snapshot(state, lottery_id);
    }

    #[view]
    public fun get_owner(lottery_id: u64): option::Option<address> acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return option::none<address>()
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            return option::none<address>()
        };
        let entry = table::borrow(&state.entries, lottery_id);
        option::some(entry.owner)
    }

    #[view]
    public fun is_operator(lottery_id: u64, operator: address): bool acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return false
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            return false
        };
        let entry = table::borrow(&state.entries, lottery_id);
        table::contains(&entry.operators, operator)
    }

    #[view]
    public fun can_manage(lottery_id: u64, actor: address): bool acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return false
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        if (state.admin == actor) {
            return true
        };
        if (!table::contains(&state.entries, lottery_id)) {
            return false
        };
        let entry = table::borrow(&state.entries, lottery_id);
        if (entry.owner == actor) {
            return true
        };
        table::contains(&entry.operators, actor)
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun list_operators(lottery_id: u64): option::Option<vector<address>>
    acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return option::none<vector<address>>()
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            return option::none<vector<address>>()
        };
        let entry = table::borrow(&state.entries, lottery_id);
        option::some(copy_address_vector(&entry.operator_list))
    }

    #[view]
    public fun get_operator_snapshot(lottery_id: u64): OperatorSnapshot acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            return OperatorSnapshot {
                owner: option::none(),
                operators: vector::empty<address>(),
            }
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        build_operator_snapshot(state, lottery_id)
    }

    #[test_only]
    public fun operator_snapshot_fields_for_test(
        snapshot: &OperatorSnapshot
    ): (option::Option<address>, vector<address>) {
        (
            snapshot.owner,
            copy_address_vector(&snapshot.operators),
        )
    }

    #[test_only]
    public fun operator_snapshot_event_fields_for_test(
        event: &OperatorSnapshotUpdatedEvent
    ): (u64, option::Option<address>, vector<address>) {
        (
            event.lottery_id,
            event.owner,
            copy_address_vector(&event.operators),
        )
    }

    public fun ensure_authorized(caller: &signer, lottery_id: u64) acquires LotteryOperators {
        if (!can_manage(lottery_id, signer::address_of(caller))) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_admin(caller: &signer) acquires LotteryOperators {
        let addr = signer::address_of(caller);
        if (!exists<LotteryOperators>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<LotteryOperators>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_can_manage(caller: &signer, lottery_id: u64) acquires LotteryOperators {
        if (!exists<LotteryOperators>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let addr = signer::address_of(caller);
        let state = borrow_global<LotteryOperators>(@lottery);
        if (state.admin == addr) {
            return
        };
        if (!table::contains(&state.entries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let entry = table::borrow(&state.entries, lottery_id);
        if (entry.owner != addr && !table::contains(&entry.operators, addr)) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(ids, lottery_id);
    }

    fun record_operator(operators: &mut vector<address>, operator: address) {
        let len = vector::length(operators);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(operators, idx) == operator) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(operators, operator);
    }

    fun remove_operator(operators: &mut vector<address>, operator: address) {
        let len = vector::length(operators);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(operators, idx) == operator) {
                if (idx != len - 1) {
                    vector::swap(operators, idx, len - 1);
                };
                vector::pop_back(operators);
                return
            };
            idx = idx + 1;
        };
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        let out = vector::empty<u64>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun copy_address_vector(values: &vector<address>): vector<address> {
        let out = vector::empty<address>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun emit_all_snapshots(state: &mut LotteryOperators) {
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            emit_operator_snapshot(state, lottery_id);
            idx = idx + 1;
        };
    }

    fun emit_operator_snapshot(state: &mut LotteryOperators, lottery_id: u64) {
        let snapshot = build_operator_snapshot_from_mut(state, lottery_id);
        let OperatorSnapshot { owner, operators } = snapshot;
        event::emit_event(
            &mut state.snapshot_events,
            OperatorSnapshotUpdatedEvent { lottery_id, owner, operators },
        );
    }

    fun build_operator_snapshot_from_mut(
        state: &mut LotteryOperators,
        lottery_id: u64,
    ): OperatorSnapshot {
        build_operator_snapshot_from_table(&state.entries, lottery_id)
    }

    fun build_operator_snapshot(state: &LotteryOperators, lottery_id: u64): OperatorSnapshot {
        build_operator_snapshot_from_table(&state.entries, lottery_id)
    }

    fun build_operator_snapshot_from_table(
        entries: &table::Table<u64, LotteryOperatorEntry>,
        lottery_id: u64,
    ): OperatorSnapshot {
        if (!table::contains(entries, lottery_id)) {
            return OperatorSnapshot {
                owner: option::none(),
                operators: vector::empty<address>(),
            }
        };
        let entry = table::borrow(entries, lottery_id);
        OperatorSnapshot {
            owner: option::some(entry.owner),
            operators: copy_address_vector(&entry.operator_list),
        }
    }
}
