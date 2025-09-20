#[test_only]
module lottery::lottery_tests {
    use 0x1::account;
    use 0x1::coin;
    use 0x1::event;
    use 0x1::supra_coin;
    use 0x1::supra_coin::SupraCoin;
    use 0x1::timestamp;
    use std::option;
    use std::vector;
    use lottery::main_v2;

    const LOTTERY_ADDR: address = @lottery;
    const ADMIN: address = @0x1;
    const PLAYER1: address = @0x2;
    const PLAYER2: address = @0x3;
    const TICKET_PRICE: u64 = 10000000;

    fun setup_accounts() {
        account::create_account_for_test(LOTTERY_ADDR);
        account::create_account_for_test(PLAYER1);
        account::create_account_for_test(PLAYER2);

        supra_coin::ensure_initialized_with_sup_fa_metadata_for_test();

        let framework = account::create_signer_for_test(ADMIN);
        timestamp::set_time_has_started_for_testing(&framework);

        let player1_signer = account::create_signer_for_test(PLAYER1);
        coin::register<SupraCoin>(&player1_signer);

        let player2_signer = account::create_signer_for_test(PLAYER2);
        coin::register<SupraCoin>(&player2_signer);
    }

    fun mint_to(addr: address, amount: u64) {
        supra_coin::ensure_initialized_with_sup_fa_metadata_for_test();
        let framework = account::create_signer_for_test(ADMIN);
        supra_coin::mint(&framework, addr, amount);
    }

    #[test]
    fun init_creates_store() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        assert!(main_v2::get_ticket_count() == 0, 1);
    }

    #[test]
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 2)]
    fun init_twice_fails() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);
        main_v2::init(&lottery_signer);
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

        main_v2::simple_draw(&account::create_signer_for_test(LOTTERY_ADDR));

        assert!(main_v2::get_ticket_count() == 0, 3);
        assert!(main_v2::get_jackpot_amount() == 0, 4);
    }

    #[test]
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 4)]
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
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 1)]
    fun withdraw_requires_admin() {
        setup_accounts();
        let lottery_signer = account::create_signer_for_test(LOTTERY_ADDR);
        main_v2::init(&lottery_signer);

        main_v2::withdraw_funds(&account::create_signer_for_test(PLAYER1), 1);
    }

    #[test]
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 10)]
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
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 1)]
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
    #[expected_failure(location = 0x50989d6bf578d211a2f3b54833e3a1e3c5864ec64f9b24bad6d24a7bd69e9cde::main_v2, abort_code = 6)]
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