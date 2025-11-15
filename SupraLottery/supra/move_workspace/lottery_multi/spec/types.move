spec module lottery_multi::types {
    use lottery_multi::types::{
        VrfState,
        WinnerCursor,



    };

    spec struct VrfState {
        invariant attempt <= 255;
        invariant status == lottery_multi::types::vrf_status_idle() ==> !consumed;
        invariant status == lottery_multi::types::vrf_status_requested() ==> !consumed;
        invariant consumed ==> status == lottery_multi::types::vrf_status_fulfilled();
        invariant schema_version >= 1;
        invariant retry_strategy == 0 || retry_strategy == 1 || retry_strategy == 2;
        invariant closing_block_height >= 0;
        invariant chain_id >= 0;
    }

    spec struct WinnerCursor {
        invariant len(checksum_after_batch) == 32;
    }
}
