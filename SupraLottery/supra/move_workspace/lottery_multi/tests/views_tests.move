module lottery_multi::views_tests {
    use std::signer;
    use std::string;
    use std::vector;

    use lottery_multi::economics;
    use lottery_multi::registry;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    #[test(account = @lottery_multi)]
    fun list_by_all_tags_requires_full_mask(account: &signer) {
        registry::init_registry(account);

        let mut config_a = new_config(tags::TYPE_BASIC, tags::TAG_DAILY | tags::TAG_PROMO);
        config_a.run_id = 10;
        registry::create_draft_admin(account, 1, config_a);

        let mut config_b = new_config(tags::TYPE_BASIC, tags::TAG_DAILY);
        config_b.run_id = 11;
        registry::create_draft_admin(account, 2, config_b);

        let filtered = views::list_by_all_tags(tags::TAG_DAILY | tags::TAG_PROMO, 0, 10);
        assert!(vector::length(&filtered) == 1, 0);
        assert!(*vector::borrow(&filtered, 0) == 1, 0);
    }

    #[test(account = @lottery_multi)]
    fun list_by_primary_type_returns_descending(account: &signer) {
        registry::init_registry(account);

        let mut config_basic = new_config(tags::TYPE_BASIC, 0);
        config_basic.run_id = 1;
        registry::create_draft_admin(account, 20, config_basic);

        let mut config_partner_a = new_config(tags::TYPE_PARTNER, tags::TAG_WEEKLY);
        config_partner_a.run_id = 2;
        registry::create_draft_admin(account, 21, config_partner_a);

        let mut config_partner_b = new_config(tags::TYPE_PARTNER, tags::TAG_PROMO);
        config_partner_b.run_id = 3;
        registry::create_draft_admin(account, 22, config_partner_b);

        let partners = views::list_by_primary_type(tags::TYPE_PARTNER, 0, 10);
        assert!(vector::length(&partners) == 2, 0);
        assert!(*vector::borrow(&partners, 0) == 22, 0);
        assert!(*vector::borrow(&partners, 1) == 21, 0);

        let partners_paginated = views::list_by_primary_type(tags::TYPE_PARTNER, 1, 1);
        assert!(vector::length(&partners_paginated) == 1, 0);
        assert!(*vector::borrow(&partners_paginated, 0) == 21, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = lottery_multi::errors::E_PAGINATION_LIMIT)]
    fun list_active_rejects_large_limit(account: &signer) {
        registry::init_registry(account);
        views::list_active(0, 1001);
    }

    #[test(account = @lottery_multi)]
    fun badge_metadata_marks_experimental(account: &signer) {
        registry::init_registry(account);
        let config = new_config(tags::TYPE_VIP, tags::TAG_EXPERIMENTAL | tags::TAG_PROMO);
        registry::create_draft_admin(account, 33, config);

        let metadata = views::get_badge_metadata(tags::TYPE_VIP, tags::TAG_EXPERIMENTAL | tags::TAG_PROMO);
        let expected_label = string::utf8(b"vip");
        assert!(string::eq(&metadata.primary_label, &expected_label), 0);
        assert!(metadata.is_experimental, 0);
        assert!(metadata.tags_mask == tags::TAG_EXPERIMENTAL | tags::TAG_PROMO, 0);
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
