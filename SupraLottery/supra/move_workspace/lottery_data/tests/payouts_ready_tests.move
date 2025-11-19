#[test_only]
module lottery_data::payouts_ready_tests {
    use std::option;

    use lottery_data::payouts;
    use lottery_vrf_gateway::table;

    #[test(lottery_admin = @lottery)]
    fun payouts_ready_snapshot_flow(lottery_admin: &signer) {
        assert!(!payouts::ready(), 0);
        assert!(option::is_none(&payouts::payout_record_snapshot(5)), 1);

        payouts::init_ledger(lottery_admin);
        assert!(payouts::ready(), 2);

        let legacy_record = payouts::LegacyPayoutRecord {
            payout_id: 5,
            lottery_id: 7,
            round_number: 3,
            winner: @lottery,
            ticket_index: 9,
            amount: 1000,
            status: payouts::status_pending(),
            randomness_hash: b"rand",
            payload_hash: b"payload",
            refund_recipient: @lottery,
            refund_amount: 0,
        };
        payouts::import_existing_payout(lottery_admin, legacy_record);
        assert!(payouts::ready(), 3);

        let record_opt = payouts::payout_record_snapshot(5);
        assert!(option::is_some(&record_opt), 4);
        let snapshot = option::borrow(&record_opt);
        assert!(snapshot.lottery_id == 7, 5);
        assert!(snapshot.ticket_index == 9, 6);

        let ledger = payouts::borrow_mut(@lottery);
        let state = table::borrow_mut(&mut ledger.states, 7);
        let missing_record = table::remove(&mut state.payouts, 5);
        assert!(!payouts::ready(), 7);
        table::add(&mut state.payouts, 5, missing_record);
        assert!(payouts::ready(), 8);

        table::remove(&mut ledger.payout_index, 5);
        assert!(!payouts::ready(), 9);
        table::add(&mut ledger.payout_index, 5, 7);
        assert!(payouts::ready(), 10);
    }
}
