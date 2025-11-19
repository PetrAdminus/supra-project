#[test_only]
module lottery_rewards_engine::autopurchase_ready_tests {
    use lottery_data::rounds;
    use lottery_data::treasury;
    use lottery_rewards_engine::autopurchase;
    use std::signer;

    #[test(lottery_admin = @lottery)]
    fun autopurchase_ready_flow(lottery_admin: &signer) {
        assert!(!autopurchase::ready(), 1);

        rounds::init_registry(lottery_admin);
        rounds::init_control(lottery_admin);
        rounds::init_history_queue(lottery_admin);
        rounds::init_purchase_queue(lottery_admin);

        let vault_config = treasury::VaultConfig {
            bp_jackpot: 3_000,
            bp_prize: 3_000,
            bp_treasury: 2_000,
            bp_marketing: 1_000,
            bp_community: 500,
            bp_team: 400,
            bp_partners: 100,
        };
        let vault_recipients = treasury::VaultRecipients {
            treasury: @lottery,
            marketing: @lottery,
            community: @lottery,
            team: @lottery,
            partners: @lottery,
        };
        treasury::init_vaults(lottery_admin, vault_config, vault_recipients);
        treasury::init_control(lottery_admin);

        autopurchase::init(lottery_admin);
        autopurchase::init_access(lottery_admin);

        assert!(autopurchase::ready(), 2);
    }
}
