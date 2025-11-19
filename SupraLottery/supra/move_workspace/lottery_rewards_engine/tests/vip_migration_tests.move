#[test_only]
module lottery_rewards_engine::vip_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use lottery_rewards_engine::vip;

    #[test(lottery_admin = @lottery)]
    fun import_existing_lotteries_restore_snapshot(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 11, @0xA011);
        register_lottery(lottery_admin, 22, @0xB022);

        let mut lotteries = vector::empty<vip::LegacyVipLottery>();
        vector::push_back(
            &mut lotteries,
            make_legacy_vip_lottery(
                11,
                50,
                7200,
                3,
                900,
                120,
                make_members(@0xC001, @0xC002),
                make_subscriptions(
                    make_subscription(@0xC001, 10_000, 5),
                    make_subscription(@0xC002, 5_000, 1),
                ),
            ),
        );
        vector::push_back(
            &mut lotteries,
            make_legacy_vip_lottery(
                22,
                75,
                3600,
                2,
                400,
                25,
                make_members(@0xD001, @0xD002),
                make_subscriptions(
                    make_subscription(@0xD001, 2_000, 4),
                    make_subscription(@0xD002, 500, 0),
                ),
            ),
        );

        vip::import_existing_lotteries(lottery_admin, lotteries);

        let ids = vip::list_lottery_ids();
        assert!(vector::length(&ids) == 2, 0);

        let summary_opt = vip::get_lottery_summary(11);
        assert!(option::is_some(&summary_opt), 1);
        let summary = option::destroy_some(summary_opt);
        let config = summary.config;
        assert!(vip::vip_config_price(&config) == 50, 2);
        assert!(vip::vip_config_duration_secs(&config) == 7200, 3);
        assert!(vip::vip_config_bonus_tickets(&config) == 3, 4);
        assert!(summary.total_members == 2, 5);
        assert!(summary.active_members == 2, 6);
        assert!(summary.total_revenue == 900, 7);
        assert!(summary.bonus_tickets_issued == 120, 8);

        let players_opt = vip::list_players(11);
        assert!(option::is_some(&players_opt), 9);
        let players = option::destroy_some(players_opt);
        assert!(vector::length(&players) == 2, 10);
        assert!(*vector::borrow(&players, 0) == @0xC001, 11);
        assert!(*vector::borrow(&players, 1) == @0xC002, 12);

        let alice_opt = vip::get_subscription(11, @0xC001);
        assert!(option::is_some(&alice_opt), 13);
        let alice = option::destroy_some(alice_opt);
        assert!(alice.expiry_ts == 10_000, 14);
        assert!(alice.is_active, 15);
        assert!(alice.bonus_tickets == 5, 16);

        let bob_opt = vip::get_subscription(11, @0xC002);
        assert!(option::is_some(&bob_opt), 17);
        let bob = option::destroy_some(bob_opt);
        assert!(bob.expiry_ts == 5_000, 18);
        assert!(bob.bonus_tickets == 1, 19);

        let second_summary_opt = vip::get_lottery_summary(22);
        assert!(option::is_some(&second_summary_opt), 20);
        let second_summary = option::destroy_some(second_summary_opt);
        let second_config = second_summary.config;
        assert!(vip::vip_config_price(&second_config) == 75, 21);
        assert!(second_summary.total_members == 2, 22);
        assert!(second_summary.total_revenue == 400, 23);
        assert!(second_summary.bonus_tickets_issued == 25, 24);

        let second_players_opt = vip::list_players(22);
        assert!(option::is_some(&second_players_opt), 25);
        let second_players = option::destroy_some(second_players_opt);
        assert!(vector::length(&second_players) == 2, 26);
        assert!(*vector::borrow(&second_players, 0) == @0xD001, 27);
        assert!(*vector::borrow(&second_players, 1) == @0xD002, 28);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_snapshot(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 33, @0xAA33);

        vip::import_existing_lottery(
            lottery_admin,
            make_legacy_vip_lottery(
                33,
                40,
                3600,
                1,
                200,
                5,
                make_members(@0xE001, @0xE002),
                make_subscriptions(
                    make_subscription(@0xE001, 3_000, 2),
                    make_subscription(@0xE002, 1_000, 1),
                ),
            ),
        );

        vip::import_existing_lottery(
            lottery_admin,
            make_legacy_vip_lottery(
                33,
                60,
                10_800,
                4,
                900,
                42,
                make_members(@0xE002, @0xE003),
                make_subscriptions(
                    make_subscription(@0xE002, 7_000, 3),
                    make_subscription(@0xE003, 6_000, 4),
                ),
            ),
        );

        let summary_opt = vip::get_lottery_summary(33);
        assert!(option::is_some(&summary_opt), 29);
        let summary = option::destroy_some(summary_opt);
        let config = summary.config;
        assert!(vip::vip_config_price(&config) == 60, 30);
        assert!(vip::vip_config_duration_secs(&config) == 10_800, 31);
        assert!(vip::vip_config_bonus_tickets(&config) == 4, 32);
        assert!(summary.total_members == 2, 33);
        assert!(summary.total_revenue == 900, 34);
        assert!(summary.bonus_tickets_issued == 42, 35);

        let players_opt = vip::list_players(33);
        assert!(option::is_some(&players_opt), 36);
        let players = option::destroy_some(players_opt);
        assert!(vector::length(&players) == 2, 37);
        assert!(*vector::borrow(&players, 0) == @0xE002, 38);
        assert!(*vector::borrow(&players, 1) == @0xE003, 39);

        let removed_opt = vip::get_subscription(33, @0xE001);
        assert!(option::is_none(&removed_opt), 40);

        let retained_opt = vip::get_subscription(33, @0xE002);
        assert!(option::is_some(&retained_opt), 41);
        let retained = option::destroy_some(retained_opt);
        assert!(retained.expiry_ts == 7_000, 42);
        assert!(retained.bonus_tickets == 3, 43);

        let newcomer_opt = vip::get_subscription(33, @0xE003);
        assert!(option::is_some(&newcomer_opt), 44);
        let newcomer = option::destroy_some(newcomer_opt);
        assert!(newcomer.expiry_ts == 6_000, 45);
        assert!(newcomer.bonus_tickets == 4, 46);
    }

    fun bootstrap_prerequisites(lottery_admin: &signer) {
        if (!instances::is_initialized()) {
            instances::init_registry(lottery_admin, @lottery);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init_state(lottery_admin, @lottery, @lottery);
        };
        treasury_multi::bootstrap_control_for_tests(lottery_admin);
        if (!vip::is_initialized()) {
            vip::init(lottery_admin);
        };
    }

    fun register_lottery(lottery_admin: &signer, lottery_id: u64, owner: address) {
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
    }

    fun make_members(first: address, second: address): vector<address> {
        let mut members = vector::empty<address>();
        vector::push_back(&mut members, first);
        vector::push_back(&mut members, second);
        members
    }

    fun make_subscription(player: address, expiry_ts: u64, bonus_tickets: u64): vip::LegacyVipSubscription {
        vip::LegacyVipSubscription { player, expiry_ts, bonus_tickets }
    }

    fun make_subscriptions(
        first: vip::LegacyVipSubscription,
        second: vip::LegacyVipSubscription,
    ): vector<vip::LegacyVipSubscription> {
        let mut subscriptions = vector::empty<vip::LegacyVipSubscription>();
        vector::push_back(&mut subscriptions, first);
        vector::push_back(&mut subscriptions, second);
        subscriptions
    }

    fun make_legacy_vip_lottery(
        lottery_id: u64,
        price: u64,
        duration_secs: u64,
        bonus_tickets: u64,
        total_revenue: u64,
        bonus_tickets_issued: u64,
        members: vector<address>,
        subscriptions: vector<vip::LegacyVipSubscription>,
    ): vip::LegacyVipLottery {
        vip::LegacyVipLottery {
            lottery_id,
            config: vip::vip_config_for_tests(price, duration_secs, bonus_tickets),
            total_revenue,
            bonus_tickets_issued,
            members,
            subscriptions,
        }
    }
}
