#[test_only]
module lottery_factory::factory_tests {
    use std::account;
    use std::option;
    use std::vector;
    use supra_framework::event;
    use lottery_factory::registry;
    use lottery_vrf_gateway::hub;

    const HUB_ADDR: address = @lottery_vrf_gateway;
    const FACTORY_ADDR: address = @lottery_factory;
    const OWNER: address = @0x101;
    const LOTTERY_ADDR: address = @0x202;

    #[test]
    fun create_and_update() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);
        let hub_payload = hub::LegacyHubState {
            admin: FACTORY_ADDR,
            next_lottery_id: 1,
            next_request_id: 0,
            lotteries: vector::empty<hub::LegacyLotteryRegistration>(),
            requests: vector::empty<hub::LegacyRequestRecord>(),
            lottery_ids: vector::empty<u64>(),
            pending_request_ids: vector::empty<u64>(),
            callback_sender: option::none<address>(),
        };
        hub::migrate_lottery_vrf_gateway_state(&hub_signer, hub_payload);

        let factory_signer = account::create_signer_for_test(FACTORY_ADDR);
        registry::init(&factory_signer);

        let initial_snapshot = registry::get_registry_snapshot();
        let (initial_admin, initial_entries) =
            registry::registry_snapshot_fields_for_test(&initial_snapshot);
        assert!(initial_admin == FACTORY_ADDR, 0);
        assert!(vector::length(&initial_entries) == 0, 1);

        let snapshot_events_after_init =
            event::emitted_events<registry::LotteryRegistrySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events_after_init) == 1, 100);
        let init_event = vector::borrow(&snapshot_events_after_init, 0);
        let (init_event_admin, init_event_entries) =
            registry::registry_snapshot_event_fields_for_test(init_event);
        assert!(init_event_admin == FACTORY_ADDR, 101);
        assert!(vector::length(&init_event_entries) == 0, 102);

        let blueprint = registry::new_blueprint(10, 100);
        let lottery_id = registry::create_lottery(&factory_signer, OWNER, LOTTERY_ADDR, blueprint, b"meta");
        assert!(lottery_id == 1, 0);
        let vrf_snapshot = hub::hub_snapshot();
        let vrf_ids = vrf_snapshot.lottery_ids;
        let vrf_lotteries = vrf_snapshot.lotteries;
        assert!(vector::length(&vrf_ids) == 1, 133);
        assert!(*vector::borrow(&vrf_ids, 0) == lottery_id, 134);
        assert!(vector::length(&vrf_lotteries) == 1, 135);
        let vrf_registration = vector::borrow(&vrf_lotteries, 0);
        assert!(vrf_registration.owner == OWNER, 136);
        assert!(vrf_registration.lottery == LOTTERY_ADDR, 137);
        assert!(vrf_registration.active, 138);

        let planned_events = event::emitted_events<registry::LotteryPlannedEvent>();
        assert!(vector::length(&planned_events) == 1, 103);
        let planned_event = vector::borrow(&planned_events, 0);
        let (planned_id, planned_owner) =
            registry::lottery_planned_event_fields_for_test(planned_event);
        assert!(planned_id == lottery_id, 104);
        assert!(planned_owner == OWNER, 105);

        let activated_events = event::emitted_events<registry::LotteryActivatedEvent>();
        assert!(vector::length(&activated_events) == 1, 106);
        let activated_event = vector::borrow(&activated_events, 0);
        let (activated_id, activated_lottery) =
            registry::lottery_activated_event_fields_for_test(activated_event);
        assert!(activated_id == lottery_id, 107);
        assert!(activated_lottery == LOTTERY_ADDR, 108);

        let ids = registry::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 2);
        assert!(*vector::borrow(&ids, 0) == lottery_id, 3);

        let snapshot_after_create = registry::get_registry_snapshot();
        let (admin_after_create, entries_after_create) =
            registry::registry_snapshot_fields_for_test(&snapshot_after_create);
        assert!(admin_after_create == FACTORY_ADDR, 4);
        assert!(vector::length(&entries_after_create) == 1, 5);
        let create_entry = vector::borrow(&entries_after_create, 0);
        let (
            create_entry_id,
            create_owner,
            create_lottery,
            create_price,
            create_share,
        ) = registry::registry_entry_fields_for_test(create_entry);
        assert!(create_entry_id == lottery_id, 6);
        assert!(create_owner == OWNER, 7);
        assert!(create_lottery == LOTTERY_ADDR, 8);
        assert!(create_price == 10, 9);
        assert!(create_share == 100, 10);

        let snapshot_events_after_create =
            event::emitted_events<registry::LotteryRegistrySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events_after_create) == 2, 109);
        let create_snapshot_event = vector::borrow(&snapshot_events_after_create, 1);
        let (create_event_admin, create_event_entries) =
            registry::registry_snapshot_event_fields_for_test(create_snapshot_event);
        assert!(create_event_admin == FACTORY_ADDR, 110);
        assert!(vector::length(&create_event_entries) == 1, 111);
        let create_event_entry = vector::borrow(&create_event_entries, 0);
        let (
            create_event_id,
            create_event_owner,
            create_event_lottery,
            create_event_price,
            create_event_share,
        ) = registry::registry_entry_fields_for_test(create_event_entry);
        assert!(create_event_id == lottery_id, 112);
        assert!(create_event_owner == OWNER, 113);
        assert!(create_event_lottery == LOTTERY_ADDR, 114);
        assert!(create_event_price == 10, 115);
        assert!(create_event_share == 100, 116);

        let info_opt = registry::get_lottery(lottery_id);
        let info = option::destroy_some(info_opt);
        let (owner, lottery, ticket_price, _) = registry::lottery_info_fields_for_test(&info);
        assert!(owner == OWNER, 11);
        assert!(lottery == LOTTERY_ADDR, 12);
        assert!(ticket_price == 10, 13);

        let new_blueprint = registry::new_blueprint(25, 150);
        registry::update_blueprint(&factory_signer, lottery_id, new_blueprint);

        let snapshot_after_update = registry::get_registry_snapshot();
        let (admin_after_update, entries_after_update) =
            registry::registry_snapshot_fields_for_test(&snapshot_after_update);
        assert!(admin_after_update == FACTORY_ADDR, 14);
        assert!(vector::length(&entries_after_update) == 1, 15);
        let updated_entry = vector::borrow(&entries_after_update, 0);
        let (
            updated_entry_id,
            updated_owner,
            updated_lottery,
            updated_price,
            updated_share,
        ) = registry::registry_entry_fields_for_test(updated_entry);
        assert!(updated_entry_id == lottery_id, 16);
        assert!(updated_owner == OWNER, 17);
        assert!(updated_lottery == LOTTERY_ADDR, 18);
        assert!(updated_price == 25, 19);
        assert!(updated_share == 150, 20);

        let snapshot_events_after_update =
            event::emitted_events<registry::LotteryRegistrySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events_after_update) == 3, 117);
        let update_snapshot_event = vector::borrow(&snapshot_events_after_update, 2);
        let (update_event_admin, update_event_entries) =
            registry::registry_snapshot_event_fields_for_test(update_snapshot_event);
        assert!(update_event_admin == FACTORY_ADDR, 118);
        assert!(vector::length(&update_event_entries) == 1, 119);
        let update_event_entry = vector::borrow(&update_event_entries, 0);
        let (
            update_event_id,
            update_event_owner,
            update_event_lottery,
            update_event_price,
            update_event_share,
        ) = registry::registry_entry_fields_for_test(update_event_entry);
        assert!(update_event_id == lottery_id, 120);
        assert!(update_event_owner == OWNER, 121);
        assert!(update_event_lottery == LOTTERY_ADDR, 122);
        assert!(update_event_price == 25, 123);
        assert!(update_event_share == 150, 124);

        let updated_opt = registry::get_lottery(lottery_id);
        let updated = option::destroy_some(updated_opt);
        let (_owner2, _lottery2, updated_price, updated_share) =
            registry::lottery_info_fields_for_test(&updated);
        assert!(updated_price == 25, 21);
        assert!(updated_share == 150, 22);

        registry::set_admin(&factory_signer, OWNER);

        let snapshot_after_admin_change = registry::get_registry_snapshot();
        let (admin_after_change, entries_after_change) =
            registry::registry_snapshot_fields_for_test(&snapshot_after_admin_change);
        assert!(admin_after_change == OWNER, 23);
        assert!(vector::length(&entries_after_change) == 1, 24);

        let snapshot_events_after_admin_change =
            event::emitted_events<registry::LotteryRegistrySnapshotUpdatedEvent>();
        assert!(vector::length(&snapshot_events_after_admin_change) == 4, 125);
        let admin_snapshot_event = vector::borrow(&snapshot_events_after_admin_change, 3);
        let (admin_event_admin, admin_event_entries) =
            registry::registry_snapshot_event_fields_for_test(admin_snapshot_event);
        assert!(admin_event_admin == OWNER, 126);
        assert!(vector::length(&admin_event_entries) == 1, 127);
        let admin_event_entry = vector::borrow(&admin_event_entries, 0);
        let (
            admin_event_id,
            admin_event_owner,
            admin_event_lottery,
            admin_event_price,
            admin_event_share,
        ) = registry::registry_entry_fields_for_test(admin_event_entry);
        assert!(admin_event_id == lottery_id, 128);
        assert!(admin_event_owner == OWNER, 129);
        assert!(admin_event_lottery == LOTTERY_ADDR, 130);
        assert!(admin_event_price == 25, 131);
        assert!(admin_event_share == 150, 132);
    }

    fun setup_accounts() {
        account::create_account_for_test(HUB_ADDR);
        account::create_account_for_test(FACTORY_ADDR);
        account::create_account_for_test(OWNER);
        account::create_account_for_test(LOTTERY_ADDR);
    }
}
