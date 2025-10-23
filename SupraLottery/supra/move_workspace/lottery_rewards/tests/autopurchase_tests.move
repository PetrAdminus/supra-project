#[test_only]
module lottery_rewards::autopurchase_tests {
    use lottery_core::instances;
    use lottery_core::rounds;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::autopurchase;
    use lottery_rewards::test_utils;
    use std::signer;
    use std::vector;

    const TICKET_PRICE: u64 = 100;

    fun setup_lottery(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ): u64 {
        test_utils::bootstrap_multi_treasury(lottery_admin, factory_admin, vrf_admin);
        test_utils::ensure_autopurchase_initialized(lottery_admin);

        let blueprint = registry::new_blueprint(TICKET_PRICE, 2_000);
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
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7_000, 2_000, 1_000);

        treasury_v1::register_store(buyer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 20_000);

        let _ = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 2, true);

        let baseline_dep = {
            let events = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
            test_utils::events_len(&events)
        };
        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE * 3);
        {
            let snapshot_events = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
            test_utils::assert_grew_by<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
                baseline_dep,
                &snapshot_events,
                0,
                145,
            );
        };

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

        let baseline_exec1 = {
            let events = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
            test_utils::events_len(&events)
        };
        autopurchase::execute(lottery_admin, lottery_id, @player1);
        {
            let snapshot_events = test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
            test_utils::assert_grew_by<autopurchase::AutopurchaseSnapshotUpdatedEvent>(
                baseline_exec1,
                &snapshot_events,
                0,
                146,
            );
        };

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

        autopurchase::execute(lottery_admin, lottery_id, @player1);

        let plan_after_second_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_second = test_utils::unwrap(&mut plan_after_second_opt);
        let (balance_after_second, tickets_per_draw_after_second, active_after_second) =
            autopurchase::plan_fields_for_test(&plan_after_second);
        assert!(balance_after_second == 0, 4);
        assert!(tickets_per_draw_after_second == 2, 5);
        assert!(active_after_second, 6);

        let snapshot_after_second_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_after_second = test_utils::unwrap(&mut snapshot_after_second_opt);
        let (ticket_count_after_second, _, _, _, _) =
            rounds::round_snapshot_fields_for_test(&snapshot_after_second);
        assert!(ticket_count_after_second == 4, 7);

        autopurchase::refund(buyer, lottery_id, TICKET_PRICE);
        let plan_after_refund_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_refund = test_utils::unwrap(&mut plan_after_refund_opt);
        let (refund_balance, refund_tickets, refund_active) =
            autopurchase::plan_fields_for_test(&plan_after_refund);
        assert!(refund_balance == 0, 8);
        assert!(refund_tickets == 2, 9);
        assert!(refund_active, 10);
    }
}
