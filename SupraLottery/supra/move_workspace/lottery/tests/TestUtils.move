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
        let framework = account::create_signer_for_test(@supra_framework);
        timestamp::set_time_has_started_for_testing(&framework);
    }
}
