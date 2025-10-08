module lottery::autopurchase_tests {
    use std::option;
    use std::vector;
    use std::account;
    use std::signer;
    use lottery::autopurchase;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
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

        let summary_before = option::extract(autopurchase::get_lottery_summary(lottery_id));
        let balance_before = summary_before.total_balance;
        let total_players = summary_before.total_players;
        let active_players = summary_before.active_players;
        assert!(balance_before == TICKET_PRICE * 3, 9);
        assert!(total_players == 1, 10);
        assert!(active_players == 1, 11);

        let players = option::extract(autopurchase::list_players(lottery_id));
        assert!(vector::length(&players) == 1, 12);
        assert!(*vector::borrow(&players, 0) == @player1, 13);

        let lotteries = autopurchase::list_lottery_ids();
        assert!(vector::length(&lotteries) == 1, 14);
        assert!(*vector::borrow(&lotteries, 0) == lottery_id, 15);


        autopurchase::execute(lottery_admin, lottery_id, @player1);

        let plan_after_first = option::extract(autopurchase::get_plan(lottery_id, @player1));
        let balance = plan_after_first.balance;
        let tickets_per_draw = plan_after_first.tickets_per_draw;
        let active = plan_after_first.active;
        assert!(balance == TICKET_PRICE, 0);
        assert!(tickets_per_draw == 2, 1);
        assert!(active, 2);

        let snapshot = option::extract(rounds::get_round_snapshot(lottery_id));
        let ticket_count = snapshot.ticket_count;
        assert!(ticket_count == 2, 3);

        let summary_mid = option::extract(autopurchase::get_lottery_summary(lottery_id));
        let balance_mid = summary_mid.total_balance;
        let total_players_mid = summary_mid.total_players;
        let active_players_mid = summary_mid.active_players;
        assert!(balance_mid == TICKET_PRICE, 16);
        assert!(total_players_mid == 1, 17);
        assert!(active_players_mid == 1, 18);


        autopurchase::execute(lottery_admin, lottery_id, @player1);
        let plan_after_second = option::extract(autopurchase::get_plan(lottery_id, @player1));
        let final_balance = plan_after_second.balance;
        assert!(final_balance == 0, 4);

        let summary_final = option::extract(autopurchase::get_lottery_summary(lottery_id));
        let balance_final = summary_final.total_balance;
        assert!(balance_final == 0, 19);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        let pool_snapshot = option::extract(pool_opt);
        let prize_balance = pool_snapshot.prize_balance;
        let operations_balance = pool_snapshot.operations_balance;
        assert!(prize_balance == 210, 5);
        assert!(operations_balance == 30, 6);
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

        let plan = option::extract(autopurchase::get_plan(lottery_id, @player3));
        let balance = plan.balance;
        assert!(balance == 380, 1);

        let summary = option::extract(autopurchase::get_lottery_summary(lottery_id));
        let total_balance = summary.total_balance;
        assert!(total_balance == 380, 2);
    }
}
