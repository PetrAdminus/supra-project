module lottery_utils::feature_flags {
    use std::option;
    use std::signer;
    use std::table;

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
}
