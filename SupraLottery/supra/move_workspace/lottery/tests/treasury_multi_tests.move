#[test_only]
module lottery::treasury_multi_tests {
    use std::vector;
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

        let pool = test_utils::unwrap(treasury_multi::get_pool(1));
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 600, 1);
        assert!(operations_balance == 200, 2);
        assert!(treasury_multi::jackpot_balance() == 200, 3);

        let config = test_utils::unwrap(treasury_multi::get_config(1));
        let (prize_bps, jackpot_bps, operations_bps) =
            treasury_multi::share_config_bps_for_test(&config);
        assert!(prize_bps == 6_000, 4);
        assert!(jackpot_bps == 2_000, 5);
        assert!(operations_bps == 2_000, 6);

        let ids = treasury_multi::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 7);
        assert!(*vector::borrow(&ids, 0) == 1, 8);

        let summary = test_utils::unwrap(treasury_multi::get_lottery_summary(1));
        let (summary_config, summary_pool) = treasury_multi::summary_components_for_test(&summary);
        let (s_prize, s_jackpot, s_ops) =
            treasury_multi::share_config_bps_for_test(&summary_config);
        let (s_prize_balance, s_ops_balance) =
            treasury_multi::pool_balances_for_test(&summary_pool);
        assert!(s_prize == 6_000, 9);
        assert!(s_jackpot == 2_000, 10);
        assert!(s_ops == 2_000, 11);
        assert!(s_prize_balance == 600, 12);
        assert!(s_ops_balance == 200, 13);

        treasury_multi::upsert_lottery_config(lottery_admin, 1, 5_500, 2_500, 2_000);
        let ids_after_update = treasury_multi::list_lottery_ids();
        assert!(vector::length(&ids_after_update) == 1, 14);
        assert!(*vector::borrow(&ids_after_update, 0) == 1, 15);
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

        let pool = test_utils::unwrap(treasury_multi::get_pool(1));
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 0, 1);
        assert!(operations_balance == 20, 2);

        let winner_balance = treasury_v1::balance_of(signer::address_of(winner));

        assert!(winner_balance == 940, 3);

        let summary_after_prize = test_utils::unwrap(treasury_multi::get_lottery_summary(1));
        let (_config_after, after_pool) =
            treasury_multi::summary_components_for_test(&summary_after_prize);
        let (after_prize_balance, after_ops_balance) =
            treasury_multi::pool_balances_for_test(&after_pool);
        assert!(after_prize_balance == 0, 4);
        assert!(after_ops_balance == 20, 5);
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

        let pool = test_utils::unwrap(treasury_multi::get_pool(1));
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(operations_balance == 0, 1);
        assert!(prize_balance == 600, 2);


        treasury_multi::distribute_jackpot(lottery_admin, signer::address_of(winner), 200);
        assert!(treasury_v1::balance_of(signer::address_of(winner)) == 4_200, 3);
        assert!(treasury_multi::jackpot_balance() == 0, 4);

        let summary_after_ops = test_utils::unwrap(treasury_multi::get_lottery_summary(1));
        let (_config_post, post_pool) = treasury_multi::summary_components_for_test(&summary_after_ops);
        let (post_prize, post_ops) = treasury_multi::pool_balances_for_test(&post_pool);
        assert!(post_prize == 600, 5);
        assert!(post_ops == 0, 6);
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
