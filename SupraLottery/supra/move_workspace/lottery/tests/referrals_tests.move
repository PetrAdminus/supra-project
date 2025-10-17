#[test_only]
module lottery::referrals_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::instances;
    use lottery::referrals;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;
    use supra_framework::event;

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
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        referrals::init(lottery_admin);

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
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
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
        let snapshot_events_baseline =
            vector::length(&event::emitted_events<referrals::ReferralSnapshotUpdatedEvent>());

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
        let stats = test_utils::unwrap(&mut stats_opt);
        let (rewarded_purchases, total_referrer_rewards, total_referee_rewards) =
            referrals::referral_stats_for_test(&stats);
        assert!(rewarded_purchases == 1, 2);
        assert!(total_referrer_rewards == 8, 3);
        assert!(total_referee_rewards == 6, 4);

        let referrer_opt = referrals::get_referrer(signer::address_of(buyer));
        assert!(option::is_some(&referrer_opt), 5);
        let stored_referrer = test_utils::unwrap(&mut referrer_opt);
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

        let snapshot_events = event::emitted_events<referrals::ReferralSnapshotUpdatedEvent>();
        let snapshot_events_len = vector::length(&snapshot_events);
        let new_events = snapshot_events_len - snapshot_events_baseline;
        assert!(new_events >= 4, 17);
        let latest_snapshot = vector::borrow(&snapshot_events, snapshot_events_len - 1);
        let latest_previous_opt = referrals::referral_snapshot_event_previous_for_test(latest_snapshot);
        assert!(option::is_some(&latest_previous_opt), 18);
        let latest_snapshot_state = referrals::referral_snapshot_event_current_for_test(latest_snapshot);
        let latest_total_registered = referrals::referral_snapshot_total_registered(&latest_snapshot_state);
        assert!(latest_total_registered == 1, 19);
        let latest_count = referrals::referral_snapshot_lottery_count(&latest_snapshot_state);
        assert!(latest_count == 1, 20);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        referrer = @player4,
    )]
    #[expected_failure(
        location = lottery::referrals,
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
