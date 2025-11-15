module lottery_multi::vrf_deposit_tests {
    use std::vector;

    use lottery_multi::automation;
    use lottery_multi::errors;
    use lottery_multi::vrf_deposit;

    // #[test(account = @lottery_multi)]
    fun init_and_snapshot_ok(account: &signer) {

        vrf_deposit::init_vrf_deposit(account, 12_000, 1_000);
        vrf_deposit::record_snapshot_admin(account, 20_000, 10_000, 15_000, 100);
        let status = vrf_deposit::get_status();
        assert!(!vrf_deposit::status_requests_paused(&status), 0);
        assert!(vrf_deposit::status_required_minimum(&status) == 12_000, 0);
        vrf_deposit::ensure_requests_allowed();
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_VRF_REQUESTS_PAUSED)]
    fun snapshot_pauses_requests(account: &signer) {

        vrf_deposit::init_vrf_deposit(account, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(account, 2_000, 1_500, 1_000, 200);
        vrf_deposit::ensure_requests_allowed();
    }

    // #[test(account = @lottery_multi)]
    fun resume_after_pause(account: &signer) {

        vrf_deposit::init_vrf_deposit(account, 12_000, 5_000);
        vrf_deposit::record_snapshot_admin(account, 2_000, 1_500, 1_000, 200);
        vrf_deposit::resume_requests(account, 400);
        vrf_deposit::record_snapshot_admin(account, 20_000, 10_000, 15_000, 500);
        vrf_deposit::ensure_requests_allowed();
        let status = vrf_deposit::get_status();
        assert!(!vrf_deposit::status_requests_paused(&status), 0);
        assert!(vrf_deposit::status_paused_since_ts(&status) == 0, 0);
    }

    // #[test(admin = @lottery_multi, operator = @0x1)]
    // // #[expected_failure(abort_code = errors::E_AUTOBOT_PENDING_REQUIRED)]
    fun automation_snapshot_requires_pending(
        admin: &signer,
        operator: &signer,
    ) {
        setup_vrf_and_bot(admin, operator, 60, 3, 10_000);
        let cap = automation::take_cap_for_tests(operator);
        vrf_deposit::record_snapshot_automation(
            operator,
            &cap,
            20_000,
            10_000,
            15_000,
            200,
            hash(1),
        );
        automation::return_cap_for_tests(operator, cap);
    }

    // #[test(admin = @lottery_multi, operator = @0x1)]
    // // #[expected_failure(abort_code = errors::E_AUTOBOT_TIMELOCK)]
    fun automation_snapshot_respects_timelock(
        admin: &signer,
        operator: &signer,
    ) {
        setup_vrf_and_bot(admin, operator, 40, 3, 10_000);
        let digest = hash(2);
        let announced = clone_bytes(&digest);
        automation::announce_dry_run_for_tests(
            operator,
            automation::action_topup_vrf_deposit(),
            announced,
            100,
            150,
        );
        let cap = automation::take_cap_for_tests(operator);
        vrf_deposit::record_snapshot_automation(
            operator,
            &cap,
            18_000,
            9_000,
            12_000,
            130,
            digest,
        );
        automation::return_cap_for_tests(operator, cap);
    }

    // #[test(admin = @lottery_multi, operator = @0x1)]
    fun automation_snapshot_clears_pending(
        admin: &signer,
        operator: &signer,
    ) {
        setup_vrf_and_bot(admin, operator, 45, 3, 10_000);
        let digest = hash(3);
        let announced = clone_bytes(&digest);
        automation::announce_dry_run_for_tests(
            operator,
            automation::action_topup_vrf_deposit(),
            announced,
            200,
            250,
        );
        let cap = automation::take_cap_for_tests(operator);
        vrf_deposit::record_snapshot_automation(
            operator,
            &cap,
            50_000,
            20_000,
            30_000,
            260,
            digest,
        );
        automation::return_cap_for_tests(operator, cap);
        automation::announce_dry_run_for_tests(
            operator,
            automation::action_topup_vrf_deposit(),
            hash(4),
            270,
            320,
        );
        let status = vrf_deposit::get_status();
        assert!(vrf_deposit::status_total_balance(&status) == 50_000, 0);
        assert!(vrf_deposit::status_minimum_balance(&status) == 20_000, 0);
        assert!(vrf_deposit::status_effective_balance(&status) == 30_000, 0);
        assert!(vrf_deposit::status_last_update_ts(&status) == 260, 0);
    }

    fun setup_vrf_and_bot(
        admin: &signer,
        operator: &signer,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
    ) {

        vrf_deposit::init_vrf_deposit(admin, 12_000, 5_000);

        automation::init_automation(admin);
        automation::register_bot(
            admin,
            operator,
            cron_spec(),
            single_action(),
            timelock_secs,
            max_failures,
            expires_at,
        );
    }

    fun cron_spec(): vector<u8> {
        vector::empty<u8>()
    }

    fun single_action(): vector<u64> {
        let actions = vector::empty<u64>();
        vector::push_back(&mut actions, automation::action_topup_vrf_deposit());
        actions
    }

    fun hash(seed: u8): vector<u8> {
        let out = vector::empty<u8>();
        vector::push_back(&mut out, seed);
        out
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let out = vector::empty<u8>();
        let idx = 0;
        while (idx < len) {
            let byte = *vector::borrow(source, idx);
            vector::push_back(&mut out, byte);
            idx = idx + 1;
        };
        out
    }
}








