module lottery_utils::migration {
    use lottery_data::instances;
    use lottery_data::treasury;
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_CAPS_NOT_READY: u64 = 2;
    const E_LEDGER_ALREADY_INITIALIZED: u64 = 3;
    const E_LEDGER_NOT_INITIALIZED: u64 = 4;
    const E_SESSION_NOT_INITIALIZED: u64 = 5;

    struct MigrationLedger has key {
        snapshots: table::Table<u64, MigrationSnapshot>,
        lottery_ids: vector<u64>,
        snapshot_events: event::EventHandle<MigrationSnapshotUpdatedEvent>,
    }

    struct MigrationLedgerSnapshot has copy, drop, store {
        lottery_ids: vector<u64>,
        snapshots: vector<MigrationSnapshot>,
    }

    struct MigrationSnapshot has copy, drop, store {
        lottery_id: u64,
        ticket_count: u64,
        legacy_next_ticket_id: u64,
        migrated_next_ticket_id: u64,
        legacy_draw_scheduled: bool,
        migrated_draw_scheduled: bool,
        legacy_pending_request: bool,
        jackpot_amount_migrated: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    }

    #[event]
    struct MigrationSnapshotUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        snapshot: MigrationSnapshot,
    }

    struct MigrationSession has key {
        instances_cap: option::Option<instances::InstancesExportCap>,
        legacy_cap: option::Option<treasury::LegacyTreasuryCap>,
    }

    struct MigrationSessionSnapshot has copy, drop, store {
        instances_cap_ready: bool,
        legacy_cap_ready: bool,
    }

    public entry fun init_ledger(caller: &signer) acquires MigrationLedger {
        ensure_admin(caller);
        if (exists<MigrationLedger>(@lottery)) {
            abort E_LEDGER_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            MigrationLedger {
                snapshots: table::new<u64, MigrationSnapshot>(),
                lottery_ids: vector::empty<u64>(),
                snapshot_events: account::new_event_handle<MigrationSnapshotUpdatedEvent>(caller),
            },
        );
    }

    #[view]
    public fun ledger_initialized(): bool {
        exists<MigrationLedger>(@lottery)
    }

    #[view]
    public fun is_initialized(): bool {
        ledger_initialized()
    }

    #[view]
    public fun ledger_snapshot(): option::Option<MigrationLedgerSnapshot> acquires MigrationLedger {
        if (!exists<MigrationLedger>(@lottery)) {
            return option::none<MigrationLedgerSnapshot>();
        };
        let ledger = borrow_global<MigrationLedger>(@lottery);
        option::some(build_ledger_snapshot(&ledger))
    }

    public entry fun ensure_caps_initialized(caller: &signer)
    acquires MigrationSession, instances::InstanceControl, treasury::TreasuryV1Control {
        ensure_admin(caller);
        let addr = signer::address_of(caller);
        if (!exists<MigrationSession>(addr)) {
            move_to(
                caller,
                MigrationSession {
                    instances_cap: option::none<instances::InstancesExportCap>(),
                    legacy_cap: option::none<treasury::LegacyTreasuryCap>(),
                },
            );
        };
        let session = borrow_global_mut<MigrationSession>(addr);
        let need_instances_cap = !option::is_some(&session.instances_cap);
        let need_legacy_cap = !option::is_some(&session.legacy_cap);
        if (!need_instances_cap && !need_legacy_cap) {
            return;
        };

        let mut new_instances_cap = option::none<instances::InstancesExportCap>();
        if (need_instances_cap) {
            let control = instances::borrow_control_mut(@lottery);
            let extracted = instances::extract_export_cap(control);
            if (!option::is_some(&extracted)) {
                abort E_CAPS_NOT_READY;
            };
            new_instances_cap = extracted;
        };

        let mut new_legacy_cap = option::none<treasury::LegacyTreasuryCap>();
        if (need_legacy_cap) {
            let control = treasury::borrow_control_mut(@lottery);
            let extracted = treasury::extract_legacy_cap(control);
            if (!option::is_some(&extracted)) {
                if (need_instances_cap) {
                    let control_restore = instances::borrow_control_mut(@lottery);
                    let cap_to_restore = option::destroy_some(new_instances_cap);
                    instances::restore_export_cap(control_restore, cap_to_restore);
                };
                abort E_CAPS_NOT_READY;
            };
            new_legacy_cap = extracted;
        };

        if (need_instances_cap) {
            session.instances_cap = new_instances_cap;
        };
        if (need_legacy_cap) {
            session.legacy_cap = new_legacy_cap;
        };
    }

    #[view]
    public fun caps_ready(): bool acquires MigrationSession {
        if (!exists<MigrationSession>(@lottery)) {
            return false;
        };
        let session = borrow_global<MigrationSession>(@lottery);
        option::is_some(&session.instances_cap) && option::is_some(&session.legacy_cap)
    }

    #[view]
    public fun session_initialized(): bool {
        exists<MigrationSession>(@lottery)
    }

    public entry fun release_caps(caller: &signer)
    acquires MigrationSession, instances::InstanceControl, treasury::TreasuryV1Control {
        ensure_admin(caller);
        if (!exists<MigrationSession>(@lottery)) {
            abort E_SESSION_NOT_INITIALIZED;
        };
        let MigrationSession { instances_cap, legacy_cap } = move_from<MigrationSession>(@lottery);
        if (option::is_some(&instances_cap)) {
            let cap = option::destroy_some(instances_cap);
            let control = instances::borrow_control_mut(@lottery);
            instances::restore_export_cap(control, cap);
        } else {
            option::destroy_none(instances_cap);
        };
        if (option::is_some(&legacy_cap)) {
            let cap = option::destroy_some(legacy_cap);
            let control = treasury::borrow_control_mut(@lottery);
            treasury::restore_legacy_cap(control, cap);
        } else {
            option::destroy_none(legacy_cap);
        };
    }

    public fun borrow_instances_cap(): &instances::InstancesExportCap acquires MigrationSession {
        ensure_session_ready();
        let session = borrow_global<MigrationSession>(@lottery);
        option::borrow(&session.instances_cap)
    }

    public fun borrow_legacy_cap(): &treasury::LegacyTreasuryCap acquires MigrationSession {
        ensure_session_ready();
        let session = borrow_global<MigrationSession>(@lottery);
        option::borrow(&session.legacy_cap)
    }

    #[view]
    public fun session_snapshot(): option::Option<MigrationSessionSnapshot> acquires MigrationSession {
        if (!exists<MigrationSession>(@lottery)) {
            return option::none<MigrationSessionSnapshot>();
        };
        let session = borrow_global<MigrationSession>(@lottery);
        option::some(build_session_snapshot(&session))
    }

    public entry fun record_snapshot(caller: &signer, snapshot: MigrationSnapshot)
    acquires MigrationLedger {
        ensure_admin(caller);
        ensure_ledger_exists(caller);
        let state = borrow_global_mut<MigrationLedger>(@lottery);
        record_snapshot_internal(state, snapshot);
    }

    #[view]
    public fun list_migrated_lottery_ids(): vector<u64> acquires MigrationLedger {
        if (!exists<MigrationLedger>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_global<MigrationLedger>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_migration_snapshot(lottery_id: u64): option::Option<MigrationSnapshot>
    acquires MigrationLedger {
        if (!exists<MigrationLedger>(@lottery)) {
            return option::none<MigrationSnapshot>();
        };
        let state = borrow_global<MigrationLedger>(@lottery);
        if (!table::contains(&state.snapshots, lottery_id)) {
            option::none<MigrationSnapshot>()
        } else {
            option::some(*table::borrow(&state.snapshots, lottery_id))
        }
    }

    fun build_ledger_snapshot(ledger: &MigrationLedger): MigrationLedgerSnapshot {
        let lottery_ids = copy_u64_vector(&ledger.lottery_ids);
        let snapshots = collect_snapshots(&ledger.snapshots, &ledger.lottery_ids, 0, vector::length(&ledger.lottery_ids));
        MigrationLedgerSnapshot { lottery_ids, snapshots }
    }

    fun collect_snapshots(
        snapshots_table: &table::Table<u64, MigrationSnapshot>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<MigrationSnapshot> {
        if (index >= len) {
            return vector::empty<MigrationSnapshot>();
        };
        let head_id = *vector::borrow(lottery_ids, index);
        let mut result = vector::empty<MigrationSnapshot>();
        if (table::contains(snapshots_table, head_id)) {
            vector::push_back(&mut result, *table::borrow(snapshots_table, head_id));
        };
        let tail = collect_snapshots(snapshots_table, lottery_ids, index + 1, len);
        append_snapshots(&mut result, &tail, 0, vector::length(&tail));
        result
    }

    fun append_snapshots(
        dest: &mut vector<MigrationSnapshot>,
        src: &vector<MigrationSnapshot>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        vector::push_back(dest, *vector::borrow(src, index));
        append_snapshots(dest, src, index + 1, len);
    }

    #[test_only]
    public fun migration_snapshot_fields_for_test(
        snapshot: &MigrationSnapshot,
    ): (u64, u64, u64, u64, bool, bool, bool, u64, u64, u64, u64) {
        (
            snapshot.lottery_id,
            snapshot.ticket_count,
            snapshot.legacy_next_ticket_id,
            snapshot.migrated_next_ticket_id,
            snapshot.legacy_draw_scheduled,
            snapshot.migrated_draw_scheduled,
            snapshot.legacy_pending_request,
            snapshot.jackpot_amount_migrated,
            snapshot.prize_bps,
            snapshot.jackpot_bps,
            snapshot.operations_bps,
        )
    }

    #[test_only]
    public fun migration_snapshot_event_fields_for_test(
        event: &MigrationSnapshotUpdatedEvent,
    ): (u64, MigrationSnapshot) {
        (event.lottery_id, event.snapshot)
    }

    #[test_only]
    public fun migration_snapshot_for_test(
        lottery_id: u64,
        ticket_count: u64,
        legacy_next_ticket_id: u64,
        migrated_next_ticket_id: u64,
        legacy_draw_scheduled: bool,
        migrated_draw_scheduled: bool,
        legacy_pending_request: bool,
        jackpot_amount_migrated: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ): MigrationSnapshot {
        MigrationSnapshot {
            lottery_id,
            ticket_count,
            legacy_next_ticket_id,
            migrated_next_ticket_id,
            legacy_draw_scheduled,
            migrated_draw_scheduled,
            legacy_pending_request,
            jackpot_amount_migrated,
            prize_bps,
            jackpot_bps,
            operations_bps,
        }
    }

    fun ensure_session_ready() acquires MigrationSession {
        if (!exists<MigrationSession>(@lottery)) {
            abort E_CAPS_NOT_READY;
        };
        let session = borrow_global<MigrationSession>(@lottery);
        if (!option::is_some(&session.instances_cap) || !option::is_some(&session.legacy_cap)) {
            abort E_CAPS_NOT_READY;
        };
    }

    fun ensure_ledger_exists(caller: &signer) acquires MigrationLedger {
        if (exists<MigrationLedger>(@lottery)) {
            return;
        };
        move_to(
            caller,
            MigrationLedger {
                snapshots: table::new<u64, MigrationSnapshot>(),
                lottery_ids: vector::empty<u64>(),
                snapshot_events: account::new_event_handle<MigrationSnapshotUpdatedEvent>(caller),
            },
        );
    }

    fun record_snapshot_internal(state: &mut MigrationLedger, snapshot: MigrationSnapshot) {
        let lottery_id = snapshot.lottery_id;
        table::add(&mut state.snapshots, lottery_id, snapshot);
        record_lottery_id(&mut state.lottery_ids, lottery_id);
        let snapshot_for_event = *table::borrow(&state.snapshots, lottery_id);
        event::emit_event(
            &mut state.snapshot_events,
            MigrationSnapshotUpdatedEvent { lottery_id, snapshot: snapshot_for_event },
        );
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        if (contains_lottery_id(ids, lottery_id, 0)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun contains_lottery_id(ids: &vector<u64>, lottery_id: u64, index: u64): bool {
        let len = vector::length(ids);
        if (index >= len) {
            return false;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            return true;
        };
        contains_lottery_id(ids, lottery_id, index + 1)
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        copy_u64_vector_from(values, 0, vector::empty<u64>())
    }

    fun copy_u64_vector_from(
        values: &vector<u64>,
        index: u64,
        acc: vector<u64>,
    ): vector<u64> {
        let len = vector::length(values);
        if (index >= len) {
            return acc;
        };
        let value = *vector::borrow(values, index);
        let mut next = acc;
        vector::push_back(&mut next, value);
        copy_u64_vector_from(values, index + 1, next)
    }

    fun ensure_admin(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun build_session_snapshot(session: &MigrationSession): MigrationSessionSnapshot {
        MigrationSessionSnapshot {
            instances_cap_ready: option::is_some(&session.instances_cap),
            legacy_cap_ready: option::is_some(&session.legacy_cap),
        }
    }
}
