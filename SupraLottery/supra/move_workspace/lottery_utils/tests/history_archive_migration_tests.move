#[test_only]
module lottery_utils::history_archive_migration_tests {
    use lottery_data::rounds;
    use lottery_utils::history;

    use std::bcs;
    use std::hash;
    use std::option;
    use std::vector;

    fun bytes(value: u8): vector<u8> {
        vector::singleton(value)
    }

    fun summary(id: u64, tag: u64): history::LotterySummary {
        history::LotterySummary {
            id,
            event_slug: bytes(1),
            series_code: bytes(2),
            run_id: 77,
            tickets_sold: 5,
            proceeds_accum: 1_000,
            total_allocated: 600,
            total_prize_paid: 300,
            total_operations_paid: 100,
            vrf_status: 2,
            primary_type: 3,
            tags_mask: tag,
            snapshot_hash: bytes(4),
            slots_checksum: bytes(5),
            winners_batch_hash: bytes(6),
            checksum_after_batch: bytes(7),
            payout_round: 8,
            created_at: 9,
            closed_at: 10,
            finalized_at: 11,
        }
    }

    fun import_payload(id: u64, tag: u64): history::LegacyArchiveImport {
        let summary = summary(id, tag);
        let summary_bytes = bcs::to_bytes(&summary);
        let expected_hash = hash::sha3_256(copy summary_bytes);
        history::LegacyArchiveImport {
            lottery_id: id,
            summary_bcs: summary_bytes,
            expected_hash,
        }
    }

    #[test(lottery_admin = @lottery)]
    fun batch_import_and_rollback(
        lottery_admin: &signer,
    ) acquires
        history::ArchiveLedger,
        history::DualWriteControl,
        history::HistoryCollection,
        history::HistoryWarden,
        history::LegacyArchive,
        rounds::RoundControl
    {
        rounds::init_control(lottery_admin);
        history::init(lottery_admin);
        history::init_archive(lottery_admin);
        history::init_legacy_archive(lottery_admin);
        history::init_dual_write(lottery_admin, true, true, false);

        let import_a = import_payload(1, 99);
        let import_b = import_payload(2, 100);
        history::set_expected_hash(lottery_admin, 1, vector::copy(&import_a.expected_hash));
        history::set_expected_hash(lottery_admin, 2, vector::copy(&import_b.expected_hash));

        let mut imports = vector::empty<history::LegacyArchiveImport>();
        vector::push_back(&mut imports, import_a);
        vector::push_back(&mut imports, import_b);

        history::import_existing_legacy_summaries(lottery_admin, imports);

        let summary_opt = history::archive_summary(1);
        assert!(option::is_some(&summary_opt), 0);
        let summary = option::destroy_some(summary_opt);
        assert!(summary.id == 1, 1);
        assert!(summary.tags_mask == 99, 2);
        assert!(history::is_legacy_summary(1), 3);

        let legacy_opt = history::legacy_summary(1);
        assert!(option::is_some(&legacy_opt), 4);

        let pending = history::pending_expected_hashes();
        assert!(vector::length(&pending) == 0, 5);

        history::rollback_legacy_summary(lottery_admin, 2);
        let rollback_opt = history::archive_summary(2);
        assert!(option::is_none(&rollback_opt), 6);

        let finalized = history::list_finalized(0, 10);
        assert!(vector::length(&finalized) == 1, 7);
        assert!(*vector::borrow(&finalized, 0) == 1, 8);
    }
}
