#[test_only]
module lottery_data::jackpot_ready_tests {
    use lottery_data::jackpot;

    #[test(lottery_admin = @lottery)]
    fun jackpot_ready_flow(lottery_admin: &signer) {
        assert!(!jackpot::ready(), 0);

        jackpot::init_registry(lottery_admin);
        assert!(jackpot::ready(), 1);

        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::register_jackpot(registry, 7);
        assert!(jackpot::ready(), 2);

        jackpot::test_force_pending_mismatch(7);
        assert!(!jackpot::ready(), 3);

        jackpot::test_restore_pending_state(7);
        assert!(jackpot::ready(), 4);
    }
}
