module lottery_multi::draw_tests {
    use std::hash;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::math;
    use lottery_multi::lottery_registry as registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;
    use lottery_multi::vrf_deposit;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";

    // #[test(admin = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_VRF_REQUESTS_PAUSED)]
    fun request_rejected_when_deposit_paused(admin: &signer) {

        vrf_deposit::init_vrf_deposit(admin, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(admin, 2_000, 1_500, 1_000, 200);

        draw::init_draw(admin);
        draw::request_draw_admin(admin, 1, 300, 42, 1, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_VRF_PENDING)]
    fun request_fails_while_pending(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 500, 30);

        draw::request_draw_admin(admin, 500, 600, 42, 1, 0);
        draw::request_draw_admin(admin, 500, 610, 43, 1, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_VRF_RETRY_WINDOW)]
    fun request_respects_retry_window(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 501, 40);

        let now_ts = 700;
        draw::request_draw_admin(admin, 501, now_ts, 90, 2, 0);
        draw::test_override_vrf_state(501, types::vrf_status_fulfilled(), true, now_ts + 600, 1);

        draw::request_draw_admin(admin, 501, now_ts + 500, 91, 2, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_VRF_ATTEMPT_OUT_OF_ORDER)]
    fun request_prevents_attempt_overflow(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 502, 50);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(502);
        let numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x01u256);
        let payload_hash = hash::sha3_256(b"draw-attempt-overflow");

        draw::test_seed_vrf_state(
            502,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::vrf_default_schema_version(),
            255,
            77,
            1,
        );

        draw::prepare_for_winner_computation(502);

        draw::request_draw_admin(admin, 502, 1_200, 120, 1, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_updates_finalization_snapshot(admin: &signer, buyer: &signer) {
        setup_lottery(admin, buyer, 503, 60);

        let (snapshot_hash, _, _) = sales::snapshot_for_draw(503);
        let now_ts = 1_300;
        let closing_block = 555;
        let chain_id = 4;
        draw::request_draw_admin(admin, 503, now_ts, closing_block, chain_id, 0);

        let info = draw::finalization_snapshot(503);
        assert!(
            draw::finalization_snapshot_snapshot_hash(&info) == snapshot_hash,
            0,
        );
        assert!(
            draw::finalization_snapshot_closing_block(&info) == closing_block,
            0,
        );
        assert!(draw::finalization_snapshot_chain_id(&info) == chain_id, 0);
        assert!(draw::finalization_snapshot_attempt(&info) == 1, 0);
        assert!(
            draw::finalization_snapshot_vrf_status(&info) == types::vrf_status_requested(),
            0,
        );
        assert!(draw::finalization_snapshot_request_ts(&info) == now_ts, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_cancels_after_attempt_limit(admin: &signer, buyer: &signer) {
        let lottery_id = 504;
        setup_lottery(admin, buyer, lottery_id, 70);

        let max_attempts = math::widen_u64_from_u8(draw::max_vrf_attempts());
        let idx = 0u64;
        while (idx < max_attempts) {
            let now_ts = 1_400 + idx * 30;
            draw::request_draw_admin(admin, lottery_id, now_ts, 600 + idx, 1, 0);
            let snapshot = draw::finalization_snapshot(lottery_id);
            let attempt = draw::finalization_snapshot_attempt(&snapshot);
            assert!(math::widen_u64_from_u8(attempt) == idx + 1, 0);
            if (idx + 1 < max_attempts) {
                draw::test_override_vrf_state(
                    lottery_id,
                    types::vrf_status_idle(),
                    true,
                    0,
                    attempt,
                );
            };
            idx = idx + 1;
        };

        draw::request_draw_admin(admin, lottery_id, 1_400 + max_attempts * 30, 800 + max_attempts, 1, 0);
        let status = views::get_lottery_status(lottery_id);
        assert!(views::lottery_status_status(&status) == types::status_canceled(), 0);
        let refund = views::get_refund_progress(lottery_id);
        assert!(sales::refund_view_active(&refund), 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    fun request_uses_exponential_policy(admin: &signer, buyer: &signer) {
        let lottery_id = 505;
        let policy = types::new_retry_policy(types::retry_strategy_exponential(), 300, 1_800);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 80, config);

        let now_ts = 900;
        draw::request_draw_admin(admin, lottery_id, now_ts, 610, 1, 0);
        let first_view = draw::vrf_state_view(lottery_id);
        assert!(draw::vrf_state_view_attempt(&first_view) == 1, 0);
        assert!(
            draw::vrf_state_view_retry_strategy(&first_view) == types::retry_strategy_exponential(),
            0,
        );
        assert!(draw::vrf_state_view_retry_after_ts(&first_view) == now_ts + 300, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::vrf_status_idle(),
            true,
            now_ts + 300,
            draw::vrf_state_view_attempt(&first_view),
        );
        now_ts = now_ts + 300;
        draw::request_draw_admin(admin, lottery_id, now_ts, 611, 1, 0);
        let second_view = draw::vrf_state_view(lottery_id);
        assert!(draw::vrf_state_view_attempt(&second_view) == 2, 0);
        assert!(draw::vrf_state_view_retry_after_ts(&second_view) == now_ts + 600, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::vrf_status_idle(),
            true,
            now_ts + 600,
            draw::vrf_state_view_attempt(&second_view),
        );
        now_ts = now_ts + 600;
        draw::request_draw_admin(admin, lottery_id, now_ts, 612, 1, 0);
        let third_view = draw::vrf_state_view(lottery_id);
        assert!(draw::vrf_state_view_attempt(&third_view) == 3, 0);
        assert!(draw::vrf_state_view_retry_after_ts(&third_view) == now_ts + 1_200, 0);

        draw::test_override_vrf_state(
            lottery_id,
            types::vrf_status_idle(),
            true,
            now_ts + 1_200,
            draw::vrf_state_view_attempt(&third_view),
        );
        now_ts = now_ts + 1_200;
        draw::request_draw_admin(admin, lottery_id, now_ts, 613, 1, 0);
        let fourth_view = draw::vrf_state_view(lottery_id);
        assert!(draw::vrf_state_view_attempt(&fourth_view) == 4, 0);
        assert!(draw::vrf_state_view_retry_after_ts(&fourth_view) == now_ts + 1_800, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    // // #[expected_failure(abort_code = errors::E_VRF_MANUAL_SCHEDULE_REQUIRED)]
    fun manual_policy_requires_schedule(admin: &signer, buyer: &signer) {
        let lottery_id = 506;
        let policy = types::new_retry_policy(types::retry_strategy_manual(), 0, 0);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 90, config);

        let now_ts = 2_000;
        draw::request_draw_admin(admin, lottery_id, now_ts, 700, 1, 0);
        let state = draw::vrf_state_view(lottery_id);
        assert!(
            draw::vrf_state_view_retry_strategy(&state) == types::retry_strategy_manual(),
            0,
        );
        draw::test_override_vrf_state(
            lottery_id,
            types::vrf_status_idle(),
            true,
            0,
            draw::vrf_state_view_attempt(&state),
        );

        draw::request_draw_admin(admin, lottery_id, now_ts + 10, 701, 1, 0);
    }

    // #[test(admin = @lottery_multi, buyer = @0x1)]
    fun manual_policy_allows_scheduled_retry(admin: &signer, buyer: &signer) {
        let lottery_id = 507;
        let policy = types::new_retry_policy(types::retry_strategy_manual(), 0, 0);
        let config = new_config_with_policy(policy);
        setup_lottery_with_config(admin, buyer, lottery_id, 100, config);

        let now_ts = 2_100;
        draw::request_draw_admin(admin, lottery_id, now_ts, 720, 1, 0);
        let first = draw::vrf_state_view(lottery_id);
        draw::test_override_vrf_state(
            lottery_id,
            types::vrf_status_idle(),
            true,
            0,
            draw::vrf_state_view_attempt(&first),
        );

        let schedule_now = now_ts + 60;
        let retry_deadline = schedule_now + 45;
        draw::schedule_manual_retry_admin(admin, lottery_id, schedule_now, retry_deadline);

        now_ts = retry_deadline;
        draw::request_draw_admin(admin, lottery_id, now_ts, 721, 1, 0);
        let second = draw::vrf_state_view(lottery_id);
        assert!(draw::vrf_state_view_attempt(&second) == 2, 0);
        assert!(
            draw::vrf_state_view_retry_strategy(&second) == types::retry_strategy_manual(),
            0,
        );
        assert!(draw::vrf_state_view_retry_after_ts(&second) == 0, 0);
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

        registry::create_draft_admin_with_config(admin, lottery_id, copy config);
        registry::advance_status(admin, lottery_id, types::status_active());
        sales::purchase_tickets_public(buyer, lottery_id, 2, purchase_ts, 1);
        registry::advance_status(admin, lottery_id, types::status_closing());
    }

    fun new_config(): registry::Config {
        new_config_with_policy(types::default_retry_policy())
    }

    fun new_config_with_policy(policy: types::RetryPolicy): registry::Config {
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
            tags::type_basic(),
            0,
            types::new_sales_window(10, 100),
            100,
            types::new_ticket_limits(100, 10),
            economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            true,
            types::draw_algo_without_replacement_value(),
            types::new_auto_close_policy(true, 60),
            types::new_reward_backend(types::backend_native_value(), b""),
            policy,
        )
    }
}








