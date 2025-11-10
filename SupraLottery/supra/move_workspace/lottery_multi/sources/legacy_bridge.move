// sources/legacy_bridge.move
module lottery_multi::legacy_bridge {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::history;

    use lottery_support::history_bridge;

    use vrf_hub::table;

    pub const EVENT_VERSION_V1: u16 = 1;
    pub const EVENT_CATEGORY_MIGRATION: u8 = 8;

    pub struct ArchiveDualWriteStartedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub expected_hash: vector<u8>,
    }

    pub struct ArchiveDualWriteCompletedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub archive_hash: vector<u8>,
        pub finalized_at: u64,
    }

    pub struct DualWriteStatus has copy, drop, store {
        pub enabled: bool,
        pub abort_on_mismatch: bool,
        pub abort_on_missing: bool,
        pub expected_hash: option::Option<vector<u8>>,
    }

    struct DualWriteControl has key {
        enabled: bool,
        abort_on_mismatch: bool,
        abort_on_missing: bool,
        expected_hashes: table::Table<u64, vector<u8>>,
        started_events: event::EventHandle<ArchiveDualWriteStartedEvent>,
        completed_events: event::EventHandle<ArchiveDualWriteCompletedEvent>,
    }

    struct MirrorConfig has key {}

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
            started_events: event::new_event_handle<ArchiveDualWriteStartedEvent>(admin),
            completed_events: event::new_event_handle<ArchiveDualWriteCompletedEvent>(admin),
        };
        move_to(admin, control);
    }

    public entry fun enable_legacy_mirror(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        if (exists<MirrorConfig>(addr)) {
            return;
        };
        move_to(admin, MirrorConfig {});
    }

    public entry fun disable_legacy_mirror(admin: &signer) acquires MirrorConfig {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        if (!exists<MirrorConfig>(addr)) {
            return;
        };
        let _ = move_from<MirrorConfig>(addr);
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
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let control = borrow_control_mut();
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
            return;
        };
        let control = borrow_control_mut();
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
        let archive_hash_copy = copy *archive_hash;
        if (*expected != *archive_hash) {
            if (control.abort_on_mismatch) {
                abort errors::E_HISTORY_MISMATCH;
            };
            return;
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

    public entry fun mirror_summary_admin(admin: &signer, lottery_id: u64)
    acquires history::ArchiveLedger, MirrorConfig {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        if (!exists<MirrorConfig>(addr)) {
            return;
        };
        let summary = history::get_summary(lottery_id);
        let summary_bytes = bcs::to_bytes(&summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        mirror_summary_internal(lottery_id, &summary_bytes, &archive_hash, summary.finalized_at);
    }

    public fun is_enabled(): bool acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return false;
        };
        let control = borrow_control();
        control.enabled
    }

    public fun dual_write_status(lottery_id: u64): DualWriteStatus acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return DualWriteStatus {
                enabled: false,
                abort_on_mismatch: false,
                abort_on_missing: false,
                expected_hash: option::none<vector<u8>>(),
            };
        };
        let control = borrow_control();
        let expected_opt = if (table::contains(&control.expected_hashes, lottery_id)) {
            let hash_ref = table::borrow(&control.expected_hashes, lottery_id);
            option::some(copy *hash_ref)
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
            };
        };
        let control = borrow_control();
        DualWriteStatus {
            enabled: control.enabled,
            abort_on_mismatch: control.abort_on_mismatch,
            abort_on_missing: control.abort_on_missing,
            expected_hash: option::none<vector<u8>>(),
        }
    }

    public fun has_expected_hash(lottery_id: u64): bool acquires DualWriteControl {
        if (!exists<DualWriteControl>(@lottery_multi)) {
            return false;
        };
        let control = borrow_control();
        table::contains(&control.expected_hashes, lottery_id)
    }

    public fun mirror_summary_to_legacy(
        lottery_id: u64,
        summary_bytes: &vector<u8>,
        archive_hash: &vector<u8>,
        finalized_at: u64,
    ) acquires MirrorConfig {
        if (!exists<MirrorConfig>(@lottery_multi)) {
            return;
        };
        if (!history_bridge::is_initialized()) {
            return;
        };
        let summary_copy = copy *summary_bytes;
        let hash_copy = copy *archive_hash;
        history_bridge::record_summary(lottery_id, summary_copy, hash_copy, finalized_at);
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

    fun mirror_summary_internal(
        lottery_id: u64,
        summary_bytes: &vector<u8>,
        archive_hash: &vector<u8>,
        finalized_at: u64,
    ) acquires MirrorConfig {
        mirror_summary_to_legacy(lottery_id, summary_bytes, archive_hash, finalized_at);
    }
}

