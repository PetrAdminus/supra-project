#[test_only]
module lottery_data::operators_ready_tests {
    use lottery_data::operators;
    use std::option;
    use std::signer;
    use std::vector;

    #[test(lottery_admin = @lottery, owner = @operator_owner, bot = @automation_bot)]
    fun operator_ready_snapshot_flow(lottery_admin: &signer, owner: address, bot: address) {
        assert!(!operators::is_initialized(), 0);
        assert!(!operators::ready(), 1);
        assert!(option::is_none(&operators::operator_snapshot(1)), 2);

        operators::init_registry(lottery_admin);

        assert!(operators::is_initialized(), 3);
        assert!(operators::ready(), 4);
        assert!(option::is_none(&operators::operator_snapshot(1)), 5);

        let record = operators::LegacyOperatorRecord {
            lottery_id: 1,
            owner: option::some(owner),
            operators: vector::singleton(bot),
        };
        operators::import_existing_operator_record(lottery_admin, record);

        let snapshot_opt = operators::operator_snapshot(1);
        assert!(option::is_some(&snapshot_opt), 6);

        let snapshot_ref = option::borrow(&snapshot_opt);
        assert!(snapshot_ref.owner == option::some(owner), 7);
        assert!(vector::length(&snapshot_ref.operators) == 1, 8);
        assert!(*vector::borrow(&snapshot_ref.operators, 0) == bot, 9);
    }
}
