module std::timestamp {
    use std::signer;

    const E_NOT_AUTHORIZED: u64 = 1;

    struct TimestampState has key {
        started: bool,
        microseconds: u64,
    }

    const ADMIN: address = @0x1;

    fun borrow_state(): &TimestampState acquires TimestampState {
        if (!exists<TimestampState>(ADMIN)) {
            abort E_NOT_AUTHORIZED
        };
        borrow_global<TimestampState>(ADMIN)
    }

    fun borrow_state_mut(): &mut TimestampState acquires TimestampState {
        if (!exists<TimestampState>(ADMIN)) {
            abort E_NOT_AUTHORIZED
        };
        borrow_global_mut<TimestampState>(ADMIN)
    }

    public fun now_seconds(): u64 acquires TimestampState {
        if (!exists<TimestampState>(ADMIN)) {
            return 0
        };
        let state = borrow_state();
        if (!state.started) {
            0
        } else {
            state.microseconds / 1_000_000
        }
    }

    public fun now_microseconds(): u64 acquires TimestampState {
        if (!exists<TimestampState>(ADMIN)) {
            return 0
        };
        let state = borrow_state();
        if (!state.started) {
            0
        } else {
            state.microseconds
        }
    }

    public fun set_time_has_started_for_testing(framework: &signer) acquires TimestampState {
        assert!(signer::address_of(framework) == ADMIN, E_NOT_AUTHORIZED);
        if (!exists<TimestampState>(ADMIN)) {
            move_to(
                framework,
                TimestampState { started: true, microseconds: 0 },
            );
        } else {
            let state = borrow_state_mut();
            state.started = true;
        };
    }

    public fun set_time_microseconds_for_testing(framework: &signer, microseconds: u64) acquires TimestampState {
        assert!(signer::address_of(framework) == ADMIN, E_NOT_AUTHORIZED);
        if (!exists<TimestampState>(ADMIN)) {
            move_to(
                framework,
                TimestampState { started: true, microseconds },
            );
        } else {
            let state = borrow_state_mut();
            state.started = true;
            state.microseconds = microseconds;
        };
    }
}
