module lottery::jackpot_tests {
    use std::option;
    use std::vector;
    use std::account;
    use std::signer;
    use lottery::jackpot;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use vrf_hub::hub;

    fun setup_token(lottery_admin: &signer, player1: &signer, player2: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"jackpot_seed",
            b"Jackpot Token",
            b"JCK",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(player1);
        treasury_v1::register_store(player2);
        treasury_v1::mint_to(lottery_admin, signer::address_of(player1), 5_000);
        treasury_v1::mint_to(lottery_admin, signer::address_of(player2), 5_000);
    }

    fun build_randomness(value: u8): vector<u8> {
        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, value);
        let i = 1;
        while (i < 8) {
            vector::push_back(&mut randomness, 0);
            i = i + 1;
        };
        randomness
    }

    #[test(
        vrf_admin = @vrf_hub,
        lottery_admin = @lottery,
        player1 = @player1,
        player2 = @player2,
        aggregator = @0x45,
    )]
    fun jackpot_full_cycle(
        vrf_admin: &signer,
        lottery_admin: &signer,
        player1: &signer,
        player2: &signer,
        aggregator: &signer,
    ) {
        hub::init(vrf_admin);
        let lottery_id = hub::register_lottery(vrf_admin, @lottery_owner, @lottery_contract, b"jackpot");
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        jackpot::init(lottery_admin, lottery_id);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 0, 10_000, 0);
        setup_token(lottery_admin, player1, player2);

        treasury_v1::deposit_from_user(player1, 1_000);
        treasury_multi::record_allocation(lottery_admin, 1, 1_000);
        assert!(treasury_multi::jackpot_balance() == 1_000, 0);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);

        jackpot::grant_ticket(lottery_admin, player1_addr);
        jackpot::grant_ticket(lottery_admin, player2_addr);
        jackpot::schedule_draw(lottery_admin);
        jackpot::request_randomness(lottery_admin, b"global");

        let request_id = option::extract(jackpot::pending_request());
        let randomness = build_randomness(1);
        jackpot::fulfill_draw(aggregator, request_id, randomness);

        let snapshot = option::extract(jackpot::get_snapshot());
        let jackpot::JackpotSnapshot { ticket_count, draw_scheduled, has_pending_request } = snapshot;
        assert!(ticket_count == 0, 1);
        assert!(!draw_scheduled, 2);
        assert!(!has_pending_request, 3);

        assert!(treasury_multi::jackpot_balance() == 0, 4);
        assert!(treasury_v1::treasury_balance() == 0, 5);
        assert!(treasury_v1::balance_of(player1_addr) == 4_000, 6);
        assert!(treasury_v1::balance_of(player2_addr) == 6_000, 7);
    }

    #[test(
        vrf_admin = @vrf_hub,
        lottery_admin = @lottery,
        player1 = @player3,
        player2 = @player4,
        aggregator = @0x46,
    )]
    #[expected_failure(abort_code = 11)]
    fun jackpot_requires_balance(
        vrf_admin: &signer,
        lottery_admin: &signer,
        player1: &signer,
        player2: &signer,
        aggregator: &signer,
    ) {
        hub::init(vrf_admin);
        let lottery_id = hub::register_lottery(vrf_admin, @lottery_owner, @lottery_contract, b"jackpot-empty");
        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        jackpot::init(lottery_admin, lottery_id);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 2, 0, 10_000, 0);
        setup_token(lottery_admin, player1, player2);

        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);
        jackpot::grant_ticket(lottery_admin, player1_addr);
        jackpot::grant_ticket(lottery_admin, player2_addr);
        jackpot::schedule_draw(lottery_admin);
        jackpot::request_randomness(lottery_admin, b"global");

        let request_id = option::extract(jackpot::pending_request());
        let randomness = build_randomness(0);
        jackpot::fulfill_draw(aggregator, request_id, randomness);
    }
}
