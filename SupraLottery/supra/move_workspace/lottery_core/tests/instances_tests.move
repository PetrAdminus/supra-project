#[test_only]
module lottery_core::instances_tests {
    use std::vector;
    use lottery_core::instances;
    use lottery_core::test_utils;
    use lottery_factory::registry;
    use vrf_hub::hub;

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    fun create_and_sync_flow(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);

        let _ = test_utils::drain_events<instances::LotteryInstancesSnapshotUpdatedEvent>();

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

        let initial_snapshot_opt = instances::get_instance_snapshot(lottery_id);
        let initial_snapshot = test_utils::unwrap(&mut initial_snapshot_opt);
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

        let collection_snapshot_opt = instances::get_instances_snapshot();
        let collection_snapshot = test_utils::unwrap(&mut collection_snapshot_opt);
        let (collection_admin, collection_hub, collection_entries) =
            instances::instances_snapshot_fields_for_test(&collection_snapshot);
        assert!(collection_admin == @lottery, 22);
        assert!(collection_hub == @vrf_hub, 23);
        assert!(vector::length(&collection_entries) == 1, 24);

        let info_opt = instances::get_lottery_info(lottery_id);
        let info = test_utils::unwrap(&mut info_opt);
        let (owner, lottery_addr, ticket_price, jackpot_share_bps) =
            registry::lottery_info_fields_for_test(&info);
        assert!(owner == @lottery_owner, 4);
        assert!(lottery_addr == @lottery_contract, 5);
        assert!(ticket_price == 10, 6);
        assert!(jackpot_share_bps == 500, 7);

        let updated_blueprint = registry::new_blueprint(25, 800);
        registry::update_blueprint(factory_admin, lottery_id, updated_blueprint);

        let baseline = {
            let ev = test_utils::drain_events<instances::LotteryInstancesSnapshotUpdatedEvent>();
            test_utils::events_len(&ev)
        };

        instances::sync_blueprint(lottery_admin, lottery_id);

        let synced_info_opt = instances::get_lottery_info(lottery_id);
        let synced_info = test_utils::unwrap(&mut synced_info_opt);
        let (_owner_sync, _lottery_sync, synced_price, synced_share) =
            registry::lottery_info_fields_for_test(&synced_info);
        assert!(synced_price == 25, 8);
        assert!(synced_share == 800, 9);

        let updated_snapshot_opt = instances::get_instance_snapshot(lottery_id);
        let updated_snapshot = test_utils::unwrap(&mut updated_snapshot_opt);
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

        let snapshot_events =
            test_utils::drain_events<instances::LotteryInstancesSnapshotUpdatedEvent>();
        let snapshot_events_len = vector::length(&snapshot_events);
        test_utils::assert_grew_by<instances::LotteryInstancesSnapshotUpdatedEvent>(
            baseline,
            &snapshot_events,
            0,
            28,
        );
        if (snapshot_events_len > 1) {
            let first_event = vector::borrow(&snapshot_events, 0);
            let (first_admin, first_hub, first_snapshot) =
                instances::snapshot_event_fields_for_test(first_event);
            assert!(first_admin == @lottery, 29);
            assert!(first_hub == @vrf_hub, 30);
            let (
                first_lottery_id,
                _first_owner,
                _first_lottery,
                first_price,
                first_share,
                _first_tickets,
                _first_jackpot,
                first_active,
            ) = instances::instance_snapshot_fields_for_test(&first_snapshot);
            assert!(first_lottery_id == lottery_id, 31);
            assert!(first_price == 10, 32);
            assert!(first_share == 500, 33);
            assert!(first_active, 34);
        };
        if (snapshot_events_len > 0) {
            let last_event = test_utils::last_event_ref(&snapshot_events);
            let (event_admin, event_hub, event_snapshot) =
                instances::snapshot_event_fields_for_test(last_event);
            assert!(event_admin == @lottery, 35);
            assert!(event_hub == @vrf_hub, 36);
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
        };

        let stats_opt = instances::get_instance_stats(lottery_id);
        let stats = test_utils::unwrap(&mut stats_opt);
        let (tickets_sold, jackpot_accumulated, active) =
            instances::instance_stats_fields_for_test(&stats);
        assert!(tickets_sold == 0, 40);
        assert!(jackpot_accumulated == 0, 41);
        assert!(active, 42);

        hub::set_lottery_active(vrf_admin, lottery_id, false);
        instances::set_instance_active(lottery_admin, lottery_id, false);
        assert!(!instances::is_instance_active(lottery_id), 43);

        let inactive_list = instances::list_active_lottery_ids();
        assert!(vector::length(&inactive_list) == 0, 44);

        hub::set_lottery_active(vrf_admin, lottery_id, true);
        instances::set_instance_active(lottery_admin, lottery_id, true);
        let active_list = instances::list_active_lottery_ids();
        assert!(vector::length(&active_list) == 1, 45);

        let ids = instances::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 46);

        instances::set_admin(lottery_admin, @0x123);
        instances::set_hub(lottery_admin, @0x456);
        let snapshot_opt = instances::get_instances_snapshot();
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (admin_after, hub_after, _) = instances::instances_snapshot_fields_for_test(&snapshot);
        assert!(admin_after == @0x123, 47);
        assert!(hub_after == @0x456, 48);
    }
}
