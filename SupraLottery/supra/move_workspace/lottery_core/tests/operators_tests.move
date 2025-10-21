#[test_only]
module lottery_core::operators_tests {
    use std::vector;
    use std::signer;
    use lottery_core::operators;
    use lottery_core::test_utils;

    #[test(lottery_admin = @lottery, owner = @player1, operator = @player2)]
    fun admin_assigns_and_grants(
        lottery_admin: &signer,
        owner: &signer,
        operator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        operators::init(lottery_admin);
        let _ = test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
        operators::set_owner(lottery_admin, 0, signer::address_of(owner));

        let owner_opt = operators::get_owner(0);
        let owner_addr = test_utils::unwrap(&mut owner_opt);
        assert!(owner_addr == signer::address_of(owner), 0);

        let snapshot = operators::get_operator_snapshot(0);
        let (snapshot_owner_opt, snapshot_operators) =
            operators::operator_snapshot_fields_for_test(&snapshot);
        let snapshot_owner = test_utils::unwrap(&mut snapshot_owner_opt);
        assert!(snapshot_owner == signer::address_of(owner), 6);
        assert!(vector::length(&snapshot_operators) == 0, 7);

        // Baseline before granting operator (snapshot)
        let baseline = {
            let ev = test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
            test_utils::events_len(&ev)
        };

        // Strict baseline for OperatorGrantedEvent (core)
        let granted_baseline = {
            let ev = test_utils::drain_events<operators::OperatorGrantedEvent>();
            test_utils::events_len(&ev)
        };

        operators::grant_operator(lottery_admin, 0, signer::address_of(operator));
        assert!(operators::is_operator(0, signer::address_of(operator)), 1);

        // Strict: exactly one OperatorGrantedEvent emitted
        let granted_events = test_utils::drain_events<operators::OperatorGrantedEvent>();
        test_utils::assert_grew_by<operators::OperatorGrantedEvent>(
            granted_baseline,
            &granted_events,
            0,
            100,
        );

        let operators_list_opt = operators::list_operators(0);
        let operators_list = test_utils::unwrap(&mut operators_list_opt);
        assert!(vector::length(&operators_list) == 1, 2);
        assert!(*vector::borrow(&operators_list, 0) == signer::address_of(operator), 3);

        let snapshot_after_grant = operators::get_operator_snapshot(0);
        let (owner_after_grant_opt, operators_after_grant) =
            operators::operator_snapshot_fields_for_test(&snapshot_after_grant);
        let owner_after_grant = test_utils::unwrap(&mut owner_after_grant_opt);
        assert!(owner_after_grant == signer::address_of(owner), 8);
        assert!(vector::length(&operators_after_grant) == 1, 9);
        assert!(*vector::borrow(&operators_after_grant, 0) == signer::address_of(operator), 10);

        let lotteries = operators::list_lottery_ids();
        assert!(vector::length(&lotteries) == 1, 4);
        assert!(*vector::borrow(&lotteries, 0) == 0, 5);

        let snapshot_events =
            test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
        let snapshot_events_len = vector::length(&snapshot_events);
        test_utils::assert_grew_by<operators::OperatorSnapshotUpdatedEvent>(
            baseline,
            &snapshot_events,
            0,
            11,
        );
        if (snapshot_events_len > 1) {
            let initial_event = vector::borrow(&snapshot_events, 0);
            let (
                initial_lottery,
                initial_owner_opt,
                initial_operators,
            ) = operators::operator_snapshot_event_fields_for_test(initial_event);
            assert!(initial_lottery == 0, 12);
            let initial_owner = test_utils::unwrap(&mut initial_owner_opt);
            assert!(initial_owner == signer::address_of(owner), 13);
            assert!(vector::length(&initial_operators) == 0, 14);
        };

        if (snapshot_events_len > 0) {
            let grant_event = test_utils::last_event_ref(&snapshot_events);
            let (grant_lottery, grant_owner_opt, grant_operators) =
                operators::operator_snapshot_event_fields_for_test(grant_event);
            assert!(grant_lottery == 0, 15);
            let grant_owner = test_utils::unwrap(&mut grant_owner_opt);
            assert!(grant_owner == signer::address_of(owner), 16);
            assert!(vector::length(&grant_operators) == 1, 17);
            assert!(*vector::borrow(&grant_operators, 0) == signer::address_of(operator), 18);
        };
    }

