module lottery_data::jackpot {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_JACKPOT_EXISTS: u64 = 3;
    const E_JACKPOT_UNKNOWN: u64 = 4;

    struct JackpotRuntime has copy, drop, store {
        tickets: vector<address>,
        draw_scheduled: bool,
        pending_request: option::Option<u64>,
        pending_payload: option::Option<vector<u8>>,
    }

    struct JackpotRuntimeView has copy, drop, store {
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        pending_request_id: option::Option<u64>,
        pending_payload: option::Option<vector<u8>>,
    }

    struct JackpotSnapshot has copy, drop, store {
        lottery_id: u64,
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
        pending_request_id: option::Option<u64>,
    }

    struct JackpotRegistrySnapshot has copy, drop, store {
        admin: address,
        lottery_ids: vector<u64>,
        snapshots: vector<JackpotSnapshot>,
    }

    #[event]
    struct JackpotTicketGrantedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        ticket_index: u64,
    }

    #[event]
    struct JackpotScheduleUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        draw_scheduled: bool,
    }

    #[event]
    struct JackpotRequestIssuedEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        payload: vector<u8>,
    }

    #[event]
    struct JackpotFulfilledEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    }

    #[event]
    struct JackpotSnapshotUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        snapshot: JackpotSnapshot,
    }

    struct JackpotRegistry has key {
        admin: address,
        jackpots: table::Table<u64, JackpotRuntime>,
        lottery_ids: vector<u64>,
        ticket_events: event::EventHandle<JackpotTicketGrantedEvent>,
        schedule_events: event::EventHandle<JackpotScheduleUpdatedEvent>,
        request_events: event::EventHandle<JackpotRequestIssuedEvent>,
        fulfill_events: event::EventHandle<JackpotFulfilledEvent>,
        snapshot_events: event::EventHandle<JackpotSnapshotUpdatedEvent>,
    }

    #[view]
    public fun is_initialized(): bool {
        exists<JackpotRegistry>(@lottery)
    }

    #[view]
    public fun ready(): bool acquires JackpotRegistry {
        if (!exists<JackpotRegistry>(@lottery)) {
            return false;
        };

        let registry = borrow_registry(@lottery);
        if (registry.admin != @lottery) {
            return false;
        };

        let expected_len = vector::length(&registry.lottery_ids);
        if (table::length(&registry.jackpots) != expected_len) {
            return false;
        };

        lotteries_ready(&registry.jackpots, &registry.lottery_ids, 0, expected_len)
    }

    public entry fun init_registry(caller: &signer) {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @lottery, E_UNAUTHORIZED);
        assert!(!exists<JackpotRegistry>(caller_addr), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            JackpotRegistry {
                admin: caller_addr,
                jackpots: table::new<u64, JackpotRuntime>(),
                lottery_ids: vector::empty<u64>(),
                ticket_events: account::new_event_handle<JackpotTicketGrantedEvent>(caller),
                schedule_events: account::new_event_handle<JackpotScheduleUpdatedEvent>(caller),
                request_events: account::new_event_handle<JackpotRequestIssuedEvent>(caller),
                fulfill_events: account::new_event_handle<JackpotFulfilledEvent>(caller),
                snapshot_events: account::new_event_handle<JackpotSnapshotUpdatedEvent>(caller),
            },
        );
    }

    public fun borrow_registry(addr: address): &JackpotRegistry acquires JackpotRegistry {
        borrow_global<JackpotRegistry>(addr)
    }

    public fun borrow_registry_mut(addr: address): &mut JackpotRegistry acquires JackpotRegistry {
        borrow_global_mut<JackpotRegistry>(addr)
    }

    public fun register_jackpot(registry: &mut JackpotRegistry, lottery_id: u64) {
        assert!(!table::contains(&registry.jackpots, lottery_id), E_JACKPOT_EXISTS);
        table::add(
            &mut registry.jackpots,
            lottery_id,
            JackpotRuntime {
                tickets: vector::empty<address>(),
                draw_scheduled: false,
                pending_request: option::none<u64>(),
                pending_payload: option::none<vector<u8>>(),
            },
        );
        vector::push_back(&mut registry.lottery_ids, lottery_id);
        emit_snapshot(registry, lottery_id);
    }

    public fun is_registered(registry: &JackpotRegistry, lottery_id: u64): bool {
        table::contains(&registry.jackpots, lottery_id)
    }

    public fun jackpot(registry: &JackpotRegistry, lottery_id: u64): &JackpotRuntime {
        assert!(table::contains(&registry.jackpots, lottery_id), E_JACKPOT_UNKNOWN);
        table::borrow(&registry.jackpots, lottery_id)
    }

    public fun jackpot_mut(registry: &mut JackpotRegistry, lottery_id: u64): &mut JackpotRuntime {
        assert!(table::contains(&registry.jackpots, lottery_id), E_JACKPOT_UNKNOWN);
        table::borrow_mut(&mut registry.jackpots, lottery_id)
    }

    public fun record_ticket(
        registry: &mut JackpotRegistry,
        lottery_id: u64,
        player: address,
    ): u64 {
        let runtime = jackpot_mut(registry, lottery_id);
        let ticket_index = vector::length(&runtime.tickets);
        vector::push_back(&mut runtime.tickets, player);
        event::emit_event(
            &mut registry.ticket_events,
            JackpotTicketGrantedEvent { lottery_id, player, ticket_index },
        );
        emit_snapshot(registry, lottery_id);
        ticket_index
    }

    public fun schedule_draw(registry: &mut JackpotRegistry, lottery_id: u64) {
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.draw_scheduled = true;
        event::emit_event(
            &mut registry.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
        );
        emit_snapshot(registry, lottery_id);
    }

    public fun reset_draw(registry: &mut JackpotRegistry, lottery_id: u64) {
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.draw_scheduled = false;
        runtime.pending_request = option::none<u64>();
        runtime.pending_payload = option::none<vector<u8>>();
        clear_tickets(&mut runtime.tickets);
        event::emit_event(
            &mut registry.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
        );
        emit_snapshot(registry, lottery_id);
    }

    public fun record_request(
        registry: &mut JackpotRegistry,
        lottery_id: u64,
        request_id: u64,
        payload: &vector<u8>,
    ) {
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.pending_request = option::some(request_id);
        runtime.pending_payload = option::some(clone_bytes(payload));
        event::emit_event(
            &mut registry.request_events,
            JackpotRequestIssuedEvent {
                lottery_id,
                request_id,
                payload: clone_bytes(payload),
            },
        );
        emit_snapshot(registry, lottery_id);
    }

    public fun record_fulfillment(
        registry: &mut JackpotRegistry,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        randomness: &vector<u8>,
        payload: &vector<u8>,
    ) {
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.draw_scheduled = false;
        runtime.pending_request = option::none<u64>();
        runtime.pending_payload = option::none<vector<u8>>();
        clear_tickets(&mut runtime.tickets);
        event::emit_event(
            &mut registry.fulfill_events,
            JackpotFulfilledEvent {
                lottery_id,
                request_id,
                winner,
                ticket_index,
                prize_amount,
                random_bytes: clone_bytes(randomness),
                payload: clone_bytes(payload),
            },
        );
        emit_snapshot(registry, lottery_id);
    }

    public fun restore_runtime(
        registry: &mut JackpotRegistry,
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        pending_request: option::Option<u64>,
        pending_payload: option::Option<vector<u8>>,
    ) {
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.tickets = tickets;
        runtime.draw_scheduled = draw_scheduled;
        runtime.pending_request = pending_request;
        runtime.pending_payload = pending_payload;
        emit_snapshot(registry, lottery_id);
    }

    public fun emit_snapshot(registry: &mut JackpotRegistry, lottery_id: u64) {
        let runtime_ref = jackpot(registry, lottery_id);
        let snapshot = build_snapshot(lottery_id, runtime_ref);
        event::emit_event(&mut registry.snapshot_events, JackpotSnapshotUpdatedEvent { lottery_id, snapshot });
    }

    #[view]
    public fun registry_snapshot(): option::Option<JackpotRegistrySnapshot> acquires JackpotRegistry {
        if (!exists<JackpotRegistry>(@lottery)) {
            return option::none<JackpotRegistrySnapshot>();
        };
        let registry = borrow_registry(@lottery);
        let ids = clone_u64s(&registry.lottery_ids);
        let snapshots = collect_snapshots(&registry.jackpots, &registry.lottery_ids, 0, vector::length(&registry.lottery_ids));
        option::some(JackpotRegistrySnapshot { admin: registry.admin, lottery_ids: ids, snapshots })
    }

    #[view]
    public fun lottery_snapshot(lottery_id: u64): option::Option<JackpotSnapshot> acquires JackpotRegistry {
        if (!exists<JackpotRegistry>(@lottery)) {
            return option::none<JackpotSnapshot>();
        };
        let registry = borrow_registry(@lottery);
        if (!table::contains(&registry.jackpots, lottery_id)) {
            return option::none<JackpotSnapshot>();
        };
        let runtime_ref = table::borrow(&registry.jackpots, lottery_id);
        option::some(build_snapshot(lottery_id, runtime_ref))
    }

    #[view]
    public fun runtime_view(lottery_id: u64): option::Option<JackpotRuntimeView> acquires JackpotRegistry {
        if (!exists<JackpotRegistry>(@lottery)) {
            return option::none<JackpotRuntimeView>();
        };
        let registry = borrow_registry(@lottery);
        if (!table::contains(&registry.jackpots, lottery_id)) {
            return option::none<JackpotRuntimeView>();
        };
        let runtime_ref = table::borrow(&registry.jackpots, lottery_id);
        option::some(build_runtime_view(lottery_id, runtime_ref))
    }

    #[view]
    public fun runtime_views(): option::Option<vector<JackpotRuntimeView>> acquires JackpotRegistry {
        if (!exists<JackpotRegistry>(@lottery)) {
            return option::none<vector<JackpotRuntimeView>>();
        };
        let registry = borrow_registry(@lottery);
        let views = collect_runtime_views(&registry.jackpots, &registry.lottery_ids, 0, vector::length(&registry.lottery_ids));
        option::some(views)
    }

    public fun empty_runtime(): JackpotRuntime {
        JackpotRuntime {
            tickets: vector::empty<address>(),
            draw_scheduled: false,
            pending_request: option::none<u64>(),
            pending_payload: option::none<vector<u8>>(),
        }
    }

    fun lotteries_ready(
        jackpots: &table::Table<u64, JackpotRuntime>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            return true;
        };

        let lottery_id = *vector::borrow(lottery_ids, index);
        if (!table::contains(jackpots, lottery_id)) {
            return false;
        };

        let runtime_ref = table::borrow(jackpots, lottery_id);
        if (!runtime_ready(runtime_ref)) {
            return false;
        };

        lotteries_ready(jackpots, lottery_ids, index + 1, len)
    }

    fun runtime_ready(runtime_ref: &JackpotRuntime): bool {
        let request_pending = option::is_some(&runtime_ref.pending_request);
        let payload_pending = option::is_some(&runtime_ref.pending_payload);
        if (request_pending != payload_pending) {
            return false;
        };
        true
    }

    fun build_snapshot(lottery_id: u64, runtime_ref: &JackpotRuntime): JackpotSnapshot {
        JackpotSnapshot {
            lottery_id,
            ticket_count: vector::length(&runtime_ref.tickets),
            draw_scheduled: runtime_ref.draw_scheduled,
            has_pending_request: option::is_some(&runtime_ref.pending_request),
            pending_request_id: runtime_ref.pending_request,
        }
    }

    fun clear_tickets(tickets: &mut vector<address>) {
        let len = vector::length(tickets);
        clear_tickets_recursive(tickets, len)
    }

    fun clear_tickets_recursive(tickets: &mut vector<address>, remaining: u64) {
        if (remaining == 0) {
            return;
        };
        vector::pop_back(tickets);
        let next = remaining - 1;
        clear_tickets_recursive(tickets, next);
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        clone_into(&mut buffer, data, 0, len);
        buffer
    }

    fun clone_into(buffer: &mut vector<u8>, data: &vector<u8>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(data, index);
        vector::push_back(buffer, byte);
        let next_index = index + 1;
        clone_into(buffer, data, next_index, len);
    }

    fun collect_snapshots(
        jackpots: &table::Table<u64, JackpotRuntime>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<JackpotSnapshot> {
        if (index >= len) {
            return vector::empty<JackpotSnapshot>();
        };
        let lottery_id = *vector::borrow(lottery_ids, index);
        let runtime_ref = table::borrow(jackpots, lottery_id);
        let current_snapshot = build_snapshot(lottery_id, runtime_ref);
        let result = vector::empty<JackpotSnapshot>();
        vector::push_back(&mut result, current_snapshot);
        let tail = collect_snapshots(jackpots, lottery_ids, index + 1, len);
        append_snapshot_tail(&mut result, &tail, 0);
        result
    }

    fun collect_runtime_views(
        jackpots: &table::Table<u64, JackpotRuntime>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<JackpotRuntimeView> {
        if (index >= len) {
            return vector::empty<JackpotRuntimeView>();
        };
        let lottery_id = *vector::borrow(lottery_ids, index);
        let runtime_ref = table::borrow(jackpots, lottery_id);
        let current = build_runtime_view(lottery_id, runtime_ref);
        let buffer = vector::empty<JackpotRuntimeView>();
        vector::push_back(&mut buffer, current);
        let tail = collect_runtime_views(jackpots, lottery_ids, index + 1, len);
        append_runtime_tail(&mut buffer, &tail, 0);
        buffer
    }

    fun build_runtime_view(lottery_id: u64, runtime_ref: &JackpotRuntime): JackpotRuntimeView {
        JackpotRuntimeView {
            lottery_id,
            tickets: clone_addresses(&runtime_ref.tickets),
            draw_scheduled: runtime_ref.draw_scheduled,
            pending_request_id: runtime_ref.pending_request,
            pending_payload: clone_payload(&runtime_ref.pending_payload),
        }
    }

    fun clone_payload(payload: &option::Option<vector<u8>>): option::Option<vector<u8>> {
        if (!option::is_some(payload)) {
            return option::none<vector<u8>>();
        };
        let data = option::borrow(payload);
        option::some(clone_bytes(data))
    }

    fun clone_addresses(addresses: &vector<address>): vector<address> {
        let buffer = vector::empty<address>();
        let len = vector::length(addresses);
        clone_addresses_into(&mut buffer, addresses, 0, len);
        buffer
    }

    fun clone_addresses_into(
        buffer: &mut vector<address>,
        addresses: &vector<address>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let addr = *vector::borrow(addresses, index);
        vector::push_back(buffer, addr);
        let next_index = index + 1;
        clone_addresses_into(buffer, addresses, next_index, len);
    }

    fun append_snapshot_tail(
        head: &mut vector<JackpotSnapshot>,
        tail: &vector<JackpotSnapshot>,
        index: u64,
    ) {
        if (index >= vector::length(tail)) {
            return;
        };
        let item = *vector::borrow(tail, index);
        vector::push_back(head, item);
        append_snapshot_tail(head, tail, index + 1);
    }

    fun append_runtime_tail(
        head: &mut vector<JackpotRuntimeView>,
        tail: &vector<JackpotRuntimeView>,
        index: u64,
    ) {
        if (index >= vector::length(tail)) {
            return;
        };
        let item = *vector::borrow(tail, index);
        vector::push_back(head, item);
        append_runtime_tail(head, tail, index + 1);
    }

    fun clone_u64s(data: &vector<u64>): vector<u64> {
        let buffer = vector::empty<u64>();
        let len = vector::length(data);
        clone_u64s_into(&mut buffer, data, 0, len);
        buffer
    }

    fun clone_u64s_into(buffer: &mut vector<u64>, data: &vector<u64>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let value = *vector::borrow(data, index);
        vector::push_back(buffer, value);
        let next_index = index + 1;
        clone_u64s_into(buffer, data, next_index, len);
    }

    #[test_only]
    public fun test_force_pending_mismatch(lottery_id: u64) acquires JackpotRegistry {
        let registry = borrow_registry_mut(@lottery);
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.pending_request = option::some<u64>(999);
        runtime.pending_payload = option::none<vector<u8>>();
    }

    #[test_only]
    public fun test_restore_pending_state(lottery_id: u64) acquires JackpotRegistry {
        let registry = borrow_registry_mut(@lottery);
        let runtime = jackpot_mut(registry, lottery_id);
        runtime.pending_request = option::none<u64>();
        runtime.pending_payload = option::none<vector<u8>>();
    }
}
