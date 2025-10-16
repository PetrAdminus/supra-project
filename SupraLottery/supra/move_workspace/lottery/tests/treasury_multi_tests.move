#[test_only]
module lottery::treasury_multi_tests {
    use std::vector;
    use std::option;
    use supra_framework::account;
    use std::signer;
    use supra_framework::event;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery::test_utils;

    fun init_token(lottery_admin: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        account::create_account_for_test(@lottery_owner);
        account::create_account_for_test(@lottery_contract);
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
        treasury_v1::register_store_for(lottery_admin, @lottery_owner);
        treasury_v1::register_store_for(lottery_admin, @lottery_contract);
    }

    #[test(lottery_admin = @lottery)]
    fun init_and_allocate(lottery_admin: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        assert!(treasury_multi::is_initialized(), 0);

        let (jackpot_status, operations_status) = treasury_multi::get_recipient_statuses();
        let (
            jackpot_addr,
            jackpot_registered,
            jackpot_frozen,
            jackpot_store_opt,
            jackpot_balance,
        ) = treasury_multi::recipient_status_fields_for_test(&jackpot_status);
        assert!(jackpot_addr == @lottery_owner, 16);
        assert!(jackpot_registered, 17);
        assert!(!jackpot_frozen, 18);
        assert!(option::is_some(&jackpot_store_opt), 19);
        let jackpot_store = *option::borrow(&jackpot_store_opt);
        assert!(
            jackpot_store == treasury_v1::primary_store_address(@lottery_owner),
            20,
        );
        assert!(jackpot_balance == 0, 21);

        let (
            operations_addr,
            operations_registered,
            operations_frozen,
            operations_store_opt,
            operations_balance,
        ) = treasury_multi::recipient_status_fields_for_test(&operations_status);
        assert!(operations_addr == @lottery_contract, 22);
        assert!(operations_registered, 23);
        assert!(!operations_frozen, 24);
        assert!(option::is_some(&operations_store_opt), 25);
        let operations_store = *option::borrow(&operations_store_opt);
        assert!(
            operations_store == treasury_v1::primary_store_address(@lottery_contract),
            26,
        );
        assert!(operations_balance == 0, 27);

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

    #[test(lottery_admin = @lottery)]
    fun recipients_event_captures_statuses(lottery_admin: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);

        let events = event::emitted_events<treasury_multi::RecipientsUpdatedEvent>();
        assert!(vector::length(&events) == 1, 100);
        let init_event = vector::borrow(&events, 0);
        let (
            previous_jackpot_opt,
            previous_operations_opt,
            next_jackpot_status,
            next_operations_status,
        ) = treasury_multi::recipient_event_fields_for_test(init_event);
        assert!(!option::is_some(&previous_jackpot_opt), 101);
        assert!(!option::is_some(&previous_operations_opt), 102);

        let (
            jackpot_addr,
            jackpot_registered,
            jackpot_frozen,
            jackpot_store_opt,
            jackpot_balance,
        ) = treasury_multi::recipient_status_fields_for_test(&next_jackpot_status);
        assert!(jackpot_addr == @lottery_owner, 103);
        assert!(jackpot_registered, 104);
        assert!(!jackpot_frozen, 105);
        assert!(option::is_some(&jackpot_store_opt), 106);
        assert!(jackpot_balance == 0, 107);

        let (
            operations_addr,
            operations_registered,
            operations_frozen,
            operations_store_opt,
            operations_balance,
        ) = treasury_multi::recipient_status_fields_for_test(&next_operations_status);
        assert!(operations_addr == @lottery_contract, 108);
        assert!(operations_registered, 109);
        assert!(!operations_frozen, 110);
        assert!(option::is_some(&operations_store_opt), 111);
        assert!(operations_balance == 0, 112);

        treasury_multi::set_recipients(lottery_admin, @jackpot_pool, @operations_pool);

        let updated_events = event::emitted_events<treasury_multi::RecipientsUpdatedEvent>();
        let events_count = vector::length(&updated_events);
        assert!(events_count == 2, 113);
        let latest_event = vector::borrow(&updated_events, events_count - 1);
        let (
            prev_jackpot_opt_after,
            prev_operations_opt_after,
            next_jackpot_after,
            next_operations_after,
        ) = treasury_multi::recipient_event_fields_for_test(latest_event);
        assert!(option::is_some(&prev_jackpot_opt_after), 114);
        assert!(option::is_some(&prev_operations_opt_after), 115);

        let prev_jackpot_after = option::borrow(&prev_jackpot_opt_after);
        let prev_operations_after = option::borrow(&prev_operations_opt_after);

        let (
            prev_jackpot_addr,
            prev_jackpot_registered,
            prev_jackpot_frozen,
            _,
            prev_jackpot_balance,
        ) = treasury_multi::recipient_status_fields_for_test(prev_jackpot_after);
        assert!(prev_jackpot_addr == @lottery_owner, 116);
        assert!(prev_jackpot_registered, 117);
        assert!(!prev_jackpot_frozen, 118);
        assert!(prev_jackpot_balance == 0, 119);

        let (
            prev_operations_addr,
            prev_operations_registered,
            prev_operations_frozen,
            _,
            prev_operations_balance,
        ) = treasury_multi::recipient_status_fields_for_test(prev_operations_after);
        assert!(prev_operations_addr == @lottery_contract, 120);
        assert!(prev_operations_registered, 121);
        assert!(!prev_operations_frozen, 122);
        assert!(prev_operations_balance == 0, 123);

        let (
            jackpot_addr_after,
            jackpot_registered_after,
            jackpot_frozen_after,
            jackpot_store_opt_after,
            jackpot_balance_after,
        ) = treasury_multi::recipient_status_fields_for_test(&next_jackpot_after);
        assert!(jackpot_addr_after == @jackpot_pool, 124);
        assert!(jackpot_registered_after, 125);
        assert!(!jackpot_frozen_after, 126);
        assert!(option::is_some(&jackpot_store_opt_after), 127);
        assert!(jackpot_balance_after == 0, 128);

        let (
            operations_addr_after,
            operations_registered_after,
            operations_frozen_after,
            operations_store_opt_after,
            operations_balance_after,
        ) = treasury_multi::recipient_status_fields_for_test(&next_operations_after);
        assert!(operations_addr_after == @operations_pool, 129);
        assert!(operations_registered_after, 130);
        assert!(!operations_frozen_after, 131);
        assert!(option::is_some(&operations_store_opt_after), 132);
        assert!(operations_balance_after == 0, 133);
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

        let (_jackpot_status_after_withdraw, operations_status_after_withdraw) =
            treasury_multi::get_recipient_statuses();
        let (
            _operations_addr_after,
            operations_registered_after,
            operations_frozen_after,
            _operations_store_opt_after,
            operations_balance_after,
        ) = treasury_multi::recipient_status_fields_for_test(&operations_status_after_withdraw);
        assert!(operations_registered_after, 7);
        assert!(!operations_frozen_after, 8);
        assert!(operations_balance_after == 200, 9);

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

    #[test(lottery_admin = @lottery, winner = @player2)]
    #[expected_failure(abort_code = 14)]
    fun operations_withdraw_requires_not_frozen(lottery_admin: &signer, winner: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::register_store(winner);
        treasury_v1::mint_to(lottery_admin, signer::address_of(winner), 500);
        treasury_v1::deposit_from_user(winner, 200);
        treasury_multi::record_allocation(lottery_admin, 1, 200);

        treasury_v1::set_store_frozen(lottery_admin, @operations_pool, true);
        treasury_multi::withdraw_operations(lottery_admin, 1);
    }

    #[test(lottery_admin = @lottery, bonus_recipient = @player3, payer = @player1)]
    #[expected_failure(abort_code = 15)]
    fun operations_bonus_requires_registered_store(
        lottery_admin: &signer,
        bonus_recipient: &signer,
        payer: &signer,
    ) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::register_store(payer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(payer), 1_000);
        treasury_v1::deposit_from_user(payer, 400);
        treasury_multi::record_allocation(lottery_admin, 1, 400);

        treasury_multi::pay_operations_bonus_internal(
            1,
            signer::address_of(bonus_recipient),
            50,
        );
    }

