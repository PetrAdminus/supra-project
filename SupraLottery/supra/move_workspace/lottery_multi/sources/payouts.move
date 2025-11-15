// sources/payouts.move
module lottery_multi::payouts {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::lottery_registry;
    use lottery_multi::math;
    use lottery_multi::roles;
    use lottery_multi::sales;
    use lottery_multi::types;

    const EVENT_CATEGORY_PAYOUT: u8 = 5;
    const EVENT_CATEGORY_REFUND: u8 = 8;
    const WINNER_EVENT_VERSION_V1: u16 = 1;
    const PAYOUT_EVENT_VERSION_V1: u16 = 1;
    const PARTNER_EVENT_VERSION_V1: u16 = 1;
    const REFUND_EVENT_VERSION_V1: u16 = 1;
    const WINNER_CHUNK_CAPACITY: u64 = 64;
    const MAX_REHASH_ATTEMPTS: u8 = 16;

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

    struct WinnerProgressView has copy, drop, store {
        initialized: bool,
        total_required: u64,
        total_assigned: u64,
        payout_round: u64,
        next_winner_batch_no: u64,
        last_payout_ts: u64,
    }

    struct PayoutLedger has key {
        states: table::Table<u64, WinnerState>,
        winner_events: event::EventHandle<history::WinnersComputedEvent>,
        payout_events: event::EventHandle<history::PayoutBatchEvent>,
        partner_events: event::EventHandle<history::PartnerPayoutEvent>,
        refund_events: event::EventHandle<history::RefundBatchEvent>,
    }

    public entry fun init_payouts(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(!exists<PayoutLedger>(addr), errors::err_already_initialized());
        let ledger = PayoutLedger {
            states: table::new(),
            winner_events: account::new_event_handle<history::WinnersComputedEvent>(admin),
            payout_events: account::new_event_handle<history::PayoutBatchEvent>(admin),
            partner_events: account::new_event_handle<history::PartnerPayoutEvent>(admin),
            refund_events: account::new_event_handle<history::RefundBatchEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun compute_winners_admin(
        admin: &signer,
        lottery_id: u64,
        batch_limit: u64,
    ) acquires PayoutLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());
        assert!(batch_limit > 0, errors::err_pagination_limit());

        let status = lottery_registry::get_status(lottery_id);
        assert!(
            status == types::status_drawn() || status == types::status_payout(),
            errors::err_draw_status_invalid(),
        );
        let prize_plan = lottery_registry::clone_prize_plan(lottery_id);
        let winners_dedup = lottery_registry::winners_dedup_enabled(lottery_id);
        let total_required = total_winners(&prize_plan);

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
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
            let seed = winner_hash_seed();
            let initial_checksum = hash::sha3_256(seed);
            types::winner_cursor_set_checksum(&mut state.cursor, &initial_checksum);
            state.winners_batch_hash = hash::sha3_256(b"lottery_multi::winner_batch_seed");
        };

        if (state.total_required == 0) {
            state.total_required = total_required;
        };
        assert!(state.total_required == total_required, errors::err_draw_status_invalid());

        if (state.total_assigned >= state.total_required) {
            abort errors::err_winner_all_assigned()
        };

        let remaining = state.total_required - state.total_assigned;
        let to_assign = if (batch_limit < remaining) { batch_limit } else { remaining };
        if (to_assign == 0) {
            abort errors::err_winner_all_assigned()
        };

