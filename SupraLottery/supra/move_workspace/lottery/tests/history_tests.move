#[test_only]
module lottery::history_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::history;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        test_utils::ensure_core_accounts();
        treasury_v1::init_token(
            lottery_admin,
            b"history_seed",
            b"History Token",
            b"HST",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(buyer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 10_000);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        aggregator = @0x55,
    )]
    fun records_draw_history(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        let _ = test_utils::drain_events<history::HistorySnapshotUpdatedEvent>();
        test_utils::ensure_core_accounts();
        test_utils::ensure_time_started();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        history::init(lottery_admin);
        setup_token(lottery_admin, buyer);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(80, 1500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::buy_ticket(buyer, lottery_id);
        rounds::schedule_draw(lottery_admin, lottery_id);

        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        rounds::request_randomness(lottery_admin, lottery_id, b"log");
        let request_id_opt = rounds::pending_request_id(lottery_id);
        let request_id = test_utils::unwrap(&mut request_id_opt);

        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, 9);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);

        rounds::fulfill_draw(aggregator, request_id, randomness);

        let history_opt = history::get_history(lottery_id);
        let records = test_utils::unwrap(&mut history_opt);
        assert!(vector::length(&records) == 1, 0);
        let record = *vector::borrow(&records, 0);
        let (
            stored_request,
            winner_addr,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
            _timestamp,
        ) = history::draw_record_fields_for_test(&record);
        assert!(stored_request == request_id, 1);
        assert!(winner_addr == signer::address_of(buyer), 2);
        assert!(ticket_index == 0, 3);
        assert!(prize_amount > 0, 4);
        assert!(vector::length(&random_bytes) == 8, 5);
        assert!(payload == b"log", 6);

        let ids = history::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 7);
        assert!(*vector::borrow(&ids, 0) == lottery_id, 8);

        let latest_opt = history::latest_record(lottery_id);
        let latest = test_utils::unwrap(&mut latest_opt);
        let (latest_request, _, _, _, _, _, _) =
            history::draw_record_fields_for_test(&latest);
        assert!(latest_request == stored_request, 9);

        let lottery_snapshot_opt = history::get_lottery_snapshot(lottery_id);
        let lottery_snapshot = test_utils::unwrap(&mut lottery_snapshot_opt);
        let (snapshot_lottery_id, snapshot_records) =
            history::lottery_history_snapshot_fields_for_test(&lottery_snapshot);
        assert!(snapshot_lottery_id == lottery_id, 10);
        assert!(vector::length(&snapshot_records) == 1, 11);

        let history_snapshot_opt = history::get_history_snapshot();
        let history_snapshot = test_utils::unwrap(&mut history_snapshot_opt);
        let (snapshot_admin, snapshot_ids, snapshot_histories) =
            history::history_snapshot_fields_for_test(&history_snapshot);
        assert!(snapshot_admin == signer::address_of(lottery_admin), 12);
        assert!(vector::length(&snapshot_ids) == 1, 13);
        assert!(*vector::borrow(&snapshot_ids, 0) == lottery_id, 14);
        assert!(vector::length(&snapshot_histories) == 1, 15);

        let snapshot_events =
            test_utils::drain_events<history::HistorySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 2, 16);
        let init_event = vector::borrow(&snapshot_events, 0);
        let (init_previous, init_current) =
            history::history_snapshot_event_fields_for_test(init_event);
        assert!(option::is_none(&init_previous), 17);
        let (init_admin, init_ids, init_histories) =
            history::history_snapshot_fields_for_test(&init_current);
        assert!(init_admin == signer::address_of(lottery_admin), 18);
        assert!(vector::is_empty(&init_ids), 19);
        assert!(vector::is_empty(&init_histories), 20);

        let draw_event = vector::borrow(&snapshot_events, 1);
        let (draw_previous_opt, draw_current) =
            history::history_snapshot_event_fields_for_test(draw_event);
        assert!(option::is_some(&draw_previous_opt), 30);
        let draw_previous = option::borrow(&draw_previous_opt);
        let (_, prev_ids, _) = history::history_snapshot_fields_for_test(draw_previous);
        assert!(vector::length(&prev_ids) <= 1, 21);
        let (
            draw_admin,
            draw_ids,
            draw_histories,
        ) = history::history_snapshot_fields_for_test(&draw_current);
        assert!(draw_admin == signer::address_of(lottery_admin), 22);
        assert!(vector::length(&draw_ids) == 1, 23);
        let draw_snapshot = vector::borrow(&draw_histories, 0);
        let (_, draw_records) =
            history::lottery_history_snapshot_fields_for_test(draw_snapshot);
        assert!(vector::length(&draw_records) == 1, 24);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player4,
        aggregator = @0x56,
    )]
    fun clear_history_resets_records(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        test_utils::ensure_time_started();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        history::init(lottery_admin);
        setup_token(lottery_admin, buyer);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(60, 1200);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::buy_ticket(buyer, lottery_id);
        rounds::schedule_draw(lottery_admin, lottery_id);
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));
        rounds::request_randomness(lottery_admin, lottery_id, b"clear");
        let request_id_opt = rounds::pending_request_id(lottery_id);
        let request_id = test_utils::unwrap(&mut request_id_opt);

        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, 11);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);

        rounds::fulfill_draw(aggregator, request_id, randomness);

        let records_before_opt = history::get_history(lottery_id);
        let records_before = test_utils::unwrap(&mut records_before_opt);
        assert!(vector::length(&records_before) == 1, 0);

        history::clear_history(lottery_admin, lottery_id);

        let records_after_opt = history::get_history(lottery_id);
        let records_after = test_utils::unwrap(&mut records_after_opt);
        assert!(vector::is_empty(&records_after), 1);

        let latest_opt = history::latest_record(lottery_id);
        assert!(option::is_none(&latest_opt), 2);

        let snapshot_events =
            test_utils::drain_events<history::HistorySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 3, 3);
        let clear_event = vector::borrow(&snapshot_events, 2);
        let (clear_previous_opt, clear_current) =
            history::history_snapshot_event_fields_for_test(clear_event);
        assert!(option::is_some(&clear_previous_opt), 31);
        let clear_previous = option::borrow(&clear_previous_opt);
        let (_, _, clear_prev_histories) =
            history::history_snapshot_fields_for_test(clear_previous);
        let clear_prev_snapshot = vector::borrow(&clear_prev_histories, 0);
        let (_, clear_prev_records) =
            history::lottery_history_snapshot_fields_for_test(clear_prev_snapshot);
        assert!(vector::length(&clear_prev_records) == 1, 4);

        let (_, _, clear_histories) = history::history_snapshot_fields_for_test(&clear_current);
        let clear_current_snapshot = vector::borrow(&clear_histories, 0);
        let (_, clear_current_records) =
            history::lottery_history_snapshot_fields_for_test(clear_current_snapshot);
        assert!(vector::is_empty(&clear_current_records), 5);
    }
}
