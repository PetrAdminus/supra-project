module lottery_utils::history {
    use lottery_data::rounds;
    use std::bcs;
    use std::hash;
    use std::option;
    use std::signer;
    use std::timestamp;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const MAX_HISTORY_LENGTH: u64 = 128;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_CAPS_UNAVAILABLE: u64 = 4;
    const E_CAPS_NOT_READY: u64 = 5;
    const E_DUAL_WRITE_NOT_INITIALIZED: u64 = 6;
    const E_EXPECTED_HASH_NOT_FOUND: u64 = 7;
    const E_EXPECTED_HASH_MISMATCH: u64 = 8;
    const E_ARCHIVE_NOT_INITIALIZED: u64 = 9;
    const E_ARCHIVE_ID_MISMATCH: u64 = 10;
    const E_ARCHIVE_HASH_MISMATCH: u64 = 11;
    const E_ARCHIVE_UNKNOWN_SUMMARY: u64 = 12;
    const E_ARCHIVE_NOT_LEGACY: u64 = 13;
    const E_PAGINATION_TOO_LARGE: u64 = 14;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_MIGRATION: u8 = 8;
    const EVENT_CATEGORY_ARCHIVE: u8 = 2;
    const MAX_ARCHIVE_PAGE: u64 = 1000;

    struct LotteryHistory has store {
        records: vector<DrawRecord>,
    }

    struct HistoryCollection has key {
        admin: address,
        histories: table::Table<u64, LotteryHistory>,
        lottery_ids: vector<u64>,
        record_events: event::EventHandle<DrawRecordedEvent>,
        snapshot_events: event::EventHandle<HistorySnapshotUpdatedEvent>,
    }

    struct HistoryWarden has key {
        writer: rounds::HistoryWriterCap,
    }

    #[event]
    struct ArchiveDualWriteStartedEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        expected_hash: vector<u8>,
    }

    #[event]
    struct ArchiveDualWriteCompletedEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    #[event]
    struct LotteryFinalizedEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        id: u64,
        archive_slot_hash: vector<u8>,
        primary_type: u8,
        tags_mask: u64,
    }

    #[event]
    struct LegacySummaryImportedEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
    }

    #[event]
    struct LegacySummaryRolledBackEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
    }

    #[event]
    struct LegacySummaryClassificationUpdatedEvent has drop, store, copy {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        primary_type: u8,
        tags_mask: u64,
    }

    #[event]
    struct LegacySummaryEvent has drop, store, copy {
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    struct LotterySummary has copy, drop, store {
        id: u64,
        status: u8,
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        tickets_sold: u64,
        proceeds_accum: u64,
        total_allocated: u64,
        total_prize_paid: u64,
        total_operations_paid: u64,
        vrf_status: u8,
        primary_type: u8,
        tags_mask: u64,
        snapshot_hash: vector<u8>,
        slots_checksum: vector<u8>,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
        payout_round: u64,
        created_at: u64,
        closed_at: u64,
        finalized_at: u64,
    }

    struct ArchiveLedger has key {
        summaries: table::Table<u64, LotterySummary>,
        imported_flags: table::Table<u64, bool>,
        ordered_ids: vector<u64>,
        finalized_events: event::EventHandle<LotteryFinalizedEvent>,
        import_events: event::EventHandle<LegacySummaryImportedEvent>,
        rollback_events: event::EventHandle<LegacySummaryRolledBackEvent>,
        classification_events: event::EventHandle<LegacySummaryClassificationUpdatedEvent>,
    }

    struct LegacySummary has copy, drop, store {
        summary_bcs: vector<u8>,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    struct LegacyArchive has key {
        summaries: table::Table<u64, LegacySummary>,
        summary_events: event::EventHandle<LegacySummaryEvent>,
    }

    struct DrawRecord has copy, drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
        timestamp_seconds: u64,
    }

    struct LegacyHistoryRecord has drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
        timestamp_seconds: u64,
    }

    struct LotteryHistorySnapshot has copy, drop, store {
        lottery_id: u64,
        records: vector<DrawRecord>,
    }

    struct HistorySnapshot has copy, drop, store {
        admin: address,
        lottery_ids: vector<u64>,
        histories: vector<LotteryHistorySnapshot>,
    }

    #[event]
    struct DrawRecordedEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        timestamp_seconds: u64,
    }

    #[event]
    struct HistorySnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<HistorySnapshot>,
        current: HistorySnapshot,
    }

    struct DualWriteStatus has copy, drop, store {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hash: option::Option<vector<u8>>,
    }

    struct DualWriteControl has key {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hashes: table::Table<u64, vector<u8>>,
        started_events: event::EventHandle<ArchiveDualWriteStartedEvent>,
        completed_events: event::EventHandle<ArchiveDualWriteCompletedEvent>,
    }

    public struct LegacyDualWriteExpectation has drop, store {
        lottery_id: u64,
        expected_hash: vector<u8>,
    }

    public struct LegacyDualWriteState has drop, store {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expectations: vector<LegacyDualWriteExpectation>,
    }

    public entry fun init(caller: &signer)
    acquires HistoryCollection, HistoryWarden, rounds::RoundControl {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<HistoryCollection>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            HistoryCollection {
                admin: addr,
                histories: table::new<u64, LotteryHistory>(),
                lottery_ids: vector::empty<u64>(),
                record_events: account::new_event_handle<DrawRecordedEvent>(caller),
                snapshot_events: account::new_event_handle<HistorySnapshotUpdatedEvent>(caller),
            },
        );
        emit_initial_snapshot();
        ensure_caps_initialized(caller);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<HistoryCollection>(@lottery)
    }

    #[view]
    public fun caps_ready(): bool {
        exists<HistoryWarden>(@lottery)
    }

    public entry fun set_admin(caller: &signer, new_admin: address)
    acquires HistoryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        state.admin = new_admin;
        emit_history_snapshot_with_previous(state, previous);
    }

    public entry fun clear_history(caller: &signer, lottery_id: u64)
    acquires HistoryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            return;
        };
        let previous = option::some(build_snapshot_from_mut(state));
        let history = table::borrow_mut(&mut state.histories, lottery_id);
        clear_records(&mut history.records);
        emit_history_snapshot_with_previous(state, previous);
    }

    public entry fun init_archive(caller: &signer)
    acquires ArchiveLedger, HistoryCollection {
        ensure_admin(caller);
        if (exists<ArchiveLedger>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            ArchiveLedger {
                summaries: table::new<u64, LotterySummary>(),
                imported_flags: table::new<u64, bool>(),
                ordered_ids: vector::empty<u64>(),
                finalized_events: account::new_event_handle<LotteryFinalizedEvent>(caller),
                import_events: account::new_event_handle<LegacySummaryImportedEvent>(caller),
                rollback_events: account::new_event_handle<LegacySummaryRolledBackEvent>(caller),
                classification_events: account::new_event_handle<LegacySummaryClassificationUpdatedEvent>(caller),
            },
        );
    }

    public entry fun init_legacy_archive(caller: &signer)
    acquires HistoryCollection, LegacyArchive {
        ensure_admin(caller);
        if (exists<LegacyArchive>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            LegacyArchive {
                summaries: table::new<u64, LegacySummary>(),
                summary_events: account::new_event_handle<LegacySummaryEvent>(caller),
            },
        );
    }

    public entry fun record_archive_summary(caller: &signer, summary: LotterySummary)
    acquires ArchiveLedger, DualWriteControl, HistoryCollection, LegacyArchive {
        ensure_admin(caller);
        ensure_archive_initialized();
        let summary_bytes = bcs::to_bytes(&summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        let hash_for_store = clone_bytes(&archive_hash);
        let hash_for_legacy = clone_bytes(&archive_hash);
        store_archive_summary(summary.id, summary, hash_for_store, false);
        mirror_summary_to_legacy(summary_bytes, hash_for_legacy, summary.finalized_at);
        notify_summary_written(summary.id, &archive_hash, summary.finalized_at);
    }

    public entry fun import_legacy_summary(
        caller: &signer,
        lottery_id: u64,
        summary_bytes: vector<u8>,
        expected_hash: vector<u8>,
    ) acquires ArchiveLedger, DualWriteControl, HistoryCollection, LegacyArchive {
        ensure_admin(caller);
        ensure_archive_initialized();
        let summary = bcs::from_bytes<LotterySummary>(&summary_bytes);
        if (summary.id != lottery_id) {
            abort E_ARCHIVE_ID_MISMATCH;
        };
        let computed_hash = hash::sha3_256(copy summary_bytes);
        if (computed_hash != expected_hash) {
            abort E_ARCHIVE_HASH_MISMATCH;
        };
        let hash_for_store = clone_bytes(&computed_hash);
        let hash_for_legacy = clone_bytes(&computed_hash);
        let hash_for_notify = clone_bytes(&computed_hash);
        store_archive_summary(lottery_id, summary, hash_for_store, true);
        mirror_summary_to_legacy(summary_bytes, hash_for_legacy, summary.finalized_at);
        notify_summary_written(lottery_id, &hash_for_notify, summary.finalized_at);
        emit_legacy_import_event(lottery_id, computed_hash, summary.finalized_at, summary.primary_type, summary.tags_mask);
    }

    public entry fun rollback_legacy_summary(caller: &signer, lottery_id: u64)
    acquires ArchiveLedger, HistoryCollection {
        ensure_admin(caller);
        ensure_archive_initialized();
        let ledger = borrow_global_mut<ArchiveLedger>(@lottery);
        if (!table::contains(&ledger.imported_flags, lottery_id)) {
            abort E_ARCHIVE_UNKNOWN_SUMMARY;
        };
        let imported_flag = table::borrow(&ledger.imported_flags, lottery_id);
        if (!*imported_flag) {
            abort E_ARCHIVE_NOT_LEGACY;
        };
        let stored_ref = table::borrow(&ledger.summaries, lottery_id);
        let stored_copy = clone_summary(stored_ref);
        let archive_hash = hash::sha3_256(bcs::to_bytes(&stored_copy));
        let finalized_at = stored_copy.finalized_at;
        let primary_type = stored_copy.primary_type;
        let tags_mask = stored_copy.tags_mask;
        let _removed_summary = table::remove(&mut ledger.summaries, lottery_id);
        let _removed_flag = table::remove(&mut ledger.imported_flags, lottery_id);
        let _ = _removed_summary;
        let _ = _removed_flag;
        remove_archive_id(&mut ledger.ordered_ids, lottery_id);
        emit_legacy_rollback_event(lottery_id, archive_hash, finalized_at, primary_type, tags_mask, ledger);
    }

    public entry fun update_legacy_classification(
        caller: &signer,
        lottery_id: u64,
        primary_type: u8,
        tags_mask: u64,
    ) acquires ArchiveLedger, HistoryCollection, LegacyArchive {
        ensure_admin(caller);
        ensure_archive_initialized();
        let ledger = borrow_global_mut<ArchiveLedger>(@lottery);
        if (!table::contains(&ledger.summaries, lottery_id)) {
            abort E_ARCHIVE_UNKNOWN_SUMMARY;
        };
        let imported_ref = table::borrow(&ledger.imported_flags, lottery_id);
        if (!*imported_ref) {
            abort E_ARCHIVE_NOT_LEGACY;
        };
        let summary = table::borrow_mut(&mut ledger.summaries, lottery_id);
        summary.primary_type = primary_type;
        summary.tags_mask = tags_mask;
        let summary_bytes = bcs::to_bytes(&*summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        mirror_summary_to_legacy(summary_bytes, archive_hash, summary.finalized_at);
        emit_classification_event(lottery_id, archive_hash, primary_type, tags_mask, ledger);
    }

    public entry fun init_caps(caller: &signer)
    acquires HistoryCollection, HistoryWarden, rounds::RoundControl {
        ensure_admin(caller);
        ensure_caps_initialized(caller);
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_CAPS_UNAVAILABLE;
        };
    }

    public entry fun release_caps(caller: &signer)
    acquires HistoryCollection, HistoryWarden, rounds::RoundControl {
        ensure_admin(caller);
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let HistoryWarden { writer } = move_from<HistoryWarden>(@lottery);
        let control = rounds::borrow_control_mut(@lottery);
        rounds::restore_history_cap(control, writer);
    }

    public entry fun init_dual_write(
        caller: &signer,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) acquires DualWriteControl, HistoryCollection {
        ensure_admin(caller);
        if (exists<DualWriteControl>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            DualWriteControl {
                enabled: true,
                abort_on_mismatch,
                abort_on_missing,
                expected_hashes: table::new<u64, vector<u8>>(),
                started_events: account::new_event_handle<ArchiveDualWriteStartedEvent>(caller),
                completed_events: account::new_event_handle<ArchiveDualWriteCompletedEvent>(caller),
            },
        );
    }

    public entry fun update_dual_write_flags(
        caller: &signer,
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) acquires DualWriteControl, HistoryCollection {
        ensure_admin(caller);
        ensure_dual_write_initialized();
        let control = borrow_global_mut<DualWriteControl>(@lottery);
        control.enabled = enabled;
        control.abort_on_mismatch = abort_on_mismatch;
        control.abort_on_missing = abort_on_missing;
    }

    public entry fun set_expected_hash(
        caller: &signer,
        lottery_id: u64,
        expected_hash: vector<u8>,
    ) acquires DualWriteControl, HistoryCollection {
        ensure_admin(caller);
        ensure_dual_write_initialized();
        let control = borrow_global_mut<DualWriteControl>(@lottery);
        upsert_expected_hash(control, lottery_id, expected_hash);
    }

    public entry fun clear_expected_hash(caller: &signer, lottery_id: u64)
    acquires DualWriteControl, HistoryCollection {
        ensure_admin(caller);
        ensure_dual_write_initialized();
        let control = borrow_global_mut<DualWriteControl>(@lottery);
        if (!table::contains(&control.expected_hashes, lottery_id)) {
            return;
        };
        let _removed = table::remove(&mut control.expected_hashes, lottery_id);
        let _ = _removed;
    }

    public entry fun import_existing_dual_write_state(
        caller: &signer,
        state: LegacyDualWriteState,
    ) acquires DualWriteControl, HistoryCollection {
        ensure_admin(caller);
        apply_legacy_dual_write_state(caller, state);
    }

    public entry fun record_draw_from_rounds(
        caller: &signer,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) acquires HistoryCollection, HistoryWarden {
        ensure_admin(caller);
        ensure_caps_ready();
        let warden = borrow_global<HistoryWarden>(@lottery);
        record_draw_internal(
            &warden.writer,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        );
    }

    public entry fun sync_draws_from_rounds(caller: &signer, limit: u64)
    acquires HistoryCollection, HistoryWarden, rounds::PendingHistoryQueue {
        ensure_admin(caller);
        ensure_caps_ready();
        let warden = borrow_global<HistoryWarden>(@lottery);
        let cap_ref = &warden.writer;
        let mut pending = rounds::drain_history_queue(cap_ref, limit);
        replay_pending_records(cap_ref, &mut pending);
    }

    public entry fun import_existing_history_record(
        caller: &signer,
        record: LegacyHistoryRecord,
    ) acquires HistoryCollection {
        ensure_admin(caller);
        append_imported_history_record(record);
    }

    public entry fun import_existing_history_batch(
        caller: &signer,
        mut records: vector<LegacyHistoryRecord>,
    ) acquires HistoryCollection {
        ensure_admin(caller);
        import_history_batch_recursive(&mut records);
    }

    #[view]
    public fun dual_write_initialized(): bool {
        exists<DualWriteControl>(@lottery)
    }

    #[view]
    public fun dual_write_status(lottery_id: u64): DualWriteStatus
    acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery)) {
            return DualWriteStatus {
                enabled: false,
                abort_on_mismatch: false,
                abort_on_missing: false,
                expected_hash: option::none<vector<u8>>(),
            };
        };
        let control = borrow_global<DualWriteControl>(@lottery);
        let expected = if (table::contains(&control.expected_hashes, lottery_id)) {
            let hash_ref = table::borrow(&control.expected_hashes, lottery_id);
            option::some(clone_bytes(hash_ref))
        } else {
            option::none<vector<u8>>()
        };
        DualWriteStatus {
            enabled: control.enabled,
            abort_on_mismatch: control.abort_on_mismatch,
            abort_on_missing: control.abort_on_missing,
            expected_hash: expected,
        }
    }

    #[view]
    public fun dual_write_flags(): DualWriteStatus acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery)) {
            return DualWriteStatus {
                enabled: false,
                abort_on_mismatch: false,
                abort_on_missing: false,
                expected_hash: option::none<vector<u8>>(),
            };
        };
        let control = borrow_global<DualWriteControl>(@lottery);
        DualWriteStatus {
            enabled: control.enabled,
            abort_on_mismatch: control.abort_on_mismatch,
            abort_on_missing: control.abort_on_missing,
            expected_hash: option::none<vector<u8>>(),
        }
    }

    #[view]
    public fun pending_expected_hashes(): vector<u64> acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery)) {
            return vector::empty<u64>();
        };
        let control = borrow_global<DualWriteControl>(@lottery);
        table::keys(&control.expected_hashes)
    }

    #[view]
    public fun archive_initialized(): bool {
        exists<ArchiveLedger>(@lottery)
    }

    #[view]
    public fun legacy_archive_initialized(): bool {
        exists<LegacyArchive>(@lottery)
    }

    #[view]
    public fun archive_summary(lottery_id: u64): option::Option<LotterySummary>
    acquires ArchiveLedger {
        if (!exists<ArchiveLedger>(@lottery)) {
            return option::none<LotterySummary>();
        };
        let ledger = borrow_global<ArchiveLedger>(@lottery);
        if (!table::contains(&ledger.summaries, lottery_id)) {
            option::none<LotterySummary>()
        } else {
            let summary = table::borrow(&ledger.summaries, lottery_id);
            option::some(clone_summary(summary))
        }
    }

    #[view]
    public fun is_legacy_summary(lottery_id: u64): bool acquires ArchiveLedger {
        if (!exists<ArchiveLedger>(@lottery)) {
            return false;
        };
        let ledger = borrow_global<ArchiveLedger>(@lottery);
        if (!table::contains(&ledger.imported_flags, lottery_id)) {
            return false;
        };
        let flag = table::borrow(&ledger.imported_flags, lottery_id);
        *flag
    }

    #[view]
    public fun list_finalized(from: u64, limit: u64): vector<u64> acquires ArchiveLedger {
        if (limit > MAX_ARCHIVE_PAGE) {
            abort E_PAGINATION_TOO_LARGE;
        };
        ensure_archive_initialized();
        let ledger = borrow_global<ArchiveLedger>(@lottery);
        let ids_ref = &ledger.ordered_ids;
        let result = vector::empty<u64>();
        collect_finalized(ids_ref, vector::length(ids_ref), from, 0, limit, &mut result);
        result
    }

    #[view]
    public fun legacy_summary(lottery_id: u64): option::Option<LegacySummary>
    acquires LegacyArchive {
        if (!exists<LegacyArchive>(@lottery)) {
            return option::none<LegacySummary>();
        };
        let archive = borrow_global<LegacyArchive>(@lottery);
        if (!table::contains(&archive.summaries, lottery_id)) {
            option::none<LegacySummary>()
        } else {
            let summary = table::borrow(&archive.summaries, lottery_id);
            option::some(*summary)
        }
    }

    public fun notify_summary_written(
        lottery_id: u64,
        archive_hash: &vector<u8>,
        finalized_at: u64,
    ) acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery)) {
            return;
        };
        let control = borrow_global_mut<DualWriteControl>(@lottery);
        if (!control.enabled) {
            return;
        };
        if (!table::contains(&control.expected_hashes, lottery_id)) {
            if (control.abort_on_missing) {
                abort E_EXPECTED_HASH_NOT_FOUND;
            };
            return;
        };
        let hashes_match = {
            let expected_ref = table::borrow(&control.expected_hashes, lottery_id);
            *expected_ref == *archive_hash
        };
        if (!hashes_match) {
            if (control.abort_on_mismatch) {
                abort E_EXPECTED_HASH_MISMATCH;
            };
            return;
        };
        let _removed = table::remove(&mut control.expected_hashes, lottery_id);
        let _ = _removed;
        let archive_hash_copy = clone_bytes(archive_hash);
        event::emit_event(
            &mut control.completed_events,
            ArchiveDualWriteCompletedEvent {
                event_version: EVENT_VERSION_V1,
                event_category: EVENT_CATEGORY_MIGRATION,
                lottery_id,
                archive_hash: archive_hash_copy,
                finalized_at,
            },
        );
    }

    #[view]
    public fun has_history(lottery_id: u64): bool acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return false;
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        table::contains(&state.histories, lottery_id)
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        clone_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_history(
        lottery_id: u64,
    ): option::Option<vector<DrawRecord>> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<vector<DrawRecord>>();
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<vector<DrawRecord>>()
        } else {
            let history = table::borrow(&state.histories, lottery_id);
            option::some(clone_draw_records(&history.records))
        }
    }

    #[view]
    public fun latest_record(lottery_id: u64): option::Option<DrawRecord>
    acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<DrawRecord>();
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<DrawRecord>()
        } else {
            let history = table::borrow(&state.histories, lottery_id);
            latest_record_internal(&history.records)
        }
    }

    #[view]
    public fun get_lottery_snapshot(
        lottery_id: u64,
    ): option::Option<LotteryHistorySnapshot> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<LotteryHistorySnapshot>();
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<LotteryHistorySnapshot>()
        } else {
            option::some(build_lottery_snapshot(state, lottery_id))
        }
    }

    #[view]
    public fun get_history_snapshot(): option::Option<HistorySnapshot>
    acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<HistorySnapshot>();
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        option::some(build_snapshot(state))
    }

    public fun ensure_caps_initialized(caller: &signer)
    acquires HistoryCollection, HistoryWarden, rounds::RoundControl {
        ensure_admin(caller);
        if (exists<HistoryWarden>(@lottery)) {
            return;
        };
        let control = rounds::borrow_control_mut(@lottery);
        let cap_opt = rounds::extract_history_cap(control);
        if (!option::is_some(&cap_opt)) {
            return;
        };
        let cap = option::destroy_some(cap_opt);
        move_to(caller, HistoryWarden { writer: cap });
    }

    fun ensure_archive_initialized() acquires ArchiveLedger {
        if (!exists<ArchiveLedger>(@lottery)) {
            abort E_ARCHIVE_NOT_INITIALIZED;
        };
    }

    fun store_archive_summary(
        lottery_id: u64,
        summary: LotterySummary,
        archive_hash: vector<u8>,
        is_legacy: bool,
    ) acquires ArchiveLedger {
        let primary_type = summary.primary_type;
        let tags_mask = summary.tags_mask;
        let ledger = borrow_global_mut<ArchiveLedger>(@lottery);
        if (table::contains(&ledger.summaries, lottery_id)) {
            let existing_summary = table::borrow(&ledger.summaries, lottery_id);
            let existing_hash = hash::sha3_256(bcs::to_bytes(existing_summary));
            let imported_flag = table::borrow(&ledger.imported_flags, lottery_id);
            if (*imported_flag) {
                if (!is_legacy) {
                    abort E_ARCHIVE_NOT_LEGACY;
                };
            } else {
                if (is_legacy) {
                    abort E_ARCHIVE_NOT_LEGACY;
                };
                if (existing_hash != archive_hash) {
                    abort E_ARCHIVE_HASH_MISMATCH;
                };
            };
            let slot = table::borrow_mut(&mut ledger.summaries, lottery_id);
            *slot = summary;
        } else {
            table::add(&mut ledger.summaries, lottery_id, summary);
            table::add(&mut ledger.imported_flags, lottery_id, is_legacy);
            push_unique_lottery_id(&mut ledger.ordered_ids, lottery_id);
        };
        let finalized_event = LotteryFinalizedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            id: lottery_id,
            archive_slot_hash: archive_hash,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.finalized_events, finalized_event);
    }

    fun mirror_summary_to_legacy(
        summary_bytes: vector<u8>,
        archive_hash: vector<u8>,
        finalized_at: u64,
    ) acquires LegacyArchive {
        if (!exists<LegacyArchive>(@lottery)) {
            return;
        };
        let archive = borrow_global_mut<LegacyArchive>(@lottery);
        let summary = LegacySummary {
            summary_bcs: clone_bytes(&summary_bytes),
            archive_hash: clone_bytes(&archive_hash),
            finalized_at,
        };
        let lottery_id = decode_summary_id(&summary_bytes);
        if (table::contains(&archive.summaries, lottery_id)) {
            let slot = table::borrow_mut(&mut archive.summaries, lottery_id);
            *slot = summary;
        } else {
            table::add(&mut archive.summaries, lottery_id, summary);
        };
        let event = LegacySummaryEvent {
            lottery_id,
            archive_hash,
            finalized_at,
        };
        event::emit_event(&mut archive.summary_events, event);
    }

    fun emit_legacy_import_event(
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
    ) acquires ArchiveLedger {
        let ledger = borrow_global_mut<ArchiveLedger>(@lottery);
        let event = LegacySummaryImportedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash,
            finalized_at,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.import_events, event);
    }

    fun emit_legacy_rollback_event(
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
        ledger: &mut ArchiveLedger,
    ) {
        let event = LegacySummaryRolledBackEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash,
            finalized_at,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.rollback_events, event);
    }

    fun emit_classification_event(
        lottery_id: u64,
        archive_hash: vector<u8>,
        primary_type: u8,
        tags_mask: u64,
        ledger: &mut ArchiveLedger,
    ) {
        let event = LegacySummaryClassificationUpdatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.classification_events, event);
    }

    fun ensure_admin(caller: &signer) acquires HistoryCollection {
        let addr = signer::address_of(caller);
        if (!exists<HistoryCollection>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_caps_ready() {
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_CAPS_NOT_READY;
        };
    }

    fun ensure_dual_write_initialized() {
        if (!exists<DualWriteControl>(@lottery)) {
            abort E_DUAL_WRITE_NOT_INITIALIZED;
        };
    }

    fun emit_initial_snapshot() acquires HistoryCollection {
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        emit_history_snapshot_with_previous(state, option::none<HistorySnapshot>());
    }

    fun record_draw_internal(
        _cap: &rounds::HistoryWriterCap,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return;
        };
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        let timestamp_seconds = timestamp::now_seconds();
        append_history_record(
            state,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
            timestamp_seconds,
        );
    }

    fun replay_pending_records(
        cap: &rounds::HistoryWriterCap,
        pending: &mut vector<rounds::PendingHistoryRecord>,
    ) acquires HistoryCollection {
        if (vector::is_empty(pending)) {
            return;
        };
        let record = vector::remove(pending, 0);
        let (
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        ) = rounds::destroy_pending_history_record(record);
        record_draw_internal(
            cap,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        );
        replay_pending_records(cap, pending);
    }

    fun append_imported_history_record(record: LegacyHistoryRecord) acquires HistoryCollection {
        let LegacyHistoryRecord {
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
            timestamp_seconds,
        } = record;
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        append_history_record(
            state,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
            timestamp_seconds,
        );
    }

    fun import_history_batch_recursive(records: &mut vector<LegacyHistoryRecord>)
    acquires HistoryCollection {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        import_history_batch_recursive(records);
        append_imported_history_record(record);
    }

    fun append_history_record(
        state: &mut HistoryCollection,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
        timestamp_seconds: u64,
    ) {
        let previous = option::some(build_snapshot_from_mut(state));
        let history = borrow_or_create_history(state, lottery_id);
        let record = DrawRecord {
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
            timestamp_seconds,
        };
        vector::push_back(&mut history.records, record);
        trim_history(&mut history.records);
        event::emit_event(
            &mut state.record_events,
            DrawRecordedEvent {
                lottery_id,
                request_id,
                winner,
                ticket_index,
                prize_amount,
                timestamp_seconds,
            },
        );
        emit_history_snapshot_with_previous(state, previous);
    }

    fun borrow_or_create_history(
        state: &mut HistoryCollection,
        lottery_id: u64,
    ): &mut LotteryHistory {
        if (!table::contains(&state.histories, lottery_id)) {
            table::add(
                &mut state.histories,
                lottery_id,
                LotteryHistory {
                    records: vector::empty<DrawRecord>(),
                },
            );
            push_unique_lottery_id(&mut state.lottery_ids, lottery_id);
        };
        table::borrow_mut(&mut state.histories, lottery_id)
    }

    fun trim_history(records: &mut vector<DrawRecord>) {
        if (vector::length(records) <= MAX_HISTORY_LENGTH) {
            return;
        };
        let _ = vector::remove(records, 0);
        trim_history(records);
    }

    fun clear_records(records: &mut vector<DrawRecord>) {
        if (vector::is_empty(records)) {
            return;
        };
        let _ = vector::pop_back(records);
        clear_records(records);
    }

    fun push_unique_lottery_id(list: &mut vector<u64>, lottery_id: u64) {
        if (contains_lottery_id(list, lottery_id, 0)) {
            return;
        };
        vector::push_back(list, lottery_id);
    }

    fun contains_lottery_id(
        list: &vector<u64>,
        lottery_id: u64,
        index: u64,
    ): bool {
        if (index >= vector::length(list)) {
            false
        } else if (*vector::borrow(list, index) == lottery_id) {
            true
        } else {
            let next_index = index + 1;
            contains_lottery_id(list, lottery_id, next_index)
        }
    }

    fun collect_finalized(
        ids: &vector<u64>,
        len: u64,
        skipped: u64,
        taken: u64,
        limit: u64,
        buffer: &mut vector<u64>,
    ) {
        if (len == 0 || taken >= limit) {
            return;
        };
        let index = len - 1;
        let lottery_id = *vector::borrow(ids, index);
        if (skipped > 0) {
            let next_len = len - 1;
            let next_skipped = skipped - 1;
            collect_finalized(ids, next_len, next_skipped, taken, limit, buffer);
            return;
        };
        vector::push_back(buffer, lottery_id);
        let next_taken = taken + 1;
        let next_len = len - 1;
        collect_finalized(ids, next_len, skipped, next_taken, limit, buffer);
    }

    fun remove_archive_id(ids: &mut vector<u64>, lottery_id: u64) {
        remove_archive_id_at(ids, lottery_id, 0);
    }

    fun remove_archive_id_at(ids: &mut vector<u64>, lottery_id: u64, index: u64) {
        if (index >= vector::length(ids)) {
            return;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            let _ = vector::remove(ids, index);
            return;
        };
        let next_index = index + 1;
        remove_archive_id_at(ids, lottery_id, next_index);
    }

    fun clone_u64_vector(values: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        clone_u64_into(values, 0, &mut result);
        result
    }

    fun clone_u64_into(values: &vector<u64>, index: u64, buffer: &mut vector<u64>) {
        if (index >= vector::length(values)) {
            return;
        };
        vector::push_back(buffer, *vector::borrow(values, index));
        let next_index = index + 1;
        clone_u64_into(values, next_index, buffer);
    }

    fun clone_draw_records(records: &vector<DrawRecord>): vector<DrawRecord> {
        let result = vector::empty<DrawRecord>();
        clone_records_into(records, 0, &mut result);
        result
    }

    fun clone_records_into(
        records: &vector<DrawRecord>,
        index: u64,
        buffer: &mut vector<DrawRecord>,
    ) {
        if (index >= vector::length(records)) {
            return;
        };
        vector::push_back(buffer, *vector::borrow(records, index));
        let next_index = index + 1;
        clone_records_into(records, next_index, buffer);
    }

    fun latest_record_internal(records: &vector<DrawRecord>): option::Option<DrawRecord> {
        if (vector::is_empty(records)) {
            option::none<DrawRecord>()
        } else {
            let last_index = vector::length(records) - 1;
            option::some(*vector::borrow(records, last_index))
        }
    }

    fun build_lottery_snapshot(
        state: &HistoryCollection,
        lottery_id: u64,
    ): LotteryHistorySnapshot {
        build_lottery_snapshot_from_table(&state.histories, lottery_id)
    }

    fun build_lottery_snapshot_from_table(
        histories: &table::Table<u64, LotteryHistory>,
        lottery_id: u64,
    ): LotteryHistorySnapshot {
        let history = table::borrow(histories, lottery_id);
        LotteryHistorySnapshot {
            lottery_id,
            records: clone_draw_records(&history.records),
        }
    }

    fun build_snapshot(state: &HistoryCollection): HistorySnapshot {
        build_snapshot_internal(state.admin, &state.lottery_ids, &state.histories)
    }

    fun build_snapshot_from_mut(state: &mut HistoryCollection): HistorySnapshot {
        build_snapshot_internal(state.admin, &state.lottery_ids, &state.histories)
    }

    fun clone_summary(summary: &LotterySummary): LotterySummary {
        LotterySummary {
            id: summary.id,
            status: summary.status,
            event_slug: clone_bytes(&summary.event_slug),
            series_code: clone_bytes(&summary.series_code),
            run_id: summary.run_id,
            tickets_sold: summary.tickets_sold,
            proceeds_accum: summary.proceeds_accum,
            total_allocated: summary.total_allocated,
            total_prize_paid: summary.total_prize_paid,
            total_operations_paid: summary.total_operations_paid,
            vrf_status: summary.vrf_status,
            primary_type: summary.primary_type,
            tags_mask: summary.tags_mask,
            snapshot_hash: clone_bytes(&summary.snapshot_hash),
            slots_checksum: clone_bytes(&summary.slots_checksum),
            winners_batch_hash: clone_bytes(&summary.winners_batch_hash),
            checksum_after_batch: clone_bytes(&summary.checksum_after_batch),
            payout_round: summary.payout_round,
            created_at: summary.created_at,
            closed_at: summary.closed_at,
            finalized_at: summary.finalized_at,
        }
    }

    fun decode_summary_id(summary_bytes: &vector<u8>): u64 {
        let summary = bcs::from_bytes<LotterySummary>(summary_bytes);
        summary.id
    }

    fun build_snapshot_internal(
        admin: address,
        lottery_ids: &vector<u64>,
        histories: &table::Table<u64, LotteryHistory>,
    ): HistorySnapshot {
        let entries = vector::empty<LotteryHistorySnapshot>();
        collect_snapshots(histories, lottery_ids, 0, entries, admin)
    }

    fun collect_snapshots(
        histories: &table::Table<u64, LotteryHistory>,
        lottery_ids: &vector<u64>,
        index: u64,
        acc: vector<LotteryHistorySnapshot>,
        admin: address,
    ): HistorySnapshot {
        if (index >= vector::length(lottery_ids)) {
            HistorySnapshot {
                admin,
                lottery_ids: clone_u64_vector(lottery_ids),
                histories: acc,
            }
        } else {
            let lottery_id = *vector::borrow(lottery_ids, index);
            let mut next_acc = acc;
            if (table::contains(histories, lottery_id)) {
                let snapshot = build_lottery_snapshot_from_table(histories, lottery_id);
                vector::push_back(&mut next_acc, snapshot);
            };
            let next_index = index + 1;
            collect_snapshots(histories, lottery_ids, next_index, next_acc, admin)
        }
    }

    fun emit_history_snapshot_with_previous(
        state: &mut HistoryCollection,
        previous: option::Option<HistorySnapshot>,
    ) {
        let current = build_snapshot_from_mut(state);
        event::emit_event(
            &mut state.snapshot_events,
            HistorySnapshotUpdatedEvent { previous, current },
        );
    }

    fun apply_legacy_dual_write_state(caller: &signer, state: LegacyDualWriteState)
    acquires DualWriteControl {
        let LegacyDualWriteState {
            enabled,
            abort_on_mismatch,
            abort_on_missing,
            mut expectations,
        } = state;
        if (!exists<DualWriteControl>(@lottery)) {
            move_to(
                caller,
                DualWriteControl {
                    enabled,
                    abort_on_mismatch,
                    abort_on_missing,
                    expected_hashes: table::new<u64, vector<u8>>(),
                    started_events: account::new_event_handle<ArchiveDualWriteStartedEvent>(caller),
                    completed_events: account::new_event_handle<ArchiveDualWriteCompletedEvent>(caller),
                },
            );
        } else {
            let control = borrow_global_mut<DualWriteControl>(@lottery);
            control.enabled = enabled;
            control.abort_on_mismatch = abort_on_mismatch;
            control.abort_on_missing = abort_on_missing;
            clear_expected_hashes(&mut control.expected_hashes);
        };
        let control_ref = borrow_global_mut<DualWriteControl>(@lottery);
        import_dual_write_expectations(control_ref, &mut expectations);
    }

    fun import_dual_write_expectations(
        control: &mut DualWriteControl,
        expectations: &mut vector<LegacyDualWriteExpectation>,
    ) {
        if (vector::is_empty(expectations)) {
            return;
        };
        let expectation = vector::pop_back(expectations);
        import_dual_write_expectations(control, expectations);
        let LegacyDualWriteExpectation { lottery_id, expected_hash } = expectation;
        upsert_expected_hash(control, lottery_id, expected_hash);
    }

    fun clear_expected_hashes(expected: &mut table::Table<u64, vector<u8>>) {
        let keys = table::keys(expected);
        clear_expected_hashes_recursive(expected, &keys, 0);
    }

    fun clear_expected_hashes_recursive(
        expected: &mut table::Table<u64, vector<u8>>,
        keys: &vector<u64>,
        index: u64,
    ) {
        if (index >= vector::length(keys)) {
            return;
        };
        let lottery_id = *vector::borrow(keys, index);
        if (table::contains(expected, lottery_id)) {
            let _removed = table::remove(expected, lottery_id);
            let _ = _removed;
        };
        let next_index = index + 1;
        clear_expected_hashes_recursive(expected, keys, next_index);
    }

    fun upsert_expected_hash(
        control: &mut DualWriteControl,
        lottery_id: u64,
        expected_hash: vector<u8>,
    ) {
        if (table::contains(&control.expected_hashes, lottery_id)) {
            let _removed = table::remove(&mut control.expected_hashes, lottery_id);
            let _ = _removed;
        };
        let hash_for_event = clone_bytes(&expected_hash);
        table::add(&mut control.expected_hashes, lottery_id, expected_hash);
        event::emit_event(
            &mut control.started_events,
            ArchiveDualWriteStartedEvent {
                event_version: EVENT_VERSION_V1,
                event_category: EVENT_CATEGORY_MIGRATION,
                lottery_id,
                expected_hash: hash_for_event,
            },
        );
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let copy = vector::empty<u8>();
        let len = vector::length(source);
        clone_bytes_into(&mut copy, source, 0, len);
        copy
    }

    fun clone_bytes_into(
        buffer: &mut vector<u8>,
        source: &vector<u8>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(source, index);
        vector::push_back(buffer, byte);
        let next_index = index + 1;
        clone_bytes_into(buffer, source, next_index, len);
    }
}