        let assigned_in_batch = 0u64;
        let batch_no = state.next_winner_batch_no;
        let batch_hash = clone_bytes(&state.winners_batch_hash);
        let checksum = types::winner_cursor_checksum(&state.cursor);
        let ordinal = state.total_assigned;
        while (assigned_in_batch < to_assign) {
            let slot_ctx = slot_context(&prize_plan, ordinal);
            let slot_pos = slot_ctx.slot_position;
            let base_number = *vector::borrow(&state.random_numbers, slot_pos);
            let base_bytes = bcs::to_bytes(&base_number);
            let digest = derive_seed(
                &base_bytes,
                lottery_id,
                ordinal,
                slot_ctx.local_index,
                state,
            );
            let (ticket_index, updated_digest) = select_ticket_candidate(
                winners_dedup,
                state.total_tickets,
                &state.assigned_indices,
                digest,
            );
            digest = updated_digest;
            assert!(ticket_index < state.total_tickets, errors::err_winner_index_out_of_range());
            if (winners_dedup) {
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
        types::winner_cursor_set_last_index(&mut state.cursor, state.total_assigned);
        types::winner_cursor_set_checksum(&mut state.cursor, &checksum);
        state.winners_batch_hash = clone_bytes(&batch_hash);

        let cursor_checksum_for_record = types::winner_cursor_checksum(&state.cursor);
        draw::record_winner_hashes(lottery_id, &state.winners_batch_hash, &cursor_checksum_for_record);

        let event = history::new_winners_computed_event(
            lottery_id,
            batch_no,
            assigned_in_batch,
            state.total_assigned,
            clone_bytes(&state.winners_batch_hash),
            types::winner_cursor_checksum(&state.cursor),
        );
        event::emit_event(&mut ledger.winner_events, event);
        state.next_winner_batch_no = state.next_winner_batch_no + 1;

        if (state.total_assigned == state.total_required && status == types::status_drawn()) {
            lottery_registry::mark_payout(lottery_id);
        };
    }

    #[test_only]
    public fun test_read_winner_indices(lottery_id: u64): vector<u64> acquires PayoutLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            return vector::empty()
        };
        let state = table::borrow(&ledger.states, lottery_id);
        let winners = vector::empty<u64>();
        let seq = 0u64;
        while (seq <= state.next_chunk_seq) {
            if (table::contains(&state.winner_chunks, seq)) {
                let chunk = table::borrow(&state.winner_chunks, seq);
                let idx = 0;
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
    ) acquires PayoutLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());

        let status = lottery_registry::get_status(lottery_id);
        assert!(status == types::status_payout(), errors::err_draw_status_invalid());

        roles::consume_payout_batch_from_store(
            winners_paid,
            operations_paid,
            timestamp,
            payout_round,
        );

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::err_payout_state_missing()
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(payout_round == state.payout_round + 1, errors::err_payout_round_non_monotonic());
        if (state.last_payout_ts > 0) {
            assert!(timestamp >= state.last_payout_ts, errors::err_payout_cooldown());
        };
        state.payout_round = payout_round;
        state.last_payout_ts = timestamp;

        sales::record_payouts(lottery_id, prize_paid, operations_paid);

