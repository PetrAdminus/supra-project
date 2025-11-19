#[test_only]
module lottery_data::cancellations_ready_tests {
    use lottery_data::cancellations;
    use std::option;

    #[test(lottery_admin = @lottery)]
    fun cancellations_ready_snapshot_flow(lottery_admin: &signer) {
        assert!(!cancellations::ready(), 0);
        assert!(option::is_none(&cancellations::record_snapshot(10)), 1);

        cancellations::init_ledger(lottery_admin);
        assert!(cancellations::ready(), 2);
        assert!(option::is_none(&cancellations::record_snapshot(10)), 3);

        let legacy_record = cancellations::LegacyCancellationRecord {
            lottery_id: 10,
            reason_code: 2,
            canceled_ts: 123,
            previous_status: 1,
            tickets_sold: 50,
            proceeds_accum: 1000,
            jackpot_locked: 500,
            pending_tickets_cleared: 5,
        };
        cancellations::import_existing_cancellation(lottery_admin, legacy_record);

        let record_opt = cancellations::record_snapshot(10);
        assert!(option::is_some(&record_opt), 4);
        let record_ref = option::borrow(&record_opt);
        assert!(record_ref.reason_code == 2, 5);
        assert!(record_ref.canceled_ts == 123, 6);
        assert!(record_ref.jackpot_locked == 500, 7);
    }
}
