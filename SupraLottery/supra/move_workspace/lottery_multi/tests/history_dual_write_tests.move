module lottery_multi::history_dual_write_tests {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::vector;

    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::legacy_bridge;
    use lottery_support::history_bridge;

    // #[test(account = @lottery_multi)]
    fun dual_write_pass(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(1);
        let expected = hash::sha3_256(bcs::to_bytes(&summary));
        legacy_bridge::set_expected_hash(account, 1, copy expected);
        history::record_summary(1, summary);
        let stored = history::get_summary(1);
        assert!(history::lottery_summary_id(&stored) == 1, 0);
        let flags = legacy_bridge::dual_write_flags();
        assert!(legacy_bridge::dual_write_status_enabled(&flags), 0);
        assert!(!legacy_bridge::dual_write_status_has_expected_hash(&flags), 0);
        assert!(!legacy_bridge::has_expected_hash(1), 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_HISTORY_EXPECTED_MISSING)]
    fun dual_write_missing_abort(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(2);
        history::record_summary(2, summary);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_HISTORY_MISMATCH)]
    fun dual_write_mismatch(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let mismatch = vector::empty<u8>();
        vector::push_back(&mut mismatch, 0);
        legacy_bridge::set_expected_hash(account, 3, mismatch);
        let summary = sample_summary(3);
        history::record_summary(3, summary);
    }

    // #[test(account = @lottery_multi)]
    fun dual_write_missing_allowed(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, false);
        let summary = sample_summary(4);
        history::record_summary(4, summary);
        let enabled = legacy_bridge::is_enabled();
        assert!(enabled, 0);
        let status = legacy_bridge::dual_write_status(4);
        assert!(!legacy_bridge::dual_write_status_has_expected_hash(&status), 0);
    }

    // #[test(account = @lottery_multi)]
    fun dual_write_mirror_summary(account: &signer) {
        history::init_history(account);
        history_bridge::init_bridge(account);
        legacy_bridge::enable_legacy_mirror(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(5);
        let summary_bytes = bcs::to_bytes(&summary);
        let expected_hash = hash::sha3_256(copy summary_bytes);
        legacy_bridge::set_expected_hash(account, 5, copy expected_hash);
        history::record_summary(5, summary);
        let mirrored_opt = history_bridge::get_summary(5);
        assert!(option::is_some(&mirrored_opt), 0);
        let mirrored = option::destroy_some(mirrored_opt);
        assert!(history_bridge::legacy_summary_archive_hash(&mirrored) == expected_hash, 1);
        let mirrored_bytes = history_bridge::legacy_summary_summary_bcs(&mirrored);
        let decoded = history::decode_summary_for_test(mirrored_bytes);
        assert!(history::lottery_summary_id(&decoded) == 5, 2);
        assert!(
            history_bridge::legacy_summary_finalized_at(&mirrored)
                == history::lottery_summary_finalized_at(&summary),
            3,
        );
    }

    // #[test(account = @lottery_multi)]
    fun dual_write_mismatch_requires_manual_clear(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, false, true);
        let mismatch = vector::empty<u8>();
        vector::push_back(&mut mismatch, 7);
        legacy_bridge::set_expected_hash(account, 6, copy mismatch);
        let summary = sample_summary(6);
        history::record_summary(6, summary);
        let pending = legacy_bridge::has_expected_hash(6);
        assert!(pending, 0);
        let stored = history::get_summary(6);
        assert!(history::lottery_summary_id(&stored) == 6, 1);
        legacy_bridge::clear_expected_hash(account, 6);
        let pending_after = legacy_bridge::has_expected_hash(6);
        assert!(!pending_after, 2);
    }

    // #[test(account = @lottery_multi)]
    fun dual_write_pending_list(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, false, true);
        let summary_11 = sample_summary(11);
        let hash_11 = hash::sha3_256(bcs::to_bytes(&summary_11));
        legacy_bridge::set_expected_hash(account, 11, copy hash_11);
        let summary_12 = sample_summary(12);
        let hash_12 = hash::sha3_256(bcs::to_bytes(&summary_12));
        legacy_bridge::set_expected_hash(account, 12, copy hash_12);
        let pending = legacy_bridge::pending_expected_hashes();
        assert!(vector::length(&pending) == 2, 0);
        assert!(*vector::borrow(&pending, 0) == 11, 1);
        assert!(*vector::borrow(&pending, 1) == 12, 2);
        history::record_summary(11, summary_11);
        let pending_after = legacy_bridge::pending_expected_hashes();
        assert!(vector::length(&pending_after) == 1, 3);
        assert!(*vector::borrow(&pending_after, 0) == 12, 4);
    }

    fun sample_summary(id: u64): history::LotterySummary {
        history::new_summary(
            id,
            0,
            vector::empty<u8>(),
            vector::empty<u8>(),
            id,
            10,
            100,
            50,
            10,
            5,
            0,
            0,
            0,
            vector::empty<u8>(),
            vector::empty<u8>(),
            vector::empty<u8>(),
            vector::empty<u8>(),
            0,
            0,
            0,
            0,
        )
    }
}








