#[test_only]
module lottery_data::operators_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::operators;

    #[test(lottery_admin = @lottery)]
    fun import_existing_records_restore_snapshot(lottery_admin: &signer) {
        operators::init_registry(lottery_admin);

        let mut first_ops = vector::empty<address>();
        vector::push_back(&mut first_ops, @0xA01);

        let mut second_ops = vector::empty<address>();
        vector::push_back(&mut second_ops, @0xB02);
        vector::push_back(&mut second_ops, @0xC03);

        let mut records = vector::empty<operators::LegacyOperatorRecord>();
        vector::push_back(
            &mut records,
            operators::LegacyOperatorRecord {
                lottery_id: 11,
                owner: option::some(@0x100),
                operators: first_ops,
            },
        );
        vector::push_back(
            &mut records,
            operators::LegacyOperatorRecord {
                lottery_id: 22,
                owner: option::none<address>(),
                operators: second_ops,
            },
        );

        operators::import_existing_operator_records(lottery_admin, records);

        let registry = operators::registry_snapshot();
        assert!(registry.admin == @lottery, 0);
        assert!(vector::length(&registry.lottery_ids) == 2, 1);

        let first_snapshot_opt = operators::operator_snapshot(11);
        assert!(option::is_some(&first_snapshot_opt), 2);
        let first_snapshot = option::destroy_some(first_snapshot_opt);
        assert!(first_snapshot.owner == option::some(@0x100), 3);
        assert!(vector::length(&first_snapshot.operators) == 1, 4);
        assert!(*vector::borrow(&first_snapshot.operators, 0) == @0xA01, 5);

        let second_snapshot_opt = operators::operator_snapshot(22);
        assert!(option::is_some(&second_snapshot_opt), 6);
        let second_snapshot = option::destroy_some(second_snapshot_opt);
        assert!(option::is_none(&second_snapshot.owner), 7);
        assert!(vector::length(&second_snapshot.operators) == 2, 8);
        assert!(*vector::borrow(&second_snapshot.operators, 0) == @0xC03, 9);
        assert!(*vector::borrow(&second_snapshot.operators, 1) == @0xB02, 10);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_owner_and_operator_list(lottery_admin: &signer) {
        operators::init_registry(lottery_admin);

        let mut initial_ops = vector::empty<address>();
        vector::push_back(&mut initial_ops, @0xF10);
        vector::push_back(&mut initial_ops, @0xF20);

        operators::import_existing_operator_record(
            lottery_admin,
            operators::LegacyOperatorRecord {
                lottery_id: 33,
                owner: option::none<address>(),
                operators: initial_ops,
            },
        );

        let mut new_ops = vector::empty<address>();
        vector::push_back(&mut new_ops, @0xE30);

        operators::import_existing_operator_record(
            lottery_admin,
            operators::LegacyOperatorRecord {
                lottery_id: 33,
                owner: option::some(@0x222),
                operators: new_ops,
            },
        );

        let registry = operators::registry_snapshot();
        assert!(vector::length(&registry.lottery_ids) == 1, 11);
        assert!(*vector::borrow(&registry.lottery_ids, 0) == 33, 12);

        let snapshot_opt = operators::operator_snapshot(33);
        assert!(option::is_some(&snapshot_opt), 13);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.owner == option::some(@0x222), 14);
        assert!(vector::length(&snapshot.operators) == 1, 15);
        assert!(*vector::borrow(&snapshot.operators, 0) == @0xE30, 16);
    }
}
