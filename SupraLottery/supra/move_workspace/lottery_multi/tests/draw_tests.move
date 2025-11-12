module lottery_multi::draw_tests {
    use std::hash;
    use std::signer;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;
    use lottery_multi::vrf_deposit;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    #[test(admin = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_VRF_REQUESTS_PAUSED)]
    fun request_rejected_when_deposit_paused(admin: &signer) {
        vrf_deposit::init_vrf_deposit(admin, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(admin, 2_000, 1_500, 1_000, 200);
        draw::init_draw(admin);
        draw::request_draw_admin(admin, 1, 300, 42, 1, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_VRF_PENDING)]
    fun request_fails_while_pending(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 500, 30);

        draw::request_draw_admin(admin, 500, 600, 42, 1, 0);
        draw::request_draw_admin(admin, 500, 610, 43, 1, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_VRF_RETRY_WINDOW)]
    fun request_respects_retry_window(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 501, 40);

        let now_ts = 700;
        draw::request_draw_admin(admin, 501, now_ts, 90, 2, 0);
        draw::test_override_vrf_state(501, types::VRF_STATUS_FULFILLED, true, now_ts + 600, 1);

        draw::request_draw_admin(admin, 501, now_ts + 500, 91, 2, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_VRF_ATTEMPT_OUT_OF_ORDER)]
    fun request_prevents_attempt_overflow(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 502, 50);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(502);
        let mut numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x01u256);
        let payload_hash = hash::sha3_256(b"draw-attempt-overflow");

        draw::test_seed_vrf_state(
            502,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::DEFAULT_SCHEMA_VERSION,
            255,
            77,
            1,
        );

        let _ = draw::prepare_for_winner_computation(502);

        draw::request_draw_admin(admin, 502, 1_200, 120, 1, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_updates_finalization_snapshot(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 503, 60);

        let (snapshot_hash, _, _) = sales::snapshot_for_draw(503);
        let now_ts = 1_300;
        let closing_block = 555;
        let chain_id = 4;
        draw::request_draw_admin(admin, 503, now_ts, closing_block, chain_id, 0);

        let info = draw::finalization_snapshot(503);
        assert!(info.snapshot_hash == snapshot_hash, 0);
        assert!(info.closing_block_height == closing_block, 0);
        assert!(info.chain_id == chain_id, 0);
        assert!(info.attempt == 1, 0);
        assert!(info.vrf_status == types::VRF_STATUS_REQUESTED, 0);
        assert!(info.request_ts == now_ts, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_cancels_after_attempt_limit(admin: &signer, buyer: &signer) {
        let lottery_id = 504;
        setup_lottery(admin, buyer, lottery_id, 70);

        let max_attempts = draw::max_vrf_attempts() as u64;
        let mut idx = 0u64;
        while (idx < max_attempts) {
            let now_ts = 1_400 + idx * 30;
            draw::request_draw_admin(admin, lottery_id, now_ts, 600 + idx, 1, 0);
            let snapshot = draw::finalization_snapshot(lottery_id);
            let attempt = snapshot.attempt;
            assert!((attempt as u64) == idx + 1, 0);
            if (idx + 1 < max_attempts) {
                draw::test_override_vrf_state(
                    lottery_id,
                    types::VRF_STATUS_IDLE,
                    true,
                    0,
                    attempt,
                );
            };
            idx = idx + 1;
        };

        draw::request_draw_admin(admin, lottery_id, 1_400 + max_attempts * 30, 800 + max_attempts, 1, 0);
        let status = views::get_lottery_status(lottery_id);
        assert!(status.status == registry::STATUS_CANCELED, 0);
        let refund = views::get_refund_progress(lottery_id);
        assert!(refund.active, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_uses_exponential_policy(admin: &signer, buyer: &signer) {
        let lottery_id = 505;
        let policy = types::new_retry_policy(types::RETRY_STRATEGY_EXPONENTIAL, 300, 1_800);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 80, config);

        let mut now_ts = 900;
        draw::request_draw_admin(admin, lottery_id, now_ts, 610, 1, 0);
        let first_view = draw::vrf_state_view(lottery_id);
        assert!(first_view.attempt == 1, 0);
        assert!(first_view.retry_strategy == types::RETRY_STRATEGY_EXPONENTIAL, 0);
        assert!(first_view.retry_after_ts == now_ts + 300, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::VRF_STATUS_IDLE,
            true,
            now_ts + 300,
            first_view.attempt,
        );
        now_ts = now_ts + 300;
        draw::request_draw_admin(admin, lottery_id, now_ts, 611, 1, 0);
        let second_view = draw::vrf_state_view(lottery_id);
        assert!(second_view.attempt == 2, 0);
        assert!(second_view.retry_after_ts == now_ts + 600, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::VRF_STATUS_IDLE,
            true,
            now_ts + 600,
            second_view.attempt,
        );
        now_ts = now_ts + 600;
        draw::request_draw_admin(admin, lottery_id, now_ts, 612, 1, 0);
        let third_view = draw::vrf_state_view(lottery_id);
        assert!(third_view.attempt == 3, 0);
        assert!(third_view.retry_after_ts == now_ts + 1_200, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::VRF_STATUS_IDLE,
            true,
            now_ts + 1_200,
            third_view.attempt,
        );
        now_ts = now_ts + 1_200;
        draw::request_draw_admin(admin, lottery_id, now_ts, 613, 1, 0);
        let fourth_view = draw::vrf_state_view(lottery_id);
        assert!(fourth_view.attempt == 4, 0);
        assert!(fourth_view.retry_after_ts == now_ts + 1_800, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    #[expected_failure(abort_code = errors::E_VRF_MANUAL_SCHEDULE_REQUIRED)]
    fun manual_policy_requires_schedule(admin: &signer, buyer: &signer) {
        let lottery_id = 506;
        let policy = types::new_retry_policy(types::RETRY_STRATEGY_MANUAL, 0, 0);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 90, config);

        let now_ts = 2_000;
        draw::request_draw_admin(admin, lottery_id, now_ts, 700, 1, 0);
        let state = draw::vrf_state_view(lottery_id);
        assert!(state.retry_strategy == types::RETRY_STRATEGY_MANUAL, 0);
        draw::test_override_vrf_state(
            lottery_id,
            types::VRF_STATUS_IDLE,
            true,
            0,
            state.attempt,
        );

        draw::request_draw_admin(admin, lottery_id, now_ts + 10, 701, 1, 0);
    }

    #[test(admin = @lottery_multi, buyer = @0x1)]
    fun manual_policy_allows_scheduled_retry(admin: &signer, buyer: &signer) {
        let lottery_id = 507;
        let policy = types::new_retry_policy(types::RETRY_STRATEGY_MANUAL, 0, 0);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 100, config);

        let mut now_ts = 2_100;
        draw::request_draw_admin(admin, lottery_id, now_ts, 720, 1, 0);
        let first = draw::vrf_state_view(lottery_id);
        draw::test_override_vrf_state(
            lottery_id,
            types::VRF_STATUS_IDLE,
            true,
            0,
            first.attempt,
        );

        let schedule_now = now_ts + 60;
        let retry_deadline = schedule_now + 45;
        draw::schedule_manual_retry_admin(admin, lottery_id, schedule_now, retry_deadline);

        now_ts = retry_deadline;
        draw::request_draw_admin(admin, lottery_id, now_ts, 721, 1, 0);
        let second = draw::vrf_state_view(lottery_id);
        assert!(second.attempt == 2, 0);
        assert!(second.retry_strategy == types::RETRY_STRATEGY_MANUAL, 0);
        assert!(second.retry_after_ts == 0, 0);
    }

    fun setup_lottery(admin: &signer, buyer: &signer, lottery_id: u64, purchase_ts: u64) {
        let config = new_config();
        setup_lottery_with_config(admin, buyer, lottery_id, purchase_ts, config);
    }

    fun setup_lottery_with_config(
        admin: &signer,
        buyer: &signer,
        lottery_id: u64,
        purchase_ts: u64,
        config: registry::Config,
    ) {
        registry::init_registry(admin);
        sales::init_sales(admin);
        draw::init_draw(admin);

        registry::create_draft_admin(admin, lottery_id, copy config);
        registry::advance_status(admin, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer, lottery_id, 2, purchase_ts, 1);
        registry::advance_status(admin, lottery_id, registry::STATUS_CLOSING);
    }

    fun new_config(): registry::Config {
        new_config_with_policy(types::default_retry_policy())
    }

    fun new_config_with_policy(policy: types::RetryPolicy): registry::Config {
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
            vrf_retry_policy: policy,
        }
    }
}
