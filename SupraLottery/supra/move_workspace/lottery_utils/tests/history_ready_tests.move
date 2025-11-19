#[test_only]
module lottery_utils::history_ready_tests {
    use lottery_data::rounds;
    use lottery_utils::history;

    #[test(lottery_admin = @lottery)]
    fun history_ready_requires_history_cap(lottery_admin: &signer) {
        assert!(!history::is_initialized(), 0);
        assert!(!history::caps_ready(), 1);
        assert!(!history::ready(), 2);

        rounds::init_control(lottery_admin);
        history::init(lottery_admin);
        assert!(history::is_initialized(), 3);
        assert!(!history::caps_ready(), 4);
        assert!(!history::ready(), 5);

        history::ensure_caps_initialized(lottery_admin);
        assert!(history::caps_ready(), 6);
        assert!(history::ready(), 7);
    }
}
