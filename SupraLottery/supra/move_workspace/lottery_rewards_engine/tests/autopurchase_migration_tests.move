#[test_only]
module lottery_rewards_engine::autopurchase_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_rewards_engine::autopurchase;

    #[test(lottery_admin = @lottery)]
    fun import_existing_plans_restore_snapshot(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 101, @0xA101);
        register_lottery(lottery_admin, 202, @0xB202);

        let mut plans = vector::empty<autopurchase::LegacyAutopurchasePlan>();
        vector::push_back(
            &mut plans,
            autopurchase::LegacyAutopurchasePlan {
                lottery_id: 101,
                player: @0xC001,
                balance: 120,
                tickets_per_draw: 5,
                active: true,
            },
        );
        vector::push_back(
            &mut plans,
            autopurchase::LegacyAutopurchasePlan {
                lottery_id: 101,
                player: @0xD002,
                balance: 20,
                tickets_per_draw: 0,
                active: false,
            },
        );
        vector::push_back(
            &mut plans,
            autopurchase::LegacyAutopurchasePlan {
                lottery_id: 202,
                player: @0xE003,
                balance: 400,
                tickets_per_draw: 2,
                active: true,
            },
        );

        autopurchase::import_existing_plans(lottery_admin, plans);

        let ids = autopurchase::list_lottery_ids();
        assert!(vector::length(&ids) == 2, 0);

        let snapshot_opt = autopurchase::snapshot();
        assert!(option::is_some(&snapshot_opt), 1);
        let snapshot = option::destroy_some(snapshot_opt);

        let first_opt = find_lottery_snapshot(&snapshot.lotteries, 101, 0);
        assert!(option::is_some(&first_opt), 2);
        let first = option::destroy_some(first_opt);
        assert!(first.total_balance == 140, 3);
        assert!(first.total_players == 2, 4);
        assert!(first.active_players == 1, 5);

        let plan_a_opt = find_player_snapshot(&first.players, @0xC001, 0);
        assert!(option::is_some(&plan_a_opt), 6);
        let plan_a = option::destroy_some(plan_a_opt);
        assert!(plan_a.balance == 120, 7);
        assert!(plan_a.tickets_per_draw == 5, 8);
        assert!(plan_a.active, 9);

        let plan_b_opt = find_player_snapshot(&first.players, @0xD002, 0);
        assert!(option::is_some(&plan_b_opt), 10);
        let plan_b = option::destroy_some(plan_b_opt);
        assert!(plan_b.balance == 20, 11);
        assert!(plan_b.tickets_per_draw == 0, 12);
        assert!(!plan_b.active, 13);

        let second_opt = find_lottery_snapshot(&snapshot.lotteries, 202, 0);
        assert!(option::is_some(&second_opt), 12);
        let second = option::destroy_some(second_opt);
        assert!(second.total_balance == 400, 14);
        assert!(second.total_players == 1, 15);
        assert!(second.active_players == 1, 16);

        let only_player_opt = find_player_snapshot(&second.players, @0xE003, 0);
        assert!(option::is_some(&only_player_opt), 17);
        let only_player = option::destroy_some(only_player_opt);
        assert!(only_player.tickets_per_draw == 2, 18);
        assert!(only_player.active, 19);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_plan(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 404, @0xF404);

        autopurchase::import_existing_plan(
            lottery_admin,
            autopurchase::LegacyAutopurchasePlan {
                lottery_id: 404,
                player: @0xAA10,
                balance: 75,
                tickets_per_draw: 3,
                active: true,
            },
        );

        autopurchase::import_existing_plan(
            lottery_admin,
            autopurchase::LegacyAutopurchasePlan {
                lottery_id: 404,
                player: @0xAA10,
                balance: 140,
                tickets_per_draw: 1,
                active: false,
            },
        );

        let summary_opt = autopurchase::get_lottery_summary(404);
        assert!(option::is_some(&summary_opt), 20);
        let summary = option::destroy_some(summary_opt);
        assert!(summary.total_balance == 140, 21);
        assert!(summary.total_players == 1, 22);
        assert!(summary.active_players == 0, 23);

        let snapshot_opt = autopurchase::snapshot();
        assert!(option::is_some(&snapshot_opt), 24);
        let snapshot = option::destroy_some(snapshot_opt);
        let lottery_opt = find_lottery_snapshot(&snapshot.lotteries, 404, 0);
        assert!(option::is_some(&lottery_opt), 25);
        let lottery_snapshot = option::destroy_some(lottery_opt);
        assert!(lottery_snapshot.total_balance == 140, 26);

        let player_snapshot_opt = find_player_snapshot(&lottery_snapshot.players, @0xAA10, 0);
        assert!(option::is_some(&player_snapshot_opt), 27);
        let player_snapshot = option::destroy_some(player_snapshot_opt);
        assert!(player_snapshot.balance == 140, 28);
        assert!(player_snapshot.tickets_per_draw == 1, 29);
        assert!(!player_snapshot.active, 30);
    }

    fun bootstrap_prerequisites(lottery_admin: &signer) {
        if (!instances::is_initialized()) {
            instances::init_registry(lottery_admin, @lottery);
        };
        if (!autopurchase::is_initialized()) {
            autopurchase::init(lottery_admin);
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

    fun find_lottery_snapshot(
        snapshots: &vector<autopurchase::AutopurchaseLotterySnapshot>,
        lottery_id: u64,
        index: u64,
    ): option::Option<autopurchase::AutopurchaseLotterySnapshot> {
        if (index == vector::length(snapshots)) {
            return option::none<autopurchase::AutopurchaseLotterySnapshot>();
        };
        let snapshot = *vector::borrow(snapshots, index);
        if (snapshot.lottery_id == lottery_id) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_lottery_snapshot(snapshots, lottery_id, next_index)
    }

    fun find_player_snapshot(
        players: &vector<autopurchase::AutopurchasePlayerSnapshot>,
        player: address,
        index: u64,
    ): option::Option<autopurchase::AutopurchasePlayerSnapshot> {
        if (index == vector::length(players)) {
            return option::none<autopurchase::AutopurchasePlayerSnapshot>();
        };
        let snapshot = *vector::borrow(players, index);
        if (snapshot.player == player) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_player_snapshot(players, player, next_index)
    }
}
