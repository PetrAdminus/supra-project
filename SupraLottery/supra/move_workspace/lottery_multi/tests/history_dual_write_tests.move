module lottery_multi::history_dual_write_tests {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::vector;

    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::legacy_bridge;

    #[test(account = @lottery_multi)]
    fun dual_write_pass(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(1);
        let expected = hash::sha3_256(bcs::to_bytes(&summary));
        legacy_bridge::set_expected_hash(account, 1, copy expected);
        history::record_summary(1, summary);
        let stored = history::get_summary(1);
        assert!(stored.id == 1, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_HISTORY_EXPECTED_MISSING)]
    fun dual_write_missing_abort(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let summary = sample_summary(2);
        history::record_summary(2, summary);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_HISTORY_MISMATCH)]
    fun dual_write_mismatch(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, true);
        let mut mismatch = vector::empty<u8>();
        vector::push_back(&mut mismatch, 0);
        legacy_bridge::set_expected_hash(account, 3, mismatch);
        let summary = sample_summary(3);
        history::record_summary(3, summary);
    }

    #[test(account = @lottery_multi)]
    fun dual_write_missing_allowed(account: &signer) {
        history::init_history(account);
        legacy_bridge::init_dual_write(account, true, false);
        let summary = sample_summary(4);
        history::record_summary(4, summary);
        let enabled = legacy_bridge::is_enabled();
        assert!(enabled, 0);
    }

    fun sample_summary(id: u64): history::LotterySummary {
        history::LotterySummary {
            id,
            status: 0,
            event_slug: vector::empty<u8>(),
            series_code: vector::empty<u8>(),
            run_id: id,
            tickets_sold: 10,
            proceeds_accum: 100,
            vrf_status: 0,
            primary_type: 0,
            tags_mask: 0,
            snapshot_hash: vector::empty<u8>(),
            slots_checksum: vector::empty<u8>(),
            winners_batch_hash: vector::empty<u8>(),
            checksum_after_batch: vector::empty<u8>(),
            payout_round: 0,
            created_at: 0,
            closed_at: 0,
            finalized_at: 0,
        }
    }
}

