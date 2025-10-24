#[test_only]
module lottery_support::history_sync_tests {
    use lottery_core::rounds;
    use lottery_core::test_utils;
    use lottery_support::history;
    use std::signer;
    use std::vector;

    #[test(
        lottery_admin = @lottery,
        factory_admin = @lottery_factory,
        vrf_admin = @vrf_hub,
        player = @player1,
    )]
    fun sync_draws_records_history(
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

        history::init(lottery_admin);
        history::ensure_caps_initialized(lottery_admin);
        history::sync_draws_from_rounds(lottery_admin, 0);
        assert!(rounds::history_queue_length() == 0, 1);

        let history_opt = history::get_history(lottery_id);
        let records = test_utils::unwrap(&mut history_opt);
        assert!(vector::length(&records) == 1, 2);
        let record_ref = vector::borrow(&records, 0);
        let (
            recorded_request,
            winner,
            ticket_index,
            prize_amount,
            _random_bytes,
            _payload,
            _timestamp,
        ) = history::draw_record_fields_for_test(record_ref);
        let expected_prize = total_paid * 6_000 / 10_000;
        assert!(recorded_request == request_id, 3);
        assert!(winner == signer::address_of(player), 4);
        assert!(ticket_index < 2, 5);
        assert!(prize_amount == expected_prize, 6);
        assert!(history::caps_ready(), 7);
    }
}
