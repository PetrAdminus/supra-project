module lottery::history_tests {
    use std::option;
    use std::vector;
    use std::account;
    use std::timestamp;
    use std::signer;
    use lottery::history;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
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

    fun ensure_time_started() {
        let framework = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player6,
        aggregator = @0x55,
    )]
    fun records_draw_history(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        ensure_time_started();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        history::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

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
        let request_id = option::extract(rounds::pending_request_id(lottery_id));

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
        let records = option::extract(history_opt);
        assert!(vector::length(&records) == 1, 0);
        let record = *vector::borrow(&records, 0);
        assert!(record.request_id == request_id, 1);
        assert!(record.winner == signer::address_of(buyer), 2);
        assert!(record.ticket_index == 0, 3);
        assert!(record.prize_amount > 0, 4);
        assert!(vector::length(&record.random_bytes) == 8, 5);
        assert!(record.payload == b"log", 6);

        let ids = history::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 7);
        assert!(*vector::borrow(&ids, 0) == lottery_id, 8);

        let latest_opt = history::latest_record(lottery_id);
        let latest = option::extract(latest_opt);
        assert!(latest.request_id == record.request_id, 9);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player7,
        aggregator = @0x56,
    )]
    fun clear_history_resets_records(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        ensure_time_started();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        history::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

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
        let request_id = option::extract(rounds::pending_request_id(lottery_id));

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

        let records_before = option::extract(history::get_history(lottery_id));
        assert!(vector::length(&records_before) == 1, 0);

        history::clear_history(lottery_admin, lottery_id);

        let records_after_opt = history::get_history(lottery_id);
        let records_after = option::extract(records_after_opt);
        assert!(vector::is_empty(&records_after), 1);

        let latest_opt = history::latest_record(lottery_id);
        assert!(option::is_none(&latest_opt), 2);
    }
}
