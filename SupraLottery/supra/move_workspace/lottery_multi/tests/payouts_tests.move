module lottery_multi::payouts_tests {
    use std::hash;
    use std::signer;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::payouts;
    use lottery_multi::registry;
    use lottery_multi::roles;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun record_batch_updates_accounting(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 100);

        payouts::record_payout_batch_admin(account, 100, 1, 2, 140, 10, 30);

        let accounting = sales::accounting_snapshot(100);
        assert!(accounting.total_sales == 200, 0);
        assert!(accounting.total_allocated == 150, 0);
        assert!(accounting.total_prize_paid == 140, 0);
        assert!(accounting.total_operations_paid == 10, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun partner_payout_updates_operations(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 200);

        roles::upsert_partner_payout_cap_admin(
            account,
            @0x99,
            roles::new_partner_payout_cap(@0x99, 50, 0, 1),
        );

        payouts::record_payout_batch_admin(account, 200, 1, 2, 140, 5, 40);
        payouts::record_partner_payout_admin(account, 200, @0x99, 5, 1, 45);

        let accounting = sales::accounting_snapshot(200);
        assert!(accounting.total_operations_paid == 10, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_OPERATIONS_ALLOC_EXCEEDED)]
    fun partner_payout_respects_operations_cap(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 201);

        roles::upsert_partner_payout_cap_admin(
            account,
            @0x77,
            roles::new_partner_payout_cap(@0x77, 100, 0, 1),
        );

        payouts::record_payout_batch_admin(account, 201, 1, 2, 140, 15, 50);
        payouts::record_partner_payout_admin(account, 201, @0x77, 10, 1, 60);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_CAP_MISSING)]
    fun partner_payout_requires_cap(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 202);

        payouts::record_payout_batch_admin(account, 202, 1, 2, 100, 5, 10);
        payouts::record_partner_payout_admin(account, 202, @0x55, 5, 1, 20);
    }

    fun setup_modules(account: &signer) {
        registry::init_registry(account);
        sales::init_sales(account);
        draw::init_draw(account);
        payouts::init_payouts(account);
        roles::init_roles(account);
        roles::set_payout_batch_cap_admin(
            account,
            roles::new_payout_batch_cap(@lottery_multi, 128, 1_000, 0, 1),
        );
    }

    fun prepare_for_payout(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        lottery_id: u64,
    ) {
        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);
        sales::purchase_tickets_public(buyer2, lottery_id, 1, 22, 2);
        registry::advance_status(account, lottery_id, registry::STATUS_CLOSING);
        registry::mark_draw_requested(lottery_id);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(lottery_id);
        let mut numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x0102030405060708u256);
        let payload_hash = hash::sha3_256(b"payload-payout-tests");
        draw::test_seed_vrf_state(
            lottery_id,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            88,
            1,
        );
        registry::mark_drawn(lottery_id);
        payouts::compute_winners_admin(account, lottery_id, 10);
        registry::mark_payout(lottery_id);
    }

    fun new_config(): registry::Config {
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
            primary_type: tags::TYPE_BASIC,
            tags_mask: 0,
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
