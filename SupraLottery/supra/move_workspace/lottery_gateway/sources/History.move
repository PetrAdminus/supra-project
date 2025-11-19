module lottery_gateway::history {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;

    const STATUS_CREATED: u8 = 1;
    const STATUS_CANCELED: u8 = 2;
    const STATUS_FINALIZED: u8 = 3;

    struct HistoryRecord has copy, drop, store {
        lottery_id: u64,
        status: u8,
        reason_code: option::Option<u8>,
        archive_hash: option::Option<vector<u8>>,
    }

    struct LegacyHistoryImport has copy, drop, store {
        lottery_id: u64,
        status: u8,
        reason_code: option::Option<u8>,
        archive_hash: option::Option<vector<u8>>,
    }

    struct LotteryHistorySnapshot has copy, drop, store {
        admin: address,
        records: vector<HistoryRecord>,
    }

    #[event]
    struct HistoryRecordedEvent has drop, store, copy {
        record: HistoryRecord,
    }

    #[event]
    struct HistorySnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<LotteryHistorySnapshot>,
        current: LotteryHistorySnapshot,
    }

    struct LotteryHistory has key {
        admin: address,
        records: vector<HistoryRecord>,
        record_events: event::EventHandle<HistoryRecordedEvent>,
        snapshot_events: event::EventHandle<HistorySnapshotUpdatedEvent>,
    }

    #[view]
    public fun is_initialized(): bool {
        exists<LotteryHistory>(@lottery)
    }

    public entry fun init(caller: &signer, admin: address) acquires LotteryHistory {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<LotteryHistory>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            LotteryHistory {
                admin,
                records: vector::empty<HistoryRecord>(),
                record_events: account::new_event_handle<HistoryRecordedEvent>(caller),
                snapshot_events: account::new_event_handle<HistorySnapshotUpdatedEvent>(caller),
            },
        );
        let history = borrow_global_mut<LotteryHistory>(caller_address);
        emit_snapshot(history, option::none<LotteryHistorySnapshot>());
    }

    public fun record_created(caller: &signer, lottery_id: u64) acquires LotteryHistory {
        record_status(caller, lottery_id, STATUS_CREATED, option::none<u8>(), option::none<vector<u8>>());
    }

    public fun record_canceled(
        caller: &signer,
        lottery_id: u64,
        reason_code: u8,
    ) acquires LotteryHistory {
        let reason = option::some(reason_code);
        record_status(caller, lottery_id, STATUS_CANCELED, reason, option::none<vector<u8>>());
    }

    public fun record_finalized(
        caller: &signer,
        lottery_id: u64,
        archive_hash: vector<u8>,
    ) acquires LotteryHistory {
        let hash_copy = clone_bytes(&archive_hash);
        record_status(caller, lottery_id, STATUS_FINALIZED, option::none<u8>(), option::some(hash_copy));
    }

    public entry fun record_existing_history(caller: &signer, payload: LegacyHistoryImport)
    acquires LotteryHistory {
        ensure_admin(caller);
        record_legacy(payload);
    }

    public entry fun record_existing_histories(caller: &signer, payloads: vector<LegacyHistoryImport>)
    acquires LotteryHistory {
        ensure_admin(caller);
        record_legacy_batch(&payloads, vector::length(&payloads));
    }

    #[view]
    public fun history_snapshot(): option::Option<LotteryHistorySnapshot> acquires LotteryHistory {
        if (!exists<LotteryHistory>(@lottery)) {
            return option::none<LotteryHistorySnapshot>();
        };
        let history = borrow_global<LotteryHistory>(@lottery);
        let snapshot = build_snapshot_view(&history);
        option::some(snapshot)
    }

    #[view]
    public fun ready(): bool acquires LotteryHistory {
        if (!exists<LotteryHistory>(@lottery)) {
            return false;
        };
        let history = borrow_global<LotteryHistory>(@lottery);
        validate_records(&history.records, vector::length(&history.records))
    }

    #[view]
    public fun history_records(): vector<HistoryRecord> acquires LotteryHistory {
        if (!exists<LotteryHistory>(@lottery)) {
            return vector::empty<HistoryRecord>();
        };
        let history = borrow_global<LotteryHistory>(@lottery);
        clone_records(&history.records, vector::length(&history.records))
    }

    fun record_status(
        caller: &signer,
        lottery_id: u64,
        status: u8,
        reason_code: option::Option<u8>,
        archive_hash: option::Option<vector<u8>>,
    ) acquires LotteryHistory {
        ensure_admin(caller);
        ensure_initialized();
        let history = borrow_global_mut<LotteryHistory>(@lottery);
        let previous = option::some(build_snapshot(history));
        let record = HistoryRecord {
            lottery_id,
            status,
            reason_code,
            archive_hash,
        };
        push_record(history, record);
        emit_record(history, record);
        emit_snapshot(history, previous);
    }

    fun record_legacy(payload: LegacyHistoryImport) acquires LotteryHistory {
        ensure_initialized();
        let history = borrow_global_mut<LotteryHistory>(@lottery);
        let previous = option::some(build_snapshot(history));
        let record = HistoryRecord {
            lottery_id: payload.lottery_id,
            status: payload.status,
            reason_code: payload.reason_code,
            archive_hash: payload.archive_hash,
        };
        push_record(history, record);
        emit_record(history, record);
        emit_snapshot(history, previous);
    }

    fun record_legacy_batch(payloads: &vector<LegacyHistoryImport>, remaining: u64) acquires LotteryHistory {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        record_legacy_batch(payloads, next_remaining);
        let payload = *vector::borrow(payloads, next_remaining);
        record_legacy(payload);
    }

    fun ensure_initialized() {
        if (!exists<LotteryHistory>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_admin(caller: &signer) acquires LotteryHistory {
        ensure_initialized();
        let history = borrow_global<LotteryHistory>(@lottery);
        let caller_address = signer::address_of(caller);
        assert!(caller_address == history.admin, E_UNAUTHORIZED);
    }

    fun push_record(history: &mut LotteryHistory, record: HistoryRecord) {
        vector::push_back(&mut history.records, record);
    }

    fun emit_record(history: &mut LotteryHistory, record: HistoryRecord) {
        event::emit_event(&mut history.record_events, HistoryRecordedEvent { record });
    }

    fun emit_snapshot(
        history: &mut LotteryHistory,
        previous: option::Option<LotteryHistorySnapshot>,
    ) {
        let current = build_snapshot(history);
        event::emit_event(
            &mut history.snapshot_events,
            HistorySnapshotUpdatedEvent { previous, current },
        );
    }

    fun build_snapshot(history: &LotteryHistory): LotteryHistorySnapshot {
        LotteryHistorySnapshot {
            admin: history.admin,
            records: clone_records(&history.records, vector::length(&history.records)),
        }
    }

    fun build_snapshot_view(history: &LotteryHistory): LotteryHistorySnapshot {
        build_snapshot(history)
    }

    fun clone_records(source: &vector<HistoryRecord>, remaining: u64): vector<HistoryRecord> {
        if (remaining == 0) {
            return vector::empty<HistoryRecord>();
        };
        let next_remaining = remaining - 1;
        let mut records = clone_records(source, next_remaining);
        let record = *vector::borrow(source, next_remaining);
        vector::push_back(&mut records, record);
        records
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        clone_bytes_inner(source, vector::length(source))
    }

    fun clone_bytes_inner(source: &vector<u8>, remaining: u64): vector<u8> {
        if (remaining == 0) {
            return vector::empty<u8>();
        };
        let next_remaining = remaining - 1;
        let mut bytes = clone_bytes_inner(source, next_remaining);
        let value = *vector::borrow(source, next_remaining);
        vector::push_back(&mut bytes, value);
        bytes
    }

    fun validate_records(records: &vector<HistoryRecord>, remaining: u64): bool {
        if (remaining == 0) {
            return true;
        };
        let next_remaining = remaining - 1;
        let previous_ok = validate_records(records, next_remaining);
        let record = vector::borrow(records, next_remaining);
        let status_valid = record.status == STATUS_CREATED
            || record.status == STATUS_CANCELED
            || record.status == STATUS_FINALIZED;
        previous_ok && status_valid
    }
}
