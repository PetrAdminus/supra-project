module lottery::vip_tests {
    use std::option;
    use std::account;
    use std::signer;
    use std::u128;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery::test_utils;
    use lottery::vip;
    use lottery_factory::registry;
    use vrf_hub::hub;

    const VIP_PRICE: u64 = 250;
    const VIP_DURATION: u64 = 1_000;
    const VIP_BONUS_TICKETS: u64 = 2;

    fun setup_token(lottery_admin: &signer, player: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"vip_seed",
            b"VIP Token",
            b"VIP",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(player);
        treasury_v1::mint_to(lottery_admin, signer::address_of(player), 50_000);
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
        vip::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(VIP_PRICE, 1500);
        registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            b"vip-test",
        )
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        player = @player1,
    )]
    fun vip_subscription_applies_bonus(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        player: &signer,
    ) {
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, player);

        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, VIP_BONUS_TICKETS);
        let (total_members, active_members, total_revenue, _) =
            vip::get_lottery_summary_view(lottery_id);
        assert!(total_members == 0, 0);
        assert!(active_members == 0, 1);
        assert!(total_revenue == u128::from_u64(0), 2);

        vip::subscribe(player, lottery_id);
        let player_addr = signer::address_of(player);
        let (is_active, bonus_tickets) =
            vip::get_subscription_view(lottery_id, player_addr);
        assert!(is_active, 3);
        assert!(bonus_tickets == VIP_BONUS_TICKETS, 4);

        let (prize_balance, operations_balance) = treasury_multi::get_pool_balances(lottery_id);
        assert!(prize_balance == u128::from_u64(0), 5);
        assert!(operations_balance == u128::from_u64(VIP_PRICE), 6);

        rounds::buy_ticket(player, lottery_id);
        let (ticket_count, _, _, _) =
            test_utils::unwrap(rounds::get_round_snapshot(lottery_id, 0));
        assert!(ticket_count == 1 + VIP_BONUS_TICKETS, 7);

        let (members_after, active_after, revenue_after, bonus_tickets_issued) =
            vip::get_lottery_summary_view(lottery_id);
        assert!(members_after == 1, 8);
        assert!(active_after == 1, 9);
        assert!(revenue_after == u128::from_u64(VIP_PRICE), 10);
        assert!(bonus_tickets_issued == VIP_BONUS_TICKETS, 11);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        gift_admin = @player2,
        recipient = @player3,
    )]
    fun admin_can_gift_and_cancel(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        gift_admin: &signer,
        recipient: &signer,
    ) {
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 6000, 2000, 2000);
        setup_token(lottery_admin, gift_admin);
        treasury_v1::register_store(recipient);
        treasury_v1::mint_to(lottery_admin, signer::address_of(recipient), 10_000);

        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, 1);
        vip::subscribe_for(gift_admin, lottery_id, signer::address_of(recipient));
        let (is_active_before, _) =
            vip::get_subscription_view(lottery_id, signer::address_of(recipient));
        assert!(is_active_before, 12);

        vip::cancel_for(lottery_admin, lottery_id, signer::address_of(recipient));
        let (is_active_after, _) =
            vip::get_subscription_view(lottery_id, signer::address_of(recipient));
        assert!(!is_active_after, 13);
    }
}
