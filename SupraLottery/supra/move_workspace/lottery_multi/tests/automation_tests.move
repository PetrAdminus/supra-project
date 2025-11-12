module lottery_multi::automation_tests {
    use std::signer;
    use std::vector;

    use lottery_multi::automation;
    use lottery_multi::errors;

    const ACTION_RETRY: u64 = automation::ACTION_RETRY_VRF;

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_PENDING_REQUIRED)]
    fun record_success_requires_pending(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 30, 3, 1_000);
        let cap = borrow_cap(operator);
        automation::record_success(operator, cap, ACTION_RETRY, hash(1), 120);
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_PENDING_EXISTS)]
    fun dry_run_blocks_duplicate_pending(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 30, 3, 1_000);
        let cap = borrow_cap(operator);
        let hash_a = hash(2);
        automation::announce_dry_run(operator, cap, ACTION_RETRY, hash_a, 100, 140);
        let hash_b = hash(3);
        automation::announce_dry_run(operator, cap, ACTION_RETRY, hash_b, 110, 150);
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_FAILURE_LIMIT)]
    fun record_failure_enforces_limit(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 0, 2, 1_000);
        let cap = borrow_cap(operator);
        automation::record_failure(operator, cap, ACTION_RETRY, hash(4), 100, 10);
        automation::record_failure(operator, cap, ACTION_RETRY, hash(5), 200, 11);
        automation::record_failure(operator, cap, ACTION_RETRY, hash(6), 300, 12);
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_FAILURE_LIMIT)]
    fun ensure_action_blocks_after_failure_limit(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 0, 1, 5_000);
        let cap = borrow_cap(operator);
        automation::record_failure(operator, cap, ACTION_RETRY, hash(40), 100, 20);
        automation::ensure_action(cap, ACTION_RETRY, 200);
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    fun record_success_resets_failure_limit(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 0, 1, 5_000);
        let cap = borrow_cap(operator);
        automation::record_failure(operator, cap, ACTION_RETRY, hash(50), 100, 30);
        automation::record_success(operator, cap, ACTION_RETRY, hash(50), 200);
        automation::ensure_action(cap, ACTION_RETRY, 201);
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    fun success_clears_pending_and_allows_new_dry_run(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 20, 3, 1_000);
        let cap = borrow_cap(operator);
        let first = hash(7);
        let first_announced = clone_bytes(&first);
        automation::announce_dry_run(operator, cap, ACTION_RETRY, first_announced, 50, 80);
        automation::record_success(operator, cap, ACTION_RETRY, first, 90);
        automation::announce_dry_run(operator, cap, ACTION_RETRY, hash(8), 100, 130);

    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_TIMELOCK)]
    fun register_enforces_sensitive_timelock(admin: &signer, operator: &signer) acquires automation::AutomationRegistry {
        automation::init_automation(admin);
        automation::register_bot(
            admin,
            operator,
            cron_spec(),
            single_action(automation::ACTION_PAYOUT_BATCH),
            600,
            3,
            1_000,
        );
    }

    #[test(admin = @lottery_multi, operator = @0x1)]
    #[expected_failure(abort_code = errors::E_AUTOBOT_TIMELOCK)]
    fun rotate_enforces_sensitive_timelock(admin: &signer, operator: &signer) acquires automation::AutomationRegistry, automation::AutomationCap {
        automation::init_automation(admin);
        automation::register_bot(admin, operator, cron_spec(), single_action(ACTION_RETRY), 0, 3, 1_000);
        automation::rotate_bot(
            admin,
            operator,
            cron_spec(),
            single_action(automation::ACTION_CANCEL),
            600,
            3,
            1_000,
        );
    }

    fun cron_spec(): vector<u8> {
        vector::empty<u8>()
    }

    fun single_action(action_id: u64): vector<u64> {
        let mut actions = vector::empty<u64>();
        vector::push_back(&mut actions, action_id);
        actions
    }

    fun borrow_cap(operator: &signer): &automation::AutomationCap {
        let addr = signer::address_of(operator);
        borrow_global<automation::AutomationCap>(addr)
    }

    fun hash(seed: u8): vector<u8> {
        let mut out = vector::empty<u8>();
        vector::push_back(&mut out, seed);
        out
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let mut out = vector::empty<u8>();
        let mut idx = 0;
        while (idx < len) {
            let byte = *vector::borrow(source, idx);
            vector::push_back(&mut out, byte);
            idx = idx + 1;
        };
        out
    }
}
