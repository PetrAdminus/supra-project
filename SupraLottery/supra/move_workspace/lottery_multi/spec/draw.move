spec module lottery_multi::draw {
    use std::table;

    use supra_addr::supra_vrf;

    use lottery_multi::draw::{DrawLedger, DrawState};
    use lottery_multi::lottery_registry;
    use lottery_multi::types;

    const MAX_VRF_ATTEMPTS: u8 = 5;

    spec struct DrawState {
        invariant len(snapshot_hash) == 0 || len(snapshot_hash) == 32;
        invariant vrf_state.status == types::vrf_status_requested() ==> len(snapshot_hash) == 32;
        invariant vrf_state.status == types::vrf_status_fulfilled() ==> len(snapshot_hash) == 32;
        invariant vrf_state.retry_after_ts == 0
            ==> vrf_state.status == types::vrf_status_idle()
                || vrf_state.status == types::vrf_status_fulfilled()
                || vrf_state.retry_strategy == types::retry_strategy_manual();
        invariant vrf_state.status == types::vrf_status_fulfilled() ==> !vrf_state.consumed || len(verified_numbers) > 0;
        invariant len(winners_batch_hash) == 0 || len(winners_batch_hash) == 32;
        invariant len(checksum_after_batch) == 0 || len(checksum_after_batch) == 32;
    }

    spec fun draw_state(addr: address, lottery_id: u64): DrawState {
        table::borrow(&global<DrawLedger>(addr).states, lottery_id)
    }

    spec fun has_state(addr: address, lottery_id: u64): bool {
        table::contains(&global<DrawLedger>(addr).states, lottery_id)
    }

    spec fun lottery_for_nonce(addr: address, nonce: u64): u64 {
        table::borrow(&global<DrawLedger>(addr).nonce_to_lottery, nonce)
    }

    spec request_draw_admin {
        let new_state = draw_state(@lottery_multi, lottery_id);
        let had_state = old(has_state(@lottery_multi, lottery_id));
        let old_state = if (had_state) {
            old(draw_state(@lottery_multi, lottery_id))
        } else {
            DrawState {
                vrf_state: types::new_vrf_state(),
                rng_count: 0,
                client_seed: 0,
                last_request_ts: 0,
                snapshot_hash: b"",
                total_tickets: 0,
                winners_batch_hash: b"",
                checksum_after_batch: b"",
                verified_numbers: vector[],
                payload: b"",
                next_client_seed: 0,
            }
        };
        ensures has_state(@lottery_multi, lottery_id);
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.status == types::vrf_status_requested();
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.status == types::vrf_status_failed();
        let config = lottery_registry::borrow_config_from_registry(&global<lottery_registry::Registry>(@lottery_multi), lottery_id);
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.retry_strategy == config.vrf_retry_policy.strategy;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS && config.vrf_retry_policy.strategy == types::retry_strategy_manual()
            ==> new_state.vrf_state.retry_after_ts == 0;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS && config.vrf_retry_policy.strategy != types::retry_strategy_manual()
            ==> new_state.vrf_state.retry_after_ts >= now_ts;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS && config.vrf_retry_policy.strategy != types::retry_strategy_manual()
            ==> new_state.vrf_state.retry_after_ts <= now_ts + config.vrf_retry_policy.max_delay_secs;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS ==> new_state.vrf_state.retry_after_ts == 0;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS ==> new_state.vrf_state.consumed == false;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS ==> new_state.vrf_state.consumed == true;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.schema_version == types::vrf_default_schema_version();
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.retry_strategy == config.vrf_retry_policy.strategy;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.chain_id == chain_id;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.closing_block_height == closing_block_height;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS ==> new_state.last_request_ts == now_ts;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS ==> new_state.last_request_ts == old_state.last_request_ts;
        ensures len(new_state.verified_numbers) == 0;
        ensures new_state.winners_batch_hash == b"";
        ensures new_state.checksum_after_batch == b"";
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS ==> new_state.client_seed < new_state.next_client_seed;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.attempt == old_state.vrf_state.attempt + 1;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS
            ==> new_state.vrf_state.attempt == old_state.vrf_state.attempt;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.next_client_seed == old_state.next_client_seed + 1;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS
            ==> new_state.next_client_seed == old_state.next_client_seed;
        ensures old_state.vrf_state.attempt < MAX_VRF_ATTEMPTS
            ==> new_state.client_seed == old_state.next_client_seed;
        ensures old_state.vrf_state.attempt >= MAX_VRF_ATTEMPTS ==> new_state.client_seed == old_state.client_seed;
    }

    spec vrf_callback {
        let lottery_id = old(lottery_for_nonce(@lottery_multi, nonce));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures new_state.vrf_state.status == types::vrf_status_fulfilled();
        ensures new_state.vrf_state.consumed == false;
        ensures new_state.vrf_state.retry_after_ts == 0;
        ensures new_state.verified_numbers == supra_vrf::verify_callback(
            nonce,
            message,
            signature,
            caller_address,
            rng_count,
            client_seed,
        );
    }

    spec prepare_for_winner_computation {
        let old_state = old(draw_state(@lottery_multi, lottery_id));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures old_state.vrf_state.status == types::vrf_status_fulfilled();
        ensures !old_state.vrf_state.consumed;
        ensures new_state.vrf_state.consumed;
        ensures new_state.vrf_state.status == old_state.vrf_state.status;
        ensures result_5 == old_state.vrf_state.attempt;
    }

    spec record_winner_hashes {
        let old_state = old(draw_state(@lottery_multi, lottery_id));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures new_state.snapshot_hash == old_state.snapshot_hash;
        ensures new_state.vrf_state.payload_hash == old_state.vrf_state.payload_hash;
        ensures new_state.winners_batch_hash == *winners_batch_hash;
        ensures new_state.checksum_after_batch == *checksum_after_batch;
    }

    spec schedule_manual_retry_admin {
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures new_state.vrf_state.retry_after_ts == retry_after_ts;
    }

    spec finalization_snapshot {
        let state = draw_state(@lottery_multi, lottery_id);
        ensures result.snapshot_hash == state.snapshot_hash;
        ensures result.payload_hash == state.vrf_state.payload_hash;
        ensures result.winners_batch_hash == state.winners_batch_hash;
        ensures result.checksum_after_batch == state.checksum_after_batch;
        ensures result.schema_version == state.vrf_state.schema_version;
        ensures result.attempt == state.vrf_state.attempt;
        ensures result.closing_block_height == state.vrf_state.closing_block_height;
        ensures result.chain_id == state.vrf_state.chain_id;
        ensures result.request_ts == state.last_request_ts;
        ensures result.vrf_status == state.vrf_state.status;
    }
}
