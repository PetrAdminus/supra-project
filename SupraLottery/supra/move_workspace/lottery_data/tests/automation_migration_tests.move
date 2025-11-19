#[test_only]
module lottery_data::automation_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::automation;

    #[test(lottery_admin = @lottery)]
    fun import_existing_bots_restore_registry(lottery_admin: &signer) {
        automation::init_registry(lottery_admin);

        let mut first_actions = vector::empty<u64>();
        vector::push_back(&mut first_actions, 10);

        let mut second_actions = vector::empty<u64>();
        vector::push_back(&mut second_actions, 1);
        vector::push_back(&mut second_actions, 5);

        let mut first_pending = vector::empty<u8>();
        vector::push_back(&mut first_pending, 0);
        vector::push_back(&mut first_pending, 7);

        let mut first_cron = vector::empty<u8>();
        vector::push_back(&mut first_cron, 42);
        vector::push_back(&mut first_cron, 47);

        let mut first_last = vector::empty<u8>();
        vector::push_back(&mut first_last, 8);

        let mut second_pending = vector::empty<u8>();
        vector::push_back(&mut second_pending, 9);

        let mut second_cron = vector::empty<u8>();
        vector::push_back(&mut second_cron, 35);

        let mut second_last = vector::empty<u8>();
        vector::push_back(&mut second_last, 12);
        vector::push_back(&mut second_last, 34);

        let mut bots = vector::empty<automation::LegacyAutomationBot>();
        vector::push_back(
            &mut bots,
            automation::LegacyAutomationBot {
                operator: @0x111,
                allowed_actions: first_actions,
                timelock_secs: 60,
                max_failures: 3,
                failure_count: 1,
                success_streak: 5,
                reputation_score: 8,
                pending_action_hash: first_pending,
                pending_execute_after: 200,
                expires_at: 10_000,
                cron_spec: first_cron,
                last_action_ts: 1_000,
                last_action_hash: first_last,
            },
        );
        vector::push_back(
            &mut bots,
            automation::LegacyAutomationBot {
                operator: @0x222,
                allowed_actions: second_actions,
                timelock_secs: 90,
                max_failures: 5,
                failure_count: 0,
                success_streak: 15,
                reputation_score: 42,
                pending_action_hash: second_pending,
                pending_execute_after: 400,
                expires_at: 20_000,
                cron_spec: second_cron,
                last_action_ts: 2_500,
                last_action_hash: second_last,
            },
        );

        automation::import_existing_bots(lottery_admin, bots);

        let snapshot_opt = automation::registry_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 1);
        assert!(vector::length(&snapshot.bots) == 2, 2);

        let first_status_opt = automation::status_option(@0x111);
        assert!(option::is_some(&first_status_opt), 3);
        let first_status = option::destroy_some(first_status_opt);
        assert!(vector::length(&first_status.allowed_actions) == 1, 4);
        assert!(*vector::borrow(&first_status.allowed_actions, 0) == 10, 5);
        assert!(first_status.timelock_secs == 60, 6);
        assert!(first_status.max_failures == 3, 7);
        assert!(first_status.failure_count == 1, 8);
        assert!(first_status.pending_execute_after == 200, 9);
        assert!(vector::length(&first_status.pending_action_hash) == 2, 10);
        assert!(vector::length(&first_status.cron_spec) == 2, 11);
        assert!(first_status.last_action_ts == 1_000, 12);
        assert!(vector::length(&first_status.last_action_hash) == 1, 13);

        let second_status_opt = automation::status_option(@0x222);
        assert!(option::is_some(&second_status_opt), 14);
        let second_status = option::destroy_some(second_status_opt);
        assert!(vector::length(&second_status.allowed_actions) == 2, 15);
        assert!(*vector::borrow(&second_status.allowed_actions, 0) == 1, 16);
        assert!(*vector::borrow(&second_status.allowed_actions, 1) == 5, 17);
        assert!(second_status.reputation_score == 42, 18);
        assert!(second_status.success_streak == 15, 19);
        assert!(second_status.pending_execute_after == 400, 20);
        assert!(vector::length(&second_status.cron_spec) == 1, 21);
        assert!(vector::length(&second_status.last_action_hash) == 2, 22);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_bot(lottery_admin: &signer) {
        automation::init_registry(lottery_admin);

        let mut initial_actions = vector::empty<u64>();
        vector::push_back(&mut initial_actions, 3);

        let mut initial_cron = vector::empty<u8>();
        vector::push_back(&mut initial_cron, 60);

        automation::import_existing_bot(
            lottery_admin,
            automation::LegacyAutomationBot {
                operator: @0x333,
                allowed_actions: initial_actions,
                timelock_secs: 30,
                max_failures: 2,
                failure_count: 1,
                success_streak: 0,
                reputation_score: 5,
                pending_action_hash: vector::empty<u8>(),
                pending_execute_after: 100,
                expires_at: 5_000,
                cron_spec: initial_cron,
                last_action_ts: 500,
                last_action_hash: vector::empty<u8>(),
            },
        );

        let mut updated_actions = vector::empty<u64>();
        vector::push_back(&mut updated_actions, 7);
        vector::push_back(&mut updated_actions, 9);

        let mut updated_cron = vector::empty<u8>();
        vector::push_back(&mut updated_cron, 15);
        vector::push_back(&mut updated_cron, 45);

        let mut updated_hash = vector::empty<u8>();
        vector::push_back(&mut updated_hash, 99);

        automation::import_existing_bot(
            lottery_admin,
            automation::LegacyAutomationBot {
                operator: @0x333,
                allowed_actions: updated_actions,
                timelock_secs: 45,
                max_failures: 4,
                failure_count: 0,
                success_streak: 11,
                reputation_score: 77,
                pending_action_hash: updated_hash,
                pending_execute_after: 222,
                expires_at: 6_000,
                cron_spec: updated_cron,
                last_action_ts: 900,
                last_action_hash: vector::empty<u8>(),
            },
        );

        let status_opt = automation::status_option(@0x333);
        assert!(option::is_some(&status_opt), 23);
        let status = option::destroy_some(status_opt);
        assert!(vector::length(&status.allowed_actions) == 2, 24);
        assert!(*vector::borrow(&status.allowed_actions, 0) == 7, 25);
        assert!(*vector::borrow(&status.allowed_actions, 1) == 9, 26);
        assert!(status.timelock_secs == 45, 27);
        assert!(status.max_failures == 4, 28);
        assert!(status.success_streak == 11, 29);
        assert!(status.reputation_score == 77, 30);
        assert!(status.pending_execute_after == 222, 31);
        assert!(status.expires_at == 6_000, 32);
        assert!(vector::length(&status.cron_spec) == 2, 33);

        let snapshot_opt = automation::registry_snapshot();
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(vector::length(&snapshot.bots) == 1, 34);
        let stored = *vector::borrow(&snapshot.bots, 0);
        assert!(stored.operator == @0x333, 35);
        assert!(stored.max_failures == 4, 36);
    }
}
