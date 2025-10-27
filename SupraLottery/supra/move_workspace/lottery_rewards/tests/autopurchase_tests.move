#[test_only]
module lottery_rewards::autopurchase_tests {
    use lottery_core::instances;
    use lottery_core::rounds;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::autopurchase;
    use lottery_rewards::rewards_test_utils as test_utils;
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
        let _ = test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        let _ = test_utils::drain_events<autopurchase::AutopurchaseRefundedEvent>();

        autopurchase::configure_plan(buyer, lottery_id, 2, true);
        let config_events =
            test_utils::drain_events<autopurchase::AutopurchaseConfigUpdatedEvent>();
        if (vector::length(&config_events) > 0) {
            let config_event = test_utils::last_event_ref(&config_events);
            let (config_lottery, config_player, config_tickets, config_active) =
                autopurchase::config_event_fields_for_test(config_event);
            assert!(config_lottery == lottery_id, 148);
            assert!(config_player == signer::address_of(buyer), 149);
            assert!(config_tickets == 2, 150);
            assert!(config_active, 151);
        };

        let config_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        if (vector::length(&config_snapshot_events) > 0) {
            let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
            let (config_admin, config_snapshot) =
                autopurchase::autopurchase_snapshot_event_fields_for_test(config_snapshot_event);
            assert!(config_admin == signer::address_of(lottery_admin), 153);
            let (
                config_total_balance,
                config_total_players,
                config_active_players,
                config_player_snapshots,
            ) = autopurchase::lottery_snapshot_fields_for_test(&config_snapshot);
            assert!(config_total_balance == 0, 154);
            assert!(config_total_players == 1, 155);
            assert!(config_active_players == 1, 156);
            assert!(vector::length(&config_player_snapshots) == 1, 157);
            let config_player_snapshot = vector::borrow(&config_player_snapshots, 0);
            let (
                config_player_addr,
                config_plan_balance,
                config_plan_tickets,
                config_plan_active,
            ) = autopurchase::player_snapshot_fields_for_test(config_player_snapshot);
            assert!(config_player_addr == signer::address_of(buyer), 158);
            assert!(config_plan_balance == 0, 159);
            assert!(config_plan_tickets == 2, 160);
            assert!(config_plan_active, 161);
        };

        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE * 3);
        let deposit_events = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();
        if (vector::length(&deposit_events) > 0) {
            let deposit_event = test_utils::last_event_ref(&deposit_events);
            let (deposit_lottery, deposit_player, deposit_amount, deposit_balance) =
                autopurchase::deposit_event_fields_for_test(deposit_event);
            assert!(deposit_lottery == lottery_id, 163);
            assert!(deposit_player == signer::address_of(buyer), 164);
            assert!(deposit_amount == TICKET_PRICE * 3, 165);
            assert!(deposit_balance == TICKET_PRICE * 3, 166);
        };

        let deposit_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        if (vector::length(&deposit_snapshot_events) > 0) {
            let deposit_snapshot_event = test_utils::last_event_ref(&deposit_snapshot_events);
            let (deposit_admin, deposit_snapshot) =
                autopurchase::autopurchase_snapshot_event_fields_for_test(deposit_snapshot_event);
            assert!(deposit_admin == signer::address_of(lottery_admin), 168);
            let (
                deposit_total_balance,
                deposit_total_players,
                deposit_active_players,
                deposit_player_snapshots,
            ) = autopurchase::lottery_snapshot_fields_for_test(&deposit_snapshot);
            assert!(deposit_total_balance == TICKET_PRICE * 3, 169);
            assert!(deposit_total_players == 1, 170);
            assert!(deposit_active_players == 1, 171);
            assert!(vector::length(&deposit_player_snapshots) == 1, 172);
            let deposit_player_snapshot = vector::borrow(&deposit_player_snapshots, 0);
            let (
                deposit_player_addr,
                deposit_plan_balance,
                deposit_plan_tickets,
                deposit_plan_active,
            ) = autopurchase::player_snapshot_fields_for_test(deposit_player_snapshot);
            assert!(deposit_player_addr == signer::address_of(buyer), 173);
            assert!(deposit_plan_balance == TICKET_PRICE * 3, 174);
            assert!(deposit_plan_tickets == 2, 175);
            assert!(deposit_plan_active, 176);
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

        autopurchase::execute(lottery_admin, lottery_id, @player1);
        let execute_events_first =
            test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        if (vector::length(&execute_events_first) > 0) {
            let first_execute_event = test_utils::last_event_ref(&execute_events_first);
            let (
                first_execute_lottery,
                first_execute_player,
                first_execute_tickets,
                first_execute_spent,
                first_execute_remaining,
            ) = autopurchase::executed_event_fields_for_test(first_execute_event);
            assert!(first_execute_lottery == lottery_id, 178);
            assert!(first_execute_player == signer::address_of(buyer), 179);
            assert!(first_execute_tickets == 2, 180);
            assert!(first_execute_spent == TICKET_PRICE * 2, 181);
            assert!(first_execute_remaining == TICKET_PRICE, 182);
        };

        let execute_snapshot_events_first =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        if (vector::length(&execute_snapshot_events_first) > 0) {
            let execute_snapshot_event_first =
                test_utils::last_event_ref(&execute_snapshot_events_first);
            let (execute_admin_first, execute_snapshot_first) =
                autopurchase::autopurchase_snapshot_event_fields_for_test(
                    execute_snapshot_event_first,
                );
            assert!(execute_admin_first == signer::address_of(lottery_admin), 184);
            let (
                execute_balance_first,
                execute_total_players_first,
                execute_active_players_first,
                execute_player_snapshots_first,
            ) = autopurchase::lottery_snapshot_fields_for_test(&execute_snapshot_first);
            assert!(execute_balance_first == TICKET_PRICE, 185);
            assert!(execute_total_players_first == 1, 186);
            assert!(execute_active_players_first == 1, 187);
            assert!(vector::length(&execute_player_snapshots_first) == 1, 188);
            let execute_player_snapshot_first = vector::borrow(&execute_player_snapshots_first, 0);
            let (
                execute_player_first,
                execute_plan_balance_first,
                execute_plan_tickets_first,
                execute_plan_active_first,
            ) = autopurchase::player_snapshot_fields_for_test(execute_player_snapshot_first);
            assert!(execute_player_first == signer::address_of(buyer), 189);
            assert!(execute_plan_balance_first == TICKET_PRICE, 190);
            assert!(execute_plan_tickets_first == 2, 191);
            assert!(execute_plan_active_first, 192);
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

        let execute_events_second =
            test_utils::drain_events<autopurchase::AutopurchaseExecutedEvent>();
        if (vector::length(&execute_events_second) > 0) {
            let second_execute_event = test_utils::last_event_ref(&execute_events_second);
            let (
                second_execute_lottery,
                second_execute_player,
                second_execute_tickets,
                second_execute_spent,
                second_execute_remaining,
            ) = autopurchase::executed_event_fields_for_test(second_execute_event);
            assert!(second_execute_lottery == lottery_id, 194);
            assert!(second_execute_player == signer::address_of(buyer), 195);
            assert!(second_execute_tickets == 1, 196);
            assert!(second_execute_spent == TICKET_PRICE, 197);
            assert!(second_execute_remaining == 0, 198);
        };

        let execute_snapshot_events_second =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        if (vector::length(&execute_snapshot_events_second) > 0) {
            let execute_snapshot_event_second =
                test_utils::last_event_ref(&execute_snapshot_events_second);
            let (execute_admin_second, execute_snapshot_second) =
                autopurchase::autopurchase_snapshot_event_fields_for_test(
                    execute_snapshot_event_second,
                );
            assert!(execute_admin_second == signer::address_of(lottery_admin), 200);
            let (
                execute_balance_second,
                execute_total_players_second,
                execute_active_players_second,
                execute_player_snapshots_second,
            ) = autopurchase::lottery_snapshot_fields_for_test(&execute_snapshot_second);
            assert!(execute_balance_second == 0, 201);
            assert!(execute_total_players_second == 1, 202);
            assert!(execute_active_players_second == 1, 203);
            assert!(vector::length(&execute_player_snapshots_second) == 1, 204);
            let execute_player_snapshot_second = vector::borrow(&execute_player_snapshots_second, 0);
            let (
                execute_player_second,
                execute_plan_balance_second,
                execute_plan_tickets_second,
                execute_plan_active_second,
            ) = autopurchase::player_snapshot_fields_for_test(execute_player_snapshot_second);
            assert!(execute_player_second == signer::address_of(buyer), 205);
            assert!(execute_plan_balance_second == 0, 206);
            assert!(execute_plan_tickets_second == 2, 207);
            assert!(execute_plan_active_second, 208);
        };

        let plan_after_second_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_second = test_utils::unwrap(&mut plan_after_second_opt);
        let (balance_after_second, tickets_per_draw_after_second, active_after_second) =
            autopurchase::plan_fields_for_test(&plan_after_second);
        assert!(balance_after_second == 0, 4);
        assert!(tickets_per_draw_after_second == 2, 5);
        assert!(active_after_second, 6);

        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE);
        let _ = test_utils::drain_events<autopurchase::AutopurchaseDepositEvent>();

        let snapshot_after_second_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_after_second = test_utils::unwrap(&mut snapshot_after_second_opt);
        let (ticket_count_after_second, _, _, _, _) =
            rounds::round_snapshot_fields_for_test(&snapshot_after_second);
        assert!(ticket_count_after_second == 3, 7);

        autopurchase::refund(buyer, lottery_id, TICKET_PRICE);
        let refund_events = test_utils::drain_events<autopurchase::AutopurchaseRefundedEvent>();
        if (vector::length(&refund_events) > 0) {
            let refund_event = test_utils::last_event_ref(&refund_events);
            let (refund_lottery, refund_player, refund_amount, refund_remaining) =
                autopurchase::refunded_event_fields_for_test(refund_event);
            assert!(refund_lottery == lottery_id, 210);
            assert!(refund_player == signer::address_of(buyer), 211);
            assert!(refund_amount == TICKET_PRICE, 212);
            assert!(refund_remaining == 0, 213);
        };

        let refund_snapshot_events =
            test_utils::drain_events<autopurchase::AutopurchaseSnapshotUpdatedEvent>();
        if (vector::length(&refund_snapshot_events) > 0) {
            let refund_snapshot_event = test_utils::last_event_ref(&refund_snapshot_events);
            let (refund_admin, refund_snapshot) =
                autopurchase::autopurchase_snapshot_event_fields_for_test(refund_snapshot_event);
            assert!(refund_admin == signer::address_of(lottery_admin), 215);
            let (
                refund_total_balance,
                refund_total_players,
                refund_active_players,
                refund_player_snapshots,
            ) = autopurchase::lottery_snapshot_fields_for_test(&refund_snapshot);
            assert!(refund_total_balance == 0, 216);
            assert!(refund_total_players == 1, 217);
            assert!(refund_active_players == 1, 218);
            assert!(vector::length(&refund_player_snapshots) == 1, 219);
            let refund_player_snapshot = vector::borrow(&refund_player_snapshots, 0);
            let (
                refund_player_addr,
                refund_plan_balance,
                refund_plan_tickets,
                refund_plan_active,
            ) = autopurchase::player_snapshot_fields_for_test(refund_player_snapshot);
            assert!(refund_player_addr == signer::address_of(buyer), 220);
            assert!(refund_plan_balance == 0, 221);
            assert!(refund_plan_tickets == 2, 222);
            assert!(refund_plan_active, 223);
        };

        let plan_after_refund_opt = autopurchase::get_plan(lottery_id, @player1);
        let plan_after_refund = test_utils::unwrap(&mut plan_after_refund_opt);
        let (refund_balance, refund_tickets, refund_active) =
            autopurchase::plan_fields_for_test(&plan_after_refund);
        assert!(refund_balance == 0, 8);
        assert!(refund_tickets == 2, 9);
        assert!(refund_active, 10);
    }
}
