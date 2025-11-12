module lottery_multi::payouts_tests {
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::payouts;
    use lottery_multi::registry;
    use lottery_multi::roles;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::views;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";
    const MULTI_SERIES_BYTES: vector<u8> = b"multi";

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
            roles::new_partner_payout_cap(@0x99, 50, 0, 1, 0),
        );

        payouts::record_payout_batch_admin(account, 200, 1, 2, 140, 5, 40);
        payouts::record_partner_payout_admin(account, 200, @0x99, 5, 1, 45);

        let accounting = sales::accounting_snapshot(200);
        assert!(accounting.total_operations_paid == 10, 0);

        let cap = roles::borrow_partner_payout_cap_mut(@0x99);
        assert!(cap.remaining_payout == 45, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    fun refund_batch_records_progress(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let lottery_id = 301;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);

        registry::cancel_lottery_admin(
            account,
            lottery_id,
            registry::CANCEL_REASON_OPERATIONS,
            30,
        );

        let before = sales::refund_progress(lottery_id);
        assert!(before.active, 0);
        assert!(before.refund_round == 0, 0);

        payouts::force_refund_batch_admin(account, lottery_id, 1, 1, 70, 30, 40);

        let progress = sales::refund_progress(lottery_id);
        assert!(progress.refund_round == 1, 0);
        assert!(progress.tickets_refunded == 1, 0);
        assert!(progress.prize_refunded == 70, 0);
        assert!(progress.operations_refunded == 30, 0);
        assert!(progress.last_refund_ts == 40, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    #[expected_failure(abort_code = errors::E_REFUND_STATUS_INVALID)]
    fun refund_requires_canceled_status(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let lottery_id = 302;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);

        payouts::force_refund_batch_admin(account, lottery_id, 1, 1, 100, 10, 30);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    #[expected_failure(abort_code = errors::E_REFUND_LIMIT_TICKETS)]
    fun refund_cannot_exceed_tickets(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let lottery_id = 303;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);

        registry::cancel_lottery_admin(
            account,
            lottery_id,
            registry::CANCEL_REASON_OPERATIONS,
            30,
        );

        payouts::force_refund_batch_admin(account, lottery_id, 1, 1, 100, 0, 35);
        payouts::force_refund_batch_admin(account, lottery_id, 2, 1, 10, 0, 40);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_CANCELLATION_RECORD_MISSING)]
    fun archive_canceled_requires_record(account: &signer) {
        setup_modules(account);
        let lottery_id = 304;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_CANCELED);

        payouts::archive_canceled_lottery_admin(account, lottery_id, 50);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    #[expected_failure(abort_code = errors::E_REFUND_PROGRESS_INCOMPLETE)]
    fun archive_canceled_requires_full_refund(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let lottery_id = 305;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);

        registry::cancel_lottery_admin(
            account,
            lottery_id,
            registry::CANCEL_REASON_OPERATIONS,
            30,
        );

        payouts::archive_canceled_lottery_admin(account, lottery_id, 40);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    fun archive_canceled_records_summary(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let lottery_id = 306;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);

        registry::cancel_lottery_admin(
            account,
            lottery_id,
            registry::CANCEL_REASON_OPERATIONS,
            30,
        );

        payouts::force_refund_batch_admin(account, lottery_id, 1, 1, 70, 30, 40);
        payouts::archive_canceled_lottery_admin(account, lottery_id, 50);

        let summary = history::get_summary(lottery_id);
        assert!(summary.status == types::STATUS_CANCELED, 0);
        assert!(summary.tickets_sold == 1, 0);
        assert!(summary.proceeds_accum == 100, 0);
        assert!(summary.payout_round == 1, 0);
        assert!(summary.closed_at == 30, 0);
        assert!(summary.finalized_at == 50, 0);
        assert!(summary.vrf_status == types::VRF_STATUS_IDLE, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun force_cancel_refund_flow_records_history(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 307;

        let mut config = new_config();
        registry::create_draft_admin(account, lottery_id, copy config);
        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);

        sales::purchase_tickets_public(buyer1, lottery_id, 1, 25, 1);
        sales::purchase_tickets_public(buyer2, lottery_id, 1, 26, 1);

        let status_before = views::get_lottery_status(lottery_id);
        assert!(status_before.status == registry::STATUS_ACTIVE, 0);

        registry::cancel_lottery_admin(
            account,
            lottery_id,
            registry::CANCEL_REASON_OPERATIONS,
            40,
        );

        let status_after = views::get_lottery_status(lottery_id);
        assert!(status_after.status == registry::STATUS_CANCELED, 0);
        assert!(status_after.snapshot_frozen, 0);

        let cancel_record_opt = views::get_cancellation(lottery_id);
        assert!(option::is_some(&cancel_record_opt), 0);
        let cancel_record_ref = option::borrow(&cancel_record_opt);
        assert!(cancel_record_ref.previous_status == registry::STATUS_ACTIVE, 0);
        assert!(cancel_record_ref.reason_code == registry::CANCEL_REASON_OPERATIONS, 0);
        assert!(cancel_record_ref.tickets_sold == 2, 0);
        assert!(cancel_record_ref.proceeds_accum == 200, 0);
        assert!(cancel_record_ref.canceled_ts == 40, 0);

        let progress_after_cancel = views::get_refund_progress(lottery_id);
        assert!(progress_after_cancel.active, 0);
        assert!(progress_after_cancel.refund_round == 0, 0);
        assert!(progress_after_cancel.tickets_refunded == 0, 0);

        payouts::force_refund_batch_admin(account, lottery_id, 1, 1, 70, 30, 55);
        payouts::force_refund_batch_admin(account, lottery_id, 2, 1, 70, 30, 65);

        let progress_after_batches = views::get_refund_progress(lottery_id);
        assert!(progress_after_batches.refund_round == 2, 0);
        assert!(progress_after_batches.tickets_refunded == 2, 0);
        assert!(progress_after_batches.prize_refunded == 140, 0);
        assert!(progress_after_batches.operations_refunded == 60, 0);
        assert!(progress_after_batches.last_refund_ts == 65, 0);

        payouts::archive_canceled_lottery_admin(account, lottery_id, 80);

        let summary = views::get_lottery_summary(lottery_id);
        assert!(summary.status == types::STATUS_CANCELED, 0);
        assert!(summary.tickets_sold == 2, 0);
        assert!(summary.proceeds_accum == 200, 0);
        assert!(summary.payout_round == 2, 0);
        assert!(summary.closed_at == 40, 0);
        assert!(summary.finalized_at == 80, 0);
        assert!(summary.vrf_status == types::VRF_STATUS_IDLE, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2, buyer3 = @0x3)]
    fun payout_handles_multi_slot_plan(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        buyer3: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 209;

        prepare_multi_slot(account, buyer1, buyer2, buyer3, lottery_id);

        payouts::compute_winners_admin(account, lottery_id, 10);

        let winners = payouts::test_read_winner_indices(lottery_id);
        assert!(vector::length(&winners) == 3, 0);

        payouts::record_payout_batch_admin(account, lottery_id, 1, 3, 210, 15, 2_000);

        let accounting = sales::accounting_snapshot(lottery_id);
        assert!(accounting.total_prize_paid == 210, 0);
        assert!(accounting.total_operations_paid == 15, 0);
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
            roles::new_partner_payout_cap(@0x77, 100, 0, 1, 0),
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

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_BUDGET_EXCEEDED)]
    fun partner_payout_cannot_exceed_cap(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 210);

        roles::upsert_partner_payout_cap_admin(
            account,
            @0x66,
            roles::new_partner_payout_cap(@0x66, 15, 0, 1, 0),
        );

        payouts::record_payout_batch_admin(account, 210, 1, 2, 140, 5, 50);
        payouts::record_partner_payout_admin(account, 210, @0x66, 16, 1, 60);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_PAYOUT_ALLOC_EXCEEDED)]
    fun payout_batch_respects_prize_cap(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 203);

        payouts::record_payout_batch_admin(account, 203, 1, 1, 151, 0, 30);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_PAYOUT_BATCH_NONCE)]
    fun payout_round_cannot_skip(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        prepare_for_payout(account, buyer1, buyer2, 204);

        payouts::record_payout_batch_admin(account, 204, 1, 1, 140, 5, 40);
        payouts::record_payout_batch_admin(account, 204, 3, 0, 0, 0, 45);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_FINALIZATION_INCOMPLETE)]
    fun finalize_requires_all_winners(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);

        let lottery_id = 205;
        prepare_partial_payout(account, buyer1, buyer2, lottery_id);

        payouts::finalize_lottery_admin(account, lottery_id, 2_000);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun finalize_records_summary(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 206;

        prepare_for_payout(account, buyer1, buyer2, lottery_id);

        payouts::record_payout_batch_admin(account, lottery_id, 1, 2, 140, 10, 1_000);
        payouts::finalize_lottery_admin(account, lottery_id, 9_999);

        let status = registry::get_status(lottery_id);
        assert!(status == registry::STATUS_FINALIZED, 0);

        let summary = history::get_summary(lottery_id);
        assert!(summary.status == types::STATUS_FINALIZED, 0);
        assert!(summary.total_prize_paid == 140, 0);
        assert!(summary.total_operations_paid == 10, 0);
        assert!(summary.payout_round == 1, 0);
        assert!(summary.tickets_sold == 2, 0);
        assert!(summary.finalized_at == 9_999, 0);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_DRAW_STATUS_INVALID)]
    fun payout_batch_rejected_after_finalization(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 207;

        prepare_for_payout(account, buyer1, buyer2, lottery_id);
        payouts::record_payout_batch_admin(account, lottery_id, 1, 2, 140, 10, 1_000);
        payouts::finalize_lottery_admin(account, lottery_id, 9_999);

        payouts::record_payout_batch_admin(account, lottery_id, 2, 0, 0, 0, 10_000);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    #[expected_failure(abort_code = errors::E_DRAW_STATUS_INVALID)]
    fun partner_payout_rejected_after_finalization(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 208;

        prepare_for_payout(account, buyer1, buyer2, lottery_id);
        roles::upsert_partner_payout_cap_admin(
            account,
            @0x88,
            roles::new_partner_payout_cap(@0x88, 50, 0, 1, 0),
        );
        payouts::record_payout_batch_admin(account, lottery_id, 1, 2, 140, 5, 1_000);
        payouts::finalize_lottery_admin(account, lottery_id, 9_999);

        payouts::record_partner_payout_admin(account, lottery_id, @0x88, 5, 1, 10_000);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2)]
    fun accounting_aligns_with_summary_and_view(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
    ) {
        setup_modules(account);
        let lottery_id = 211;

        prepare_for_payout(account, buyer1, buyer2, lottery_id);

        payouts::record_payout_batch_admin(account, lottery_id, 1, 2, 140, 10, 1_000);
        payouts::finalize_lottery_admin(account, lottery_id, 9_999);

        let accounting = sales::accounting_snapshot(lottery_id);
        let accounting_view = views::accounting_snapshot(lottery_id);
        let summary = history::get_summary(lottery_id);

        assert!(accounting.total_sales == 200, 0);
        assert!(accounting.total_allocated >= accounting.total_prize_paid, 0);
        assert!(accounting.total_operations_allocated >= accounting.total_operations_paid, 0);

        assert!(summary.total_allocated == accounting.total_allocated, 0);
        assert!(summary.total_prize_paid == accounting.total_prize_paid, 0);
        assert!(summary.total_operations_paid == accounting.total_operations_paid, 0);
        assert!(summary.payout_round == 1, 0);

        assert!(accounting_view.total_prize_paid == accounting.total_prize_paid, 0);
        assert!(accounting_view.total_operations_paid == accounting.total_operations_paid, 0);
        assert!(accounting_view.total_operations_allocated == accounting.total_operations_allocated, 0);
    }

    fun setup_modules(account: &signer) {
        registry::init_registry(account);
        sales::init_sales(account);
        draw::init_draw(account);
        payouts::init_payouts(account);
        history::init_history(account);
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
        configure_and_seed(account, buyer1, buyer2, lottery_id, 10, 10, true);
    }

    fun prepare_partial_payout(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        lottery_id: u64,
    ) {
        let mut config = new_config_with_winners(2);
        registry::create_draft_admin(account, lottery_id, copy config);
        configure_and_seed(account, buyer1, buyer2, lottery_id, 20, 1, true);
    }

    fun new_config(): registry::Config {
        new_config_with_winners(1)
    }

    fun new_config_with_winners(winners_per_slot: u16): registry::Config {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(0, winners_per_slot, types::REWARD_FROM_SALES, b""),
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
            vrf_retry_policy: types::default_retry_policy(),
        }
    }

    fun configure_and_seed(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        lottery_id: u64,
        payload_seed: u64,
        compute_limit: u64,
        auto_mark_payout: bool,
    ) {
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
            payload_seed,
            1,
        );
        registry::mark_drawn(lottery_id);
        if (compute_limit > 0) {
            payouts::compute_winners_admin(account, lottery_id, compute_limit);
        };
        if (auto_mark_payout) {
            let status = registry::get_status(lottery_id);
            if (status == registry::STATUS_DRAWN) {
                registry::mark_payout(lottery_id);
            };
        };
    }

    fun prepare_multi_slot(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        buyer3: &signer,
        lottery_id: u64,
    ) {
        let mut config = new_multi_slot_config();
        registry::create_draft_admin(account, lottery_id, copy config);

        registry::advance_status(account, lottery_id, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, lottery_id, 1, 20, 1);
        sales::purchase_tickets_public(buyer2, lottery_id, 1, 22, 2);
        sales::purchase_tickets_public(buyer3, lottery_id, 1, 24, 3);

        registry::advance_status(account, lottery_id, registry::STATUS_CLOSING);
        registry::mark_draw_requested(lottery_id);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(lottery_id);
        let mut numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x0102030405060708u256);
        vector::push_back(&mut numbers, 0x0f0e0d0c0b0a0908u256);
        let payload_hash = hash::sha3_256(b"payload-multi-slot");
        draw::test_seed_vrf_state(
            lottery_id,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            777,
            1,
        );
        registry::mark_drawn(lottery_id);
        registry::mark_payout(lottery_id);
    }

    fun new_multi_slot_config(): registry::Config {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(10, 2, types::REWARD_FROM_SALES, b""),
        );
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(11, 1, types::REWARD_FROM_SALES, b""),
        );
        registry::Config {
            event_slug: copy EVENT_BYTES,
            series_code: copy MULTI_SERIES_BYTES,
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
            vrf_retry_policy: types::default_retry_policy(),
        }
    }
}
