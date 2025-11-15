// sources/vrf_deposit.move
module lottery_multi::vrf_deposit {
    use std::signer;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::automation;
    use lottery_multi::errors;
    use lottery_multi::history;
    use lottery_multi::math;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_INFRA: u8 = 7;

    struct VrfDepositConfig has store {
        min_balance_multiplier_bps: u64,
        effective_floor: u64,
    }

    struct VrfDepositStatus has copy, drop, store {
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        last_update_ts: u64,
        requests_paused: bool,
        paused_since_ts: u64,
    }

    struct VrfDepositLedger has key {
        config: VrfDepositConfig,
        status: VrfDepositStatus,
        snapshots: event::EventHandle<history::VrfDepositSnapshotEvent>,
        alerts: event::EventHandle<history::VrfDepositAlertEvent>,
        paused_events: event::EventHandle<history::VrfRequestsPausedEvent>,
        resumed_events: event::EventHandle<history::VrfRequestsResumedEvent>,
    }

    public entry fun init_vrf_deposit(admin: &signer, min_balance_multiplier_bps: u64, effective_floor: u64) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(!exists<VrfDepositLedger>(addr), errors::err_already_initialized());
        assert!(min_balance_multiplier_bps >= 10_000, errors::err_vrf_deposit_config());
        let config = VrfDepositConfig {
            min_balance_multiplier_bps,
            effective_floor,
        };
        let status = VrfDepositStatus {
            total_balance: 0,
            minimum_balance: 0,
            effective_balance: 0,
            required_minimum: 0,
            last_update_ts: 0,
            requests_paused: false,
            paused_since_ts: 0,
        };
        let ledger = VrfDepositLedger {
            config,
            status,
            snapshots: account::new_event_handle<history::VrfDepositSnapshotEvent>(admin),
            alerts: account::new_event_handle<history::VrfDepositAlertEvent>(admin),
            paused_events: account::new_event_handle<history::VrfRequestsPausedEvent>(admin),
            resumed_events: account::new_event_handle<history::VrfRequestsResumedEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun update_config(admin: &signer, min_balance_multiplier_bps: u64, effective_floor: u64) acquires VrfDepositLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(min_balance_multiplier_bps >= 10_000, errors::err_vrf_deposit_config());
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<VrfDepositLedger>(ledger_addr);
        ledger.config.min_balance_multiplier_bps = min_balance_multiplier_bps;
        ledger.config.effective_floor = effective_floor;
    }

    public entry fun record_snapshot_admin(
        admin: &signer,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires VrfDepositLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        record_snapshot_internal(total_balance, minimum_balance, effective_balance, timestamp);
    }

    public fun record_snapshot_automation(
        operator: &signer,
        cap: &automation::AutomationCap,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
        action_hash: vector<u8>,
    ) acquires VrfDepositLedger {
        let caller = signer::address_of(operator);
        let cap_operator = automation::automation_cap_operator(cap);
        assert!(caller == cap_operator, errors::err_autobot_caller_mismatch());
        assert!(vector::length(&action_hash) > 0, errors::err_autobot_action_hash_empty());
        automation::ensure_action_with_timelock(
            cap,
            automation::action_topup_vrf_deposit(),
            &action_hash,
            timestamp,
        );
        record_snapshot_internal(total_balance, minimum_balance, effective_balance, timestamp);
        automation::record_success_internal(
            operator,
            cap,
            automation::action_topup_vrf_deposit(),
            action_hash,
            timestamp,
        );
    }


