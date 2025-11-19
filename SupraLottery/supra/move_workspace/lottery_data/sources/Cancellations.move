module lottery_data::cancellations {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_RECORD_EXISTS: u64 = 3;
    const E_UNAUTHORIZED: u64 = 4;

    public struct LegacyCancellationRecord has drop, store {
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        jackpot_locked: u64,
        pending_tickets_cleared: u64,
    }

    struct CancellationRecord has copy, drop, store {
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        jackpot_locked: u64,
        pending_tickets_cleared: u64,
    }

    public struct CancellationSnapshot has drop, store {
        admin: address,
        lottery_ids: vector<u64>,
        records: vector<CancellationRecordSnapshot>,
    }

    public struct CancellationRecordSnapshot has copy, drop, store {
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        jackpot_locked: u64,
        pending_tickets_cleared: u64,
    }

    #[event]
    struct LotteryCanceledEvent has drop, store, copy {
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        jackpot_locked: u64,
        pending_tickets_cleared: u64,
    }

    struct CancellationLedger has key {
        admin: address,
        records: table::Table<u64, CancellationRecord>,
        events: event::EventHandle<LotteryCanceledEvent>,
    }

    public entry fun init_ledger(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<CancellationLedger>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            CancellationLedger {
                admin: caller_address,
                records: table::new<u64, CancellationRecord>(),
                events: account::new_event_handle<LotteryCanceledEvent>(caller),
            },
        );
    }

    public entry fun import_existing_cancellation(caller: &signer, record: LegacyCancellationRecord)
    acquires CancellationLedger {
        ensure_admin(caller);
        upsert_legacy_cancellation_record(record);
    }

    public entry fun import_existing_cancellations(
        caller: &signer,
        mut records: vector<LegacyCancellationRecord>,
    ) acquires CancellationLedger {
        ensure_admin(caller);
        import_existing_cancellations_recursive(&mut records);
    }

    public fun is_initialized(): bool {
        exists_at(@lottery)
    }

    public fun exists_at(addr: address): bool {
        exists<CancellationLedger>(addr)
    }

    public fun borrow(addr: address): &CancellationLedger acquires CancellationLedger {
        assert!(exists_at(addr), E_NOT_PUBLISHED);
        borrow_global<CancellationLedger>(addr)
    }

    public fun borrow_mut(addr: address): &mut CancellationLedger acquires CancellationLedger {
        assert!(exists_at(addr), E_NOT_PUBLISHED);
        borrow_global_mut<CancellationLedger>(addr)
    }

    public fun record_cancellation(
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        jackpot_locked: u64,
        pending_tickets_cleared: u64,
    ) acquires CancellationLedger {
        let record = CancellationRecord {
            reason_code,
            canceled_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
            jackpot_locked,
            pending_tickets_cleared,
        };
        store_cancellation_record(lottery_id, record);
    }

    public fun cancellation_record(lottery_id: u64): CancellationRecord acquires CancellationLedger {
        let ledger = borrow(@lottery);
        let record_ref = table::borrow(&ledger.records, lottery_id);
        *record_ref
    }

    public fun has_record(lottery_id: u64): bool acquires CancellationLedger {
        let ledger = borrow(@lottery);
        table::contains(&ledger.records, lottery_id)
    }

    #[view]
    public fun ready(): bool acquires CancellationLedger {
        if (!exists_at(@lottery)) {
            return false;
        };

        let ledger = borrow(@lottery);
        ledger.admin == @lottery
    }

    #[view]
    public fun ledger_snapshot(): option::Option<CancellationSnapshot> acquires CancellationLedger {
        if (!exists_at(@lottery)) {
            return option::none<CancellationSnapshot>();
        };

        let ledger = borrow(@lottery);
        let lottery_ids = table::keys(&ledger.records);
        let len = vector::length(&lottery_ids);
        let records = collect_cancellation_snapshots(&ledger.records, &lottery_ids, 0, len);

        option::some(CancellationSnapshot { admin: ledger.admin, lottery_ids, records })
    }

    #[view]
    public fun record_snapshot(lottery_id: u64): option::Option<CancellationRecordSnapshot> acquires CancellationLedger {
        if (!exists_at(@lottery)) {
            return option::none<CancellationRecordSnapshot>();
        };

        let ledger = borrow(@lottery);
        if (!table::contains(&ledger.records, lottery_id)) {
            return option::none<CancellationRecordSnapshot>();
        };

        let record_ref = table::borrow(&ledger.records, lottery_id);
        option::some(CancellationRecordSnapshot {
            lottery_id,
            reason_code: record_ref.reason_code,
            canceled_ts: record_ref.canceled_ts,
            previous_status: record_ref.previous_status,
            tickets_sold: record_ref.tickets_sold,
            proceeds_accum: record_ref.proceeds_accum,
            jackpot_locked: record_ref.jackpot_locked,
            pending_tickets_cleared: record_ref.pending_tickets_cleared,
        })
    }

    fun ensure_admin(caller: &signer) acquires CancellationLedger {
        let ledger = borrow(@lottery);
        let caller_address = signer::address_of(caller);
        assert!(caller_address == ledger.admin, E_UNAUTHORIZED);
    }

    fun import_existing_cancellations_recursive(records: &mut vector<LegacyCancellationRecord>)
    acquires CancellationLedger {
        if (vector::is_empty(records)) {
            return;
        };

        let record = vector::pop_back(records);
        upsert_legacy_cancellation_record(record);
        import_existing_cancellations_recursive(records);
    }

    fun upsert_legacy_cancellation_record(record: LegacyCancellationRecord) acquires CancellationLedger {
        let LegacyCancellationRecord {
            lottery_id,
            reason_code,
            canceled_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
            jackpot_locked,
            pending_tickets_cleared,
        } = record;

        let canonical_record = CancellationRecord {
            reason_code,
            canceled_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
            jackpot_locked,
            pending_tickets_cleared,
        };
        store_cancellation_record(lottery_id, canonical_record);
    }

    fun store_cancellation_record(lottery_id: u64, record: CancellationRecord)
    acquires CancellationLedger {
        let ledger = borrow_mut(@lottery);
        assert!(!table::contains(&ledger.records, lottery_id), E_RECORD_EXISTS);
        table::add(&mut ledger.records, lottery_id, copy record);

        event::emit_event(
            &mut ledger.events,
            LotteryCanceledEvent {
                lottery_id,
                reason_code: record.reason_code,
                canceled_ts: record.canceled_ts,
                previous_status: record.previous_status,
                tickets_sold: record.tickets_sold,
                proceeds_accum: record.proceeds_accum,
                jackpot_locked: record.jackpot_locked,
                pending_tickets_cleared: record.pending_tickets_cleared,
            },
        );
    }

    fun collect_cancellation_snapshots(
        records: &table::Table<u64, CancellationRecord>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<CancellationRecordSnapshot> {
        if (index == len) {
            return vector::empty<CancellationRecordSnapshot>();
        };

        let lottery_id = *vector::borrow(lottery_ids, index);
        let record = table::borrow(records, lottery_id);

        let current = vector::singleton(build_record_snapshot(lottery_id, record));
        let tail = collect_cancellation_snapshots(records, lottery_ids, index + 1, len);
        append_record_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_record_snapshots(
        dst: &mut vector<CancellationRecordSnapshot>,
        src: &vector<CancellationRecordSnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };

        let snapshot = *vector::borrow(src, index);
        vector::push_back(dst, snapshot);
        append_record_snapshots(dst, src, index + 1);
    }

    fun build_record_snapshot(lottery_id: u64, record: &CancellationRecord): CancellationRecordSnapshot {
        CancellationRecordSnapshot {
            lottery_id,
            reason_code: record.reason_code,
            canceled_ts: record.canceled_ts,
            previous_status: record.previous_status,
            tickets_sold: record.tickets_sold,
            proceeds_accum: record.proceeds_accum,
            jackpot_locked: record.jackpot_locked,
            pending_tickets_cleared: record.pending_tickets_cleared,
        }
    }
}
