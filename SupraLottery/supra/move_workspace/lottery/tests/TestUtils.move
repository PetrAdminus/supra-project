
#[test_only]
module lottery::test_utils {
    use std::account;
    use std::option;
    use std::timestamp;
    use std::vector;
    use supra_framework::event;

    const FRAMEWORK_ADDRESS: address = @SupraFramework;

    public fun ensure_core_accounts() {
        account::create_account_for_test(FRAMEWORK_ADDRESS);
        ensure_time_started_internal();
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
        account::create_account_for_test(FRAMEWORK_ADDRESS);
        ensure_time_started_internal();
    }

    public fun unwrap<T>(o: &mut option::Option<T>): T {
        option::extract(o)
    }

    public fun unwrap_copy<T: copy>(o: &option::Option<T>): T {
        assert!(option::is_some(o), 9);
        *option::borrow(o)
    }

    public fun drain_events<EventT: drop + store>(): vector<EventT> {
        event::emitted_events<EventT>()
    }

    public fun last_event_ref<EventT: drop + store>(events: &vector<EventT>): &EventT {
        let len = vector::length(events);
        assert!(len > 0, 9001);
        vector::borrow(events, len - 1)
    }

    fun ensure_time_started_internal() {
        let framework_signer = account::create_signer_for_test(FRAMEWORK_ADDRESS);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        let current_time = timestamp::now_microseconds();
        if (current_time < 1) {
            timestamp::update_global_time_for_test(1);
        };
    }
}
