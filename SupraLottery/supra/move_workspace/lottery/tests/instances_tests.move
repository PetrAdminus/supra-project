module lottery::instances_tests {
    use std::option;
    use std::vector;
    use lottery::instances;
    use lottery_factory::registry;
    use vrf_hub::hub;

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    fun create_and_sync_flow(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
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

        let info = option::extract(instances::get_lottery_info(lottery_id));
        let owner = info.owner;
        let lottery_addr = info.lottery;
        let blueprint = info.blueprint;
        assert!(owner == @lottery_owner, 4);
        assert!(lottery_addr == @lottery_contract, 5);
        let ticket_price = blueprint.ticket_price;
        let jackpot_share_bps = blueprint.jackpot_share_bps;
        assert!(ticket_price == 10, 6);
        assert!(jackpot_share_bps == 500, 7);

        let updated_blueprint = registry::new_blueprint(25, 800);
        registry::update_blueprint(factory_admin, lottery_id, updated_blueprint);
        instances::sync_blueprint(lottery_admin, lottery_id);

        let synced_info = option::extract(instances::get_lottery_info(lottery_id));
        let synced_blueprint = synced_info.blueprint;
        let synced_price = synced_blueprint.ticket_price;
        let synced_share = synced_blueprint.jackpot_share_bps;
        assert!(synced_price == 25, 8);
        assert!(synced_share == 800, 9);

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

        hub::set_lottery_active(vrf_admin, lottery_id, true);
        instances::set_instance_active(lottery_admin, lottery_id, true);
        assert!(instances::is_instance_active(lottery_id), 2);
    }

    #[test(vrf_admin = @vrf_hub, factory_admin = @lottery_factory, lottery_admin = @lottery)]
    #[expected_failure(abort_code = 9)]
    fun toggle_requires_synced_hub(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
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
