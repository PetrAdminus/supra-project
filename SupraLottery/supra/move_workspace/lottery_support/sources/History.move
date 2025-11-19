module lottery_support::support_history {
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_rounds::HistoryWriterCap;
    use std::option;
    use std::signer;
    use std::timestamp;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

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
        record_events: event::EventHandle<DrawRecordedEvent>,
        snapshot_events: event::EventHandle<HistorySnapshotUpdatedEvent>,
    }

    struct HistoryWarden has key {
        writer: HistoryWriterCap,
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

    /// Ensures the support module holds the history capability.
    ///
    /// On the first call it requests `HistoryWriterCap` from the core and caches it
    /// in the `HistoryWarden` resource. Subsequent calls are no-ops.
    /// Used in smoke scenarios before recording history and during reinitialization
    /// after upgrading the package.
    public fun ensure_caps_initialized(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<HistoryWarden>(@lottery)) {
            return
        };
        let cap_opt = rounds::try_borrow_history_writer_cap(admin);
        if (!option::is_some(&cap_opt)) {
            option::destroy_none(cap_opt);
            return
        };
        let cap = option::destroy_some(cap_opt);
        move_to(admin, HistoryWarden { writer: cap });
    }

    // Checks whether the support module currently holds the history capability.
    #[view]
    public fun caps_ready(): bool {
        exists<HistoryWarden>(@lottery)
    }

    /// Returns the history capability to the core (for example, before redeploying the package).
    public fun release_caps(admin: &signer) acquires HistoryWarden {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let HistoryWarden { writer } = move_from<HistoryWarden>(@lottery);
        rounds::return_history_writer_cap(admin, writer);
    }

    public entry fun init(caller: &signer) acquires HistoryCollection {
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
                record_events: account::new_event_handle<DrawRecordedEvent>(caller),
                snapshot_events: account::new_event_handle<HistorySnapshotUpdatedEvent>(caller),
            },
        );
        let previous = option::none<HistorySnapshot>();
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        emit_history_snapshot(state, previous);
        if (!exists<HistoryWarden>(@lottery)) {
            ensure_caps_initialized(caller);
        };
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

    public fun record_draw(
        _cap: &HistoryWriterCap,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) acquires HistoryCollection {
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
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
        emit_history_snapshot(state, previous);
    }

    /// Records a draw result on behalf of the core using the cached capability.
    ///
    /// Invoked by the lottery administrator right after `lottery_core::core_rounds::fulfill_draw_request`
    /// (for example, by the VRF aggregator). The function checks that the capability
    /// is issued to `HistoryWarden` and reuses the shared `record_draw` hook.
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
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let warden = borrow_global<HistoryWarden>(@lottery);
        let cap_ref = &warden.writer;
        record_draw(
            cap_ref,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        );
    }

    /// Synchronizes accumulated draw results from the core module.
    ///
    /// `lottery_core::core_rounds` pushes every fulfilled draw into a queue guarded by
    /// the `HistoryWriterCap` capability. This function drains up to `limit` records
    /// (all records when `limit = 0`) and replays them via `record_draw`, updating
    /// history events and snapshots.
    public entry fun sync_draws_from_rounds(caller: &signer, limit: u64)
    acquires HistoryCollection, HistoryWarden {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<HistoryWarden>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let warden = borrow_global<HistoryWarden>(@lottery);
        let cap_ref = &warden.writer;
        let pending = rounds::drain_history_queue(cap_ref, limit);
        while (!vector::is_empty(&pending)) {
            let record = vector::remove(&mut pending, 0);
            let (lottery_id, request_id, winner, ticket_index, prize_amount) =
                rounds::history_record_fields(&record);
            let (random_bytes, payload) = rounds::history_record_payloads(&record);
            record_draw(
                cap_ref,
                lottery_id,
                request_id,
                winner,
                ticket_index,
                prize_amount,
                random_bytes,
                payload,
            );
        };
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
            option::some(build_lottery_snapshot(state, lottery_id))
        }
    }

    #[view]
    public fun get_history_snapshot(): option::Option<HistorySnapshot> acquires HistoryCollection {
        if (!exists<HistoryCollection>(@lottery)) {
            return option::none<HistorySnapshot>()
        };
        let state = borrow_global<HistoryCollection>(@lottery);
        option::some(build_snapshot(state))
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

    fun build_snapshot_from_mut(state: &mut HistoryCollection): HistorySnapshot {
        build_snapshot_internal(state.admin, &state.lottery_ids, &state.histories)
    }

    fun build_snapshot(state: &HistoryCollection): HistorySnapshot {
        build_snapshot_internal(state.admin, &state.lottery_ids, &state.histories)
    }

    fun build_snapshot_internal(
        admin: address,
        lottery_ids: &vector<u64>,
        histories_table: &table::Table<u64, LotteryHistory>,
    ): HistorySnapshot {
        let histories = vector::empty<LotteryHistorySnapshot>();
        let len = vector::length(lottery_ids);
        let index = 0;
        while (index < len) {
            let lottery_id = *vector::borrow(lottery_ids, index);
            if (table::contains(histories_table, lottery_id)) {
                vector::push_back(
                    &mut histories,
                    build_lottery_snapshot_from_table(histories_table, lottery_id),
                );
            };
            index = index + 1;
        };
        HistorySnapshot {
            admin,
            lottery_ids: clone_u64_vector(lottery_ids),
            histories,
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
            records: clone_records(&history.records),
        }
    }

    fun emit_history_snapshot(
        state: &mut HistoryCollection,
        previous: option::Option<HistorySnapshot>
    ) {
        let current = build_snapshot_from_mut(state);
        event::emit_event(
            &mut state.snapshot_events,
            HistorySnapshotUpdatedEvent { previous, current },
        );
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

    #[test_only]
    public fun clone_lottery_snapshots(
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



