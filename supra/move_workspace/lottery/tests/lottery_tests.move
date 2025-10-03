#[test_only]
module lottery::lottery_tests {
    use 0x1::account;
    use 0x1::event;
    use 0x1::timestamp;
    use std::option;
    use std::hash;
    use std::string;
    use std::vector;
    use std::u64;
    use std::u128;
    use lottery::main_v2;
    use lottery::treasury_v1;

    const LOTTERY_ADDR: address = @lottery;
    const ADMIN: address = @0x1;
    const PLAYER1: address = @0x2;
    const PLAYER2: address = @0x3;
    const TREASURY_RECIPIENT: address = @0x10;
    const MARKETING_RECIPIENT: address = @0x11;
    const COMMUNITY_RECIPIENT: address = @0x12;
    const TEAM_RECIPIENT: address = @0x13;
    const PARTNERS_RECIPIENT: address = @0x14;
    const TICKET_PRICE: u64 = main_v2::TICKET_PRICE;
    const DECIMALS: u8 = 9;
    const STORE_FROZEN_ABORT: u64 = 0x50003;
    const MAX_GAS_PRICE: u128 = 100;
    const MAX_GAS_LIMIT: u128 = 200;
    const CALLBACK_GAS_PRICE: u128 = 10;
    const CALLBACK_GAS_LIMIT: u128 = 40;
    const VERIFICATION_GAS_VALUE: u128 = 50;
    const EXPECTED_GAS_ERROR: u64 = main_v2::E_GAS_CONFIG_NOT_SET;
    const EXPECTED_CALLBACK_SOURCE_ERROR: u64 = main_v2::E_CALLBACK_SOURCE_NOT_SET;
    const DRAW_NOT_SCHEDULED_ERROR: u64 = main_v2::E_DRAW_NOT_SCHEDULED;
    const PENDING_REQUEST_STATE_ERROR: u64 = main_v2::E_PENDING_REQUEST_STATE;
    const WITHDRAWAL_PENDING_REQUEST_ERROR: u64 = main_v2::E_WITHDRAWAL_PENDING_REQUEST;
    const NOT_OWNER_ERROR: u64 = main_v2::E_NOT_OWNER;
    const ALREADY_INITIALIZED_ERROR: u64 = main_v2::E_ALREADY_INITIALIZED;
    const NO_TICKETS_ERROR: u64 = main_v2::E_NO_TICKETS_AVAILABLE;
    const GAS_MATH_OVERFLOW_ERROR: u64 = main_v2::E_GAS_MATH_OVERFLOW;
    const INVALID_GAS_CONFIG_ERROR: u64 = main_v2::E_INVALID_GAS_CONFIG;
    const INVALID_AGGREGATOR_ERROR: u64 = main_v2::E_INVALID_CALLBACK_SENDER;
    const INVALID_CONSUMER_ERROR: u64 = main_v2::E_INVALID_CONSUMER_ADDRESS;
    const DEFAULT_CONSUMER_REMOVE_ERROR: u64 = main_v2::E_CANNOT_REMOVE_DEFAULT_CONSUMER;
    const CONSUMER_ALREADY_WHITELISTED_ERROR: u64 = main_v2::E_CONSUMER_ALREADY_WHITELISTED;
    const CONSUMER_NOT_WHITELISTED_ERROR: u64 = main_v2::E_CONSUMER_NOT_WHITELISTED;
    const CLIENT_WHITELIST_MISMATCH_ERROR: u64 = main_v2::E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH;
    const CONSUMER_WHITELIST_MISMATCH_ERROR: u64 = main_v2::E_CONSUMER_WHITELIST_SNAPSHOT_MISMATCH;
    const REQUEST_STILL_PENDING_ERROR: u64 = main_v2::E_REQUEST_STILL_PENDING;
    const INVALID_REQUEST_CONFIG_ERROR: u64 = main_v2::E_INVALID_REQUEST_CONFIG;
    const CLIENT_SEED_REGRESSION_ERROR: u64 = main_v2::E_CLIENT_SEED_REGRESSION;
    const PLAYER_STORE_NOT_REGISTERED_ERROR: u64 = main_v2::E_PLAYER_STORE_NOT_REGISTERED;
    const INVALID_CALLBACK_PAYLOAD_ERROR: u64 = main_v2::E_INVALID_CALLBACK_PAYLOAD;
    const UNEXPECTED_RNG_COUNT_ERROR: u64 = main_v2::E_UNEXPECTED_RNG_COUNT;
    const CALLBACK_CALLER_NOT_ALLOWED_ERROR: u64 = main_v2::E_CALLBACK_CALLER_NOT_ALLOWED;
    const STORE_NOT_REGISTERED_ERROR: u64 = treasury_v1::E_STORE_NOT_REGISTERED;
    const JACKPOT_OVERFLOW_ERROR: u64 = main_v2::E_JACKPOT_OVERFLOW;
    const TICKET_ID_OVERFLOW_ERROR: u64 = main_v2::E_TICKET_ID_OVERFLOW;
    const RNG_REQUEST_OVERFLOW_ERROR: u64 = main_v2::E_RNG_REQUEST_OVERFLOW;
    const RNG_RESPONSE_OVERFLOW_ERROR: u64 = main_v2::E_RNG_RESPONSE_OVERFLOW;
    const VRF_AGGREGATOR: address = @0xa;
    const UNAUTHORIZED_CALLBACK: address = @0xb;
    const SECOND_AGGREGATOR: address = @0xc;
    const ZERO_ADDRESS: address = @0x0;
    const MIN_REQUEST_WINDOW: u128 = 30;

    fun setup_accounts_base() {
        account::create_account_for_test(LOTTERY_ADDR);
        account::create_account_for_test(PLAYER1);
        account::create_account_for_test(PLAYER2);
        account::create_account_for_test(TREASURY_RECIPIENT);
        account::create_account_for_test(MARKETING_RECIPIENT);
        account::create_account_for_test(COMMUNITY_RECIPIENT);
        account::create_account_for_test(TEAM_RECIPIENT);
        account::create_account_for_test(PARTNERS_RECIPIENT);
        account::create_account_for_test(VRF_AGGREGATOR);
        account::create_account_for_test(UNAUTHORIZED_CALLBACK);
        account::create_account_for_test(SECOND_AGGREGATOR);

        let framework = account::create_signer_for_test(ADMIN);
        timestamp::set_time_has_started_for_testing(&framework);

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        treasury_v1::init_token(
            &lottery_signer,
            b"lottery_fa_seed",
            b"Lottery Ticket",
            b"LOT",
            DECIMALS,
            b"",
            b""
        );
    }

    fun setup_accounts() {
        setup_accounts_base();

        let player1_signer = account::create_signer_for_test(PLAYER1);
        treasury_v1::register_store(&player1_signer);

        let player2_signer = account::create_signer_for_test(PLAYER2);
        treasury_v1::register_store(&player2_signer);
    }

    fun register_system_stores() {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        let accounts = vector[
            TREASURY_RECIPIENT,
            MARKETING_RECIPIENT,
            COMMUNITY_RECIPIENT,
            TEAM_RECIPIENT,
            PARTNERS_RECIPIENT,
        ];
        treasury_v1::register_stores_for(&lottery_signer, accounts);
    }

