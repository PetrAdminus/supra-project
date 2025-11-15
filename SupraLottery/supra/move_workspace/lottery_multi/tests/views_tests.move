module lottery_multi::views_tests {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_multi::automation;
    use lottery_multi::cancellation;
    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::payouts;
    use lottery_multi::lottery_registry as registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    // #[test(account = @lottery_multi)]
    fun list_by_all_tags_requires_full_mask(account: &signer) {
        registry::init_registry(account);

        let config_a_base = new_config(tags::type_basic(), tags::tag_daily() | tags::tag_promo());
        let config_a = registry::config_with_run_id(&config_a_base, 10);
        registry::create_draft_admin_with_config(account, 1, config_a);

        let config_b_base = new_config(tags::type_basic(), tags::tag_daily());
        let config_b = registry::config_with_run_id(&config_b_base, 11);
        registry::create_draft_admin_with_config(account, 2, config_b);

        let filtered = views::list_by_all_tags(tags::tag_daily() | tags::tag_promo(), 0, 10);
        assert!(vector::length(&filtered) == 1, 0);
        assert!(*vector::borrow(&filtered, 0) == 1, 0);
    }

    // #[test(admin = @lottery_multi, operator = @0x1)]
    fun automation_views_list_registered_bot(admin: &signer, operator: &signer) {

        automation::init_automation(admin);
        let actions = vector::empty<u64>();
        vector::push_back(&mut actions, automation::action_retry_vrf());
        let cron = vector::empty<u8>();
        automation::register_bot(admin, operator, cron, actions, 45, 3, 5_000);

        let bots = views::list_automation_bots();
        assert!(vector::length(&bots) == 1, 0);
        let bot_ref = vector::borrow(&bots, 0);
        assert!(views::automation_bot_operator(bot_ref) == signer::address_of(operator), 0);
        assert!(!views::automation_bot_has_pending(bot_ref), 0);
        assert!(views::automation_bot_max_failures(bot_ref) == 3, 0);

        let single_opt = views::get_automation_bot(signer::address_of(operator));
        assert!(option::is_some(&single_opt), 0);
        let single = option::extract(&mut single_opt);
        assert!(views::automation_bot_timelock_secs(&single) == 45, 0);
        assert!(views::automation_bot_max_failures(&single) == 3, 0);
        let single_actions = views::automation_bot_allowed_actions(&single);
        assert!(vector::length(&single_actions) == 1, 0);
        assert!(*vector::borrow(&single_actions, 0) == automation::action_retry_vrf(), 0);

        let missing = views::get_automation_bot(@0x2);
        assert!(option::is_none(&missing), 0);
    }

    // #[test(account = @lottery_multi)]
    fun list_by_primary_type_returns_descending(account: &signer) {
        registry::init_registry(account);

        let config_basic_base = new_config(tags::type_basic(), 0);
        let config_basic = registry::config_with_run_id(&config_basic_base, 1);
        registry::create_draft_admin_with_config(account, 20, config_basic);

        let config_partner_a_base = new_config(tags::type_partner(), tags::tag_weekly());
        let config_partner_a = registry::config_with_run_id(&config_partner_a_base, 2);
        registry::create_draft_admin_with_config(account, 21, config_partner_a);

        let config_partner_b_base = new_config(tags::type_partner(), tags::tag_promo());
        let config_partner_b = registry::config_with_run_id(&config_partner_b_base, 3);
        registry::create_draft_admin_with_config(account, 22, config_partner_b);

        let partners = views::list_by_primary_type(tags::type_partner(), 0, 10);
        assert!(vector::length(&partners) == 2, 0);
        assert!(*vector::borrow(&partners, 0) == 22, 0);
        assert!(*vector::borrow(&partners, 1) == 21, 0);

        let partners_paginated = views::list_by_primary_type(tags::type_partner(), 1, 1);
        assert!(vector::length(&partners_paginated) == 1, 0);
        assert!(*vector::borrow(&partners_paginated, 0) == 21, 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = lottery_multi::errors::E_PAGINATION_LIMIT)]
    fun list_active_rejects_large_limit(account: &signer) {
        registry::init_registry(account);
        views::list_active(0, 1001);
    }

    // #[test(account = @lottery_multi)]
    fun badge_metadata_marks_experimental(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_vip(), tags::tag_experimental() | tags::tag_promo());
        registry::create_draft_admin_with_config(account, 33, config);

        let metadata = views::get_badge_metadata(tags::type_vip(), tags::tag_experimental() | tags::tag_promo());
        let primary_label_bytes = views::badge_metadata_primary_label(&metadata);
        assert!(primary_label_bytes == b"vip", 0);
        assert!(views::badge_metadata_is_experimental(&metadata), 0);
        assert!(
            views::badge_metadata_tags_mask(&metadata) == tags::tag_experimental() | tags::tag_promo(),
            0,
        );
    }

    // #[test(account = @lottery_multi)]
    fun status_overview_counts_vrf_and_statuses(account: &signer) {
        registry::init_registry(account);

        init_sales_draw_payouts(account);

        let draft_cfg_base = new_config(tags::type_basic(), 0);
        let draft_cfg = registry::config_with_run_id(&draft_cfg_base, 1);
        registry::create_draft_admin_with_config(account, 500, draft_cfg);

        let active_cfg_base = new_config(tags::type_partner(), tags::tag_daily());
        let active_cfg = registry::config_with_run_id(&active_cfg_base, 2);
        registry::create_draft_admin_with_config(account, 501, active_cfg);
        registry::advance_status(account, 501, types::status_active());

        let draw_cfg_base = new_config(tags::type_basic(), tags::tag_weekly());
        let draw_cfg = registry::config_with_run_id(&draw_cfg_base, 3);
        registry::create_draft_admin_with_config(account, 502, draw_cfg);
        registry::advance_status(account, 502, types::status_active());
        registry::advance_status(account, 502, types::status_closing());
        registry::mark_draw_requested(502);

        let numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0);
        draw::test_seed_vrf_state(
            502,
            numbers,
            b"0123456789abcdef0123456789abcdef",
            b"fedcba9876543210fedcba9876543210",
            10,
            1,
            1,
            123,
            5,
        );
        draw::test_override_vrf_state(
            502,
            types::vrf_status_requested(),
            false,
            600,
            1,
        );

        let overview = views::status_overview(100);
        assert!(views::status_overview_total(&overview) == 3, 0);
        assert!(views::status_overview_draft(&overview) == 1, 0);
        assert!(views::status_overview_active(&overview) == 1, 0);
        assert!(views::status_overview_draw_requested(&overview) == 1, 0);
        assert!(views::status_overview_vrf_requested(&overview) == 1, 0);
        assert!(views::status_overview_vrf_retry_blocked(&overview) == 1, 0);
        assert!(views::status_overview_vrf_fulfilled_pending(&overview) == 0, 0);
        assert!(views::status_overview_winners_pending(&overview) == 0, 0);
        assert!(views::status_overview_payout_backlog(&overview) == 0, 0);
        assert!(views::status_overview_refund_active(&overview) == 0, 0);
        assert!(views::status_overview_refund_batch_pending(&overview) == 0, 0);
        assert!(!views::status_overview_refund_sla_breach(&overview), 0);
    }

    // #[test(account = @lottery_multi, buyer = @0x1)]
    fun cancellation_and_refund_views(account: &signer, buyer: &signer) {
        registry::init_registry(account);

        init_sales_and_payouts(account);

        let config_base = new_config(tags::type_basic(), 0);
        let config = registry::config_with_run_id(&config_base, 60);
        registry::create_draft_admin_with_config(account, 610, config);
        registry::advance_status(account, 610, types::status_active());

        let no_cancel = views::get_cancellation(610);
        assert!(!option::is_some(&no_cancel), 0);

        let initial_progress = views::get_refund_progress(610);
        assert!(!sales::refund_view_active(&initial_progress), 0);
        assert!(sales::refund_view_tickets_refunded(&initial_progress) == 0, 0);

        sales::purchase_tickets_public(buyer, 610, 1, 20, 1);

        cancellation::cancel_lottery_admin(
            account,
            610,
            registry::cancel_reason_operations(),
            50,
        );

        let cancel_record_opt = views::get_cancellation(610);
        assert!(option::is_some(&cancel_record_opt), 0);
        let cancel_record = option::borrow(&cancel_record_opt);
        assert!(
            registry::cancellation_record_reason_code(cancel_record)
                == registry::cancel_reason_operations(),
            0,
        );
        assert!(
            registry::cancellation_record_previous_status(cancel_record)
                == types::status_active(),
            0,
        );
        assert!(registry::cancellation_record_tickets_sold(cancel_record) == 1, 0);
        assert!(registry::cancellation_record_proceeds_accum(cancel_record) == 100, 0);
        assert!(registry::cancellation_record_canceled_ts(cancel_record) == 50, 0);

        let progress_after_cancel = views::get_refund_progress(610);
        assert!(sales::refund_view_active(&progress_after_cancel), 0);
        assert!(sales::refund_view_refund_round(&progress_after_cancel) == 0, 0);
        assert!(sales::refund_view_tickets_refunded(&progress_after_cancel) == 0, 0);

        payouts::force_refund_batch_admin(account, 610, 1, 1, 100, 10, 70);

        let progress_after_refund = views::get_refund_progress(610);
        assert!(sales::refund_view_refund_round(&progress_after_refund) == 1, 0);
        assert!(sales::refund_view_tickets_refunded(&progress_after_refund) == 1, 0);
        assert!(sales::refund_view_prize_refunded(&progress_after_refund) == 100, 0);
        assert!(sales::refund_view_operations_refunded(&progress_after_refund) == 10, 0);
        assert!(sales::refund_view_last_refund_ts(&progress_after_refund) == 70, 0);
    }

    // #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun status_overview_tracks_refund_metrics(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        registry::init_registry(account);

        init_sales_and_payouts(account);

        let config_base = new_config(tags::type_basic(), 0);
        let config = registry::config_with_run_id(&config_base, 611);
        registry::create_draft_admin_with_config(account, 611, config);
        registry::advance_status(account, 611, types::status_active());

        sales::purchase_tickets_public(buyer1, 611, 1, 20, 1);
        sales::purchase_tickets_public(buyer2, 611, 1, 21, 1);

        cancellation::cancel_lottery_admin(
            account,
            611,
            registry::cancel_reason_operations(),
            50,
        );

        let initial_overview = views::status_overview(60);
        assert!(views::status_overview_refund_active(&initial_overview) == 1, 0);
        assert!(
            views::status_overview_refund_batch_pending(&initial_overview) == 2,
            0,
        );
        assert!(!views::status_overview_refund_sla_breach(&initial_overview), 0);

        let breach_overview = views::status_overview(50 + views::refund_first_batch_sla_secs() + 1);
        assert!(views::status_overview_refund_sla_breach(&breach_overview), 0);

        payouts::force_refund_batch_admin(
            account,
            611,
            1,
            1,
            70,
            30,
            50 + views::refund_first_batch_sla_secs() + 10,
        );

        let post_first_batch =
            views::status_overview(50 + views::refund_first_batch_sla_secs() + 20);
        assert!(views::status_overview_refund_active(&post_first_batch) == 1, 0);
        assert!(
            views::status_overview_refund_batch_pending(&post_first_batch) == 1,
            0,
        );
        assert!(!views::status_overview_refund_sla_breach(&post_first_batch), 0);

        let overdue_overview = views::status_overview(50 + views::refund_full_sla_secs() + 1);
        assert!(views::status_overview_refund_sla_breach(&overdue_overview), 0);

        payouts::force_refund_batch_admin(
            account,
            611,
            2,
            1,
            70,
            30,
            50 + views::refund_full_sla_secs() + 10,
        );

        let final_overview = views::status_overview(50 + views::refund_full_sla_secs() + 20);
        assert!(views::status_overview_refund_batch_pending(&final_overview) == 0, 0);
        assert!(!views::status_overview_refund_sla_breach(&final_overview), 0);
    }

    fun init_sales_draw_payouts(account: &signer) {
        sales::init_sales(account);
        draw::init_draw(account);
        payouts::init_payouts(account);
    }

    fun init_sales_and_payouts(account: &signer) {
        sales::init_sales(account);
        payouts::init_payouts(account);
    }

    fun new_config(primary_type: u8, tags_mask: u64): registry::Config {
        let prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(
                0,
                1,
                types::reward_from_sales_value(),
                b"",
            ),
        );
        registry::new_config_for_tests(
            EVENT_BYTES,
            SERIES_BYTES,
            0,
            1,
            primary_type,
            tags_mask,
            types::new_sales_window(10, 100),
            100,
            types::new_ticket_limits(100, 10),
            economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            true,
            types::draw_algo_without_replacement_value(),
            types::new_auto_close_policy(true, 60),
            types::new_reward_backend(types::backend_native_value(), b""),
            types::default_retry_policy(),
        )
    }
}








