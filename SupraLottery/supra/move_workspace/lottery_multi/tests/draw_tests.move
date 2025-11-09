module lottery_multi::draw_tests {
    use std::signer;

    use lottery_multi::draw;
    use lottery_multi::errors;
    use lottery_multi::vrf_deposit;

    #[test(admin = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_VRF_REQUESTS_PAUSED)]
    fun request_rejected_when_deposit_paused(admin: &signer) {
        vrf_deposit::init_vrf_deposit(admin, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(admin, 2_000, 1_500, 1_000, 200);
        draw::init_draw(admin);
        draw::request_draw_admin(admin, 1, 300, 42, 1, 0);
    }
}
