#[test_only]
module lottery_rewards::rewards_referrals_tests {
    use lottery_core::core_instances as instances;
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_treasury_multi as treasury_multi;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::rewards_referrals as referrals;
    use lottery_rewards::rewards_rounds_sync as rounds_sync;
    use lottery_rewards::rewards_test_utils as test_utils;
    use std::option;
    use std::signer;
    use std::vector;
    use lottery_vrf_gateway::hub;

    fun setup_environment(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        referrer: &signer,
    ) {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @lottery_vrf_gateway);
        rounds::init(lottery_admin);
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
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        referrals::init(lottery_admin);
    }

    #[test(
        vrf_admin = @lottery_vrf_gateway,
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
        let _ = test_utils::drain_events<referrals::ReferralSnapshotUpdatedEvent>();
        setup_environment(vrf_admin, factory_admin, lottery_admin, buyer, referrer);
        let _ = test_utils::drain_events<referrals::ReferralSnapshotUpdatedEvent>();

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
        rounds_sync::sync_purchases_from_rounds(lottery_admin, 0);

        let referrer_balance = treasury_v1::balance_of(signer::address_of(referrer));
        assert!(referrer_balance == 8, 0);

        let buyer_balance = treasury_v1::balance_of(signer::address_of(buyer));

        assert!(buyer_balance == 4_906, 1);

        let stats_opt = referrals::get_lottery_stats(lottery_id);
        assert!(option::is_some(&stats_opt), 2);
        let (rewarded_purchases, total_referrer_rewards, total_referee_rewards) =
            referrals::referral_stats_for_test(option::borrow(&stats_opt));
        assert!(rewarded_purchases == 1, 2);
        assert!(total_referrer_rewards == 8, 3);
        assert!(total_referee_rewards == 6, 4);

        let referrer_opt = referrals::get_referrer(signer::address_of(buyer));
        assert!(option::is_some(&referrer_opt), 5);
        let stored_referrer = *option::borrow(&referrer_opt);
        assert!(stored_referrer == signer::address_of(referrer), 6);

        assert!(referrals::total_registered() == 1, 7);

        let snapshot = referrals::get_referral_snapshot();
        let admin_addr = referrals::referral_snapshot_admin(&snapshot);
        assert!(admin_addr == @lottery, 8);
        let total_registered = referrals::referral_snapshot_total_registered(&snapshot);
        assert!(total_registered == 1, 9);
        let lottery_count = referrals::referral_snapshot_lottery_count(&snapshot);
        assert!(lottery_count == 1, 10);
        let entry_snapshot = referrals::referral_snapshot_lottery_at(&snapshot, 0);
        let (
            entry_lottery_id,
            entry_referrer_bps,
            entry_referee_bps,
            entry_rewarded_purchases,
            entry_total_referrer_rewards,
            entry_total_referee_rewards,
        ) = referrals::lottery_referral_snapshot_fields_for_test(&entry_snapshot);
        assert!(entry_lottery_id == lottery_id, 11);
        assert!(entry_referrer_bps == 800, 12);
        assert!(entry_referee_bps == 600, 13);
        assert!(entry_rewarded_purchases == 1, 14);
        assert!(entry_total_referrer_rewards == 8, 15);
        assert!(entry_total_referee_rewards == 6, 16);

        let snapshot_events =
            test_utils::drain_events<referrals::ReferralSnapshotUpdatedEvent>();
        let snapshot_events_len = vector::length(&snapshot_events);
        if (snapshot_events_len < 3) {
            return
        };

        let config_event = vector::borrow(&snapshot_events, 0);
        let config_previous_opt =
            referrals::referral_snapshot_event_previous_for_test(config_event);
        if (option::is_some(&config_previous_opt)) {
            let config_previous = option::borrow(&config_previous_opt);
            assert!(referrals::referral_snapshot_total_registered(config_previous) == 0, 18);
            assert!(referrals::referral_snapshot_lottery_count(config_previous) == 0, 19);
        };
        let config_current = referrals::referral_snapshot_event_current_for_test(config_event);
        assert!(referrals::referral_snapshot_total_registered(&config_current) == 0, 20);
        assert!(referrals::referral_snapshot_lottery_count(&config_current) == 1, 21);
        let config_entry = referrals::referral_snapshot_lottery_at(&config_current, 0);
        let (
            config_lottery,
            config_referrer_bps,
            config_referee_bps,
            config_rewarded,
            config_total_referrer,
            config_total_referee,
        ) = referrals::lottery_referral_snapshot_fields_for_test(&config_entry);
        assert!(config_lottery == lottery_id, 22);
        assert!(config_referrer_bps == 800, 23);
        assert!(config_referee_bps == 600, 24);
        assert!(config_rewarded == 0, 25);
        assert!(config_total_referrer == 0, 26);
        assert!(config_total_referee == 0, 27);

        let register_event = vector::borrow(&snapshot_events, 1);
        let register_previous_opt =
            referrals::referral_snapshot_event_previous_for_test(register_event);
        if (option::is_some(&register_previous_opt)) {
            let register_previous = option::borrow(&register_previous_opt);
            assert!(referrals::referral_snapshot_total_registered(register_previous) == 0, 28);
        };
        let register_current = referrals::referral_snapshot_event_current_for_test(register_event);
        assert!(referrals::referral_snapshot_total_registered(&register_current) == 1, 29);
        assert!(referrals::referral_snapshot_lottery_count(&register_current) == 1, 30);

        let reward_event = vector::borrow(&snapshot_events, 2);
        let reward_previous_opt =
            referrals::referral_snapshot_event_previous_for_test(reward_event);
        if (option::is_some(&reward_previous_opt)) {
            let reward_previous = option::borrow(&reward_previous_opt);
            assert!(referrals::referral_snapshot_total_registered(reward_previous) == 1, 31);
        };
        let reward_current = referrals::referral_snapshot_event_current_for_test(reward_event);
        assert!(referrals::referral_snapshot_total_registered(&reward_current) == 1, 32);
        let reward_count = referrals::referral_snapshot_lottery_count(&reward_current);
        assert!(reward_count == 1, 33);
        let reward_entry = referrals::referral_snapshot_lottery_at(&reward_current, 0);
        let (
            reward_lottery,
            reward_referrer_bps,
            reward_referee_bps,
            reward_rewarded,
            reward_total_referrer,
            reward_total_referee,
        ) = referrals::lottery_referral_snapshot_fields_for_test(&reward_entry);
        assert!(reward_lottery == lottery_id, 34);
        assert!(reward_referrer_bps == 800, 35);
        assert!(reward_referee_bps == 600, 36);
        assert!(reward_rewarded == 1, 37);
        assert!(reward_total_referrer == 8, 38);
        assert!(reward_total_referee == 6, 39);
    }

    #[test(
        vrf_admin = @lottery_vrf_gateway,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        referrer = @player4,
    )]
    #[expected_failure(
        location = lottery_rewards::rewards_referrals,
        abort_code = referrals::E_INVALID_CONFIG,
    )]
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




