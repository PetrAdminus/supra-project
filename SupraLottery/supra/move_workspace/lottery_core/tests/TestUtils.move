#[test_only]
module lottery_core::test_utils {
    use lottery_core::core_instances as instances;
    use lottery_core::core_main_v2 as main_v2;
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_treasury_multi as treasury_multi;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_factory::registry;
    use std::account;
    use std::option;
    use std::signer;
    use std::timestamp;
    use std::vector;
    use supra_framework::event;
    use lottery_vrf_gateway::hub;

    const FRAMEWORK_ADDRESS: address = @SupraFramework;
    const TREASURY_TEST_FUNDS: u64 = 1_000_000;

    public fun ensure_core_accounts() {
        account::create_account_for_test(FRAMEWORK_ADDRESS);
        init_time_for_tests();
        account::create_account_for_test(@lottery);
        account::create_account_for_test(@lottery_factory);
        account::create_account_for_test(@lottery_owner);
        account::create_account_for_test(@lottery_contract);
        account::create_account_for_test(@lottery_vrf_gateway);
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        account::create_account_for_test(@player1);
        account::create_account_for_test(@player2);
        account::create_account_for_test(@player3);
        account::create_account_for_test(@player4);
        account::create_account_for_test(@0x45);
        account::create_account_for_test(@0x46);
        account::create_account_for_test(@0x55);
        account::create_account_for_test(@0x56);
        account::create_account_for_test(@0x123);
        account::create_account_for_test(@0x456);
        account::create_account_for_test(@0x789);
        account::create_account_for_test(@0xa11ce);
        account::create_account_for_test(@0xb0b0);
        account::create_account_for_test(@0x501);
        account::create_account_for_test(@0x502);
    }

    public fun ensure_time_started() {
        init_time_for_tests();
    }

    public fun init_time_for_tests() {
        account::create_account_for_test(FRAMEWORK_ADDRESS);
        let framework_signer = account::create_signer_for_test(FRAMEWORK_ADDRESS);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        let current_time = timestamp::now_microseconds();
        if (current_time < 1) {
            timestamp::update_global_time_for_test(1);
        };
    }

    public fun unwrap<T>(o: &mut option::Option<T>): T {
        option::extract(o)
    }

    public fun unwrap_copy<T: copy>(o: &option::Option<T>): T {
        *option::borrow(o)
    }

    public fun drain_events<EventT: drop + store>(): vector<EventT> {
        event::emitted_events<EventT>()
    }

    public fun events_len<EventT: drop + store>(events: &vector<EventT>): u64 {
        vector::length(events)
    }

    public fun assert_grew_by<EventT: drop + store>(
        baseline: u64,
        events: &vector<EventT>,
        expected_delta: u64,
        error_code: u64,
    ) {
        assert!(vector::length(events) >= baseline + expected_delta, error_code);
    }

    // Requires exact growth by expected_delta
    public fun assert_delta_eq<EventT: drop + store>(
        baseline: u64,
        events: &vector<EventT>,
        expected_delta: u64,
        error_code: u64,
    ) {
        assert!(vector::length(events) == baseline + expected_delta, error_code);
    }

    // Requires events length to equal expected
    public fun assert_len_eq<EventT: drop + store>(
        events: &vector<EventT>,
        expected: u64,
        error_code: u64,
    ) {
        assert!(vector::length(events) == expected, error_code);
    }

    public fun assert_min_events<EventT: drop + store>(
        events: &vector<EventT>,
        min_expected: u64,
        error_code: u64,
    ) {
        assert!(vector::length(events) >= min_expected, error_code);
    }

    public fun last_event_ref<EventT: drop + store>(events: &vector<EventT>): &EventT {
        let len = vector::length(events);
        assert!(len > 0, 9001);
        vector::borrow(events, len - 1)
    }

    public fun treasury_test_funds(): u64 {
        TREASURY_TEST_FUNDS
    }

    public fun sample_randomness(): vector<u8> {
        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, 1);
        vector::push_back(&mut randomness, 2);
        vector::push_back(&mut randomness, 3);
        vector::push_back(&mut randomness, 4);
        vector::push_back(&mut randomness, 5);
        vector::push_back(&mut randomness, 6);
        vector::push_back(&mut randomness, 7);
        vector::push_back(&mut randomness, 8);
        randomness
    }

    public fun setup_round_with_pending_draw(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
        player: &signer,
    ): (u64, u64, u64) {
        ensure_core_accounts();
        if (!hub::is_initialized()) {
            hub::init(vrf_admin);
        };
        if (!registry::is_initialized()) {
            registry::init(factory_admin);
        };
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                lottery_admin,
                b"seed",
                b"Lottery Token",
                b"LOT",
                6,
                b"",
                b"",
            );
        };
        if (!treasury_v1::is_core_control_initialized()) {
            treasury_v1::init(lottery_admin);
        };
        treasury_v1::register_store(player);
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store_for(lottery_admin, signer::address_of(player));
        let current_balance = treasury_v1::balance_of(@lottery);
        if (current_balance < TREASURY_TEST_FUNDS) {
            let missing = TREASURY_TEST_FUNDS - current_balance;
            treasury_v1::mint_to(lottery_admin, @lottery, missing);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        };
        if (!main_v2::is_initialized()) {
            main_v2::init(lottery_admin);
        };
        let aggregator = signer::address_of(vrf_admin);
        hub::set_callback_sender(vrf_admin, aggregator);
        main_v2::set_callback_aggregator_for_test(option::some(aggregator));
        if (!instances::is_initialized()) {
            instances::init(lottery_admin, @lottery_vrf_gateway);
        };
        if (!rounds::is_initialized()) {
            rounds::init(lottery_admin);
        };

        let blueprint = registry::new_blueprint(100, 1_000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 6_000, 3_000, 1_000);

        let autop_cap = rounds::borrow_autopurchase_round_cap(lottery_admin);
        let total_paid = rounds::record_prepaid_purchase(
            &autop_cap,
            lottery_id,
            signer::address_of(player),
            2,
        );
        rounds::return_autopurchase_round_cap(lottery_admin, autop_cap);

        rounds::schedule_draw(lottery_admin, lottery_id);
        rounds::request_randomness(lottery_admin, lottery_id, vector::empty<u8>());
        let pending = rounds::pending_request_id(lottery_id);
        let request_id = unwrap(&mut pending);
        (lottery_id, request_id, total_paid)
    }
}

