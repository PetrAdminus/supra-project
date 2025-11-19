#[test_only]
module lottery_data::treasury_migration_tests {
    use std::option;

    use lottery_data::treasury;

    #[test(lottery_admin = @lottery)]
    fun import_existing_vaults_restores_config_and_recipients(lottery_admin: &signer) {
        treasury::init_vaults(lottery_admin, baseline_config(), baseline_recipients());

        let payload = treasury::LegacyVaultState {
            config: treasury::LegacyVaultConfig {
                bp_jackpot: 2_000,
                bp_prize: 4_000,
                bp_treasury: 1_000,
                bp_marketing: 1_000,
                bp_community: 1_200,
                bp_team: 600,
                bp_partners: 200,
            },
            recipients: treasury::LegacyVaultRecipients {
                treasury: @0xAAA1,
                marketing: @0xAAA2,
                community: @0xAAA3,
                team: @0xAAA4,
                partners: @0xAAA5,
            },
        };

        treasury::import_existing_vaults(lottery_admin, payload);

        let snapshot_opt = treasury::vaults_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        let config = snapshot.config;
        assert!(config.bp_jackpot == 2_000, 1);
        assert!(config.bp_prize == 4_000, 2);
        assert!(config.bp_treasury == 1_000, 3);
        assert!(config.bp_marketing == 1_000, 4);
        assert!(config.bp_community == 1_200, 5);
        assert!(config.bp_team == 600, 6);
        assert!(config.bp_partners == 200, 7);

        let recipients = snapshot.recipients;
        assert!(recipients.treasury.account == @0xAAA1, 8);
        assert!(recipients.marketing.account == @0xAAA2, 9);
        assert!(recipients.community.account == @0xAAA3, 10);
        assert!(recipients.team.account == @0xAAA4, 11);
        assert!(recipients.partners.account == @0xAAA5, 12);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_config(lottery_admin: &signer) {
        treasury::init_vaults(lottery_admin, baseline_config(), baseline_recipients());

        treasury::import_existing_vaults(
            lottery_admin,
            treasury::LegacyVaultState {
                config: treasury::LegacyVaultConfig {
                    bp_jackpot: 3_000,
                    bp_prize: 3_500,
                    bp_treasury: 1_500,
                    bp_marketing: 800,
                    bp_community: 700,
                    bp_team: 400,
                    bp_partners: 100,
                },
                recipients: treasury::LegacyVaultRecipients {
                    treasury: @0xB001,
                    marketing: @0xB002,
                    community: @0xB003,
                    team: @0xB004,
                    partners: @0xB005,
                },
            },
        );

        treasury::import_existing_vaults(
            lottery_admin,
            treasury::LegacyVaultState {
                config: treasury::LegacyVaultConfig {
                    bp_jackpot: 1_000,
                    bp_prize: 1_000,
                    bp_treasury: 6_000,
                    bp_marketing: 1_000,
                    bp_community: 400,
                    bp_team: 400,
                    bp_partners: 600,
                },
                recipients: treasury::LegacyVaultRecipients {
                    treasury: @0xC010,
                    marketing: @0xC020,
                    community: @0xC030,
                    team: @0xC040,
                    partners: @0xC050,
                },
            },
        );

        let snapshot_opt = treasury::vaults_snapshot();
        assert!(option::is_some(&snapshot_opt), 13);
        let snapshot = option::destroy_some(snapshot_opt);
        let config = snapshot.config;
        assert!(config.bp_jackpot == 1_000, 14);
        assert!(config.bp_prize == 1_000, 15);
        assert!(config.bp_treasury == 6_000, 16);
        assert!(config.bp_marketing == 1_000, 17);
        assert!(config.bp_community == 400, 18);
        assert!(config.bp_team == 400, 19);
        assert!(config.bp_partners == 600, 20);

        let recipients = snapshot.recipients;
        assert!(recipients.treasury.account == @0xC010, 21);
        assert!(recipients.marketing.account == @0xC020, 22);
        assert!(recipients.community.account == @0xC030, 23);
        assert!(recipients.team.account == @0xC040, 24);
        assert!(recipients.partners.account == @0xC050, 25);
    }

    fun baseline_config() -> treasury::VaultConfig {
        treasury::VaultConfig {
            bp_jackpot: 1_000,
            bp_prize: 1_000,
            bp_treasury: 1_000,
            bp_marketing: 1_000,
            bp_community: 1_000,
            bp_team: 1_000,
            bp_partners: 1_000,
        }
    }

    fun baseline_recipients() -> treasury::VaultRecipients {
        treasury::VaultRecipients {
            treasury: @0x1,
            marketing: @0x2,
            community: @0x3,
            team: @0x4,
            partners: @0x5,
        }
    }
}
