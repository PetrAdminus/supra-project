#[test_only]
module lottery_rewards::rewards_rounds_sync_tests {
    use lottery_core::core_instances as instances;
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_treasury_multi as treasury_multi;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::rewards_referrals as referrals;
    use lottery_rewards::rewards_rounds_sync as rounds_sync;
    use lottery_rewards::rewards_test_utils as test_utils;
    use lottery_rewards::rewards_vip as vip;
    use std::option;
    use std::signer;
    use std::vector;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;
    const BLUEPRINT_JACKPOT_BPS: u16 = 1_000;
    const LOTTERY_PRIZE_BPS: u64 = 6_000;
    const LOTTERY_JACKPOT_BPS: u64 = 3_000;
    const LOTTERY_OPERATIONS_BPS: u64 = 1_000;
    const TICKET_PRICE: u64 = 100;
    const VIP_PRICE: u64 = 100;
    const VIP_DURATION: u64 = 1_000;
    const VIP_BONUS_TICKETS: u64 = 1;
    const REFERRER_BPS: u64 = 500;
    const REFEREE_BPS: u64 = 500;
    const BUYER_MINT_AMOUNT: u64 = 1_000;

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @lottery_vrf_gateway,
        buyer = @player1,
        referrer = @player2,
    )]
    fun syncs_purchase_queue_into_rewards(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
        buyer: &signer,
        referrer: &signer,
    ) {
        test_utils::bootstrap_multi_treasury(lottery_admin, factory_admin, vrf_admin);
        if (!instances::is_initialized()) {
            instances::init(lottery_admin, @lottery_vrf_gateway);
        };
        if (!rounds::is_initialized()) {
            rounds::init(lottery_admin);
        };

        let blueprint = registry::new_blueprint(TICKET_PRICE, BLUEPRINT_JACKPOT_BPS);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(
            lottery_admin,
            lottery_id,
            LOTTERY_PRIZE_BPS,
            LOTTERY_JACKPOT_BPS,
            LOTTERY_OPERATIONS_BPS,
        );

        treasury_v1::register_store(buyer);
        treasury_v1::register_store(referrer);
        let buyer_addr = signer::address_of(buyer);
        let referrer_addr = signer::address_of(referrer);
        treasury_v1::mint_to(lottery_admin, buyer_addr, BUYER_MINT_AMOUNT);

        if (!vip::is_initialized()) {
            vip::init(lottery_admin);
        };
        vip::ensure_caps_initialized(lottery_admin);
        vip::upsert_config(
            lottery_admin,
            lottery_id,
            VIP_PRICE,
            VIP_DURATION,
            VIP_BONUS_TICKETS,
        );

        if (!referrals::is_initialized()) {
            referrals::init(lottery_admin);
        };
        referrals::ensure_caps_initialized(lottery_admin);
        referrals::set_lottery_config(
            lottery_admin,
            lottery_id,
            REFERRER_BPS,
            REFEREE_BPS,
        );
        referrals::admin_set_referrer(lottery_admin, buyer_addr, referrer_addr);

        vip::subscribe(buyer, lottery_id);
        assert!(rounds::purchase_queue_length() == 0, 0);

        // Reset emitted events so downstream checks observe fresh state.
        let _ = test_utils::drain_events<vip::VipSubscribedEvent>();
        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipBonusIssuedEvent>();
        let _ = test_utils::drain_events<referrals::ReferralSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<referrals::ReferralRewardPaidEvent>();

        rounds::buy_ticket(buyer, lottery_id);
        assert!(rounds::purchase_queue_length() == 1, 1);

        rounds_sync::sync_purchases_from_rounds(lottery_admin, 0);
        assert!(rounds::purchase_queue_length() == 0, 2);

        let bonus_events = test_utils::drain_events<vip::VipBonusIssuedEvent>();
        let bonus_event_count = vector::length(&bonus_events);
        if (bonus_event_count > 0) {
            let bonus_event = test_utils::last_event_ref(&bonus_events);
            let (bonus_lottery, bonus_player, bonus_tickets) =
                vip::vip_bonus_event_fields_for_test(bonus_event);
            assert!(bonus_lottery == lottery_id, 201);
            assert!(bonus_player == buyer_addr, 202);
            assert!(bonus_tickets == VIP_BONUS_TICKETS, 203);
        };

        let vip_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&vip_snapshot_events) > 0) {
            let vip_snapshot_event = test_utils::last_event_ref(&vip_snapshot_events);
            let (vip_admin, vip_lottery_snapshots) =
                vip::vip_snapshot_event_fields_for_test(vip_snapshot_event);
            assert!(vip_admin == signer::address_of(lottery_admin), 205);
            assert!(vector::length(&vip_lottery_snapshots) == 1, 206);
            let vip_lottery_snapshot = vector::borrow(&vip_lottery_snapshots, 0);
            let (
                vip_snapshot_lottery,
                vip_snapshot_config,
                vip_snapshot_members,
                vip_snapshot_active,
                vip_snapshot_revenue,
                vip_snapshot_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(vip_lottery_snapshot);
            assert!(vip_snapshot_lottery == lottery_id, 207);
            let vip_snapshot_price = vip::vip_config_price(&vip_snapshot_config);
            let vip_snapshot_duration = vip::vip_config_duration_secs(&vip_snapshot_config);
            let vip_snapshot_bonus = vip::vip_config_bonus_tickets(&vip_snapshot_config);
            assert!(vip_snapshot_price == VIP_PRICE, 208);
            assert!(vip_snapshot_duration == VIP_DURATION, 209);
            assert!(vip_snapshot_bonus == VIP_BONUS_TICKETS, 210);
            assert!(vip_snapshot_members == 1, 211);
            assert!(vip_snapshot_active == 1, 212);
            assert!(vip_snapshot_revenue == VIP_PRICE, 213);
            assert!(vip_snapshot_bonus_issued == VIP_BONUS_TICKETS, 214);
        };

        let expected_referrer_reward =
            TICKET_PRICE * REFERRER_BPS / BASIS_POINT_DENOMINATOR;
        let expected_referee_reward =
            TICKET_PRICE * REFEREE_BPS / BASIS_POINT_DENOMINATOR;
        let referral_reward_events =
            test_utils::drain_events<referrals::ReferralRewardPaidEvent>();
        let referral_reward_events_len = vector::length(&referral_reward_events);
        if (referral_reward_events_len > 0) {
            let reward_event = test_utils::last_event_ref(&referral_reward_events);
            let (
                reward_lottery,
                reward_buyer,
                reward_referrer,
                referrer_amount,
                referee_amount,
                total_amount,
            ) = referrals::referral_reward_event_fields_for_test(reward_event);
            assert!(reward_lottery == lottery_id, 221);
            assert!(reward_buyer == buyer_addr, 222);
            assert!(reward_referrer == referrer_addr, 223);
            assert!(referrer_amount == expected_referrer_reward, 224);
            assert!(referee_amount == expected_referee_reward, 225);
            assert!(total_amount == TICKET_PRICE, 226);
        };

        let referral_snapshot_events =
            test_utils::drain_events<referrals::ReferralSnapshotUpdatedEvent>();
        if (vector::length(&referral_snapshot_events) > 0) {
            let referral_snapshot_event = test_utils::last_event_ref(&referral_snapshot_events);
            let previous_opt =
                referrals::referral_snapshot_event_previous_for_test(referral_snapshot_event);
            assert!(option::is_some(&previous_opt), 228);
            let previous_snapshot = option::borrow(&previous_opt);
            assert!(
                referrals::referral_snapshot_total_registered(previous_snapshot) == 1,
                229,
            );
            let previous_lottery_snapshot =
                referrals::referral_snapshot_lottery_at(previous_snapshot, 0);
            let (
                _prev_lottery_id,
                _prev_referrer_bps,
                _prev_referee_bps,
                prev_rewarded_purchases,
                prev_referrer_rewards,
                prev_referee_rewards,
            ) = referrals::lottery_referral_snapshot_fields_for_test(&previous_lottery_snapshot);
            assert!(prev_rewarded_purchases == 0, 230);
            assert!(prev_referrer_rewards == 0, 231);
            assert!(prev_referee_rewards == 0, 232);

            let referral_snapshot_current =
                referrals::referral_snapshot_event_current_for_test(referral_snapshot_event);
            assert!(
                referrals::referral_snapshot_admin(&referral_snapshot_current)
                    == signer::address_of(lottery_admin),
                233,
            );
            assert!(
                referrals::referral_snapshot_total_registered(&referral_snapshot_current) == 1,
                234,
            );
            assert!(
                referrals::referral_snapshot_lottery_count(&referral_snapshot_current) == 1,
                235,
            );
            let referral_lottery_snapshot =
                referrals::referral_snapshot_lottery_at(&referral_snapshot_current, 0);
            let (
                snapshot_lottery_id,
                snapshot_referrer_bps,
                snapshot_referee_bps,
                snapshot_rewarded_purchases,
                snapshot_total_referrer,
                snapshot_total_referee,
            ) = referrals::lottery_referral_snapshot_fields_for_test(&referral_lottery_snapshot);
            assert!(snapshot_lottery_id == lottery_id, 236);
            assert!(snapshot_referrer_bps == REFERRER_BPS, 237);
            assert!(snapshot_referee_bps == REFEREE_BPS, 238);
            assert!(snapshot_rewarded_purchases == 1, 239);
            assert!(snapshot_total_referrer == expected_referrer_reward, 240);
            assert!(snapshot_total_referee == expected_referee_reward, 241);
        };

        let vip_snapshot_opt = vip::get_lottery_snapshot(lottery_id);
        assert!(option::is_some(&vip_snapshot_opt), 3);
        let vip_snapshot_ref = option::borrow(&vip_snapshot_opt);
        let (
            _snapshot_lottery,
            _vip_config,
            _total_members,
            _active_members,
            _total_revenue,
            bonus_issued,
        ) = vip::vip_lottery_snapshot_fields_for_test(vip_snapshot_ref);
        assert!(bonus_issued == VIP_BONUS_TICKETS, 4);

        let stats_opt = referrals::get_lottery_stats(lottery_id);
        assert!(option::is_some(&stats_opt), 5);
        let stats_ref = option::borrow(&stats_opt);
        let (rewarded, total_referrer_rewards, total_referee_rewards) =
            referrals::referral_stats_for_test(stats_ref);
        assert!(rewarded == 1, 6);
        assert!(total_referrer_rewards == expected_referrer_reward, 7);
        assert!(total_referee_rewards == expected_referee_reward, 8);

        let referrer_balance = treasury_v1::balance_of(referrer_addr);
        assert!(referrer_balance == expected_referrer_reward, 9);
        let buyer_balance = treasury_v1::balance_of(buyer_addr);
        let expected_buyer_balance =
            BUYER_MINT_AMOUNT - VIP_PRICE - TICKET_PRICE + expected_referee_reward;
        assert!(buyer_balance == expected_buyer_balance, 10);
    }
}




