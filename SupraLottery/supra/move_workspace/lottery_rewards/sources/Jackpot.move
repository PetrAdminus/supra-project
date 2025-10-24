module lottery_rewards::jackpot {
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use lottery_core::treasury_v1;
    use std::option;
    use std::signer;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::hub;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_DRAW_ALREADY_SCHEDULED: u64 = 4;
    const E_REQUEST_PENDING: u64 = 5;
    const E_NO_TICKETS: u64 = 6;
    const E_DRAW_NOT_SCHEDULED: u64 = 7;
    const E_NO_PENDING_REQUEST: u64 = 8;
    const E_REQUEST_MISMATCH: u64 = 9;
    const E_RANDOM_BYTES_TOO_SHORT: u64 = 10;
    const E_EMPTY_JACKPOT: u64 = 11;
    const E_WINNER_STORE_NOT_REGISTERED: u64 = 12;
    const E_LOTTERY_MISMATCH: u64 = 13;

    struct JackpotState has key {
        admin: address,
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        pending_request: option::Option<u64>,
        ticket_events: event::EventHandle<JackpotTicketGrantedEvent>,
        schedule_events: event::EventHandle<JackpotScheduleUpdatedEvent>,
        request_events: event::EventHandle<JackpotRequestIssuedEvent>,
        fulfill_events: event::EventHandle<JackpotFulfilledEvent>,
        snapshot_events: event::EventHandle<JackpotSnapshotUpdatedEvent>,
    }

    struct JackpotAccess has key { cap: MultiTreasuryCap }

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
    }

    #[event]
    struct JackpotFulfilledEvent has drop, store, copy {
        request_id: u64,
        lottery_id: u64,
        winner: address,
        ticket_index: u64,
        random_bytes: vector<u8>,
        prize_amount: u64,
        payload: vector<u8>,
    }

    struct JackpotSnapshot has copy, drop, store {
        admin: address,
        lottery_id: u64,
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
        pending_request_id: option::Option<u64>,
    }

    #[event]
    struct JackpotSnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<JackpotSnapshot>,
        current: JackpotSnapshot,
    }

    public entry fun init(caller: &signer, lottery_id: u64)
    acquires JackpotState {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<JackpotState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            JackpotState {
                admin: addr,
                lottery_id,
                tickets: vector::empty<address>(),
                draw_scheduled: false,
                pending_request: option::none<u64>(),
                ticket_events: account::new_event_handle<JackpotTicketGrantedEvent>(caller),
                schedule_events: account::new_event_handle<JackpotScheduleUpdatedEvent>(caller),
                request_events: account::new_event_handle<JackpotRequestIssuedEvent>(caller),
                fulfill_events: account::new_event_handle<JackpotFulfilledEvent>(caller),
                snapshot_events: account::new_event_handle<JackpotSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<JackpotState>(@lottery);
        emit_snapshot_event(state, option::none<JackpotSnapshot>());
        if (!exists<JackpotAccess>(@lottery)) {
            ensure_caps_initialized(caller);
        };
    }

    #[view]
    public fun is_initialized(): bool {
        exists<JackpotState>(@lottery)
    }

    #[view]
    public fun admin(): address acquires JackpotState {
        ensure_jackpot_initialized();
        let state = borrow_global<JackpotState>(@lottery);
        state.admin
    }

    #[view]
    public fun lottery_id(): u64 acquires JackpotState {
        ensure_jackpot_initialized();
        let state = borrow_global<JackpotState>(@lottery);
        state.lottery_id
    }

    public entry fun set_admin(caller: &signer, new_admin: address)
    acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_global_mut<JackpotState>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        state.admin = new_admin;
        emit_snapshot_event(state, previous);
    }

    public entry fun grant_ticket(caller: &signer, player: address)
    acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_global_mut<JackpotState>(@lottery);
        grant_ticket_internal(state, player);
    }

    public entry fun grant_tickets_batch(caller: &signer, players: vector<address>)
    acquires JackpotState {
        ensure_admin(caller);
        let len = vector::length(&players);
        let i = 0;
        while (i < len) {
            let player = *vector::borrow(&players, i);
            grant_ticket(caller, player);
            i = i + 1;
        };
    }

    public entry fun schedule_draw(caller: &signer) acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_global_mut<JackpotState>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        if (vector::length(&state.tickets) == 0) {
            abort E_NO_TICKETS
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING
        };
        state.draw_scheduled = true;
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
        );
        emit_snapshot_event(state, previous);
    }

    public entry fun reset(caller: &signer) acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_global_mut<JackpotState>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        clear_tickets(&mut state.tickets);
        state.draw_scheduled = false;
        state.pending_request = option::none<u64>();
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
        );
        emit_snapshot_event(state, previous);
    }

    public entry fun request_randomness(caller: &signer, payload: vector<u8>)
    acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_global_mut<JackpotState>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        if (!state.draw_scheduled) {
            abort E_DRAW_NOT_SCHEDULED
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING
        };
        if (vector::length(&state.tickets) == 0) {
            abort E_NO_TICKETS
        };
        let lottery_id = state.lottery_id;
        let request_id = hub::request_randomness(lottery_id, payload);
        state.pending_request = option::some(request_id);
        event::emit_event(
            &mut state.request_events,
            JackpotRequestIssuedEvent { lottery_id, request_id },
        );
        emit_snapshot_event(state, previous);
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires JackpotAccess, JackpotState {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let recorded_lottery = hub::request_record_lottery_id(&record);
        let payload = hub::request_record_payload(&record);

        let state = borrow_global_mut<JackpotState>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        if (recorded_lottery != state.lottery_id) {
            abort E_LOTTERY_MISMATCH
        };
        if (!option::is_some(&state.pending_request)) {
            abort E_NO_PENDING_REQUEST
        };
        let expected_id = *option::borrow(&state.pending_request);
        if (expected_id != request_id) {
            abort E_REQUEST_MISMATCH
        };

        let ticket_count = vector::length(&state.tickets);
        if (ticket_count == 0) {
            abort E_NO_TICKETS
        };

        let random_value = randomness_to_u64(&randomness);
        let winner_index = random_value % ticket_count;
        let winner = *vector::borrow(&state.tickets, winner_index);

        let jackpot_amount = treasury_multi::jackpot_balance();
        if (jackpot_amount == 0) {
            abort E_EMPTY_JACKPOT
        };
        if (!treasury_v1::store_registered(winner)) {
            abort E_WINNER_STORE_NOT_REGISTERED
        };

        let cap = {
            ensure_caps_ready();
            let access = borrow_global<JackpotAccess>(@lottery);
            &access.cap
        };
        treasury_multi::distribute_jackpot_with_cap(cap, winner, jackpot_amount);

        state.draw_scheduled = false;
        state.pending_request = option::none<u64>();
        clear_tickets(&mut state.tickets);

        let randomness_for_hub = clone_bytes(&randomness);
        let lottery_id = state.lottery_id;
        hub::record_fulfillment(request_id, lottery_id, randomness_for_hub);
        event::emit_event(
            &mut state.fulfill_events,
            JackpotFulfilledEvent {
                request_id,
                lottery_id,
                winner,
                ticket_index: winner_index,
                random_bytes: randomness,
                prize_amount: jackpot_amount,
                payload,
            },
        );
        emit_snapshot_event(state, previous);
    }

    #[view]
    public fun get_snapshot(): option::Option<JackpotSnapshot>
    acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            return option::none<JackpotSnapshot>()
        };
        let state = borrow_global<JackpotState>(@lottery);
        option::some(build_snapshot(state))
    }

    #[view]
    public fun pending_request(): option::Option<u64> acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            return option::none<u64>()
        };
        let state = borrow_global<JackpotState>(@lottery);
        copy_option_u64(&state.pending_request)
    }

    public fun ensure_caps_initialized(admin: &signer) {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<JackpotAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_jackpot(),
        );
        move_to(admin, JackpotAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires JackpotAccess {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<JackpotAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let JackpotAccess { cap } = move_from<JackpotAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<JackpotAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_jackpot()
    }

    fun ensure_admin(caller: &signer) acquires JackpotState {
        ensure_jackpot_initialized();
        let state = borrow_global<JackpotState>(@lottery);
        if (signer::address_of(caller) != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_jackpot_initialized() {
        if (!exists<JackpotState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun grant_ticket_internal(state: &mut JackpotState, player: address) {
        let previous = option::some(build_snapshot_from_mut(state));
        if (state.draw_scheduled) {
            abort E_DRAW_ALREADY_SCHEDULED
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING
        };
        let ticket_index = vector::length(&state.tickets);
        vector::push_back(&mut state.tickets, player);
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.ticket_events,
            JackpotTicketGrantedEvent { lottery_id, player, ticket_index },
        );
        emit_snapshot_event(state, previous);
    }

    fun clear_tickets(tickets: &mut vector<address>) {
        while (vector::length(tickets) > 0) {
            vector::pop_back(tickets);
        };
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        if (vector::length(randomness) < 8) {
            abort E_RANDOM_BYTES_TOO_SHORT
        };
        let result = 0u64;
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(randomness, i);
            let result_mul = result * 256;
            let byte_u64 = u8_to_u64(byte);
            result = result_mul + byte_u64;
            i = i + 1;
        };
        result
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        let i = 0;
        while (i < len) {
            let byte = *vector::borrow(data, i);
            vector::push_back(&mut buffer, byte);
            i = i + 1;
        };
        buffer
    }

    fun u8_to_u64(value: u8): u64 {
        let result = 0u64;
        let remaining = value;
        while (remaining > 0) {
            result = result + 1;
            remaining = remaining - 1;
        };
        result
    }

    fun ensure_caps_ready() {
        if (!exists<JackpotAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    #[test_only]
    public fun jackpot_snapshot_fields_for_test(
        snapshot: &JackpotSnapshot
    ): (
        address,
        u64,
        u64,
        bool,
        bool,
        option::Option<u64>,
    ) {
        (
            snapshot.admin,
            snapshot.lottery_id,
            snapshot.ticket_count,
            snapshot.draw_scheduled,
            snapshot.has_pending_request,
            snapshot.pending_request_id,
        )
    }

    #[test_only]
    public fun jackpot_snapshot_event_fields_for_test(
        event: &JackpotSnapshotUpdatedEvent
    ): (option::Option<JackpotSnapshot>, JackpotSnapshot) {
        (event.previous, event.current)
    }

    fun emit_snapshot_event(
        state: &mut JackpotState,
        previous: option::Option<JackpotSnapshot>,
    ) {
        let snapshot = build_snapshot_from_mut(state);
        event::emit_event(
            &mut state.snapshot_events,
            JackpotSnapshotUpdatedEvent { previous, current: snapshot },
        );
    }

    fun build_snapshot_from_mut(state: &mut JackpotState): JackpotSnapshot {
        build_snapshot_internal(
            state.admin,
            state.lottery_id,
            &state.tickets,
            state.draw_scheduled,
            &state.pending_request,
        )
    }

    fun build_snapshot(state: &JackpotState): JackpotSnapshot {
        build_snapshot_internal(
            state.admin,
            state.lottery_id,
            &state.tickets,
            state.draw_scheduled,
            &state.pending_request,
        )
    }

    fun build_snapshot_internal(
        admin: address,
        lottery_id: u64,
        tickets: &vector<address>,
        draw_scheduled: bool,
        pending_request: &option::Option<u64>,
    ): JackpotSnapshot {
        let pending_request_id = copy_option_u64(pending_request);
        JackpotSnapshot {
            admin,
            lottery_id,
            ticket_count: vector::length(tickets),
            draw_scheduled,
            has_pending_request: option::is_some(pending_request),
            pending_request_id,
        }
    }

    fun copy_option_u64(value: &option::Option<u64>): option::Option<u64> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<u64>()
        }
    }
}
