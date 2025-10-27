#[test_only]
module lottery_rewards::rewards_test_utils {
    use lottery_core::instances;
    use lottery_core::rounds;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use std::account;
    use std::option;
    use std::timestamp;
    use std::vector;
    use supra_framework::event;
    use vrf_hub::hub;
    use lottery_rewards::autopurchase;

    const FRAMEWORK_ADDRESS: address = @SupraFramework;

    public fun ensure_core_accounts() {
        account::create_account_for_test(FRAMEWORK_ADDRESS);
        init_time_for_tests();
        account::create_account_for_test(@lottery);
        account::create_account_for_test(@lottery_factory);
        account::create_account_for_test(@lottery_owner);
        account::create_account_for_test(@lottery_contract);
        account::create_account_for_test(@vrf_hub);
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

    public fun bootstrap_multi_treasury(
        admin: &signer,
        factory: &signer,
        vrf_admin: &signer,
    ) {
        ensure_core_accounts();
        ensure_time_started();
        if (!hub::is_initialized()) {
            hub::init(vrf_admin);
        };
        if (!registry::is_initialized()) {
            registry::init(factory);
        };
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                admin,
                b"seed",
                b"Lottery Token",
                b"LOT",
                6,
                b"",
                b"",
            );
        };
        if (!treasury_v1::is_core_control_initialized()) {
            treasury_v1::init(admin);
        };
        treasury_v1::register_store_for(admin, @jackpot_pool);
        treasury_v1::register_store_for(admin, @operations_pool);
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(admin, @jackpot_pool, @operations_pool);
        };
        if (!instances::is_initialized()) {
            instances::init(admin, @vrf_hub);
        };
        if (!rounds::is_initialized()) {
            rounds::init(admin);
        };
    }

    public fun ensure_autopurchase_initialized(admin: &signer) {
        if (!autopurchase::is_initialized()) {
            autopurchase::init(admin);
        } else {
            autopurchase::ensure_caps_initialized(admin);
        };
    }
}