    #[test(lottery_admin = @lottery, bonus_recipient = @player3, payer = @player1)]
    #[expected_failure(abort_code = 16)]
    fun operations_bonus_respects_frozen_store(
        lottery_admin: &signer,
        bonus_recipient: &signer,
        payer: &signer,
    ) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::register_store(payer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(payer), 1_000);
        treasury_v1::deposit_from_user(payer, 400);
        treasury_multi::record_allocation(lottery_admin, 1, 400);

        treasury_v1::register_store(bonus_recipient);
        treasury_v1::set_store_frozen(
            lottery_admin,
            signer::address_of(bonus_recipient),
            true,
        );

        treasury_multi::pay_operations_bonus_internal(
            1,
            signer::address_of(bonus_recipient),
            50,
        );
    }

    #[test(lottery_admin = @lottery, winner = @player2)]
    #[expected_failure(abort_code = 17)]
    fun jackpot_requires_winner_store(lottery_admin: &signer, winner: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::mint_to(lottery_admin, signer::address_of(winner), 500);
        treasury_v1::deposit_from_user(winner, 200);
        treasury_multi::record_allocation(lottery_admin, 1, 200);
        treasury_multi::withdraw_operations(lottery_admin, 1);

        treasury_multi::distribute_jackpot(lottery_admin, signer::address_of(winner), 100);
    }

    #[test(lottery_admin = @lottery, winner = @player2)]
    #[expected_failure(abort_code = 18)]
    fun jackpot_respects_frozen_winner(lottery_admin: &signer, winner: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 6_000, 2_000, 2_000);

        treasury_v1::register_store(winner);
        treasury_v1::mint_to(lottery_admin, signer::address_of(winner), 500);
        treasury_v1::deposit_from_user(winner, 200);
        treasury_multi::record_allocation(lottery_admin, 1, 200);
        treasury_multi::withdraw_operations(lottery_admin, 1);

        treasury_v1::set_store_frozen(
            lottery_admin,
            signer::address_of(winner),
            true,
        );
        treasury_multi::distribute_jackpot(lottery_admin, signer::address_of(winner), 100);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 4)]
    fun invalid_basis_points(lottery_admin: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        treasury_multi::upsert_lottery_config(lottery_admin, 1, 5_000, 2_000, 1_000);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 5)]
    fun cannot_allocate_without_config(lottery_admin: &signer) {
        init_token(lottery_admin);
        treasury_multi::init(lottery_admin, @lottery_owner, @lottery_contract);
        treasury_multi::record_allocation(lottery_admin, 1, 500);
    }
}
