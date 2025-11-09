spec module lottery_multi::draw {
    use std::table;

    use lottery_multi::draw::{DrawLedger, DrawState};
    use lottery_multi::types;

    spec struct DrawState {
        invariant len(snapshot_hash) == 0 || len(snapshot_hash) == 32;
        invariant vrf_state.status == types::VRF_STATUS_REQUESTED ==> len(snapshot_hash) == 32;
        invariant vrf_state.status == types::VRF_STATUS_FULFILLED ==> len(snapshot_hash) == 32;
    }

    spec fun draw_state(addr: address, lottery_id: u64): DrawState {
        table::borrow(&global<DrawLedger>(addr).states, lottery_id)
    }

    spec record_winner_hashes {
        let old_state = old(draw_state(@lottery_multi, lottery_id));
        let new_state = draw_state(@lottery_multi, lottery_id);
        ensures new_state.snapshot_hash == old_state.snapshot_hash;
    }
}
