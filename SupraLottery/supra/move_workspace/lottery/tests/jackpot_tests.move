#[test_only]
module lottery::jackpot_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use supra_framework::event;
    use lottery::jackpot;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery::test_utils;
    use vrf_hub::hub;

    fun setup_token(lottery_admin: &signer, player1: &signer, player2: &signer) {
        test_utils::ensure_core_accounts();
        treasury_v1::init_token(
            lottery_admin,
            b"jackpot_seed",
            b"Jackpot Token",
            b"JCK",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(player1);
        treasury_v1::register_store(player2);
        treasury_v1::mint_to(lottery_admin, signer::address_of(player1), 5_000);
        treasury_v1::mint_to(lottery_admin, signer::address_of(player2), 5_000);
    }

    fun build_randomness(value: u8): vector<u8> {
        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, value);
        let i = 1;
        while (i < 8) {
            vector::push_back(&mut randomness, 0);
            i = i + 1;
        };
        randomness
    }

    #[test(
        vrf_admin = @vrf_hub,
        lottery_admin = @lottery,
        player1 = @player1,
        player2 = @player2,
        aggregator = @0x45,
    )]
    fun jackpot_full_cycle(
        vrf_admin: &signer,
        lottery_admin: &signer,
        player1: &signer,
        player2: &signer,
        aggregator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        let lottery_id = hub::register_lottery(vrf_admin, @lottery_owner, @lottery_contract, b"jackpot");
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        jackpot::init(lottery_admin, lottery_id);
        setup_token(lottery_admin, player1, player2);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 0, 10_000, 0);

        treasury_v1::deposit_from_user(player1, 1_000);
        treasury_multi::record_allocation(lottery_admin, 1, 1_000);
        assert!(treasury_multi::jackpot_balance() == 1_000, 0);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);

        jackpot::grant_ticket(lottery_admin, player1_addr);
        jackpot::grant_ticket(lottery_admin, player2_addr);
        jackpot::schedule_draw(lottery_admin);
        jackpot::request_randomness(lottery_admin, b"global");

        let mut request_id_opt = jackpot::pending_request();
        let request_id = test_utils::unwrap(&mut request_id_opt);
        let randomness = build_randomness(1);
        jackpot::fulfill_draw(aggregator, request_id, randomness);

        let mut snapshot_opt = jackpot::get_snapshot();
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (
            snapshot_admin,
            snapshot_lottery_id,
            ticket_count,
            draw_scheduled,
            has_pending_request,
            pending_request_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&snapshot);
        assert!(snapshot_admin == signer::address_of(lottery_admin), 1);
        assert!(snapshot_lottery_id == lottery_id, 2);
        assert!(ticket_count == 0, 3);
        assert!(!draw_scheduled, 4);
        assert!(!has_pending_request, 5);
        assert!(option::is_none(&pending_request_opt), 6);

        let snapshot_events = event::emitted_events<jackpot::JackpotSnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 6, 7);

        let initial_event = vector::borrow(&snapshot_events, 0);
        let (initial_previous_opt, initial_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(initial_event);
        assert!(option::is_none(&initial_previous_opt), 8);
        let (
            initial_admin,
            initial_lottery_id,
            initial_ticket_count,
            initial_draw_scheduled,
            initial_has_pending,
            initial_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&initial_current);
        assert!(initial_admin == signer::address_of(lottery_admin), 9);
        assert!(initial_lottery_id == lottery_id, 10);
        assert!(initial_ticket_count == 0, 11);
        assert!(!initial_draw_scheduled, 12);
        assert!(!initial_has_pending, 13);
        assert!(option::is_none(&initial_pending_opt), 14);

        let request_event = vector::borrow(&snapshot_events, 4);
        let (mut request_previous_opt, request_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(request_event);
        let request_previous = test_utils::unwrap(&mut request_previous_opt);
        let (
            _prev_admin,
            _prev_lottery_id,
            _prev_ticket_count,
            prev_draw_scheduled,
            prev_has_pending,
            prev_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&request_previous);
        assert!(prev_draw_scheduled, 15);
        assert!(!prev_has_pending, 16);
        assert!(option::is_none(&prev_pending_opt), 17);
        let (
            _req_admin,
            _req_lottery_id,
            _req_ticket_count,
            req_draw_scheduled,
            req_has_pending,
            req_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&request_current);
        assert!(req_draw_scheduled, 18);
        assert!(req_has_pending, 19);
        let mut req_pending_opt = req_pending_opt;
        let req_pending_id = test_utils::unwrap(&mut req_pending_opt);
        assert!(req_pending_id == request_id, 20);

        let final_event = vector::borrow(&snapshot_events, 5);
        let (mut final_previous_opt, final_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(final_event);
        let final_previous = test_utils::unwrap(&mut final_previous_opt);
        let (
            _final_prev_admin,
            _final_prev_lottery_id,
            _final_prev_ticket_count,
            final_prev_draw_scheduled,
            final_prev_has_pending,
            final_prev_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&final_previous);
        assert!(final_prev_draw_scheduled, 21);
        assert!(final_prev_has_pending, 22);
        let mut final_prev_pending_opt = final_prev_pending_opt;
        let final_prev_pending_id = test_utils::unwrap(&mut final_prev_pending_opt);
        assert!(final_prev_pending_id == request_id, 23);
        let (
            _final_admin,
            _final_lottery_id,
            final_ticket_count,
            final_draw_scheduled,
            final_has_pending,
            final_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&final_current);
        assert!(final_ticket_count == 0, 24);
        assert!(!final_draw_scheduled, 25);
        assert!(!final_has_pending, 26);
        assert!(option::is_none(&final_pending_opt), 27);

        assert!(treasury_multi::jackpot_balance() == 0, 28);
        assert!(treasury_v1::treasury_balance() == 0, 29);
        assert!(treasury_v1::balance_of(player1_addr) == 4_000, 30);
        assert!(treasury_v1::balance_of(player2_addr) == 6_000, 31);
    }

    #[test(
        vrf_admin = @vrf_hub,
        lottery_admin = @lottery,
        player1 = @player3,
        player2 = @player4,
        aggregator = @0x46,
    )]
    #[expected_failure(
        location = lottery::jackpot,
        abort_code = jackpot::E_EMPTY_JACKPOT,
    )]
    fun jackpot_requires_balance(
        vrf_admin: &signer,
        lottery_admin: &signer,
        player1: &signer,
        player2: &signer,
        aggregator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        let lottery_id = hub::register_lottery(vrf_admin, @lottery_owner, @lottery_contract, b"jackpot-empty");
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        jackpot::init(lottery_admin, lottery_id);
        setup_token(lottery_admin, player1, player2);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 2, 0, 10_000, 0);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);
        jackpot::grant_ticket(lottery_admin, player1_addr);
        jackpot::grant_ticket(lottery_admin, player2_addr);
        jackpot::schedule_draw(lottery_admin);
        jackpot::request_randomness(lottery_admin, b"global");

        let mut request_id_opt = jackpot::pending_request();
        let request_id = test_utils::unwrap(&mut request_id_opt);
        let randomness = build_randomness(0);
        jackpot::fulfill_draw(aggregator, request_id, randomness);
    }
}
