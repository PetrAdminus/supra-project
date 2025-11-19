#[test_only]
module lottery_utils::migration_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury;
    use lottery_utils::migration;

    #[test(lottery_admin = @lottery)]
    fun ensure_caps_initialized_transfers_caps(lottery_admin: &signer) {
        instances::init_control(lottery_admin);
        treasury::init_control(lottery_admin);

        assert!(!migration::caps_ready(), 0);
        migration::ensure_caps_initialized(lottery_admin);
        assert!(migration::caps_ready(), 1);

        let instances_control = instances::borrow_control(@lottery);
        assert!(!instances::export_cap_available(instances_control), 2);

        let treasury_control = treasury::borrow_control(@lottery);
        assert!(!treasury::legacy_cap_available(treasury_control), 3);

        let snapshot_opt = migration::session_snapshot();
        assert!(option::is_some(&snapshot_opt), 4);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.instances_cap_ready, 5);
        assert!(snapshot.legacy_cap_ready, 6);
    }

    #[test(lottery_admin = @lottery)]
    fun release_caps_restores_control(lottery_admin: &signer) {
        instances::init_control(lottery_admin);
        treasury::init_control(lottery_admin);
        migration::ensure_caps_initialized(lottery_admin);

        migration::release_caps(lottery_admin);

        assert!(!migration::session_initialized(), 0);
        let instances_control = instances::borrow_control(@lottery);
        assert!(instances::export_cap_available(instances_control), 1);

        let treasury_control = treasury::borrow_control(@lottery);
        assert!(treasury::legacy_cap_available(treasury_control), 2);
    }

    #[test(lottery_admin = @lottery)]
    fun record_snapshot_initializes_ledger(lottery_admin: &signer) {
        let first_snapshot = migration::migration_snapshot_for_test(
            11,
            5_000,
            10,
            5_000,
            true,
            false,
            false,
            100_000,
            7_000,
            2_000,
            1_000,
        );
        migration::record_snapshot(lottery_admin, first_snapshot);

        let ledger_opt = migration::ledger_snapshot();
        assert!(option::is_some(&ledger_opt), 0);
        let ledger = option::destroy_some(ledger_opt);
        assert!(vector::length(&ledger.lottery_ids) == 1, 1);
        assert!(*vector::borrow(&ledger.lottery_ids, 0) == 11, 2);
        assert!(vector::length(&ledger.snapshots) == 1, 3);

        let stored_snapshot = *vector::borrow(&ledger.snapshots, 0);
        let (
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
        ) = migration::migration_snapshot_fields_for_test(&stored_snapshot);
        assert!(lottery_id == 11, 4);
        assert!(ticket_count == 5_000, 5);
        assert!(legacy_next_ticket_id == 10, 6);
        assert!(migrated_next_ticket_id == 5_000, 7);
        assert!(legacy_draw_scheduled, 8);
        assert!(!migrated_draw_scheduled, 9);
        assert!(!legacy_pending_request, 10);
        assert!(jackpot_amount_migrated == 100_000, 11);
        assert!(prize_bps == 7_000, 12);
        assert!(jackpot_bps == 2_000, 13);
        assert!(operations_bps == 1_000, 14);

        let updated_snapshot = migration::migration_snapshot_for_test(
            11,
            7_500,
            20,
            7_500,
            false,
            true,
            true,
            250_000,
            6_500,
            2_500,
            1_000,
        );
        migration::record_snapshot(lottery_admin, updated_snapshot);

        let ids = migration::list_migrated_lottery_ids();
        assert!(vector::length(&ids) == 1, 15);
        assert!(*vector::borrow(&ids, 0) == 11, 16);

        let snapshot_opt = migration::get_migration_snapshot(11);
        assert!(option::is_some(&snapshot_opt), 17);
        let snapshot = option::destroy_some(snapshot_opt);
        let (
            _,
            ticket_count_after,
            legacy_next_after,
            migrated_next_after,
            legacy_draw_after,
            migrated_draw_after,
            legacy_pending_after,
            jackpot_after,
            prize_after,
            jackpot_bps_after,
            operations_after,
        ) = migration::migration_snapshot_fields_for_test(&snapshot);
        assert!(ticket_count_after == 7_500, 18);
        assert!(legacy_next_after == 20, 19);
        assert!(migrated_next_after == 7_500, 20);
        assert!(!legacy_draw_after, 21);
        assert!(migrated_draw_after, 22);
        assert!(legacy_pending_after, 23);
        assert!(jackpot_after == 250_000, 24);
        assert!(prize_after == 6_500, 25);
        assert!(jackpot_bps_after == 2_500, 26);
        assert!(operations_after == 1_000, 27);
    }
}
