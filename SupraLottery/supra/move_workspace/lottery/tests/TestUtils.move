#[test_only]
module lottery::test_utils {
    use std::account;
    use std::option;

    public fun ensure_core_accounts() {
        account::create_account_for_test(@lottery);
        account::create_account_for_test(@lottery_factory);
        account::create_account_for_test(@lottery_owner);
        account::create_account_for_test(@lottery_contract);
        account::create_account_for_test(@vrf_hub);
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
    }

    public fun unwrap<T>(o: &mut option::Option<T>): T {
        assert!(option::is_some(o), 9);
        option::extract(o)
    }

    public fun unwrap_copy<T: copy>(o: &option::Option<T>): T {
        assert!(option::is_some(o), 9);
        *option::borrow(o)
    }
}