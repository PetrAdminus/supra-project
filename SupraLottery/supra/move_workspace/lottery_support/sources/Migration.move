module lottery_support::support_migration {
    use std::option;
    use std::signer;
    use std::vector;
    use lottery_core::core_instances as instances;
    use lottery_core::core_main_v2 as main_v2;
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_treasury_multi as treasury_multi;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_factory::registry;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSTANCE_MISSING: u64 = 2;
    const E_PENDING_REQUEST: u64 = 3;
    const E_ALREADY_MIGRATED: u64 = 4;
    const E_CAPS_NOT_READY: u64 = 5;
    const E_SESSION_NOT_ADMIN: u64 = 6;

    struct MigrationLedger has key {
        snapshots: table::Table<u64, MigrationSnapshot>,
        lottery_ids: vector<u64>,
        snapshot_events: event::EventHandle<MigrationSnapshotUpdatedEvent>,
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
        legacy_cap: option::Option<treasury_v1::LegacyTreasuryCap>,
    }

    public fun ensure_caps_initialized(admin: &signer) {
        ensure_admin(admin);
        if (exists<MigrationSession>(@lottery)) {
            return
        };
        let instances_cap = instances::borrow_instances_export_cap(admin);
        let legacy_cap = treasury_v1::borrow_legacy_treasury_cap(admin);
        move_to(
            admin,
            MigrationSession {
                instances_cap: option::some(instances_cap),
                legacy_cap: option::some(legacy_cap),
            },
        );
    }

    #[view]
    public fun caps_ready(): bool acquires MigrationSession {
        if (!exists<MigrationSession>(@lottery)) {
            return false
        };
        let session = borrow_global<MigrationSession>(@lottery);
        option::is_some(&session.instances_cap) && option::is_some(&session.legacy_cap)
    }

    public fun release_caps(admin: &signer) acquires MigrationSession {
        ensure_admin(admin);
        if (!exists<MigrationSession>(@lottery)) {
            return
        };
        let MigrationSession {
            instances_cap,
            legacy_cap,
        } = move_from<MigrationSession>(@lottery);

        let instances_cap_opt = instances_cap;
        if (option::is_some(&instances_cap_opt)) {
            let cap = option::destroy_some(instances_cap_opt);
            instances::return_instances_export_cap(admin, cap);
        } else {
            option::destroy_none(instances_cap_opt);
        };

        let legacy_cap_opt = legacy_cap;
        if (option::is_some(&legacy_cap_opt)) {
            let cap = option::destroy_some(legacy_cap_opt);
            treasury_v1::return_legacy_treasury_cap(admin, cap);
        } else {
            option::destroy_none(legacy_cap_opt);
        };
    }

    public entry fun migrate_from_legacy(
        caller: &signer,
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ) acquires MigrationLedger, MigrationSession {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        ensure_caps_initialized(caller);
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };
        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_INSTANCE_MISSING
        };

        let (
            tickets,
            draw_scheduled,
            next_ticket_id_legacy,
            pending_request,
            jackpot_amount,
        ) = main_v2::export_state_for_migration(caller);

        let pending_request_present = option::is_some(&pending_request);
        if (pending_request_present) {
            abort E_PENDING_REQUEST
        };

        let pool_opt = treasury_multi::get_pool(lottery_id);
        if (option::is_some(&pool_opt)) {
            abort E_ALREADY_MIGRATED
        };

        treasury_multi::upsert_lottery_config(caller, lottery_id, prize_bps, jackpot_bps, operations_bps);

        let ticket_count = vector::length(&tickets);
        let next_ticket_id = ticket_count;
        let effective_draw = draw_scheduled && ticket_count > 0;

        treasury_multi::migrate_seed_pool(caller, lottery_id, jackpot_amount, 0, 0);
        {
            if (!exists<MigrationSession>(@lottery)) {
                abort E_CAPS_NOT_READY
            };
            let session = borrow_global<MigrationSession>(@lottery);
            if (!option::is_some(&session.instances_cap)) {
                abort E_CAPS_NOT_READY
            };
            let instances_cap_ref = option::borrow(&session.instances_cap);
            if (!option::is_some(&session.legacy_cap)) {
                abort E_CAPS_NOT_READY
            };
            let _legacy_cap_ref = option::borrow(&session.legacy_cap);
            instances::migrate_override_stats(instances_cap_ref, lottery_id, ticket_count, 0);
        };
        rounds::migrate_import_round(
            caller,
            lottery_id,
            tickets,
            effective_draw,
            next_ticket_id,
            pending_request,
        );

        let snapshot = MigrationSnapshot {
            lottery_id,
            ticket_count,
            legacy_next_ticket_id: next_ticket_id_legacy,
            migrated_next_ticket_id: next_ticket_id,
            legacy_draw_scheduled: draw_scheduled,
            migrated_draw_scheduled: effective_draw,
            legacy_pending_request: pending_request_present,
            jackpot_amount_migrated: jackpot_amount,
            prize_bps,
            jackpot_bps,
            operations_bps,
        };
        record_snapshot(caller, snapshot);

        main_v2::clear_state_after_migration(caller);
    }

    #[view]
    public fun list_migrated_lottery_ids(): vector<u64> acquires MigrationLedger {
        if (!exists<MigrationLedger>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<MigrationLedger>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_migration_snapshot(
        lottery_id: u64
    ): option::Option<MigrationSnapshot> acquires MigrationLedger {
        if (!exists<MigrationLedger>(@lottery)) {
            return option::none<MigrationSnapshot>()
        };
        let state = borrow_global<MigrationLedger>(@lottery);
        if (!table::contains(&state.snapshots, lottery_id)) {
            option::none<MigrationSnapshot>()
        } else {
            option::some(*table::borrow(&state.snapshots, lottery_id))
        }
    }

    #[test_only]
    public fun migration_snapshot_fields_for_test(
        snapshot: &MigrationSnapshot
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
        event: &MigrationSnapshotUpdatedEvent
    ): (u64, MigrationSnapshot) {
        (event.lottery_id, event.snapshot)
    }

    fun record_snapshot(caller: &signer, snapshot: MigrationSnapshot) acquires MigrationLedger {
        ensure_ledger(caller);
        let lottery_id = snapshot.lottery_id;
        {
            let state = borrow_global_mut<MigrationLedger>(@lottery);
            table::add(&mut state.snapshots, lottery_id, snapshot);
            record_lottery_id(&mut state.lottery_ids, lottery_id);
            let snapshot_for_event = *table::borrow(&state.snapshots, lottery_id);
            event::emit_event(
                &mut state.snapshot_events,
                MigrationSnapshotUpdatedEvent {
                    lottery_id,
                    snapshot: snapshot_for_event,
                },
            );
        };
    }

    fun ensure_ledger(caller: &signer) {
        if (!exists<MigrationLedger>(@lottery)) {
            move_to(
                caller,
                MigrationLedger {
                    snapshots: table::new(),
                    lottery_ids: vector::empty<u64>(),
                    snapshot_events: account::new_event_handle<MigrationSnapshotUpdatedEvent>(caller),
                },
            );
        };
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(ids, lottery_id);
    }

    fun ensure_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_SESSION_NOT_ADMIN
        };
    }




    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        let out = vector::empty<u64>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            let value = *vector::borrow(values, idx);
            vector::push_back(&mut out, value);
            idx = idx + 1;
        };
        out
    }
}



