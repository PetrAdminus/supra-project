// sources/automation.move
module lottery_multi::automation {
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_multi::errors;
    use lottery_multi::history;
    
    use lottery_vrf_gateway::table;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_AUTOMATION: u8 = 6;

    const ACTION_AUTO_CLOSE: u64 = 1;
    const ACTION_RETRY_VRF: u64 = 2;
    const ACTION_DEFRAGMENT_INDEX: u64 = 3;
    const ACTION_TOPUP_VRF_DEPOSIT: u64 = 4;
    const ACTION_UNPAUSE: u64 = 5;
    const ACTION_PAYOUT_BATCH: u64 = 6;
    const ACTION_CANCEL: u64 = 7;

    /// Minimum timelock (15 minutes) required before high-impact automation calls.
    const MIN_SENSITIVE_TIMELOCK_SECS: u64 = 900;

    //
    // Action helpers (Move v1 compatibility)
    //

    public fun action_auto_close(): u64 {
        ACTION_AUTO_CLOSE
    }

    public fun action_retry_vrf(): u64 {
        ACTION_RETRY_VRF
    }

    public fun action_defragment_index(): u64 {
        ACTION_DEFRAGMENT_INDEX
    }

    public fun action_topup_vrf_deposit(): u64 {
        ACTION_TOPUP_VRF_DEPOSIT
    }

    public fun action_unpause(): u64 {
        ACTION_UNPAUSE
    }

    public fun action_payout_batch(): u64 {
        ACTION_PAYOUT_BATCH
    }

    public fun action_cancel(): u64 {
        ACTION_CANCEL
    }

    struct AutomationCap has key, store {
        operator: address,
        cron_spec: vector<u8>,
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

    struct AutomationBotStatus has drop, store {
        operator: address,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        failure_count: u64,
        success_streak: u64,
        reputation_score: u64,
        pending_action_hash: vector<u8>,
        pending_execute_after: u64,
        expires_at: u64,
        cron_spec: vector<u8>,
        last_action_ts: u64,
        last_action_hash: vector<u8>,
    }

    public entry fun init_automation(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_autobot_registry_missing());
        assert!(!exists<AutomationRegistry>(addr), errors::err_already_initialized());
        let registry = AutomationRegistry {
            bots: table::new(),
            dry_run_events: account::new_event_handle<history::AutomationDryRunPlannedEvent>(admin),
            call_rejected_events: account::new_event_handle<history::AutomationCallRejectedEvent>(admin),
            key_rotated_events: account::new_event_handle<history::AutomationKeyRotatedEvent>(admin),
            tick_events: account::new_event_handle<history::AutomationTickEvent>(admin),
            error_events: account::new_event_handle<history::AutomationErrorEvent>(admin),
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
        assert!(signer::address_of(admin) == @lottery_multi, errors::err_autobot_registry_missing());
        assert!(vector::length(&allowed_actions) > 0, errors::err_autobot_forbidden_target());
        assert!(max_failures > 0, errors::err_autobot_failure_limit());
        assert!(expires_at > 0, errors::err_autobot_expired());
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let operator_addr = signer::address_of(operator);
        assert!(!exists<AutomationCap>(operator_addr), errors::err_autobot_already_registered());

        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
        assert!(!table::contains(&registry.bots, operator_addr), errors::err_autobot_already_registered());

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
        assert!(signer::address_of(admin) == @lottery_multi, errors::err_autobot_registry_missing());
        assert!(vector::length(&allowed_actions) > 0, errors::err_autobot_forbidden_target());
        assert!(max_failures > 0, errors::err_autobot_failure_limit());
        assert!(expires_at > 0, errors::err_autobot_expired());
        assert_timelock_policy(&allowed_actions, timelock_secs);

        let operator_addr = signer::address_of(operator);
        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
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
        assert!(exists<AutomationCap>(cap_addr), errors::err_autobot_not_registered());
        {
            let cap_ref = borrow_global_mut<AutomationCap>(cap_addr);
            cap_ref.cron_spec = copy cron_spec;
        };

        emit_key_rotated(&mut registry.key_rotated_events, operator_addr, &cron_spec, expires_at);
    }

    public entry fun announce_dry_run(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        executes_after_ts: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let operator_addr = signer::address_of(operator);
        assert!(exists<AutomationCap>(operator_addr), errors::err_autobot_not_registered());
        let cap = borrow_global<AutomationCap>(operator_addr);
        announce_dry_run_internal(operator, cap, action_id, action_hash, now_ts, executes_after_ts);
    }

