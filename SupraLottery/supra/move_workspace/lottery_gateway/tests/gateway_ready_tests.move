#[test_only]
module lottery_gateway::gateway_ready_tests {
    use std::option;

    use lottery_data::instances;
    use lottery_gateway::gateway;
    use lottery_gateway::history;
    use lottery_gateway::registry;

    #[test(lottery_admin = @lottery)]
    fun gateway_initialization_sets_registry_ready(lottery_admin: &signer) {
        assert!(!gateway::is_initialized(), 0);
        assert!(!registry::ready(), 1);
        assert!(!history::is_initialized(), 2);

        instances::init_registry(lottery_admin, @lottery);
        gateway::init(lottery_admin, @lottery);

        assert!(gateway::is_initialized(), 3);
        assert!(history::is_initialized(), 4);
        assert!(registry::ready(), 5);

        let snapshot_opt = gateway::gateway_snapshot();
        assert!(option::is_some(&snapshot_opt), 6);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.total_lotteries == 0, 7);
        assert!(snapshot.next_lottery_id == 1, 8);
    }
}
