module lottery_utils::history {
    use lottery_data::rounds;
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
        let previous = option::some(build_snapshot_from_mut(state));
        let history = borrow_or_create_history(state, lottery_id);
        let timestamp_seconds = timestamp::now_seconds();
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
}
