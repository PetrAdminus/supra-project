// sources/payouts.move
module lottery_multi::payouts {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::event;

    use lottery_multi::draw;
    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::registry;
    use lottery_multi::roles;
    use lottery_multi::sales;
    use lottery_multi::types;

    const EVENT_CATEGORY_PAYOUT: u8 = history::EVENT_CATEGORY_PAYOUT;
    const WINNER_EVENT_VERSION_V1: u16 = 1;
    const PAYOUT_EVENT_VERSION_V1: u16 = 1;
    const PARTNER_EVENT_VERSION_V1: u16 = 1;
    const WINNER_CHUNK_CAPACITY: u64 = 64;
    const MAX_REHASH_ATTEMPTS: u8 = 16;
    const WINNER_HASH_SEED: vector<u8> = b"lottery_multi::winner_seed";

    struct WinnerRecord has copy, drop, store {
        slot_id: u64,
        ticket_index: u64,
        winner: address,
        winner_hash: vector<u8>,
    }

    struct WinnerChunk has store {
        lottery_id: u64,
        chunk_seq: u64,
        start_ordinal: u64,
        records: vector<WinnerRecord>,
    }

    struct WinnerState has store {
        initialized: bool,
        total_required: u64,
        total_assigned: u64,
        total_tickets: u64,
        snapshot_hash: vector<u8>,
        payload_hash: vector<u8>,
        schema_version: u16,
        attempt: u8,
        random_numbers: vector<u256>,
        winners_batch_hash: vector<u8>,
        cursor: types::WinnerCursor,
        next_chunk_seq: u64,
        winner_chunks: table::Table<u64, WinnerChunk>,
        assigned_indices: table::Table<u64, bool>,
        payout_round: u64,
        last_payout_ts: u64,
        next_winner_batch_no: u64,
    }

    struct PayoutLedger has key {
        states: table::Table<u64, WinnerState>,
        winner_events: event::EventHandle<history::WinnersComputedEvent>,
        payout_events: event::EventHandle<history::PayoutBatchEvent>,
        partner_events: event::EventHandle<history::PartnerPayoutEvent>,
    }

