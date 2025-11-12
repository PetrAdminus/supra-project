// sources/automation.move
module lottery_multi::automation {
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;
    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::history;

    use vrf_hub::table;

    const EVENT_VERSION_V1: u16 = history::EVENT_VERSION_V1;
    const EVENT_CATEGORY_AUTOMATION: u8 = history::EVENT_CATEGORY_AUTOMATION;

    pub const ACTION_AUTO_CLOSE: u64 = 1;
    pub const ACTION_RETRY_VRF: u64 = 2;
    pub const ACTION_DEFRAGMENT_INDEX: u64 = 3;
    pub const ACTION_TOPUP_VRF_DEPOSIT: u64 = 4;
    pub const ACTION_UNPAUSE: u64 = 5;
    pub const ACTION_PAYOUT_BATCH: u64 = 6;
    pub const ACTION_CANCEL: u64 = 7;

    /// Минимальный таймлок (15 минут) для чувствительных действий automation.
    pub const MIN_SENSITIVE_TIMELOCK_SECS: u64 = 900;

    pub struct AutomationCap has store {
        pub operator: address,
        pub cron_spec: vector<u8>,
    }

    struct AutomationState has store {
        allowed_actions: vector<u64>,
        max_failures: u64,
        failure_count: u64,
        success_streak: u64,
        reputation_score: u64,
        timelock_secs: u64,
        pending_action_hash: vector<u8>,
        pending_execute_after: u64,
        expires_at: u64,
        cron_spec: vector<u8>,
        last_action_ts: u64,
        last_action_hash: vector<u8>,
    }

    struct AutomationRegistry has key {
        bots: table::Table<address, AutomationState>,
        dry_run_events: event::EventHandle<history::AutomationDryRunPlannedEvent>,
        call_rejected_events: event::EventHandle<history::AutomationCallRejectedEvent>,
        key_rotated_events: event::EventHandle<history::AutomationKeyRotatedEvent>,
        tick_events: event::EventHandle<history::AutomationTickEvent>,
        error_events: event::EventHandle<history::AutomationErrorEvent>,
    }

    pub struct AutomationBotStatus has drop, store {
        pub operator: address,
        pub allowed_actions: vector<u64>,
        pub timelock_secs: u64,
        pub max_failures: u64,
        pub failure_count: u64,
        pub success_streak: u64,
        pub reputation_score: u64,
        pub pending_action_hash: vector<u8>,
        pub pending_execute_after: u64,
        pub expires_at: u64,
        pub cron_spec: vector<u8>,
        pub last_action_ts: u64,
        pub last_action_hash: vector<u8>,
    }

