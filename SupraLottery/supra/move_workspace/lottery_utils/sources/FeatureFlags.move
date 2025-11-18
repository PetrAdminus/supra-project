module lottery_utils::feature_flags {
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    const E_NOT_ADMIN: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_REGISTRY_MISSING: u64 = 3;
    const E_FEATURE_UNKNOWN: u64 = 4;
    const E_MODE_INVALID: u64 = 5;

    const MODE_DISABLED: u8 = 0;
    const MODE_ENABLED_ALL: u8 = 1;
    const MODE_PREMIUM_ONLY: u8 = 2;

    public struct LegacyFeatureRecord has drop, store {
        feature_id: u64,
        mode: u8,
    }

    public struct LegacyFeatureRegistry has drop, store {
        admin: address,
        force_enable_devnet: bool,
        features: vector<LegacyFeatureRecord>,
    }

    struct FeatureRecord has store {
        mode: u8,
    }

    struct FeatureRegistry has key {
        admin: address,
        force_enable_devnet: bool,
        entries: table::Table<u64, FeatureRecord>,
        updates: event::EventHandle<FeatureUpdatedEvent>,
    }

    struct FeatureUpdatedEvent has drop, store {
        feature_id: u64,
        previous_mode: option::Option<u8>,
        new_mode: u8,
    }

    struct FeatureSnapshot has copy, drop, store {
        feature_id: u64,
        mode: u8,
    }

    struct FeatureRegistrySnapshot has copy, drop, store {
        admin: address,
        force_enable_devnet: bool,
        features: vector<FeatureSnapshot>,
    }

    public entry fun init(caller: &signer, force_enable_devnet: bool) {
        let addr = signer::address_of(caller);
        assert!(addr == @lottery, E_NOT_ADMIN);
        if (exists<FeatureRegistry>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            FeatureRegistry {
                admin: addr,
                force_enable_devnet,
                entries: table::new(),
                updates: account::new_event_handle<FeatureUpdatedEvent>(caller),
            },
        );
    }

    public entry fun import_existing_feature(admin: &signer, feature: LegacyFeatureRecord)
    acquires FeatureRegistry {
        ensure_registry(admin, feature.feature_id);
        let registry = borrow_registry_mut(admin);
        apply_legacy_feature(registry, feature);
    }

    public entry fun import_existing_features(admin: &signer, mut features: vector<LegacyFeatureRecord>)
    acquires FeatureRegistry {
        ensure_registry(admin, 0);
        import_features_recursive(admin, &mut features);
    }

    public entry fun import_existing_registry(admin: &signer, payload: LegacyFeatureRegistry)
    acquires FeatureRegistry {
        let LegacyFeatureRegistry { admin: new_admin, force_enable_devnet, features } = payload;
        reset_registry(admin, new_admin, force_enable_devnet);
        import_features_from_vector(admin, &features);
    }

    public entry fun set_mode(admin: &signer, feature_id: u64, mode: u8) acquires FeatureRegistry {
        assert_mode_supported(mode);
        let registry = borrow_registry_mut(admin);
        let previous = if (table::contains(&registry.entries, feature_id)) {
            let record = table::borrow_mut(&mut registry.entries, feature_id);
            let old = record.mode;
            record.mode = mode;
            option::some(old)
        } else {
            let record = FeatureRecord { mode };
            table::add(&mut registry.entries, feature_id, record);
            option::none<u8>()
        };
        event::emit_event(&mut registry.updates, FeatureUpdatedEvent {
            feature_id,
            previous_mode: previous,
            new_mode: mode,
        });
    }

    public entry fun remove_feature(admin: &signer, feature_id: u64) acquires FeatureRegistry {
        let registry = borrow_registry_mut(admin);
        if (!table::contains(&registry.entries, feature_id)) {
            abort E_FEATURE_UNKNOWN
        };
        let record = table::remove(&mut registry.entries, feature_id);
        event::emit_event(
            &mut registry.updates,
            FeatureUpdatedEvent {
                feature_id,
                previous_mode: option::some(record.mode),
                new_mode: MODE_DISABLED,
            },
        );
    }

    public entry fun set_force_enable(admin: &signer, enable: bool) acquires FeatureRegistry {
        let registry = borrow_registry_mut(admin);
        registry.force_enable_devnet = enable;
    }

    public fun is_enabled(feature_id: u64, has_premium: bool): bool acquires FeatureRegistry {
        let registry = borrow_registry();
        if (registry.force_enable_devnet) {
            return true
        };
        if (!table::contains(&registry.entries, feature_id)) {
            abort E_FEATURE_UNKNOWN
        };
        let record = table::borrow(&registry.entries, feature_id);
        if (record.mode == MODE_DISABLED) {
            return false
        };
        if (record.mode == MODE_ENABLED_ALL) {
            return true
        };
        if (record.mode == MODE_PREMIUM_ONLY) {
            return has_premium
        };
        abort E_MODE_INVALID
    }

    public fun mode(feature_id: u64): u8 acquires FeatureRegistry {
        let registry = borrow_registry();
        if (!table::contains(&registry.entries, feature_id)) {
            abort E_FEATURE_UNKNOWN
        };
        let record = table::borrow(&registry.entries, feature_id);
        record.mode
    }

    public fun has_feature(feature_id: u64): bool acquires FeatureRegistry {
        let registry = borrow_registry();
        table::contains(&registry.entries, feature_id)
    }

    public fun is_initialized(): bool {
        exists<FeatureRegistry>(@lottery)
    }

    public fun feature_purchase_id(): u64 {
        1
    }

    public fun feature_close_id(): u64 {
        2
    }

    public fun feature_draw_id(): u64 {
        3
    }

    public fun feature_payout_id(): u64 {
        4
    }

    #[view]
    public fun registry_snapshot(): option::Option<FeatureRegistrySnapshot> {
        if (!exists<FeatureRegistry>(@lottery)) {
            return option::none<FeatureRegistrySnapshot>()
        };
        let registry = borrow_registry();
        option::some(build_snapshot(registry))
    }

    fun borrow_registry(): &FeatureRegistry {
        let addr = @lottery;
        if (!exists<FeatureRegistry>(addr)) {
            abort E_REGISTRY_MISSING
        };
        borrow_global<FeatureRegistry>(addr)
    }

    fun borrow_registry_mut(admin: &signer): &mut FeatureRegistry acquires FeatureRegistry {
        let caller = signer::address_of(admin);
        if (caller != @lottery) {
            abort E_NOT_ADMIN
        };
        let addr = @lottery;
        if (!exists<FeatureRegistry>(addr)) {
            abort E_REGISTRY_MISSING
        };
        borrow_global_mut<FeatureRegistry>(addr)
    }

    fun assert_mode_supported(mode: u8) {
        if (mode == MODE_DISABLED) {
            return
        };
        if (mode == MODE_ENABLED_ALL) {
            return
        };
        if (mode == MODE_PREMIUM_ONLY) {
            return
        };
        abort E_MODE_INVALID
    }

    fun ensure_registry(admin: &signer, sample_feature_id: u64) {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery, E_NOT_ADMIN);
        if (exists<FeatureRegistry>(@lottery)) {
            return
        };
        let initial_feature = FeatureRecord { mode: MODE_DISABLED };
        let mut entries = table::new();
        if (sample_feature_id > 0) {
            table::add(&mut entries, sample_feature_id, initial_feature);
        };
        move_to(
            admin,
            FeatureRegistry {
                admin: caller,
                force_enable_devnet: false,
                entries,
                updates: account::new_event_handle<FeatureUpdatedEvent>(admin),
            },
        );
    }

    fun reset_registry(admin: &signer, new_admin: address, force_enable_devnet: bool) acquires FeatureRegistry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery, E_NOT_ADMIN);
        if (exists<FeatureRegistry>(@lottery)) {
            let _old = move_from<FeatureRegistry>(@lottery);
        };
        move_to(
            admin,
            FeatureRegistry {
                admin: new_admin,
                force_enable_devnet,
                entries: table::new(),
                updates: account::new_event_handle<FeatureUpdatedEvent>(admin),
            },
        );
    }

    fun apply_legacy_feature(registry: &mut FeatureRegistry, feature: LegacyFeatureRecord) {
        let LegacyFeatureRecord { feature_id, mode } = feature;
        assert_mode_supported(mode);
        if (table::contains(&registry.entries, feature_id)) {
            let record = table::borrow_mut(&mut registry.entries, feature_id);
            let previous = record.mode;
            record.mode = mode;
            event::emit_event(
                &mut registry.updates,
                FeatureUpdatedEvent { feature_id, previous_mode: option::some(previous), new_mode: mode },
            );
            return
        };
        let record = FeatureRecord { mode };
        table::add(&mut registry.entries, feature_id, record);
        event::emit_event(
            &mut registry.updates,
            FeatureUpdatedEvent { feature_id, previous_mode: option::none<u8>(), new_mode: mode },
        );
    }

    fun import_features_recursive(admin: &signer, features: &mut vector<LegacyFeatureRecord>) acquires FeatureRegistry {
        let len = vector::length(features);
        if (len == 0) {
            return
        };
        let last = vector::pop_back(features);
        import_features_recursive(admin, features);
        let registry = borrow_registry_mut(admin);
        apply_legacy_feature(registry, last);
    }

    fun import_features_from_vector(admin: &signer, features: &vector<LegacyFeatureRecord>) acquires FeatureRegistry {
        let len = vector::length(features);
        let idx = 0;
        while (idx < len) {
            let feature = *vector::borrow(features, idx);
            let registry = borrow_registry_mut(admin);
            apply_legacy_feature(registry, feature);
            idx = idx + 1;
        };
    }

    fun build_snapshot(registry: &FeatureRegistry): FeatureRegistrySnapshot {
        let keys = table::keys(&registry.entries);
        let len = vector::length(&keys);
        let features = collect_feature_snapshots(&registry.entries, &keys, 0, len);
        FeatureRegistrySnapshot { admin: registry.admin, force_enable_devnet: registry.force_enable_devnet, features }
    }

    fun collect_feature_snapshots(
        entries: &table::Table<u64, FeatureRecord>,
        keys: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<FeatureSnapshot> {
        if (index >= len) {
            return vector::empty<FeatureSnapshot>()
        };
        let feature_id = *vector::borrow(keys, index);
        let record = table::borrow(entries, feature_id);
        let snapshot = FeatureSnapshot { feature_id, mode: record.mode };
        let mut current = vector::singleton(snapshot);
        let tail = collect_feature_snapshots(entries, keys, index + 1, len);
        append_feature_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_feature_snapshots(
        dst: &mut vector<FeatureSnapshot>,
        src: &vector<FeatureSnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index >= len) {
            return
        };
        let snapshot = *vector::borrow(src, index);
        vector::push_back(dst, snapshot);
        append_feature_snapshots(dst, src, index + 1);
    }
}
