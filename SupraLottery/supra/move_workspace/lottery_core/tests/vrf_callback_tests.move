#[test_only]
module lottery_core::core_vrf_callback_tests {
    use std::hash;
    use std::option;
    use std::vector;
    use lottery_core::core_main_v2 as main_v2;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use lottery_core::test_utils;

    const MAX_GAS_PRICE: u128 = 1_000;
    const MAX_GAS_LIMIT: u128 = 200_000;
    const CALLBACK_GAS_PRICE: u128 = 500;
    const CALLBACK_GAS_LIMIT: u128 = 150_000;
    const VERIFICATION_GAS: u128 = 20_000;

    #[test(lottery_admin = @lottery)]
    #[expected_failure(
        location = lottery_core::core_main_v2,
        abort_code = main_v2::E_NONCE_MISMATCH,
    )]
    fun on_random_received_rejects_nonce_mismatch(lottery_admin: &signer) {
        prepare_lottery(lottery_admin);
        main_v2::configure_vrf_gas_for_test(
            lottery_admin,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS,
        );
        main_v2::set_callback_aggregator_for_test(option::some(@lottery_vrf_gateway));

        let tickets = vector::empty<address>();
        vector::push_back(&mut tickets, @player1);
        main_v2::set_draw_state_for_test(true, tickets);
        main_v2::set_jackpot_amount_for_test(0);
        main_v2::set_pending_request_for_test(option::some(111));

        let fake_message = vector::empty<u8>();
        let randomness = vector::empty<u256>();
        vector::push_back(&mut randomness, 0u256);

        main_v2::handle_verified_random_for_test(
            999, // mismatched nonce
            fake_message,
            randomness,
            main_v2::expected_rng_count_for_test(),
            0,
            @lottery_vrf_gateway,
        );
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(
        location = lottery_core::core_main_v2,
        abort_code = main_v2::E_INVALID_CALLBACK_PAYLOAD,
    )]
    fun on_random_received_rejects_payload_mismatch(lottery_admin: &signer) {
        prepare_lottery(lottery_admin);
        main_v2::configure_vrf_gas_for_test(
            lottery_admin,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS,
        );
        main_v2::set_callback_aggregator_for_test(option::some(@lottery_vrf_gateway));

        let tickets = vector::empty<address>();
        vector::push_back(&mut tickets, @player1);
        main_v2::set_draw_state_for_test(true, tickets);
        main_v2::set_jackpot_amount_for_test(0);

        let rng_count: u8 = main_v2::expected_rng_count_for_test();
        let confirmations: u64 = main_v2::expected_confirmations_for_test();
        let client_seed: u64 = 7;
        let nonce: u64 = 42;
        let requester = @lottery;

        main_v2::configure_vrf_request(
            lottery_admin,
            rng_count,
            confirmations,
            client_seed,
        );

        let canonical_message = main_v2::request_payload_message_for_test(
            nonce,
            client_seed,
            requester,
        );
        let stored_hash = hash::sha3_256(clone_bytes(&canonical_message));

        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(requester),
        );

        let tampered_message = clone_bytes(&canonical_message);
        if (vector::length(&tampered_message) > 0) {
            let first = *vector::borrow(&tampered_message, 0);
            let mut_ref = vector::borrow_mut(&mut tampered_message, 0);
            *mut_ref = if (first == 255) { 0 } else { first + 1 };
        };

        let randomness = vector::empty<u256>();
        vector::push_back(&mut randomness, 0u256);

        main_v2::handle_verified_random_for_test(
            nonce,
            tampered_message,
            randomness,
            rng_count,
            client_seed,
            @lottery_vrf_gateway,
        );
    }

    fun prepare_lottery(lottery_admin: &signer) {
        test_utils::ensure_core_accounts();
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                lottery_admin,
                b"seed",
                b"Lottery Token",
                b"LOT",
                6,
                b"",
                b"",
            );
        };
        if (!treasury_v1::is_core_control_initialized()) {
            treasury_v1::init(lottery_admin);
        };
        if (!main_v2::is_initialized()) {
            main_v2::init(lottery_admin);
        };
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let result = vector::empty<u8>();
        let len = vector::length(source);
        let i = 0;
        while (i < len) {
            vector::push_back(&mut result, *vector::borrow(source, i));
            i = i + 1;
        };
        result
    }
}
