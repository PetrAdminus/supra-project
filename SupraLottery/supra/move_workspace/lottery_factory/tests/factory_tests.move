#[test_only]
module lottery_factory::factory_tests {
    use std::account;
    use std::option;
    use lottery_factory::registry;
    use vrf_hub::hub;

    const HUB_ADDR: address = @vrf_hub;
    const FACTORY_ADDR: address = @lottery_factory;
    const OWNER: address = @0x101;
    const LOTTERY_ADDR: address = @0x202;

    #[test]
    fun create_and_update() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);
        hub::set_admin(&hub_signer, FACTORY_ADDR);

        let factory_signer = account::create_signer_for_test(FACTORY_ADDR);
        registry::init(&factory_signer);

        let blueprint = registry::new_blueprint(10, 100);
        let lottery_id = registry::create_lottery(&factory_signer, OWNER, LOTTERY_ADDR, blueprint, b"meta");
        assert!(lottery_id == 1, 0);
        assert!(hub::is_lottery_active(lottery_id), 0);

        let info_opt = registry::get_lottery(lottery_id);
        let info = option::destroy_some(info_opt);
        assert!(info.owner == OWNER, 0);
        assert!(info.lottery == LOTTERY_ADDR, 0);
        assert!(info.blueprint.ticket_price == 10, 0);

        let new_blueprint = registry::new_blueprint(25, 150);
        registry::update_blueprint(&factory_signer, lottery_id, new_blueprint);

        let updated_opt = registry::get_lottery(lottery_id);
        let updated = option::destroy_some(updated_opt);
        assert!(updated.blueprint.ticket_price == 25, 0);
        assert!(updated.blueprint.jackpot_share_bps == 150, 0);
    }

    fun setup_accounts() {
        account::create_account_for_test(HUB_ADDR);
        account::create_account_for_test(FACTORY_ADDR);
        account::create_account_for_test(OWNER);
        account::create_account_for_test(LOTTERY_ADDR);
    }
}
