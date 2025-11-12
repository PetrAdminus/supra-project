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

    fun setup_lottery(admin: &signer, buyer: &signer, lottery_id: u64, purchase_ts: u64) {
        registry::init_registry(admin);
        sales::init_sales(admin);
        draw::init_draw(admin);

        let config = new_config();
        registry::create_draft_admin(admin, lottery_id, copy config);
        registry::advance_status(admin, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer, lottery_id, 2, purchase_ts, 1);
        registry::advance_status(admin, lottery_id, registry::STATUS_CLOSING);
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