    public fun announce_dry_run_internal(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        executes_after_ts: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::err_autobot_action_hash_empty());

        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            ensure_not_expired(state, now_ts);
            ensure_action_allowed(&state.allowed_actions, action_id);
            if (state.timelock_secs == 0) {
                abort errors::err_autobot_timelock()
            };
            assert!(vector::length(&state.pending_action_hash) == 0, errors::err_autobot_pending_exists());
            let min_exec = now_ts + state.timelock_secs;
            assert!(executes_after_ts >= min_exec, errors::err_autobot_timelock());
        };

        let event_hash = clone_bytes(&action_hash);
        let evt = history::new_automation_dry_run_planned_event(
            cap.operator,
            action_id,
            event_hash,
            executes_after_ts,
        );
        event::emit_event(&mut registry.dry_run_events, evt);

        {
            let state = borrow_state_mut_internal(&mut registry.bots, cap.operator);
            state.pending_action_hash = action_hash;
            state.pending_execute_after = executes_after_ts;
        };
    }

    public entry fun record_success(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let operator_addr = signer::address_of(operator);
        assert!(exists<AutomationCap>(operator_addr), errors::err_autobot_not_registered());
        let cap = borrow_global<AutomationCap>(operator_addr);
        record_success_internal(operator, cap, action_id, action_hash, now_ts);
    }

    public fun record_success_internal(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::err_autobot_action_hash_empty());
        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
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
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let operator_addr = signer::address_of(operator);
        assert!(exists<AutomationCap>(operator_addr), errors::err_autobot_not_registered());
        let cap = borrow_global<AutomationCap>(operator_addr);
        record_failure_internal(operator, cap, action_id, action_hash, now_ts, error_code);
    }

    public fun record_failure_internal(
        operator: &signer,
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) acquires AutomationRegistry {
        ensure_operator_match(operator, cap);
        assert!(vector::length(&action_hash) > 0, errors::err_autobot_action_hash_empty());
        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
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
            assert!(state.failure_count <= state.max_failures, errors::err_autobot_failure_limit());
            emit_tick(&mut registry.tick_events, cap.operator, action_id, &action_hash, now_ts, false, state);
            emit_error(&mut registry.error_events, cap.operator, action_id, &action_hash, now_ts, error_code);
            state.last_action_hash = action_hash;
        }
    }

    public entry fun report_call_rejected(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let operator_addr = signer::address_of(operator);
        assert!(exists<AutomationCap>(operator_addr), errors::err_autobot_not_registered());
        let cap = borrow_global<AutomationCap>(operator_addr);
        report_call_rejected_internal(cap, action_id, action_hash, reason_code);
    }

    public fun report_call_rejected_internal(
        cap: &AutomationCap,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    ) acquires AutomationRegistry {
        let addr = registry_address();
        let registry = borrow_global_mut<AutomationRegistry>(addr);
        let evt = history::new_automation_call_rejected_event(
            cap.operator,
            action_id,
            action_hash,
            reason_code,
        );
        event::emit_event(&mut registry.call_rejected_events, evt);
    }

    public fun ensure_action(cap: &AutomationCap, action_id: u64, now_ts: u64) acquires AutomationRegistry {
        let addr = registry_address();
        let registry = borrow_global<AutomationRegistry>(addr);
        if (!table::contains(&registry.bots, cap.operator)) {
            abort errors::err_autobot_not_registered()
        };
        let state = table::borrow(&registry.bots, cap.operator);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.failure_count < state.max_failures, errors::err_autobot_failure_limit());
    }

    public fun ensure_action_with_timelock(
        cap: &AutomationCap,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry {
        let addr = registry_address();
        let registry = borrow_global<AutomationRegistry>(addr);
        if (!table::contains(&registry.bots, cap.operator)) {
            abort errors::err_autobot_not_registered()
        };
        let state = table::borrow(&registry.bots, cap.operator);
        ensure_not_expired(state, now_ts);
        ensure_action_allowed(&state.allowed_actions, action_id);
        assert!(state.failure_count < state.max_failures, errors::err_autobot_failure_limit());
        ensure_timelock(state, action_hash, now_ts);
    }

    fun assert_timelock_policy(allowed_actions: &vector<u64>, timelock_secs: u64) {
        let idx = 0;
        let len = vector::length(allowed_actions);
        let requires_timelock = false;
        while (idx < len) {
            let action_id = *vector::borrow(allowed_actions, idx);
            if (action_requires_timelock(action_id)) {
                requires_timelock = true;
                break
            };
            idx = idx + 1;
        };
        if (requires_timelock) {
            assert!(timelock_secs >= MIN_SENSITIVE_TIMELOCK_SECS, errors::err_autobot_timelock());
        };
    }

    public fun automation_status(operator: address): AutomationBotStatus acquires AutomationRegistry {
        let addr = registry_address();
        let registry = borrow_global<AutomationRegistry>(addr);
        if (!table::contains(&registry.bots, operator)) {
            abort errors::err_autobot_not_registered()
        };
        let state = table::borrow(&registry.bots, operator);
        state_to_status(operator, state)
    }

    public fun automation_status_option(
        operator: address,
    ): option::Option<AutomationBotStatus> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery_multi)) {
            return option::none<AutomationBotStatus>()
        };
        let registry = borrow_global<AutomationRegistry>(@lottery_multi);
        if (!table::contains(&registry.bots, operator)) {
            return option::none<AutomationBotStatus>()
        };
        let state = table::borrow(&registry.bots, operator);
        option::some(state_to_status(operator, state))
    }

    public fun automation_operators(): vector<address> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery_multi)) {
            return vector::empty<address>()
        };
        let registry = borrow_global<AutomationRegistry>(@lottery_multi);
        table::keys(&registry.bots)
    }

    //
    // Public accessors for Move v1 (no struct/pub field)
    //

    public fun automation_cap_operator(cap: &AutomationCap): address {
        cap.operator
    }

    public fun automation_cap_cron_spec(cap: &AutomationCap): vector<u8> {
        clone_bytes(&cap.cron_spec)
    }

    fun emit_error(
        handle: &mut event::EventHandle<history::AutomationErrorEvent>,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        now_ts: u64,
        error_code: u64,
    ) {
        let evt = history::new_automation_error_event(
            operator,
            action_id,
            clone_bytes(action_hash),
            now_ts,
            error_code,
        );
        event::emit_event(handle, evt);
    }

    fun emit_key_rotated(
        handle: &mut event::EventHandle<history::AutomationKeyRotatedEvent>,
        operator: address,
        cron_spec: &vector<u8>,
        expires_at: u64,
    ) {
        let schedule_hash = hash::sha3_256(clone_bytes(cron_spec));
        let evt = history::new_automation_key_rotated_event(
            operator,
            schedule_hash,
            expires_at,
        );
        event::emit_event(handle, evt);
    }

    fun action_requires_timelock(action_id: u64): bool {
        action_id == ACTION_UNPAUSE || action_id == ACTION_PAYOUT_BATCH || action_id == ACTION_CANCEL
    }

    fun ensure_timelock(state: &AutomationState, action_hash: &vector<u8>, now_ts: u64) {
        if (state.timelock_secs == 0) {
            return
        };
        if (vector::length(&state.pending_action_hash) == 0) {
            abort errors::err_autobot_pending_required()
        };
        if (!hash_equals(action_hash, &state.pending_action_hash)) {
            abort errors::err_autobot_pending_mismatch()
        };
        assert!(now_ts >= state.pending_execute_after, errors::err_autobot_timelock());
    }

    fun hash_equals(left: &vector<u8>, right: &vector<u8>): bool {
        let left_len = vector::length(left);
        if (left_len != vector::length(right)) {
            return false
        };
        let idx = 0;
        while (idx < left_len) {
            let left_byte = *vector::borrow(left, idx);
            let right_byte = *vector::borrow(right, idx);
            if (left_byte != right_byte) {
                return false
            };
            idx = idx + 1;
        };
        true
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let out = vector::empty<u8>();
        let idx = 0;
        while (idx < len) {
            let byte = *vector::borrow(source, idx);
            vector::push_back(&mut out, byte);
            idx = idx + 1;
        };
        out
    }

    fun clone_u64s(source: &vector<u64>): vector<u64> {
        let len = vector::length(source);
        let out = vector::empty<u64>();
        let idx = 0;
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
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(actions, idx) == action_id) {
                return
            };
            idx = idx + 1;
        };
        abort errors::err_autobot_forbidden_target()
    }

    fun ensure_operator_match(operator: &signer, cap: &AutomationCap) {
        let caller = signer::address_of(operator);
        assert!(caller == cap.operator, errors::err_autobot_caller_mismatch());
    }

    fun ensure_not_expired(state: &AutomationState, now_ts: u64) {
        assert!(now_ts <= state.expires_at, errors::err_autobot_expired());
        assert!(state.failure_count < state.max_failures, errors::err_autobot_failure_limit());
    }

    fun registry_address(): address {
        let addr = @lottery_multi;
        if (!exists<AutomationRegistry>(addr)) {
            abort errors::err_autobot_registry_missing()
        };
        addr
    }

    fun borrow_state_mut_internal(
        table_ref: &mut table::Table<address, AutomationState>,
        operator: address,
    ): &mut AutomationState {
        if (!table::contains(table_ref, operator)) {
            abort errors::err_autobot_not_registered()
        };
        table::borrow_mut(table_ref, operator)
    }

    #[test_only]
    public fun ensure_action_for_test(
        operator_addr: address,
        action_id: u64,
        now_ts: u64,
    ) acquires AutomationRegistry, AutomationCap {
        assert!(exists<AutomationCap>(operator_addr), errors::err_autobot_not_registered());
        let cap = borrow_global<AutomationCap>(operator_addr);
        ensure_action(cap, action_id, now_ts);
    }

    public fun announce_dry_run_for_tests(
        operator: &signer,
        action_id: u64,
        announced: vector<u8>,
        now_ts: u64,
        execute_after: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let op = signer::address_of(operator);
        let cap = borrow_global<AutomationCap>(op);
        announce_dry_run_internal(operator, cap, action_id, announced, now_ts, execute_after);
    }

    public fun record_success_for_tests(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let op = signer::address_of(operator);
        let cap = borrow_global<AutomationCap>(op);
        record_success_internal(operator, cap, action_id, action_hash, now_ts);
    }

    public fun record_failure_for_tests(
        operator: &signer,
        action_id: u64,
        action_hash: vector<u8>,
        now_ts: u64,
        code: u64,
    ) acquires AutomationRegistry, AutomationCap {
        let op = signer::address_of(operator);
        let cap = borrow_global<AutomationCap>(op);
        record_failure_internal(operator, cap, action_id, action_hash, now_ts, code);
    }

    public fun ensure_action_for_tests(operator: &signer, action_id: u64, now_ts: u64) acquires AutomationRegistry, AutomationCap {
        let op = signer::address_of(operator);
        let cap = borrow_global<AutomationCap>(op);
        ensure_action(cap, action_id, now_ts);
    }

    public fun take_cap_for_tests(operator: &signer): AutomationCap acquires AutomationCap {
        let addr = signer::address_of(operator);
        assert!(exists<AutomationCap>(addr), errors::err_autobot_not_registered());
        move_from<AutomationCap>(addr)
    }

    public fun return_cap_for_tests(operator: &signer, cap: AutomationCap) {
        move_to(operator, cap);
    }

    

    // View accessors for AutomationBotStatus (Move v1 helpers)
    public fun bot_status_operator(status: &AutomationBotStatus): address {
        status.operator
    }

    public fun bot_status_allowed_actions(status: &AutomationBotStatus): vector<u64> {
        clone_u64s(&status.allowed_actions)
    }

    public fun bot_status_timelock_secs(status: &AutomationBotStatus): u64 {
        status.timelock_secs
    }

    public fun bot_status_max_failures(status: &AutomationBotStatus): u64 {
        status.max_failures
    }

    public fun bot_status_failure_count(status: &AutomationBotStatus): u64 {
        status.failure_count
    }

    public fun bot_status_success_streak(status: &AutomationBotStatus): u64 {
        status.success_streak
    }

    public fun bot_status_reputation_score(status: &AutomationBotStatus): u64 {
        status.reputation_score
    }

    public fun bot_status_pending_action_hash(status: &AutomationBotStatus): vector<u8> {
        clone_bytes(&status.pending_action_hash)
    }

    public fun bot_status_pending_execute_after(status: &AutomationBotStatus): u64 {
        status.pending_execute_after
    }

    public fun bot_status_expires_at(status: &AutomationBotStatus): u64 {
        status.expires_at
    }

    public fun bot_status_cron_spec(status: &AutomationBotStatus): vector<u8> {
        clone_bytes(&status.cron_spec)
    }

    public fun bot_status_last_action_ts(status: &AutomationBotStatus): u64 {
        status.last_action_ts
    }

    public fun bot_status_last_action_hash(status: &AutomationBotStatus): vector<u8> {
        clone_bytes(&status.last_action_hash)
    }

    public fun bot_status_has_pending(status: &AutomationBotStatus): bool {
        vector::length(&status.pending_action_hash) > 0
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
        let event = history::new_automation_tick_event(
            operator,
            action_id,
            clone_bytes(action_hash),
            now_ts,
            success,
            state.reputation_score,
            state.success_streak,
            state.failure_count,
        );
        event::emit_event(handle, event);
    }
}

