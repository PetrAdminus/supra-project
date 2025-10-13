#[test_only]
module lottery::rounds_tests {
    use std::vector;
    use std::option;
    use std::signer;
    use std::account;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;
    use supra_framework::event;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        test_utils::ensure_framework_accounts_for_test();
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"rounds_seed",
            b"Rounds Token",
            b"RND",
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
        buyer = @player1,
    )]
    fun ticket_purchase_updates_state(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        setup_token(lottery_admin, buyer);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(100, 2000);
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

        let stats_opt = instances::get_instance_stats(lottery_id);
        let stats_snapshot = test_utils::unwrap(stats_opt);
        let (tickets_sold, jackpot_accumulated, active) =
            instances::instance_stats_for_test(&stats_snapshot);
        assert!(tickets_sold == 1, 0);
        assert!(jackpot_accumulated == 20, 1);
        assert!(active, 2);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_data = test_utils::unwrap(snapshot_opt);
        let (
            ticket_count,
            draw_scheduled,
            has_pending_request,
            next_ticket_id,
            pending_request_id_opt,
        ) = rounds::round_snapshot_fields_for_test(&snapshot_data);
        assert!(ticket_count == 1, 3);
        assert!(!draw_scheduled, 4);
        assert!(!has_pending_request, 5);
        assert!(next_ticket_id == 1, 6);
        assert!(option::is_none(&pending_request_id_opt), 7);

        let snapshot_events = event::emitted_events<rounds::RoundSnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 1, 8);
        let last_event = vector::borrow(&snapshot_events, 0);
        let (event_lottery_id, event_snapshot) =
            rounds::round_snapshot_event_fields_for_test(last_event);
        assert!(event_lottery_id == lottery_id, 9);
        let (
            event_ticket_count,
            event_draw_scheduled,
            event_has_pending,
            event_next_ticket_id,
            event_pending_id_opt,
        ) = rounds::round_snapshot_fields_for_test(&event_snapshot);
        assert!(event_ticket_count == 1, 10);
        assert!(!event_draw_scheduled, 11);
        assert!(!event_has_pending, 12);
        assert!(event_next_ticket_id == 1, 13);
        assert!(option::is_none(&event_pending_id_opt), 14);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        let pool_snapshot = test_utils::unwrap(pool_opt);
        let (prize_balance, operations_balance) =
            treasury_multi::pool_balances_for_test(&pool_snapshot);
        assert!(prize_balance == 70, 15);
        assert!(operations_balance == 10, 16);
        assert!(treasury_multi::jackpot_balance() == 20, 17);
        assert!(treasury_v1::balance_of(signer::address_of(buyer)) == 9_900, 18);
        assert!(treasury_v1::treasury_balance() == 100, 19);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player4,
    )]
    #[expected_failure(abort_code = 12)]
    fun cannot_buy_ticket_when_inactive(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        setup_token(lottery_admin, buyer);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(100, 2000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        hub::set_lottery_active(vrf_admin, lottery_id, false);
        instances::set_instance_active(lottery_admin, lottery_id, false);

        rounds::buy_ticket(buyer, lottery_id);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player2,
    )]
    fun schedule_and_reset_round(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

        let blueprint = registry::new_blueprint(50, 1000);
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

        let scheduled_snapshot = test_utils::unwrap(rounds::get_round_snapshot(lottery_id));
        let (
            _count_sched,
            is_scheduled,
            _pending_sched,
            _next_sched,
            pending_sched_opt,
        ) = rounds::round_snapshot_fields_for_test(&scheduled_snapshot);
        assert!(is_scheduled, 0);
        assert!(option::is_none(&pending_sched_opt), 1);

        rounds::reset_round(lottery_admin, lottery_id);
        let reset_snapshot = test_utils::unwrap(rounds::get_round_snapshot(lottery_id));
        let (
            ticket_count,
            draw_scheduled,
            _pending_reset,
            next_ticket_id,
            pending_reset_opt,
        ) = rounds::round_snapshot_fields_for_test(&reset_snapshot);
        assert!(ticket_count == 0, 2);
        assert!(!draw_scheduled, 3);
        assert!(next_ticket_id == 0, 4);
        assert!(option::is_none(&pending_reset_opt), 5);

        let events = event::emitted_events<rounds::RoundSnapshotUpdatedEvent>();
        assert!(vector::length(&events) == 3, 6);
        let last_event = vector::borrow(&events, 2);
        let (event_lottery_id, event_snapshot) =
            rounds::round_snapshot_event_fields_for_test(last_event);
        assert!(event_lottery_id == lottery_id, 7);
        let (
            event_ticket_count,
            event_draw_scheduled,
            event_has_pending,
            event_next_ticket_id,
            event_pending_opt,
        ) = rounds::round_snapshot_fields_for_test(&event_snapshot);
        assert!(event_ticket_count == 0, 8);
        assert!(!event_draw_scheduled, 9);
        assert!(!event_has_pending, 10);
        assert!(event_next_ticket_id == 0, 11);
        assert!(option::is_none(&event_pending_opt), 12);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        aggregator = @0x45,
    )]
    fun request_and_fulfill_draw(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        setup_token(lottery_admin, buyer);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(100, 2000);
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
        rounds::buy_ticket(buyer, lottery_id);
        rounds::schedule_draw(lottery_admin, lottery_id);

        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        rounds::request_randomness(lottery_admin, lottery_id, b"payload");
        let events_after_request = event::emitted_events<rounds::RoundSnapshotUpdatedEvent>();
        let request_events_count = vector::length(&events_after_request);
        let request_event = vector::borrow(&events_after_request, request_events_count - 1);
        let (request_event_lottery, request_snapshot) =
            rounds::round_snapshot_event_fields_for_test(request_event);
        assert!(request_event_lottery == lottery_id, 0);
        let (
            _tickets_after_request,
            is_scheduled_after_request,
            has_pending_after_request,
            _next_after_request,
            pending_request_opt,
        ) = rounds::round_snapshot_fields_for_test(&request_snapshot);
        assert!(is_scheduled_after_request, 1);
        assert!(has_pending_after_request, 2);
        let request_id = test_utils::unwrap(pending_request_opt);

        let request_opt = rounds::pending_request_id(lottery_id);
        let request_id_from_view = test_utils::unwrap(request_opt);
        assert!(request_id_from_view == request_id, 3);

        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, 5);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);

        rounds::fulfill_draw(aggregator, request_id, randomness);

        let events_after_fulfill = event::emitted_events<rounds::RoundSnapshotUpdatedEvent>();
        let fulfill_event = vector::borrow(&events_after_fulfill, vector::length(&events_after_fulfill) - 1);
        let (fulfill_event_lottery, fulfill_snapshot) =
            rounds::round_snapshot_event_fields_for_test(fulfill_event);
        assert!(fulfill_event_lottery == lottery_id, 4);
        let (
            event_ticket_count,
            event_draw_scheduled,
            event_has_pending,
            event_next_ticket_id,
            event_pending_opt,
        ) = rounds::round_snapshot_fields_for_test(&fulfill_snapshot);
        assert!(event_ticket_count == 0, 5);
        assert!(!event_draw_scheduled, 6);
        assert!(!event_has_pending, 7);
        assert!(event_next_ticket_id == 0, 8);
        assert!(option::is_none(&event_pending_opt), 9);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_values = test_utils::unwrap(snapshot_opt);
        let (
            ticket_count,
            draw_scheduled,
            has_pending_request,
            next_ticket_id,
            pending_after_fulfill,
        ) = rounds::round_snapshot_fields_for_test(&snapshot_values);
        assert!(ticket_count == 0, 10);
        assert!(!draw_scheduled, 11);
        assert!(!has_pending_request, 12);
        assert!(next_ticket_id == 0, 13);
        assert!(option::is_none(&pending_after_fulfill), 14);


        let buyer_addr = signer::address_of(buyer);
        assert!(treasury_v1::balance_of(buyer_addr) == 9_940, 15);

        assert!(treasury_v1::treasury_balance() == 60, 16);
        let pool = test_utils::unwrap(treasury_multi::get_pool(lottery_id));
        let (prize_balance, operations_balance) =
            treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 0, 17);
        assert!(operations_balance == 20, 18);
        assert!(treasury_multi::jackpot_balance() == 40, 19);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
    )]
    #[expected_failure(abort_code = 7)]
    fun schedule_without_tickets_fails(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        setup_token(lottery_admin, lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(25, 500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::schedule_draw(lottery_admin, lottery_id);
    }
}
