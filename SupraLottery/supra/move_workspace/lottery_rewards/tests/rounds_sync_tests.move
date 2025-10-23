#[test_only]
module lottery_rewards::rounds_sync_tests {
    use lottery_core::instances;
    use lottery_core::rounds;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::referrals;
    use lottery_rewards::rounds_sync;
    use lottery_rewards::test_utils;
    use lottery_rewards::vip;
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
        vrf_admin = @vrf_hub,
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
            instances::init(lottery_admin, @vrf_hub);
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

        rounds::buy_ticket(buyer, lottery_id);
        assert!(rounds::purchase_queue_length() == 1, 1);

        rounds_sync::sync_purchases_from_rounds(lottery_admin, 0);
        assert!(rounds::purchase_queue_length() == 0, 2);

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
        let expected_referrer_reward =
            TICKET_PRICE * REFERRER_BPS / BASIS_POINT_DENOMINATOR;
        let expected_referee_reward =
            TICKET_PRICE * REFEREE_BPS / BASIS_POINT_DENOMINATOR;
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
