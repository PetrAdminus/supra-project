module lottery_engine::draw {
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::payouts;
    use lottery_data::rounds;
    use lottery_engine::vrf;
    use supra_framework::event;
    use lottery_vrf_gateway::table;
    use lottery_vrf_gateway::hub;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_NO_TICKETS: u64 = 2;
    const E_INSTANCE_INACTIVE: u64 = 3;
    const E_REQUEST_PENDING: u64 = 4;
    const E_DRAW_NOT_SCHEDULED: u64 = 5;
    const E_PENDING_REQUEST_MISMATCH: u64 = 6;
    const E_RANDOMNESS_TOO_SHORT: u64 = 7;
    const E_RANDOMNESS_OVERFLOW: u64 = 8;

    public struct DrawLotterySnapshot has copy, drop, store {
        lottery_id: u64,
        draw_scheduled_round: bool,
        draw_scheduled_state: bool,
        pending_request_round: option::Option<u64>,
        pending_request_state: option::Option<u64>,
        last_request_payload_hash: option::Option<vector<u8>>,
        last_requester: option::Option<address>,
        ticket_count_round: u64,
        ticket_count_state: u64,
        next_ticket_id_round: u64,
        next_ticket_id_state: u64,
        request_count: u64,
        response_count: u64,
    }

    public struct PendingRequestAlignment has copy, drop, store {
        lottery_id: u64,
        round_pending_request_id: option::Option<u64>,
        state_pending_request_id: option::Option<u64>,
        hub_request_id: option::Option<u64>,
        hub_pending: bool,
        pending_ids_match: bool,
        payload_hash_match: bool,
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);
        let record = instances::instance(registry, lottery_id);
        assert!(record.active, E_INSTANCE_INACTIVE);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        let round = rounds::round_mut(rounds_registry, lottery_id);
        let ticket_count = vector::length(&round.tickets);
        assert!(ticket_count > 0, E_NO_TICKETS);
        assert!(!option::is_some(&round.pending_request), E_REQUEST_PENDING);

        round.draw_scheduled = true;
        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        assert!(
            !option::is_some(&runtime.pending_request.request_id),
            E_REQUEST_PENDING
        );
        runtime.draw.draw_scheduled = true;

        event::emit_event(
            &mut rounds_registry.schedule_events,
            rounds::DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun reset_round(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        let round = rounds::round_mut(rounds_registry, lottery_id);
        let cleared = vector::length(&round.tickets);
        round.tickets = vector::empty<address>();
        round.draw_scheduled = false;
        round.next_ticket_id = 0;
        round.pending_request = option::none<u64>();

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        runtime.tickets.participants = vector::empty<address>();
        runtime.tickets.next_ticket_id = 0;
        runtime.draw.draw_scheduled = false;
        runtime.pending_request.request_id = option::none<u64>();
        runtime.pending_request.last_request_payload_hash = option::none<vector<u8>>();
        runtime.pending_request.last_requester = option::none<address>();
        runtime.request_config = option::none<lottery_state::VrfRequestConfig>();

        event::emit_event(
            &mut rounds_registry.schedule_events,
            rounds::DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
        );
        event::emit_event(
            &mut rounds_registry.reset_events,
            rounds::RoundResetEvent { lottery_id, tickets_cleared: cleared },
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);
        let record = instances::instance(registry, lottery_id);
        assert!(record.active, E_INSTANCE_INACTIVE);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        let round = rounds::round_mut(rounds_registry, lottery_id);
        assert!(round.draw_scheduled, E_DRAW_NOT_SCHEDULED);
        assert!(vector::length(&round.tickets) > 0, E_NO_TICKETS);
        assert!(!option::is_some(&round.pending_request), E_REQUEST_PENDING);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        assert!(
            !option::is_some(&runtime.pending_request.request_id),
            E_REQUEST_PENDING
        );

        vrf::ensure_requests_allowed();

        let payload_for_hash = clone_bytes(&payload);
        let request_id = hub::request_randomness(lottery_id, payload);
        round.pending_request = option::some(request_id);

        runtime.pending_request.request_id = option::some(request_id);
        runtime.pending_request.last_request_payload_hash = option::some(hash::sha3_256(payload_for_hash));
        runtime.pending_request.last_requester = option::some(admin);
        runtime.request_config = option::none<lottery_state::VrfRequestConfig>();
        runtime.vrf_stats.request_count = runtime.vrf_stats.request_count + 1;

        lottery_state::emit_vrf_request_config(state, lottery_id);
        event::emit_event(
            &mut rounds_registry.request_events,
            rounds::DrawRequestIssuedEvent { lottery_id, request_id },
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::PendingHistoryQueue, rounds::RoundRegistry, payouts::PayoutLedger {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let lottery_id = hub::request_record_lottery_id(&record);
        let payload = hub::request_record_payload(&record);

        let registry = instances::borrow_registry_mut(@lottery);
        let state = lottery_state::borrow_mut(@lottery);
        let rounds_registry = rounds::borrow_registry_mut(@lottery);

        let runtime = lottery_state::runtime_mut(state, lottery_id);
        let round = rounds::round_mut(rounds_registry, lottery_id);
        assert!(option::is_some(&round.pending_request), E_REQUEST_PENDING);
        let expected_round_id = *option::borrow(&round.pending_request);
        assert!(expected_round_id == request_id, E_PENDING_REQUEST_MISMATCH);
        assert!(option::is_some(&runtime.pending_request.request_id), E_PENDING_REQUEST_MISMATCH);
        let expected_state_id = *option::borrow(&runtime.pending_request.request_id);
        assert!(expected_state_id == request_id, E_PENDING_REQUEST_MISMATCH);

        let ticket_count = vector::length(&round.tickets);
        assert!(ticket_count > 0, E_NO_TICKETS);
        let winner_index = randomness_to_index(&randomness, ticket_count);
        let winner = *vector::borrow(&round.tickets, winner_index);

        let prize_amount = runtime.jackpot_amount;
        runtime.jackpot_amount = 0;
        runtime.tickets.participants = vector::empty<address>();
        runtime.tickets.next_ticket_id = 0;
        runtime.draw.draw_scheduled = false;
        runtime.pending_request.request_id = option::none<u64>();
        runtime.pending_request.last_request_payload_hash = option::none<vector<u8>>();
        runtime.pending_request.last_requester = option::none<address>();
        runtime.request_config = option::none<lottery_state::VrfRequestConfig>();
        runtime.vrf_stats.response_count = runtime.vrf_stats.response_count + 1;

        lottery_state::emit_vrf_request_config(state, lottery_id);
        round.tickets = vector::empty<address>();
        round.draw_scheduled = false;
        round.next_ticket_id = 0;
        round.pending_request = option::none<u64>();

        let record_mut = instances::instance_mut(registry, lottery_id);
        record_mut.jackpot_accumulated = 0;
        instances::emit_snapshot(registry, lottery_id);

        let randomness_for_payout = clone_bytes(&randomness);
        let payload_for_payout = clone_bytes(&payload);
        let randomness_for_history = clone_bytes(&randomness);
        let payload_for_history = clone_bytes(&payload);

        payouts::record_draw_winner(
            lottery_id,
            winner,
            winner_index,
            prize_amount,
            randomness_for_payout,
            payload_for_payout,
        );

        let history_queue = rounds::borrow_history_queue_mut(@lottery);
        rounds::enqueue_history_record(
            history_queue,
            lottery_id,
            request_id,
            winner,
            winner_index,
            prize_amount,
            randomness_for_history,
            payload_for_history,
        );

        hub::record_fulfillment(request_id, lottery_id, clone_bytes(&randomness));
        event::emit_event(
            &mut rounds_registry.fulfill_events,
            rounds::DrawFulfilledEvent {
                lottery_id,
                request_id,
                winner,
                ticket_index: winner_index,
                random_bytes: clone_bytes(&randomness),
                prize_amount,
                payload,
            },
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    #[view]
    public fun draw_snapshot(lottery_id: u64): option::Option<DrawLotterySnapshot>
    acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        if (!instances::is_initialized()) {
            return option::none<DrawLotterySnapshot>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<DrawLotterySnapshot>();
        };
        if (!rounds::is_initialized()) {
            return option::none<DrawLotterySnapshot>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        let rounds_registry = rounds::borrow_registry(@lottery);
        if (!table::contains(&registry.instances, lottery_id)) {
            return option::none<DrawLotterySnapshot>();
        };
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<DrawLotterySnapshot>();
        };
        if (!table::contains(&rounds_registry.rounds, lottery_id)) {
            return option::none<DrawLotterySnapshot>();
        };

        let snapshot = build_draw_snapshot(&registry, &state, &rounds_registry, lottery_id);
        option::some(snapshot)
    }

    #[view]
    public fun draw_snapshots(): option::Option<vector<DrawLotterySnapshot>>
    acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        if (!instances::is_initialized()) {
            return option::none<vector<DrawLotterySnapshot>>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<vector<DrawLotterySnapshot>>();
        };
        if (!rounds::is_initialized()) {
            return option::none<vector<DrawLotterySnapshot>>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        let rounds_registry = rounds::borrow_registry(@lottery);
        let len = vector::length(&registry.lottery_ids);
        let snapshots = collect_draw_snapshots(&registry, &state, &rounds_registry, 0, len);
        option::some(snapshots)
    }

    #[view]
    public fun pending_request_alignment(lottery_id: u64): option::Option<PendingRequestAlignment>
    acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        if (!instances::is_initialized() || !lottery_state::is_initialized() || !rounds::is_initialized()) {
            return option::none<PendingRequestAlignment>();
        };

        let registry = instances::borrow_registry(@lottery);
        if (!instances::contains(registry, lottery_id)) {
            return option::none<PendingRequestAlignment>();
        };

        let round_snapshot_opt = rounds::round_snapshot(lottery_id);
        if (!option::is_some(&round_snapshot_opt)) {
            return option::none<PendingRequestAlignment>();
        };
        let mut round_snapshot = option::destroy_some(round_snapshot_opt);

        let runtime_snapshot_opt = lottery_state::runtime_snapshot(lottery_id);
        if (!option::is_some(&runtime_snapshot_opt)) {
            return option::none<PendingRequestAlignment>();
        };
        let runtime_snapshot = option::destroy_some(runtime_snapshot_opt);

        let pending_ids_match = options_equal_u64(
            &round_snapshot.pending_request_id,
            &runtime_snapshot.pending_request.request_id,
        );

        let mut hub_request_id = option::none<u64>();
        let mut hub_pending = false;
        let mut payload_hash_match = false;

        if (hub::is_initialized() && option::is_some(&round_snapshot.pending_request_id)) {
            let request_id = *option::borrow(&round_snapshot.pending_request_id);
            let hub_snapshot_opt = hub::request_snapshot(request_id);
            if (option::is_some(&hub_snapshot_opt)) {
                let hub_snapshot = option::destroy_some(hub_snapshot_opt);
                hub_pending = hub_snapshot.pending;
                hub_request_id = option::some(hub_snapshot.request_id);
                if (option::is_some(&runtime_snapshot.pending_request.last_request_payload_hash)) {
                    let state_hash = option::borrow(&runtime_snapshot.pending_request.last_request_payload_hash);
                    payload_hash_match = *state_hash == hub_snapshot.payload_hash;
                };
            };
        };

        option::some(PendingRequestAlignment {
            lottery_id,
            round_pending_request_id: round_snapshot.pending_request_id,
            state_pending_request_id: runtime_snapshot.pending_request.request_id,
            hub_request_id,
            hub_pending,
            pending_ids_match,
            payload_hash_match,
        })
    }

    fun randomness_to_index(randomness: &vector<u8>, ticket_count: u64): u64 {
        let random_value = randomness_to_u64(randomness);
        random_value % ticket_count
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        let length = vector::length(randomness);
        assert!(length >= 8, E_RANDOMNESS_TOO_SHORT);
        accumulate_randomness(randomness, 0, 0)
    }

    fun build_draw_snapshot(
        registry: &instances::InstanceRegistry,
        state: &lottery_state::LotteryState,
        rounds_registry: &rounds::RoundRegistry,
        lottery_id: u64,
    ): DrawLotterySnapshot {
        let runtime = table::borrow(&state.lotteries, lottery_id);
        let round_runtime = table::borrow(&rounds_registry.rounds, lottery_id);

        let pending_request_state = runtime.pending_request.request_id;
        let last_request_payload_hash = clone_option_bytes(&runtime.pending_request.last_request_payload_hash);
        let last_requester = runtime.pending_request.last_requester;
        let tickets_state = &runtime.tickets.participants;
        let tickets_round = &round_runtime.tickets;

        DrawLotterySnapshot {
            lottery_id,
            draw_scheduled_round: round_runtime.draw_scheduled,
            draw_scheduled_state: runtime.draw.draw_scheduled,
            pending_request_round: round_runtime.pending_request,
            pending_request_state,
            last_request_payload_hash,
            last_requester,
            ticket_count_round: vector::length(tickets_round),
            ticket_count_state: vector::length(tickets_state),
            next_ticket_id_round: round_runtime.next_ticket_id,
            next_ticket_id_state: runtime.tickets.next_ticket_id,
            request_count: runtime.vrf_stats.request_count,
            response_count: runtime.vrf_stats.response_count,
        }
    }

    fun collect_draw_snapshots(
        registry: &instances::InstanceRegistry,
        state: &lottery_state::LotteryState,
        rounds_registry: &rounds::RoundRegistry,
        index: u64,
        len: u64,
    ): vector<DrawLotterySnapshot> {
        if (index >= len) {
            return vector::empty<DrawLotterySnapshot>();
        };

        let lottery_id = *vector::borrow(&registry.lottery_ids, index);
        let mut current = vector::empty<DrawLotterySnapshot>();
        if (table::contains(&state.lotteries, lottery_id) && table::contains(&rounds_registry.rounds, lottery_id)) {
            let snapshot = build_draw_snapshot(registry, state, rounds_registry, lottery_id);
            vector::push_back(&mut current, snapshot);
        };
        let tail = collect_draw_snapshots(registry, state, rounds_registry, index + 1, len);
        append_draw_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_draw_snapshots(
        dst: &mut vector<DrawLotterySnapshot>,
        src: &vector<DrawLotterySnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index >= len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_draw_snapshots(dst, src, index + 1);
    }

    fun options_equal_u64(a: &option::Option<u64>, b: &option::Option<u64>): bool {
        if (option::is_some(a)) {
            if (!option::is_some(b)) {
                return false;
            };
            let lhs = *option::borrow(a);
            let rhs = *option::borrow(b);
            lhs == rhs
        } else {
            !option::is_some(b)
        }
    }

    fun clone_option_bytes(value: &option::Option<vector<u8>>): option::Option<vector<u8>> {
        if (option::is_some(value)) {
            option::some(clone_bytes(option::borrow(value)))
        } else {
            option::none<vector<u8>>()
        }
    }

    fun accumulate_randomness(randomness: &vector<u8>, index: u64, acc: u64): u64 {
        if (index >= 8) {
            acc
        } else {
            let byte = *vector::borrow(randomness, index);
            let scaled = safe_mul_u64(acc, 256, E_RANDOMNESS_OVERFLOW);
            let next_acc = safe_add_u64(scaled, u8_to_u64(byte), E_RANDOMNESS_OVERFLOW);
            let next_index = index + 1;
            accumulate_randomness(randomness, next_index, next_acc)
        }
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        clone_into(&mut buffer, data, 0, len);
        buffer
    }

    fun clone_into(
        buffer: &mut vector<u8>,
        data: &vector<u8>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(data, index);
        vector::push_back(buffer, byte);
        let next_index = index + 1;
        clone_into(buffer, data, next_index, len);
    }

    fun u8_to_u64(value: u8): u64 {
        value as u64
    }

    fun safe_mul_u64(lhs: u64, rhs: u64, code: u64): u64 {
        if (lhs == 0 || rhs == 0) {
            0
        } else {
            let product = (lhs as u128) * (rhs as u128);
            assert!(product <= 18446744073709551615, code);
            product as u64
        }
    }

    fun safe_add_u64(lhs: u64, rhs: u64, code: u64): u64 {
        let sum = (lhs as u128) + (rhs as u128);
        assert!(sum <= 18446744073709551615, code);
        sum as u64
    }
}
