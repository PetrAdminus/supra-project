module lottery_multi::sales_tests {
    use std::vector;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::lottery_registry as registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    // #[test(account = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_PURCHASE_RATE_LIMIT_BLOCK)]
    fun block_rate_limit_triggers(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 301;
        registry::create_draft_admin_with_config(account, lottery_id, base_config());
        registry::advance_status(account, lottery_id, types::status_active());

        let i = 0u64;
        while (i < 64) {
            sales::purchase_tickets_public(buyer, lottery_id, 1, 20 + i * 61, 1);
            i = i + 1;
        };

        sales::purchase_tickets_public(buyer, lottery_id, 1, 20 + 64 * 61, 1);
    }

    // #[test(account = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_PURCHASE_RATE_LIMIT_WINDOW)]
    fun window_rate_limit_triggers(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 302;
        registry::create_draft_admin_with_config(account, lottery_id, base_config());
        registry::advance_status(account, lottery_id, types::status_active());

        let i = 0u64;
        while (i < 10) {
            sales::purchase_tickets_public(buyer, lottery_id, 1, 40, 2);
            i = i + 1;
        };

        sales::purchase_tickets_public(buyer, lottery_id, 1, 40, 2);
    }

    // #[test(account = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_PURCHASE_GRACE_RESTRICTED)]
    fun grace_window_blocks_first_purchase(
        account: &signer,
        buyer: &signer,
    ) {
        setup(account);
        let lottery_id = 303;
        let base = base_config();
        let config =
            registry::config_with_sales_window(&base, types::new_sales_window(10, 120));
        registry::create_draft_admin_with_config(account, lottery_id, config);
        registry::advance_status(account, lottery_id, types::status_active());

        sales::purchase_tickets_public(buyer, lottery_id, 1, 111, 3);
    }

    fun setup(account: &signer) {
        registry::init_registry(account);
        sales::init_sales(account);
    }

    fun base_config(): registry::Config {
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
            b"lottery",
            b"limit",
            0,
            1,
            tags::type_basic(),
            0,
            types::new_sales_window(10, 10_000),
            100,
            types::new_ticket_limits(10_000, 0),
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