        let event = history::new_payout_batch_event(
            lottery_id,
            payout_round,
            winners_paid,
            prize_paid,
            operations_paid,
            timestamp,
        );
        event::emit_event(&mut ledger.payout_events, event);
    }

    public entry fun record_partner_payout_admin(
        admin: &signer,
        lottery_id: u64,
        partner: address,
        amount: u64,
        payout_round: u64,
        timestamp: u64,
    ) acquires PayoutLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());

        let status = lottery_registry::get_status(lottery_id);
        assert!(status == types::status_payout(), errors::err_draw_status_invalid());

        roles::consume_partner_payout_from_store(partner, amount, timestamp, payout_round);

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::err_payout_state_missing()
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(payout_round >= state.payout_round, errors::err_payout_round_non_monotonic());

        sales::record_payouts(lottery_id, 0, amount);

        let event = history::new_partner_payout_event(
            lottery_id,
            partner,
            amount,
            payout_round,
            timestamp,
        );
        event::emit_event(&mut ledger.partner_events, event);
    }

    public entry fun force_refund_batch_admin(
        admin: &signer,
        lottery_id: u64,
        refund_round: u64,
        tickets_refunded: u64,
        prize_refund: u64,
        operations_refund: u64,
        timestamp: u64,
    ) acquires PayoutLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());

        let status = lottery_registry::get_status(lottery_id);
        assert!(status == types::status_canceled(), errors::err_refund_status_invalid());

        roles::consume_payout_batch_from_store(
            tickets_refunded,
            operations_refund,
            timestamp,
            refund_round,
        );

        let (
            total_tickets_refunded,
            total_prize_refunded,
            total_operations_refunded,
        ) = sales::record_refund_batch(
            lottery_id,
            refund_round,
            tickets_refunded,
            prize_refund,
            operations_refund,
            timestamp,
        );
        let total_amount_refunded = total_prize_refunded + total_operations_refunded;

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
        let event = history::new_refund_batch_event(
            lottery_id,
            refund_round,
            tickets_refunded,
            prize_refund,
            operations_refund,
            total_tickets_refunded,
            total_amount_refunded,
            timestamp,
        );
        event::emit_event(&mut ledger.refund_events, event);
    }

    public entry fun archive_canceled_lottery_admin(
        admin: &signer,
        lottery_id: u64,
        finalized_at: u64,
    ) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());

        let status = lottery_registry::get_status(lottery_id);
        assert!(status == types::status_canceled(), errors::err_draw_status_invalid());

        let cancel_record_opt = lottery_registry::get_cancellation_record(lottery_id);
        if (!option::is_some(&cancel_record_opt)) {
            abort errors::err_cancellation_record_missing()
        };
        let cancel_record = option::destroy_some(cancel_record_opt);
        let canceled_ts = lottery_registry::cancellation_record_canceled_ts(&cancel_record);
        assert!(finalized_at >= canceled_ts, errors::err_refund_timestamp());
        let _unused = cancel_record;

        let has_sales = sales::has_state(lottery_id);
        let (tickets_sold, proceeds_accum, last_purchase_ts) = if (has_sales) {
            sales::sales_totals(lottery_id)
        } else {
            (0, 0, 0)
        };

        let accounting = if (has_sales) {
            sales::accounting_snapshot(lottery_id)
        } else {
            economics::new_accounting()
        };

        let refund_view = sales::refund_progress(lottery_id);
        let tickets_refunded = sales::refund_view_tickets_refunded(&refund_view);
        let refund_round = sales::refund_view_refund_round(&refund_view);
        let last_refund_ts = sales::refund_view_last_refund_ts(&refund_view);
        let prize_refunded = sales::refund_view_prize_refunded(&refund_view);
        let operations_refunded = sales::refund_view_operations_refunded(&refund_view);

        if (tickets_sold > 0) {
            assert!(tickets_refunded == tickets_sold, errors::err_refund_progress_incomplete());
            assert!(refund_round > 0, errors::err_refund_progress_incomplete());
            assert!(last_refund_ts > 0, errors::err_refund_progress_incomplete());
            let total_refunded = prize_refunded + operations_refunded;
            assert!(total_refunded >= proceeds_accum, errors::err_refund_progress_funds());
        };

        let slots_checksum = lottery_registry::slots_checksum(lottery_id);
        let draw_snapshot = if (draw::has_state(lottery_id)) {
            draw::finalization_snapshot(lottery_id)
        } else {
            let (snapshot_hash, _, _) = sales::snapshot_for_draw(lottery_id);
            draw::finalization_snapshot_placeholder(snapshot_hash, canceled_ts)
        };

        let event_slug = lottery_registry::event_slug(lottery_id);
        let series_code = lottery_registry::series_code(lottery_id);
        let run_id = lottery_registry::run_id(lottery_id);
        let primary_type = lottery_registry::primary_type(lottery_id);
        let tags_mask = lottery_registry::tags_mask(lottery_id);
        let created_at = lottery_registry::sales_start(lottery_id);
        let closed_ts = if (last_purchase_ts > 0) {
            last_purchase_ts
        } else {
            canceled_ts
        };

        let summary = history::new_summary(
            lottery_id,
            types::status_canceled(),
            event_slug,
            series_code,
            run_id,
            tickets_sold,
            proceeds_accum,
            economics::accounting_total_allocated(&accounting),
            economics::accounting_total_prize_paid(&accounting),
            economics::accounting_total_operations_paid(&accounting),
            draw::finalization_snapshot_vrf_status(&draw_snapshot),
            primary_type,
            tags_mask,
            draw::finalization_snapshot_snapshot_hash(&draw_snapshot),
            slots_checksum,
            draw::finalization_snapshot_winners_batch_hash(&draw_snapshot),
            draw::finalization_snapshot_checksum_after_batch(&draw_snapshot),
            refund_round,
            created_at,
            closed_ts,
            finalized_at,
        );
        history::record_summary(lottery_id, summary);
    }

    public entry fun finalize_lottery_admin(
        admin: &signer,
        lottery_id: u64,
        finalized_at: u64,
    ) acquires PayoutLedger {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery_multi, errors::err_registry_missing());

        let status = lottery_registry::get_status(lottery_id);
        assert!(status == types::status_payout(), errors::err_draw_status_invalid());

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<PayoutLedger>(ledger_addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            abort errors::err_payout_state_missing()
        };
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(state.total_required > 0, errors::err_finalization_incomplete());
        assert!(state.total_assigned == state.total_required, errors::err_finalization_incomplete());

        let (tickets_sold, proceeds_accum, last_purchase_ts) = sales::sales_totals(lottery_id);
        let draw_snapshot = draw::finalization_snapshot(lottery_id);
        let slots_checksum = lottery_registry::slots_checksum(lottery_id);
        let event_slug = lottery_registry::event_slug(lottery_id);
        let series_code = lottery_registry::series_code(lottery_id);
        let run_id = lottery_registry::run_id(lottery_id);
        let primary_type = lottery_registry::primary_type(lottery_id);
        let tags_mask = lottery_registry::tags_mask(lottery_id);
        let created_at = lottery_registry::sales_start(lottery_id);

        let closed_ts = if (last_purchase_ts > 0) {
            last_purchase_ts
        } else {
            draw::finalization_snapshot_request_ts(&draw_snapshot)
        };

        let accounting = sales::accounting_snapshot(lottery_id);

        let summary = history::new_summary(
            lottery_id,
            types::status_finalized(),
            event_slug,
            series_code,
            run_id,
            tickets_sold,
            proceeds_accum,
            economics::accounting_total_allocated(&accounting),
            economics::accounting_total_prize_paid(&accounting),
            economics::accounting_total_operations_paid(&accounting),
            draw::finalization_snapshot_vrf_status(&draw_snapshot),
            primary_type,
            tags_mask,
            draw::finalization_snapshot_snapshot_hash(&draw_snapshot),
            slots_checksum,
            draw::finalization_snapshot_winners_batch_hash(&draw_snapshot),
            draw::finalization_snapshot_checksum_after_batch(&draw_snapshot),
            state.payout_round,
            created_at,
            closed_ts,
            finalized_at,
        );
        history::record_summary(lottery_id, summary);
        lottery_registry::mark_finalized(lottery_id);
    }

    public fun winner_progress(lottery_id: u64): WinnerProgressView acquires PayoutLedger {
        let addr = @lottery_multi;
        if (!exists<PayoutLedger>(addr)) {
            return WinnerProgressView {
                initialized: false,
                total_required: 0,
                total_assigned: 0,
                payout_round: 0,
                next_winner_batch_no: 0,
                last_payout_ts: 0,
            }
        };
        let ledger = borrow_global<PayoutLedger>(@lottery_multi);
        if (!table::contains(&ledger.states, lottery_id)) {
            return WinnerProgressView {
                initialized: false,
                total_required: 0,
                total_assigned: 0,
                payout_round: 0,
                next_winner_batch_no: 0,
                last_payout_ts: 0,
            }
        };
        let state = table::borrow(&ledger.states, lottery_id);
        WinnerProgressView {
            initialized: state.initialized,
            total_required: state.total_required,
            total_assigned: state.total_assigned,
            payout_round: state.payout_round,
            next_winner_batch_no: state.next_winner_batch_no,
            last_payout_ts: state.last_payout_ts,
        }
    }

    //
    // Winner progress helpers (Move v1 compatibility)
    //

    public fun winner_progress_initialized(view: &WinnerProgressView): bool {
        view.initialized
    }

    public fun winner_progress_total_required(view: &WinnerProgressView): u64 {
        view.total_required
    }

    public fun winner_progress_total_assigned(view: &WinnerProgressView): u64 {
        view.total_assigned
    }

    public fun winner_progress_payout_round(view: &WinnerProgressView): u64 {
        view.payout_round
    }

    public fun winner_progress_next_batch(view: &WinnerProgressView): u64 {
        view.next_winner_batch_no
    }

    fun select_ticket_candidate(
        winners_dedup: bool,
        total_tickets: u64,
        assigned_indices: &table::Table<u64, bool>,
        digest_in: vector<u8>,
    ): (u64, vector<u8>) {
        let digest = digest_in;
        let attempts = 0u8;
        loop {
            let candidate = reduce_digest(&digest, total_tickets);
            if (!winners_dedup || !is_already_assigned(assigned_indices, candidate)) {
                return (candidate, digest)
            };
            attempts = attempts + 1;
            assert!(attempts < MAX_REHASH_ATTEMPTS, errors::err_winner_dedup_exhausted());
            digest = hash::sha3_256(copy digest);
        }
    }

    fun append_record(
        lottery_id: u64,
        state: &mut WinnerState,
        record: WinnerRecord,
        ordinal: u64,
    ) {
        let chunk_seq = state.next_chunk_seq;
        if (!table::contains(&state.winner_chunks, chunk_seq)) {
            let chunk = WinnerChunk {
                lottery_id,
                chunk_seq,
                start_ordinal: ordinal,
                records: vector::empty(),
            };
            table::add(&mut state.winner_chunks, chunk_seq, chunk);
        };
        let advance = false;
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
            let cursor = default_cursor();
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
                cursor,
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

    fun ledger_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<PayoutLedger>(addr)) {
            abort errors::err_registry_missing()
        };
        addr
    }

    struct SlotContext has copy, drop, store {
        slot_id: u64,
        slot_position: u64,
        local_index: u64,
    }

    fun slot_context(prize_plan: &vector<types::PrizeSlot>, ordinal: u64): SlotContext {
        let accumulated = 0u64;
        let len = vector::length(prize_plan);
        let idx = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            let winners_per_slot = math::widen_u64_from_u16(types::prize_slot_winners(slot));
            if (ordinal < accumulated + winners_per_slot) {
                return SlotContext {
                    slot_id: types::prize_slot_slot_id(slot),
                    slot_position: idx,
                    local_index: ordinal - accumulated,
                }
            };
            accumulated = accumulated + winners_per_slot;
            idx = idx + 1;
        };
        abort errors::err_winner_index_out_of_range()
    }

    fun total_winners(prize_plan: &vector<types::PrizeSlot>): u64 {
        let len = vector::length(prize_plan);
        let idx = 0;
        let total = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            total = total + math::widen_u64_from_u16(types::prize_slot_winners(slot));
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
        let data = clone_bytes(base_seed);
        vector::append(&mut data, clone_bytes(&state.snapshot_hash));
        vector::append(&mut data, clone_bytes(&state.payload_hash));
        vector::append(&mut data, bcs::to_bytes(&lottery_id));
        vector::append(&mut data, bcs::to_bytes(&ordinal));
        vector::append(&mut data, bcs::to_bytes(&local_index));
        let schema_version_u64 = math::widen_u64_from_u16(state.schema_version);
        vector::append(&mut data, bcs::to_bytes(&schema_version_u64));
        let attempt_u64 = math::widen_u64_from_u8(state.attempt);
        vector::append(&mut data, bcs::to_bytes(&attempt_u64));
        hash::sha3_256(data)
    }

    fun reduce_digest(digest: &vector<u8>, total_tickets: u64): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            let byte = *vector::borrow(digest, i);
            let shift =
                math::narrow_u8_from_u64(i * 8u64, errors::err_winner_index_out_of_range());
            value = value | (math::widen_u64_from_u8(byte) << shift);
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
        let data = clone_bytes(current);
        vector::append(&mut data, bcs::to_bytes(&ticket_index));
        vector::append(&mut data, clone_bytes(digest));
        hash::sha3_256(data)
    }

    fun update_batch_hash(
        current: &vector<u8>,
        slot_id: u64,
        ticket_index: u64,
        digest: &vector<u8>,
    ): vector<u8> {
        let data = clone_bytes(current);
        vector::append(&mut data, bcs::to_bytes(&slot_id));
        vector::append(&mut data, bcs::to_bytes(&ticket_index));
        vector::append(&mut data, clone_bytes(digest));
        hash::sha3_256(data)
    }

    fun default_cursor(): types::WinnerCursor {
        let cursor = types::winner_cursor_new();
        let seed = winner_hash_seed();
        let checksum = hash::sha3_256(seed);
        types::winner_cursor_set_checksum(&mut cursor, &checksum);
        cursor
    }

    fun winner_hash_seed(): vector<u8> {
        b"lottery_multi::winner_seed"
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let result = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(source, i);
            vector::push_back(&mut result, byte);
            i = i + 1;
        };
        result
    }
}
