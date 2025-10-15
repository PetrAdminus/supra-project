#[test_only]
module lottery::test_utils {
    use std::account;
    use std::option;
    use std::timestamp;

    public fun unwrap<T>(opt: option::Option<T>): T {
        option::destroy_some(opt)
    }

    public fun ensure_framework_accounts_for_test() {
        account::create_account_for_test(@lottery);
        account::create_account_for_test(@lottery_factory);
        account::create_account_for_test(@vrf_hub);
        account::create_account_for_test(@lottery_owner);
        account::create_account_for_test(@lottery_contract);
        account::create_account_for_test(@supra_framework);
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        account::create_account_for_test(@player1);
        account::create_account_for_test(@player2);
        account::create_account_for_test(@player3);
        account::create_account_for_test(@player4);
        account::create_account_for_test(@0x123);
        account::create_account_for_test(@0x456);
        account::create_account_for_test(@0x789);
        account::create_account_for_test(@0xa11ce);
        account::create_account_for_test(@0xb0b0);
        account::create_account_for_test(@0x45);
        account::create_account_for_test(@0x46);
        account::create_account_for_test(@0x55);
        account::create_account_for_test(@0x56);
        account::create_account_for_test(@0xa);
        account::create_account_for_test(@0xb);
        account::create_account_for_test(@0xc);
        account::create_account_for_test(@0x4);
        account::create_account_for_test(@0x10);
        account::create_account_for_test(@0x11);
        account::create_account_for_test(@0x12);
        account::create_account_for_test(@0x13);
        account::create_account_for_test(@0x14);

        let framework = account::create_signer_for_test(@supra_framework);
        timestamp::set_time_has_started_for_testing(&framework);
    }
}
