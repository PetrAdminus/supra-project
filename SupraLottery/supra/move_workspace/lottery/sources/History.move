module lottery::history {
    friend lottery::rounds;

    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;
    use std::timestamp;

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

    #[event]
    struct DrawRecordedEvent has copy, drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        timestamp_seconds: u64,
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
                record_events: event::new_event_handle<DrawRecordedEvent>(caller),
            },
        );
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
        state.admin = new_admin;
    }

    public entry fun clear_history(caller: &signer, lottery_id: u64) acquires HistoryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<HistoryCollection>(@lottery);
        if (table::contains(&state.histories, lottery_id)) {
            let history = table::borrow_mut(&mut state.histories, lottery_id);
            clear_records(&mut history.records);
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
}
