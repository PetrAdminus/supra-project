module lottery::operators {
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;

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

    public entry fun init(caller: &signer) {
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
                admin_events: event::new_event_handle<AdminUpdatedEvent>(caller),
                owner_events: event::new_event_handle<OwnerUpdatedEvent>(caller),
                grant_events: event::new_event_handle<OperatorGrantedEvent>(caller),
                revoke_events: event::new_event_handle<OperatorRevokedEvent>(caller),
            },
        );
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
            return
        };

        let entry = table::borrow_mut(&mut state.entries, lottery_id);
        if (entry.owner != owner) {
            let previous_owner = entry.owner;
            entry.owner = owner;
            event::emit_event(
                &mut state.owner_events,
                OwnerUpdatedEvent {
                    lottery_id,
                    previous: option::some(previous_owner),
                    next: option::some(owner),
                },
            );
        };
    }

    public entry fun grant_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires LotteryOperators {
        ensure_can_manage(caller, lottery_id);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        let entry = table::borrow_mut(&mut state.entries, lottery_id);
        if (table::contains(&entry.operators, operator)) {
            abort E_OPERATOR_EXISTS
        };
        table::add(&mut entry.operators, operator, true);
        record_operator(&mut entry.operator_list, operator);
        event::emit_event(
            &mut state.grant_events,
            OperatorGrantedEvent {
                lottery_id,
                operator,
                granted_by: signer::address_of(caller),
            },
        );
    }

    public entry fun revoke_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires LotteryOperators {
        ensure_can_manage(caller, lottery_id);
        let state = borrow_global_mut<LotteryOperators>(@lottery);
        let entry = table::borrow_mut(&mut state.entries, lottery_id);
        if (!table::contains(&entry.operators, operator)) {
            abort E_OPERATOR_MISSING
        };
        table::remove(&mut entry.operators, operator);
        remove_operator(&mut entry.operator_list, operator);
        event::emit_event(
            &mut state.revoke_events,
            OperatorRevokedEvent {
                lottery_id,
                operator,
                revoked_by: signer::address_of(caller),
            },
        );
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
}
