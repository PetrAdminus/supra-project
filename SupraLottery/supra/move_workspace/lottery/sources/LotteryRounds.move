module lottery::rounds {
    friend lottery::migration;
    friend lottery::autopurchase;
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;
    use std::bcs;
    use std::math64;
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

    struct RoundState has store {
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    }

    struct RoundCollection has key {
        admin: address,
        rounds: table::Table<u64, RoundState>,
        ticket_events: event::EventHandle<TicketPurchasedEvent>,
        schedule_events: event::EventHandle<DrawScheduleUpdatedEvent>,
        reset_events: event::EventHandle<RoundResetEvent>,
        request_events: event::EventHandle<DrawRequestIssuedEvent>,
        fulfill_events: event::EventHandle<DrawFulfilledEvent>,
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
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<RoundCollection>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            RoundCollection {
                admin: addr,
                rounds: table::new(),
                ticket_events: event::new_event_handle<TicketPurchasedEvent>(caller),
                schedule_events: event::new_event_handle<DrawScheduleUpdatedEvent>(caller),
                reset_events: event::new_event_handle<RoundResetEvent>(caller),
                request_events: event::new_event_handle<DrawRequestIssuedEvent>(caller),
                fulfill_events: event::new_event_handle<DrawFulfilledEvent>(caller),
            },
        );
    }

    #[view]
    public fun is_initialized(): bool {
        exists<RoundCollection>(@lottery)
    }

    #[view]
    public fun admin(): address acquires RoundCollection {
        borrow_state().admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_state_mut();
        state.admin = new_admin;
    }

    public entry fun buy_ticket(caller: &signer, lottery_id: u64)
    acquires RoundCollection, instances::LotteryCollection {
        let buyer = signer::address_of(caller);
        let state = borrow_state_mut();
        let (round, blueprint) = prepare_purchase(state, lottery_id);
        let ticket_price = blueprint.ticket_price;
        let jackpot_share_bps = blueprint.jackpot_share_bps;

        treasury_v1::deposit_from_user(caller, ticket_price);
        let _ = complete_purchase(state, round, lottery_id, buyer, ticket_price, jackpot_share_bps, 1);
    }

    public(friend) fun record_prepaid_purchase(
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
    ): u64 acquires RoundCollection, instances::LotteryCollection {
        if (ticket_count == 0) {
            abort E_INVALID_TICKET_COUNT;
        };
        let state = borrow_state_mut();
        let (round, blueprint) = prepare_purchase(state, lottery_id);
        let ticket_price = blueprint.ticket_price;
        let jackpot_share_bps = blueprint.jackpot_share_bps;
        complete_purchase(state, round, lottery_id, buyer, ticket_price, jackpot_share_bps, ticket_count)
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires RoundCollection, instances::LotteryCollection {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let round = ensure_round(state, lottery_id);
        if (vector::length(&round.tickets) == 0) {
            abort E_NO_TICKETS;
        };
        if (!instances::is_instance_active(lottery_id)) {
            abort E_INSTANCE_INACTIVE;
        };
        if (option::is_some(&round.pending_request)) {
            abort E_REQUEST_PENDING;
        };
        round.draw_scheduled = true;
        event::emit_event(&mut state.schedule_events, DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: true });
    }

    public entry fun reset_round(caller: &signer, lottery_id: u64)
    acquires RoundCollection, instances::LotteryCollection {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let round = ensure_round(state, lottery_id);
        let cleared = vector::length(&round.tickets);
        clear_tickets(&mut round.tickets);
        round.draw_scheduled = false;
        round.next_ticket_id = 0;
        round.pending_request = option::none<u64>();
        event::emit_event(&mut state.schedule_events, DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false });
        event::emit_event(&mut state.reset_events, RoundResetEvent { lottery_id, tickets_cleared: cleared });
    }

    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
    ) acquires RoundCollection, instances::LotteryCollection, hub::HubState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let round = ensure_round(state, lottery_id);
        if (!round.draw_scheduled) {
            abort E_DRAW_NOT_SCHEDULED;
        };
        if (!instances::is_instance_active(lottery_id)) {
            abort E_INSTANCE_INACTIVE;
        };
        if (option::is_some(&round.pending_request)) {
            abort E_REQUEST_PENDING;
        };
        if (vector::length(&round.tickets) == 0) {
            abort E_NO_TICKETS;
        };

        let request_id = hub::request_randomness(lottery_id, payload);
        round.pending_request = option::some(request_id);
        event::emit_event(&mut state.request_events, DrawRequestIssuedEvent { lottery_id, request_id });
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires RoundCollection, instances::LotteryCollection, hub::HubState {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let record_data = record;
        let lottery_id = record_data.lottery_id;
        let payload = record_data.payload;

        let state = borrow_state_mut();
        if (!table::contains(&state.rounds, lottery_id)) {
            abort E_NO_PENDING_REQUEST;
        };
        let mut round = table::borrow_mut(&mut state.rounds, lottery_id);
        if (!option::is_some(&round.pending_request)) {
            abort E_NO_PENDING_REQUEST;
        };
        let expected_id = *option::borrow(&round.pending_request);
        if (expected_id != request_id) {
            abort E_REQUEST_MISMATCH;
        };

        let ticket_count = vector::length(&round.tickets);
        if (ticket_count == 0) {
            abort E_NO_TICKETS;
        };

        let random_value = randomness_to_u64(&randomness);
        let winner_index = math64::mod(random_value, ticket_count);
        let winner = *vector::borrow(&round.tickets, winner_index);

        round.draw_scheduled = false;
        round.next_ticket_id = 0;
        round.pending_request = option::none<u64>();
        clear_tickets(&mut round.tickets);

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
            return option::none<RoundSnapshot>();
        };
        let state = borrow_state();
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<RoundSnapshot>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            option::some(RoundSnapshot {
                ticket_count: vector::length(&round.tickets),
                draw_scheduled: round.draw_scheduled,
                has_pending_request: option::is_some(&round.pending_request),
                next_ticket_id: round.next_ticket_id,
            })
        }
    }

    #[view]
    public fun pending_request_id(lottery_id: u64): option::Option<u64> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return option::none<u64>();
        };
        let state = borrow_state();
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<u64>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            if (option::is_some(&round.pending_request)) {
                option::some(*option::borrow(&round.pending_request))
            } else {
                option::none<u64>()
            }
        }
    }

    fun prepare_purchase(
        state: &mut RoundCollection,
        lottery_id: u64,
    ): (&mut RoundState, registry::LotteryBlueprint) acquires instances::LotteryCollection {
        let info_opt = instances::get_lottery_info(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_INSTANCE_MISSING;
        };
        let info = *option::borrow(&info_opt);
        let blueprint = info.blueprint;
        if (!instances::is_instance_active(lottery_id)) {
            abort E_INSTANCE_INACTIVE;
        };
        let round = ensure_round(state, lottery_id);
        ensure_round_available(round);
        (round, blueprint)
    }

    fun ensure_round_available(round: &RoundState) {
        if (round.draw_scheduled) {
            abort E_DRAW_ALREADY_SCHEDULED;
        };
        if (option::is_some(&round.pending_request)) {
            abort E_REQUEST_PENDING;
        };
    }

    fun complete_purchase(
        state: &mut RoundCollection,
        round: &mut RoundState,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        ticket_count: u64,
    ): u64 acquires instances::LotteryCollection {
        let jackpot_bps = (jackpot_share_bps as u64);
        let jackpot_contribution = math64::mul_div(ticket_price, jackpot_bps, BASIS_POINT_DENOMINATOR);
        let issued = 0;
        let total_amount = 0;
        while (issued < ticket_count) {
            let ticket_id = round.next_ticket_id;
            round.next_ticket_id = math64::checked_add(ticket_id, 1);
            vector::push_back(&mut round.tickets, buyer);
            instances::record_ticket_sale(lottery_id, jackpot_contribution);
            event::emit_event(
                &mut state.ticket_events,
                TicketPurchasedEvent { lottery_id, ticket_id, buyer, amount: ticket_price },
            );
            total_amount = math64::checked_add(total_amount, ticket_price);
            issued = issued + 1;
        };
        let bonus_tickets = vip::bonus_tickets_for(lottery_id, buyer);
        if (bonus_tickets > 0) {
            let bonus_issued = 0;
            while (bonus_issued < bonus_tickets) {
                let ticket_id = round.next_ticket_id;
                round.next_ticket_id = math64::checked_add(ticket_id, 1);
                vector::push_back(&mut round.tickets, buyer);
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
        total_amount
    }

    fun borrow_state(): &RoundCollection acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<RoundCollection>(@lottery)
    }

    fun borrow_state_mut(): &mut RoundCollection acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<RoundCollection>(@lottery)
    }

    fun ensure_round(state: &mut RoundCollection, lottery_id: u64): &mut RoundState acquires instances::LotteryCollection {
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING;
        };
        if (!table::contains(&state.rounds, lottery_id)) {
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
        if (addr != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
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
    ) acquires RoundCollection, instances::LotteryCollection {
        let state = borrow_state_mut();
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING;
        };
        if (table::contains(&state.rounds, lottery_id)) {
            let mut round = table::borrow_mut(&mut state.rounds, lottery_id);
            round.tickets = tickets;
            round.draw_scheduled = draw_scheduled;
            round.next_ticket_id = next_ticket_id;
            round.pending_request = pending_request;
            return;
        };
        table::add(
            &mut state.rounds,
            lottery_id,
            RoundState { tickets, draw_scheduled, next_ticket_id, pending_request },
        );
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        if (vector::length(randomness) < 8) {
            abort E_RANDOM_BYTES_TOO_SHORT;
        };
        let mut prefix = vector::empty<u8>();
        let mut i = 0;
        while (i < 8) {
            let byte = *vector::borrow(randomness, i);
            vector::push_back(&mut prefix, byte);
            i = i + 1;
        };
        bcs::from_bytes<u64>(prefix)
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let mut buffer = vector::empty<u8>();
        let len = vector::length(data);
        let mut i = 0;
        while (i < len) {
            let byte = *vector::borrow(data, i);
            vector::push_back(&mut buffer, byte);
            i = i + 1;
        };
        buffer
    }
}
