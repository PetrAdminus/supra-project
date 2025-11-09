// sources/sales.move
module lottery_multi::sales {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;
    use supra_framework::event;

    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::feature_switch;
    use lottery_multi::registry;
    use lottery_multi::roles;
    use lottery_multi::types;

    const PURCHASE_EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_SALES: u8 = history::EVENT_CATEGORY_SALES;
    const CHUNK_CAPACITY: u64 = 256;
    const MAX_TICKETS_PER_TX: u64 = 128;

    struct TicketChunk has store {
        lottery_id: u64,
        chunk_seq: u64,
        start_index: u64,
        buyers: vector<address>,
    }

    pub struct TicketPurchaseEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub buyer: address,
        pub quantity: u64,
        pub sale_amount: u64,
        pub prize_allocation: u64,
        pub jackpot_allocation: u64,
        pub operations_allocation: u64,
        pub reserve_allocation: u64,
        pub tickets_sold: u64,
        pub proceeds_accum: u64,
    }

    struct SalesState has store {
        ticket_price: u64,
        tickets_sold: u64,
        proceeds_accum: u64,
        last_purchase_ts: u64,
        next_chunk_seq: u64,
        tickets_per_address: table::Table<address, u64>,
        ticket_chunks: table::Table<u64, TicketChunk>,
        distribution: economics::SalesDistribution,
        accounting: economics::Accounting,
    }

    struct SalesLedger has key {
        states: table::Table<u64, SalesState>,
        purchase_events: event::EventHandle<TicketPurchaseEvent>,
    }

    public entry fun init_sales(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(!exists<SalesLedger>(addr), errors::E_ALREADY_INITIALIZED);
        let ledger = SalesLedger {
            states: table::new(),
            purchase_events: event::new_event_handle<TicketPurchaseEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun purchase_tickets_public(
        buyer: &signer,
        lottery_id: u64,
        quantity: u64,
        now_ts: u64,
    ) acquires SalesLedger, registry::Registry {
        purchase_internal(buyer, lottery_id, quantity, now_ts, false);
    }

    public entry fun purchase_tickets_premium(
        buyer: &signer,
        lottery_id: u64,
        quantity: u64,
        now_ts: u64,
        premium_cap: &roles::PremiumAccessCap,
    ) acquires SalesLedger, registry::Registry {
        let buyer_addr = signer::address_of(buyer);
        assert!(premium_cap.holder == buyer_addr, errors::E_PREMIUM_CAP_MISMATCH);
        let active = roles::is_premium_active(premium_cap, now_ts);
        assert!(active, errors::E_PREMIUM_CAP_EXPIRED);
        purchase_internal(buyer, lottery_id, quantity, now_ts, true);
    }

    fun purchase_internal(
        buyer: &signer,
        lottery_id: u64,
        quantity: u64,
        now_ts: u64,
        has_premium: bool,
    ) acquires SalesLedger, registry::Registry {
        assert!(quantity > 0, errors::E_PURCHASE_QTY_ZERO);
        assert!(quantity <= MAX_TICKETS_PER_TX, errors::E_PURCHASE_QTY_LIMIT);

        if (feature_switch::is_initialized()) {
            let enabled = feature_switch::is_enabled(feature_switch::FEATURE_PURCHASE, has_premium);
            assert!(enabled, errors::E_FEATURE_DISABLED);
        };

        let status = registry::get_status(lottery_id);
        assert!(status == types::STATUS_ACTIVE, errors::E_LOTTERY_NOT_ACTIVE);
        let config = registry::borrow_config(lottery_id);
        assert!(
            now_ts >= config.sales_window.sales_start && now_ts <= config.sales_window.sales_end,
            errors::E_SALES_WINDOW_CLOSED,
        );

        let ledger = borrow_ledger_mut();
        let state = borrow_or_create_state(
            ledger,
            lottery_id,
            config.ticket_price,
            &config.sales_distribution,
        );

        assert_total_limit(state, &config.ticket_limits, quantity);
        let buyer_addr = signer::address_of(buyer);
        let existing = per_address_count(state, buyer_addr);
        assert_address_limit(&config.ticket_limits, existing, quantity);
        update_per_address(state, buyer_addr, existing, quantity);

        append_tickets(state, lottery_id, buyer_addr, quantity);
        let (
            sale_amount,
            prize_allocation,
            jackpot_allocation,
            operations_allocation,
            reserve_allocation,
        ) = apply_sale(
            state,
            quantity,
            config.ticket_price,
            &config.sales_distribution,
            now_ts,
        );

        emit_purchase_event(
            ledger,
            lottery_id,
            buyer_addr,
            quantity,
            sale_amount,
            prize_allocation,
            jackpot_allocation,
            operations_allocation,
            reserve_allocation,
            state,
        );
    }

    fun borrow_or_create_state(
        ledger: &mut SalesLedger,
        lottery_id: u64,
        ticket_price: u64,
        distribution: &economics::SalesDistribution,
    ): &mut SalesState {
        if (!table::contains(&ledger.states, lottery_id)) {
            let state = SalesState {
                ticket_price,
                tickets_sold: 0,
                proceeds_accum: 0,
                last_purchase_ts: 0,
                next_chunk_seq: 0,
                tickets_per_address: table::new(),
                ticket_chunks: table::new(),
                distribution: copy *distribution,
                accounting: economics::new_accounting(),
            };
            table::add(&mut ledger.states, lottery_id, state);
        };
        table::borrow_mut(&mut ledger.states, lottery_id)
    }

    fun per_address_count(state: &SalesState, buyer: address): u64 {
        let table_ref = &state.tickets_per_address;
        if (table::contains(table_ref, buyer)) {
            *table::borrow(table_ref, buyer)
        } else {
            0
        }
    }

    fun update_per_address(state: &mut SalesState, buyer: address, current: u64, quantity: u64) {
        let table_ref = &mut state.tickets_per_address;
        let total = current + quantity;
        if (table::contains(table_ref, buyer)) {
            let count_ref = table::borrow_mut(table_ref, buyer);
            *count_ref = total;
        } else {
            table::add(table_ref, buyer, total);
        };
    }

    fun append_tickets(state: &mut SalesState, lottery_id: u64, buyer: address, quantity: u64) {
        let mut remaining = quantity;
        let mut inserted = 0u64;
        while (remaining > 0) {
            let chunk_seq = state.next_chunk_seq;
            if (!table::contains(&state.ticket_chunks, chunk_seq)) {
                let chunk = TicketChunk {
                    lottery_id,
                    chunk_seq,
                    start_index: state.tickets_sold + inserted,
                    buyers: vector::empty(),
                };
                table::add(&mut state.ticket_chunks, chunk_seq, chunk);
            };
            let mut advance_seq = false;
            {
                let chunk_ref = table::borrow_mut(&mut state.ticket_chunks, chunk_seq);
                let current_len = vector::length(&chunk_ref.buyers);
                if (current_len == CHUNK_CAPACITY) {
                    advance_seq = true;
                } else {
                    let capacity = CHUNK_CAPACITY - current_len;
                    let take = if (remaining < capacity) { remaining } else { capacity };
                    let mut idx = 0u64;
                    while (idx < take) {
                        vector::push_back(&mut chunk_ref.buyers, buyer);
                        idx = idx + 1;
                    };
                    inserted = inserted + take;
                    remaining = remaining - take;
                    if (vector::length(&chunk_ref.buyers) == CHUNK_CAPACITY) {
                        advance_seq = true;
                    };
                };
            };
            if (advance_seq) {
                state.next_chunk_seq = state.next_chunk_seq + 1;
            };
        };
    }

    public fun snapshot_for_draw(lottery_id: u64): (vector<u8>, u64, u64) acquires SalesLedger {
        let ledger_addr = @lottery_multi;
        if (!exists<SalesLedger>(ledger_addr)) {
            return (hash::sha3_256(b"lottery_multi::snapshot_empty"), 0, 0);
        };
        let ledger = borrow_global<SalesLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            return (hash::sha3_256(b"lottery_multi::snapshot_empty"), 0, 0);
        };
        let state = table::borrow(&ledger.states, lottery_id);
        let snapshot_hash = compute_snapshot_hash(state);
        (snapshot_hash, state.tickets_sold, state.proceeds_accum)
    }

    public fun accounting_snapshot(lottery_id: u64): economics::Accounting acquires SalesLedger {
        let ledger_addr = @lottery_multi;
        if (!exists<SalesLedger>(ledger_addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        let ledger = borrow_global<SalesLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::E_REGISTRY_MISSING;
        };
        let state = table::borrow(&ledger.states, lottery_id);
        copy state.accounting
    }

    public fun ticket_owner(lottery_id: u64, ticket_index: u64): address acquires SalesLedger {
        let ledger_addr = @lottery_multi;
        if (!exists<SalesLedger>(ledger_addr)) {
            abort errors::E_WINNER_INDEX_OUT_OF_RANGE;
        };
        let ledger = borrow_global<SalesLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::E_WINNER_INDEX_OUT_OF_RANGE;
        };
        let state = table::borrow(&ledger.states, lottery_id);
        if (ticket_index >= state.tickets_sold) {
            abort errors::E_WINNER_INDEX_OUT_OF_RANGE;
        };
        let mut seq = 0u64;
        while (seq <= state.next_chunk_seq) {
            if (table::contains(&state.ticket_chunks, seq)) {
                let chunk = table::borrow(&state.ticket_chunks, seq);
                let start = chunk.start_index;
                let len = vector::length(&chunk.buyers);
                if (ticket_index >= start && ticket_index < start + len) {
                    let offset = ticket_index - start;
                    let buyer = *vector::borrow(&chunk.buyers, offset);
                    return buyer;
                };
            };
            seq = seq + 1;
        };
        abort errors::E_WINNER_INDEX_OUT_OF_RANGE;
    }

    fun compute_snapshot_hash(state: &SalesState): vector<u8> {
        let mut digest = hash::sha3_256(b"lottery_multi::snapshot_seed");
        let mut seq = 0u64;
        while (seq < state.next_chunk_seq) {
            if (table::contains(&state.ticket_chunks, seq)) {
                let chunk = table::borrow(&state.ticket_chunks, seq);
                let tuple = (chunk.chunk_seq, chunk.start_index, copy chunk.buyers);
                let chunk_bytes = bcs::to_bytes(&tuple);
                let mut combined = copy digest;
                vector::append(&mut combined, chunk_bytes);
                digest = hash::sha3_256(combined);
            };
            seq = seq + 1;
        };
        let mut combined_totals = copy digest;
        let tickets_bytes = bcs::to_bytes(&state.tickets_sold);
        vector::append(&mut combined_totals, tickets_bytes);
        let proceeds_bytes = bcs::to_bytes(&state.proceeds_accum);
        vector::append(&mut combined_totals, proceeds_bytes);
        let distribution_bytes = bcs::to_bytes(&state.distribution);
        vector::append(&mut combined_totals, distribution_bytes);
        let accounting_bytes = bcs::to_bytes(&state.accounting);
        vector::append(&mut combined_totals, accounting_bytes);
        hash::sha3_256(combined_totals)
    }

    fun apply_sale(
        state: &mut SalesState,
        quantity: u64,
        ticket_price: u64,
        distribution: &economics::SalesDistribution,
        now_ts: u64,
    ): (u64, u64, u64, u64, u64) {
        let total_after = state.tickets_sold + quantity;
        state.tickets_sold = total_after;
        let sale_amount_u128 = (quantity as u128) * (ticket_price as u128);
        assert!(sale_amount_u128 <= 0xFFFFFFFFFFFFFFFF, errors::E_AMOUNT_OVERFLOW);
        let sale_amount = sale_amount_u128 as u64;
        state.proceeds_accum = state.proceeds_accum + sale_amount;
        state.last_purchase_ts = now_ts;
        let (prize, jackpot, operations, reserve) =
            economics::apply_sale(&mut state.accounting, sale_amount, distribution);
        (
            sale_amount,
            prize,
            jackpot,
            operations,
            reserve,
        )
    }

    fun emit_purchase_event(
        ledger: &mut SalesLedger,
        lottery_id: u64,
        buyer: address,
        quantity: u64,
        sale_amount: u64,
        prize_allocation: u64,
        jackpot_allocation: u64,
        operations_allocation: u64,
        reserve_allocation: u64,
        state: &SalesState,
    ) {
        let event = TicketPurchaseEvent {
            event_version: PURCHASE_EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_SALES,
            lottery_id,
            buyer,
            quantity,
            sale_amount,
            prize_allocation,
            jackpot_allocation,
            operations_allocation,
            reserve_allocation,
            tickets_sold: state.tickets_sold,
            proceeds_accum: state.proceeds_accum,
        };
        event::emit_event(&mut ledger.purchase_events, event);
    }

    fun assert_total_limit(state: &SalesState, limits: &types::TicketLimits, quantity: u64) {
        let total_limit = limits.max_tickets_total;
        if (total_limit > 0) {
            let total_after = state.tickets_sold + quantity;
            assert!(total_after <= total_limit, errors::E_PURCHASE_TOTAL_LIMIT);
        };
    }

    fun assert_address_limit(limits: &types::TicketLimits, current: u64, quantity: u64) {
        let per_limit = limits.max_tickets_per_address;
        if (per_limit > 0) {
            let sum = (current as u128) + (quantity as u128);
            assert!(sum <= (per_limit as u128), errors::E_PURCHASE_ADDRESS_LIMIT);
        };
    }

    fun borrow_ledger_mut(): &mut SalesLedger acquires SalesLedger {
        let addr = @lottery_multi;
        if (!exists<SalesLedger>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global_mut<SalesLedger>(addr)
    }
}
