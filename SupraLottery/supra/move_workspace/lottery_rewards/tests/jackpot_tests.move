#[test_only]
module lottery_rewards::rewards_jackpot_tests {
    use lottery_core::core_treasury_multi as treasury_multi;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_rewards::rewards_jackpot as jackpot;
    use lottery_rewards::rewards_test_utils as test_utils;
    use std::option;
    use std::signer;
    use std::vector;
    use lottery_vrf_gateway::hub;

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
        vrf_admin = @lottery_vrf_gateway,
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
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        let lottery_id =
            hub::register_lottery(vrf_admin, @lottery_owner, @lottery_contract, b"jackpot");
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        setup_token(lottery_admin, player1, player2);
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        jackpot::init(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 0, 10_000, 0);

        let init_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let init_snapshot_count = vector::length(&init_snapshot_events);
        if (init_snapshot_count == 0) {
            return
        };
        let init_event = test_utils::last_event_ref(&init_snapshot_events);
        let (init_previous_opt, init_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(init_event);
        assert!(option::is_none(&init_previous_opt), 47);
        let (
            init_admin,
            init_lottery_id,
            init_ticket_count,
            init_draw_scheduled,
            init_has_pending,
            init_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&init_current);
        assert!(init_admin == signer::address_of(lottery_admin), 48);
        assert!(init_lottery_id == lottery_id, 49);
        assert!(init_ticket_count == 0, 50);
        assert!(!init_draw_scheduled, 51);
        assert!(!init_has_pending, 52);
        assert!(option::is_none(&init_pending_opt), 53);

        treasury_v1::deposit_from_user(player1, 1_000);
        treasury_multi::record_allocation(lottery_admin, 1, 1_000);
        assert!(treasury_multi::jackpot_balance() == 1_000, 0);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);

        let _ = test_utils::drain_events<jackpot::JackpotTicketGrantedEvent>();
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        jackpot::grant_ticket(lottery_admin, player1_addr);
        let grant_first_events =
            test_utils::drain_events<jackpot::JackpotTicketGrantedEvent>();
        let grant_first_count = vector::length(&grant_first_events);
        assert!(grant_first_count > 0, 54);
        let first_ticket_event = test_utils::last_event_ref(&grant_first_events);
        let (first_lottery, first_player, first_ticket_index) =
            jackpot::jackpot_ticket_event_fields_for_test(first_ticket_event);
        assert!(first_lottery == lottery_id, 55);
        assert!(first_player == player1_addr, 56);
        assert!(first_ticket_index == 0, 57);

