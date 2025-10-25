#[test_only]
module lottery_support::migration_tests {
    use std::option;
    use std::signer;
    use std::vector;
    use lottery_core::instances;
    use lottery_core::main_v2;
    use lottery_core::rounds;
    use lottery_core::test_utils;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use lottery_support::migration;
    use vrf_hub::hub;

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @vrf_hub
    )]
    fun migration_cap_lifecycle(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
    ) {
        setup_environment(lottery_admin, factory_admin, vrf_admin);
        assert!(!migration::caps_ready(), 0);

        migration::ensure_caps_initialized(lottery_admin);
        assert!(migration::caps_ready(), 1);

        // Reinitializing should be idempotent.
        migration::ensure_caps_initialized(lottery_admin);
        assert!(migration::caps_ready(), 2);

        migration::release_caps(lottery_admin);
        assert!(!migration::caps_ready(), 3);

        migration::ensure_caps_initialized(lottery_admin);
        assert!(migration::caps_ready(), 4);
        migration::release_caps(lottery_admin);
        assert!(!migration::caps_ready(), 5);
    }

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @vrf_hub
    )]
    #[expected_failure(
        location = lottery_core::instances,
        abort_code = instances::E_EXPORT_CAP_ALREADY_BORROWED
    )]
    fun migration_session_locks_instances_cap(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
    ) {
        setup_environment(lottery_admin, factory_admin, vrf_admin);
        migration::ensure_caps_initialized(lottery_admin);
        // Borrowing the capability a second time must abort in the core module.
        instances::borrow_instances_export_cap(lottery_admin);
    }

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @vrf_hub,
        lottery_owner = @player1,
        lottery_contract = @player2
    )]
    fun migrate_legacy_state(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
        lottery_owner: &signer,
        lottery_contract: &signer,
    ) {
        let _ = test_utils::drain_events<migration::MigrationSnapshotUpdatedEvent>();
        setup_environment(lottery_admin, factory_admin, vrf_admin);

        let metadata = vector::empty<u8>();
        let blueprint = registry::new_blueprint(100, 1_000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            signer::address_of(lottery_owner),
            signer::address_of(lottery_contract),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery_admin, lottery_id);

        let tickets = vector::empty<address>();
        vector::push_back(&mut tickets, signer::address_of(lottery_owner));
        vector::push_back(&mut tickets, signer::address_of(lottery_contract));
        main_v2::set_draw_state_for_test(true, tickets);
        main_v2::set_jackpot_amount_for_test(500);
        main_v2::set_next_ticket_id_for_test(3);
        main_v2::set_pending_request_for_test(option::none<u64>());

        migration::migrate_from_legacy(lottery_admin, lottery_id, 9_000, 1_000, 0);

        let stats_opt = instances::get_instance_stats(lottery_id);
        assert!(option::is_some(&stats_opt), 0);
        let stats = test_utils::unwrap(&mut stats_opt);
        assert!(stats.tickets_sold == 2, stats.tickets_sold);
        assert!(stats.jackpot_accumulated == 0, stats.jackpot_accumulated);
        assert!(stats.active, 6);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        assert!(option::is_some(&snapshot_opt), 1);
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (
            ticket_count,
            draw_scheduled,
            has_pending_request,
            next_ticket_id,
            _pending_request_id,
        ) = rounds::round_snapshot_fields_for_test(&snapshot);
        assert!(ticket_count == 2, ticket_count);
        assert!(draw_scheduled, 2);
        assert!(!has_pending_request, 3);
        assert!(next_ticket_id == 2, next_ticket_id);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        assert!(option::is_some(&pool_opt), 4);
        let pool = test_utils::unwrap(&mut pool_opt);
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 500, prize_balance);
        assert!(operations_balance == 0, operations_balance);
        assert!(treasury_multi::jackpot_balance() == 0, treasury_multi::jackpot_balance());

        let config_opt = treasury_multi::get_config(lottery_id);
        assert!(option::is_some(&config_opt), 5);
        let config = test_utils::unwrap(&mut config_opt);
        let (prize_bps, jackpot_bps, operations_bps) =
            treasury_multi::share_config_bps_for_test(&config);
        assert!(prize_bps == 9_000, prize_bps);
        assert!(jackpot_bps == 1_000, jackpot_bps);
        assert!(operations_bps == 0, operations_bps);

        assert!(main_v2::get_jackpot_amount() == 0, main_v2::get_jackpot_amount());

        let migrated_ids = migration::list_migrated_lottery_ids();
        assert!(vector::length(&migrated_ids) == 1, 11);
        assert!(*vector::borrow(&migrated_ids, 0) == lottery_id, 12);

        let snapshot_opt = migration::get_migration_snapshot(lottery_id);
        assert!(option::is_some(&snapshot_opt), 13);
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (
            snapshot_lottery_id,
            snapshot_ticket_count,
            legacy_next_ticket_id,
            migrated_next_ticket_id,
            legacy_draw_scheduled,
            migrated_draw_scheduled,
            legacy_pending_request,
            jackpot_amount_migrated,
            snapshot_prize_bps,
            snapshot_jackpot_bps,
            snapshot_operations_bps,
        ) = migration::migration_snapshot_fields_for_test(&snapshot);
        assert!(snapshot_lottery_id == lottery_id, 14);
        assert!(snapshot_ticket_count == 2, snapshot_ticket_count);
        assert!(legacy_next_ticket_id == 3, legacy_next_ticket_id);
        assert!(migrated_next_ticket_id == 2, migrated_next_ticket_id);
        assert!(legacy_draw_scheduled, 15);
        assert!(migrated_draw_scheduled, 16);
        assert!(!legacy_pending_request, 17);
        assert!(jackpot_amount_migrated == 500, jackpot_amount_migrated);
        assert!(snapshot_prize_bps == 9_000, snapshot_prize_bps);
        assert!(snapshot_jackpot_bps == 1_000, snapshot_jackpot_bps);
        assert!(snapshot_operations_bps == 0, snapshot_operations_bps);

        let snapshot_events =
            test_utils::drain_events<migration::MigrationSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<migration::MigrationSnapshotUpdatedEvent>(&snapshot_events, 1, 18);
        let latest_event = test_utils::last_event_ref(&snapshot_events);
        let (event_lottery_id, event_snapshot) =
            migration::migration_snapshot_event_fields_for_test(latest_event);
        assert!(event_lottery_id == lottery_id, 19);
        let (
            event_snapshot_lottery_id,
            event_ticket_count,
            event_legacy_next_ticket_id,
            event_migrated_next_ticket_id,
            event_legacy_draw_scheduled,
            event_migrated_draw_scheduled,
            event_legacy_pending_request,
            event_jackpot_amount,
            event_prize_bps,
            event_jackpot_bps,
            event_operations_bps,
        ) = migration::migration_snapshot_fields_for_test(&event_snapshot);
        assert!(event_snapshot_lottery_id == lottery_id, 20);
        assert!(event_ticket_count == 2, 21);
        assert!(event_legacy_next_ticket_id == 3, 22);
        assert!(event_migrated_next_ticket_id == 2, 23);
        assert!(event_legacy_draw_scheduled, 24);
        assert!(event_migrated_draw_scheduled, 25);
        assert!(!event_legacy_pending_request, 26);
        assert!(event_jackpot_amount == 500, 27);
        assert!(event_prize_bps == 9_000, 28);
        assert!(event_jackpot_bps == 1_000, 29);
        assert!(event_operations_bps == 0, 30);

        migration::release_caps(lottery_admin);
    }

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @vrf_hub
    )]
    #[expected_failure(
        location = lottery_support::migration,
        abort_code = migration::E_PENDING_REQUEST
    )]
    fun migration_rejects_pending_request(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
    ) {
        setup_environment(lottery_admin, factory_admin, vrf_admin);

        let blueprint = registry::new_blueprint(100, 1_000);
        let metadata = vector::empty<u8>();
        let lottery_id = registry::create_lottery(
            factory_admin,
            signer::address_of(lottery_admin),
            signer::address_of(lottery_admin),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery_admin, lottery_id);

        main_v2::set_draw_state_for_test(false, vector::empty<address>());
        main_v2::set_jackpot_amount_for_test(0);
        main_v2::set_pending_request_for_test(option::some(7));

        migration::migrate_from_legacy(lottery_admin, lottery_id, 10_000, 0, 0);
    }

    fun setup_environment(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
    ) {
        test_utils::ensure_core_accounts();
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                lottery_admin,
                b"seed",
                b"Legacy Token",
                b"LEG",
                6,
                b"",
                b"",
            );
        };
        if (!treasury_v1::is_core_control_initialized()) {
            treasury_v1::init(lottery_admin);
        };
        treasury_v1::register_store(lottery_admin);
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);

        if (!hub::is_initialized()) {
            hub::init(vrf_admin);
        };
        if (!registry::is_initialized()) {
            registry::init(factory_admin);
        };
        if (!instances::is_initialized()) {
            instances::init(lottery_admin, @vrf_hub);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        if (!rounds::is_initialized()) {
            rounds::init(lottery_admin);
        };
        if (!main_v2::is_initialized()) {
            main_v2::init(lottery_admin);
        };
    }
}
