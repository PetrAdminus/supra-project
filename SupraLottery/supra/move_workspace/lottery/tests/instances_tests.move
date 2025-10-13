#[test_only]
module lottery::instances_tests {
    use std::vector;
    use lottery::instances;
    use lottery::test_utils;
    use lottery_factory::registry;
    use vrf_hub::hub;
    use supra_framework::event;

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    fun create_and_sync_flow(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);

        let blueprint = registry::new_blueprint(10, 500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        assert!(lottery_id == 1, 0);

        instances::create_instance(lottery_admin, lottery_id);
        assert!(instances::instance_count() == 1, 1);
        assert!(instances::contains_instance(lottery_id), 2);
        assert!(instances::is_instance_active(lottery_id), 3);

        let initial_snapshot = test_utils::unwrap(instances::get_instance_snapshot(lottery_id));
        let (
            snapshot_id,
            snapshot_owner,
            snapshot_lottery,
            snapshot_price,
            snapshot_share,
            snapshot_tickets,
            snapshot_jackpot,
            snapshot_active,
        ) = instances::instance_snapshot_fields_for_test(&initial_snapshot);
        assert!(snapshot_id == lottery_id, 14);
        assert!(snapshot_owner == @lottery_owner, 15);
        assert!(snapshot_lottery == @lottery_contract, 16);
        assert!(snapshot_price == 10, 17);
        assert!(snapshot_share == 500, 18);
        assert!(snapshot_tickets == 0, 19);
        assert!(snapshot_jackpot == 0, 20);
        assert!(snapshot_active, 21);

        let collection_snapshot = test_utils::unwrap(instances::get_instances_snapshot());
        let (collection_admin, collection_hub, collection_entries) =
            instances::instances_snapshot_fields_for_test(&collection_snapshot);
        assert!(collection_admin == @lottery, 22);
        assert!(collection_hub == @vrf_hub, 23);
        assert!(vector::length(&collection_entries) == 1, 24);

        let info = test_utils::unwrap(instances::get_lottery_info(lottery_id));
        let (owner, lottery_addr, ticket_price, jackpot_share_bps) =
            registry::lottery_info_fields_for_test(&info);
        assert!(owner == @lottery_owner, 4);
        assert!(lottery_addr == @lottery_contract, 5);
        assert!(ticket_price == 10, 6);
        assert!(jackpot_share_bps == 500, 7);

        let updated_blueprint = registry::new_blueprint(25, 800);
        registry::update_blueprint(factory_admin, lottery_id, updated_blueprint);
        instances::sync_blueprint(lottery_admin, lottery_id);

        let synced_info = test_utils::unwrap(instances::get_lottery_info(lottery_id));
        let (_owner_sync, _lottery_sync, synced_price, synced_share) =
            registry::lottery_info_fields_for_test(&synced_info);
        assert!(synced_price == 25, 8);
        assert!(synced_share == 800, 9);

        let updated_snapshot = test_utils::unwrap(instances::get_instance_snapshot(lottery_id));
        let (
            _updated_id,
            _updated_owner,
            _updated_lottery,
            updated_price,
            updated_share,
            _updated_tickets,
            _updated_jackpot,
            updated_active,
        ) = instances::instance_snapshot_fields_for_test(&updated_snapshot);
        assert!(updated_price == 25, 25);
        assert!(updated_share == 800, 26);
        assert!(updated_active, 27);

        let snapshot_events = event::emitted_events<instances::LotteryInstancesSnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events) == 2, 28);
        let last_event = vector::borrow(&snapshot_events, 1);
        let (event_admin, event_hub, event_snapshot) =
            instances::snapshot_event_fields_for_test(last_event);
        assert!(event_admin == @lottery, 29);
        assert!(event_hub == @vrf_hub, 30);
        let (
            event_lottery_id,
            _event_owner,
            _event_lottery,
            event_price,
            event_share,
            _event_tickets,
            _event_jackpot,
            event_active,
        ) = instances::instance_snapshot_fields_for_test(&event_snapshot);
        assert!(event_lottery_id == lottery_id, 31);
        assert!(event_price == 25, 32);
        assert!(event_share == 800, 33);
        assert!(event_active, 34);

        let ids = instances::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 10);
        assert!(*vector::borrow(&ids, 0) == lottery_id, 11);

        let active_ids = instances::list_active_lottery_ids();
        assert!(vector::length(&active_ids) == 1, 12);
        assert!(*vector::borrow(&active_ids, 0) == lottery_id, 13);
    }

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    #[expected_failure(abort_code = 7)]
    fun cannot_create_without_registration(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);

        instances::create_instance(lottery_admin, 42);
    }

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    fun toggle_activity_flow(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);

        let blueprint = registry::new_blueprint(10, 500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);

        hub::set_lottery_active(vrf_admin, lottery_id, false);
        instances::set_instance_active(lottery_admin, lottery_id, false);
        assert!(!instances::is_instance_active(lottery_id), 0);
        let active_empty = instances::list_active_lottery_ids();
        assert!(vector::length(&active_empty) == 0, 1);

        let snapshot_after_deactivate =
            test_utils::unwrap(instances::get_instance_snapshot(lottery_id));
        let (
            _after_id,
            _after_owner,
            _after_lottery,
            _after_price,
            _after_share,
            _after_tickets,
            _after_jackpot,
            after_active,
        ) = instances::instance_snapshot_fields_for_test(&snapshot_after_deactivate);
        assert!(!after_active, 3);

        hub::set_lottery_active(vrf_admin, lottery_id, true);
        instances::set_instance_active(lottery_admin, lottery_id, true);
        assert!(instances::is_instance_active(lottery_id), 2);

        let events = event::emitted_events<instances::LotteryInstancesSnapshotUpdatedEvent>();
        // create_instance + deactivate + activate = 3 snapshot events
        assert!(vector::length(&events) == 3, 4);
    }

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    #[expected_failure(abort_code = 9)]
    fun toggle_requires_synced_hub(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_framework_accounts_for_test();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);

        let blueprint = registry::new_blueprint(10, 500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);


        instances::set_instance_active(lottery_admin, lottery_id, false);
    }
}
