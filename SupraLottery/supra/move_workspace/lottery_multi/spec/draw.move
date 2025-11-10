spec module lottery_multi::draw {
    use std::bcs;
    use std::table;

    use supra_addr::supra_vrf;

    use lottery_multi::draw::{DrawLedger, DrawState, RETRY_DELAY_SECS};
    use lottery_multi::types;

    spec struct DrawState {
        invariant len(snapshot_hash) == 0 || len(snapshot_hash) == 32;
        invariant vrf_state.status == types::VRF_STATUS_REQUESTED ==> len(snapshot_hash) == 32;
        invariant vrf_state.status == types::VRF_STATUS_FULFILLED ==> len(snapshot_hash) == 32;
        invariant vrf_state.retry_after_ts == 0
            ==> vrf_state.status == types::VRF_STATUS_IDLE
                || vrf_state.status == types::VRF_STATUS_FULFILLED;
        invariant vrf_state.status == types::VRF_STATUS_FULFILLED ==> !vrf_state.consumed || len(verified_payload) > 0;
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
        ensures has_state(@lottery_multi, lottery_id);
        ensures new_state.vrf_state.status == types::VRF_STATUS_REQUESTED;
        ensures new_state.vrf_state.retry_after_ts == now_ts + RETRY_DELAY_SECS;
        ensures new_state.vrf_state.consumed == false;
        ensures new_state.vrf_state.schema_version == types::DEFAULT_SCHEMA_VERSION;
        ensures new_state.vrf_state.retry_strategy == types::RETRY_STRATEGY_FIXED;
        ensures new_state.vrf_state.chain_id == chain_id;
        ensures new_state.vrf_state.closing_block_height == closing_block_height;
        ensures new_state.last_request_ts == now_ts;
        ensures new_state.verified_payload == b"";
        ensures new_state.winners_batch_hash == b"";
        ensures new_state.checksum_after_batch == b"";
        ensures new_state.client_seed < new_state.next_client_seed;
        ensures old(has_state(@lottery_multi, lottery_id))
            ==> new_state.vrf_state.attempt == old(draw_state(@lottery_multi, lottery_id)).vrf_state.attempt + 1;
        ensures !old(has_state(@lottery_multi, lottery_id)) ==> new_state.vrf_state.attempt == 1;
        ensures old(has_state(@lottery_multi, lottery_id))
            ==> new_state.next_client_seed == old(draw_state(@lottery_multi, lottery_id)).next_client_seed + 1;
        ensures !old(has_state(@lottery_multi, lottery_id)) ==> new_state.next_client_seed == 1;
        ensures old(has_state(@lottery_multi, lottery_id))
            ==> new_state.client_seed == old(draw_state(@lottery_multi, lottery_id)).next_client_seed;
        ensures !old(has_state(@lottery_multi, lottery_id)) ==> new_state.client_seed == 0;
    }

    spec vrf_callback {
        let lottery_id = old(lottery_for_nonce(@lottery_multi, nonce));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures new_state.vrf_state.status == types::VRF_STATUS_FULFILLED;
        ensures new_state.vrf_state.consumed == false;
        ensures new_state.vrf_state.retry_after_ts == 0;
        ensures new_state.verified_payload == bcs::to_bytes(&supra_vrf::verify_callback(
            nonce,
            message,
            signature,
            caller_address,
            rng_count,
            client_seed,
        ));
    }

    spec prepare_for_winner_computation {
        let old_state = old(draw_state(@lottery_multi, lottery_id));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures old_state.vrf_state.status == types::VRF_STATUS_FULFILLED;
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