    fun configure_recipients() {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        treasury_v1::set_recipients(
            &lottery_signer,
            TREASURY_RECIPIENT,
            MARKETING_RECIPIENT,
            COMMUNITY_RECIPIENT,
            TEAM_RECIPIENT,
            PARTNERS_RECIPIENT,
        );
    }

    fun whitelist_callback_sender() {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::whitelist_callback_sender(&lottery_signer, VRF_AGGREGATOR);
    }

    fun whitelist_consumer(addr: address) {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::whitelist_consumer(&lottery_signer, addr);
    }

    fun mint_to(addr: address, amount: u64) {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        treasury_v1::mint_to(&lottery_signer, addr, amount);
    }

    fun configure_gas_default() {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE,
        );
    }

    fun expected_min_balance(): u128 {
        let per_request = MAX_GAS_PRICE * (MAX_GAS_LIMIT + VERIFICATION_GAS_VALUE);
        per_request * MIN_REQUEST_WINDOW
    }

    fun buy_ticket_for(addr: address) {
        let signer = account::create_signer_for_test(addr);
        main_v2::buy_ticket(&signer);
    }

    #[test]
    fun first_u64_from_bytes_handles_max_value() {
        let bytes = vector[
            255u8,
            255u8,
            255u8,
            255u8,
            255u8,
            255u8,
            255u8,
            255u8,
        ];

        let value = main_v2::first_u64_from_bytes_for_test(bytes);
        assert!(value == u64::max_value(), 9000);
    }

    #[test]
    fun get_ticket_price_view_returns_constant() {
        let price = main_v2::get_ticket_price();
        assert!(price == TICKET_PRICE, 9002);
    }

    #[test]
    fun first_u64_from_bytes_respects_little_endian_order() {
        let bytes = vector[
            1u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
        ];

        let value = main_v2::first_u64_from_bytes_for_test(bytes);
        assert!(value == 1, 9001);

        let high_bytes = vector[
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            1u8,
        ];

        let high_value = main_v2::first_u64_from_bytes_for_test(high_bytes);
        assert!(high_value == 72057594037927936, 9002);
    }

    #[test]
    fun admin_registers_multiple_stores() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        let accounts = vector[PLAYER1, PLAYER2];

        treasury_v1::register_stores_for(&lottery_signer, accounts);

        assert!(treasury_v1::store_registered(PLAYER1), 50);
        assert!(treasury_v1::store_registered(PLAYER2), 51);
    }

    #[test]
    fun whitelisting_events_track_consumers_and_aggregator() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_callback_sender();
        whitelist_consumer(PLAYER1);

        let consumer_events = event::emitted_events<main_v2::ConsumerWhitelistedEvent>();
        let consumer_event_len = vector::length(&consumer_events);
        assert!(consumer_event_len >= 2, 52);
        let last_consumer_event = vector::borrow(&consumer_events, consumer_event_len - 1);
        let consumer_addr = main_v2::consumer_whitelisted_fields(last_consumer_event);
        assert!(consumer_addr == PLAYER1, 53);

        let aggregator_events = event::emitted_events<main_v2::AggregatorWhitelistedEvent>();
        assert!(vector::length(&aggregator_events) == 1, 54);
        let aggregator_event = vector::borrow(&aggregator_events, 0);
        let aggregator_addr = main_v2::aggregator_whitelisted_fields(aggregator_event);
        assert!(aggregator_addr == VRF_AGGREGATOR, 55);

        let status = main_v2::get_whitelist_status();
        assert!(option::is_some(&status.aggregator), 223);
        let aggregator = *option::borrow(&status.aggregator);
        assert!(aggregator == VRF_AGGREGATOR, 224);
        let consumer_count = vector::length(&status.consumers);
        assert!(consumer_count == 2, 225);
        let first_consumer = *vector::borrow(&status.consumers, 0);
        let second_consumer = *vector::borrow(&status.consumers, 1);
        assert!(first_consumer == LOTTERY_ADDR, 226);
        assert!(second_consumer == PLAYER1, 227);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CONSUMER_ALREADY_WHITELISTED_ERROR)]
    fun whitelist_consumer_rejects_duplicates() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_consumer(PLAYER1);
        whitelist_consumer(PLAYER1);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_CONSUMER_ERROR)]
    fun whitelist_consumer_rejects_zero_address() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::whitelist_consumer(&lottery_signer, ZERO_ADDRESS);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CONSUMER_NOT_WHITELISTED_ERROR)]
    fun remove_consumer_requires_existing_entry() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let lottery_admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::remove_consumer(&lottery_admin, PLAYER1);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = EXPECTED_CALLBACK_SOURCE_ERROR)]
    fun revoke_callback_sender_requires_existing_aggregator() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::revoke_callback_sender(&admin);
    }

    #[test]
    fun revoke_callback_sender_emits_event() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_callback_sender();

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::revoke_callback_sender(&admin);

        let revoked_events = event::emitted_events<main_v2::AggregatorRevokedEvent>();
        assert!(vector::length(&revoked_events) == 1, 56);
        let revoked_event = vector::borrow(&revoked_events, 0);
        let revoked_addr = main_v2::aggregator_revoked_fields(revoked_event);
        assert!(revoked_addr == VRF_AGGREGATOR, 57);
    }

    #[test]
    fun record_client_whitelist_snapshot_records_state_and_event() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        configure_gas_default();

        let min_balance_limit = expected_min_balance();
        main_v2::record_client_whitelist_snapshot(&lottery_signer, MAX_GAS_PRICE, MAX_GAS_LIMIT, min_balance_limit);

        let events = event::emitted_events<main_v2::ClientWhitelistRecordedEvent>();
        assert!(vector::length(&events) == 1, 200);
        let event_ref = vector::borrow(&events, 0);
        let (event_price, event_limit, event_min) = main_v2::client_whitelist_recorded_fields(event_ref);
        assert!(event_price == MAX_GAS_PRICE, 201);
        assert!(event_limit == MAX_GAS_LIMIT, 202);
        assert!(event_min == min_balance_limit, 203);

        let snapshot_opt = main_v2::get_client_whitelist_snapshot();
        assert!(option::is_some(&snapshot_opt), 204);
        let snapshot_ref = option::borrow(&snapshot_opt);
        let snapshot = *snapshot_ref;
        assert!(snapshot.max_gas_price == MAX_GAS_PRICE, 205);
        assert!(snapshot.max_gas_limit == MAX_GAS_LIMIT, 206);
        assert!(snapshot.min_balance_limit == min_balance_limit, 207);

        let min_snapshot_opt = main_v2::get_min_balance_limit_snapshot();
        assert!(option::is_some(&min_snapshot_opt), 208);
        let min_snapshot_ref = option::borrow(&min_snapshot_opt);
        let min_snapshot = *min_snapshot_ref;
        assert!(min_snapshot == min_balance_limit, 209);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CLIENT_WHITELIST_MISMATCH_ERROR)]
    fun record_client_whitelist_snapshot_rejects_mismatch() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        configure_gas_default();

        let min_balance_limit = expected_min_balance();
        let wrong_price = MAX_GAS_PRICE + 1u128;

        main_v2::record_client_whitelist_snapshot(&lottery_signer, wrong_price, MAX_GAS_LIMIT, min_balance_limit);
    }

    #[test]
    fun record_consumer_whitelist_snapshot_records_event_and_state() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        configure_gas_default();

        main_v2::record_consumer_whitelist_snapshot(&lottery_signer, CALLBACK_GAS_PRICE, CALLBACK_GAS_LIMIT);

        let events = event::emitted_events<main_v2::ConsumerWhitelistSnapshotRecordedEvent>();
        assert!(vector::length(&events) == 1, 210);
        let event_ref = vector::borrow(&events, 0);
        let (event_price, event_limit) = main_v2::consumer_whitelist_snapshot_fields(event_ref);
        assert!(event_price == CALLBACK_GAS_PRICE, 211);
        assert!(event_limit == CALLBACK_GAS_LIMIT, 212);

        let snapshot_opt = main_v2::get_consumer_whitelist_snapshot();
        assert!(option::is_some(&snapshot_opt), 213);
        let snapshot_ref = option::borrow(&snapshot_opt);
        let snapshot = *snapshot_ref;
        assert!(snapshot.callback_gas_price == CALLBACK_GAS_PRICE, 214);
        assert!(snapshot.callback_gas_limit == CALLBACK_GAS_LIMIT, 215);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CONSUMER_WHITELIST_MISMATCH_ERROR)]
    fun record_consumer_whitelist_snapshot_rejects_mismatch() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        configure_gas_default();

        let wrong_limit = CALLBACK_GAS_LIMIT + 1u128;
        main_v2::record_consumer_whitelist_snapshot(&lottery_signer, CALLBACK_GAS_PRICE, wrong_limit);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = REQUEST_STILL_PENDING_ERROR)]
    fun whitelist_callback_sender_rejects_updates_with_pending_request() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_callback_sender();
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE,
        );

        main_v2::record_request_for_test(42, LOTTERY_ADDR);

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::whitelist_callback_sender(&admin, SECOND_AGGREGATOR);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = REQUEST_STILL_PENDING_ERROR)]
    fun revoke_callback_sender_rejects_pending_request() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_callback_sender();
        configure_gas_default();

        main_v2::record_request_for_test(43, LOTTERY_ADDR);

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::revoke_callback_sender(&admin);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_AGGREGATOR_ERROR)]
    fun whitelist_callback_sender_rejects_zero_address() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::whitelist_callback_sender(&lottery_signer, @0x0);
    }

    #[test]
    fun configure_vrf_request_updates_seed_and_records_event() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let new_seed = 5u64;
        main_v2::configure_vrf_request(&lottery_signer, 1u8, new_seed);

        let events = event::emitted_events<main_v2::VrfRequestConfigUpdatedEvent>();
        assert!(vector::length(&events) == 1, 216);
        let event_ref = vector::borrow(&events, 0);
        let (event_rng, event_seed) = main_v2::vrf_request_config_fields(event_ref);
        assert!(event_rng == 1u8, 217);
        assert!(event_seed == new_seed, 218);

        let next_seed = main_v2::next_client_seed_for_test();
        assert!(next_seed == new_seed, 219);

        let config_opt = main_v2::get_vrf_request_config();
        assert!(option::is_some(&config_opt), 220);
        let config_ref = option::borrow(&config_opt);
        let config = *config_ref;
        assert!(config.rng_count == 1u8, 221);
        assert!(config.client_seed == new_seed, 222);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_REQUEST_CONFIG_ERROR)]
    fun configure_vrf_request_rejects_invalid_rng_count() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_request(&lottery_signer, 2u8, 0u64);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CLIENT_SEED_REGRESSION_ERROR)]
    fun configure_vrf_request_rejects_seed_regression() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_request(&lottery_signer, 1u8, 10u64);
        main_v2::configure_vrf_request(&lottery_signer, 1u8, 5u64);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = REQUEST_STILL_PENDING_ERROR)]
    fun configure_vrf_request_rejects_pending_request() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_callback_sender();
        configure_gas_default();

        main_v2::record_request_for_test(100, LOTTERY_ADDR);

        main_v2::configure_vrf_request(&lottery_signer, 1u8, 1u64);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = DEFAULT_CONSUMER_REMOVE_ERROR)]
    fun remove_consumer_rejects_lottery_address() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::remove_consumer(&admin, LOTTERY_ADDR);
    }

    #[test]
    fun remove_consumer_emits_event() {
        setup_accounts_base();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        whitelist_consumer(PLAYER1);

        let admin = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::remove_consumer(&admin, PLAYER1);

        let events = event::emitted_events<main_v2::ConsumerRemovedEvent>();
        assert!(vector::length(&events) == 1, 58);
        let removed_event = vector::borrow(&events, 0);
        let removed_addr = main_v2::consumer_removed_fields(removed_event);
        assert!(removed_addr == PLAYER1, 59);
    }

    #[test]
    fun treasury_config_defaults_and_updates_emit_event() {
        setup_accounts_base();

        let (
            bp_jackpot,
            bp_prize,
            bp_treasury,
            bp_marketing,
            bp_community,
            bp_team,
            bp_partners
        ) = treasury_v1::get_config();

        assert!(bp_jackpot == 5_000, 60);
        assert!(bp_prize == 2_000, 61);
        assert!(bp_treasury == 1_500, 62);
        assert!(bp_marketing == 800, 63);
        assert!(bp_community == 400, 64);
        assert!(bp_team == 200, 65);
        assert!(bp_partners == 100, 66);

        let total =
            bp_jackpot +
            bp_prize +
            bp_treasury +
            bp_marketing +
            bp_community +
            bp_team +
            bp_partners;
        assert!(total == 10_000, 67);

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        treasury_v1::set_config(
            &lottery_signer,
            4_000,
            3_000,
            1_500,
            700,
            400,
            200,
            200,
        );

        let (
            new_jackpot,
            new_prize,
            new_treasury,
            new_marketing,
            new_community,
            new_team,
            new_partners
        ) = treasury_v1::get_config();

        assert!(new_jackpot == 4_000, 68);
        assert!(new_prize == 3_000, 69);
        assert!(new_treasury == 1_500, 70);
        assert!(new_marketing == 700, 71);
        assert!(new_community == 400, 72);
        assert!(new_team == 200, 73);
        assert!(new_partners == 200, 74);

        let events = event::emitted_events<treasury_v1::ConfigUpdatedEvent>();
        let count = vector::length(&events);
        assert!(count == 2, 75); // init_token + set_config
        let last_event = vector::borrow(&events, count - 1);
        let (
            event_jackpot,
            event_prize,
            event_treasury,
            event_marketing,
            event_community,
            event_team,
            event_partners
        ) = treasury_v1::config_event_fields(last_event);

        assert!(event_jackpot == 4_000, 76);
        assert!(event_prize == 3_000, 77);
        assert!(event_treasury == 1_500, 78);
        assert!(event_marketing == 700, 79);
        assert!(event_community == 400, 80);
        assert!(event_team == 200, 81);
        assert!(event_partners == 200, 82);
    }

    #[test]
    fun configure_vrf_gas_for_test_updates_state_and_event() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::whitelist_callback_sender(&lottery_signer, VRF_AGGREGATOR);
        main_v2::whitelist_consumer(&lottery_signer, PLAYER1);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let (stored_max_price, stored_max_limit) = main_v2::get_vrf_gas_config();
        let (stored_callback_price, stored_callback_limit) = main_v2::get_callback_gas_config();
        let verification_value = main_v2::get_verification_gas_value();
        assert!(stored_max_price == MAX_GAS_PRICE, 0);
        assert!(stored_max_limit == MAX_GAS_LIMIT, 1);
        assert!(stored_callback_price == CALLBACK_GAS_PRICE, 2);
        assert!(stored_callback_limit == CALLBACK_GAS_LIMIT, 3);
        assert!(verification_value == VERIFICATION_GAS_VALUE, 4);

        let events = event::emitted_events<main_v2::GasConfigUpdatedEvent>();
        assert!(vector::length(&events) == 1, 5);
        let event_ref = vector::borrow(&events, 0);
        let (
            event_max_price,
            event_max_limit,
            event_callback_price,
            event_callback_limit,
            event_verification_value,
            event_per_request_fee
        ) = main_v2::gas_config_updated_fields(event_ref);
        let expected_per_request_fee = (MAX_GAS_LIMIT + VERIFICATION_GAS_VALUE) * MAX_GAS_PRICE;
        assert!(event_max_price == MAX_GAS_PRICE, 6);
        assert!(event_max_limit == MAX_GAS_LIMIT, 7);
        assert!(event_callback_price == CALLBACK_GAS_PRICE, 8);
        assert!(event_callback_limit == CALLBACK_GAS_LIMIT, 9);
        assert!(event_verification_value == VERIFICATION_GAS_VALUE, 10);
        let expected_per_request_fee_u64 = u64::from_u128(expected_per_request_fee);
        assert!(event_per_request_fee == expected_per_request_fee_u64, 11);

        let (callback_sender, consumer_count, pending_request) =
            main_v2::gas_config_event_context(event_ref);
        assert!(option::is_some(&callback_sender), 12);
        let sender_addr = *option::borrow(&callback_sender);
        assert!(sender_addr == VRF_AGGREGATOR, 13);
        assert!(consumer_count == 2, 14);
        assert!(option::is_none(&pending_request), 15);
    }

    #[test]
    fun create_subscription_emits_subscription_context() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::whitelist_callback_sender(&lottery_signer, VRF_AGGREGATOR);
        main_v2::whitelist_consumer(&lottery_signer, PLAYER1);

        let max_gas_price = 5u64;
        let max_gas_limit = 120u64;
        let verification_value = 40u64;
        let callback_price = 2u64;
        let callback_limit = 60u64;

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            u128::from_u64(max_gas_price),
            u128::from_u64(max_gas_limit),
            u128::from_u64(callback_price),
            u128::from_u64(callback_limit),
            u128::from_u64(verification_value)
        );

        let expected_per_request_fee = (max_gas_limit + verification_value) * max_gas_price;
        let expected_min_balance = 30 * expected_per_request_fee;
        let initial_deposit = expected_min_balance + 5000;

        main_v2::create_subscription_for_test(&lottery_signer, initial_deposit);

        assert!(main_v2::get_max_gas_fee() == expected_per_request_fee, 0);

        let events = event::emitted_events<main_v2::SubscriptionConfiguredEvent>();
        assert!(vector::length(&events) == 1, 1);
        let event_ref = vector::borrow(&events, 0);
        let (
            min_balance,
            per_request_fee,
            event_max_price,
            event_max_limit,
            event_verification_value,
            event_initial_deposit,
        ) = main_v2::subscription_configured_fields(event_ref);
        assert!(min_balance == expected_min_balance, 2);
        assert!(per_request_fee == expected_per_request_fee, 3);
        assert!(event_max_price == u128::from_u64(max_gas_price), 4);
        assert!(event_max_limit == u128::from_u64(max_gas_limit), 5);
        assert!(event_verification_value == u128::from_u64(verification_value), 6);
        assert!(event_initial_deposit == initial_deposit, 7);

        let (callback_sender, consumer_count, pending_request) =
            main_v2::subscription_configured_context(event_ref);
        assert!(option::is_some(&callback_sender), 8);
        let sender_addr = *option::borrow(&callback_sender);
        assert!(sender_addr == VRF_AGGREGATOR, 9);
        assert!(consumer_count == 2, 10);
        assert!(option::is_none(&pending_request), 11);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = GAS_MATH_OVERFLOW_ERROR)]
    fun configure_vrf_gas_rejects_overflowing_sum() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let max_value = u128::max_value();
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            1u128,
            max_value,
            1u128,
            1u128,
            1u128,
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = GAS_MATH_OVERFLOW_ERROR)]
    fun configure_vrf_gas_rejects_overflowing_product() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let max_value = u128::max_value();
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            max_value,
            1u128,
            1u128,
            1u128,
            1u128,
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_GAS_CONFIG_ERROR)]
    fun configure_vrf_gas_rejects_zero_max_price() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            0u128,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE,
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_GAS_CONFIG_ERROR)]
    fun configure_vrf_gas_rejects_zero_verification_value() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            0u128,
        );
    }

    #[test]
    fun init_creates_store() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        assert!(main_v2::get_ticket_count() == 0, 1);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = ALREADY_INITIALIZED_ERROR)]
    fun init_twice_fails() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::init(&lottery_signer);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = PLAYER_STORE_NOT_REGISTERED_ERROR)]
    fun buy_ticket_requires_store_registration() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = JACKPOT_OVERFLOW_ERROR)]
    fun buy_ticket_rejects_jackpot_overflow() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, TICKET_PRICE);
        main_v2::set_jackpot_amount_for_test(u64::max_value());

        let player_signer = account::create_signer_for_test(PLAYER1);
        main_v2::buy_ticket(&player_signer);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = TICKET_ID_OVERFLOW_ERROR)]
    fun buy_ticket_rejects_ticket_id_overflow() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, TICKET_PRICE);
        main_v2::set_next_ticket_id_for_test(u64::max_value());

        let player_signer = account::create_signer_for_test(PLAYER1);
        main_v2::buy_ticket(&player_signer);
    }

    #[test]
    fun set_draw_state_helper_updates_next_ticket_id() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let tickets = vector[PLAYER1, PLAYER2];

        main_v2::set_draw_state_for_test(true, tickets);

        let next_ticket_id = main_v2::next_ticket_id_for_test();
        assert!(next_ticket_id == 3, 1001);
    }

    #[test]
    #[expected_failure(location = lottery::treasury_v1, abort_code = STORE_NOT_REGISTERED_ERROR)]
    fun mint_requires_registered_store() {
        setup_accounts_base();
        mint_to(PLAYER1, 1);
    }

    #[test]
    #[expected_failure(location = lottery::treasury_v1, abort_code = STORE_NOT_REGISTERED_ERROR)]
    fun deposit_requires_registered_store() {
        setup_accounts_base();
        let player_signer = account::create_signer_for_test(PLAYER1);
        treasury_v1::deposit_from_user(&player_signer, 1);
    }

    #[test]
    #[expected_failure(location = 0x1::fungible_asset, abort_code = STORE_FROZEN_ABORT)]
    fun deposit_rejected_when_user_store_frozen() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        mint_to(PLAYER1, 10);
        treasury_v1::set_store_frozen(&lottery_signer, PLAYER1, true);

        let player_signer = account::create_signer_for_test(PLAYER1);
        treasury_v1::deposit_from_user(&player_signer, 1);
    }

    #[test]
    #[expected_failure(location = 0x1::fungible_asset, abort_code = STORE_FROZEN_ABORT)]
    fun deposit_rejected_when_treasury_store_frozen() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        mint_to(PLAYER1, 10);
        treasury_v1::set_store_frozen(&lottery_signer, @lottery, true);

        let player_signer = account::create_signer_for_test(PLAYER1);
        treasury_v1::deposit_from_user(&player_signer, 1);
    }

    #[test]
    fun freeze_status_view_reflects_changes() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        mint_to(PLAYER1, 10);

        assert!(!treasury_v1::store_frozen(PLAYER1), 40);
        treasury_v1::set_store_frozen(&lottery_signer, PLAYER1, true);
        assert!(treasury_v1::store_frozen(PLAYER1), 41);
        treasury_v1::set_store_frozen(&lottery_signer, PLAYER1, false);
        assert!(!treasury_v1::store_frozen(PLAYER1), 42);

        let player_signer = account::create_signer_for_test(PLAYER1);
        treasury_v1::deposit_from_user(&player_signer, 5);
        assert!(treasury_v1::treasury_balance() == 5, 43);
    }

    #[test]
    fun buy_and_simple_draw() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        assert!(main_v2::get_ticket_count() == 5, 2);
        assert!(treasury_v1::treasury_balance() == 5 * TICKET_PRICE, 21);

        main_v2::simple_draw(&account::create_signer_for_test(LOTTERY_ADDR));

        assert!(main_v2::get_ticket_count() == 0, 3);
        assert!(main_v2::get_jackpot_amount() == 0, 4);
        assert!(treasury_v1::treasury_balance() == 0, 22);
    }

    #[test]
    fun jackpot_distribution_respects_config() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let total_pool = 5 * TICKET_PRICE;
        assert!(treasury_v1::treasury_balance() == total_pool, 200);

        main_v2::simple_draw(&lottery_signer);

        let winner_events = event::emitted_events<main_v2::WinnerSelected>();
        let winner_event_ref = vector::borrow(&winner_events, vector::length(&winner_events) - 1);
        let (winner_addr, winner_prize) = main_v2::winner_selected_fields(winner_event_ref);

        let expected_jackpot = total_pool * 5_000 / 10_000;
        let expected_prize = total_pool * 2_000 / 10_000;
        let expected_winner_total = expected_jackpot + expected_prize;
        let expected_treasury_share = total_pool * 1_500 / 10_000;
        let expected_marketing_share = total_pool * 800 / 10_000;
        let expected_community_share = total_pool * 400 / 10_000;
        let expected_team_share = total_pool * 200 / 10_000;
        let expected_partners_share = total_pool * 100 / 10_000;

        assert!(winner_prize == expected_winner_total, 201);

        let player1_expected =
            1_000_000_000 - (2 * TICKET_PRICE) +
            if (winner_addr == PLAYER1) { expected_winner_total } else { 0 };
        let player2_expected =
            1_000_000_000 - (3 * TICKET_PRICE) +
            if (winner_addr == PLAYER2) { expected_winner_total } else { 0 };

        assert!(treasury_v1::balance_of(PLAYER1) == player1_expected, 202);
        assert!(treasury_v1::balance_of(PLAYER2) == player2_expected, 203);

        assert!(treasury_v1::balance_of(TREASURY_RECIPIENT) == expected_treasury_share, 204);
        assert!(treasury_v1::balance_of(MARKETING_RECIPIENT) == expected_marketing_share, 205);
        assert!(treasury_v1::balance_of(COMMUNITY_RECIPIENT) == expected_community_share, 206);
        assert!(treasury_v1::balance_of(TEAM_RECIPIENT) == expected_team_share, 207);
        assert!(treasury_v1::balance_of(PARTNERS_RECIPIENT) == expected_partners_share, 208);
        assert!(treasury_v1::treasury_balance() == 0, 209);

        let payout_events = event::emitted_events<treasury_v1::JackpotDistributedEvent>();
        let payout_event_ref = vector::borrow(&payout_events, vector::length(&payout_events) - 1);
        let (
            event_winner,
            event_total,
            event_winner_share,
            event_jackpot_share,
            event_prize_share,
            event_treasury_share,
            event_marketing_share,
            event_community_share,
            event_team_share,
            event_partners_share
        ) = treasury_v1::jackpot_distribution_fields(payout_event_ref);

        assert!(event_winner == winner_addr, 210);
        assert!(event_total == total_pool, 211);
        assert!(event_winner_share == expected_winner_total, 212);
        assert!(event_jackpot_share == expected_jackpot, 213);
        assert!(event_prize_share == expected_prize, 214);
        assert!(event_treasury_share == expected_treasury_share, 215);
        assert!(event_marketing_share == expected_marketing_share, 216);
        assert!(event_community_share == expected_community_share, 217);
        assert!(event_team_share == expected_team_share, 218);
        assert!(event_partners_share == expected_partners_share, 219);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = DRAW_NOT_SCHEDULED_ERROR)]
    fun simple_draw_requires_schedule() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        main_v2::simple_draw(&account::create_signer_for_test(LOTTERY_ADDR));
    }

    #[test]
    fun compute_request_payload_hash_reacts_to_config() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let reference_hash = main_v2::compute_request_payload_hash_for_test(42, 7, LOTTERY_ADDR);
        assert!(vector::length(&reference_hash) == 32, 0);

        let repeat_hash = main_v2::compute_request_payload_hash_for_test(42, 7, LOTTERY_ADDR);
        assert!(vector_equals(&reference_hash, &repeat_hash), 1);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE + 1,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );
        let updated_hash = main_v2::compute_request_payload_hash_for_test(42, 7, LOTTERY_ADDR);
        assert!(!vector_equals(&reference_hash, &updated_hash), 2);
    }

    #[test]
    fun validate_payload_hash_succeeds_for_matching_data() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let nonce = 77;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::validate_payload_hash_for_test(nonce, client_seed, message);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_CALLBACK_PAYLOAD_ERROR)]
    fun validate_payload_hash_fails_for_mismatch() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let nonce = 88;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let tampered_message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let byte_len = vector::length(&tampered_message);
        if (byte_len > 0) {
            let last_index = byte_len - 1;
            let last_value = *vector::borrow(&tampered_message, last_index);
            let tweaked_value = last_value ^ 0x1u8;
            *vector::borrow_mut(&mut tampered_message, last_index) = tweaked_value;
        };

        main_v2::validate_payload_hash_for_test(nonce, client_seed, tampered_message);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_CALLBACK_PAYLOAD_ERROR)]
    fun validate_payload_hash_fails_for_wrong_requester() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let nonce = 99;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, PLAYER1);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, PLAYER1);
        main_v2::validate_payload_hash_for_test(nonce, client_seed, message);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_CALLBACK_PAYLOAD_ERROR)]
    fun validate_payload_hash_fails_for_mismatched_gas_configuration() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let nonce = 109;
        let client_seed = 0;

        let tampered_gas_limit = MAX_GAS_LIMIT + 1;
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            tampered_gas_limit,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        let tampered_message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let tampered_hash = hash::sha3_256(copy tampered_message);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(tampered_hash),
            option::some(LOTTERY_ADDR)
        );

        main_v2::validate_payload_hash_for_test(nonce, client_seed, tampered_message);
    }

    #[test]
    fun handle_verified_random_processes_single_rng_value() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 101;
        let client_seed = main_v2::next_client_seed_for_test();
        main_v2::record_request_for_test(nonce, LOTTERY_ADDR);

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector[999u256];
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );

        let (requests, responses) = main_v2::rng_counters_for_test();
        assert!(requests == 1, 0);
        assert!(responses == 1, 1);

        let status = main_v2::get_lottery_status();
        let (
            ticket_count,
            draw_scheduled,
            pending_request,
            jackpot_amount,
            request_count_after,
            response_count_after,
        ) = main_v2::lottery_status_fields(&status);
        assert!(ticket_count == 0, 2);
        assert!(!draw_scheduled, 3);
        assert!(!pending_request, 4);
        assert!(jackpot_amount == 0, 5);
        assert!(request_count_after == requests, 6);
        assert!(response_count_after == responses, 7);

        let config_after = main_v2::get_vrf_request_config();
        assert!(option::is_none(&config_after), 13);

        let draw_events = event::emitted_events<main_v2::DrawHandledEvent>();
        assert!(vector::length(&draw_events) == 1, 8);
        let draw_event_ref = vector::borrow(&draw_events, 0);
        let (event_nonce, event_success) = main_v2::draw_handled_fields(draw_event_ref);
        assert!(event_nonce == nonce, 10);
        assert!(event_success, 11);

        let winner_events = event::emitted_events<main_v2::WinnerSelected>();
        assert!(vector::length(&winner_events) == 1, 12);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = UNEXPECTED_RNG_COUNT_ERROR)]
    fun handle_verified_random_rejects_wrong_rng_count() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 202;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector[55u256];
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            2,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = UNEXPECTED_RNG_COUNT_ERROR)]
    fun handle_verified_random_rejects_wrong_vector_length() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 303;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector::empty<u256>();
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = DRAW_NOT_SCHEDULED_ERROR)]
    fun handle_verified_random_rejects_when_draw_not_scheduled() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        let nonce = 404;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);

        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let tickets = vector[PLAYER1];
        main_v2::set_draw_state_for_test(false, tickets);

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector[777u256];

        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = EXPECTED_CALLBACK_SOURCE_ERROR)]
    fun handle_verified_random_requires_configured_aggregator() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 404;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector[55u256];
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = CALLBACK_CALLER_NOT_ALLOWED_ERROR)]
    fun handle_verified_random_rejects_unwhitelisted_caller() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 505;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, LOTTERY_ADDR);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, LOTTERY_ADDR);
        let verified_nums = vector[77u256];
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            UNAUTHORIZED_CALLBACK
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = INVALID_CALLBACK_PAYLOAD_ERROR)]
    fun handle_verified_random_rejects_wrong_requester_in_payload() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let nonce = 606;
        let client_seed = 0;
        let stored_hash = main_v2::compute_request_payload_hash_for_test(nonce, client_seed, PLAYER1);
        main_v2::set_pending_request_and_hash_for_test(
            option::some(nonce),
            option::some(stored_hash),
            option::some(LOTTERY_ADDR)
        );

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, PLAYER1);
        let verified_nums = vector[42u256];
        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = EXPECTED_GAS_ERROR)]
    fun manual_draw_requires_configured_gas() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        buy_ticket_for(PLAYER1);
        buy_ticket_for(PLAYER2);
        buy_ticket_for(PLAYER1);
        buy_ticket_for(PLAYER2);
        buy_ticket_for(PLAYER1);

        main_v2::manual_draw(&lottery_signer);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = EXPECTED_CALLBACK_SOURCE_ERROR)]
    fun manual_draw_requires_whitelisted_callback_sender() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        buy_ticket_for(PLAYER1);
        buy_ticket_for(PLAYER2);
        buy_ticket_for(PLAYER1);
        buy_ticket_for(PLAYER2);
        buy_ticket_for(PLAYER1);

        main_v2::manual_draw(&lottery_signer);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = NO_TICKETS_ERROR)]
    fun manual_draw_rejects_without_tickets() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        configure_gas_default();
        whitelist_callback_sender();
        whitelist_consumer(LOTTERY_ADDR);

        let empty_tickets = vector::empty<address>();
        main_v2::set_draw_state_for_test(true, empty_tickets);

        main_v2::manual_draw(&lottery_signer);
    }

    #[test]
    fun record_request_emits_client_seed_and_increments_counter() {
        setup_accounts();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        main_v2::record_request_for_test(100, LOTTERY_ADDR);
        main_v2::record_request_for_test(200, LOTTERY_ADDR);

        let events = event::emitted_events<main_v2::DrawRequestedEvent>();
        let event_len = vector::length(&events);
        assert!(event_len == 2, 34);

        let first_event = vector::borrow(&events, 0);
        let second_event = vector::borrow(&events, 1);

        let (first_nonce, first_seed, _, _, _, first_requester) = main_v2::draw_requested_fields(first_event);
        assert!(first_nonce == 100, 35);
        assert!(first_seed == 0, 36);
        assert!(first_requester == LOTTERY_ADDR, 350);

        let (second_nonce, second_seed, _, _, _, second_requester) = main_v2::draw_requested_fields(second_event);
        assert!(second_nonce == 200, 37);
        assert!(second_seed == 1, 38);
        assert!(second_requester == LOTTERY_ADDR, 351);

        let (request_count, response_count) = main_v2::rng_counters_for_test();
        assert!(request_count == 2, 39);
        assert!(response_count == 0, 40);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = RNG_REQUEST_OVERFLOW_ERROR)]
    fun record_request_rejects_request_counter_overflow() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();

        main_v2::set_rng_counters_for_test(u64::max_value(), 0);

        main_v2::record_request_for_test(500, LOTTERY_ADDR);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = RNG_RESPONSE_OVERFLOW_ERROR)]
    fun handle_verified_random_rejects_response_counter_overflow() {
        setup_accounts();
        register_system_stores();
        configure_recipients();

        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        whitelist_callback_sender();
        whitelist_consumer(PLAYER1);

        mint_to(PLAYER1, 1_000_000_000);
        buy_ticket_for(PLAYER1);

        main_v2::set_rng_counters_for_test(0, u64::max_value());

        let nonce = 777;
        let client_seed = main_v2::next_client_seed_for_test();
        main_v2::record_request_for_test(nonce, PLAYER1);

        let message = main_v2::request_payload_message_for_test(nonce, client_seed, PLAYER1);
        let verified_nums = vector[123u256];

        main_v2::handle_verified_random_for_test(
            nonce,
            message,
            verified_nums,
            1,
            client_seed,
            VRF_AGGREGATOR
        );
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = REQUEST_STILL_PENDING_ERROR)]
    fun gas_configuration_blocked_during_pending_request() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );

        main_v2::set_pending_request_for_test(option::some(99));

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE + 1,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT,
            VERIFICATION_GAS_VALUE
        );
    }

    #[test]
    fun account_status_view_reports_registration_and_balance() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 500);

        let (registered, store_opt, balance) = treasury_v1::account_status(PLAYER1);
        assert!(registered, 0);
        assert!(option::is_some(&store_opt), 1);
        assert!(balance == 500, 2);

        let (extended_registered, frozen_flag, extended_store_opt, extended_balance) =
            treasury_v1::account_extended_status(PLAYER1);
        assert!(extended_registered, 3);
        assert!(!frozen_flag, 4);
        assert!(option::is_some(&extended_store_opt), 5);
        assert!(extended_balance == 500, 6);

        let store_addr = option::borrow(&store_opt);
        let extended_store_addr = option::borrow(&extended_store_opt);
        assert!(*store_addr == *extended_store_addr, 7);

        let (second_registered, second_store_opt, second_balance) = treasury_v1::account_status(@0x4);
        assert!(!second_registered, 8);
        assert!(!option::is_some(&second_store_opt), 9);
        assert!(second_balance == 0, 10);

        let (second_ext_registered, second_frozen, second_ext_store_opt, second_ext_balance) =
            treasury_v1::account_extended_status(@0x4);
        assert!(!second_ext_registered, 11);
        assert!(!second_frozen, 12);
        assert!(!option::is_some(&second_ext_store_opt), 13);
        assert!(second_ext_balance == 0, 14);
    }

    #[test]
    fun treasury_views_expose_metadata_and_store_state() {
        setup_accounts();

        let (name, symbol, decimals, icon_uri, project_uri) = treasury_v1::metadata_summary();
        assert!(decimals == DECIMALS, 23);
        assert!(vector_equals(string::bytes(&name), &b"Lottery Ticket"), 24);
        assert!(vector_equals(string::bytes(&symbol), &b"LOT"), 25);
        assert!(vector_equals(string::bytes(&icon_uri), &b""), 26);
        assert!(vector_equals(string::bytes(&project_uri), &b""), 27);

        assert!(treasury_v1::is_initialized(), 28);
        assert!(treasury_v1::store_registered(LOTTERY_ADDR), 29);
        assert!(treasury_v1::store_registered(PLAYER1), 30);
        assert!(treasury_v1::store_registered(PLAYER2), 31);

        let extra_addr = @0x4;
        account::create_account_for_test(extra_addr);
        assert!(!treasury_v1::store_registered(extra_addr), 32);

        let store_addr = treasury_v1::primary_store_address(PLAYER1);
        assert!(store_addr != @0x0, 33);
    }

    fun vector_equals(lhs: &vector<u8>, rhs: &vector<u8>): bool {
        if (vector::length(lhs) != vector::length(rhs)) {
            return false
        };
        let i = 0;
        let len = vector::length(lhs);
        while (i < len) {
            if (*vector::borrow(lhs, i) != *vector::borrow(rhs, i)) {
                return false
            };
            i = i + 1;
        };
        true
    }

    #[test]
    fun lottery_status_reflects_state_changes() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let initial_status = main_v2::get_lottery_status();
        let (
            initial_tickets,
            initial_draw_scheduled,
            initial_pending,
            initial_jackpot,
            initial_request_count,
            initial_response_count,
        ) = main_v2::lottery_status_fields(&initial_status);
        assert!(initial_tickets == 0, 0);
        assert!(!initial_draw_scheduled, 1);
        assert!(!initial_pending, 2);
        assert!(initial_jackpot == 0, 3);
        assert!(initial_request_count == 0, 4);
        assert!(initial_response_count == 0, 5);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let status_after_purchases = main_v2::get_lottery_status();
        let (
            scheduled_tickets,
            is_scheduled,
            pending_after_purchases,
            jackpot_after_purchases,
            request_count_after_purchases,
            response_count_after_purchases,
        ) = main_v2::lottery_status_fields(&status_after_purchases);
        assert!(scheduled_tickets == 5, 6);
        assert!(is_scheduled, 7);
        assert!(!pending_after_purchases, 8);
        assert!(jackpot_after_purchases == 5 * TICKET_PRICE, 9);
        assert!(request_count_after_purchases == 0, 10);
        assert!(response_count_after_purchases == 0, 11);

        main_v2::set_pending_request_for_test(option::some(99));
        let status_after_pending = main_v2::get_lottery_status();
        let (_, _, pending_after_flag, _, _, _) = main_v2::lottery_status_fields(&status_after_pending);
        assert!(pending_after_flag, 12);

        main_v2::set_pending_request_for_test(option::none());
    }

    #[test]
    fun rng_counters_default_zero() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let (requests, responses) = main_v2::get_rng_counters();
        assert!(requests == 0, 0);
        assert!(responses == 0, 1);
    }

    #[test]
    fun clear_pending_request_state_handles_empty_options() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        // Calling helper with empty state must not abort.
        main_v2::clear_pending_request_state_for_test();

        let payload = vector::empty<u8>();
        main_v2::set_pending_request_and_hash_for_test(
            option::some(7),
            option::some(payload),
            option::some(PLAYER1),
        );

        // First call clears stored values, second call operates on empty options.
        main_v2::clear_pending_request_state_for_test();
        main_v2::clear_pending_request_state_for_test();
    }

    #[test]
    fun ticket_purchase_emits_event() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));

        let events = event::emitted_events<main_v2::TicketBought>();
        assert!(vector::length(&events) == 1, 0);
        let event_ref = vector::borrow(&events, 0);
        let (buyer, ticket_id, amount) = main_v2::ticket_bought_fields(event_ref);
        assert!(buyer == PLAYER1, 1);
        assert!(ticket_id == 1, 2);
        assert!(amount == TICKET_PRICE, 3);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = NOT_OWNER_ERROR)]
    fun withdraw_requires_admin() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::withdraw_funds(&account::create_signer_for_test(PLAYER1), 1);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = WITHDRAWAL_PENDING_REQUEST_ERROR)]
    fun withdraw_fails_with_pending_request() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::set_pending_request_for_test(option::some(7));

        main_v2::withdraw_funds(&lottery_signer, 1);
    }

    #[test]
    fun withdraw_emits_event() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::withdraw_funds_for_test(&lottery_signer, 250);

        let events = event::emitted_events<main_v2::FundsWithdrawnEvent>();
        assert!(vector::length(&events) == 1, 0);
        let event_ref = vector::borrow(&events, 0);
        let (admin, amount) = main_v2::funds_withdrawn_fields(event_ref);
        assert!(admin == LOTTERY_ADDR, 1);
        assert!(amount == 250, 2);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = NOT_OWNER_ERROR)]
    fun set_minimum_balance_requires_admin() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::set_minimum_balance(&account::create_signer_for_test(PLAYER1));
    }

    #[test]
    fun set_minimum_balance_updates_state_and_event() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::whitelist_callback_sender(&lottery_signer, VRF_AGGREGATOR);
        main_v2::whitelist_consumer(&lottery_signer, PLAYER1);

        let custom_max_price = 7u64;
        let custom_max_limit = 13u64;
        let custom_verification = 19u64;
        let custom_callback_price = 5u64;
        let custom_callback_limit = 29u64;

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            u128::from_u64(custom_max_price),
            u128::from_u64(custom_max_limit),
            u128::from_u64(custom_callback_price),
            u128::from_u64(custom_callback_limit),
            u128::from_u64(custom_verification)
        );

        main_v2::set_minimum_balance_for_test(&lottery_signer);

        let expected_per_request_fee = (custom_max_limit + custom_verification) * custom_max_price;
        let expected_min_balance = 30 * expected_per_request_fee;

        assert!(main_v2::get_max_gas_fee() == expected_per_request_fee, 0);

        let events = event::emitted_events<main_v2::MinimumBalanceUpdatedEvent>();
        assert!(vector::length(&events) == 1, 1);
        let event_ref = vector::borrow(&events, 0);
        let (
            min_balance,
            per_request_fee,
            event_max_price,
            event_max_limit,
            event_verification_value
        ) = main_v2::minimum_balance_updated_fields(event_ref);
        assert!(min_balance == expected_min_balance, 2);
        assert!(per_request_fee == expected_per_request_fee, 3);
        assert!(event_max_price == u128::from_u64(custom_max_price), 4);
        assert!(event_max_limit == u128::from_u64(custom_max_limit), 5);
        assert!(event_verification_value == u128::from_u64(custom_verification), 6);

        let (callback_sender, consumer_count, pending_request) =
            main_v2::minimum_balance_event_context(event_ref);
        assert!(option::is_some(&callback_sender), 7);
        let sender_addr = *option::borrow(&callback_sender);
        assert!(sender_addr == VRF_AGGREGATOR, 8);
        assert!(consumer_count == 2, 9);
        assert!(option::is_none(&pending_request), 10);
    }

    #[test]
    fun minimum_balance_reacts_to_gas_changes() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::whitelist_callback_sender(&lottery_signer, VRF_AGGREGATOR);
        main_v2::whitelist_consumer(&lottery_signer, PLAYER1);

        let first_price = 3u64;
        let first_limit = 20u64;
        let first_verification = 11u64;
        let callback_price = 4u64;
        let callback_limit = 25u64;

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            u128::from_u64(first_price),
            u128::from_u64(first_limit),
            u128::from_u64(callback_price),
            u128::from_u64(callback_limit),
            u128::from_u64(first_verification)
        );
        main_v2::set_minimum_balance_for_test(&lottery_signer);

        let second_price = 9u64;
        let second_limit = 15u64;
        let second_verification = 17u64;

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            u128::from_u64(second_price),
            u128::from_u64(second_limit),
            u128::from_u64(callback_price),
            u128::from_u64(callback_limit),
            u128::from_u64(second_verification)
        );
        main_v2::set_minimum_balance_for_test(&lottery_signer);

        let events = event::emitted_events<main_v2::MinimumBalanceUpdatedEvent>();
        assert!(vector::length(&events) == 2, 7);

        let first_expected_per_request = (first_limit + first_verification) * first_price;
        let first_expected_min_balance = 30 * first_expected_per_request;
        let (first_min_balance, first_per_request_fee, first_price_event, first_limit_event, first_verification_event) =
            main_v2::minimum_balance_updated_fields(vector::borrow(&events, 0));
        assert!(first_min_balance == first_expected_min_balance, 8);
        assert!(first_per_request_fee == first_expected_per_request, 9);
        assert!(first_price_event == u128::from_u64(first_price), 10);
        assert!(first_limit_event == u128::from_u64(first_limit), 11);
        assert!(first_verification_event == u128::from_u64(first_verification), 12);
        let (first_sender, first_consumer_count, first_pending) =
            main_v2::minimum_balance_event_context(vector::borrow(&events, 0));
        assert!(option::is_some(&first_sender), 18);
        let first_addr = *option::borrow(&first_sender);
        assert!(first_addr == VRF_AGGREGATOR, 19);
        assert!(first_consumer_count == 2, 20);
        assert!(option::is_none(&first_pending), 21);

        let second_expected_per_request = (second_limit + second_verification) * second_price;
        let second_expected_min_balance = 30 * second_expected_per_request;
        let (second_min_balance, second_per_request_fee, second_price_event, second_limit_event, second_verification_event) =
            main_v2::minimum_balance_updated_fields(vector::borrow(&events, 1));
        assert!(second_min_balance == second_expected_min_balance, 13);
        assert!(second_per_request_fee == second_expected_per_request, 14);
        assert!(second_price_event == u128::from_u64(second_price), 15);
        assert!(second_limit_event == u128::from_u64(second_limit), 16);
        assert!(second_verification_event == u128::from_u64(second_verification), 17);
        let (second_sender, second_consumer_count, second_pending) =
            main_v2::minimum_balance_event_context(vector::borrow(&events, 1));
        assert!(option::is_some(&second_sender), 22);
        let second_addr = *option::borrow(&second_sender);
        assert!(second_addr == VRF_AGGREGATOR, 23);
        assert!(second_consumer_count == 2, 24);
        assert!(option::is_none(&second_pending), 25);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = GAS_MATH_OVERFLOW_ERROR)]
    fun set_minimum_balance_rejects_overflowing_window_product() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        let price = u128::max_value() / 2u128;
        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            price,
            1u128,
            1u128,
            1u128,
            1u128,
        );

        main_v2::set_minimum_balance_for_test(&lottery_signer);
    }

    #[test]
    #[expected_failure(location = lottery::main_v2, abort_code = PENDING_REQUEST_STATE_ERROR)]
    fun simple_draw_rejects_when_pending_request() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));

        main_v2::set_pending_request_for_test(option::some(99));

        main_v2::simple_draw(&lottery_signer);
    }

    #[test]
    fun registered_tickets_view_returns_all() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        mint_to(PLAYER1, 1_000_000_000);
        mint_to(PLAYER2, 1_000_000_000);

        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER2));

        let tickets = main_v2::get_registered_tickets();
        assert!(vector::length(&tickets) == 3, 1);
        assert!(*vector::borrow(&tickets, 0) == PLAYER1, 2);
        assert!(*vector::borrow(&tickets, 1) == PLAYER2, 3);
        assert!(*vector::borrow(&tickets, 2) == PLAYER2, 4);
    }

    #[test]
    fun is_vrf_request_pending_reflects_resource_state() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        assert!(!main_v2::is_vrf_request_pending(), 0);

        main_v2::set_pending_request_for_test(option::some(777));
        assert!(main_v2::is_vrf_request_pending(), 1);

        main_v2::set_pending_request_for_test(option::none());
        assert!(!main_v2::is_vrf_request_pending(), 2);
    }
}