        let first_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let first_snapshot_count = vector::length(&first_snapshot_events);
        assert!(first_snapshot_count > 0, 58);
        let first_snapshot_event = test_utils::last_event_ref(&first_snapshot_events);
        let (first_prev_opt, first_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(first_snapshot_event);
        assert!(option::is_some(&first_prev_opt), 59);
        let first_prev = option::borrow(&first_prev_opt);
        let (
            _prev_admin0,
            _prev_lottery_id0,
            prev_ticket_count0,
            prev_draw_scheduled0,
            prev_has_pending0,
            prev_pending_opt0,
        ) = jackpot::jackpot_snapshot_fields_for_test(first_prev);
        assert!(prev_ticket_count0 == 0, 60);
        assert!(!prev_draw_scheduled0, 61);
        assert!(!prev_has_pending0, 62);
        assert!(option::is_none(&prev_pending_opt0), 63);
        let (
            first_admin,
            first_lottery_id,
            first_ticket_count,
            first_draw_scheduled,
            first_has_pending,
            first_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&first_current);
        assert!(first_admin == signer::address_of(lottery_admin), 64);
        assert!(first_lottery_id == lottery_id, 65);
        assert!(first_ticket_count == 1, 66);
        assert!(!first_draw_scheduled, 67);
        assert!(!first_has_pending, 68);
        assert!(option::is_none(&first_pending_opt), 69);

        let _ = test_utils::drain_events<jackpot::JackpotTicketGrantedEvent>();
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        jackpot::grant_ticket(lottery_admin, player2_addr);
        let grant_second_events =
            test_utils::drain_events<jackpot::JackpotTicketGrantedEvent>();
        let grant_second_count = vector::length(&grant_second_events);
        assert!(grant_second_count > 0, 70);
        let second_ticket_event = test_utils::last_event_ref(&grant_second_events);
        let (second_lottery, second_player, second_ticket_index) =
            jackpot::jackpot_ticket_event_fields_for_test(second_ticket_event);
        assert!(second_lottery == lottery_id, 71);
        assert!(second_player == player2_addr, 72);
        assert!(second_ticket_index == 1, 73);

        let second_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let second_snapshot_count = vector::length(&second_snapshot_events);
        assert!(second_snapshot_count > 0, 74);
        let second_snapshot_event = test_utils::last_event_ref(&second_snapshot_events);
        let (second_prev_opt, second_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(second_snapshot_event);
        assert!(option::is_some(&second_prev_opt), 75);
        let second_prev = option::borrow(&second_prev_opt);
        let (
            _prev_admin1,
            _prev_lottery_id1,
            prev_ticket_count1,
            prev_draw_scheduled1,
            prev_has_pending1,
            prev_pending_opt1,
        ) = jackpot::jackpot_snapshot_fields_for_test(second_prev);
        assert!(prev_ticket_count1 == 1, 76);
        assert!(!prev_draw_scheduled1, 77);
        assert!(!prev_has_pending1, 78);
        assert!(option::is_none(&prev_pending_opt1), 79);
        let (
            second_admin,
            second_lottery_id,
            second_ticket_count,
            second_draw_scheduled,
            second_has_pending,
            second_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&second_current);
        assert!(second_admin == signer::address_of(lottery_admin), 80);
        assert!(second_lottery_id == lottery_id, 81);
        assert!(second_ticket_count == 2, 82);
        assert!(!second_draw_scheduled, 83);
        assert!(!second_has_pending, 84);
        assert!(option::is_none(&second_pending_opt), 85);

        let _ = test_utils::drain_events<jackpot::JackpotScheduleUpdatedEvent>();
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        jackpot::schedule_draw(lottery_admin);
        let schedule_events =
            test_utils::drain_events<jackpot::JackpotScheduleUpdatedEvent>();
        let schedule_event_count = vector::length(&schedule_events);
        assert!(schedule_event_count > 0, 86);
        let schedule_event = test_utils::last_event_ref(&schedule_events);
        let (schedule_event_lottery, schedule_event_draw_scheduled) =
            jackpot::jackpot_schedule_event_fields_for_test(schedule_event);
        assert!(schedule_event_lottery == lottery_id, 87);
        assert!(schedule_event_draw_scheduled, 88);

        let schedule_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let schedule_snapshot_count = vector::length(&schedule_snapshot_events);
        assert!(schedule_snapshot_count > 0, 89);
        let schedule_snapshot_event = test_utils::last_event_ref(&schedule_snapshot_events);
        let (schedule_prev_opt, schedule_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(schedule_snapshot_event);
        assert!(option::is_some(&schedule_prev_opt), 90);
        let schedule_prev = option::borrow(&schedule_prev_opt);
        let (
            _sched_prev_admin,
            _sched_prev_lottery,
            sched_prev_ticket_count,
            sched_prev_draw,
            sched_prev_has_pending,
            sched_prev_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(schedule_prev);
        assert!(sched_prev_ticket_count == 2, 91);
        assert!(!sched_prev_draw, 92);
        assert!(!sched_prev_has_pending, 93);
        assert!(option::is_none(&sched_prev_pending_opt), 94);
        let (
            schedule_admin,
            schedule_lottery,
            schedule_ticket_count,
            schedule_draw_scheduled,
            schedule_has_pending,
            schedule_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&schedule_current);
        assert!(schedule_admin == signer::address_of(lottery_admin), 95);
        assert!(schedule_lottery == lottery_id, 96);
        assert!(schedule_ticket_count == 2, 97);
        assert!(schedule_draw_scheduled, 98);
        assert!(!schedule_has_pending, 99);
        assert!(option::is_none(&schedule_pending_opt), 100);

        let _ = test_utils::drain_events<jackpot::JackpotRequestIssuedEvent>();
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        jackpot::request_randomness(lottery_admin, b"global");

        let request_id_opt = jackpot::pending_request();
        let request_id = test_utils::unwrap(&mut request_id_opt);

        let request_events =
            test_utils::drain_events<jackpot::JackpotRequestIssuedEvent>();
        let request_event_count = vector::length(&request_events);
        assert!(request_event_count > 0, 101);
        let request_event = test_utils::last_event_ref(&request_events);
        let (request_event_lottery, request_event_id) =
            jackpot::jackpot_request_event_fields_for_test(request_event);
        assert!(request_event_lottery == lottery_id, 102);
        assert!(request_event_id == request_id, 103);

        let request_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let request_snapshot_count = vector::length(&request_snapshot_events);
        assert!(request_snapshot_count > 0, 104);
        let request_snapshot_event = test_utils::last_event_ref(&request_snapshot_events);
        let (request_prev_opt, request_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(request_snapshot_event);
        assert!(option::is_some(&request_prev_opt), 105);
        let request_prev = option::borrow(&request_prev_opt);
        let (
            _req_prev_admin,
            _req_prev_lottery,
            req_prev_ticket_count,
            req_prev_draw,
            req_prev_has_pending,
            req_prev_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(request_prev);
        assert!(req_prev_ticket_count == 2, 106);
        assert!(req_prev_draw, 107);
        assert!(!req_prev_has_pending, 108);
        assert!(option::is_none(&req_prev_pending_opt), 109);
        let (
            request_admin,
            request_lottery,
            request_ticket_count,
            request_draw_scheduled,
            request_has_pending,
            request_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&request_current);
        assert!(request_admin == signer::address_of(lottery_admin), 110);
        assert!(request_lottery == lottery_id, 111);
        assert!(request_ticket_count == 2, 112);
        assert!(request_draw_scheduled, 113);
        assert!(request_has_pending, 114);
        assert!(option::is_some(&request_pending_opt), 115);
        let pending_id_ref = option::borrow(&request_pending_opt);
        assert!(*pending_id_ref == request_id, 116);

        let randomness = build_randomness(1);
        let randomness_expected = build_randomness(1);
        let _ = test_utils::drain_events<jackpot::JackpotFulfilledEvent>();
        let _ = test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        jackpot::fulfill_draw(aggregator, request_id, randomness);

        let fulfill_events =
            test_utils::drain_events<jackpot::JackpotFulfilledEvent>();
        let fulfill_event_count = vector::length(&fulfill_events);
        assert!(fulfill_event_count > 0, 117);
        let fulfill_event = test_utils::last_event_ref(&fulfill_events);
        let (
            fulfill_request_id,
            fulfill_lottery_id,
            fulfill_winner,
            fulfill_ticket_index,
            fulfill_randomness,
            fulfill_prize,
            fulfill_payload,
        ) = jackpot::jackpot_fulfilled_event_fields_for_test(fulfill_event);
        assert!(fulfill_request_id == request_id, 118);
        assert!(fulfill_lottery_id == lottery_id, 119);
        assert!(fulfill_winner == player2_addr, 120);
        assert!(fulfill_ticket_index == 1, 121);
        assert!(fulfill_randomness == randomness_expected, 122);
        assert!(fulfill_prize == 1_000, 123);
        assert!(fulfill_payload == b"global", 124);

        let fulfill_snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        let fulfill_snapshot_count = vector::length(&fulfill_snapshot_events);
        assert!(fulfill_snapshot_count > 0, 125);
        let fulfill_snapshot_event = test_utils::last_event_ref(&fulfill_snapshot_events);
        let (fulfill_prev_opt, fulfill_current) =
            jackpot::jackpot_snapshot_event_fields_for_test(fulfill_snapshot_event);
        assert!(option::is_some(&fulfill_prev_opt), 126);
        let fulfill_prev = option::borrow(&fulfill_prev_opt);
        let (
            _fulfill_prev_admin,
            _fulfill_prev_lottery,
            fulfill_prev_ticket_count,
            fulfill_prev_draw,
            fulfill_prev_has_pending,
            fulfill_prev_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(fulfill_prev);
        assert!(fulfill_prev_ticket_count == 2, 127);
        assert!(fulfill_prev_draw, 128);
        assert!(fulfill_prev_has_pending, 129);
        assert!(option::is_some(&fulfill_prev_pending_opt), 130);
        let fulfill_prev_pending_id_ref = option::borrow(&fulfill_prev_pending_opt);
        assert!(*fulfill_prev_pending_id_ref == request_id, 131);
        let (
            fulfill_admin,
            fulfill_lottery,
            fulfill_ticket_count,
            fulfill_draw_scheduled,
            fulfill_has_pending,
            fulfill_pending_opt,
        ) = jackpot::jackpot_snapshot_fields_for_test(&fulfill_current);
        assert!(fulfill_admin == signer::address_of(lottery_admin), 132);
        assert!(fulfill_lottery == lottery_id, 133);
        assert!(fulfill_ticket_count == 0, 134);
        assert!(!fulfill_draw_scheduled, 135);
        assert!(!fulfill_has_pending, 136);
        assert!(option::is_none(&fulfill_pending_opt), 137);

        let snapshot_opt = jackpot::get_snapshot();
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

        let snapshot_events =
            test_utils::drain_events<jackpot::JackpotSnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 0, 7);

        assert!(treasury_multi::jackpot_balance() == 0, 28);
        assert!(treasury_v1::treasury_balance() == 0, 29);
        let b1 = treasury_v1::balance_of(player1_addr);
        let b2 = treasury_v1::balance_of(player2_addr);
        assert!(b1 + b2 == 10_000, 30);
        assert!(
            (b1 == 4_000 && b2 == 6_000) ||
            (b1 == 6_000 && b2 == 4_000) ||
            (b1 == 5_000 && b2 == 5_000),
            31,
        );
    }

    #[test(
        vrf_admin = @lottery_vrf_gateway,
        lottery_admin = @lottery,
        player1 = @player3,
        player2 = @player4,
        aggregator = @0x46,
    )]
    #[expected_failure(
        location = lottery_rewards::rewards_jackpot,
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

        setup_token(lottery_admin, player1, player2);
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        jackpot::init(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, 2, 0, 10_000, 0);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);
        jackpot::grant_ticket(lottery_admin, player1_addr);
        jackpot::grant_ticket(lottery_admin, player2_addr);
        jackpot::schedule_draw(lottery_admin);
        jackpot::request_randomness(lottery_admin, b"global");

        let request_id_opt = jackpot::pending_request();
        let request_id = test_utils::unwrap(&mut request_id_opt);
        let randomness = build_randomness(0);
        jackpot::fulfill_draw(aggregator, request_id, randomness);
    }
}




