#[test_only]
module lottery::migration_tests {
    use std::option;
    use std::signer;
    use std::vector;
    use lottery::instances;
    use lottery::main_v2;
    use lottery::migration;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use supra_framework::event;
    use vrf_hub::hub;

    #[test(lottery = @lottery, lottery_owner = @player1, lottery_contract = @player2)]
    fun migrate_legacy_state(
        lottery: &signer,
        lottery_owner: &signer,
        lottery_contract: &signer,
    ) {
        setup_environment(lottery);

        let metadata = vector::empty<u8>();
        let blueprint = registry::new_blueprint(100, 1_000);
        let lottery_id = registry::create_lottery(
            lottery,
            signer::address_of(lottery),
            signer::address_of(lottery),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery, lottery_id);

        let tickets = vector::empty<address>();
        vector::push_back(&mut tickets, signer::address_of(lottery_owner));
        vector::push_back(&mut tickets, signer::address_of(lottery_contract));
        main_v2::set_draw_state_for_test(true, tickets);
        main_v2::set_jackpot_amount_for_test(500);
        main_v2::set_next_ticket_id_for_test(3);
        main_v2::set_pending_request_for_test(option::none());

        migration::migrate_from_legacy(lottery, lottery_id, 9_000, 1_000, 0);

        let mut stats_opt = instances::get_instance_stats(lottery_id);
        assert!(option::is_some(&stats_opt), 0);
        let stats = test_utils::unwrap(&mut stats_opt);
        let (tickets_sold, jackpot_accumulated, active) =
            instances::instance_stats_for_test(&stats);
        assert!(tickets_sold == 2, tickets_sold);
        assert!(jackpot_accumulated == 0, jackpot_accumulated);
        assert!(active, 6);

        let mut snapshot_opt = rounds::get_round_snapshot(lottery_id);
        assert!(option::is_some(&snapshot_opt), 1);
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (
            ticket_count,
            draw_scheduled,
            has_pending_request,
            next_ticket_id,
            _,
        ) = rounds::round_snapshot_fields_for_test(&snapshot);
        assert!(ticket_count == 2, ticket_count);
        assert!(draw_scheduled, 2);
        assert!(!has_pending_request, 3);
        assert!(next_ticket_id == 2, next_ticket_id);

        let mut pool_opt = treasury_multi::get_pool(lottery_id);
        assert!(option::is_some(&pool_opt), 4);
        let pool = test_utils::unwrap(&mut pool_opt);
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 500, prize_balance);
        assert!(operations_balance == 0, operations_balance);
        assert!(treasury_multi::jackpot_balance() == 0, treasury_multi::jackpot_balance());

        let config_opt = treasury_multi::get_config(lottery_id);
        assert!(option::is_some(&config_opt), 5);
        assert!(main_v2::get_jackpot_amount() == 0, main_v2::get_jackpot_amount());

        let migrated_ids = migration::list_migrated_lottery_ids();
        assert!(vector::length(&migrated_ids) == 1, 11);
        assert!(*vector::borrow(&migrated_ids, 0) == lottery_id, 12);

        let mut snapshot_opt = migration::get_migration_snapshot(lottery_id);
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

        let snapshot_events = event::emitted_events<migration::MigrationSnapshotUpdatedEvent>();
        let events_len = vector::length(&snapshot_events);
        assert!(events_len >= 1, 18);
        let latest_event = vector::borrow(&snapshot_events, events_len - 1);
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
    }

    #[test(lottery = @lottery)]
    #[expected_failure(location = lottery::migration, abort_code = migration::E_PENDING_REQUEST)]
    fun migration_rejects_pending_request(lottery: &signer) {
        setup_environment(lottery);

        let blueprint = registry::new_blueprint(100, 1_000);
        let metadata = vector::empty<u8>();
        let lottery_id = registry::create_lottery(
            lottery,
            signer::address_of(lottery),
            signer::address_of(lottery),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery, lottery_id);

        main_v2::set_draw_state_for_test(false, vector::empty<address>());
        main_v2::set_jackpot_amount_for_test(0);
        main_v2::set_pending_request_for_test(option::some(7));

        migration::migrate_from_legacy(lottery, lottery_id, 10_000, 0, 0);
    }

    fun setup_environment(lottery: &signer) {
        test_utils::ensure_core_accounts();
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                lottery,
                b"seed",
                b"Legacy Token",
                b"LEG",
                6,
                b"",
                b"",
            );
        };
        if (!main_v2::is_initialized()) {
            main_v2::init(lottery);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(
                lottery,
                signer::address_of(lottery),
                signer::address_of(lottery),
            );
        };
        if (!hub::is_initialized()) {
            hub::init(lottery);
        };
        if (!registry::is_initialized()) {
            registry::init(lottery);
        };
        if (!instances::is_initialized()) {
            instances::init(lottery, signer::address_of(lottery));
        };
        if (!rounds::is_initialized()) {
            rounds::init(lottery);
        };
    }
}
