module lottery::jackpot {
    use std::option;
    use std::signer;
    use std::vector;
    use std::bcs;
    use std::event;
    use std::math64;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
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
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
    }

    public entry fun init(caller: &signer, lottery_id: u64) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<JackpotState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            JackpotState {
                admin: addr,
                lottery_id,
                tickets: vector::empty<address>(),
                draw_scheduled: false,
                pending_request: option::none<u64>(),
                ticket_events: event::new_event_handle<JackpotTicketGrantedEvent>(caller),
                schedule_events: event::new_event_handle<JackpotScheduleUpdatedEvent>(caller),
                request_events: event::new_event_handle<JackpotRequestIssuedEvent>(caller),
                fulfill_events: event::new_event_handle<JackpotFulfilledEvent>(caller),
            },
        );
    }

    #[view]
    public fun is_initialized(): bool {
        exists<JackpotState>(@lottery)
    }

    #[view]
    public fun admin(): address acquires JackpotState {
        borrow_state().admin
    }

    #[view]
    public fun lottery_id(): u64 acquires JackpotState {
        borrow_state().lottery_id
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        state.admin = new_admin;
    }

    public entry fun grant_ticket(caller: &signer, player: address) acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        grant_ticket_internal(state, player);
    }

    public entry fun grant_tickets_batch(caller: &signer, players: vector<address>) acquires JackpotState {
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
        let state = borrow_state_mut();
        if (vector::length(&state.tickets) == 0) {
            abort E_NO_TICKETS;
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING;
        };
        state.draw_scheduled = true;
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
        );
    }

    public entry fun reset(caller: &signer) acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        clear_tickets(&mut state.tickets);
        state.draw_scheduled = false;
        state.pending_request = option::none<u64>();
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.schedule_events,
            JackpotScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
        );
    }

    public entry fun request_randomness(caller: &signer, payload: vector<u8>)
    acquires JackpotState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        if (!state.draw_scheduled) {
            abort E_DRAW_NOT_SCHEDULED;
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING;
        };
        if (vector::length(&state.tickets) == 0) {
            abort E_NO_TICKETS;
        };
        let lottery_id = state.lottery_id;
        let request_id = hub::request_randomness(lottery_id, payload);
        state.pending_request = option::some(request_id);
        event::emit_event(
            &mut state.request_events,
            JackpotRequestIssuedEvent { lottery_id, request_id },
        );
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires JackpotState {
        hub::ensure_callback_sender(caller);
        let (recorded_lottery, payload) = hub::consume_request(request_id);

        let state = borrow_state_mut();
        if (recorded_lottery != state.lottery_id) {
            abort E_LOTTERY_MISMATCH;
        };
        if (!option::is_some(&state.pending_request)) {
            abort E_NO_PENDING_REQUEST;
        };
        let expected_id = *option::borrow(&state.pending_request);
        if (expected_id != request_id) {
            abort E_REQUEST_MISMATCH;
        };

        let ticket_count = vector::length(&state.tickets);
        if (ticket_count == 0) {
            abort E_NO_TICKETS;
        };

        let random_value = randomness_to_u64(&randomness);
        let winner_index = math64::mod(random_value, ticket_count);
        let winner = *vector::borrow(&state.tickets, winner_index);

        let jackpot_amount = treasury_multi::jackpot_balance();
        if (jackpot_amount == 0) {
            abort E_EMPTY_JACKPOT;
        };
        if (!treasury_v1::store_registered(winner)) {
            abort E_WINNER_STORE_NOT_REGISTERED;
        };

        treasury_multi::distribute_jackpot_internal(winner, jackpot_amount);

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
    }

    #[view]
    public fun get_snapshot(): option::Option<JackpotSnapshot> acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            return option::none<JackpotSnapshot>();
        };
        let state = borrow_state();
        option::some(JackpotSnapshot {
            ticket_count: vector::length(&state.tickets),
            draw_scheduled: state.draw_scheduled,
            has_pending_request: option::is_some(&state.pending_request),
        })
    }

    #[view]
    /// test-view: возвращает (ticket_count, draw_scheduled, has_pending_request)
    public fun get_snapshot_view(): option::Option<(u64, bool, bool)> acquires JackpotState {
        let snapshot_opt = get_snapshot();
        if (option::is_some(&snapshot_opt)) {
            let snapshot_ref = option::borrow(&snapshot_opt);
            option::some((
                snapshot_ref.ticket_count,
                snapshot_ref.draw_scheduled,
                snapshot_ref.has_pending_request,
            ))
        } else {
            option::none<(u64, bool, bool)>()
        }
    }

    #[view]
    public fun pending_request(): option::Option<u64> acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            return option::none<u64>();
        };
        let state = borrow_state();
        if (option::is_some(&state.pending_request)) {
            option::some(*option::borrow(&state.pending_request))
        } else {
            option::none<u64>()
        }
    }

    fun borrow_state(): &JackpotState acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<JackpotState>(@lottery)
    }

    fun borrow_state_mut(): &mut JackpotState acquires JackpotState {
        if (!exists<JackpotState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<JackpotState>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires JackpotState {
        if (signer::address_of(caller) != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun grant_ticket_internal(state: &mut JackpotState, player: address) {
        if (state.draw_scheduled) {
            abort E_DRAW_ALREADY_SCHEDULED;
        };
        if (option::is_some(&state.pending_request)) {
            abort E_REQUEST_PENDING;
        };
        let ticket_index = vector::length(&state.tickets);
        vector::push_back(&mut state.tickets, player);
        let lottery_id = state.lottery_id;
        event::emit_event(
            &mut state.ticket_events,
            JackpotTicketGrantedEvent { lottery_id, player, ticket_index },
        );
    }

    fun clear_tickets(tickets: &mut vector<address>) {
        while (vector::length(tickets) > 0) {
            vector::pop_back(tickets);
        };
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        if (vector::length(randomness) < 8) {
            abort E_RANDOM_BYTES_TOO_SHORT;
        };
        let prefix = vector::empty<u8>();
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(randomness, i);
            vector::push_back(&mut prefix, byte);
            i = i + 1;
        };
        bcs::from_bytes<u64>(prefix)
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
}
