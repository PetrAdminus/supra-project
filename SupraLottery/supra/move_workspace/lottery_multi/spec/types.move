spec module lottery_multi::types {
    use lottery_multi::types::{
        VrfState,
        WinnerCursor,
        VRF_STATUS_IDLE,
        VRF_STATUS_REQUESTED,
        VRF_STATUS_FULFILLED,
    };

    spec struct VrfState {
        invariant attempt <= 255;
        invariant status == VRF_STATUS_IDLE ==> !consumed;
        invariant status == VRF_STATUS_REQUESTED ==> !consumed;
        invariant consumed ==> status == VRF_STATUS_FULFILLED;
        invariant schema_version >= 1;
    }

    spec struct WinnerCursor {
        invariant len(checksum_after_batch) == 32;
    }
}
