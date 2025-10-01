#[test_only]
module lottery::lottery_tests {
    use 0x1::account;
    use 0x1::event;
    use 0x1::timestamp;
    use std::option;
    use std::string;
    use std::vector;
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
    const TICKET_PRICE: u64 = 10000000;
    const DECIMALS: u8 = 9;
    const STORE_FROZEN_ABORT: u64 = 0x50003;
    const MAX_GAS_PRICE: u128 = 100;
    const MAX_GAS_LIMIT: u128 = 200;
    const CALLBACK_GAS_PRICE: u128 = 10;
    const CALLBACK_GAS_LIMIT: u128 = 40;

    fun setup_accounts_base() {
        account::create_account_for_test(LOTTERY_ADDR);
        account::create_account_for_test(PLAYER1);
        account::create_account_for_test(PLAYER2);
        account::create_account_for_test(TREASURY_RECIPIENT);
        account::create_account_for_test(MARKETING_RECIPIENT);
        account::create_account_for_test(COMMUNITY_RECIPIENT);
        account::create_account_for_test(TEAM_RECIPIENT);
        account::create_account_for_test(PARTNERS_RECIPIENT);

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

    fun mint_to(addr: address, amount: u64) {
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        treasury_v1::mint_to(&lottery_signer, addr, amount);
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

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT
        );

        let (stored_max_price, stored_max_limit) = main_v2::get_vrf_gas_config();
        let (stored_callback_price, stored_callback_limit) = main_v2::get_callback_gas_config();
        assert!(stored_max_price == MAX_GAS_PRICE, 0);
        assert!(stored_max_limit == MAX_GAS_LIMIT, 1);
        assert!(stored_callback_price == CALLBACK_GAS_PRICE, 2);
        assert!(stored_callback_limit == CALLBACK_GAS_LIMIT, 3);

        let events = event::emitted_events<main_v2::GasConfigUpdatedEvent>();
        assert!(vector::length(&events) == 1, 4);
        let event_ref = vector::borrow(&events, 0);
        let (event_max_price, event_max_limit, event_callback_price, event_callback_limit) = main_v2::gas_config_updated_fields(event_ref);
        assert!(event_max_price == MAX_GAS_PRICE, 5);
        assert!(event_max_limit == MAX_GAS_LIMIT, 6);
        assert!(event_callback_price == CALLBACK_GAS_PRICE, 7);
        assert!(event_callback_limit == CALLBACK_GAS_LIMIT, 8);
    }

    #[test]
    fun init_creates_store() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        assert!(main_v2::get_ticket_count() == 0, 1);
    }

    #[test]
    #[expected_failure(location = @lottery::main_v2, abort_code = 2)]
    fun init_twice_fails() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::init(&lottery_signer);
    }

    #[test]
    #[expected_failure(location = @lottery::main_v2, abort_code = 13)]
    fun buy_ticket_requires_store_registration() {
        setup_accounts_base();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::buy_ticket(&account::create_signer_for_test(PLAYER1));
    }

    #[test]
    #[expected_failure(location = @lottery::treasury_v1, abort_code = 4)]
    fun mint_requires_registered_store() {
        setup_accounts_base();
        mint_to(PLAYER1, 1);
    }

    #[test]
    #[expected_failure(location = @lottery::treasury_v1, abort_code = 4)]
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
    #[expected_failure(location = @lottery::main_v2, abort_code = 4)]
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
            CALLBACK_GAS_LIMIT
        );

        let reference_hash = main_v2::compute_request_payload_hash_for_test(42, 7);
        assert!(vector::length(&reference_hash) == 32, 0);

        let repeat_hash = main_v2::compute_request_payload_hash_for_test(42, 7);
        assert!(vector_equals(&reference_hash, &repeat_hash), 1);

        main_v2::configure_vrf_gas_for_test(
            &lottery_signer,
            MAX_GAS_PRICE + 1,
            MAX_GAS_LIMIT,
            CALLBACK_GAS_PRICE,
            CALLBACK_GAS_LIMIT
        );
        let updated_hash = main_v2::compute_request_payload_hash_for_test(42, 7);
        assert!(!vector_equals(&reference_hash, &updated_hash), 2);
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
    #[expected_failure(location = @lottery::main_v2, abort_code = 1)]
    fun withdraw_requires_admin() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::withdraw_funds(&account::create_signer_for_test(PLAYER1), 1);
    }

    #[test]
    #[expected_failure(location = @lottery::main_v2, abort_code = 10)]
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
    #[expected_failure(location = @lottery::main_v2, abort_code = 1)]
    fun set_minimum_balance_requires_admin() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::set_minimum_balance(&account::create_signer_for_test(PLAYER1), 42);
    }

    #[test]
    fun set_minimum_balance_updates_state_and_event() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::set_minimum_balance_for_test(&lottery_signer, 42);

        assert!(main_v2::get_max_gas_fee() == 42, 0);

        let events = event::emitted_events<main_v2::MinimumBalanceUpdatedEvent>();
        assert!(vector::length(&events) == 1, 1);
        let event_ref = vector::borrow(&events, 0);
        let (max_gas_fee, min_balance) = main_v2::minimum_balance_updated_fields(event_ref);
        assert!(max_gas_fee == 42, 2);
        assert!(min_balance == 42 * 30, 3);
    }

    #[test]
    #[expected_failure(location = @lottery::main_v2, abort_code = 6)]
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