module lottery_multi::history_migration_tests {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::vector;

    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::legacy_bridge;
    use lottery_support::history_bridge;

    #[test(account = @lottery_multi)]
    fun import_and_rollback(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, false, false);
        let summary = sample_summary(101, 2, 0x10);
        let summary_bytes = bcs::to_bytes(&summary);
        let hash = hash::sha3_256(copy summary_bytes);
        history::import_legacy_summary_admin(account, 101, summary_bytes, copy hash);
        let stored = history::get_summary(101);
        assert!(stored.primary_type == 2, 0);
        assert!(stored.tags_mask == 0x10, 1);
        let legacy_flag = history::is_legacy_summary(101);
        assert!(legacy_flag, 2);
        history::rollback_legacy_summary_admin(account, 101);
        let list_after = history::list_finalized(0, 10);
        assert!(vector::length(&list_after) == 0, 3);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_HISTORY_IMPORT_HASH)]
    fun import_rejects_mismatched_hash(account: &signer) {
        history::init_history(account);
        let summary = sample_summary(11, 1, 0);
        let summary_bytes = bcs::to_bytes(&summary);
        let mut fake_hash = vector::empty<u8>();
        vector::push_back(&mut fake_hash, 0);
        history::import_legacy_summary_admin(account, 11, summary_bytes, fake_hash);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_HISTORY_NOT_LEGACY)]
    fun rollback_rejects_non_legacy(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, false, false);
        let summary = sample_summary(77, 0, 0);
        let bytes = bcs::to_bytes(&summary);
        let hash = hash::sha3_256(copy bytes);
        legacy_bridge::set_expected_hash(account, 77, copy hash);
        history::record_summary(77, summary);
        history::rollback_legacy_summary_admin(account, 77);
    }

    #[test(account = @lottery_multi)]
    fun update_legacy_classification(account: &signer) {
        history::init_history(account);
        let summary = sample_summary(55, 0, 0);
        let summary_bytes = bcs::to_bytes(&summary);
        let hash = hash::sha3_256(copy summary_bytes);
        history::import_legacy_summary_admin(account, 55, summary_bytes, copy hash);
        history::update_legacy_classification_admin(account, 55, 3, 0xFF);
        let stored = history::get_summary(55);
        assert!(stored.primary_type == 3, 0);
        assert!(stored.tags_mask == 0xFF, 1);
    }

    #[test(account = @lottery_multi)]
    fun import_completes_dual_write(account: &signer) {
        history::init_history(account);
        history_bridge::init_bridge(account);
        legacy_bridge::enable_legacy_mirror(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(205, 4, 0x40);
        let summary_bytes = bcs::to_bytes(&summary);
        let hash = hash::sha3_256(copy summary_bytes);
        legacy_bridge::set_expected_hash(account, 205, copy hash);
        assert!(legacy_bridge::has_expected_hash(205), 0);
        history::import_legacy_summary_admin(account, 205, summary_bytes, copy hash);
        assert!(!legacy_bridge::has_expected_hash(205), 1);
        let mirrored_opt = history_bridge::get_summary(205);
        assert!(option::is_some(&mirrored_opt), 2);
        let mirrored = option::destroy_some(mirrored_opt);
        assert!(history_bridge::legacy_summary_archive_hash(&mirrored) == hash, 3);
        assert!(history_bridge::legacy_summary_finalized_at(&mirrored) == summary.finalized_at, 4);
    }

    fun sample_summary(id: u64, primary_type: u8, tags_mask: u64): history::LotterySummary {
        history::LotterySummary {
            id,
            status: 0,
            event_slug: vector::empty<u8>(),
            series_code: vector::empty<u8>(),
            run_id: id,
            tickets_sold: 0,
            proceeds_accum: 0,
            total_allocated: 0,
            total_prize_paid: 0,
            total_operations_paid: 0,
            vrf_status: 0,
            primary_type,
            tags_mask,
            snapshot_hash: vector::empty<u8>(),
            slots_checksum: vector::empty<u8>(),
            winners_batch_hash: vector::empty<u8>(),
            checksum_after_batch: vector::empty<u8>(),
            payout_round: 0,
            created_at: 0,
            closed_at: 0,
            finalized_at: 1,
        }
    }
}

