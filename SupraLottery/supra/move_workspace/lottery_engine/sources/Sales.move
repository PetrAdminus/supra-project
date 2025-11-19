module lottery_engine::sales {
    friend lottery_rewards_engine::autopurchase;
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_data::treasury_multi;
    use lottery_rewards_engine::treasury;
    use lottery_vrf_gateway::table;
    use supra_framework::event;

    const E_TICKET_LIMIT_EXCEEDED: u64 = 1;
    const E_INVALID_TICKET_COUNT: u64 = 2;
    const E_INVALID_PAYMENT: u64 = 3;
    const E_LOTTERY_INACTIVE: u64 = 4;
    const E_TICKET_OVERFLOW: u64 = 5;
    const E_JACKPOT_OVERFLOW: u64 = 6;
    const E_NOT_AUTHORIZED: u64 = 7;

    const MAX_SUPPORTED_TICKETS_PER_PURCHASE: u64 = 128;
    const BPS_DENOMINATOR: u128 = 10_000;

    public struct SalesLotterySnapshot has copy, drop, store {
        lottery_id: u64,
        ticket_price: u64,
        jackpot_share_bps: u16,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        next_ticket_id: u64,
        auto_draw_threshold: u64,
        draw_scheduled: bool,
    }

    #[view]
    public fun is_initialized(): bool {
        instances::is_initialized()
            && lottery_state::is_initialized()
            && rounds::is_initialized()
            && rounds::queues_initialized()
    }

    public entry fun enter_paid_round(
        caller: &signer,
        lottery_id: u64,
        ticket_count: u64,
        payment_amount: u64,
    ) acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::PendingPurchaseQueue,
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

        record_purchase_for_rewards(lottery_id, buyer, ticket_count, payment_amount);
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
        rounds::PendingPurchaseQueue,
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

        record_purchase_for_rewards(lottery_id, buyer, ticket_count, payment_amount);

        (ticket_price, payment_amount)
    }

    public entry fun grant_bonus_tickets_admin(
        caller: &signer,
        lottery_id: u64,
        player: address,
        bonus_tickets: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        ensure_admin(caller);
        grant_bonus_tickets_internal(lottery_id, player, bonus_tickets);
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

    fun record_purchase_for_rewards(
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        payment_amount: u64,
    ) acquires rounds::PendingPurchaseQueue {
        let queue = rounds::borrow_purchase_queue_mut(@lottery);
        rounds::enqueue_purchase_record(queue, lottery_id, buyer, ticket_count, payment_amount);
    }

    fun grant_bonus_tickets_internal(
        lottery_id: u64,
        player: address,
        remaining: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        if (remaining == 0) {
            return;
        };
        let chunk = select_chunk(remaining);
        grant_bonus_chunk(lottery_id, player, chunk);
        let next_remaining = remaining - chunk;
        grant_bonus_tickets_internal(lottery_id, player, next_remaining);
    }

    fun grant_bonus_chunk(
        lottery_id: u64,
        player: address,
        ticket_count: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        if (ticket_count == 0) {
            return;
        };
        {
            let registry = instances::borrow_registry_mut(@lottery);
            let record = instances::instance_mut(registry, lottery_id);
            let new_total = add_u64(record.tickets_sold, ticket_count, E_TICKET_OVERFLOW);
            record.tickets_sold = new_total;
            instances::emit_snapshot(registry, lottery_id);
        };
        let state = lottery_state::borrow_mut(@lottery);
        let (start_ticket_id, schedule_now) = update_lottery_runtime(
            state,
            lottery_id,
            player,
            ticket_count,
            0,
        );
        lottery_state::emit_snapshot(state, lottery_id);
        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        update_round_runtime(
            rounds_registry,
            lottery_id,
            player,
            0,
            start_ticket_id,
            ticket_count,
            schedule_now,
        );
        rounds::emit_snapshot(rounds_registry, lottery_id);
    }

    #[view]
    public fun sales_snapshot(lottery_id: u64): option::Option<SalesLotterySnapshot>
    acquires instances::InstanceRegistry, lottery_state::LotteryState {
        if (!instances::is_initialized()) {
            return option::none<SalesLotterySnapshot>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<SalesLotterySnapshot>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        if (!table::contains(&registry.instances, lottery_id)) {
            return option::none<SalesLotterySnapshot>();
        };
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<SalesLotterySnapshot>();
        };

        let snapshot = build_sales_snapshot(&registry, &state, lottery_id);
        option::some(snapshot)
    }

    #[view]
    public fun sales_snapshots(): option::Option<vector<SalesLotterySnapshot>>
    acquires instances::InstanceRegistry, lottery_state::LotteryState {
        if (!instances::is_initialized()) {
            return option::none<vector<SalesLotterySnapshot>>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<vector<SalesLotterySnapshot>>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        let len = vector::length(&registry.lottery_ids);
        let snapshots = collect_sales_snapshots(&registry, &state, 0, len);
        option::some(snapshots)
    }

    fun build_sales_snapshot(
        registry: &instances::InstanceRegistry,
        state: &lottery_state::LotteryState,
        lottery_id: u64,
    ): SalesLotterySnapshot {
        let record = table::borrow(&registry.instances, lottery_id);
        let runtime = table::borrow(&state.lotteries, lottery_id);

        SalesLotterySnapshot {
            lottery_id,
            ticket_price: record.ticket_price,
            jackpot_share_bps: record.jackpot_share_bps,
            tickets_sold: record.tickets_sold,
            jackpot_accumulated: record.jackpot_accumulated,
            next_ticket_id: runtime.tickets.next_ticket_id,
            auto_draw_threshold: runtime.draw.auto_draw_threshold,
            draw_scheduled: runtime.draw.draw_scheduled,
        }
    }

    fun collect_sales_snapshots(
        registry: &instances::InstanceRegistry,
        state: &lottery_state::LotteryState,
        index: u64,
        len: u64,
    ): vector<SalesLotterySnapshot> {
        if (index >= len) {
            return vector::empty<SalesLotterySnapshot>();
        };

        let lottery_id = *vector::borrow(&registry.lottery_ids, index);
        let mut current = vector::empty<SalesLotterySnapshot>();
        if (table::contains(&state.lotteries, lottery_id)) {
            let snapshot = build_sales_snapshot(registry, state, lottery_id);
            vector::push_back(&mut current, snapshot);
        };
        let tail = collect_sales_snapshots(registry, state, index + 1, len);
        append_sales_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_sales_snapshots(
        dst: &mut vector<SalesLotterySnapshot>,
        src: &vector<SalesLotterySnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index >= len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_sales_snapshots(dst, src, index + 1);
    }

    fun select_chunk(remaining: u64): u64 {
        if (remaining > MAX_SUPPORTED_TICKETS_PER_PURCHASE) {
            MAX_SUPPORTED_TICKETS_PER_PURCHASE
        } else {
            remaining
        }
    }

    fun ensure_admin(caller: &signer) acquires instances::InstanceRegistry {
        let registry = instances::borrow_registry(@lottery);
        let caller_address = signer::address_of(caller);
        assert!(caller_address == registry.admin, E_NOT_AUTHORIZED);
    }
}
