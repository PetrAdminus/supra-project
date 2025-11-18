module lottery_data::automation {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_BOT_EXISTS: u64 = 3;
    const E_BOT_UNKNOWN: u64 = 4;
    const E_CAP_EXISTS: u64 = 5;
    const E_CAP_MISSING: u64 = 6;
    const E_NOT_INITIALIZED: u64 = 7;

    public struct AutomationState has store {
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

    public struct LegacyAutomationBot has drop, store {
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

    struct AutomationRegistry has key {
        admin: address,
        bots: table::Table<address, AutomationState>,
        register_events: event::EventHandle<AutomationBotRegisteredEvent>,
        rotate_events: event::EventHandle<AutomationBotRotatedEvent>,
        remove_events: event::EventHandle<AutomationBotRemovedEvent>,
        dry_run_events: event::EventHandle<AutomationActionPlannedEvent>,
        tick_events: event::EventHandle<AutomationActionTickEvent>,
        rejected_events: event::EventHandle<AutomationActionRejectedEvent>,
        error_events: event::EventHandle<AutomationErrorEvent>,
    }

    struct AutomationCap has key {
        operator: address,
        cron_spec: vector<u8>,
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

    struct AutomationRegistrySnapshot has copy, drop, store {
        admin: address,
        bots: vector<AutomationBotStatus>,
    }

    #[view]
    public fun is_initialized(): bool {
        exists<AutomationRegistry>(@lottery)
    }

    #[event]
    struct AutomationBotRegisteredEvent has drop, store, copy {
        operator: address,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
        cron_spec: vector<u8>,
    }

    #[event]
    struct AutomationBotRotatedEvent has drop, store, copy {
        operator: address,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
        cron_spec: vector<u8>,
    }

    #[event]
    struct AutomationBotRemovedEvent has drop, store, copy {
        operator: address,
    }

    #[event]
    struct AutomationActionPlannedEvent has drop, store, copy {
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        executes_after_ts: u64,
    }

    #[event]
    struct AutomationActionTickEvent has drop, store, copy {
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        timestamp: u64,
        success: bool,
        failure_count: u64,
        success_streak: u64,
        reputation_score: u64,
    }

    #[event]
    struct AutomationActionRejectedEvent has drop, store, copy {
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    }

    #[event]
    struct AutomationErrorEvent has drop, store, copy {
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        timestamp: u64,
        error_code: u64,
    }

    public entry fun init_registry(caller: &signer) {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @lottery, E_UNAUTHORIZED);
        assert!(!exists<AutomationRegistry>(caller_addr), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            AutomationRegistry {
                admin: caller_addr,
                bots: table::new<address, AutomationState>(),
                register_events: account::new_event_handle<AutomationBotRegisteredEvent>(caller),
                rotate_events: account::new_event_handle<AutomationBotRotatedEvent>(caller),
                remove_events: account::new_event_handle<AutomationBotRemovedEvent>(caller),
                dry_run_events: account::new_event_handle<AutomationActionPlannedEvent>(caller),
                tick_events: account::new_event_handle<AutomationActionTickEvent>(caller),
                rejected_events: account::new_event_handle<AutomationActionRejectedEvent>(caller),
                error_events: account::new_event_handle<AutomationErrorEvent>(caller),
            },
        );
    }

    public entry fun import_existing_bot(
        caller: &signer,
        bot: LegacyAutomationBot,
    ) acquires AutomationRegistry {
        ensure_registry_admin(caller);
        upsert_legacy_bot(bot);
    }

    public entry fun import_existing_bots(
        caller: &signer,
        bots: vector<LegacyAutomationBot>,
    ) acquires AutomationRegistry {
        ensure_registry_admin(caller);
        import_existing_bots_recursive(&bots, vector::length(&bots));
    }

    public entry fun claim_cap_from_registry(operator: &signer)
    acquires AutomationRegistry, AutomationCap {
        ensure_registry_initialized();
        let operator_addr = signer::address_of(operator);
        assert!(!exists<AutomationCap>(operator_addr), E_CAP_EXISTS);
        let registry = borrow_registry(@lottery);
        assert!(table::contains(&registry.bots, operator_addr), E_BOT_UNKNOWN);
        let bot = table::borrow(&registry.bots, operator_addr);
        let cron_spec = clone_bytes(&bot.cron_spec);
        move_to(operator, AutomationCap { operator: operator_addr, cron_spec });
    }

    #[view]
    public fun cap_exists(operator_addr: address): bool acquires AutomationCap {
        exists<AutomationCap>(operator_addr)
    }

    public fun borrow_registry(addr: address): &AutomationRegistry acquires AutomationRegistry {
        borrow_global<AutomationRegistry>(addr)
    }

    public fun borrow_registry_mut(addr: address): &mut AutomationRegistry acquires AutomationRegistry {
        borrow_global_mut<AutomationRegistry>(addr)
    }

    public fun add_bot(
        registry: &mut AutomationRegistry,
        operator: address,
        state: AutomationState,
    ) {
        assert!(!table::contains(&registry.bots, operator), E_BOT_EXISTS);
        table::add(&mut registry.bots, operator, state);
    }

    public fun bot(registry: &AutomationRegistry, operator: address): &AutomationState {
        assert!(table::contains(&registry.bots, operator), E_BOT_UNKNOWN);
        table::borrow(&registry.bots, operator)
    }

    public fun bot_mut(
        registry: &mut AutomationRegistry,
        operator: address,
    ): &mut AutomationState {
        assert!(table::contains(&registry.bots, operator), E_BOT_UNKNOWN);
        table::borrow_mut(&mut registry.bots, operator)
    }

    public fun remove_bot(
        registry: &mut AutomationRegistry,
        operator: address,
    ): AutomationState {
        assert!(table::contains(&registry.bots, operator), E_BOT_UNKNOWN);
        table::remove(&mut registry.bots, operator)
    }

    public fun emit_registered(
        registry: &mut AutomationRegistry,
        operator: address,
        allowed_actions: &vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
        cron_spec: &vector<u8>,
    ) {
        event::emit_event(
            &mut registry.register_events,
            AutomationBotRegisteredEvent {
                operator,
                allowed_actions: clone_u64s(allowed_actions),
                timelock_secs,
                max_failures,
                expires_at,
                cron_spec: clone_bytes(cron_spec),
            },
        );
    }

    public fun emit_rotated(
        registry: &mut AutomationRegistry,
        operator: address,
        allowed_actions: &vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        expires_at: u64,
        cron_spec: &vector<u8>,
    ) {
        event::emit_event(
            &mut registry.rotate_events,
            AutomationBotRotatedEvent {
                operator,
                allowed_actions: clone_u64s(allowed_actions),
                timelock_secs,
                max_failures,
                expires_at,
                cron_spec: clone_bytes(cron_spec),
            },
        );
    }

    public fun emit_removed(registry: &mut AutomationRegistry, operator: address) {
        event::emit_event(
            &mut registry.remove_events,
            AutomationBotRemovedEvent { operator },
        );
    }

    public fun emit_dry_run(
        registry: &mut AutomationRegistry,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        executes_after_ts: u64,
    ) {
        event::emit_event(
            &mut registry.dry_run_events,
            AutomationActionPlannedEvent {
                operator,
                action_id,
                action_hash: clone_bytes(action_hash),
                executes_after_ts,
            },
        );
    }

    public fun emit_tick(
        registry: &mut AutomationRegistry,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        timestamp: u64,
        success: bool,
        failure_count: u64,
        success_streak: u64,
        reputation_score: u64,
    ) {
        event::emit_event(
            &mut registry.tick_events,
            AutomationActionTickEvent {
                operator,
                action_id,
                action_hash: clone_bytes(action_hash),
                timestamp,
                success,
                failure_count,
                success_streak,
                reputation_score,
            },
        );
    }

    public fun emit_rejected(
        registry: &mut AutomationRegistry,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        reason_code: u64,
    ) {
        event::emit_event(
            &mut registry.rejected_events,
            AutomationActionRejectedEvent {
                operator,
                action_id,
                action_hash: clone_bytes(action_hash),
                reason_code,
            },
        );
    }

    public fun emit_error(
        registry: &mut AutomationRegistry,
        operator: address,
        action_id: u64,
        action_hash: &vector<u8>,
        timestamp: u64,
        error_code: u64,
    ) {
        event::emit_event(
            &mut registry.error_events,
            AutomationErrorEvent {
                operator,
                action_id,
                action_hash: clone_bytes(action_hash),
                timestamp,
                error_code,
            },
        );
    }

    public fun publish_cap(operator: &signer, cron_spec: vector<u8>) {
        let operator_addr = signer::address_of(operator);
        assert!(!exists<AutomationCap>(operator_addr), E_CAP_EXISTS);
        move_to(
            operator,
            AutomationCap { operator: operator_addr, cron_spec },
        );
    }

    public fun update_cap(operator_addr: address, cron_spec: vector<u8>) acquires AutomationCap {
        assert!(exists<AutomationCap>(operator_addr), E_CAP_MISSING);
        let cap = borrow_global_mut<AutomationCap>(operator_addr);
        cap.cron_spec = cron_spec;
    }

    public fun remove_cap(operator_addr: address) acquires AutomationCap {
        assert!(exists<AutomationCap>(operator_addr), E_CAP_MISSING);
        let AutomationCap { operator: _, cron_spec: _ } = move_from<AutomationCap>(operator_addr);
    }

    public fun cap(operator_addr: address): &AutomationCap acquires AutomationCap {
        assert!(exists<AutomationCap>(operator_addr), E_CAP_MISSING);
        borrow_global<AutomationCap>(operator_addr)
    }

    public fun cap_mut(operator_addr: address): &mut AutomationCap acquires AutomationCap {
        assert!(exists<AutomationCap>(operator_addr), E_CAP_MISSING);
        borrow_global_mut<AutomationCap>(operator_addr)
    }

    public fun status_for(registry: &AutomationRegistry, operator: address): AutomationBotStatus {
        let state = bot(registry, operator);
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

    public fun status_option(operator: address): option::Option<AutomationBotStatus> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery)) {
            return option::none<AutomationBotStatus>()
        };
        let registry = borrow_registry(@lottery);
        if (!table::contains(&registry.bots, operator)) {
            return option::none<AutomationBotStatus>()
        };
        option::some(status_for(registry, operator))
    }

    #[view]
    public fun registry_snapshot(): option::Option<AutomationRegistrySnapshot> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery)) {
            return option::none<AutomationRegistrySnapshot>()
        };
        let registry = borrow_registry(@lottery);
        let operators = table::keys(&registry.bots);
        let snapshots = collect_statuses(registry, &operators, 0, vector::length(&operators));
        let snapshot = AutomationRegistrySnapshot { admin: registry.admin, bots: snapshots };
        option::some(snapshot)
    }

    public fun operators(): vector<address> acquires AutomationRegistry {
        if (!exists<AutomationRegistry>(@lottery)) {
            return vector::empty<address>()
        };
        let registry = borrow_registry(@lottery);
        table::keys(&registry.bots)
    }

    fun import_existing_bots_recursive(
        bots: &vector<LegacyAutomationBot>,
        remaining: u64,
    ) acquires AutomationRegistry {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        import_existing_bots_recursive(bots, next_remaining);
        let bot_ref = vector::borrow(bots, next_remaining);
        let cloned = clone_legacy_bot(bot_ref);
        upsert_legacy_bot(cloned);
    }

    fun upsert_legacy_bot(bot: LegacyAutomationBot) acquires AutomationRegistry {
        ensure_registry_initialized();
        let LegacyAutomationBot {
            operator,
            allowed_actions,
            timelock_secs,
            max_failures,
            failure_count,
            success_streak,
            reputation_score,
            pending_action_hash,
            pending_execute_after,
            expires_at,
            cron_spec,
            last_action_ts,
            last_action_hash,
        } = bot;
        let registry = borrow_registry_mut(@lottery);
        let allowed_for_event = clone_u64s(&allowed_actions);
        let cron_for_event = clone_bytes(&cron_spec);
        let state = AutomationState {
            allowed_actions,
            timelock_secs,
            max_failures,
            failure_count,
            success_streak,
            reputation_score,
            pending_action_hash,
            pending_execute_after,
            expires_at,
            cron_spec,
            last_action_ts,
            last_action_hash,
        };
        if (table::contains(&registry.bots, operator)) {
            let existing = table::borrow_mut(&mut registry.bots, operator);
            *existing = state;
            emit_rotated(
                registry,
                operator,
                &allowed_for_event,
                timelock_secs,
                max_failures,
                expires_at,
                &cron_for_event,
            );
        } else {
            table::add(&mut registry.bots, operator, state);
            emit_registered(
                registry,
                operator,
                &allowed_for_event,
                timelock_secs,
                max_failures,
                expires_at,
                &cron_for_event,
            );
        };
    }

    fun ensure_registry_admin(caller: &signer) acquires AutomationRegistry {
        ensure_registry_initialized();
        let registry = borrow_registry(@lottery);
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == registry.admin, E_UNAUTHORIZED);
    }

    fun ensure_registry_initialized() {
        assert!(exists<AutomationRegistry>(@lottery), E_NOT_INITIALIZED);
    }

    fun clone_legacy_bot(bot: &LegacyAutomationBot): LegacyAutomationBot {
        LegacyAutomationBot {
            operator: bot.operator,
            allowed_actions: clone_u64s(&bot.allowed_actions),
            timelock_secs: bot.timelock_secs,
            max_failures: bot.max_failures,
            failure_count: bot.failure_count,
            success_streak: bot.success_streak,
            reputation_score: bot.reputation_score,
            pending_action_hash: clone_bytes(&bot.pending_action_hash),
            pending_execute_after: bot.pending_execute_after,
            expires_at: bot.expires_at,
            cron_spec: clone_bytes(&bot.cron_spec),
            last_action_ts: bot.last_action_ts,
            last_action_hash: clone_bytes(&bot.last_action_hash),
        }
    }

    public fun clone_bytes(source: &vector<u8>): vector<u8> {
        let result = vector::empty<u8>();
        let len = vector::length(source);
        clone_bytes_into(&mut result, source, 0, len);
        result
    }

    fun clone_bytes_into(
        buffer: &mut vector<u8>,
        source: &vector<u8>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(source, index);
        vector::push_back(buffer, byte);
        let next = index + 1;
        clone_bytes_into(buffer, source, next, len);
    }

    public fun clone_u64s(source: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        let len = vector::length(source);
        clone_u64s_into(&mut result, source, 0, len);
        result
    }

    fun clone_u64s_into(
        buffer: &mut vector<u64>,
        source: &vector<u64>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let value = *vector::borrow(source, index);
        vector::push_back(buffer, value);
        let next = index + 1;
        clone_u64s_into(buffer, source, next, len);
    }

    fun collect_statuses(
        registry: &AutomationRegistry,
        operators: &vector<address>,
        index: u64,
        len: u64,
    ): vector<AutomationBotStatus> {
        if (index >= len) {
            return vector::empty<AutomationBotStatus>()
        };
        let status = status_for(registry, *vector::borrow(operators, index));
        let result = vector::empty<AutomationBotStatus>();
        vector::push_back(&result, status);
        let tail = collect_statuses(registry, operators, index + 1, len);
        vector::append(&result, tail);
        result
    }
}
