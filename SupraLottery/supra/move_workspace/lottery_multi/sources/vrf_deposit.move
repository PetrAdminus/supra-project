// sources/vrf_deposit.move
module lottery_multi::vrf_deposit {
    use std::signer;
    use supra_framework::event;

    use lottery_multi::automation;
    use lottery_multi::errors;
    use lottery_multi::history;

    const EVENT_VERSION_V1: u16 = history::EVENT_VERSION_V1;
    const EVENT_CATEGORY_INFRA: u8 = history::EVENT_CATEGORY_INFRA;

    pub struct VrfDepositConfig has store {
        pub min_balance_multiplier_bps: u64,
        pub effective_floor: u64,
    }

    pub struct VrfDepositStatus has copy, drop, store {
        pub total_balance: u64,
        pub minimum_balance: u64,
        pub effective_balance: u64,
        pub required_minimum: u64,
        pub last_update_ts: u64,
        pub requests_paused: bool,
        pub paused_since_ts: u64,
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
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(!exists<VrfDepositLedger>(addr), errors::E_ALREADY_INITIALIZED);
        assert!(min_balance_multiplier_bps >= 10_000, errors::E_VRF_DEPOSIT_CONFIG);
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
            snapshots: event::new_event_handle<history::VrfDepositSnapshotEvent>(admin),
            alerts: event::new_event_handle<history::VrfDepositAlertEvent>(admin),
            paused_events: event::new_event_handle<history::VrfRequestsPausedEvent>(admin),
            resumed_events: event::new_event_handle<history::VrfRequestsResumedEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun update_config(admin: &signer, min_balance_multiplier_bps: u64, effective_floor: u64) acquires VrfDepositLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(min_balance_multiplier_bps >= 10_000, errors::E_VRF_DEPOSIT_CONFIG);
        let ledger = borrow_ledger_mut();
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
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        record_snapshot_internal(total_balance, minimum_balance, effective_balance, timestamp);
    }

    public entry fun record_snapshot_automation(
        operator: &signer,
        cap: &automation::AutomationCap,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires VrfDepositLedger, automation::AutomationRegistry {
        let caller = signer::address_of(operator);
        assert!(caller == cap.operator, errors::E_AUTOBOT_CALLER_MISMATCH);
        automation::ensure_action(cap, automation::ACTION_TOPUP_VRF_DEPOSIT, timestamp);
        record_snapshot_internal(total_balance, minimum_balance, effective_balance, timestamp);
    }

    public entry fun resume_requests(admin: &signer, timestamp: u64) acquires VrfDepositLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        let ledger = borrow_ledger_mut();
        if (!ledger.status.requests_paused) {
            return;
        };
        ledger.status.requests_paused = false;
        ledger.status.paused_since_ts = 0;
        let event = history::VrfRequestsResumedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            resumed_ts: timestamp,
        };
        event::emit_event(&mut ledger.resumed_events, event);
    }

    public fun ensure_requests_allowed() acquires VrfDepositLedger {
        if (!exists<VrfDepositLedger>(@lottery_multi)) {
            return;
        };
        let ledger = borrow_global<VrfDepositLedger>(@lottery_multi);
        if (ledger.status.requests_paused) {
            abort errors::E_VRF_REQUESTS_PAUSED;
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
            };
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
        let ledger = borrow_ledger_mut();
        let required_minimum = compute_required_minimum(minimum_balance, ledger.config.min_balance_multiplier_bps);
        let mut should_pause = false;
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
            return 0;
        };
        let numerator = (minimum_balance as u128) * (multiplier_bps as u128);
        let required = numerator / 10_000;
        assert!(required <= 0xffffffffffffffffu128, errors::E_AMOUNT_OVERFLOW);
        required as u64
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
        let event = history::VrfDepositSnapshotEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        };
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
        let event = history::VrfDepositAlertEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        };
        event::emit_event(handle, event);
    }

    fun emit_paused(handle: &mut event::EventHandle<history::VrfRequestsPausedEvent>, timestamp: u64) {
        let event = history::VrfRequestsPausedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            paused_since_ts: timestamp,
        };
        event::emit_event(handle, event);
    }

    fun emit_resumed(handle: &mut event::EventHandle<history::VrfRequestsResumedEvent>, timestamp: u64) {
        let event = history::VrfRequestsResumedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            resumed_ts: timestamp,
        };
        event::emit_event(handle, event);
    }

    fun borrow_ledger_mut(): &mut VrfDepositLedger acquires VrfDepositLedger {
        let addr = @lottery_multi;
        if (!exists<VrfDepositLedger>(addr)) {
            abort errors::E_VRF_DEPOSIT_NOT_INITIALIZED;
        };
        borrow_global_mut<VrfDepositLedger>(addr)
    }
}
