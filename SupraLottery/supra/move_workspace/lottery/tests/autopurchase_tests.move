#[test_only]
module lottery::autopurchase_tests {
    use std::vector;
    use std::signer;
    use lottery::autopurchase;
    use lottery::instances;
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

        let snapshot_baseline =
            test_utils::event_count<autopurchase::AutopurchaseSnapshotUpdatedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 2, true);
        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE * 3);

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

        let plan_after_first_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_first = test_utils::unwrap(&mut plan_after_first_opt);
        let (balance, tickets_per_draw, active) =
            autopurchase::plan_fields_for_test(&plan_after_first);
        assert!(balance == TICKET_PRICE, 0);
        assert!(tickets_per_draw == 2, 1);
        assert!(active, 2);

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

        let snapshot_events_len =
            test_utils::event_count<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        assert!(snapshot_events_len == snapshot_baseline + 4, 45);
        let last_event = test_utils::borrow_event<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            snapshot_events_len - 1,
        );
        let (event_admin, event_snapshot) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(last_event);
        assert!(event_admin == signer::address_of(lottery_admin), 46);
        let (event_balance, event_players, event_active_players, event_player_snapshots) =
            autopurchase::lottery_snapshot_fields_for_test(&event_snapshot);
        assert!(event_balance == 0, 47);
        assert!(event_players == 1, 48);
        assert!(event_active_players == 1, 49);
        assert!(vector::length(&event_player_snapshots) == 1, 50);
        let player_snapshot = vector::borrow(&event_player_snapshots, 0);
        let (_, final_plan_balance, final_plan_tickets, final_plan_active) =
            autopurchase::player_snapshot_fields_for_test(player_snapshot);
        assert!(final_plan_balance == 0, 51);
        assert!(final_plan_tickets == 2, 52);
        assert!(final_plan_active, 53);
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

        let snapshot_baseline =
            test_utils::event_count<autopurchase::AutopurchaseSnapshotUpdatedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 1, true);
        autopurchase::deposit(buyer, lottery_id, 500);

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

        let snapshot_events_len =
            test_utils::event_count<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        assert!(snapshot_events_len == snapshot_baseline + 3, 54);
        let last_event = test_utils::borrow_event<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
            snapshot_events_len - 1,
        );
        let (event_admin, event_snapshot) =
            autopurchase::autopurchase_snapshot_event_fields_for_test(last_event);
        assert!(event_admin == signer::address_of(lottery_admin), 55);
        let (event_balance, _, _, players) =
            autopurchase::lottery_snapshot_fields_for_test(&event_snapshot);
        assert!(event_balance == 380, 56);
        assert!(vector::length(&players) == 1, 57);
        let player_snapshot = vector::borrow(&players, 0);
        let (player_addr, player_balance, player_tickets, player_active) =
            autopurchase::player_snapshot_fields_for_test(player_snapshot);
        assert!(player_addr == @player3, 58);
        assert!(player_balance == 380, 59);
        assert!(player_tickets == 1, 60);
        assert!(player_active, 61);
    }
}
