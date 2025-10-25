#[test_only]
module lottery::vip_tests {
    use std::signer;
    use std::vector;
    use lottery_core::instances;
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
        test_utils::ensure_core_accounts();
        treasury_v1::init_token(
            lottery_admin,
            b"vip_seed",
            b"VIP Token",
            b"VIP",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store(lottery_admin);
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
        test_utils::ensure_core_accounts();
        test_utils::init_time_for_tests();
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
        setup_token(lottery_admin, player);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipSubscribedEvent>();
        let _ = test_utils::drain_events<vip::VipCancelledEvent>();
        let _ = test_utils::drain_events<vip::VipBonusIssuedEvent>();

        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, VIP_BONUS_TICKETS);
        let config_events = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipConfigUpdatedEvent>(&config_events, 1, 1500);
        let config_event = *test_utils::last_event_ref(&config_events);
        let vip::VipConfigUpdatedEvent {
            lottery_id: config_lottery,
            price: config_price,
            duration_secs: config_duration,
            bonus_tickets: config_bonus,
        } = config_event;
        assert!(config_lottery == lottery_id, 1501);
        assert!(config_price == VIP_PRICE, 1502);
        assert!(config_duration == VIP_DURATION, 1503);
        assert!(config_bonus == VIP_BONUS_TICKETS, 1504);

