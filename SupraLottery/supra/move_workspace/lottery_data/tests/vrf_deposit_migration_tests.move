#[test_only]
module lottery_data::vrf_deposit_migration_tests {
    use std::option;

    use lottery_data::vrf_deposit;

    #[test(lottery_admin = @lottery)]
    fun import_existing_ledger_restores_config_and_status(lottery_admin: &signer) {
        vrf_deposit::import_existing_ledger(lottery_admin, sample_payload(false));

        let snapshot_opt = vrf_deposit::ledger_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 1);

        let config = snapshot.config;
        assert!(config.min_balance_multiplier_bps == 15_000, 2);
        assert!(config.effective_floor == 42, 3);

        let status = snapshot.status;
        assert!(status.total_balance == 5_000_000, 4);
        assert!(status.minimum_balance == 3_000_000, 5);
        assert!(status.effective_balance == 4_500_000, 6);
        assert!(status.required_minimum == 2_500_000, 7);
        assert!(status.last_update_ts == 123, 8);
        assert!(!status.requests_paused, 9);
        assert!(status.paused_since_ts == 0, 10);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_status_and_pause_flags(lottery_admin: &signer) {
        vrf_deposit::import_existing_ledger(lottery_admin, sample_payload(false));

        vrf_deposit::import_existing_ledger(lottery_admin, sample_payload(true));

        let snapshot_opt = vrf_deposit::ledger_snapshot();
        assert!(option::is_some(&snapshot_opt), 11);
        let snapshot = option::destroy_some(snapshot_opt);
        let config = snapshot.config;
        assert!(config.min_balance_multiplier_bps == 20_000, 12);
        assert!(config.effective_floor == 64, 13);

        let status = snapshot.status;
        assert!(status.total_balance == 6_000_000, 14);
        assert!(status.minimum_balance == 4_000_000, 15);
        assert!(status.effective_balance == 5_500_000, 16);
        assert!(status.required_minimum == 3_000_000, 17);
        assert!(status.last_update_ts == 456, 18);
        assert!(status.requests_paused, 19);
        assert!(status.paused_since_ts == 400, 20);
    }

    fun sample_payload(paused: bool) -> vrf_deposit::LegacyVrfDepositLedger {
        if (paused) {
            vrf_deposit::LegacyVrfDepositLedger {
                admin: @lottery,
                config: vrf_deposit::VrfDepositConfig {
                    min_balance_multiplier_bps: 20_000,
                    effective_floor: 64,
                },
                status: vrf_deposit::VrfDepositStatus {
                    total_balance: 6_000_000,
                    minimum_balance: 4_000_000,
                    effective_balance: 5_500_000,
                    required_minimum: 3_000_000,
                    last_update_ts: 456,
                    requests_paused: true,
                    paused_since_ts: 400,
                },
                snapshot_timestamp: 200,
            }
        } else {
            vrf_deposit::LegacyVrfDepositLedger {
                admin: @lottery,
                config: vrf_deposit::VrfDepositConfig {
                    min_balance_multiplier_bps: 15_000,
                    effective_floor: 42,
                },
                status: vrf_deposit::VrfDepositStatus {
                    total_balance: 5_000_000,
                    minimum_balance: 3_000_000,
                    effective_balance: 4_500_000,
                    required_minimum: 2_500_000,
                    last_update_ts: 123,
                    requests_paused: false,
                    paused_since_ts: 0,
                },
                snapshot_timestamp: 100,
            }
        }
    }
}
