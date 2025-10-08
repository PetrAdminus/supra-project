#[test_only]
module vrf_hub::hub_tests {
    use std::account;
    use std::option;
    use std::vector;
    use vrf_hub::hub;

    const HUB_ADDR: address = @vrf_hub;
    const OWNER: address = @0x42;
    const LOTTERY_ADDR: address = @0x43;

    #[test]
    fun init_and_register() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);

        let id = hub::register_lottery(&hub_signer, OWNER, LOTTERY_ADDR, b"meta");
        assert!(id == 1, 0);
        assert!(hub::is_lottery_active(id), 0);

        let ids = hub::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 0);
        assert!(*vector::borrow(&ids, 0) == id, 0);
        let active = hub::list_active_lottery_ids();
        assert!(vector::length(&active) == 1, 0);
        assert!(*vector::borrow(&active, 0) == id, 0);

        let registration_opt = hub::get_registration(id);
        let registration = option::destroy_some(registration_opt);
        assert!(registration.owner == OWNER, 0);
        assert!(registration.lottery == LOTTERY_ADDR, 0);
        assert!(vector::length(&registration.metadata) == 4, 0);
    }

    #[test]
    fun deactivate_and_update_metadata() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);

        let id = hub::register_lottery(&hub_signer, OWNER, LOTTERY_ADDR, b"meta");
        hub::set_lottery_active(&hub_signer, id, false);
        assert!(!hub::is_lottery_active(id), 0);
        let active = hub::list_active_lottery_ids();
        assert!(vector::length(&active) == 0, 0);

        hub::update_metadata(&hub_signer, id, b"data");
        let registration_opt = hub::get_registration(id);
        let registration = option::destroy_some(registration_opt);
        assert!(vector::length(&registration.metadata) == 4, 0);
        assert!(*vector::borrow(&registration.metadata, 0) == 100, 0); // 'd'
    }

    #[test]
    fun request_and_consume() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);

        let lottery_id = hub::register_lottery(&hub_signer, OWNER, LOTTERY_ADDR, b"meta");
        let request_id = hub::request_randomness(lottery_id, b"payload");
        assert!(request_id == 1, 0);

        let pending = hub::list_pending_request_ids();
        assert!(vector::length(&pending) == 1, 0);
        assert!(*vector::borrow(&pending, 0) == request_id, 0);

        let record_opt = hub::get_request(request_id);
        let preview = option::destroy_some(record_opt);
        assert!(preview.lottery_id == lottery_id, 0);
        assert!(vector::length(&preview.payload) == 7, 0);

        let record = hub::consume_request(request_id);
        let hub::RequestRecord { lottery_id: stored_lottery, payload } = record;
        assert!(stored_lottery == lottery_id, 0);
        assert!(vector::length(&payload) == 7, 0);

        let empty = hub::list_pending_request_ids();
        assert!(vector::length(&empty) == 0, 0);
        let missing = hub::get_request(request_id);
        assert!(!option::is_some(&missing), 0);
    }

    #[test]
    fun callback_enforcement() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);
        let lottery_id = hub::register_lottery(&hub_signer, OWNER, LOTTERY_ADDR, b"meta");
        let request_id = hub::request_randomness(lottery_id, b"payload");

        let aggregator = account::create_signer_for_test(@0x44);
        hub::set_callback_sender(&hub_signer, @0x44);

        let _record = hub::consume_request(request_id);
        hub::record_fulfillment(request_id, lottery_id, b"random");

        hub::ensure_callback_sender(&aggregator);
    }

    fun setup_accounts() {
        account::create_account_for_test(HUB_ADDR);
        account::create_account_for_test(OWNER);
        account::create_account_for_test(LOTTERY_ADDR);
    }
}