        let config_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&config_snapshot_events, 1, 1505);
        let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
        let (config_admin, config_snapshots) =
            vip::vip_snapshot_event_fields_for_test(config_snapshot_event);
        assert!(config_admin == signer::address_of(lottery_admin), 1506);
        assert!(vector::length(&config_snapshots) == 1, 1507);
        let config_snapshot_ref = vector::borrow(&config_snapshots, 0);
        let (
            config_snapshot_lottery,
            config_snapshot_config,
            config_members,
            config_active,
            config_revenue,
            config_issued,
        ) = vip::vip_lottery_snapshot_fields_for_test(config_snapshot_ref);
        assert!(config_snapshot_lottery == lottery_id, 1508);
        assert!(vip::vip_config_price(&config_snapshot_config) == VIP_PRICE, 1509);
        assert!(vip::vip_config_duration_secs(&config_snapshot_config) == VIP_DURATION, 1510);
        assert!(vip::vip_config_bonus_tickets(&config_snapshot_config) == VIP_BONUS_TICKETS, 1511);
        assert!(config_members == 0, 1512);
        assert!(config_active == 0, 1513);
        assert!(config_revenue == 0, 1514);
        assert!(config_issued == 0, 1515);

        let summary_before_opt = vip::get_lottery_summary(lottery_id);
        let summary_before = test_utils::unwrap(&mut summary_before_opt);
        let (_config_before, total_members, active_members, total_revenue, _) =
            vip::summary_fields_for_test(&summary_before);
        assert!(total_members == 0, 0);
        assert!(active_members == 0, 1);
        assert!(total_revenue == 0, 2);

        let vip_snapshot_initial_opt = vip::get_vip_snapshot();
        let vip_snapshot_initial = test_utils::unwrap(&mut vip_snapshot_initial_opt);
        let (snapshot_admin_initial, lottery_snapshots_initial) =
            vip::vip_snapshot_fields_for_test(&vip_snapshot_initial);
        assert!(snapshot_admin_initial == signer::address_of(lottery_admin), 20);
        assert!(vector::length(&lottery_snapshots_initial) == 1, 21);
        let initial_snapshot = vector::borrow(&lottery_snapshots_initial, 0);
        let (_, config_initial, members_initial, active_initial, revenue_initial, issued_initial) =
            vip::vip_lottery_snapshot_fields_for_test(initial_snapshot);
        let config_price = vip::vip_config_price(&config_initial);
        let config_duration = vip::vip_config_duration_secs(&config_initial);
        let config_bonus = vip::vip_config_bonus_tickets(&config_initial);
        assert!(config_price == VIP_PRICE, 22);
        assert!(config_duration == VIP_DURATION, 23);
        assert!(config_bonus == VIP_BONUS_TICKETS, 24);
        assert!(members_initial == 0, 25);
        assert!(active_initial == 0, 26);
        assert!(revenue_initial == 0, 27);
        assert!(issued_initial == 0, 28);

        vip::subscribe(player, lottery_id);
        let player_addr = signer::address_of(player);
        let subscribe_events = test_utils::drain_events<vip::VipSubscribedEvent>();
        test_utils::assert_len_eq<vip::VipSubscribedEvent>(&subscribe_events, 1, 1516);
        let subscribe_event = *test_utils::last_event_ref(&subscribe_events);
        let vip::VipSubscribedEvent {
            lottery_id: subscribed_lottery,
            player: subscribed_player,
            expiry_ts: subscribed_expiry,
            bonus_tickets: subscribed_bonus,
            amount_paid: subscribed_amount,
            renewed: subscribed_renewed,
        } = subscribe_event;
        assert!(subscribed_lottery == lottery_id, 1517);
        assert!(subscribed_player == player_addr, 1518);
        assert!(subscribed_bonus == VIP_BONUS_TICKETS, 1519);
        assert!(subscribed_amount == VIP_PRICE, 1520);
        assert!(!subscribed_renewed, 1521);
        assert!(subscribed_expiry > 0, 1522);

        let subscribe_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&subscribe_snapshot_events, 1, 1523);
        let subscribe_snapshot_event = test_utils::last_event_ref(&subscribe_snapshot_events);
        let (subscribe_admin, subscribe_snapshots) =
            vip::vip_snapshot_event_fields_for_test(subscribe_snapshot_event);
        assert!(subscribe_admin == signer::address_of(lottery_admin), 1524);
        assert!(vector::length(&subscribe_snapshots) == 1, 1525);
        let subscribe_snapshot_ref = vector::borrow(&subscribe_snapshots, 0);
        let (
            subscribe_lottery_id,
            subscribe_config,
            subscribe_members,
            subscribe_active,
            subscribe_revenue,
            subscribe_issued,
        ) = vip::vip_lottery_snapshot_fields_for_test(subscribe_snapshot_ref);
        assert!(subscribe_lottery_id == lottery_id, 1526);
        assert!(vip::vip_config_price(&subscribe_config) == VIP_PRICE, 1527);
        assert!(subscribe_members == 1, 1528);
        assert!(subscribe_active == 1, 1529);
        assert!(subscribe_revenue == VIP_PRICE, 1530);
        assert!(subscribe_issued == 0, 1531);

        let subscription_opt = vip::get_subscription(lottery_id, player_addr);
        let subscription = test_utils::unwrap(&mut subscription_opt);
        let (_expiry, is_active, bonus_tickets) =
            vip::subscription_fields_for_test(&subscription);
        assert!(is_active, 3);
        assert!(bonus_tickets == VIP_BONUS_TICKETS, 4);

        let treasury_summary_opt = treasury_multi::get_lottery_summary(lottery_id);
        let treasury_summary = test_utils::unwrap(&mut treasury_summary_opt);
        let (_config_summary, pool) = treasury_multi::summary_components_for_test(&treasury_summary);
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 0, 5);
        assert!(operations_balance == VIP_PRICE, 6);

        rounds::buy_ticket(player, lottery_id);
        let bonus_events = test_utils::drain_events<vip::VipBonusIssuedEvent>();
        test_utils::assert_len_eq<vip::VipBonusIssuedEvent>(&bonus_events, 1, 1532);
        let bonus_event = *test_utils::last_event_ref(&bonus_events);
        let vip::VipBonusIssuedEvent {
            lottery_id: bonus_lottery,
            player: bonus_player,
            bonus_tickets: bonus_amount,
        } = bonus_event;
        assert!(bonus_lottery == lottery_id, 1533);
        assert!(bonus_player == player_addr, 1534);
        assert!(bonus_amount == VIP_BONUS_TICKETS, 1535);

        let bonus_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&bonus_snapshot_events, 1, 1536);
        let bonus_snapshot_event = test_utils::last_event_ref(&bonus_snapshot_events);
        let (bonus_admin, bonus_snapshots) =
            vip::vip_snapshot_event_fields_for_test(bonus_snapshot_event);
        assert!(bonus_admin == signer::address_of(lottery_admin), 1537);
        assert!(vector::length(&bonus_snapshots) == 1, 1538);
        let bonus_snapshot_ref = vector::borrow(&bonus_snapshots, 0);
        let (
            bonus_snapshot_lottery,
            _bonus_config,
            bonus_members,
            bonus_active,
            bonus_revenue,
            bonus_issued,
        ) = vip::vip_lottery_snapshot_fields_for_test(bonus_snapshot_ref);
        assert!(bonus_snapshot_lottery == lottery_id, 1539);
        assert!(bonus_members == 1, 1540);
        assert!(bonus_active == 1, 1541);
        assert!(bonus_revenue == VIP_PRICE, 1542);
        assert!(bonus_issued == VIP_BONUS_TICKETS, 1543);

        let round_snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let round_snapshot = test_utils::unwrap(&mut round_snapshot_opt);
        let (ticket_count, _, _, _, _) = rounds::round_snapshot_fields_for_test(&round_snapshot);
        assert!(ticket_count == 1 + VIP_BONUS_TICKETS, 7);

        let summary_after_opt = vip::get_lottery_summary(lottery_id);
        let summary_after = test_utils::unwrap(&mut summary_after_opt);
        let (_config_after, members_after, active_after, revenue_after, bonus_tickets_issued) =
            vip::summary_fields_for_test(&summary_after);
        assert!(members_after == 1, 8);
        assert!(active_after == 1, 9);
        assert!(revenue_after == VIP_PRICE, 10);
        assert!(bonus_tickets_issued == VIP_BONUS_TICKETS, 11);

        let lottery_snapshot_opt = vip::get_lottery_snapshot(lottery_id);
        let lottery_snapshot = test_utils::unwrap(&mut lottery_snapshot_opt);
        let (
            _lottery_id_snapshot,
            _config_snapshot,
            members_snapshot,
            active_snapshot,
            revenue_snapshot,
            issued_snapshot,
        ) = vip::vip_lottery_snapshot_fields_for_test(&lottery_snapshot);
        assert!(members_snapshot == 1, 29);
        assert!(active_snapshot == 1, 30);
        assert!(revenue_snapshot == VIP_PRICE, 31);
        assert!(issued_snapshot == VIP_BONUS_TICKETS, 32);

        let vip_snapshot_after_opt = vip::get_vip_snapshot();
        let vip_snapshot_after = test_utils::unwrap(&mut vip_snapshot_after_opt);
        let (snapshot_admin_after, lottery_snapshots_after) =
            vip::vip_snapshot_fields_for_test(&vip_snapshot_after);
        assert!(snapshot_admin_after == signer::address_of(lottery_admin), 33);
        assert!(vector::length(&lottery_snapshots_after) == 1, 34);
        let latest_snapshot = vector::borrow(&lottery_snapshots_after, 0);
        let (
            _lottery_id_latest,
            _config_latest,
            members_latest,
            active_latest,
            revenue_latest,
            issued_latest,
        ) = vip::vip_lottery_snapshot_fields_for_test(latest_snapshot);
        assert!(members_latest == 1, 35);
        assert!(active_latest == 1, 36);
        assert!(revenue_latest == VIP_PRICE, 37);
        assert!(issued_latest == VIP_BONUS_TICKETS, 38);

        let snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&snapshot_events, 0, 1544);
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
        setup_token(lottery_admin, gift_admin);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 6000, 2000, 2000);
        treasury_v1::register_store(recipient);
        treasury_v1::mint_to(lottery_admin, signer::address_of(recipient), 10_000);

        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipSubscribedEvent>();
        let _ = test_utils::drain_events<vip::VipCancelledEvent>();

        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, 1);
        let config_events = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipConfigUpdatedEvent>(&config_events, 1, 1545);
        let config_event = *test_utils::last_event_ref(&config_events);
        let vip::VipConfigUpdatedEvent {
            lottery_id: config_lottery,
            price: config_price,
            duration_secs: config_duration,
            bonus_tickets: config_bonus,
        } = config_event;
        assert!(config_lottery == lottery_id, 1546);
        assert!(config_price == VIP_PRICE, 1547);
        assert!(config_duration == VIP_DURATION, 1548);
        assert!(config_bonus == 1, 1549);

        let config_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&config_snapshot_events, 1, 1550);
        let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
        let (config_admin, config_snapshots) =
            vip::vip_snapshot_event_fields_for_test(config_snapshot_event);
        assert!(config_admin == signer::address_of(lottery_admin), 1551);
        assert!(vector::length(&config_snapshots) == 1, 1552);

        treasury_v1::mint_to(lottery_admin, signer::address_of(lottery_admin), VIP_PRICE * 10);
        vip::subscribe_for(lottery_admin, lottery_id, signer::address_of(recipient));
        let subscribe_events = test_utils::drain_events<vip::VipSubscribedEvent>();
        test_utils::assert_len_eq<vip::VipSubscribedEvent>(&subscribe_events, 1, 1553);
        let subscribe_event = *test_utils::last_event_ref(&subscribe_events);
        let vip::VipSubscribedEvent {
            lottery_id: subscribed_lottery,
            player: subscribed_player,
            expiry_ts: subscribed_expiry,
            bonus_tickets: subscribed_bonus,
            amount_paid: subscribed_amount,
            renewed: subscribed_renewed,
        } = subscribe_event;
        assert!(subscribed_lottery == lottery_id, 1554);
        assert!(subscribed_player == signer::address_of(recipient), 1555);
        assert!(subscribed_bonus == 1, 1556);
        assert!(subscribed_amount == VIP_PRICE, 1557);
        assert!(!subscribed_renewed, 1558);
        assert!(subscribed_expiry > 0, 1559);

        let subscribe_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&subscribe_snapshot_events, 1, 1560);
        let subscribe_snapshot_event = test_utils::last_event_ref(&subscribe_snapshot_events);
        let (subscribe_admin, subscribe_snapshots) =
            vip::vip_snapshot_event_fields_for_test(subscribe_snapshot_event);
        assert!(subscribe_admin == signer::address_of(lottery_admin), 1561);
        assert!(vector::length(&subscribe_snapshots) == 1, 1562);

        let subscription_opt =
            vip::get_subscription(lottery_id, signer::address_of(recipient));
        let subscription = test_utils::unwrap(&mut subscription_opt);
        let (_expiry_before_cancel, is_active_before, _bonus_before) =
            vip::subscription_fields_for_test(&subscription);
        assert!(is_active_before, 12);

        let lottery_snapshot_before_cancel_opt =
            vip::get_lottery_snapshot(lottery_id);
        let lottery_snapshot_before_cancel =
            test_utils::unwrap(&mut lottery_snapshot_before_cancel_opt);
        let (
            _snapshot_lottery_id,
            _snapshot_config,
            members_before_cancel,
            active_before_cancel,
            revenue_before_cancel,
            issued_before_cancel,
        ) = vip::vip_lottery_snapshot_fields_for_test(&lottery_snapshot_before_cancel);
        assert!(members_before_cancel == 1, 14);
        assert!(active_before_cancel == 1, 15);
        assert!(revenue_before_cancel == VIP_PRICE, 16);
        assert!(issued_before_cancel == 0, 17);

        vip::set_admin(lottery_admin, signer::address_of(gift_admin));
        let admin_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&admin_snapshot_events, 1, 1563);
        let admin_snapshot_event = test_utils::last_event_ref(&admin_snapshot_events);
        let (admin_event_admin, _) =
            vip::vip_snapshot_event_fields_for_test(admin_snapshot_event);
        assert!(admin_event_admin == signer::address_of(gift_admin), 1564);

        vip::cancel_for(gift_admin, lottery_id, signer::address_of(recipient));
        let cancelled_events = test_utils::drain_events<vip::VipCancelledEvent>();
        test_utils::assert_len_eq<vip::VipCancelledEvent>(&cancelled_events, 1, 1565);
        let cancelled_event = *test_utils::last_event_ref(&cancelled_events);
        let vip::VipCancelledEvent {
            lottery_id: cancelled_lottery,
            player: cancelled_player,
        } = cancelled_event;
        assert!(cancelled_lottery == lottery_id, 1566);
        assert!(cancelled_player == signer::address_of(recipient), 1567);

        let cancel_snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&cancel_snapshot_events, 1, 1568);
        let cancel_snapshot_event = test_utils::last_event_ref(&cancel_snapshot_events);
        let (cancel_admin, cancel_snapshots) =
            vip::vip_snapshot_event_fields_for_test(cancel_snapshot_event);
        assert!(cancel_admin == signer::address_of(gift_admin), 1569);
        assert!(vector::length(&cancel_snapshots) == 1, 1570);

        let after_cancel_opt =
            vip::get_subscription(lottery_id, signer::address_of(recipient));
        let after_cancel = test_utils::unwrap(&mut after_cancel_opt);
        let (_expiry_after_cancel, is_active_after, _bonus_after) =
            vip::subscription_fields_for_test(&after_cancel);
        assert!(!is_active_after, 13);

        let lottery_snapshot_after_cancel_opt =
            vip::get_lottery_snapshot(lottery_id);
        let lottery_snapshot_after_cancel =
            test_utils::unwrap(&mut lottery_snapshot_after_cancel_opt);
        let (
            _snapshot_lottery_id_after,
            _snapshot_config_after,
            members_after_cancel,
            active_after_cancel,
            revenue_after_cancel,
            issued_after_cancel,
        ) = vip::vip_lottery_snapshot_fields_for_test(&lottery_snapshot_after_cancel);
        assert!(members_after_cancel == 1, 18);
        assert!(active_after_cancel == 0, 19);
        assert!(revenue_after_cancel == VIP_PRICE, 20);
        assert!(issued_after_cancel == 0, 21);

        let vip_snapshot_after_cancel_opt = vip::get_vip_snapshot();
        let vip_snapshot_after_cancel =
            test_utils::unwrap(&mut vip_snapshot_after_cancel_opt);
        let (_vip_admin_after_cancel, vip_lotteries_after_cancel) =
            vip::vip_snapshot_fields_for_test(&vip_snapshot_after_cancel);
        assert!(vector::length(&vip_lotteries_after_cancel) == 1, 22);
        let vip_snapshot_entry = vector::borrow(&vip_lotteries_after_cancel, 0);
        let (
            _vip_snapshot_lottery_id,
            _vip_snapshot_config,
            _vip_members,
            vip_active_after_cancel,
            vip_revenue_after_cancel,
            vip_issued_after_cancel,
        ) = vip::vip_lottery_snapshot_fields_for_test(vip_snapshot_entry);
        assert!(vip_active_after_cancel == 0, 23);
        assert!(vip_revenue_after_cancel == VIP_PRICE, 24);
        assert!(vip_issued_after_cancel == 0, 25);

        let snapshot_events = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        test_utils::assert_len_eq<vip::VipSnapshotUpdatedEvent>(&snapshot_events, 0, 1571);
    }
}
