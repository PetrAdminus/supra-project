#[test_only]
module lottery_vrf_gateway::hub_tests {
    use std::option;
    use std::hash;
    use std::vector;

    use lottery_vrf_gateway::hub;

    #[test(admin = @lottery_vrf_gateway, callback = @lottery)]
    fun register_request_and_fulfill_flow(admin: &signer, callback: &signer) {
        hub::init(admin);
        hub::register_lottery(admin, @lottery, @0x501, b"meta");
        hub::set_callback_sender(admin, option::some(@lottery));

        let payload = b"payload";
        let request_id = hub::request_randomness(0, vector::copy(payload));
        assert!(request_id == 0, 0);

        let pending = hub::list_pending_request_ids();
        assert!(vector::length(&pending) == 1, 1);
        assert!(*vector::borrow(&pending, 0) == request_id, 2);

        hub::fulfill_randomness_with_callback(callback, request_id, vector::copy(payload), b"randomness");

        let pending_after = hub::list_pending_request_ids();
        assert!(vector::length(&pending_after) == 0, 3);

        let request_lookup = hub::get_request(request_id);
        assert!(!option::is_some(&request_lookup), 4);
    }

    #[test(admin = @lottery_vrf_gateway, callback = @lottery)]
    fun snapshot_views_cover_registrations_and_requests(admin: &signer, callback: &signer) {
        hub::init(admin);
        hub::register_lottery(admin, @lottery, @0x501, b"meta");

        let reg_opt = hub::lottery_snapshot(0);
        assert!(option::is_some(&reg_opt), 0);
        let reg = option::destroy_some(reg_opt);
        assert!(reg.owner == @lottery, 1);
        assert!(reg.lottery == @0x501, 2);
        assert!(reg.metadata == b"meta", 3);
        assert!(reg.active, 4);

        hub::set_callback_sender(admin, option::some(@lottery));
        let payload = b"payload";
        let request_id = hub::request_randomness(0, vector::copy(payload));
        let hash_expected = hash::sha3_256(&payload);

        let snapshot_opt = hub::request_snapshot(request_id);
        assert!(option::is_some(&snapshot_opt), 5);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.request_id == request_id, 6);
        assert!(snapshot.lottery_id == 0, 7);
        assert!(snapshot.pending, 8);
        assert!(snapshot.payload == vector::copy(payload), 9);
        assert!(snapshot.payload_hash == hash_expected, 10);

        hub::fulfill_randomness_with_callback(callback, request_id, vector::copy(payload), b"rnd");
        let after_fulfill = hub::request_snapshot(request_id);
        assert!(option::is_some(&after_fulfill), 11);
        let fulfilled = option::destroy_some(after_fulfill);
        assert!(!fulfilled.pending, 12);

        hub::remove_request(admin, request_id);
        let removed = hub::request_snapshot(request_id);
        assert!(!option::is_some(&removed), 13);
    }
}
