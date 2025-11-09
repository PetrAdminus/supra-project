module lottery_multi::vrf_deposit_tests {
    use std::signer;

    use lottery_multi::errors;
    use lottery_multi::vrf_deposit;

    #[test(account = @lottery_multi)]
    fun init_and_snapshot_ok(account: &signer) {
        vrf_deposit::init_vrf_deposit(account, 12_000, 1_000);
        vrf_deposit::record_snapshot_admin(account, 20_000, 10_000, 15_000, 100);
        let status = vrf_deposit::get_status();
        assert!(!status.requests_paused, 0);
        assert!(status.required_minimum == 12_000, 0);
        vrf_deposit::ensure_requests_allowed();
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_VRF_REQUESTS_PAUSED)]
    fun snapshot_pauses_requests(account: &signer) {
        vrf_deposit::init_vrf_deposit(account, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(account, 2_000, 1_500, 1_000, 200);
        vrf_deposit::ensure_requests_allowed();
    }

    #[test(account = @lottery_multi)]
    fun resume_after_pause(account: &signer) {
        vrf_deposit::init_vrf_deposit(account, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(account, 2_000, 1_500, 1_000, 200);
        vrf_deposit::resume_requests(account, 400);
        vrf_deposit::record_snapshot_admin(account, 20_000, 10_000, 15_000, 500);
        vrf_deposit::ensure_requests_allowed();
        let status = vrf_deposit::get_status();
        assert!(!status.requests_paused, 0);
        assert!(status.paused_since_ts == 0, 0);
    }
}
