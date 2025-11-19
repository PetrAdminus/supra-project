// sources/legacy_bridge.move
module lottery_multi::legacy_bridge {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::errors;

    use lottery_support::history_bridge;

    use lottery_vrf_gateway::table;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_MIGRATION: u8 = 8;

    struct ArchiveDualWriteStartedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        expected_hash: vector<u8>,
    }

    struct ArchiveDualWriteCompletedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    struct DualWriteStatus has copy, drop, store {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hash: option::Option<vector<u8>>,
    }

    struct DualWriteControl has key {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hashes: table::Table<u64, vector<u8>>,
        started_events: event::EventHandle<ArchiveDualWriteStartedEvent>,
        completed_events: event::EventHandle<ArchiveDualWriteCompletedEvent>,
    }

    struct MirrorConfig has key, drop {}

    public entry fun init_dual_write(
        admin: &signer,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        assert!(!exists<DualWriteControl>(addr), errors::err_already_initialized());
        let control = DualWriteControl {
            enabled: true,
            abort_on_mismatch,
            abort_on_missing,
            expected_hashes: table::new(),
            started_events: account::new_event_handle<ArchiveDualWriteStartedEvent>(admin),
            completed_events: account::new_event_handle<ArchiveDualWriteCompletedEvent>(admin),
        };
        move_to(admin, control);
    }

    public entry fun enable_legacy_mirror(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        if (exists<MirrorConfig>(addr)) {
            return
        };
        move_to(admin, MirrorConfig {});
    }

    public entry fun disable_legacy_mirror(admin: &signer) acquires MirrorConfig {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        if (!exists<MirrorConfig>(addr)) {
            return
        };
        let _config = move_from<MirrorConfig>(addr);
        let _ = _config;
    }

    public entry fun update_flags(
        admin: &signer,
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
    ) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let control_addr = control_addr_or_abort();
        let control = borrow_global_mut<DualWriteControl>(control_addr);
        control.enabled = enabled;
        control.abort_on_mismatch = abort_on_mismatch;
        control.abort_on_missing = abort_on_missing;
    }

    public fun is_mirror_enabled(): bool {
        exists<MirrorConfig>(@lottery_multi)
    }

    public entry fun set_expected_hash(
        admin: &signer,
        lottery_id: u64,
        expected_hash: vector<u8>,
    ) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let control_addr = control_addr_or_abort();
        let control = borrow_global_mut<DualWriteControl>(control_addr);
        if (table::contains(&control.expected_hashes, lottery_id)) {
            table::remove(&mut control.expected_hashes, lottery_id);
        };
        let event_hash = copy expected_hash;
        table::add(&mut control.expected_hashes, lottery_id, expected_hash);
        let started = ArchiveDualWriteStartedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_MIGRATION,
            lottery_id,
            expected_hash: event_hash,
        };
        event::emit_event(&mut control.started_events, started);
    }

    public entry fun clear_expected_hash(admin: &signer, lottery_id: u64) acquires DualWriteControl {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let control_addr = control_addr_or_abort();
        let control = borrow_global_mut<DualWriteControl>(control_addr);
        if (table::contains(&control.expected_hashes, lottery_id)) {
            table::remove(&mut control.expected_hashes, lottery_id);
        };
    }

    public fun notify_summary_written(
        lottery_id: u64,
        archive_hash: &vector<u8>,
        finalized_at: u64,
    ) acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return
        };
        let control_addr = control_addr_or_abort();
        let control = borrow_global_mut<DualWriteControl>(control_addr);
        if (!control.enabled) {
            return
        };
        if (!table::contains(&control.expected_hashes, lottery_id)) {
            if (control.abort_on_missing) {
                abort errors::err_history_expected_missing()
            };
            return
        };
        let expected = table::borrow(&control.expected_hashes, lottery_id);
        let archive_hash_copy = clone_bytes(archive_hash);
        if (*expected != *archive_hash) {
            if (control.abort_on_mismatch) {
                abort errors::err_history_mismatch()
            };
            return
        };
        table::remove(&mut control.expected_hashes, lottery_id);
        let completed = ArchiveDualWriteCompletedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_MIGRATION,
            lottery_id,
            archive_hash: archive_hash_copy,
            finalized_at,
        };
        event::emit_event(&mut control.completed_events, completed);
    }

    public fun is_enabled(): bool acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return false
        };
        let control = borrow_global<DualWriteControl>(@lottery_multi);
        control.enabled
    }

    public fun dual_write_status(lottery_id: u64): DualWriteStatus acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return DualWriteStatus {
                enabled: false,
                abort_on_mismatch: false,
                abort_on_missing: false,
                expected_hash: option::none<vector<u8>>(),
            }
        };
        let control = borrow_global<DualWriteControl>(@lottery_multi);
        let expected_opt = if (table::contains(&control.expected_hashes, lottery_id)) {
            let hash_ref = table::borrow(&control.expected_hashes, lottery_id);
            option::some(clone_bytes(hash_ref))
        } else {
            option::none<vector<u8>>()
        };
        DualWriteStatus {
            enabled: control.enabled,
            abort_on_mismatch: control.abort_on_mismatch,
            abort_on_missing: control.abort_on_missing,
            expected_hash: expected_opt,
        }
    }

    public fun dual_write_flags(): DualWriteStatus acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return DualWriteStatus {
                enabled: false,
                abort_on_mismatch: false,
                abort_on_missing: false,
                expected_hash: option::none<vector<u8>>(),
            }
        };
        let control = borrow_global<DualWriteControl>(@lottery_multi);
        DualWriteStatus {
            enabled: control.enabled,
            abort_on_mismatch: control.abort_on_mismatch,
            abort_on_missing: control.abort_on_missing,
            expected_hash: option::none<vector<u8>>(),
        }
    }

    public fun has_expected_hash(lottery_id: u64): bool acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return false
        };
        let control = borrow_global<DualWriteControl>(@lottery_multi);
        table::contains(&control.expected_hashes, lottery_id)
    }

    public fun pending_expected_hashes(): vector<u64> acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return vector::empty<u64>()
        };
        let control = borrow_global<DualWriteControl>(@lottery_multi);
        table::keys(&control.expected_hashes)
    }

    public fun mirror_summary_to_legacy(
        lottery_id: u64,
        summary_bytes: &vector<u8>,
        archive_hash: &vector<u8>,
        finalized_at: u64,
    ) {
        if (!exists<MirrorConfig>(@lottery_multi)) {
            return
        };
        if (!history_bridge::is_initialized()) {
            return
        };
        let summary_copy = clone_bytes(summary_bytes);
        let hash_copy = clone_bytes(archive_hash);
        history_bridge::record_summary(lottery_id, summary_copy, hash_copy, finalized_at);
    }

    fun control_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<DualWriteControl>(addr)) {
            abort errors::err_history_control_missing()
        };
        addr
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let result = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(source, i);
            vector::push_back(&mut result, byte);
            i = i + 1;
        };
        result
    }

    public fun dual_write_status_enabled(status: &DualWriteStatus): bool {
        status.enabled
    }

    public fun dual_write_status_has_expected_hash(status: &DualWriteStatus): bool {
        option::is_some(&status.expected_hash)
    }
}

