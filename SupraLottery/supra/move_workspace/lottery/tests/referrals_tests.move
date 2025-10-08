module lottery::referrals_tests {
    use std::option;
    use std::vector;
    use std::account;
    use std::signer;
    use lottery::instances;
    use lottery::referrals;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    fun setup_environment(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        referrer: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        referrals::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"ref_seed",
            b"Referral Token",
            b"RFT",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(buyer);
        treasury_v1::register_store(referrer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 5_000);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player1,
        referrer = @player2,
    )]
    fun referral_rewards_paid(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        referrer: &signer,
    ) {
        setup_environment(vrf_admin, factory_admin, lottery_admin, buyer, referrer);

        let blueprint = registry::new_blueprint(100, 1500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7_000, 1_500, 1_500);

        referrals::set_lottery_config(lottery_admin, lottery_id, 800, 600);
        referrals::register_referrer(buyer, signer::address_of(referrer));

        rounds::buy_ticket(buyer, lottery_id);

        let referrer_balance = treasury_v1::balance_of(signer::address_of(referrer));
        assert!(referrer_balance == 8, 0);

        let buyer_balance = treasury_v1::balance_of(signer::address_of(buyer));

        assert!(buyer_balance == 4_906, 1);

        let stats_opt = referrals::get_lottery_stats(lottery_id);
        let stats = option::extract(stats_opt);
        let referrals::ReferralStats {
            rewarded_purchases,
            total_referrer_rewards,
            total_referee_rewards,
        } = stats;
        assert!(rewarded_purchases == 1, 2);
        assert!(total_referrer_rewards == 8, 3);
        assert!(total_referee_rewards == 6, 4);

        let referrer_opt = referrals::get_referrer(signer::address_of(buyer));
        assert!(option::is_some(&referrer_opt), 5);
        let stored_referrer = option::extract(referrer_opt);
        assert!(stored_referrer == signer::address_of(referrer), 6);

        assert!(referrals::total_registered() == 1, 7);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        referrer = @player4,
    )]
    #[expected_failure(abort_code = 4)]
    fun invalid_config_rejected(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        referrer: &signer,
    ) {
        setup_environment(vrf_admin, factory_admin, lottery_admin, buyer, referrer);

        let blueprint = registry::new_blueprint(100, 1000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7_000, 1_500, 1_500);


        referrals::set_lottery_config(lottery_admin, lottery_id, 1_200, 400);
    }
}
