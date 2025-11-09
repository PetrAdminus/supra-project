// sources/legacy_bridge.move
module lottery_multi::legacy_bridge {
    use std::signer;
    use std::vector;

    use lottery_multi::errors;

    use vrf_hub::table;

    struct DualWriteControl has key {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hashes: table::Table<u64, vector<u8>>,
    }

    public entry fun init_dual_write(
        admin: &signer,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        assert!(!exists<DualWriteControl>(addr), errors::E_ALREADY_INITIALIZED);
        let control = DualWriteControl {
            enabled: true,
            abort_on_mismatch,
            abort_on_missing,
            expected_hashes: table::new(),
        };
        move_to(admin, control);
    }

    public entry fun update_flags(
        admin: &signer,
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let control = borrow_control_mut();
        control.enabled = enabled;
        control.abort_on_mismatch = abort_on_mismatch;
        control.abort_on_missing = abort_on_missing;
    }

    public entry fun set_expected_hash(
        admin: &signer,
        lottery_id: u64,
        expected_hash: vector<u8>,
    ) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let control = borrow_control_mut();
        if (table::contains(&control.expected_hashes, lottery_id)) {
            table::remove(&mut control.expected_hashes, lottery_id);
        };
        table::add(&mut control.expected_hashes, lottery_id, expected_hash);
    }

    public entry fun clear_expected_hash(admin: &signer, lottery_id: u64) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let control = borrow_control_mut();
        if (table::contains(&control.expected_hashes, lottery_id)) {
            table::remove(&mut control.expected_hashes, lottery_id);
        };
    }

    public fun enforce_dual_write(lottery_id: u64, archive_hash: &vector<u8>) acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return;
        };
        let control = borrow_control();
        if (!control.enabled) {
            return;
        };
        if (!table::contains(&control.expected_hashes, lottery_id)) {
            if (control.abort_on_missing) {
                abort errors::E_HISTORY_EXPECTED_MISSING;
            };
            return;
        };
        let expected = table::borrow(&control.expected_hashes, lottery_id);
        if (*expected != *archive_hash && control.abort_on_mismatch) {
            abort errors::E_HISTORY_MISMATCH;
        };
    }

    public fun is_enabled(): bool acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return false;
        };
        let control = borrow_control();
        control.enabled
    }

    fun borrow_control_mut(): &mut DualWriteControl acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            abort errors::E_HISTORY_CONTROL_MISSING;
        };
        borrow_global_mut<DualWriteControl>(@lottery_multi)
    }

    fun borrow_control(): &DualWriteControl acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            abort errors::E_HISTORY_CONTROL_MISSING;
        };
        borrow_global<DualWriteControl>(@lottery_multi)
    }
}

