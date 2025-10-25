#[test_only]
module lottery::autopurchase_tests {
    use std::vector;
    use std::signer;
    use lottery::autopurchase;
    use lottery_core::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    const TICKET_PRICE: u64 = 100;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        test_utils::ensure_core_accounts();
        treasury_v1::init_token(
            lottery_admin,
            b"autopurchase_seed",
            b"Auto Token",
            b"AUTO",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(buyer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 20_000);
    }

    fun setup_lottery(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ): u64 {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        autopurchase::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(TICKET_PRICE, 2000);
        registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            b"autopurchase-test",
        )
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player1,
    )]
    fun executes_autopurchase_plan(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        setup_token(lottery_admin, buyer);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        let _ = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseRefundedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 2, true);
        let config_events =
            test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseConfigUpdatedEvent>(
            &config_events,
            1,
            1400,
        );
        let config_event = *test_utils::last_event_ref(&config_events);
        let autopurchase::AutopurchaseConfigUpdatedEvent {
            lottery_id: config_lottery,
            player: config_player,
            tickets_per_draw: config_tickets,
            active: config_active,
        } = config_event;
        assert!(config_lottery == lottery_id, 1401);
        assert!(config_player == signer::address_of(buyer), 1402);
        assert!(config_tickets == 2, 1403);
        assert!(config_active, 1404);

        let config_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &config_snapshot_events,
            1,
            1405,
        );
        let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
        let (config_admin, config_snapshot) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(config_snapshot_event);
        assert!(config_admin == signer::address_of(lottery_admin), 1406);
        let (
            config_total_balance,
            config_total_players,
            config_active_players,
            config_player_snapshots,
        ) = autopurchase::lottery_snapshot_fields_for_test(&config_snapshot);
        assert!(config_total_balance == 0, 1407);
        assert!(config_total_players == 1, 1408);
        assert!(config_active_players == 1, 1409);
        assert!(vector::length(&config_player_snapshots) == 1, 1410);
        let config_player_snapshot = vector::borrow(&config_player_snapshots, 0);
        let (
            config_player_addr,
            config_plan_balance,
            config_plan_tickets,
            config_plan_active,
        ) = autopurchase::player_snapshot_fields_for_test(config_player_snapshot);
        assert!(config_player_addr == signer::address_of(buyer), 1411);
        assert!(config_plan_balance == 0, 1412);
        assert!(config_plan_tickets == 2, 1413);
        assert!(config_plan_active, 1414);

        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE * 3);
        let deposit_events = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseDepositEvent>(
            &deposit_events,
            1,
            1415,
        );
        let deposit_event = *test_utils::last_event_ref(&deposit_events);
        let autopurchase::AutopurchaseDepositEvent {
            lottery_id: deposit_lottery,
            player: deposit_player,
            amount: deposit_amount,
            new_balance: deposit_balance,
        } = deposit_event;
        assert!(deposit_lottery == lottery_id, 1416);
        assert!(deposit_player == signer::address_of(buyer), 1417);
        assert!(deposit_amount == TICKET_PRICE * 3, 1418);
        assert!(deposit_balance == TICKET_PRICE * 3, 1419);

        let deposit_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &deposit_snapshot_events,
            1,
            1420,
        );
        let deposit_snapshot_event = test_utils::last_event_ref(&deposit_snapshot_events);
        let (deposit_admin, deposit_snapshot) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(deposit_snapshot_event);
        assert!(deposit_admin == signer::address_of(lottery_admin), 1421);
        let (
            deposit_total_balance,
            deposit_total_players,
            deposit_active_players,
            deposit_player_snapshots,
        ) = autopurchase::lottery_snapshot_fields_for_test(&deposit_snapshot);
        assert!(deposit_total_balance == TICKET_PRICE * 3, 1422);
        assert!(deposit_total_players == 1, 1423);
        assert!(deposit_active_players == 1, 1424);
        assert!(vector::length(&deposit_player_snapshots) == 1, 1425);
        let deposit_player_snapshot = vector::borrow(&deposit_player_snapshots, 0);
        let (
            deposit_player_addr,
            deposit_plan_balance,
            deposit_plan_tickets,
            deposit_plan_active,
        ) = autopurchase::player_snapshot_fields_for_test(deposit_player_snapshot);
        assert!(deposit_player_addr == signer::address_of(buyer), 1426);
        assert!(deposit_plan_balance == TICKET_PRICE * 3, 1427);
        assert!(deposit_plan_tickets == 2, 1428);
        assert!(deposit_plan_active, 1429);

        let summary_before_opt = autopurchase::get_lottery_summary(lottery_id);
        let summary_before = test_utils::unwrap(&mut summary_before_opt);
        let (balance_before, total_players, active_players) =
            autopurchase::summary_fields_for_test(&summary_before);
        assert!(balance_before == TICKET_PRICE * 3, 9);
        assert!(total_players == 1, 10);
        assert!(active_players == 1, 11);

        let players_opt = autopurchase::list_players(lottery_id);
        let players = test_utils::unwrap(&mut players_opt);
        assert!(vector::length(&players) == 1, 12);
        assert!(*vector::borrow(&players, 0) == @player1, 13);

        let lotteries = autopurchase::list_lottery_ids();
        assert!(vector::length(&lotteries) == 1, 14);
        assert!(*vector::borrow(&lotteries, 0) == lottery_id, 15);

        let lottery_snapshot_opt = autopurchase::get_lottery_snapshot(lottery_id);
        let lottery_snapshot = test_utils::unwrap(&mut lottery_snapshot_opt);
        let (balance_snapshot, players_count_snapshot, active_players_snapshot, player_snapshots) =
            autopurchase::lottery_snapshot_fields_for_test(&lottery_snapshot);
        assert!(balance_snapshot == TICKET_PRICE * 3, 35);
        assert!(players_count_snapshot == 1, 36);
        assert!(active_players_snapshot == 1, 37);
        assert!(vector::length(&player_snapshots) == 1, 38);
        let first_player = vector::borrow(&player_snapshots, 0);
        let (player_addr, plan_balance, plan_tickets, plan_active) =
            autopurchase::player_snapshot_fields_for_test(first_player);
        assert!(player_addr == @player1, 39);
        assert!(plan_balance == TICKET_PRICE * 3, 40);
        assert!(plan_tickets == 2, 41);
        assert!(plan_active, 42);

        let autopurchase_snapshot_opt = autopurchase::get_autopurchase_snapshot();
        let autopurchase_snapshot = test_utils::unwrap(&mut autopurchase_snapshot_opt);
        let (admin_addr, lotteries_snapshot) =
            autopurchase::autopurchase_snapshot_fields_for_test(&autopurchase_snapshot);
        assert!(admin_addr == signer::address_of(lottery_admin), 43);
        assert!(vector::length(&lotteries_snapshot) == 1, 44);

        autopurchase::execute(lottery_admin, lottery_id, @player1);
        let execute_events_1 =
            test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseExecutedEvent>(
            &execute_events_1,
            1,
            1430,
        );
        let execute_event_1 = *test_utils::last_event_ref(&execute_events_1);
        let autopurchase::AutopurchaseExecutedEvent {
            lottery_id: exec_lottery_1,
            player: exec_player_1,
            tickets_bought: exec_tickets_1,
            spent_amount: exec_spent_1,
            remaining_balance: exec_remaining_1,
        } = execute_event_1;
        assert!(exec_lottery_1 == lottery_id, 1431);
        assert!(exec_player_1 == @player1, 1432);
        assert!(exec_tickets_1 == 2, 1433);
        assert!(exec_spent_1 == TICKET_PRICE * 2, 1434);
        assert!(exec_remaining_1 == TICKET_PRICE, 1435);

        let snapshot_events_1 =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &snapshot_events_1,
            1,
            1436,
        );
        let snapshot_event_1 = test_utils::last_event_ref(&snapshot_events_1);
        let (exec_admin_1, exec_snapshot_1) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(snapshot_event_1);
        assert!(exec_admin_1 == signer::address_of(lottery_admin), 1437);
        let (
            exec_balance_1,
            exec_total_players_1,
            exec_active_players_1,
            exec_player_snapshots_1,
        ) = autopurchase::lottery_snapshot_fields_for_test(&exec_snapshot_1);
        assert!(exec_balance_1 == TICKET_PRICE, 1438);
        assert!(exec_total_players_1 == 1, 1439);
        assert!(exec_active_players_1 == 1, 1440);
        assert!(vector::length(&exec_player_snapshots_1) == 1, 1441);
        let exec_player_snapshot_1 = vector::borrow(&exec_player_snapshots_1, 0);
        let (
            exec_player_addr_1,
            exec_plan_balance_1,
            exec_plan_tickets_1,
            exec_plan_active_1,
        ) = autopurchase::player_snapshot_fields_for_test(exec_player_snapshot_1);
        assert!(exec_player_addr_1 == @player1, 1442);
        assert!(exec_plan_balance_1 == TICKET_PRICE, 1443);
        assert!(exec_plan_tickets_1 == 2, 1444);
        assert!(exec_plan_active_1, 1445);

        let plan_after_first_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_first = test_utils::unwrap(&mut plan_after_first_opt);
        let (balance_after_first, tickets_per_draw_after_first, active_after_first) =
            autopurchase::plan_fields_for_test(&plan_after_first);
        assert!(balance_after_first == TICKET_PRICE, 0);
        assert!(tickets_per_draw_after_first == 2, 1);
        assert!(active_after_first, 2);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (ticket_count, _, _, _, _) = rounds::round_snapshot_fields_for_test(&snapshot);
        assert!(ticket_count == 2, 3);

        let summary_mid_opt = autopurchase::get_lottery_summary(lottery_id);
        let summary_mid = test_utils::unwrap(&mut summary_mid_opt);
        let (balance_mid, total_players_mid, active_players_mid) =
            autopurchase::summary_fields_for_test(&summary_mid);
        assert!(balance_mid == TICKET_PRICE, 16);
        assert!(total_players_mid == 1, 17);
        assert!(active_players_mid == 1, 18);

        autopurchase::execute(lottery_admin, lottery_id, @player1);
        let execute_events_2 =
            test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseExecutedEvent>(
            &execute_events_2,
            1,
            1446,
        );
        let execute_event_2 = *test_utils::last_event_ref(&execute_events_2);
        let autopurchase::AutopurchaseExecutedEvent {
            lottery_id: exec_lottery_2,
            player: exec_player_2,
            tickets_bought: exec_tickets_2,
            spent_amount: exec_spent_2,
            remaining_balance: exec_remaining_2,
        } = execute_event_2;
        assert!(exec_lottery_2 == lottery_id, 1447);
        assert!(exec_player_2 == @player1, 1448);
        assert!(exec_tickets_2 == 1, 1449);
        assert!(exec_spent_2 == TICKET_PRICE, 1450);
        assert!(exec_remaining_2 == 0, 1451);

        let snapshot_events_2 =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &snapshot_events_2,
            1,
            1452,
        );
        let snapshot_event_2 = test_utils::last_event_ref(&snapshot_events_2);
        let (exec_admin_2, exec_snapshot_2) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(snapshot_event_2);
        assert!(exec_admin_2 == signer::address_of(lottery_admin), 1453);
        let (
            exec_balance_2,
            exec_total_players_2,
            exec_active_players_2,
            exec_player_snapshots_2,
        ) = autopurchase::lottery_snapshot_fields_for_test(&exec_snapshot_2);
        assert!(exec_balance_2 == 0, 1454);
        assert!(exec_total_players_2 == 1, 1455);
        assert!(exec_active_players_2 == 1, 1456);
        assert!(vector::length(&exec_player_snapshots_2) == 1, 1457);
        let exec_player_snapshot_2 = vector::borrow(&exec_player_snapshots_2, 0);
        let (
            exec_player_addr_2,
            exec_plan_balance_2,
            exec_plan_tickets_2,
            exec_plan_active_2,
        ) = autopurchase::player_snapshot_fields_for_test(exec_player_snapshot_2);
        assert!(exec_player_addr_2 == @player1, 1458);
        assert!(exec_plan_balance_2 == 0, 1459);
        assert!(exec_plan_tickets_2 == 2, 1460);
        assert!(exec_plan_active_2, 1461);

        let plan_after_second_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_second = test_utils::unwrap(&mut plan_after_second_opt);
        let (final_balance, _, _) = autopurchase::plan_fields_for_test(&plan_after_second);
        assert!(final_balance == 0, 4);

        let summary_final_opt = autopurchase::get_lottery_summary(lottery_id);
        let summary_final = test_utils::unwrap(&mut summary_final_opt);
        let (balance_final, _, _) = autopurchase::summary_fields_for_test(&summary_final);
        assert!(balance_final == 0, 19);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        let pool_snapshot = test_utils::unwrap(&mut pool_opt);
        let (prize_balance, operations_balance) =
            treasury_multi::pool_balances_for_test(&pool_snapshot);
        assert!(prize_balance == 210, 5);
        assert!(operations_balance == 30, 6);
        assert!(treasury_multi::jackpot_balance() == 60, 7);
        assert!(treasury_v1::balance_of(@player1) == 20_000 - (TICKET_PRICE * 3), 8);

        let snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &snapshot_events,
            0,
            1462,
        );
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player2,
    )]
    #[expected_failure(
        location = lottery::autopurchase,
        abort_code = autopurchase::E_PLAN_INACTIVE,
    )]
    fun cannot_execute_inactive_plan(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        setup_token(lottery_admin, buyer);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        autopurchase::configure_plan(buyer, lottery_id, 1, false);
        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE);

        autopurchase::execute(lottery_admin, lottery_id, @player2);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
    )]
    fun refund_returns_tokens(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        setup_token(lottery_admin, buyer);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        let _ = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseRefundedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 1, true);
        let config_events =
            test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseConfigUpdatedEvent>(
            &config_events,
            1,
            1470,
        );
        let config_event = *test_utils::last_event_ref(&config_events);
        let autopurchase::AutopurchaseConfigUpdatedEvent {
            lottery_id: config_lottery,
            player: config_player,
            tickets_per_draw: config_tickets,
            active: config_active,
        } = config_event;
        assert!(config_lottery == lottery_id, 1487);
        assert!(config_player == signer::address_of(buyer), 1488);
        assert!(config_tickets == 1, 1489);
        assert!(config_active, 1490);

        let config_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &config_snapshot_events,
            1,
            1471,
        );

        autopurchase::deposit(buyer, lottery_id, 500);
        let deposit_events = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseDepositEvent>(
            &deposit_events,
            1,
            1472,
        );
        let deposit_event = *test_utils::last_event_ref(&deposit_events);
        let autopurchase::AutopurchaseDepositEvent {
            lottery_id: deposit_lottery,
            player: deposit_player,
            amount: deposit_amount,
            new_balance: deposit_balance,
        } = deposit_event;
        assert!(deposit_lottery == lottery_id, 1491);
        assert!(deposit_player == signer::address_of(buyer), 1492);
        assert!(deposit_amount == 500, 1493);
        assert!(deposit_balance == 500, 1494);

        let deposit_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &deposit_snapshot_events,
            1,
            1473,
        );

        let balance_before = treasury_v1::balance_of(@player3);
        autopurchase::refund(buyer, lottery_id, 120);
        let balance_after = treasury_v1::balance_of(@player3);
        assert!(balance_after == balance_before + 120, 0);

        let plan_opt = autopurchase::get_plan(lottery_id, @player3);
        let plan = test_utils::unwrap(&mut plan_opt);
        let (balance, _, _) = autopurchase::plan_fields_for_test(&plan);
        assert!(balance == 380, 1);

        let summary_opt = autopurchase::get_lottery_summary(lottery_id);
        let summary = test_utils::unwrap(&mut summary_opt);
        let (total_balance, _, _) = autopurchase::summary_fields_for_test(&summary);
        assert!(total_balance == 380, 2);

        let refund_events = test_utils::drain_events<autopurchase::AutopurchaseRefundedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseRefundedEvent>(
            &refund_events,
            1,
            1474,
        );
        let refund_event = *test_utils::last_event_ref(&refund_events);
        let autopurchase::AutopurchaseRefundedEvent {
            lottery_id: refund_lottery,
            player: refund_player,
            amount: refund_amount,
            remaining_balance: refund_balance,
        } = refund_event;
        assert!(refund_lottery == lottery_id, 1475);
        assert!(refund_player == signer::address_of(buyer), 1476);
        assert!(refund_amount == 120, 1477);
        assert!(refund_balance == 380, 1478);

        let snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            &snapshot_events,
            1,
            1479,
        );
        let last_event = test_utils::last_event_ref(&snapshot_events);
        let (event_admin, event_snapshot) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(last_event);
        assert!(event_admin == signer::address_of(lottery_admin), 1480);
        let (event_balance, _, _, players) =
            autopurchase::lottery_snapshot_fields_for_test(&event_snapshot);
        assert!(event_balance == 380, 1481);
        assert!(vector::length(&players) == 1, 1482);
        let player_snapshot = vector::borrow(&players, 0);
        let (player_addr, player_balance, player_tickets, player_active) =
            autopurchase::player_snapshot_fields_for_test(player_snapshot);
        assert!(player_addr == @player3, 1483);
        assert!(player_balance == 380, 1484);
        assert!(player_tickets == 1, 1485);
        assert!(player_active, 1486);
    }
}