    public entry fun resume_requests(admin: &signer, timestamp: u64) acquires VrfDepositLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<VrfDepositLedger>(ledger_addr);
        if (!ledger.status.requests_paused) {
            return
        };
        ledger.status.requests_paused = false;
        ledger.status.paused_since_ts = 0;
        let event = history::new_vrf_requests_resumed_event(timestamp);
        event::emit_event(&mut ledger.resumed_events, event);
    }

    public fun ensure_requests_allowed() acquires VrfDepositLedger {
        if (!exists<VrfDepositLedger>(@lottery_multi)) {
            return
        };
        let ledger = borrow_global<VrfDepositLedger>(@lottery_multi);
        if (ledger.status.requests_paused) {
            abort errors::err_vrf_requests_paused()
        };
    }

    public fun get_status(): VrfDepositStatus acquires VrfDepositLedger {
        if (!exists<VrfDepositLedger>(@lottery_multi)) {
            return VrfDepositStatus {
                total_balance: 0,
                minimum_balance: 0,
                effective_balance: 0,
                required_minimum: 0,
                last_update_ts: 0,
                requests_paused: false,
                paused_since_ts: 0,
            }
        };
        let ledger = borrow_global<VrfDepositLedger>(@lottery_multi);
        let status_ref = &ledger.status;
        *status_ref
    }

    fun record_snapshot_internal(
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires VrfDepositLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<VrfDepositLedger>(ledger_addr);
        let required_minimum = compute_required_minimum(minimum_balance, ledger.config.min_balance_multiplier_bps);
        let should_pause = false;
        if (effective_balance < ledger.config.effective_floor) {
            should_pause = true;
        };
        if (effective_balance < required_minimum) {
            should_pause = true;
        };

        ledger.status.total_balance = total_balance;
        ledger.status.minimum_balance = minimum_balance;
        ledger.status.effective_balance = effective_balance;
        ledger.status.required_minimum = required_minimum;
        ledger.status.last_update_ts = timestamp;

        emit_snapshot(&mut ledger.snapshots, total_balance, minimum_balance, effective_balance, required_minimum, ledger.config.effective_floor, timestamp);

        if (should_pause) {
            emit_alert(&mut ledger.alerts, total_balance, minimum_balance, effective_balance, required_minimum, ledger.config.effective_floor, timestamp);
            if (!ledger.status.requests_paused) {
                ledger.status.requests_paused = true;
                ledger.status.paused_since_ts = timestamp;
                emit_paused(&mut ledger.paused_events, timestamp);
            };
        } else if (ledger.status.requests_paused) {
            ledger.status.requests_paused = false;
            ledger.status.paused_since_ts = 0;
            emit_resumed(&mut ledger.resumed_events, timestamp);
        };
    }

    fun compute_required_minimum(minimum_balance: u64, multiplier_bps: u64): u64 {
        if (minimum_balance == 0) {
            return 0
        };
        let numerator =
            math::widen_u128_from_u64(minimum_balance) * math::widen_u128_from_u64(multiplier_bps);
        let required = numerator / 10_000;
        assert!(required <= 0xffffffffffffffffu128, errors::err_amount_overflow());
        math::checked_u64_from_u128(required, errors::err_amount_overflow())
    }

    fun emit_snapshot(
        handle: &mut event::EventHandle<history::VrfDepositSnapshotEvent>,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ) {
        let event = history::new_vrf_deposit_snapshot_event(
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        );
        event::emit_event(handle, event);
    }

    fun emit_alert(
        handle: &mut event::EventHandle<history::VrfDepositAlertEvent>,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ) {
        let event = history::new_vrf_deposit_alert_event(
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        );
        event::emit_event(handle, event);
    }

    fun emit_paused(handle: &mut event::EventHandle<history::VrfRequestsPausedEvent>, timestamp: u64) {
        let event = history::new_vrf_requests_paused_event(timestamp);
        event::emit_event(handle, event);
    }

    fun emit_resumed(handle: &mut event::EventHandle<history::VrfRequestsResumedEvent>, timestamp: u64) {
        let event = history::new_vrf_requests_resumed_event(timestamp);
        event::emit_event(handle, event);
    }

    //
    // Status helpers (Move v1 compatibility)
    //

    public fun status_total_balance(status: &VrfDepositStatus): u64 {
        status.total_balance
    }

    public fun status_minimum_balance(status: &VrfDepositStatus): u64 {
        status.minimum_balance
    }

    public fun status_effective_balance(status: &VrfDepositStatus): u64 {
        status.effective_balance
    }

    public fun status_required_minimum(status: &VrfDepositStatus): u64 {
        status.required_minimum
    }

    public fun status_last_update_ts(status: &VrfDepositStatus): u64 {
        status.last_update_ts
    }

    public fun status_requests_paused(status: &VrfDepositStatus): bool {
        status.requests_paused
    }

    public fun status_paused_since_ts(status: &VrfDepositStatus): u64 {
        status.paused_since_ts
    }

    fun ledger_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<VrfDepositLedger>(addr)) {
            abort errors::err_vrf_deposit_not_initialized()
        };
        addr
    }
}
