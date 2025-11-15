module lottery_multi::config_tests {
    use std::option;
    use std::vector;

    use lottery_multi::cancellation;
    use lottery_multi::economics;
    use lottery_multi::lottery_registry as registry;
    use lottery_multi::roles;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    // #[test(account = @lottery_multi)]
    fun create_basic_config(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), 0);
        registry::create_draft_admin_with_config(account, 1, config);
        let (primary, mask) = views::get_lottery_badges(1);
        assert!(primary == tags::type_basic(), 0);
        assert!(mask == 0, 0);
        let stored = views::get_lottery(1);
        assert!(registry::config_run_id(&stored) == 0, 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = lottery_multi::errors::E_TAG_PRIMARY_TYPE)]
    fun create_invalid_primary(account: &signer) {
        registry::init_registry(account);
        let config = new_config(42, 0);
        registry::create_draft_admin_with_config(account, 1, config);
    }

    // #[test(account = @lottery_multi, partner = @0x42)]
    // // #[expected_failure(abort_code = lottery_multi::errors::E_TAG_MASK_NOT_ALLOWED)]
    fun partner_forbidden_tag(account: &signer, partner: &signer) {
        registry::init_registry(account);
        let allowed_types = vector::empty<u8>();
        vector::push_back(&mut allowed_types, tags::type_partner());
        let cap = roles::new_partner_cap(
            EVENT_BYTES,
            vector::singleton<vector<u8>>(SERIES_BYTES),
            allowed_types,
            tags::tag_nft(),
            1,
            10,
            60,
        );
        let config = new_config(tags::type_partner(), tags::tag_promo());
        registry::create_draft_partner_with_config(partner, &cap, 1, config);
    }

    // #[test(account = @lottery_multi)]
    fun list_active_only_returns_active(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), 0);
        registry::create_draft_admin_with_config(account, 10, config);
        registry::advance_status(account, 10, types::status_active());
        let other_base = new_config(tags::type_basic(), 0);
        let other = registry::config_with_run_id(&other_base, 1);
        registry::create_draft_admin_with_config(account, 11, other);
        let active_ids = views::list_active(0, 10);
        assert!(vector::length(&active_ids) == 1, 0);
        assert!(*vector::borrow(&active_ids, 0) == 10, 0);
    }

    // #[test(account = @lottery_multi)]
    fun basic_status_progression(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), 0);
        registry::create_draft_admin_with_config(account, 7, config);
        registry::advance_status(account, 7, types::status_active());
        registry::advance_status(account, 7, types::status_closing());
        let status = views::get_lottery_status(7);
        assert!(views::lottery_status_status(&status) == types::status_closing(), 0);
        assert!(views::lottery_status_snapshot_frozen(&status), 0);
    }

    // #[test(account = @lottery_multi)]
    fun list_by_tag_mask_orders_desc(account: &signer) {
        registry::init_registry(account);
        let config_a_base = new_config(tags::type_basic(), tags::tag_daily());
        let config_a = registry::config_with_run_id(&config_a_base, 1);
        registry::create_draft_admin_with_config(account, 1, config_a);

        let config_b_base =
            new_config(tags::type_basic(), tags::tag_daily() | tags::tag_promo());
        let config_b = registry::config_with_run_id(&config_b_base, 2);
        registry::create_draft_admin_with_config(account, 2, config_b);

        let config_c_base = new_config(tags::type_basic(), tags::tag_weekly());
        let config_c = registry::config_with_run_id(&config_c_base, 3);
        registry::create_draft_admin_with_config(account, 3, config_c);

        let filtered = views::list_by_tag_mask(tags::tag_daily(), 0, 10);
        assert!(vector::length(&filtered) == 2, 0);
        assert!(*vector::borrow(&filtered, 0) == 2, 0);
        assert!(*vector::borrow(&filtered, 1) == 1, 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = lottery_multi::errors::E_TAGS_LOCKED)]
    fun cannot_update_tags_after_snapshot(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), tags::tag_daily());
        registry::create_draft_admin_with_config(account, 20, config);
        registry::advance_status(account, 20, types::status_active());
        registry::set_tags_mask(account, 20, tags::tag_daily() | tags::tag_promo());
        registry::advance_status(account, 20, types::status_closing());
        registry::set_tags_mask(account, 20, tags::tag_weekly());
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = lottery_multi::errors::E_CANCEL_REASON_INVALID)]
    fun cancel_requires_reason(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), 0);
        registry::create_draft_admin_with_config(account, 30, config);
        cancellation::cancel_lottery_admin(account, 30, 0, 0);
    }

    // #[test(account = @lottery_multi)]
    fun cancel_records_reason(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::type_basic(), 0);
        registry::create_draft_admin_with_config(account, 31, config);
        registry::advance_status(account, 31, types::status_active());
        let canceled_at = 1_234u64;
        cancellation::cancel_lottery_admin(
            account,
            31,
            registry::cancel_reason_vrf_failure(),
            canceled_at,
        );
        let status = views::get_lottery_status(31);
        assert!(views::lottery_status_status(&status) == types::status_canceled(), 0);
        assert!(views::lottery_status_snapshot_frozen(&status), 0);
        let info_opt = registry::get_cancellation_record(31);
        assert!(option::is_some(&info_opt), 0);
        let info = option::destroy_some(info_opt);
        assert!(
            registry::cancellation_record_reason_code(&info)
                == registry::cancel_reason_vrf_failure(),
            0,
        );
        assert!(
            registry::cancellation_record_previous_status(&info) == types::status_active(),
            0,
        );
        assert!(registry::cancellation_record_canceled_ts(&info) == canceled_at, 0);
        assert!(registry::cancellation_record_tickets_sold(&info) == 0, 0);
        assert!(registry::cancellation_record_proceeds_accum(&info) == 0, 0);
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








