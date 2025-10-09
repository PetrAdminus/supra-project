module lottery::treasury_multi_tests {
    use std::option;
    use std::vector;
    use std::u128;
    use std::account;
    use std::signer;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery::test_utils;

    fun init_token(lottery_admin: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"multi_seed",
            b"Multi Lottery Token",
            b"MLT",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
    }

    #[test(lottery_admin = @lottery)]
    fun init_and_allocate(lottery_admin: &signer) {
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        assert!(treasury_multi::is_initialized(), 0);

        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);
        treasury_multi::record_allocation(lottery_admin, 1, 1_000);

        let (prize_balance, operations_balance) = treasury_multi::get_pool_balances(1);
        assert!(prize_balance == u128::from_u64(600), 1);
        assert!(operations_balance == u128::from_u64(200), 2);
        assert!(treasury_multi::jackpot_balance() == 200, 3);

        let (prize_bps, jackpot_bps, operations_bps) = treasury_multi::get_share_config(1);
        assert!(prize_bps == 6_000, 4);
        assert!(jackpot_bps == 2_000, 5);
        assert!(operations_bps == 2_000, 6);

        let ids = treasury_multi::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 7);
        assert!(*vector::borrow(&ids, 0) == 1, 8);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 5_500, 2_500, 2_000);
        let ids_after_update = treasury_multi::list_lottery_ids();
        assert!(vector::length(&ids_after_update) == 1, 9);
        assert!(*vector::borrow(&ids_after_update, 0) == 1, 10);
    }

    #[test(lottery_admin = @lottery, winner = @player1)]
    fun prize_distribution(lottery_admin: &signer, winner: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 7_000, 2_000, 1_000);

        treasury_v1::register_store(winner);
        treasury_v1::mint_to(lottery_admin, signer::address_of(winner), 1_000);
        treasury_v1::deposit_from_user(winner, 200);
        treasury_multi::record_allocation(lottery_admin, 1, 200);

        treasury_multi::distribute_prize(lottery_admin, 1, signer::address_of(winner));

        let (prize_balance, operations_balance) = treasury_multi::get_pool_balances(1);
        assert!(prize_balance == u128::from_u64(0), 0);
        assert!(operations_balance == u128::from_u64(20), 1);

        let winner_balance = treasury_v1::balance_of(signer::address_of(winner));
        assert!(winner_balance == 940, 2);
    }

    #[test(lottery_admin = @lottery, winner = @player2)]
    fun operations_and_jackpot_withdrawals(lottery_admin: &signer, winner: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::register_store(winner);
        treasury_v1::mint_to(lottery_admin, signer::address_of(winner), 5_000);
        treasury_v1::deposit_from_user(winner, 1_000);
        treasury_multi::record_allocation(lottery_admin, 1, 1_000);

        treasury_multi::withdraw_operations(lottery_admin, 1);
        assert!(treasury_v1::balance_of(@operations_pool) == 200, 0);

        let (prize_balance, operations_balance) = treasury_multi::get_pool_balances(1);
        assert!(operations_balance == u128::from_u64(0), 1);
        assert!(prize_balance == u128::from_u64(600), 2);

        treasury_multi::distribute_jackpot(lottery_admin, signer::address_of(winner), 200);
        assert!(treasury_v1::balance_of(signer::address_of(winner)) == 4_200, 3);
        assert!(treasury_multi::jackpot_balance() == 0, 4);

        let (post_prize, post_ops) = treasury_multi::get_pool_balances(1);
        assert!(post_prize == u128::from_u64(600), 5);
        assert!(post_ops == u128::from_u64(0), 6);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 4)]
    fun invalid_basis_points(lottery_admin: &signer) {
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 5_000, 2_000, 1_000);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 5)]
    fun cannot_allocate_without_config(lottery_admin: &signer) {
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        treasury_multi::record_allocation(lottery_admin, 1, 500);
    }
}
