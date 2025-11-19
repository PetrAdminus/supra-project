#[test_only]
module lottery_utils::history_migration_tests {
    use lottery_data::rounds;
    use lottery_utils::history;

    use std::option;
    use std::vector;

    fun record(
        lottery_id: u64,
        request_id: u64,
        ticket_index: u64,
        prize_amount: u64,
    ): history::LegacyHistoryRecord {
        history::LegacyHistoryRecord {
            lottery_id,
            request_id,
            winner: @lottery,
            ticket_index,
            prize_amount,
            random_bytes: vector::singleton(1),
            payload: vector::singleton(2),
            timestamp_seconds: 123,
        }
    }

    #[test(lottery_admin = @lottery)]
    fun batch_import_restores_snapshot(lottery_admin: &signer) acquires history::HistoryCollection {
        rounds::init_control(lottery_admin);
        history::init(lottery_admin);
        history::ensure_caps_initialized(lottery_admin);

        let mut records = vector::empty<history::LegacyHistoryRecord>();
        vector::push_back(&mut records, record(11, 900, 7, 50));
        vector::push_back(&mut records, record(12, 901, 8, 60));

        history::import_existing_history_batch(lottery_admin, records);

        let snapshot_opt = history::get_history_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(vector::length(&snapshot.lottery_ids) == 2, 1);
        assert!(vector::length(&snapshot.histories) == 2, 2);
        assert!(snapshot.admin == @lottery, 3);

        let lottery_a = vector::borrow(&snapshot.histories, 0);
        assert!(lottery_a.lottery_id == 11, 4);
        assert!(vector::length(&lottery_a.records) == 1, 5);
        let record_a = vector::borrow(&lottery_a.records, 0);
        assert!(record_a.request_id == 900, 6);
        assert!(record_a.ticket_index == 7, 7);
        assert!(record_a.prize_amount == 50, 8);

        let lottery_b = vector::borrow(&snapshot.histories, 1);
        assert!(lottery_b.lottery_id == 12, 9);
        assert!(vector::length(&lottery_b.records) == 1, 10);
        let record_b = vector::borrow(&lottery_b.records, 0);
        assert!(record_b.request_id == 901, 11);
        assert!(record_b.ticket_index == 8, 12);
        assert!(record_b.prize_amount == 60, 13);
    }

    #[test(lottery_admin = @lottery)]
    fun import_dual_write_state_updates_expectations(lottery_admin: &signer) acquires history::DualWriteControl, history::HistoryCollection {
        rounds::init_control(lottery_admin);
        history::init(lottery_admin);
        history::init_dual_write(lottery_admin, false, false, false);

        let expectation = history::LegacyDualWriteExpectation {
            lottery_id: 42,
            expected_hash: vector::singleton(9),
        };
        let state = history::LegacyDualWriteState {
            enabled: true,
            abort_on_mismatch: true,
            abort_on_missing: false,
            expectations: vector::singleton(expectation),
        };

        history::import_existing_dual_write_state(lottery_admin, state);

        let flags = history::dual_write_flags();
        assert!(flags.enabled, 0);
        assert!(flags.abort_on_mismatch, 1);
        assert!(!flags.abort_on_missing, 2);

        let pending = history::pending_expected_hashes();
        assert!(vector::length(&pending) == 1, 3);
        assert!(*vector::borrow(&pending, 0) == 42, 4);

        let status = history::dual_write_status(42);
        assert!(status.enabled, 5);
        assert!(option::is_some(&status.expected_hash), 6);
        let hash = option::destroy_some(status.expected_hash);
        assert!(vector::length(&hash) == 1, 7);
        assert!(*vector::borrow(&hash, 0) == 9, 8);
    }
}
