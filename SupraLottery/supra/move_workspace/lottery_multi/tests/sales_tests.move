module lottery_multi::sales_tests {
    use std::vector;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    #[test(account = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_PURCHASE_RATE_LIMIT_BLOCK)]
    fun block_rate_limit_triggers(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 301;
        registry::create_draft_admin(account, lottery_id, base_config());
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);

        let mut i = 0u64;
        while (i < 64) {
            sales::purchase_tickets_public(buyer, lottery_id, 1, 20 + i * 61, 1);
            i = i + 1;
        };

        sales::purchase_tickets_public(buyer, lottery_id, 1, 20 + 64 * 61, 1);
    }

    #[test(account = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_PURCHASE_RATE_LIMIT_WINDOW)]
    fun window_rate_limit_triggers(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 302;
        registry::create_draft_admin(account, lottery_id, base_config());
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);

        let mut i = 0u64;
        while (i < 10) {
            sales::purchase_tickets_public(buyer, lottery_id, 1, 40, 2);
            i = i + 1;
        };

        sales::purchase_tickets_public(buyer, lottery_id, 1, 40, 2);
    }

    #[test(account = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_PURCHASE_GRACE_RESTRICTED)]
    fun grace_window_blocks_first_purchase(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 303;
        let mut config = base_config();
        config.sales_window = types::new_sales_window(10, 120);
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);

        sales::purchase_tickets_public(buyer, lottery_id, 1, 111, 3);
    }

    fun setup(account: &signer) {
        registry::init_registry(account);
        sales::init_sales(account);
    }

    fun base_config(): registry::Config {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(0, 1, types::REWARD_FROM_SALES, b""),
        );
        registry::Config {
            event_slug: b"lottery",
            series_code: b"limit",
            run_id: 0,
            config_version: 1,
            primary_type: tags::TYPE_BASIC,
            tags_mask: 0,
            sales_window: types::new_sales_window(10, 10_000),
            ticket_price: 100,
            ticket_limits: types::new_ticket_limits(10_000, 0),
            sales_distribution: economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            winners_dedup: true,
            draw_algo: types::DRAW_ALGO_WITHOUT_REPLACEMENT,
            auto_close_policy: types::new_auto_close_policy(true, 60),
            reward_backend: types::new_reward_backend(types::BACKEND_NATIVE, b""),
        }
    }
}
