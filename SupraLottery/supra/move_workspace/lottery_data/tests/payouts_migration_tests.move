#[test_only]
module lottery_data::payouts_migration_tests {
    use lottery_data::payouts;
    use std::option;
    use std::vector;

    #[test(lottery_admin = @lottery)]
    fun import_existing_payouts_restore_snapshot(lottery_admin: &signer) {
        payouts::init_ledger(lottery_admin);

        let mut records = vector::empty<payouts::LegacyPayoutRecord>();
        vector::push_back(
            &mut records,
            payouts::LegacyPayoutRecord {
                payout_id: 2,
                lottery_id: 7,
                round_number: 3,
                winner: @winner_one,
                ticket_index: 4,
                amount: 5_000,
                status: payouts::status_pending(),
                randomness_hash: b"r1",
                payload_hash: b"p1",
                refund_recipient: @treasury,
                refund_amount: 0,
            },
        );
        vector::push_back(
            &mut records,
            payouts::LegacyPayoutRecord {
                payout_id: 5,
                lottery_id: 7,
                round_number: 4,
                winner: @winner_two,
                ticket_index: 8,
                amount: 10_000,
                status: payouts::status_paid(),
                randomness_hash: b"r2",
                payload_hash: b"p2",
                refund_recipient: @treasury,
                refund_amount: 0,
            },
        );
        vector::push_back(
            &mut records,
            payouts::LegacyPayoutRecord {
                payout_id: 9,
                lottery_id: 11,
                round_number: 2,
                winner: @winner_three,
                ticket_index: 1,
                amount: 7_500,
                status: payouts::status_refunded(),
                randomness_hash: b"r3",
                payload_hash: b"p3",
                refund_recipient: @winner_three,
                refund_amount: 7_500,
            },
        );

        payouts::import_existing_payouts(lottery_admin, records);

        let ledger_snapshot = payouts::ledger_snapshot();
        assert!(option::is_some(&ledger_snapshot), 0);
        let ledger_ref = option::borrow(&ledger_snapshot);
        assert!(ledger_ref.next_payout_id == 10, 1);
        assert!(vector::length(&ledger_ref.lotteries) == 2, 2);

        let lottery_seven = payouts::lottery_snapshot(7);
        assert!(option::is_some(&lottery_seven), 3);
        let lottery_ref = option::borrow(&lottery_seven);
        assert!(lottery_ref.round_number == 4, 4);
        assert!(lottery_ref.pending_count == 1, 5);
        assert!(lottery_ref.paid_count == 1, 6);
        assert!(lottery_ref.refunded_count == 0, 7);
        assert!(vector::length(&lottery_ref.payouts) == 2, 8);

        let lottery_eleven = payouts::lottery_snapshot(11);
        assert!(option::is_some(&lottery_eleven), 9);
        let lottery_eleven_ref = option::borrow(&lottery_eleven);
        assert!(lottery_eleven_ref.pending_count == 0, 10);
        assert!(lottery_eleven_ref.paid_count == 0, 11);
        assert!(lottery_eleven_ref.refunded_count == 1, 12);

        let refunded_snapshot = payouts::payout_record_snapshot(9);
        assert!(option::is_some(&refunded_snapshot), 13);
        let refunded_ref = option::borrow(&refunded_snapshot);
        assert!(refunded_ref.status == payouts::status_refunded(), 14);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 7, location = lottery_data::payouts)]
    fun import_existing_payout_rejects_duplicates(lottery_admin: &signer) {
        payouts::init_ledger(lottery_admin);

        let record = payouts::LegacyPayoutRecord {
            payout_id: 1,
            lottery_id: 3,
            round_number: 1,
            winner: @winner_one,
            ticket_index: 0,
            amount: 2_000,
            status: payouts::status_pending(),
            randomness_hash: b"r4",
            payload_hash: b"p4",
            refund_recipient: @winner_one,
            refund_amount: 0,
        };
        payouts::import_existing_payout(lottery_admin, record);
        payouts::import_existing_payout(lottery_admin, record);
    }
}
