#[test_only]
module lottery_rewards_engine::referrals_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use lottery_rewards_engine::referrals;

    #[test(lottery_admin = @lottery)]
    fun import_legacy_referrals_restore_snapshot(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 501, @0xFA01, 3_000);
        register_lottery(lottery_admin, 777, @0xFA02, 2_500);

        let mut lotteries = vector::empty<referrals::LegacyReferralLottery>();
        vector::push_back(
            &mut lotteries,
            referrals::LegacyReferralLottery {
                lottery_id: 501,
                referrer_bps: 1_000,
                referee_bps: 500,
                rewarded_purchases: 4,
                total_referrer_rewards: 80,
                total_referee_rewards: 40,
            },
        );
        vector::push_back(
            &mut lotteries,
            referrals::LegacyReferralLottery {
                lottery_id: 777,
                referrer_bps: 750,
                referee_bps: 250,
                rewarded_purchases: 2,
                total_referrer_rewards: 30,
                total_referee_rewards: 10,
            },
        );

        referrals::import_existing_lotteries(lottery_admin, lotteries);

        let mut registrations = vector::empty<referrals::LegacyReferralRegistration>();
        vector::push_back(
            &mut registrations,
            referrals::LegacyReferralRegistration { player: @0xC001, referrer: @0xF0A1 },
        );
        vector::push_back(
            &mut registrations,
            referrals::LegacyReferralRegistration { player: @0xC002, referrer: @0xF0A1 },
        );
        vector::push_back(
            &mut registrations,
            referrals::LegacyReferralRegistration { player: @0xC003, referrer: @0xF0B2 },
        );

        referrals::import_existing_registrations(lottery_admin, registrations);

        let snapshot = referrals::get_referral_snapshot();
        assert!(snapshot.admin == @lottery, 0);
        assert!(snapshot.total_registered == 3, 1);
        assert!(vector::length(&snapshot.lotteries) == 2, 2);

        let first_opt = find_lottery_snapshot(&snapshot.lotteries, 501, 0);
        assert!(option::is_some(&first_opt), 3);
        let first = option::destroy_some(first_opt);
        assert!(first.referrer_bps == 1_000, 4);
        assert!(first.referee_bps == 500, 5);
        assert!(first.rewarded_purchases == 4, 6);
        assert!(first.total_referrer_rewards == 80, 7);
        assert!(first.total_referee_rewards == 40, 8);

        let second_opt = find_lottery_snapshot(&snapshot.lotteries, 777, 0);
        assert!(option::is_some(&second_opt), 9);
        let second = option::destroy_some(second_opt);
        assert!(second.referrer_bps == 750, 10);
        assert!(second.referee_bps == 250, 11);
        assert!(second.rewarded_purchases == 2, 12);
        assert!(second.total_referrer_rewards == 30, 13);
        assert!(second.total_referee_rewards == 10, 14);

        let ledger = referrals::get_ledger_snapshot();
        assert!(vector::length(&ledger.registrations) == 3, 15);
        let reg_opt = find_registration(&ledger.registrations, @0xC003, 0);
        assert!(option::is_some(&reg_opt), 16);
        let registration = option::destroy_some(reg_opt);
        assert!(registration.referrer == @0xF0B2, 17);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_lotteries_and_registrations(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 909, @0xDD01, 4_000);

        referrals::import_existing_lottery(
            lottery_admin,
            referrals::LegacyReferralLottery {
                lottery_id: 909,
                referrer_bps: 500,
                referee_bps: 250,
                rewarded_purchases: 1,
                total_referrer_rewards: 10,
                total_referee_rewards: 5,
            },
        );

        referrals::import_existing_registration(
            lottery_admin,
            referrals::LegacyReferralRegistration { player: @0xE100, referrer: @0xEA10 },
        );

        referrals::import_existing_lottery(
            lottery_admin,
            referrals::LegacyReferralLottery {
                lottery_id: 909,
                referrer_bps: 800,
                referee_bps: 300,
                rewarded_purchases: 3,
                total_referrer_rewards: 45,
                total_referee_rewards: 18,
            },
        );

        referrals::import_existing_registration(
            lottery_admin,
            referrals::LegacyReferralRegistration { player: @0xE100, referrer: @0xEB11 },
        );

        let snapshot = referrals::get_referral_snapshot();
        assert!(vector::length(&snapshot.lotteries) == 1, 18);
        assert!(snapshot.total_registered == 1, 19);

        let lottery_opt = find_lottery_snapshot(&snapshot.lotteries, 909, 0);
        assert!(option::is_some(&lottery_opt), 20);
        let lottery_snapshot = option::destroy_some(lottery_opt);
        assert!(lottery_snapshot.referrer_bps == 800, 21);
        assert!(lottery_snapshot.referee_bps == 300, 22);
        assert!(lottery_snapshot.rewarded_purchases == 3, 23);
        assert!(lottery_snapshot.total_referrer_rewards == 45, 24);
        assert!(lottery_snapshot.total_referee_rewards == 18, 25);

        let referrer_opt = referrals::get_referrer(@0xE100);
        assert!(option::is_some(&referrer_opt), 26);
        assert!(*option::borrow(&referrer_opt) == @0xEB11, 27);
    }

    fun bootstrap_prerequisites(lottery_admin: &signer) {
        if (!instances::is_initialized()) {
            instances::init_registry(lottery_admin);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init_state(lottery_admin, @0xCAFE, @0xBEEF);
        };
        if (!referrals::is_initialized()) {
            referrals::init(lottery_admin);
        };
    }

    fun register_lottery(
        lottery_admin: &signer,
        lottery_id: u64,
        owner: address,
        operations_bps: u64,
    ) {
        let record = instances::LegacyInstanceRecord {
            lottery_id,
            owner,
            lottery_address: owner,
            ticket_price: 1,
            jackpot_share_bps: 100,
            tickets_sold: 0,
            jackpot_accumulated: 0,
            active: true,
        };
        instances::import_existing_instance(lottery_admin, record);

        treasury_multi::import_existing_lottery(
            lottery_admin,
            treasury_multi::LegacyMultiTreasuryLottery {
                lottery_id,
                prize_bps: 6_000,
                jackpot_bps: 1_000,
                operations_bps,
                prize_balance: 0,
                operations_balance: 0,
            },
        );
    }

    fun find_lottery_snapshot(
        snapshots: &vector<referrals::LotteryReferralSnapshot>,
        lottery_id: u64,
        index: u64,
    ): option::Option<referrals::LotteryReferralSnapshot> {
        if (index == vector::length(snapshots)) {
            return option::none<referrals::LotteryReferralSnapshot>();
        };
        let snapshot = *vector::borrow(snapshots, index);
        if (snapshot.lottery_id == lottery_id) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_lottery_snapshot(snapshots, lottery_id, next_index)
    }

    fun find_registration(
        registrations: &vector<referrals::ReferralRegistrationSnapshot>,
        player: address,
        index: u64,
    ): option::Option<referrals::ReferralRegistrationSnapshot> {
        if (index == vector::length(registrations)) {
            return option::none<referrals::ReferralRegistrationSnapshot>();
        };
        let snapshot = *vector::borrow(registrations, index);
        if (snapshot.player == player) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_registration(registrations, player, next_index)
    }
}
