#[test_only]
module lottery_core::core_rounds_queue_tests {
    use lottery_core::core_rounds as rounds;
    use lottery_core::test_utils;
    use lottery_core::core_treasury_v1 as treasury_v1;
    use std::option;
    use std::signer;
    use std::vector;

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @lottery_vrf_gateway,
        player = @player1,
    )]
    fun queues_roundtrip(
        lottery_admin: &signer,
        factory_admin: &signer,
        vrf_admin: &signer,
        player: &signer,
    ) {
        let (lottery_id, request_id, total_paid) = test_utils::setup_round_with_pending_draw(
            lottery_admin,
            factory_admin,
            vrf_admin,
            player,
        );
        let randomness = test_utils::sample_randomness();
        rounds::fulfill_draw(vrf_admin, request_id, randomness);

        assert!(rounds::history_queue_length() == 1, 0);
        assert!(rounds::purchase_queue_length() == 1, 1);

        let pending_after = rounds::pending_request_id(lottery_id);
        assert!(option::is_none(&pending_after), 2);

        let expected_prize = total_paid * 6_000 / 10_000;
        let player_addr = signer::address_of(player);
        let player_balance = treasury_v1::balance_of(player_addr);
        assert!(player_balance == expected_prize, 3);

        let history_cap = rounds::borrow_history_writer_cap(lottery_admin);
        let history_records = rounds::drain_history_queue(&history_cap, 0);
        rounds::return_history_writer_cap(lottery_admin, history_cap);
        assert!(vector::length(&history_records) == 1, 4);
        let history_ref = vector::borrow(&history_records, 0);
        let (hist_lottery, hist_request, hist_winner, hist_index, hist_amount) =
            rounds::history_record_fields(history_ref);
        assert!(hist_lottery == lottery_id, 5);
        assert!(hist_request == request_id, 6);
        assert!(hist_winner == player_addr, 7);
        assert!(hist_index < 2, 8);
        assert!(hist_amount == expected_prize, 9);
        assert!(rounds::history_queue_length() == 0, 10);

        let purchase_records = rounds::drain_purchase_queue_admin(lottery_admin, 0);
        assert!(vector::length(&purchase_records) == 1, 11);
        let purchase_ref = vector::borrow(&purchase_records, 0);
        let (purchase_lottery, purchase_buyer, purchase_count, purchase_paid) =
            rounds::purchase_record_fields(purchase_ref);
        assert!(purchase_lottery == lottery_id, 12);
        assert!(purchase_buyer == player_addr, 13);
        assert!(purchase_count == 2, 14);
        assert!(purchase_paid == total_paid, 15);
        assert!(rounds::purchase_queue_length() == 0, 16);

        let treasury_balance = treasury_v1::balance_of(@lottery);
        assert!(
            treasury_balance == test_utils::treasury_test_funds() - expected_prize,
            17,
        );
    }
}

