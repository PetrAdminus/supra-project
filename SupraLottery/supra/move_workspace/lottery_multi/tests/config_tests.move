module lottery_multi::config_tests {
    use std::signer;
    use std::vector;

    use lottery_multi::economics;
    use lottery_multi::registry;
    use lottery_multi::roles;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    #[test(account = @lottery_multi)]
    fun create_basic_config(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::TYPE_BASIC, 0);
        registry::create_draft_admin(account, 1, config);
        let (primary, mask) = views::get_lottery_badges(1);
        assert!(primary == tags::TYPE_BASIC, 0);
        assert!(mask == 0, 0);
        let stored = views::get_lottery(1);
        assert!(stored.run_id == 0, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = lottery_multi::errors::E_TAG_PRIMARY_TYPE)]
    fun create_invalid_primary(account: &signer) {
        registry::init_registry(account);
        let config = new_config(42, 0);
        registry::create_draft_admin(account, 1, config);
    }

    #[test(account = @lottery_multi, partner = @0x42)]
    #[expected_failure(abort_code = lottery_multi::errors::E_TAG_MASK_NOT_ALLOWED)]
    fun partner_forbidden_tag(account: &signer, partner: &signer) {
        registry::init_registry(account);
        let mut allowed_types = vector::empty<u8>();
        vector::push_back(&mut allowed_types, tags::TYPE_PARTNER);
        let cap = roles::new_partner_cap(
            copy EVENT_BYTES,
            vector::singleton<vector<u8>>(copy SERIES_BYTES),
            allowed_types,
            tags::TAG_NFT,
            1,
            10,
            60,
        );
        let config = new_config(tags::TYPE_PARTNER, tags::TAG_PROMO);
        registry::create_draft_partner(partner, &cap, 1, config);
    }

    #[test(account = @lottery_multi)]
    fun list_active_only_returns_active(account: &signer) {
        registry::init_registry(account);
        let mut config = new_config(tags::TYPE_BASIC, 0);
        registry::create_draft_admin(account, 10, copy config);
        registry::advance_status(account, 10, registry::STATUS_ACTIVE);
        let mut other = new_config(tags::TYPE_BASIC, 0);
        other.run_id = 1;
        registry::create_draft_admin(account, 11, other);
        let active_ids = views::list_active(0, 10);
        assert!(vector::length(&active_ids) == 1, 0);
        assert!(*vector::borrow(&active_ids, 0) == 10, 0);
    }

    #[test(account = @lottery_multi)]
    fun basic_status_progression(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::TYPE_BASIC, 0);
        registry::create_draft_admin(account, 7, config);
        registry::advance_status(account, 7, registry::STATUS_ACTIVE);
        registry::advance_status(account, 7, registry::STATUS_CLOSING);
        let status = views::get_lottery_status(7);
        assert!(status.status == registry::STATUS_CLOSING, 0);
        assert!(status.snapshot_frozen, 0);
    }

    #[test(account = @lottery_multi)]
    fun list_by_tag_mask_orders_desc(account: &signer) {
        registry::init_registry(account);
        let mut config_a = new_config(tags::TYPE_BASIC, tags::TAG_DAILY);
        config_a.run_id = 1;
        registry::create_draft_admin(account, 1, config_a);

        let mut config_b = new_config(tags::TYPE_BASIC, tags::TAG_DAILY | tags::TAG_PROMO);
        config_b.run_id = 2;
        registry::create_draft_admin(account, 2, config_b);

        let mut config_c = new_config(tags::TYPE_BASIC, tags::TAG_WEEKLY);
        config_c.run_id = 3;
        registry::create_draft_admin(account, 3, config_c);

        let filtered = views::list_by_tag_mask(tags::TAG_DAILY, 0, 10);
        assert!(vector::length(&filtered) == 2, 0);
        assert!(*vector::borrow(&filtered, 0) == 2, 0);
        assert!(*vector::borrow(&filtered, 1) == 1, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = lottery_multi::errors::E_TAGS_LOCKED)]
    fun cannot_update_tags_after_snapshot(account: &signer) {
        registry::init_registry(account);
        let mut config = new_config(tags::TYPE_BASIC, tags::TAG_DAILY);
        registry::create_draft_admin(account, 20, copy config);
        registry::advance_status(account, 20, registry::STATUS_ACTIVE);
        registry::set_tags_mask(account, 20, tags::TAG_DAILY | tags::TAG_PROMO);
        registry::advance_status(account, 20, registry::STATUS_CLOSING);
        registry::set_tags_mask(account, 20, tags::TAG_WEEKLY);
    }

    fun new_config(primary_type: u8, tags_mask: u64): registry::Config {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(0, 1, types::REWARD_FROM_SALES, b""),
        );
        registry::Config {
            event_slug: copy EVENT_BYTES,
            series_code: copy SERIES_BYTES,
            run_id: 0,
            config_version: 1,
            primary_type,
            tags_mask,
            sales_window: types::new_sales_window(10, 100),
            ticket_price: 100,
            ticket_limits: types::new_ticket_limits(100, 10),
            sales_distribution: economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            winners_dedup: true,
            draw_algo: types::DRAW_ALGO_WITHOUT_REPLACEMENT,
            auto_close_policy: types::new_auto_close_policy(true, 60),
            reward_backend: types::new_reward_backend(types::BACKEND_NATIVE, b""),
        }
    }
}
