module lottery_engine::sales {
    friend lottery_rewards_engine::autopurchase;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_data::treasury_multi;
    use lottery_rewards_engine::treasury;
    use supra_framework::event;

    const E_TICKET_LIMIT_EXCEEDED: u64 = 1;
    const E_INVALID_TICKET_COUNT: u64 = 2;
    const E_INVALID_PAYMENT: u64 = 3;
    const E_LOTTERY_INACTIVE: u64 = 4;
    const E_TICKET_OVERFLOW: u64 = 5;
    const E_JACKPOT_OVERFLOW: u64 = 6;

    const MAX_SUPPORTED_TICKETS_PER_PURCHASE: u64 = 128;
    const BPS_DENOMINATOR: u128 = 10_000;

    public entry fun enter_paid_round(
        caller: &signer,
        lottery_id: u64,
        ticket_count: u64,
        payment_amount: u64,
    ) acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry,
        treasury_multi::TreasuryState
    {
        assert!(ticket_count > 0, E_INVALID_TICKET_COUNT);
        assert!(ticket_count <= MAX_SUPPORTED_TICKETS_PER_PURCHASE, E_TICKET_LIMIT_EXCEEDED);

        let buyer = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        let (ticket_price, jackpot_increment) = update_instance_on_purchase(
            registry,
            lottery_id,
            ticket_count,
            payment_amount,
        );
        instances::emit_snapshot(registry, lottery_id);

        treasury::record_sale_allocation(lottery_id, payment_amount, jackpot_increment);

        let state = lottery_state::borrow_mut(@lottery);
        let (start_ticket_id, schedule_now) = update_lottery_runtime(
            state,
            lottery_id,
            buyer,
            ticket_count,
            jackpot_increment,
        );
        lottery_state::emit_snapshot(state, lottery_id);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        update_round_runtime(
            rounds_registry,
            lottery_id,
            buyer,
            ticket_price,
            start_ticket_id,
            ticket_count,
            schedule_now,
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
    }

    fun update_instance_on_purchase(
        registry: &mut instances::InstanceRegistry,
        lottery_id: u64,
        ticket_count: u64,
        payment_amount: u64,
    ): (u64, u64) acquires instances::InstanceRegistry {
        let record = instances::instance_mut(registry, lottery_id);
        assert!(record.active, E_LOTTERY_INACTIVE);

        let ticket_price = record.ticket_price;
        let expected_payment = multiply(ticket_price, ticket_count);
        assert!(payment_amount == expected_payment, E_INVALID_PAYMENT);

        let new_total = record.tickets_sold + ticket_count;
        assert!(new_total >= record.tickets_sold, E_TICKET_OVERFLOW);
        record.tickets_sold = new_total;

        let jackpot_increment = compute_share(payment_amount, record.jackpot_share_bps);
        let new_jackpot = record.jackpot_accumulated + jackpot_increment;
        assert!(new_jackpot >= record.jackpot_accumulated, E_JACKPOT_OVERFLOW);
        record.jackpot_accumulated = new_jackpot;

        (ticket_price, jackpot_increment)
    }

    fun update_lottery_runtime(
        state: &mut lottery_state::LotteryState,
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        jackpot_increment: u64,
    ): (u64, bool) acquires lottery_state::LotteryState {
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        let ledger = &mut runtime.tickets;
        let start_ticket_id = ledger.next_ticket_id;
        let next_ticket_id = add_u64(start_ticket_id, ticket_count, E_TICKET_OVERFLOW);
        ledger.next_ticket_id = next_ticket_id;

        push_addresses(&mut ledger.participants, buyer, ticket_count);

        let new_jackpot = runtime.jackpot_amount + jackpot_increment;
        assert!(new_jackpot >= runtime.jackpot_amount, E_JACKPOT_OVERFLOW);
        runtime.jackpot_amount = new_jackpot;

        let threshold = runtime.draw.auto_draw_threshold;
        let total_tickets = vector::length(&ledger.participants);
        let schedule_now =
            !runtime.draw.draw_scheduled && threshold > 0 && total_tickets >= threshold;
        if (schedule_now) {
            runtime.draw.draw_scheduled = true;
        }

        (start_ticket_id, schedule_now)
    }

    fun update_round_runtime(
        registry: &mut rounds::RoundRegistry,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        start_ticket_id: u64,
        ticket_count: u64,
        schedule_now: bool,
    ) acquires rounds::RoundRegistry {
        let runtime = rounds::round_mut(registry, lottery_id);
        let current_next_id = runtime.next_ticket_id;
        assert!(current_next_id == start_ticket_id, E_TICKET_OVERFLOW);
        let next_ticket_id = add_u64(start_ticket_id, ticket_count, E_TICKET_OVERFLOW);
        runtime.next_ticket_id = next_ticket_id;

        push_addresses(&mut runtime.tickets, buyer, ticket_count);
        emit_ticket_events(
            registry,
            lottery_id,
            buyer,
            ticket_price,
            start_ticket_id,
            ticket_count,
        );
        if (schedule_now) {
            runtime.draw_scheduled = true;
        }
        emit_schedule_event_if_needed(registry, lottery_id, schedule_now);
    }

    public(friend) fun max_supported_tickets_per_purchase(): u64 {
        MAX_SUPPORTED_TICKETS_PER_PURCHASE
    }

    public(friend) fun record_prepaid_purchase(
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
    ): (u64, u64)
    acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry,
        treasury_multi::TreasuryState
    {
        assert!(ticket_count > 0, E_INVALID_TICKET_COUNT);
        assert!(ticket_count <= MAX_SUPPORTED_TICKETS_PER_PURCHASE, E_TICKET_LIMIT_EXCEEDED);

        let registry = instances::borrow_registry_mut(@lottery);
        let ticket_price = instances::instance(registry, lottery_id).ticket_price;
        let payment_amount = multiply(ticket_price, ticket_count);
        let (_, jackpot_increment) = update_instance_on_purchase(
            registry,
            lottery_id,
            ticket_count,
            payment_amount,
        );
        instances::emit_snapshot(registry, lottery_id);

        treasury::record_sale_allocation(lottery_id, payment_amount, jackpot_increment);

        let state = lottery_state::borrow_mut(@lottery);
        let (start_ticket_id, schedule_now) = update_lottery_runtime(
            state,
            lottery_id,
            buyer,
            ticket_count,
            jackpot_increment,
        );
        lottery_state::emit_snapshot(state, lottery_id);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        update_round_runtime(
            rounds_registry,
            lottery_id,
            buyer,
            ticket_price,
            start_ticket_id,
            ticket_count,
            schedule_now,
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);

        (ticket_price, payment_amount)
    }

    fun multiply(value: u64, count: u64): u64 {
        let product = (value as u128) * (count as u128);
        assert!(product <= 18446744073709551615, E_INVALID_PAYMENT);
        product as u64
    }

    fun compute_share(amount: u64, share_bps: u16): u64 {
        let numerator = (amount as u128) * (share_bps as u128);
        let share = numerator / BPS_DENOMINATOR;
        assert!(share <= 18446744073709551615, E_JACKPOT_OVERFLOW);
        share as u64
    }

    fun add_u64(lhs: u64, rhs: u64, err: u64): u64 {
        let sum = (lhs as u128) + (rhs as u128);
        assert!(sum <= 18446744073709551615, err);
        sum as u64
    }

    fun push_addresses(target: &mut vector<address>, buyer: address, ticket_count: u64) {
        push_addresses_recursive(target, buyer, ticket_count);
    }

    fun push_addresses_recursive(target: &mut vector<address>, buyer: address, remaining: u64) {
        if (remaining == 0) {
            return;
        };
        vector::push_back(target, buyer);
        let next_remaining = remaining - 1;
        push_addresses_recursive(target, buyer, next_remaining);
    }

    fun emit_ticket_events(
        registry: &mut rounds::RoundRegistry,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        start_ticket_id: u64,
        ticket_count: u64,
    ) {
        emit_ticket_events_from_offset(
            registry,
            lottery_id,
            buyer,
            ticket_price,
            start_ticket_id,
            ticket_count,
            0,
        );
    }

    fun emit_ticket_events_from_offset(
        registry: &mut rounds::RoundRegistry,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        start_ticket_id: u64,
        remaining: u64,
        offset: u64,
    ) {
        if (remaining == 0) {
            return;
        };
        let ticket_id = add_u64(start_ticket_id, offset, E_TICKET_OVERFLOW);
        event::emit_event(
            &mut registry.ticket_events,
            rounds::TicketPurchasedEvent { lottery_id, ticket_id, buyer, amount: ticket_price },
        );
        let next_offset = add_u64(offset, 1, E_TICKET_OVERFLOW);
        let next_remaining = remaining - 1;
        emit_ticket_events_from_offset(
            registry,
            lottery_id,
            buyer,
            ticket_price,
            start_ticket_id,
            next_remaining,
            next_offset,
        );
    }

    fun emit_schedule_event_if_needed(
        registry: &mut rounds::RoundRegistry,
        lottery_id: u64,
        schedule_now: bool,
    ) {
        if (schedule_now) {
            event::emit_event(
                &mut registry.schedule_events,
                rounds::DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
            );
        }
    }
}
