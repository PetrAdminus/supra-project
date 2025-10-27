#[test_only]
module lottery_rewards::vip_tests {
    use lottery_core::instances;
    use lottery_core::rounds;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use lottery_rewards::rounds_sync;
    use lottery_rewards::referrals;
    use lottery_rewards::rewards_test_utils as test_utils;
    use lottery_rewards::vip;
    use std::signer;
    use std::timestamp;
    use std::vector;
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
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        vip::init(lottery_admin);

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

        vip::ensure_caps_initialized(lottery_admin);
        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, VIP_BONUS_TICKETS);
        if (!referrals::is_initialized()) {
            referrals::init(lottery_admin);
        };
        referrals::ensure_caps_initialized(lottery_admin);
        referrals::set_lottery_config(lottery_admin, lottery_id, 0, 0);

        let config_events = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        if (vector::length(&config_events) > 0) {
            let config_event = test_utils::last_event_ref(&config_events);
            let (config_lottery, config_price_value, config_duration_value, config_bonus_value) =
                vip::vip_config_event_fields_for_test(config_event);
            assert!(config_lottery == lottery_id, 147);
            assert!(config_price_value == VIP_PRICE, 148);
            assert!(config_duration_value == VIP_DURATION, 149);
            assert!(config_bonus_value == VIP_BONUS_TICKETS, 150);
        };

        let config_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&config_snapshot_events) > 0) {
            let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
            let (config_snapshot_admin, config_snapshot_lotteries) =
                vip::vip_snapshot_event_fields_for_test(config_snapshot_event);
            assert!(config_snapshot_admin == signer::address_of(lottery_admin), 152);
            assert!(vector::length(&config_snapshot_lotteries) == 1, 153);
            let config_snapshot_entry = vector::borrow(&config_snapshot_lotteries, 0);
            let (
                config_snapshot_lottery_id,
                config_snapshot_config,
                config_snapshot_members,
                config_snapshot_active,
                config_snapshot_revenue,
                config_snapshot_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(config_snapshot_entry);
            assert!(config_snapshot_lottery_id == lottery_id, 154);
            let config_snapshot_price = vip::vip_config_price(&config_snapshot_config);
            let config_snapshot_duration = vip::vip_config_duration_secs(&config_snapshot_config);
            let config_snapshot_bonus = vip::vip_config_bonus_tickets(&config_snapshot_config);
            assert!(config_snapshot_price == VIP_PRICE, 155);
            assert!(config_snapshot_duration == VIP_DURATION, 156);
            assert!(config_snapshot_bonus == VIP_BONUS_TICKETS, 157);
            assert!(config_snapshot_members == 0, 158);
            assert!(config_snapshot_active == 0, 159);
            assert!(config_snapshot_revenue == 0, 160);
            assert!(config_snapshot_bonus_issued == 0, 161);
        };

        let _ = test_utils::drain_events<vip::VipSubscribedEvent>();
        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let _ = test_utils::drain_events<vip::VipBonusIssuedEvent>();
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

        let subscribe_start = timestamp::now_seconds();
        vip::subscribe(player, lottery_id);
        let subscribed_events = test_utils::drain_events<vip::VipSubscribedEvent>();
        let subscribed_event_count = vector::length(&subscribed_events);
        if (subscribed_event_count > 0) {
            let subscribed_event = test_utils::last_event_ref(&subscribed_events);
            let (
                subscribed_lottery,
                subscribed_player,
                subscribed_expiry,
                subscribed_bonus,
                subscribed_amount,
                subscribed_renewed,
            ) = vip::vip_subscribed_event_fields_for_test(subscribed_event);
            assert!(subscribed_lottery == lottery_id, 163);
            assert!(subscribed_player == signer::address_of(player), 164);
            assert!(subscribed_bonus == VIP_BONUS_TICKETS, 165);
            assert!(subscribed_amount == VIP_PRICE, 166);
            assert!(!subscribed_renewed, 167);
            assert!(subscribed_expiry >= subscribe_start + VIP_DURATION, 168);
        };

        let subscribed_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let subscribed_snapshot_count = vector::length(&subscribed_snapshot_events);
        if (subscribed_snapshot_count > 0) {
            let subscribed_snapshot_event =
                test_utils::last_event_ref(&subscribed_snapshot_events);
            let (subscribed_admin, subscribed_lotteries) =
                vip::vip_snapshot_event_fields_for_test(subscribed_snapshot_event);
            assert!(subscribed_admin == signer::address_of(lottery_admin), 170);
            assert!(vector::length(&subscribed_lotteries) == 1, 171);
            let subscribed_entry = vector::borrow(&subscribed_lotteries, 0);
            let (
                subscribed_lottery_id,
                subscribed_config,
                subscribed_members,
                subscribed_active,
                subscribed_revenue,
                subscribed_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(subscribed_entry);
            assert!(subscribed_lottery_id == lottery_id, 172);
            let subscribed_config_price = vip::vip_config_price(&subscribed_config);
            let subscribed_config_duration = vip::vip_config_duration_secs(&subscribed_config);
            let subscribed_config_bonus = vip::vip_config_bonus_tickets(&subscribed_config);
            assert!(subscribed_config_price == VIP_PRICE, 173);
            assert!(subscribed_config_duration == VIP_DURATION, 174);
            assert!(subscribed_config_bonus == VIP_BONUS_TICKETS, 175);
            assert!(subscribed_members == 1, 176);
            assert!(subscribed_active == 1, 177);
            assert!(subscribed_revenue == VIP_PRICE, 178);
            assert!(subscribed_bonus_issued == 0, 179);
        };

        let _ = test_utils::drain_events<vip::VipBonusIssuedEvent>();
        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let player_addr = signer::address_of(player);
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
        assert!(rounds::purchase_queue_length() == 1, 60);
        rounds_sync::sync_purchases_from_rounds(lottery_admin, 0);
        assert!(rounds::purchase_queue_length() == 0, 61);

        let bonus_events = test_utils::drain_events<vip::VipBonusIssuedEvent>();
        let bonus_event_count = vector::length(&bonus_events);
        if (bonus_event_count > 0) {
            let bonus_event = test_utils::last_event_ref(&bonus_events);
            let (bonus_lottery, bonus_player, bonus_amount) =
                vip::vip_bonus_event_fields_for_test(bonus_event);
            assert!(bonus_lottery == lottery_id, 181);
            assert!(bonus_player == signer::address_of(player), 182);
            assert!(bonus_amount == VIP_BONUS_TICKETS, 183);
        };

        let bonus_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        let bonus_snapshot_count = vector::length(&bonus_snapshot_events);
        if (bonus_snapshot_count > 0) {
            let bonus_snapshot_event = test_utils::last_event_ref(&bonus_snapshot_events);
            let (bonus_snapshot_admin, bonus_snapshot_lotteries) =
                vip::vip_snapshot_event_fields_for_test(bonus_snapshot_event);
            assert!(bonus_snapshot_admin == signer::address_of(lottery_admin), 185);
            assert!(vector::length(&bonus_snapshot_lotteries) == 1, 186);
            let bonus_snapshot_entry = vector::borrow(&bonus_snapshot_lotteries, 0);
            let (
                bonus_snapshot_lottery_id,
                bonus_snapshot_config,
                bonus_snapshot_members,
                bonus_snapshot_active,
                bonus_snapshot_revenue,
                bonus_snapshot_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(bonus_snapshot_entry);
            assert!(bonus_snapshot_lottery_id == lottery_id, 187);
            let bonus_snapshot_price = vip::vip_config_price(&bonus_snapshot_config);
            let bonus_snapshot_duration = vip::vip_config_duration_secs(&bonus_snapshot_config);
            let bonus_snapshot_bonus = vip::vip_config_bonus_tickets(&bonus_snapshot_config);
            assert!(bonus_snapshot_price == VIP_PRICE, 188);
            assert!(bonus_snapshot_duration == VIP_DURATION, 189);
            assert!(bonus_snapshot_bonus == VIP_BONUS_TICKETS, 190);
            assert!(bonus_snapshot_members == 1, 191);
            assert!(bonus_snapshot_active == 1, 192);
            assert!(bonus_snapshot_revenue == VIP_PRICE, 193);
            assert!(bonus_snapshot_bonus_issued == VIP_BONUS_TICKETS, 194);
        };
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

        let remaining_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        assert!(vector::length(&remaining_snapshot_events) == 0, 195);
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

        vip::ensure_caps_initialized(lottery_admin);
        vip::upsert_config(lottery_admin, lottery_id, VIP_PRICE, VIP_DURATION, 1);
        if (!referrals::is_initialized()) {
            referrals::init(lottery_admin);
        };
        referrals::ensure_caps_initialized(lottery_admin);
        referrals::set_lottery_config(lottery_admin, lottery_id, 0, 0);

        let config_events = test_utils::drain_events<vip::VipConfigUpdatedEvent>();
        if (vector::length(&config_events) > 0) {
            let config_event = test_utils::last_event_ref(&config_events);
            let (config_lottery, config_price_value, config_duration_value, config_bonus_value) =
                vip::vip_config_event_fields_for_test(config_event);
            assert!(config_lottery == lottery_id, 201);
            assert!(config_price_value == VIP_PRICE, 202);
            assert!(config_duration_value == VIP_DURATION, 203);
            assert!(config_bonus_value == 1, 204);
        };

        let config_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&config_snapshot_events) > 0) {
            let config_snapshot_event = test_utils::last_event_ref(&config_snapshot_events);
            let (config_snapshot_admin, config_snapshot_lotteries) =
                vip::vip_snapshot_event_fields_for_test(config_snapshot_event);
            assert!(config_snapshot_admin == signer::address_of(lottery_admin), 206);
            assert!(vector::length(&config_snapshot_lotteries) == 1, 207);
            let config_snapshot_entry = vector::borrow(&config_snapshot_lotteries, 0);
            let (
                config_snapshot_lottery_id,
                config_snapshot_config,
                config_snapshot_members,
                config_snapshot_active,
                config_snapshot_revenue,
                config_snapshot_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(config_snapshot_entry);
            assert!(config_snapshot_lottery_id == lottery_id, 208);
            let config_snapshot_price = vip::vip_config_price(&config_snapshot_config);
            let config_snapshot_duration = vip::vip_config_duration_secs(&config_snapshot_config);
            let config_snapshot_bonus = vip::vip_config_bonus_tickets(&config_snapshot_config);
            assert!(config_snapshot_price == VIP_PRICE, 209);
            assert!(config_snapshot_duration == VIP_DURATION, 210);
            assert!(config_snapshot_bonus == 1, 211);
            assert!(config_snapshot_members == 0, 212);
            assert!(config_snapshot_active == 0, 213);
            assert!(config_snapshot_revenue == 0, 214);
            assert!(config_snapshot_bonus_issued == 0, 215);
        };

        let _ = test_utils::drain_events<vip::VipSubscribedEvent>();
        let _ = test_utils::drain_events<vip::VipCancelledEvent>();
        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();

        treasury_v1::mint_to(lottery_admin, signer::address_of(lottery_admin), VIP_PRICE * 10);
        vip::subscribe_for(lottery_admin, lottery_id, signer::address_of(recipient));
        let subscribed_events = test_utils::drain_events<vip::VipSubscribedEvent>();
        if (vector::length(&subscribed_events) > 0) {
            let subscribed_event = test_utils::last_event_ref(&subscribed_events);
            let (subscribed_lottery, subscribed_player, subscribed_expiry, subscribed_bonus, subscribed_amount, subscribed_renewed) =
                vip::vip_subscribed_event_fields_for_test(subscribed_event);
            assert!(subscribed_lottery == lottery_id, 217);
            assert!(subscribed_player == signer::address_of(recipient), 218);
            assert!(subscribed_bonus == 1, 219);
            assert!(subscribed_amount == VIP_PRICE, 220);
            assert!(!subscribed_renewed, 221);
            assert!(subscribed_expiry > 0, 222);
        };

        let subscribed_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&subscribed_snapshot_events) > 0) {
            let subscribed_snapshot_event =
                test_utils::last_event_ref(&subscribed_snapshot_events);
            let (subscribed_admin, subscribed_lotteries) =
                vip::vip_snapshot_event_fields_for_test(subscribed_snapshot_event);
            assert!(subscribed_admin == signer::address_of(lottery_admin), 224);
            assert!(vector::length(&subscribed_lotteries) == 1, 225);
            let subscribed_entry = vector::borrow(&subscribed_lotteries, 0);
            let (
                subscribed_lottery_id,
                subscribed_config,
                subscribed_members,
                subscribed_active,
                subscribed_revenue,
                subscribed_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(subscribed_entry);
            assert!(subscribed_lottery_id == lottery_id, 226);
            let subscribed_price = vip::vip_config_price(&subscribed_config);
            let subscribed_duration = vip::vip_config_duration_secs(&subscribed_config);
            let subscribed_bonus_config = vip::vip_config_bonus_tickets(&subscribed_config);
            assert!(subscribed_price == VIP_PRICE, 227);
            assert!(subscribed_duration == VIP_DURATION, 228);
            assert!(subscribed_bonus_config == 1, 229);
            assert!(subscribed_members == 1, 230);
            assert!(subscribed_active == 1, 231);
            assert!(subscribed_revenue == VIP_PRICE, 232);
            assert!(subscribed_bonus_issued == 0, 233);
        };

        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
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
        let admin_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&admin_snapshot_events) > 0) {
            let admin_snapshot_event = test_utils::last_event_ref(&admin_snapshot_events);
            let (admin_snapshot_admin, admin_snapshot_lotteries) =
                vip::vip_snapshot_event_fields_for_test(admin_snapshot_event);
            assert!(admin_snapshot_admin == signer::address_of(gift_admin), 235);
            assert!(vector::length(&admin_snapshot_lotteries) == 1, 236);
            let admin_snapshot_entry = vector::borrow(&admin_snapshot_lotteries, 0);
            let (
                admin_snapshot_lottery_id,
                _admin_snapshot_config,
                admin_snapshot_members,
                admin_snapshot_active,
                admin_snapshot_revenue,
                admin_snapshot_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(admin_snapshot_entry);
            assert!(admin_snapshot_lottery_id == lottery_id, 237);
            assert!(admin_snapshot_members == 1, 238);
            assert!(admin_snapshot_active == 1, 239);
            assert!(admin_snapshot_revenue == VIP_PRICE, 240);
            assert!(admin_snapshot_bonus_issued == 0, 241);
        };

        let _ = test_utils::drain_events<vip::VipCancelledEvent>();
        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();

        vip::cancel_for(gift_admin, lottery_id, signer::address_of(recipient));
        let cancelled_events = test_utils::drain_events<vip::VipCancelledEvent>();
        if (vector::length(&cancelled_events) > 0) {
            let cancelled_event = test_utils::last_event_ref(&cancelled_events);
            let (cancelled_lottery, cancelled_player) =
                vip::vip_cancelled_event_fields_for_test(cancelled_event);
            assert!(cancelled_lottery == lottery_id, 243);
            assert!(cancelled_player == signer::address_of(recipient), 244);
        };

        let cancelled_snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        if (vector::length(&cancelled_snapshot_events) > 0) {
            let cancelled_snapshot_event =
                test_utils::last_event_ref(&cancelled_snapshot_events);
            let (cancelled_admin, cancelled_lotteries) =
                vip::vip_snapshot_event_fields_for_test(cancelled_snapshot_event);
            assert!(cancelled_admin == signer::address_of(gift_admin), 246);
            assert!(vector::length(&cancelled_lotteries) == 1, 247);
            let cancelled_entry = vector::borrow(&cancelled_lotteries, 0);
            let (
                cancelled_lottery_id,
                _cancelled_config,
                cancelled_members,
                cancelled_active,
                cancelled_revenue,
                cancelled_bonus_issued,
            ) = vip::vip_lottery_snapshot_fields_for_test(cancelled_entry);
            assert!(cancelled_lottery_id == lottery_id, 248);
            assert!(cancelled_members == 1, 249);
            assert!(cancelled_active == 0, 250);
            assert!(cancelled_revenue == VIP_PRICE, 251);
            assert!(cancelled_bonus_issued == 0, 252);
        };

        let _ = test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
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

        let snapshot_events =
            test_utils::drain_events<vip::VipSnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 0, 253);
    }
}
