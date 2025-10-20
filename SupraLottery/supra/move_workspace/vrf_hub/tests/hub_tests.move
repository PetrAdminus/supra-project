#[test_only]
module vrf_hub::hub_tests {
    use std::account;
    use std::option;
    use std::vector;
    use supra_framework::event;
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
        let (owner, lottery, metadata, active) =
            hub::registration_fields_for_test(&registration);
        assert!(owner == OWNER, 0);
        assert!(lottery == LOTTERY_ADDR, 0);
        assert!(vector::length(&metadata) == 4, 0);
        assert!(active, 0);
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
        let (_owner_after, _lottery_after, metadata_after, _active_after) =
            hub::registration_fields_for_test(&registration);
        assert!(vector::length(&metadata_after) == 4, 0);
        assert!(*vector::borrow(&metadata_after, 0) == 100, 0); // 'd'
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
        let (preview_lottery, preview_payload, preview_hash) =
            hub::request_record_fields_for_test(&preview);
        assert!(preview_lottery == lottery_id, 0);
        assert!(vector::length(&preview_payload) == 7, 0);
        assert!(vector::length(&preview_hash) == 32, 0);

        let record = hub::consume_request(request_id);
        let (stored_lottery, payload, payload_hash) = hub::request_record_fields_for_test(&record);
        assert!(stored_lottery == lottery_id, 0);
        assert!(vector::length(&payload) == 7, 0);
        assert!(vector::length(&payload_hash) == 32, 0);

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

        let status = hub::get_callback_sender_status();
        let status_sender_opt = hub::callback_sender_status_sender(&status);
        assert!(option::is_some(&status_sender_opt), 0);
        let status_sender = option::destroy_some(status_sender_opt);
        assert!(status_sender == @0x44, 0);

        let sender_events = event::emitted_events<hub::CallbackSenderUpdatedEvent>();
        let events_len = vector::length(&sender_events);
        if (events_len > 0) {
            let latest_sender_event = vector::borrow(&sender_events, events_len - 1);
            let (previous_opt, current_opt) = hub::callback_sender_event_fields_for_test(latest_sender_event);
            assert!(!option::is_some(&previous_opt), 0);
            let current_sender = option::destroy_some(current_opt);
            assert!(current_sender == @0x44, 0);
        };

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
