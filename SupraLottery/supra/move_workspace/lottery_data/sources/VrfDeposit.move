module lottery_data::vrf_deposit {
    use std::signer;

    use supra_framework::account;
    use supra_framework::event;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;

    struct VrfDepositConfig has copy, drop, store {
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

    #[event]
    struct VrfDepositSnapshotEvent has drop, store, copy {
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    }

    #[event]
    struct VrfDepositAlertEvent has drop, store, copy {
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    }

    #[event]
    struct VrfRequestsPausedEvent has drop, store, copy {
        timestamp: u64,
    }

    #[event]
    struct VrfRequestsResumedEvent has drop, store, copy {
        timestamp: u64,
    }

    struct VrfDepositLedger has key {
        admin: address,
        config: VrfDepositConfig,
        status: VrfDepositStatus,
        snapshot_events: event::EventHandle<VrfDepositSnapshotEvent>,
        alert_events: event::EventHandle<VrfDepositAlertEvent>,
        paused_events: event::EventHandle<VrfRequestsPausedEvent>,
        resumed_events: event::EventHandle<VrfRequestsResumedEvent>,
    }

    public entry fun init_ledger(
        caller: &signer,
        min_balance_multiplier_bps: u64,
        effective_floor: u64,
    ) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<VrfDepositLedger>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            VrfDepositLedger {
                admin: caller_address,
                config: VrfDepositConfig {
                    min_balance_multiplier_bps,
                    effective_floor,
                },
                status: VrfDepositStatus {
                    total_balance: 0,
                    minimum_balance: 0,
                    effective_balance: 0,
                    required_minimum: 0,
                    last_update_ts: 0,
                    requests_paused: false,
                    paused_since_ts: 0,
                },
                snapshot_events: account::new_event_handle<VrfDepositSnapshotEvent>(caller),
                alert_events: account::new_event_handle<VrfDepositAlertEvent>(caller),
                paused_events: account::new_event_handle<VrfRequestsPausedEvent>(caller),
                resumed_events: account::new_event_handle<VrfRequestsResumedEvent>(caller),
            },
        );
    }

    public fun ledger(addr: address): &VrfDepositLedger acquires VrfDepositLedger {
        assert!(exists<VrfDepositLedger>(addr), E_NOT_PUBLISHED);
        borrow_global<VrfDepositLedger>(addr)
    }

    public fun ledger_mut(addr: address): &mut VrfDepositLedger acquires VrfDepositLedger {
        assert!(exists<VrfDepositLedger>(addr), E_NOT_PUBLISHED);
        borrow_global_mut<VrfDepositLedger>(addr)
    }

    public fun emit_snapshot(
        ledger: &mut VrfDepositLedger,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ) acquires VrfDepositLedger {
        event::emit_event(
            &mut ledger.snapshot_events,
            VrfDepositSnapshotEvent {
                total_balance,
                minimum_balance,
                effective_balance,
                required_minimum,
                effective_floor,
                timestamp,
            },
        );
    }

    public fun emit_alert(
        ledger: &mut VrfDepositLedger,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ) acquires VrfDepositLedger {
        event::emit_event(
            &mut ledger.alert_events,
            VrfDepositAlertEvent {
                total_balance,
                minimum_balance,
                effective_balance,
                required_minimum,
                effective_floor,
                timestamp,
            },
        );
    }

    public fun emit_paused(ledger: &mut VrfDepositLedger, timestamp: u64) acquires VrfDepositLedger {
        event::emit_event(
            &mut ledger.paused_events,
            VrfRequestsPausedEvent { timestamp },
        );
    }

    public fun emit_resumed(ledger: &mut VrfDepositLedger, timestamp: u64) acquires VrfDepositLedger {
        event::emit_event(
            &mut ledger.resumed_events,
            VrfRequestsResumedEvent { timestamp },
        );
    }
}
