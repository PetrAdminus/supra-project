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

        let registered_events = event::emitted_events<hub::LotteryRegisteredEvent>();
        assert!(vector::length(&registered_events) == 1, 1);
        let register_event = vector::borrow(&registered_events, 0);
        let hub::LotteryRegisteredEvent {
            lottery_id: register_id,
            owner: register_owner,
            lottery: register_lottery,
        } = *register_event;
        assert!(register_id == id, 2);
        assert!(register_owner == OWNER, 3);
        assert!(register_lottery == LOTTERY_ADDR, 4);

        let metadata_events = event::emitted_events<hub::LotteryMetadataUpdatedEvent>();
        assert!(vector::length(&metadata_events) == 1, 5);
        let metadata_event = vector::borrow(&metadata_events, 0);
        let hub::LotteryMetadataUpdatedEvent {
            lottery_id: metadata_event_id,
            metadata: metadata_bytes,
        } = *metadata_event;
        assert!(metadata_event_id == id, 6);
        assert!(vector::length(&metadata_bytes) == 4, 7);

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

        let status_events = event::emitted_events<hub::LotteryStatusChangedEvent>();
        assert!(vector::length(&status_events) == 1, 8);
        let status_event = vector::borrow(&status_events, 0);
        let hub::LotteryStatusChangedEvent {
            lottery_id: status_lottery,
            active: status_active,
        } = *status_event;
        assert!(status_lottery == id, 9);
        assert!(!status_active, 10);

        hub::update_metadata(&hub_signer, id, b"data");
        let registration_opt = hub::get_registration(id);
        let registration = option::destroy_some(registration_opt);
        let (_owner_after, _lottery_after, metadata_after, _active_after) =
            hub::registration_fields_for_test(&registration);
        assert!(vector::length(&metadata_after) == 4, 0);
        assert!(*vector::borrow(&metadata_after, 0) == 100, 0); // 'd'

        let metadata_events_after_update =
            event::emitted_events<hub::LotteryMetadataUpdatedEvent>();
        assert!(vector::length(&metadata_events_after_update) == 2, 11);
        let metadata_update_event = vector::borrow(&metadata_events_after_update, 1);
        let hub::LotteryMetadataUpdatedEvent {
            lottery_id: update_event_id,
            metadata: update_bytes,
        } = *metadata_update_event;
        assert!(update_event_id == id, 12);
        assert!(vector::length(&update_bytes) == 4, 13);
        assert!(*vector::borrow(&update_bytes, 0) == 100, 14);
    }

    #[test]
    fun request_and_consume() {
        setup_accounts();
        let hub_signer = account::create_signer_for_test(HUB_ADDR);
        hub::init(&hub_signer);

        let lottery_id = hub::register_lottery(&hub_signer, OWNER, LOTTERY_ADDR, b"meta");
        let request_id = hub::request_randomness(lottery_id, b"payload");
        assert!(request_id == 1, 0);

        let requested_events = event::emitted_events<hub::RandomnessRequestedEvent>();
        assert!(vector::length(&requested_events) == 1, 15);
        let requested_event = vector::borrow(&requested_events, 0);
        let hub::RandomnessRequestedEvent {
            request_id: event_request_id,
            lottery_id: event_lottery_id,
            payload: event_payload,
            payload_hash: event_hash,
        } = *requested_event;
        assert!(event_request_id == request_id, 16);
        assert!(event_lottery_id == lottery_id, 17);
        assert!(vector::length(&event_payload) == 7, 18);
        assert!(vector::length(&event_hash) == 32, 19);

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

        hub::record_fulfillment(request_id, lottery_id, b"random");
        let fulfilled_events = event::emitted_events<hub::RandomnessFulfilledEvent>();
        assert!(vector::length(&fulfilled_events) == 1, 20);
        let fulfilled_event = vector::borrow(&fulfilled_events, 0);
        let hub::RandomnessFulfilledEvent {
            request_id: fulfilled_request_id,
            lottery_id: fulfilled_lottery_id,
            randomness: fulfilled_randomness,
        } = *fulfilled_event;
        assert!(fulfilled_request_id == request_id, 21);
        assert!(fulfilled_lottery_id == lottery_id, 22);
        assert!(vector::length(&fulfilled_randomness) == 6, 23);
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
        assert!(vector::length(&sender_events) == 1, 24);
        let latest_sender_event = vector::borrow(&sender_events, 0);
        let (previous_opt, current_opt) = hub::callback_sender_event_fields_for_test(latest_sender_event);
        assert!(!option::is_some(&previous_opt), 0);
        let current_sender = option::destroy_some(current_opt);
        assert!(current_sender == @0x44, 0);

        let _record = hub::consume_request(request_id);
        hub::record_fulfillment(request_id, lottery_id, b"random");
        let fulfillment_events = event::emitted_events<hub::RandomnessFulfilledEvent>();
        assert!(vector::length(&fulfillment_events) == 1, 25);

        hub::ensure_callback_sender(&aggregator);
    }

    fun setup_accounts() {
        account::create_account_for_test(HUB_ADDR);
        account::create_account_for_test(OWNER);
        account::create_account_for_test(LOTTERY_ADDR);
    }
}
