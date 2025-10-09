module lottery::autopurchase_tests {
    use std::option;
    use std::vector;
    use std::u128;
    use std::account;
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
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
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
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, buyer);

        autopurchase::configure_plan(buyer, lottery_id, 2, true);
        autopurchase::deposit(buyer, lottery_id, TICKET_PRICE * 3);

        let (total_players, active_players, total_balance) =
            autopurchase::get_lottery_summary_view(lottery_id);
        assert!(total_balance == u128::from_u64(TICKET_PRICE * 3), 9);
        assert!(total_players == 1, 10);
        assert!(active_players == 1, 11);

        let players = test_utils::unwrap(autopurchase::list_players(lottery_id));
        assert!(vector::length(&players) == 1, 12);
        assert!(*vector::borrow(&players, 0) == @player1, 13);

        let lotteries = autopurchase::list_lottery_ids();
        assert!(vector::length(&lotteries) == 1, 14);
        assert!(*vector::borrow(&lotteries, 0) == lottery_id, 15);


        autopurchase::execute(lottery_admin, lottery_id, @player1);

        let balance_after_first = autopurchase::get_plan_balance(@player1, lottery_id);
        assert!(balance_after_first == u128::from_u64(TICKET_PRICE), 0);

        let (ticket_count, _, _, _) = test_utils::unwrap(rounds::get_round_snapshot(lottery_id, 0));
        assert!(ticket_count == 2, 3);

        let (total_players_mid, active_players_mid, balance_mid) =
            autopurchase::get_lottery_summary_view(lottery_id);
        assert!(balance_mid == u128::from_u64(TICKET_PRICE), 16);
        assert!(total_players_mid == 1, 17);
        assert!(active_players_mid == 1, 18);


        autopurchase::execute(lottery_admin, lottery_id, @player1);
        let final_balance = autopurchase::get_plan_balance(@player1, lottery_id);
        assert!(final_balance == u128::from_u64(0), 4);

        let (_, _, balance_final) = autopurchase::get_lottery_summary_view(lottery_id);
        assert!(balance_final == u128::from_u64(0), 19);

        let (prize_balance, operations_balance) = treasury_multi::get_pool_balances(lottery_id);
        assert!(prize_balance == u128::from_u64(210), 5);
        assert!(operations_balance == u128::from_u64(30), 6);
        assert!(treasury_multi::jackpot_balance() == 60, 7);
        assert!(treasury_v1::balance_of(@player1) == 20_000 - (TICKET_PRICE * 3), 8);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player2,
    )]
    #[expected_failure(abort_code = 6)]
    fun cannot_execute_inactive_plan(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, buyer);

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
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, buyer);

        autopurchase::configure_plan(buyer, lottery_id, 1, true);
        autopurchase::deposit(buyer, lottery_id, 500);

        let balance_before = treasury_v1::balance_of(@player3);
        autopurchase::refund(buyer, lottery_id, 120);
        let balance_after = treasury_v1::balance_of(@player3);
        assert!(balance_after == balance_before + 120, 0);

        let balance = autopurchase::get_plan_balance(@player3, lottery_id);
        assert!(balance == u128::from_u64(380), 1);

        let (_, _, total_balance) = autopurchase::get_lottery_summary_view(lottery_id);
        assert!(total_balance == u128::from_u64(380), 2);
    }
}
