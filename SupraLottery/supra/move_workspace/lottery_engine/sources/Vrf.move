module lottery_engine::vrf {
    use std::option;
    use std::signer;

    use lottery_data::vrf_deposit;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_INVALID_MULTIPLIER: u64 = 2;
    const E_AMOUNT_OVERFLOW: u64 = 3;
    const E_REQUESTS_PAUSED: u64 = 4;

    const MIN_MULTIPLIER_BPS: u64 = 10_000;
    const BPS_DENOMINATOR: u128 = 10_000;
    const U64_MAX: u128 = 18446744073709551615;

    public entry fun init_deposit(
        caller: &signer,
        min_balance_multiplier_bps: u64,
        effective_floor: u64,
    ) {
        validate_multiplier(min_balance_multiplier_bps);
        validate_effective_floor(effective_floor);
        lottery_data::vrf_deposit::init_ledger(caller, min_balance_multiplier_bps, effective_floor);
    }

    public entry fun update_config(
        caller: &signer,
        min_balance_multiplier_bps: u64,
        effective_floor: u64,
    ) acquires vrf_deposit::VrfDepositLedger {
        validate_multiplier(min_balance_multiplier_bps);
        validate_effective_floor(effective_floor);

        let ledger = ensure_admin_mut(caller);
        ledger.config.min_balance_multiplier_bps = min_balance_multiplier_bps;
        ledger.config.effective_floor = effective_floor;
    }

    public entry fun record_snapshot_admin(
        caller: &signer,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires vrf_deposit::VrfDepositLedger {
        let ledger = ensure_admin_mut(caller);
        record_snapshot_internal(
            ledger,
            total_balance,
            minimum_balance,
            effective_balance,
            timestamp,
        );
    }

    public entry fun resume_requests(caller: &signer, timestamp: u64) acquires vrf_deposit::VrfDepositLedger {
        let ledger = ensure_admin_mut(caller);
        if (!ledger.status.requests_paused) {
            return;
        };
        ledger.status.requests_paused = false;
        ledger.status.paused_since_ts = 0;
        vrf_deposit::emit_resumed(ledger, timestamp);
    }

    public fun record_snapshot(
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires vrf_deposit::VrfDepositLedger {
        let ledger = vrf_deposit::ledger_mut(@lottery);
        record_snapshot_internal(
            ledger,
            total_balance,
            minimum_balance,
            effective_balance,
            timestamp,
        );
    }

    public fun ensure_requests_allowed() acquires vrf_deposit::VrfDepositLedger {
        if (!exists<vrf_deposit::VrfDepositLedger>(@lottery)) {
            return;
        };
        let ledger = vrf_deposit::ledger(@lottery);
        if (ledger.status.requests_paused) {
            abort E_REQUESTS_PAUSED;
        };
    }

    public fun status(): vrf_deposit::VrfDepositStatus acquires vrf_deposit::VrfDepositLedger {
        if (!exists<vrf_deposit::VrfDepositLedger>(@lottery)) {
            return vrf_deposit::VrfDepositStatus {
                total_balance: 0,
                minimum_balance: 0,
                effective_balance: 0,
                required_minimum: 0,
                last_update_ts: 0,
                requests_paused: false,
                paused_since_ts: 0,
            };
        };
        let ledger = vrf_deposit::ledger(@lottery);
        ledger.status
    }

    public fun is_initialized(): bool {
        vrf_deposit::is_initialized()
    }

    public fun ledger_snapshot(): option::Option<vrf_deposit::VrfDepositSnapshot>
    acquires vrf_deposit::VrfDepositLedger {
        vrf_deposit::ledger_snapshot()
    }

    fun ensure_admin_mut(caller: &signer): &mut vrf_deposit::VrfDepositLedger acquires vrf_deposit::VrfDepositLedger {
        let caller_addr = signer::address_of(caller);
        let ledger = vrf_deposit::ledger_mut(@lottery);
        assert!(caller_addr == ledger.admin, E_UNAUTHORIZED_ADMIN);
        ledger
    }

    fun record_snapshot_internal(
        ledger: &mut vrf_deposit::VrfDepositLedger,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        timestamp: u64,
    ) acquires vrf_deposit::VrfDepositLedger {
        let required_minimum = compute_required_minimum(minimum_balance, ledger.config.min_balance_multiplier_bps);
        let was_paused = ledger.status.requests_paused;
        let should_pause = should_pause_requests(effective_balance, ledger.config.effective_floor, required_minimum);

        ledger.status.total_balance = total_balance;
        ledger.status.minimum_balance = minimum_balance;
        ledger.status.effective_balance = effective_balance;
        ledger.status.required_minimum = required_minimum;
        ledger.status.last_update_ts = timestamp;

        vrf_deposit::emit_snapshot(
            ledger,
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            ledger.config.effective_floor,
            timestamp,
        );

        if (should_pause) {
            ledger.status.requests_paused = true;
            if (!was_paused) {
                ledger.status.paused_since_ts = timestamp;
                vrf_deposit::emit_paused(ledger, timestamp);
            };
            vrf_deposit::emit_alert(
                ledger,
                total_balance,
                minimum_balance,
                effective_balance,
                required_minimum,
                ledger.config.effective_floor,
                timestamp,
            );
            return;
        };

        if (was_paused) {
            ledger.status.requests_paused = false;
            ledger.status.paused_since_ts = 0;
            vrf_deposit::emit_resumed(ledger, timestamp);
        };
    }

    fun should_pause_requests(
        effective_balance: u64,
        effective_floor: u64,
        required_minimum: u64,
    ): bool {
        if (effective_floor > 0 && effective_balance < effective_floor) {
            return true;
        };
        if (required_minimum > 0 && effective_balance < required_minimum) {
            return true;
        };
        false
    }

    fun compute_required_minimum(minimum_balance: u64, multiplier_bps: u64): u64 {
        if (minimum_balance == 0) {
            return 0;
        };
        let numerator = (minimum_balance as u128) * (multiplier_bps as u128);
        let required = numerator / BPS_DENOMINATOR;
        assert!(required <= U64_MAX, E_AMOUNT_OVERFLOW);
        required as u64
    }

    fun validate_multiplier(multiplier: u64) {
        assert!(multiplier >= MIN_MULTIPLIER_BPS, E_INVALID_MULTIPLIER);
    }

    fun validate_effective_floor(_value: u64) {
    }
}
