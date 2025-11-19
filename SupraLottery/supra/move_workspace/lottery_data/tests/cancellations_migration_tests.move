#[test_only]
module lottery_data::cancellations_migration_tests {
    use lottery_data::cancellations;
    use std::option;
    use std::vector;

    #[test(lottery_admin = @lottery)]
    fun import_existing_cancellations_restores_records(lottery_admin: &signer) {
        cancellations::init_ledger(lottery_admin);

        let mut records = vector::empty<cancellations::LegacyCancellationRecord>();
        vector::push_back(
            &mut records,
            cancellations::LegacyCancellationRecord {
                lottery_id: 7,
                reason_code: 4,
                canceled_ts: 111,
                previous_status: 2,
                tickets_sold: 500,
                proceeds_accum: 7_500,
                jackpot_locked: 2_000,
                pending_tickets_cleared: 25,
            },
        );
        vector::push_back(
            &mut records,
            cancellations::LegacyCancellationRecord {
                lottery_id: 8,
                reason_code: 5,
                canceled_ts: 222,
                previous_status: 3,
                tickets_sold: 250,
                proceeds_accum: 6_000,
                jackpot_locked: 1_500,
                pending_tickets_cleared: 10,
            },
        );

        cancellations::import_existing_cancellations(lottery_admin, records);

        let first = cancellations::record_snapshot(7);
        assert!(option::is_some(&first), 0);
        let first_ref = option::borrow(&first);
        assert!(first_ref.reason_code == 4, 1);
        assert!(first_ref.tickets_sold == 500, 2);
        assert!(first_ref.pending_tickets_cleared == 25, 3);

        let second = cancellations::record_snapshot(8);
        assert!(option::is_some(&second), 4);
        let second_ref = option::borrow(&second);
        assert!(second_ref.canceled_ts == 222, 5);
        assert!(second_ref.jackpot_locked == 1_500, 6);

        let snapshot_opt = cancellations::ledger_snapshot();
        assert!(option::is_some(&snapshot_opt), 7);
        let snapshot_ref = option::borrow(&snapshot_opt);
        assert!(vector::length(&snapshot_ref.lottery_ids) == 2, 8);
        assert!(vector::length(&snapshot_ref.records) == 2, 9);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 3, location = lottery_data::cancellations)]
    fun import_existing_cancellation_rejects_duplicates(lottery_admin: &signer) {
        cancellations::init_ledger(lottery_admin);
        let record = cancellations::LegacyCancellationRecord {
            lottery_id: 12,
            reason_code: 1,
            canceled_ts: 999,
            previous_status: 2,
            tickets_sold: 100,
            proceeds_accum: 2_000,
            jackpot_locked: 400,
            pending_tickets_cleared: 4,
        };
        cancellations::import_existing_cancellation(lottery_admin, record);

        let duplicate = cancellations::LegacyCancellationRecord {
            lottery_id: 12,
            reason_code: 3,
            canceled_ts: 1_000,
            previous_status: 3,
            tickets_sold: 120,
            proceeds_accum: 2_500,
            jackpot_locked: 500,
            pending_tickets_cleared: 5,
        };
        cancellations::import_existing_cancellation(lottery_admin, duplicate);
    }
}
