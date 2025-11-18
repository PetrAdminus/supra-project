module lottery_engine::automation {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::automation;
    use lottery_data::automation::{AutomationBotStatus, AutomationRegistrySnapshot};
    use vrf_hub::table;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_ACTIONS_EMPTY: u64 = 2;
    const E_MAX_FAILURES: u64 = 3;
    const E_EXPIRES_AT: u64 = 4;
    const E_ACTION_HASH_EMPTY: u64 = 5;
    const E_PENDING_EXISTS: u64 = 6;
    const E_PENDING_REQUIRED: u64 = 7;
    const E_PENDING_MISMATCH: u64 = 8;
    const E_TIMELOCK: u64 = 9;
    const E_NOT_REGISTERED: u64 = 10;
    const E_ACTION_FORBIDDEN: u64 = 11;
    const E_FAILURE_LIMIT: u64 = 12;
    const E_OPERATOR_MISMATCH: u64 = 13;

    const ACTION_AUTO_CLOSE: u64 = 1;
    const ACTION_RETRY_VRF: u64 = 2;
    const ACTION_DEFRAGMENT_INDEX: u64 = 3;
    const ACTION_TOPUP_VRF_DEPOSIT: u64 = 4;
    const ACTION_UNPAUSE: u64 = 5;
    const ACTION_PAYOUT_BATCH: u64 = 6;
    const ACTION_CANCEL: u64 = 7;

    const MIN_SENSITIVE_TIMELOCK_SECS: u64 = 900;

    public entry fun init_registry(admin: &signer) {
        automation::init_registry(admin);
    }

    #[view]
    public fun is_initialized(): bool {
        automation::is_initialized()
    }

    public entry fun register_bot(
        admin: &signer,
        operator: &signer,
        cron_spec: vector<u8>,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery, E_UNAUTHORIZED_ADMIN);
        assert!(vector::length(&allowed_actions) > 0, E_ACTIONS_EMPTY);
        assert!(max_failures > 0, E_MAX_FAILURES);
        assert!(expires_at > 0, E_EXPIRES_AT);
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let registry = automation::borrow_registry_mut(@lottery);
        let operator_addr = signer::address_of(operator);
        let cron_for_state = copy cron_spec;
        let cron_for_event = copy cron_spec;
        let state = automation::AutomationState {
            allowed_actions: copy allowed_actions,
            timelock_secs,
            max_failures,
            failure_count: 0,
            success_streak: 0,
            reputation_score: 0,
            pending_action_hash: vector::empty<u8>(),
            pending_execute_after: 0,
            expires_at,
            cron_spec: cron_for_state,
            last_action_ts: 0,
            last_action_hash: vector::empty<u8>(),
        };
        automation::add_bot(registry, operator_addr, state);
        automation::publish_cap(operator, cron_spec);
        automation::emit_registered(
            registry,
            operator_addr,
            &allowed_actions,
            timelock_secs,
            max_failures,
            expires_at,
            &cron_for_event,
        );
    }

    public entry fun rotate_bot(
        admin: &signer,
        operator: address,
        cron_spec: vector<u8>,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery, E_UNAUTHORIZED_ADMIN);
        assert!(vector::length(&allowed_actions) > 0, E_ACTIONS_EMPTY);
        assert!(max_failures > 0, E_MAX_FAILURES);
        assert!(expires_at > 0, E_EXPIRES_AT);
        {
            let cap_ref = automation::cap(operator);
            assert!(automation_cap_operator(cap_ref) == operator, E_NOT_REGISTERED);
        };
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let registry = automation::borrow_registry_mut(@lottery);
        let state = automation::bot_mut(registry, operator);
        let cron_for_state = copy cron_spec;
        let cron_for_cap = copy cron_spec;
        let cron_for_event = copy cron_spec;
        state.allowed_actions = copy allowed_actions;
        state.timelock_secs = timelock_secs;
        state.max_failures = max_failures;
        state.expires_at = expires_at;
        state.cron_spec = cron_for_state;
        if (vector::length(&state.pending_action_hash) > 0) {
            state.pending_action_hash = vector::empty<u8>();
            state.pending_execute_after = 0;
        };
        state.last_action_hash = vector::empty<u8>();

        automation::update_cap(operator, cron_for_cap);
        automation::emit_rotated(
            registry,
            operator,
            &allowed_actions,
            timelock_secs,
            max_failures,
            expires_at,
            &cron_for_event,
        );
    }

    public entry fun remove_bot(
        admin: &signer,
        operator: address,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery, E_UNAUTHORIZED_ADMIN);

        let registry = automation::borrow_registry_mut(@lottery);
        automation::remove_bot(registry, operator);
        if (exists<automation::AutomationCap>(operator)) {
            automation::remove_cap(operator);
        };
        automation::emit_removed(registry, operator);
    }

    public entry fun announce_dry_run(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        executes_after_ts: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        ensure_action_hash(&action_hash);
        let operator_addr = signer::address_of(operator);
        let cap = automation::cap(operator_addr);
        ensure_cap_match(operator_addr, cap);

        let registry = automation::borrow_registry_mut(@lottery);
        let state = automation::bot_mut(registry, operator_addr);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.timelock_secs > 0, E_TIMELOCK);
        assert!(vector::length(&state.pending_action_hash) == 0, E_PENDING_EXISTS);
        let min_execute = safe_add(now_ts, state.timelock_secs, E_TIMELOCK);
        assert!(executes_after_ts >= min_execute, E_TIMELOCK);

        let event_hash = copy action_hash;
        automation::emit_dry_run(registry, operator_addr, action_id, &event_hash, executes_after_ts);
        state.pending_action_hash = action_hash;
        state.pending_execute_after = executes_after_ts;
    }

    public entry fun record_success(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        handle_completion(operator, action_id, action_hash, now_ts, true, 0);
    }

    public entry fun record_failure(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        handle_completion(operator, action_id, action_hash, now_ts, false, error_code);
    }

    public entry fun report_call_rejected(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        ensure_action_hash(&action_hash);
        let operator_addr = signer::address_of(operator);
        let cap = automation::cap(operator_addr);
        ensure_cap_match(operator_addr, cap);

        let registry = automation::borrow_registry_mut(@lottery);
        automation::emit_rejected(registry, operator_addr, action_id, &action_hash, reason_code);
    }

    #[view]
    public fun bot_status(operator: address): option::Option<AutomationBotStatus> acquires automation::AutomationRegistry {
        automation::status_option(operator)
    }

    #[view]
    public fun operators(): vector<address> acquires automation::AutomationRegistry {
        automation::operators()
    }

    #[view]
    public fun registry_snapshot(): option::Option<AutomationRegistrySnapshot> acquires automation::AutomationRegistry {
        automation::registry_snapshot()
    }

    public fun ensure_action(
        cap: &automation::AutomationCap,
        action_id: u64,
        now_ts: u64,
    ) acquires automation::AutomationRegistry {
        let registry = automation::borrow_registry(@lottery);
        if (!table::contains(&registry.bots, cap.operator)) {
            abort E_NOT_REGISTERED
        };
        let state = automation::bot(registry, cap.operator);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.failure_count < state.max_failures, E_FAILURE_LIMIT);
    }

    public fun ensure_action_with_timelock(
        cap: &automation::AutomationCap,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
    ) acquires automation::AutomationRegistry {
        ensure_action(cap, action_id, now_ts);
        let registry = automation::borrow_registry(@lottery);
        let state = automation::bot(registry, cap.operator);
        ensure_timelock(state, action_hash, now_ts);
    }

    public fun automation_status(operator: address): automation::AutomationBotStatus acquires automation::AutomationRegistry {
        let registry = automation::borrow_registry(@lottery);
        automation::status_for(registry, operator)
    }

    public fun automation_status_option(
        operator: address,
    ): option::Option<automation::AutomationBotStatus> acquires automation::AutomationRegistry {
        automation::status_option(operator)
    }

    public fun automation_operators(): vector<address> acquires automation::AutomationRegistry {
        automation::operators()
    }

    public fun automation_cap_operator(cap: &automation::AutomationCap): address {
        cap.operator
    }

    public fun automation_cap_cron_spec(cap: &automation::AutomationCap): vector<u8> {
        automation::clone_bytes(&cap.cron_spec)
    }

    fun handle_completion(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        success: bool,
        error_code: u64,
    ) acquires automation::AutomationRegistry, automation::AutomationCap {
        ensure_action_hash(&action_hash);
        let operator_addr = signer::address_of(operator);
        let cap = automation::cap(operator_addr);
        ensure_cap_match(operator_addr, cap);

        let registry = automation::borrow_registry_mut(@lottery);
        let state = automation::bot_mut(registry, operator_addr);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        ensure_timelock(state, &action_hash, now_ts);

        state.last_action_ts = now_ts;
        state.last_action_hash = copy action_hash;
        state.pending_action_hash = vector::empty<u8>();
        state.pending_execute_after = 0;
        if (success) {
            state.failure_count = 0;
            state.success_streak = state.success_streak + 1;
            state.reputation_score = state.reputation_score + 1;
        } else {
            state.success_streak = 0;
            state.reputation_score = decrement_if_possible(state.reputation_score);
            let next_failures = state.failure_count + 1;
            assert!(next_failures <= state.max_failures, E_FAILURE_LIMIT);
            state.failure_count = next_failures;
        };

        automation::emit_tick(
            registry,
            operator_addr,
            action_id,
            &action_hash,
            now_ts,
            success,
            state.failure_count,
            state.success_streak,
            state.reputation_score,
        );

        if (!success) {
            automation::emit_error(registry, operator_addr, action_id, &action_hash, now_ts, error_code);
        };
    }

    fun ensure_cap_match(operator_addr: address, cap: &automation::AutomationCap) {
        assert!(operator_addr == cap.operator, E_OPERATOR_MISMATCH);
    }

    fun ensure_action_hash(hash: &vector<u8>) {
        assert!(vector::length(hash) > 0, E_ACTION_HASH_EMPTY);
    }

    fun ensure_not_expired(state: &automation::AutomationState, now_ts: u64) {
        assert!(now_ts <= state.expires_at, E_EXPIRES_AT);
        assert!(state.failure_count < state.max_failures, E_FAILURE_LIMIT);
    }

    fun ensure_action_allowed(actions: &vector<u64>, action_id: u64) {
        let len = vector::length(actions);
        ensure_action_allowed_at(actions, action_id, 0, len);
    }

    fun ensure_action_allowed_at(
        actions: &vector<u64>,
        action_id: u64,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            abort E_ACTION_FORBIDDEN
        };
        let current = *vector::borrow(actions, index);
        if (current == action_id) {
            return;
        };
        let next = index + 1;
        ensure_action_allowed_at(actions, action_id, next, len);
    }

    fun ensure_timelock(
        state: &automation::AutomationState,
        action_hash: &vector<u8>,
        now_ts: u64,
    ) {
        if (state.timelock_secs == 0) {
            return;
        };
        let pending_len = vector::length(&state.pending_action_hash);
        assert!(pending_len > 0, E_PENDING_REQUIRED);
        assert!(bytes_equal(&state.pending_action_hash, action_hash), E_PENDING_MISMATCH);
        assert!(now_ts >= state.pending_execute_after, E_TIMELOCK);
    }

    fun assert_timelock_policy(allowed_actions: &vector<u64>, timelock_secs: u64) {
        let len = vector::length(allowed_actions);
        let requires = actions_require_timelock(allowed_actions, 0, len);
        if (requires) {
            assert!(timelock_secs >= MIN_SENSITIVE_TIMELOCK_SECS, E_TIMELOCK);
        };
    }

    fun actions_require_timelock(
        allowed_actions: &vector<u64>,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            return false;
        };
        let action_id = *vector::borrow(allowed_actions, index);
        if (action_requires_timelock(action_id)) {
            return true;
        };
        let next = index + 1;
        actions_require_timelock(allowed_actions, next, len)
    }

    fun action_requires_timelock(action_id: u64): bool {
        action_id == ACTION_UNPAUSE || action_id == ACTION_PAYOUT_BATCH || action_id == ACTION_CANCEL
    }

    fun bytes_equal(left: &vector<u8>, right: &vector<u8>): bool {
        let left_len = vector::length(left);
        if (left_len != vector::length(right)) {
            return false;
        };
        bytes_equal_at(left, right, 0, left_len)
    }

    fun bytes_equal_at(
        left: &vector<u8>,
        right: &vector<u8>,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            return true;
        };
        let left_byte = *vector::borrow(left, index);
        let right_byte = *vector::borrow(right, index);
        if (left_byte != right_byte) {
            return false;
        };
        let next = index + 1;
        bytes_equal_at(left, right, next, len)
    }

    fun decrement_if_possible(value: u64): u64 {
        if (value == 0) {
            0
        } else {
            value - 1
        }
    }

    fun safe_add(left: u64, right: u64, err: u64): u64 {
        let sum = left + right;
        assert!(sum >= left, err);
        sum
    }
}
