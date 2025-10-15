module lottery::history {
    friend lottery::rounds;

    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::timestamp;
    use lottery::events;

    const MAX_HISTORY_LENGTH: u64 = 128;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;

    struct LotteryHistory has store {
        records: vector<DrawRecord>,
    }

    struct HistoryCollection has key {
        admin: address,
        histories: table::Table<u64, LotteryHistory>,
        lottery_ids: vector<u64>,
    }

    struct DrawRecord has copy, drop, store {
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
    struct DrawRecordedEvent has copy, drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        timestamp_seconds: u64,
    }

    #[event]
    struct HistorySnapshotUpdatedEvent has copy, drop, store {
        previous: option::Option<HistorySnapshot>,
        current: HistorySnapshot,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<HistoryCollection>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            HistoryCollection {
                admin: addr,
                histories: table::new(),
                lottery_ids: vector::empty<u64>(),
            },
        );
        let previous = option::none<HistorySnapshot>();
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        emit_history_snapshot(state, previous);
    }

    public fun is_initialized(): bool {
        exists<HistoryCollection>(@lottery)
    }

    public fun admin(): address acquires HistoryCollection {
        let state = borrow_global<HistoryCollection>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires HistoryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        state.admin = new_admin;
        emit_history_snapshot(state, previous);
    }

    public entry fun clear_history(caller: &signer, lottery_id: u64) acquires HistoryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        if (table::contains(&state.histories, lottery_id)) {
            let previous = option::some(build_snapshot_from_mut(state));
            let history = table::borrow_mut(&mut state.histories, lottery_id);
            clear_records(&mut history.records);
            emit_history_snapshot(state, previous);
        };
    }

    public(friend) fun record_draw(
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return
        };
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        let previous = option::some(build_snapshot_from_mut(state));
        let history = borrow_or_create_history(state, lottery_id);
        let timestamp_seconds = timestamp::now_seconds();
        let record = DrawRecord {
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
        events::emit(DrawRecordedEvent {
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            timestamp_seconds,
        });
        emit_history_snapshot(state, previous);
    }

    #[view]
    public fun has_history(lottery_id: u64): bool acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return false
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        table::contains(&state.histories, lottery_id)
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        clone_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_history(lottery_id: u64): option::Option<vector<DrawRecord>> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<vector<DrawRecord>>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<vector<DrawRecord>>()
        } else {
            let history = table::borrow(&state.histories, lottery_id);
            option::some(clone_records(&history.records))
        }
    }

    #[view]
    public fun latest_record(lottery_id: u64): option::Option<DrawRecord> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<DrawRecord>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<DrawRecord>()
        } else {
            let history = table::borrow(&state.histories, lottery_id);
            if (vector::is_empty(&history.records)) {
                option::none<DrawRecord>()
            } else {
                let last_index = vector::length(&history.records) - 1;
                option::some(*vector::borrow(&history.records, last_index))
            }
        }
    }

    #[view]
    public fun get_lottery_snapshot(
        lottery_id: u64
    ): option::Option<LotteryHistorySnapshot> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<LotteryHistorySnapshot>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (!table::contains(&state.histories, lottery_id)) {
            option::none<LotteryHistorySnapshot>()
        } else {
            option::some(build_lottery_snapshot_from_ref(state, lottery_id))
        }
    }

    #[view]
    public fun get_history_snapshot(): option::Option<HistorySnapshot> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<HistorySnapshot>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        option::some(build_snapshot_from_ref(state))
    }

    fun ensure_admin(caller: &signer) acquires HistoryCollection {
        let addr = signer::address_of(caller);
        if (!exists<HistoryCollection>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun borrow_or_create_history(state: &mut HistoryCollection, lottery_id: u64): &mut LotteryHistory {
        if (!table::contains(&state.histories, lottery_id)) {
            table::add(&mut state.histories, lottery_id, LotteryHistory { records: vector::empty<DrawRecord>() });
            push_unique(&mut state.lottery_ids, lottery_id);
        };
        table::borrow_mut(&mut state.histories, lottery_id)
    }

    fun trim_history(records: &mut vector<DrawRecord>) {
        while (vector::length(records) > MAX_HISTORY_LENGTH) {
            let _ = vector::remove(records, 0);
        };
    }

    fun clear_records(records: &mut vector<DrawRecord>) {
        while (!vector::is_empty(records)) {
            let _ = vector::pop_back(records);
        };
    }

    fun push_unique(list: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(list);
        let index = 0;
        while (index < len) {
            if (*vector::borrow(list, index) == lottery_id) {
                return
            } else {
                index = index + 1;
            }
        };
        vector::push_back(list, lottery_id);
    }

    fun clone_u64_vector(values: &vector<u64>) : vector<u64> {
        let result = vector::empty<u64>();
        let len = vector::length(values);
        let index = 0;
        while (index < len) {
            vector::push_back(&mut result, *vector::borrow(values, index));
            index = index + 1;
        };
        result
    }

    fun clone_records(records: &vector<DrawRecord>): vector<DrawRecord> {
        let result = vector::empty<DrawRecord>();
        let len = vector::length(records);
        let index = 0;
        while (index < len) {
            vector::push_back(&mut result, *vector::borrow(records, index));
            index = index + 1;
        };
        result
    }

    fun build_snapshot_from_parts(
        admin: address,
        histories_table: &table::Table<u64, LotteryHistory>,
        lottery_ids: &vector<u64>,
    ): HistorySnapshot {
        let histories = vector::empty<LotteryHistorySnapshot>();
        let len = vector::length(lottery_ids);
        let index = 0;
        while (index < len) {
            let lottery_id = *vector::borrow(lottery_ids, index);
            if (table::contains(histories_table, lottery_id)) {
                vector::push_back(&mut histories, build_lottery_snapshot_from_parts(
                    lottery_id,
                    table::borrow(histories_table, lottery_id),
                ));
            };
            index = index + 1;
        };
        HistorySnapshot {
            admin,
            lottery_ids: clone_u64_vector(lottery_ids),
            histories,
        }
    }

    fun build_snapshot_from_ref(state: &HistoryCollection): HistorySnapshot {
        build_snapshot_from_parts(state.admin, &state.histories, &state.lottery_ids)
    }

    fun build_snapshot_from_mut(state: &mut HistoryCollection): HistorySnapshot {
        build_snapshot_from_parts(state.admin, &state.histories, &state.lottery_ids)
    }

    fun build_lottery_snapshot_from_parts(
        lottery_id: u64,
        history: &LotteryHistory,
    ): LotteryHistorySnapshot {
        LotteryHistorySnapshot {
            lottery_id,
            records: clone_records(&history.records),
        }
    }

    fun build_lottery_snapshot_from_ref(
        state: &HistoryCollection,
        lottery_id: u64,
    ): LotteryHistorySnapshot {
        build_lottery_snapshot_from_parts(lottery_id, table::borrow(&state.histories, lottery_id))
    }

    fun emit_history_snapshot(
        state: &mut HistoryCollection,
        previous: option::Option<HistorySnapshot>
    ) {
        let current = build_snapshot_from_mut(state);
        events::emit(HistorySnapshotUpdatedEvent { previous, current });
    }

    #[test_only]
    public fun draw_record_fields_for_test(
        record: &DrawRecord
    ): (u64, address, u64, u64, vector<u8>, vector<u8>, u64) {
        (
            record.request_id,
            record.winner,
            record.ticket_index,
            record.prize_amount,
            record.random_bytes,
            record.payload,
            record.timestamp_seconds,
        )
    }

    #[test_only]
    public fun history_snapshot_fields_for_test(
        snapshot: &HistorySnapshot
    ): (address, vector<u64>, vector<LotteryHistorySnapshot>) {
        (
            snapshot.admin,
            clone_u64_vector(&snapshot.lottery_ids),
            clone_lottery_snapshots(&snapshot.histories),
        )
    }

    #[test_only]
    public fun lottery_history_snapshot_fields_for_test(
        snapshot: &LotteryHistorySnapshot
    ): (u64, vector<DrawRecord>) {
        (snapshot.lottery_id, clone_records(&snapshot.records))
    }

    #[test_only]
    public fun history_snapshot_event_fields_for_test(
        event: &HistorySnapshotUpdatedEvent
    ): (option::Option<HistorySnapshot>, HistorySnapshot) {
        (event.previous, event.current)
    }

    fun clone_lottery_snapshots(
        snapshots: &vector<LotteryHistorySnapshot>
    ): vector<LotteryHistorySnapshot> {
        let result = vector::empty<LotteryHistorySnapshot>();
        let len = vector::length(snapshots);
        let index = 0;
        while (index < len) {
            vector::push_back(&mut result, *vector::borrow(snapshots, index));
            index = index + 1;
        };
        result
    }
}