    public entry fun init_automation(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_AUTOBOT_REGISTRY_MISSING);
        assert!(!exists<AutomationRegistry>(addr), errors::E_ALREADY_INITIALIZED);
        let registry = AutomationRegistry {
            bots: table::new(),
            dry_run_events: event::new_event_handle<history::AutomationDryRunPlannedEvent>(admin),
            call_rejected_events: event::new_event_handle<history::AutomationCallRejectedEvent>(admin),
            key_rotated_events: event::new_event_handle<history::AutomationKeyRotatedEvent>(admin),
            tick_events: event::new_event_handle<history::AutomationTickEvent>(admin),
            error_events: event::new_event_handle<history::AutomationErrorEvent>(admin),
        };
        move_to(admin, registry);
    }

    public entry fun register_bot(
        admin: &signer,
        operator: &signer,
        cron_spec: vector<u8>,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
    ) acquires AutomationRegistry {
        assert!(signer::address_of(admin) == @lottery_multi, errors::E_AUTOBOT_REGISTRY_MISSING);
        assert!(vector::length(&allowed_actions) > 0, errors::E_AUTOBOT_FORBIDDEN_TARGET);
        assert!(max_failures > 0, errors::E_AUTOBOT_FAILURE_LIMIT);
        assert!(expires_at > 0, errors::E_AUTOBOT_EXPIRED);
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let operator_addr = signer::address_of(operator);
        assert!(!exists<AutomationCap>(operator_addr), errors::E_AUTOBOT_ALREADY_REGISTERED);

        let registry = borrow_registry_mut();
        assert!(!table::contains(&registry.bots, operator_addr), errors::E_AUTOBOT_ALREADY_REGISTERED);

        let state = AutomationState {
            allowed_actions: copy allowed_actions,
            max_failures,
            failure_count: 0,
            success_streak: 0,
            reputation_score: 0,
            timelock_secs,
            pending_action_hash: vector::empty<u8>(),
            pending_execute_after: 0,
            expires_at,
            cron_spec: copy cron_spec,
            last_action_ts: 0,
            last_action_hash: vector::empty<u8>(),
        };
        table::add(&mut registry.bots, operator_addr, state);

        let cap = AutomationCap { operator: operator_addr, cron_spec: copy cron_spec };
        move_to(operator, cap);

        emit_key_rotated(&mut registry.key_rotated_events, operator_addr, &cron_spec, expires_at);
    }

    public entry fun rotate_bot(
        admin: &signer,
        operator: &signer,
        cron_spec: vector<u8>,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
    ) acquires AutomationRegistry, AutomationCap {
        assert!(signer::address_of(admin) == @lottery_multi, errors::E_AUTOBOT_REGISTRY_MISSING);
        assert!(vector::length(&allowed_actions) > 0, errors::E_AUTOBOT_FORBIDDEN_TARGET);
        assert!(max_failures > 0, errors::E_AUTOBOT_FAILURE_LIMIT);
        assert!(expires_at > 0, errors::E_AUTOBOT_EXPIRED);
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let operator_addr = signer::address_of(operator);
        let registry = borrow_registry_mut();
        {
            let state = borrow_state_mut_internal(&mut registry.bots, operator_addr);
            state.allowed_actions = copy allowed_actions;
            state.timelock_secs = timelock_secs;
            state.max_failures = max_failures;
            state.expires_at = expires_at;
            state.cron_spec = copy cron_spec;
            if (vector::length(&state.pending_action_hash) > 0) {
                state.pending_action_hash = vector::empty<u8>();
                state.pending_execute_after = 0;
            };
            if (vector::length(&state.last_action_hash) > 0) {
                state.last_action_hash = vector::empty<u8>();
            };
        };

        let cap_addr = operator_addr;
        assert!(exists<AutomationCap>(cap_addr), errors::E_AUTOBOT_NOT_REGISTERED);
        {
            let cap_ref = borrow_global_mut<AutomationCap>(cap_addr);
            cap_ref.cron_spec = copy cron_spec;
        };

        emit_key_rotated(&mut registry.key_rotated_events, operator_addr, &cron_spec, expires_at);
    }

    public entry fun announce_dry_run(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        executes_after_ts: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::E_AUTOBOT_ACTION_HASH_EMPTY);

        let registry = borrow_registry_mut();
        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            ensure_not_expired(state, now_ts);
            ensure_action_allowed(&state.allowed_actions, action_id);
            if (state.timelock_secs == 0) {
                abort errors::E_AUTOBOT_TIMELOCK;
            };
            assert!(vector::length(&state.pending_action_hash) == 0, errors::E_AUTOBOT_PENDING_EXISTS);
            let min_exec = now_ts + state.timelock_secs;
            assert!(executes_after_ts >= min_exec, errors::E_AUTOBOT_TIMELOCK);
        };

        let event_hash = clone_bytes(&action_hash);
        let event = history::AutomationDryRunPlannedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator: cap.operator,
            action_id,
            action_hash: event_hash,
            executes_after_ts,
        };
        event::emit_event(&mut registry.dry_run_events, event);

        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            state.pending_action_hash = action_hash;
            state.pending_execute_after = executes_after_ts;
        };
    }

    public entry fun record_success(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::E_AUTOBOT_ACTION_HASH_EMPTY);
        let registry = borrow_registry_mut();
        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            ensure_not_expired(state, now_ts);
            ensure_action_allowed(&state.allowed_actions, action_id);
            ensure_timelock(state, &action_hash, now_ts);
            state.failure_count = 0;
            state.success_streak = state.success_streak + 1;
            state.reputation_score = state.reputation_score + 1;
            state.last_action_ts = now_ts;
            state.pending_action_hash = vector::empty<u8>();
            state.pending_execute_after = 0;
            emit_tick(&mut registry.tick_events, cap.operator, action_id, &action_hash, now_ts, true, state);
            state.last_action_hash = action_hash;
        }
    }

    public entry fun record_failure(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::E_AUTOBOT_ACTION_HASH_EMPTY);
        let registry = borrow_registry_mut();
        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            ensure_not_expired(state, now_ts);
            ensure_action_allowed(&state.allowed_actions, action_id);
            ensure_timelock(state, &action_hash, now_ts);
            state.last_action_ts = now_ts;
            state.pending_action_hash = vector::empty<u8>();
            state.pending_execute_after = 0;
            state.success_streak = 0;
            if (state.reputation_score > 0) {
                state.reputation_score = state.reputation_score - 1;
            };
            state.failure_count = state.failure_count + 1;
            assert!(state.failure_count <= state.max_failures, errors::E_AUTOBOT_FAILURE_LIMIT);
            emit_tick(&mut registry.tick_events, cap.operator, action_id, &action_hash, now_ts, false, state);
            emit_error(&mut registry.error_events, cap.operator, action_id, &action_hash, now_ts, error_code);
            state.last_action_hash = action_hash;
        }
    }

    public entry fun report_call_rejected(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        let registry = borrow_registry_mut();
        let event = history::AutomationCallRejectedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator: cap.operator,
            action_id,
            action_hash,
            reason_code,
        };
        event::emit_event(&mut registry.call_rejected_events, event);
    }

    public fun ensure_action(cap: &AutomationCap, action_id: u64, now_ts: u64) acquires AutomationRegistry {
        let state = borrow_state_ref(cap.operator);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.failure_count < state.max_failures, errors::E_AUTOBOT_FAILURE_LIMIT);
    }

    public fun ensure_action_with_timelock(
        cap: &AutomationCap,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry {
        let state = borrow_state_ref(cap.operator);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.failure_count < state.max_failures, errors::E_AUTOBOT_FAILURE_LIMIT);
        ensure_timelock(state, action_hash, now_ts);
    }

    fun assert_timelock_policy(allowed_actions: &vector<u64>, timelock_secs: u64) {
        let mut idx = 0;
        let len = vector::length(allowed_actions);
        let mut requires_timelock = false;
        while (idx < len) {
            let action_id = *vector::borrow(allowed_actions, idx);
            if (action_requires_timelock(action_id)) {
                requires_timelock = true;
                break;
            };
            idx = idx + 1;
        };
        if (requires_timelock) {
            assert!(timelock_secs >= MIN_SENSITIVE_TIMELOCK_SECS, errors::E_AUTOBOT_TIMELOCK);
        };
    }

    public fun automation_status(operator: address): AutomationBotStatus acquires AutomationRegistry {
        let state = borrow_state_ref(operator);
        state_to_status(operator, state)
    }

    public fun automation_status_option(
        operator: address,
    ): option::Option<AutomationBotStatus> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery_multi)) {
            return option::none<AutomationBotStatus>();
        };
        let registry = borrow_global<AutomationRegistry>(@lottery_multi);
        if (!table::contains(&registry.bots, operator)) {
            return option::none<AutomationBotStatus>();
        };
        let state = table::borrow(&registry.bots, operator);
        option::some(state_to_status(operator, state))
    }

    public fun automation_operators(): vector<address> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery_multi)) {
            return vector::empty<address>();
        };
        let registry = borrow_global<AutomationRegistry>(@lottery_multi);
        table::keys(&registry.bots)
    }

    fun emit_tick(
        handle: &mut event::EventHandle<history::AutomationTickEvent>,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
        success: bool,
        state: &AutomationState,
    ) {
        let event = history::AutomationTickEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash: clone_bytes(action_hash),
            executed_ts: now_ts,
            success,
            reputation_score: state.reputation_score,
            success_streak: state.success_streak,
            failure_count: state.failure_count,
        };
        event::emit_event(handle, event);
    }

    fun emit_error(
        handle: &mut event::EventHandle<history::AutomationErrorEvent>,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) {
        let event = history::AutomationErrorEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash: clone_bytes(action_hash),
            error_code,
            timestamp: now_ts,
        };
        event::emit_event(handle, event);
    }

    fun emit_key_rotated(
        handle: &mut event::EventHandle<history::AutomationKeyRotatedEvent>,
        operator: address,
        cron_spec: &vector<u8>,
        expires_at: u64,
    ) {
        let schedule_hash = hash::sha3_256(clone_bytes(cron_spec));
        let event = history::AutomationKeyRotatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            schedule_hash,
            expires_at,
        };
        event::emit_event(handle, event);
    }

    fun action_requires_timelock(action_id: u64): bool {
        action_id == ACTION_UNPAUSE || action_id == ACTION_PAYOUT_BATCH || action_id == ACTION_CANCEL
    }

    fun ensure_timelock(state: &AutomationState, action_hash: &vector<u8>, now_ts: u64) {
        if (state.timelock_secs == 0) {
            return;
        };
        if (vector::length(&state.pending_action_hash) == 0) {
            abort errors::E_AUTOBOT_PENDING_REQUIRED;
        };
        if (!hash_equals(action_hash, &state.pending_action_hash)) {
            abort errors::E_AUTOBOT_PENDING_MISMATCH;
        };
        assert!(now_ts >= state.pending_execute_after, errors::E_AUTOBOT_TIMELOCK);
    }

    fun hash_equals(left: &vector<u8>, right: &vector<u8>): bool {
        let left_len = vector::length(left);
        if (left_len != vector::length(right)) {
            return false;
        };
        let mut idx = 0;
        while (idx < left_len) {
            let left_byte = *vector::borrow(left, idx);
            let right_byte = *vector::borrow(right, idx);
            if (left_byte != right_byte) {
                return false;
            };
            idx = idx + 1;
        };
        true
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

    fun clone_u64s(source: &vector<u64>): vector<u64> {
        let len = vector::length(source);
        let mut out = vector::empty<u64>();
        let mut idx = 0;
        while (idx < len) {
            let value = *vector::borrow(source, idx);
            vector::push_back(&mut out, value);
            idx = idx + 1;
        };
        out
    }

    fun state_to_status(operator: address, state: &AutomationState): AutomationBotStatus {
        AutomationBotStatus {
            operator,
            allowed_actions: clone_u64s(&state.allowed_actions),
            timelock_secs: state.timelock_secs,
            max_failures: state.max_failures,
            failure_count: state.failure_count,
            success_streak: state.success_streak,
            reputation_score: state.reputation_score,
            pending_action_hash: clone_bytes(&state.pending_action_hash),
            pending_execute_after: state.pending_execute_after,
            expires_at: state.expires_at,
            cron_spec: clone_bytes(&state.cron_spec),
            last_action_ts: state.last_action_ts,
            last_action_hash: clone_bytes(&state.last_action_hash),
        }
    }

    fun ensure_action_allowed(actions: &vector<u64>, action_id: u64) {
        let len = vector::length(actions);
        let mut idx = 0;
        while (idx < len) {
            if (*vector::borrow(actions, idx) == action_id) {
                return;
            };
            idx = idx + 1;
        };
        abort errors::E_AUTOBOT_FORBIDDEN_TARGET;
    }

    fun ensure_operator_match(operator: &signer, cap: &AutomationCap) {
        let caller = signer::address_of(operator);
        assert!(caller == cap.operator, errors::E_AUTOBOT_CALLER_MISMATCH);
    }

    fun ensure_not_expired(state: &AutomationState, now_ts: u64) {
        assert!(now_ts <= state.expires_at, errors::E_AUTOBOT_EXPIRED);
        assert!(state.failure_count < state.max_failures, errors::E_AUTOBOT_FAILURE_LIMIT);
    }

    fun borrow_registry_mut(): &mut AutomationRegistry acquires AutomationRegistry {
        let addr = @lottery_multi;
        if (!exists<AutomationRegistry>(addr)) {
            abort errors::E_AUTOBOT_REGISTRY_MISSING;
        };
        borrow_global_mut<AutomationRegistry>(addr)
    }

    fun borrow_state_mut_internal(
        table_ref: &mut table::Table<address, AutomationState>,
        operator: address,
    ): &mut AutomationState {
        if (!table::contains(table_ref, operator)) {
            abort errors::E_AUTOBOT_NOT_REGISTERED;
        };
        table::borrow_mut(table_ref, operator)
    }

    fun borrow_state_ref(operator: address): &AutomationState acquires AutomationRegistry {
        let addr = @lottery_multi;
        if (!exists<AutomationRegistry>(addr)) {
            abort errors::E_AUTOBOT_REGISTRY_MISSING;
        };
        let registry = borrow_global<AutomationRegistry>(addr);
        if (!table::contains(&registry.bots, operator)) {
            abort errors::E_AUTOBOT_NOT_REGISTERED;
        };
        table::borrow(&registry.bots, operator)
    }
}