    #[test(lottery_admin = @lottery, owner = @player1, operator = @player2)]
    fun owner_can_manage(
        lottery_admin: &signer,
        owner: &signer,
        operator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        operators::init(lottery_admin);
        let _ = test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
        operators::set_owner(lottery_admin, 7, signer::address_of(owner));

        operators::grant_operator(owner, 7, signer::address_of(operator));
        assert!(operators::is_operator(7, signer::address_of(operator)), 10);

        let snapshot_after_grant = operators::get_operator_snapshot(7);
        let (owner_after_grant_opt, operators_after_grant) =
            operators::operator_snapshot_fields_for_test(&snapshot_after_grant);
        let owner_after_grant = test_utils::unwrap(&mut owner_after_grant_opt);
        assert!(owner_after_grant == signer::address_of(owner), 19);
        assert!(vector::length(&operators_after_grant) == 1, 20);

        // Baseline before revoke (snapshot)
        let baseline = {
            let ev = test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
            test_utils::events_len(&ev)
        };

        // Strict baseline for OperatorRevokedEvent (core)
        let revoked_baseline = {
            let ev = test_utils::drain_events<operators::OperatorRevokedEvent>();
            test_utils::events_len(&ev)
        };

        operators::revoke_operator(owner, 7, signer::address_of(operator));
        assert!(!operators::is_operator(7, signer::address_of(operator)), 11);

        // Strict: exactly one OperatorRevokedEvent emitted
        let revoked_events = test_utils::drain_events<operators::OperatorRevokedEvent>();
        test_utils::assert_grew_by<operators::OperatorRevokedEvent>(
            revoked_baseline,
            &revoked_events,
            0,
            101,
        );

        let operators_after_opt = operators::list_operators(7);
        let operators_after = test_utils::unwrap(&mut operators_after_opt);
        assert!(vector::length(&operators_after) == 0, 12);

        let snapshot_after_revoke = operators::get_operator_snapshot(7);
        let (owner_after_revoke_opt, operators_after_revoke) =
            operators::operator_snapshot_fields_for_test(&snapshot_after_revoke);
        let owner_after_revoke = test_utils::unwrap(&mut owner_after_revoke_opt);
        assert!(owner_after_revoke == signer::address_of(owner), 21);
        assert!(vector::length(&operators_after_revoke) == 0, 22);

        let snapshot_events =
            test_utils::drain_events<operators::OperatorSnapshotUpdatedEvent>();
        let snapshot_events_len = vector::length(&snapshot_events);
        test_utils::assert_grew_by<operators::OperatorSnapshotUpdatedEvent>(
            baseline,
            &snapshot_events,
            0,
            23,
        );
        if (vector::length(&snapshot_events) > 0) {
            let revoke_event = test_utils::last_event_ref(&snapshot_events);
            let (revoke_lottery, revoke_owner_opt, revoke_operators) =
                operators::operator_snapshot_event_fields_for_test(revoke_event);
            assert!(revoke_lottery == 7, 24);
            let revoke_owner = test_utils::unwrap(&mut revoke_owner_opt);
            assert!(revoke_owner == signer::address_of(owner), 25);
            assert!(vector::length(&revoke_operators) == 0, 26);
        };
    }

    #[test(lottery_admin = @lottery, owner = @player1, intruder = @player2, operator = @player3)]
    #[expected_failure(
        location = lottery_core::operators,
        abort_code = operators::E_NOT_AUTHORIZED,
    )]
    fun unauthorized_cannot_grant(
        lottery_admin: &signer,
        owner: &signer,
        intruder: &signer,
        operator: &signer,
    ) {
        test_utils::ensure_core_accounts();
        operators::init(lottery_admin);
        operators::set_owner(lottery_admin, 42, signer::address_of(owner));

        operators::grant_operator(intruder, 42, signer::address_of(operator));
    }
}
