module std::account {
    #[test_only]
    native public fun create_account_for_test(addr: address);

    #[test_only]
    native public fun create_signer_for_test(addr: address): signer;
}
