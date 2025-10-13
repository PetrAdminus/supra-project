module lottery::rounds {
    friend lottery::autopurchase;
    friend lottery::migration;

    use std::borrow;
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
    use lottery::history;
    use lottery::instances;
    use lottery::treasury_multi;
    use lottery::referrals;
    use lottery::treasury_v1;
    use lottery::vip;
    use lottery_factory::registry;
    use vrf_hub::hub;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INSTANCE_MISSING: u64 = 4;
    const E_DRAW_ALREADY_SCHEDULED: u64 = 5;
    const E_REQUEST_PENDING: u64 = 6;
    const E_NO_TICKETS: u64 = 7;
    const E_DRAW_NOT_SCHEDULED: u64 = 8;
    const E_NO_PENDING_REQUEST: u64 = 9;
    const E_RANDOM_BYTES_TOO_SHORT: u64 = 10;
    const E_REQUEST_MISMATCH: u64 = 11;
    const E_INSTANCE_INACTIVE: u64 = 12;
    const E_INVALID_TICKET_COUNT: u64 = 13;
    const E_ARITHMETIC_OVERFLOW: u64 = 14;

    struct RoundState has store {
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    }

    struct RoundCollection has key {
        admin: address,
        rounds: table::Table<u64, RoundState>,
        lottery_ids: vector<u64>,
        ticket_events: event::EventHandle<TicketPurchasedEvent>,
        schedule_events: event::EventHandle<DrawScheduleUpdatedEvent>,
        reset_events: event::EventHandle<RoundResetEvent>,
        request_events: event::EventHandle<DrawRequestIssuedEvent>,
        fulfill_events: event::EventHandle<DrawFulfilledEvent>,
        snapshot_events: event::EventHandle<RoundSnapshotUpdatedEvent>,
    }

    #[event]
    struct TicketPurchasedEvent has drop, store, copy {
        lottery_id: u64,
        ticket_id: u64,
        buyer: address,
        amount: u64,
    }

    #[event]
    struct DrawScheduleUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        draw_scheduled: bool,
    }

    #[event]
    struct RoundResetEvent has drop, store, copy {
        lottery_id: u64,
        tickets_cleared: u64,
    }

    #[event]
    struct DrawRequestIssuedEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
    }

    #[event]
    struct DrawFulfilledEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        random_bytes: vector<u8>,
        prize_amount: u64,
        payload: vector<u8>,
    }

    struct RoundSnapshot has copy, drop, store {
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
        next_ticket_id: u64,
        pending_request_id: option::Option<u64>,
    }

    #[event]
    struct RoundSnapshotUpdatedEvent has copy, drop, store {
        lottery_id: u64,
        snapshot: RoundSnapshot,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<RoundCollection>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            RoundCollection {
                admin: addr,
                rounds: table::new(),
                lottery_ids: vector::empty<u64>(),
                ticket_events: account::new_event_handle<TicketPurchasedEvent>(caller),
                schedule_events: account::new_event_handle<DrawScheduleUpdatedEvent>(caller),
                reset_events: account::new_event_handle<RoundResetEvent>(caller),
                request_events: account::new_event_handle<DrawRequestIssuedEvent>(caller),
                fulfill_events: account::new_event_handle<DrawFulfilledEvent>(caller),
                snapshot_events: account::new_event_handle<RoundSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<RoundCollection>(@lottery);
        emit_all_snapshots(state);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<RoundCollection>(@lottery)
    }

    #[view]
    public fun admin(): address acquires RoundCollection {
        let state = borrow_global<RoundCollection>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        state.admin = new_admin;
    }

    public entry fun buy_ticket(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        let buyer = signer::address_of(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let blueprint = prepare_purchase(state, lottery_id);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);

        treasury_v1::deposit_from_user(caller, ticket_price);
        let _ = complete_purchase(state, lottery_id, buyer, ticket_price, jackpot_share_bps, 1);
    }

    public(friend) fun record_prepaid_purchase(
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
    ): u64 acquires RoundCollection {
        if (ticket_count == 0) {
            abort E_INVALID_TICKET_COUNT
        };
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let blueprint = prepare_purchase(state, lottery_id);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);
        complete_purchase(state, lottery_id, buyer, ticket_price, jackpot_share_bps, ticket_count)
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let snapshot = {
            let round = ensure_round(state, lottery_id);
            if (vector::length(&round.tickets) == 0) {
                abort E_NO_TICKETS
            };
            if (!instances::is_instance_active(lottery_id)) {
                abort E_INSTANCE_INACTIVE
            };
            if (option::is_some(&round.pending_request)) {
                abort E_REQUEST_PENDING
            };
            round.draw_scheduled = true;
            event::emit_event(
                &mut state.schedule_events,
                DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
            );
            snapshot_from_round(borrow::freeze(round))
        };
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    public entry fun reset_round(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let snapshot = {
            let round = ensure_round(state, lottery_id);
            let cleared = vector::length(&round.tickets);
            clear_tickets(&mut round.tickets);
            round.draw_scheduled = false;
            round.next_ticket_id = 0;
            round.pending_request = option::none<u64>();
            event::emit_event(
                &mut state.schedule_events,
                DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
            );
            event::emit_event(&mut state.reset_events, RoundResetEvent { lottery_id, tickets_cleared: cleared });
            snapshot_from_round(borrow::freeze(round))
        };
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
    ) acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let (request_id, snapshot) = {
            let round = ensure_round(state, lottery_id);
            if (!round.draw_scheduled) {
                abort E_DRAW_NOT_SCHEDULED
            };
            if (!instances::is_instance_active(lottery_id)) {
                abort E_INSTANCE_INACTIVE
            };
            if (option::is_some(&round.pending_request)) {
                abort E_REQUEST_PENDING
            };
            if (vector::length(&round.tickets) == 0) {
                abort E_NO_TICKETS
            };

            let request_id_inner = hub::request_randomness(lottery_id, payload);
            round.pending_request = option::some(request_id_inner);
            event::emit_event(
                &mut state.request_events,
                DrawRequestIssuedEvent { lottery_id, request_id: request_id_inner },
            );
            (request_id_inner, snapshot_from_round(borrow::freeze(round)))
        };
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires RoundCollection {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let lottery_id = hub::request_record_lottery_id(&record);
        let payload = hub::request_record_payload(&record);

        let state = borrow_global_mut<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            abort E_NO_PENDING_REQUEST
        };
        let (winner, winner_index, snapshot) = {
            let round = table::borrow_mut(&mut state.rounds, lottery_id);
            if (!option::is_some(&round.pending_request)) {
                abort E_NO_PENDING_REQUEST
            };
            let expected_id = *option::borrow(&round.pending_request);
            if (expected_id != request_id) {
                abort E_REQUEST_MISMATCH
            };
            let ticket_count = vector::length(&round.tickets);
            if (ticket_count == 0) {
                abort E_NO_TICKETS
            };
            let random_value = randomness_to_u64(&randomness);
            let winner_index_inner = random_value % ticket_count;
            let winner_addr = *vector::borrow(&round.tickets, winner_index_inner);
            round.draw_scheduled = false;
            round.next_ticket_id = 0;
            round.pending_request = option::none<u64>();
            clear_tickets(&mut round.tickets);
            (winner_addr, winner_index_inner, snapshot_from_round(borrow::freeze(round)))
        };
        emit_snapshot_event(state, lottery_id, snapshot);

        let prize_amount = treasury_multi::distribute_prize_internal(lottery_id, winner);
        let randomness_for_hub = clone_bytes(&randomness);
        hub::record_fulfillment(request_id, lottery_id, randomness_for_hub);
        let random_for_event = copy randomness;
        let payload_for_event = copy payload;
        event::emit_event(
            &mut state.fulfill_events,
            DrawFulfilledEvent {
                lottery_id,
                request_id,
                winner,
                ticket_index: winner_index,
                random_bytes: random_for_event,
                prize_amount,
                payload: payload_for_event,
            },
        );
        history::record_draw(
            lottery_id,
            request_id,
            winner,
            winner_index,
            prize_amount,
            randomness,
            payload,
        );
    }

    #[view]
    public fun get_round_snapshot(lottery_id: u64): option::Option<RoundSnapshot> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return option::none<RoundSnapshot>()
        };
        let state = borrow_global<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<RoundSnapshot>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            option::some(snapshot_from_round(round))
        }
    }

    #[view]
    public fun pending_request_id(lottery_id: u64): option::Option<u64> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return option::none<u64>()
        };
        let state = borrow_global<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<u64>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            copy_option_u64(&round.pending_request)
        }
    }

    fun prepare_purchase(
        state: &mut RoundCollection,
        lottery_id: u64,
    ): registry::LotteryBlueprint {
        let info_opt = instances::get_lottery_info(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_INSTANCE_MISSING
        };
        let info_ref = option::borrow(&info_opt);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        if (!instances::is_instance_active(lottery_id)) {
            abort E_INSTANCE_INACTIVE
        };
        {
            let round = ensure_round(state, lottery_id);
            ensure_round_available(round);
        };
        blueprint
    }

    fun ensure_round_available(round: &RoundState) {
        if (round.draw_scheduled) {
            abort E_DRAW_ALREADY_SCHEDULED
        };
        if (option::is_some(&round.pending_request)) {
            abort E_REQUEST_PENDING
        };
    }

    fun complete_purchase(
        state: &mut RoundCollection,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        ticket_count: u64,
    ): u64 {
        let jackpot_bps = jackpot_share_bps as u64;
        let jackpot_contribution = mul_div(ticket_price, jackpot_bps, BASIS_POINT_DENOMINATOR);
        let issued = 0;
        let total_amount = 0;
        while (issued < ticket_count) {
            let ticket_id = {
                let round = ensure_round(state, lottery_id);
                let ticket_id_inner = round.next_ticket_id;
                round.next_ticket_id = safe_add(ticket_id_inner, 1);
                vector::push_back(&mut round.tickets, buyer);
                ticket_id_inner
            };
            instances::record_ticket_sale(lottery_id, jackpot_contribution);
            event::emit_event(
                &mut state.ticket_events,
                TicketPurchasedEvent { lottery_id, ticket_id, buyer, amount: ticket_price },
            );
            total_amount = safe_add(total_amount, ticket_price);
            issued = issued + 1;
        };
        let bonus_tickets = vip::bonus_tickets_for(lottery_id, buyer);
        if (bonus_tickets > 0) {
            let bonus_issued = 0;
            while (bonus_issued < bonus_tickets) {
                let ticket_id = {
                    let round = ensure_round(state, lottery_id);
                    let ticket_id_inner = round.next_ticket_id;
                    round.next_ticket_id = safe_add(ticket_id_inner, 1);
                    vector::push_back(&mut round.tickets, buyer);
                    ticket_id_inner
                };
                instances::record_ticket_sale(lottery_id, 0);
                event::emit_event(
                    &mut state.ticket_events,
                    TicketPurchasedEvent { lottery_id, ticket_id, buyer, amount: 0 },
                );
                bonus_issued = bonus_issued + 1;
            };
            vip::record_bonus_usage(lottery_id, buyer, bonus_tickets);
        };
        treasury_multi::record_allocation_internal(lottery_id, total_amount);
        referrals::record_purchase(lottery_id, buyer, total_amount);
        let snapshot = {
            let round = ensure_round(state, lottery_id);
            snapshot_from_round(borrow::freeze(round))
        };
        emit_snapshot_event(state, lottery_id, snapshot);
        total_amount
    }

    fun ensure_round(state: &mut RoundCollection, lottery_id: u64): &mut RoundState {
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };
        if (!table::contains(&state.rounds, lottery_id)) {
            record_lottery_id(&mut state.lottery_ids, lottery_id);
            table::add(
                &mut state.rounds,
                lottery_id,
                RoundState {
                    tickets: vector::empty<address>(),
                    draw_scheduled: false,
                    next_ticket_id: 0,
                    pending_request: option::none<u64>(),
                },
            );
        };
        table::borrow_mut(&mut state.rounds, lottery_id)
    }

    fun ensure_admin(caller: &signer) acquires RoundCollection {
        let addr = signer::address_of(caller);
        if (!exists<RoundCollection>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<RoundCollection>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        }
    }

    fun clear_tickets(tickets: &mut vector<address>) {
        while (vector::length(tickets) > 0) {
            vector::pop_back(tickets);
        };
    }


    public(friend) fun migrate_import_round(
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    ) acquires RoundCollection {
        let state = borrow_global_mut<RoundCollection>(@lottery);
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };
        if (table::contains(&state.rounds, lottery_id)) {
            let snapshot = {
                let round = table::borrow_mut(&mut state.rounds, lottery_id);
                round.tickets = tickets;
                round.draw_scheduled = draw_scheduled;
                round.next_ticket_id = next_ticket_id;
                round.pending_request = pending_request;
                snapshot_from_round(borrow::freeze(round))
            };
            emit_snapshot_event(state, lottery_id, snapshot);
            return
        };
        record_lottery_id(&mut state.lottery_ids, lottery_id);
        table::add(
            &mut state.rounds,
            lottery_id,
            RoundState { tickets, draw_scheduled, next_ticket_id, pending_request },
        );
        let snapshot = {
            let round = table::borrow(&state.rounds, lottery_id);
            snapshot_from_round(round)
        };
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        if (vector::length(randomness) < 8) {
            abort E_RANDOM_BYTES_TOO_SHORT
        };
        let result = 0u64;
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(randomness, i);
            let result_mul = safe_mul(result, 256);
            let byte_u64 = u8_to_u64(byte);
            result = safe_add(result_mul, byte_u64);
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

    #[test_only]
    public fun round_snapshot_fields_for_test(
        snapshot: &RoundSnapshot
    ): (u64, bool, bool, u64, option::Option<u64>) {
        (
            snapshot.ticket_count,
            snapshot.draw_scheduled,
            snapshot.has_pending_request,
            snapshot.next_ticket_id,
            copy_option_u64(&snapshot.pending_request_id),
        )
    }

    #[test_only]
    public fun round_snapshot_event_fields_for_test(
        event: &RoundSnapshotUpdatedEvent
    ): (u64, RoundSnapshot) {
        (event.lottery_id, event.snapshot)
    }

    fun mul_div(amount: u64, basis_points: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_INVALID_TICKET_COUNT);
        if (amount == 0 || basis_points == 0) {
            return 0
        };

        let quotient = amount / denominator;
        let remainder = amount % denominator;
        let scaled_quotient = safe_mul(quotient, basis_points);
        let scaled_remainder = safe_mul(remainder, basis_points) / denominator;
        safe_add(scaled_quotient, scaled_remainder)
    }

    fun safe_add(lhs: u64, rhs: u64): u64 {
        let sum = lhs + rhs;
        assert!(sum >= lhs, E_ARITHMETIC_OVERFLOW);
        sum
    }

    fun safe_mul(lhs: u64, rhs: u64): u64 {
        if (lhs == 0 || rhs == 0) {
            return 0
        };

        let product = lhs * rhs;
        assert!(product / lhs == rhs, E_ARITHMETIC_OVERFLOW);
        product
    }

    fun snapshot_from_round(round: &RoundState): RoundSnapshot {
        RoundSnapshot {
            ticket_count: vector::length(&round.tickets),
            draw_scheduled: round.draw_scheduled,
            has_pending_request: option::is_some(&round.pending_request),
            next_ticket_id: round.next_ticket_id,
            pending_request_id: copy_option_u64(&round.pending_request),
        }
    }

    fun emit_all_snapshots(state: &mut RoundCollection) {
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.rounds, lottery_id)) {
                let snapshot = {
                    let round = table::borrow(&state.rounds, lottery_id);
                    snapshot_from_round(round)
                };
                emit_snapshot_event(state, lottery_id, snapshot);
            };
            idx = idx + 1;
        };
    }

    fun emit_snapshot_event(
        state: &mut RoundCollection,
        lottery_id: u64,
        snapshot: RoundSnapshot,
    ) {
        event::emit_event(
            &mut state.snapshot_events,
            RoundSnapshotUpdatedEvent { lottery_id, snapshot },
        );
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

    fun copy_option_u64(value: &option::Option<u64>): option::Option<u64> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<u64>()
        }
    }
}