    public entry fun init_payouts(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(!exists<PayoutLedger>(addr), errors::E_ALREADY_INITIALIZED);
        let ledger = PayoutLedger {
            states: table::new(),
            winner_events: event::new_event_handle<history::WinnersComputedEvent>(admin),
            payout_events: event::new_event_handle<history::PayoutBatchEvent>(admin),
            partner_events: event::new_event_handle<history::PartnerPayoutEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun compute_winners_admin(
        admin: &signer,
        lottery_id: u64,
        batch_limit: u64,
    ) acquires PayoutLedger, registry::Registry, sales::SalesLedger, draw::DrawLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(batch_limit > 0, errors::E_PAGINATION_LIMIT);

        let status = registry::get_status(lottery_id);
        assert!(
            status == types::STATUS_DRAWN || status == types::STATUS_PAYOUT,
            errors::E_DRAW_STATUS_INVALID,
        );
        let config = registry::borrow_config(lottery_id);
        let total_required = total_winners(&config.prize_plan);

        let ledger = borrow_ledger_mut();
        let state = borrow_or_create_state(&mut ledger.states, lottery_id);
        if (!state.initialized) {
            let (
                numbers,
                snapshot_hash,
                payload_hash,
                total_tickets,
                schema_version,
                attempt,
            ) = draw::prepare_for_winner_computation(lottery_id);
            state.initialized = true;
            state.total_tickets = total_tickets;
            state.snapshot_hash = snapshot_hash;
            state.payload_hash = payload_hash;
            state.random_numbers = numbers;
            state.schema_version = schema_version;
            state.attempt = attempt;
            state.cursor.checksum_after_batch = hash::sha3_256(copy WINNER_HASH_SEED);
            state.winners_batch_hash = hash::sha3_256(b"lottery_multi::winner_batch_seed");
        };

        if (state.total_required == 0) {
            state.total_required = total_required;
        };
        assert!(state.total_required == total_required, errors::E_DRAW_STATUS_INVALID);

        if (state.total_assigned >= state.total_required) {
            abort errors::E_WINNER_ALL_ASSIGNED;
        };

        let remaining = state.total_required - state.total_assigned;
        let mut to_assign = if (batch_limit < remaining) { batch_limit } else { remaining };
        if (to_assign == 0) {
            abort errors::E_WINNER_ALL_ASSIGNED;
        };

        let mut assigned_in_batch = 0u64;
        let batch_no = state.next_winner_batch_no;
        let mut batch_hash = copy state.winners_batch_hash;
        let mut checksum = copy state.cursor.checksum_after_batch;
        let mut ordinal = state.total_assigned;
        while (assigned_in_batch < to_assign) {
            let slot_ctx = slot_context(&config.prize_plan, ordinal);
            let slot_pos = slot_ctx.slot_position;
            let base_number = *vector::borrow(&state.random_numbers, slot_pos);
            let base_bytes = bcs::to_bytes(&base_number);
            let mut digest = derive_seed(
                &base_bytes,
                lottery_id,
                ordinal,
                slot_ctx.local_index,
                state,
            );
            let mut attempts = 0u8;
            let ticket_index = loop {
                let candidate = reduce_digest(&digest, state.total_tickets);
                if (!config.winners_dedup || !is_already_assigned(&state.assigned_indices, candidate)) {
                    break candidate;
                };
                attempts = attempts + 1;
                assert!(attempts < MAX_REHASH_ATTEMPTS, errors::E_WINNER_DEDUP_EXHAUSTED);
                digest = hash::sha3_256(copy digest);
            };
            assert!(ticket_index < state.total_tickets, errors::E_WINNER_INDEX_OUT_OF_RANGE);
            if (config.winners_dedup) {
                table::add(&mut state.assigned_indices, ticket_index, true);
            };
            let winner = sales::ticket_owner(lottery_id, ticket_index);
            let record = WinnerRecord {
                slot_id: slot_ctx.slot_id,
                ticket_index,
                winner,
                winner_hash: copy digest,
            };
            append_record(lottery_id, state, record, ordinal);
            assigned_in_batch = assigned_in_batch + 1;
            ordinal = ordinal + 1;
            checksum = update_checksum(&checksum, ticket_index, &digest);
            batch_hash = update_batch_hash(&batch_hash, slot_ctx.slot_id, ticket_index, &digest);
        };

        state.total_assigned = state.total_assigned + assigned_in_batch;
        state.cursor.last_processed_index = state.total_assigned;
        state.cursor.checksum_after_batch = copy checksum;
        state.winners_batch_hash = copy batch_hash;

        draw::record_winner_hashes(lottery_id, &state.winners_batch_hash, &state.cursor.checksum_after_batch);

        let event = history::WinnersComputedEvent {
            event_version: WINNER_EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            batch_no,
            assigned_in_batch,
            total_assigned: state.total_assigned,
            winners_batch_hash: copy state.winners_batch_hash,
            checksum_after_batch: copy state.cursor.checksum_after_batch,
        };
        event::emit_event(&mut ledger.winner_events, event);
        state.next_winner_batch_no = state.next_winner_batch_no + 1;

        if (state.total_assigned == state.total_required && status == types::STATUS_DRAWN) {
            registry::mark_payout(lottery_id);
        };
    }

    #[test_only]
    public fun test_read_winner_indices(lottery_id: u64): vector<u64> acquires PayoutLedger {
        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.states, lottery_id)) {
            return vector::empty();
        };
        let state = table::borrow(&ledger.states, lottery_id);
        let mut winners = vector::empty<u64>();
        let mut seq = 0u64;
        while (seq <= state.next_chunk_seq) {
            if (table::contains(&state.winner_chunks, seq)) {
                let chunk = table::borrow(&state.winner_chunks, seq);
                let mut idx = 0;
                let len = vector::length(&chunk.records);
                while (idx < len) {
                    let record = vector::borrow(&chunk.records, idx);
                    vector::push_back(&mut winners, record.ticket_index);
                    idx = idx + 1;
                };
            };
            seq = seq + 1;
        };
        winners
    }

    public entry fun record_payout_batch_admin(
        admin: &signer,
        lottery_id: u64,
        payout_round: u64,
        winners_paid: u64,
        prize_paid: u64,
        operations_paid: u64,
        timestamp: u64,
    ) acquires PayoutLedger, registry::Registry, sales::SalesLedger, roles::RoleStore {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::E_REGISTRY_MISSING);

        let status = registry::get_status(lottery_id);
        assert!(status == types::STATUS_PAYOUT || status == types::STATUS_FINALIZED, errors::E_DRAW_STATUS_INVALID);

        let batch_cap = roles::borrow_payout_batch_cap_mut();
        roles::consume_payout_batch(batch_cap, winners_paid, operations_paid, timestamp, payout_round);

        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::E_PAYOUT_STATE_MISSING;
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(payout_round == state.payout_round + 1, errors::E_PAYOUT_ROUND_NON_MONOTONIC);
        if (state.last_payout_ts > 0) {
            assert!(timestamp >= state.last_payout_ts, errors::E_PAYOUT_COOLDOWN);
        };
        state.payout_round = payout_round;
        state.last_payout_ts = timestamp;

        sales::record_payouts(lottery_id, prize_paid, operations_paid);

        let event = history::PayoutBatchEvent {
            event_version: PAYOUT_EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            payout_round,
            winners_paid,
            prize_paid,
            operations_paid,
            timestamp,
        };
        event::emit_event(&mut ledger.payout_events, event);
    }

    public entry fun record_partner_payout_admin(
        admin: &signer,
        lottery_id: u64,
        partner: address,
        amount: u64,
        payout_round: u64,
        timestamp: u64,
    ) acquires PayoutLedger, registry::Registry, sales::SalesLedger, roles::RoleStore {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::E_REGISTRY_MISSING);

        let status = registry::get_status(lottery_id);
        assert!(status == types::STATUS_PAYOUT || status == types::STATUS_FINALIZED, errors::E_DRAW_STATUS_INVALID);

        let partner_cap = roles::borrow_partner_payout_cap_mut(partner);
        roles::consume_partner_payout(partner_cap, amount, timestamp, payout_round);

        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::E_PAYOUT_STATE_MISSING;
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(payout_round >= state.payout_round, errors::E_PAYOUT_ROUND_NON_MONOTONIC);

        sales::record_payouts(lottery_id, 0, amount);

        let event = history::PartnerPayoutEvent {
            event_version: PARTNER_EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            partner,
            amount,
            payout_round,
            timestamp,
        };
        event::emit_event(&mut ledger.partner_events, event);
    }

    public entry fun finalize_lottery_admin(
        admin: &signer,
        lottery_id: u64,
        finalized_at: u64,
    ) acquires PayoutLedger, registry::Registry, sales::SalesLedger, draw::DrawLedger, history::ArchiveLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::E_REGISTRY_MISSING);

        let status = registry::get_status(lottery_id);
        assert!(status == types::STATUS_PAYOUT, errors::E_DRAW_STATUS_INVALID);

        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::E_PAYOUT_STATE_MISSING;
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(state.total_required > 0, errors::E_FINALIZATION_INCOMPLETE);
        assert!(state.total_assigned == state.total_required, errors::E_FINALIZATION_INCOMPLETE);

        let (tickets_sold, proceeds_accum, last_purchase_ts) = sales::sales_totals(lottery_id);
        let config = registry::borrow_config(lottery_id);
        let draw_snapshot = draw::finalization_snapshot(lottery_id);
        let slots_checksum = registry::slots_checksum(lottery_id);

        let closed_ts = if (last_purchase_ts > 0) { last_purchase_ts } else { draw_snapshot.request_ts };

        let accounting = sales::accounting_snapshot(lottery_id);

        let summary = history::LotterySummary {
            id: lottery_id,
            status: types::STATUS_FINALIZED,
            event_slug: copy config.event_slug,
            series_code: copy config.series_code,
            run_id: config.run_id,
            tickets_sold,
            proceeds_accum,
            total_allocated: accounting.total_allocated,
            total_prize_paid: accounting.total_prize_paid,
            total_operations_paid: accounting.total_operations_paid,
            vrf_status: draw_snapshot.vrf_status,
            primary_type: config.primary_type,
            tags_mask: config.tags_mask,
            snapshot_hash: copy draw_snapshot.snapshot_hash,
            slots_checksum,
            winners_batch_hash: copy draw_snapshot.winners_batch_hash,
            checksum_after_batch: copy draw_snapshot.checksum_after_batch,
            payout_round: state.payout_round,
            created_at: config.sales_window.sales_start,
            closed_at: closed_ts,
            finalized_at,
        };
        history::record_summary(lottery_id, summary);
        registry::mark_finalized(lottery_id);
    }

    fun append_record(
        lottery_id: u64,
        state: &mut WinnerState,
        record: WinnerRecord,
        ordinal: u64,
    ) {
        let mut chunk_seq = state.next_chunk_seq;
        if (!table::contains(&state.winner_chunks, chunk_seq)) {
            let chunk = WinnerChunk {
                lottery_id,
                chunk_seq,
                start_ordinal: ordinal,
                records: vector::empty(),
            };
            table::add(&mut state.winner_chunks, chunk_seq, chunk);
        };
        let mut advance = false;
        {
            let chunk = table::borrow_mut(&mut state.winner_chunks, chunk_seq);
            if (vector::length(&chunk.records) == WINNER_CHUNK_CAPACITY) {
                advance = true;
            } else {
                vector::push_back(&mut chunk.records, record);
                if (vector::length(&chunk.records) == WINNER_CHUNK_CAPACITY) {
                    advance = true;
                };
            };
        };
        if (advance) {
            state.next_chunk_seq = state.next_chunk_seq + 1;
        };
    }

    fun borrow_or_create_state(
        states: &mut table::Table<u64, WinnerState>,
        lottery_id: u64,
    ): &mut WinnerState {
        if (!table::contains(states, lottery_id)) {
            let state = WinnerState {
                initialized: false,
                total_required: 0,
                total_assigned: 0,
                total_tickets: 0,
                snapshot_hash: b"",
                payload_hash: b"",
                schema_version: 0,
                attempt: 0,
                random_numbers: vector::empty(),
                winners_batch_hash: hash::sha3_256(b"lottery_multi::winner_batch_seed"),
                cursor: types::WinnerCursor {
                    last_processed_index: 0,
                    checksum_after_batch: hash::sha3_256(copy WINNER_HASH_SEED),
                },
                next_chunk_seq: 0,
                winner_chunks: table::new(),
                assigned_indices: table::new(),
                payout_round: 0,
                last_payout_ts: 0,
                next_winner_batch_no: 0,
            };
            table::add(states, lottery_id, state);
        };
        table::borrow_mut(states, lottery_id)
    }

    fun borrow_ledger_mut(): &mut PayoutLedger acquires PayoutLedger {
        let addr = @lottery_multi;
        if (!exists<PayoutLedger>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global_mut<PayoutLedger>(addr)
    }

    struct SlotContext has copy, drop, store {
        slot_id: u64,
        slot_position: u64,
        local_index: u64,
    }

    fun slot_context(prize_plan: &vector<types::PrizeSlot>, ordinal: u64): SlotContext {
        let mut accumulated = 0u64;
        let len = vector::length(prize_plan);
        let mut idx = 0u64;
        while (idx < (len as u64)) {
            let slot = vector::borrow(prize_plan, idx);
            let winners_per_slot = slot.winners_per_slot as u64;
            if (ordinal < accumulated + winners_per_slot) {
                return SlotContext {
                    slot_id: slot.slot_id,
                    slot_position: idx,
                    local_index: ordinal - accumulated,
                };
            };
            accumulated = accumulated + winners_per_slot;
            idx = idx + 1;
        };
        abort errors::E_WINNER_INDEX_OUT_OF_RANGE;
    }

    fun total_winners(prize_plan: &vector<types::PrizeSlot>): u64 {
        let len = vector::length(prize_plan);
        let mut idx = 0;
        let mut total = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            total = total + (slot.winners_per_slot as u64);
            idx = idx + 1;
        };
        total
    }

    fun derive_seed(
        base_seed: &vector<u8>,
        lottery_id: u64,
        ordinal: u64,
        local_index: u64,
        state: &WinnerState,
    ): vector<u8> {
        let mut data = copy *base_seed;
        vector::append(&mut data, state.snapshot_hash);
        vector::append(&mut data, state.payload_hash);
        vector::append(&mut data, bcs::to_bytes(&lottery_id));
        vector::append(&mut data, bcs::to_bytes(&ordinal));
        vector::append(&mut data, bcs::to_bytes(&local_index));
        vector::append(&mut data, bcs::to_bytes(&(state.schema_version as u64)));
        vector::append(&mut data, bcs::to_bytes(&(state.attempt as u64)));
        hash::sha3_256(data)
    }

    fun reduce_digest(digest: &vector<u8>, total_tickets: u64): u64 {
        let mut value = 0u64;
        let mut i = 0u64;
        while (i < 8) {
            let byte = *vector::borrow(digest, i);
            value = value | ((byte as u64) << (i * 8));
            i = i + 1;
        };
        value % total_tickets
    }

    fun is_already_assigned(
        assigned: &table::Table<u64, bool>,
        ticket_index: u64,
    ): bool {
        table::contains(assigned, ticket_index)
    }

    fun update_checksum(
        current: &vector<u8>,
        ticket_index: u64,
        digest: &vector<u8>,
    ): vector<u8> {
        let mut data = copy *current;
        vector::append(&mut data, bcs::to_bytes(&ticket_index));
        vector::append(&mut data, copy *digest);
        hash::sha3_256(data)
    }

    fun update_batch_hash(
        current: &vector<u8>,
        slot_id: u64,
        ticket_index: u64,
        digest: &vector<u8>,
    ): vector<u8> {
        let mut data = copy *current;
        vector::append(&mut data, bcs::to_bytes(&slot_id));
        vector::append(&mut data, bcs::to_bytes(&ticket_index));
        vector::append(&mut data, copy *digest);
        hash::sha3_256(data)
    }
}
