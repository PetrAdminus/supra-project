#[test_only]
module lottery_utils::history_warden_migration_tests {
    use lottery_data::rounds;
    use lottery_utils::history;

    #[test(lottery_admin = @lottery)]
    fun caps_can_be_issued_and_returned(
        lottery_admin: &signer,
    ) acquires history::HistoryCollection, history::HistoryWarden, rounds::RoundControl {
        rounds::init_control(lottery_admin);
        history::init(lottery_admin);

        assert!(!history::caps_ready(), 0);

        history::ensure_caps_initialized(lottery_admin);
        assert!(history::caps_ready(), 1);

        history::release_caps(lottery_admin);
        assert!(!history::caps_ready(), 2);

        history::ensure_caps_initialized(lottery_admin);
        assert!(history::caps_ready(), 3);
    }
}
