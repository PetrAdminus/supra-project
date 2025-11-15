module lottery_engine::cancellation {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::cancellations;
    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use supra_framework::event;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_INVALID_REASON: u64 = 2;
    const E_PENDING_REQUEST: u64 = 3;

    const STATUS_ACTIVE: u8 = 1;
    const STATUS_INACTIVE: u8 = 2;

    public entry fun cancel_lottery(
        caller: &signer,
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
    ) acquires cancellations::CancellationLedger, instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        assert!(reason_code > 0, E_INVALID_REASON);

        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);

        let record_view = instances::instance(registry, lottery_id);
        let ticket_price = record_view.ticket_price;
        let tickets_sold = record_view.tickets_sold;
        let jackpot_locked = record_view.jackpot_accumulated;
        let previous_status = if (record_view.active) { STATUS_ACTIVE } else { STATUS_INACTIVE };

        let proceeds_accum = multiply(ticket_price, tickets_sold);

        {
            let record_mut = instances::instance_mut(registry, lottery_id);
            record_mut.jackpot_accumulated = 0;
        };
        instances::set_active(registry, lottery_id, false);
        instances::emit_snapshot(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        assert!(!option::is_some(&runtime.pending_request.request_id), E_PENDING_REQUEST);

        let pending_tickets = vector::length(&runtime.tickets.participants);
        runtime.tickets.participants = vector::empty<address>();
        runtime.tickets.next_ticket_id = 0;
        runtime.jackpot_amount = 0;
        runtime.draw.draw_scheduled = false;
        runtime.pending_request.request_id = option::none<u64>();
        runtime.pending_request.last_request_payload_hash = option::none<vector<u8>>();
        runtime.pending_request.last_requester = option::none<address>();
        runtime.request_config = option::none<lottery_state::VrfRequestConfig>();

        lottery_state::emit_vrf_request_config(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        let round = rounds::round_mut(rounds_registry, lottery_id);
        assert!(!option::is_some(&round.pending_request), E_PENDING_REQUEST);
        round.tickets = vector::empty<address>();
        round.draw_scheduled = false;
        round.next_ticket_id = 0;
        round.pending_request = option::none<u64>();

        event::emit_event(
            &mut rounds_registry.schedule_events,
            rounds::DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
        );
        event::emit_event(
            &mut rounds_registry.reset_events,
            rounds::RoundResetEvent { lottery_id, tickets_cleared: pending_tickets },
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);

        cancellations::record_cancellation(
            lottery_id,
            reason_code,
            canceled_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
            jackpot_locked,
            pending_tickets,
        );
    }

    fun multiply(lhs: u64, rhs: u64): u64 {
        let product = (lhs as u128) * (rhs as u128);
        assert!(product <= 18446744073709551615, E_INVALID_REASON);
        product as u64
    }
}
