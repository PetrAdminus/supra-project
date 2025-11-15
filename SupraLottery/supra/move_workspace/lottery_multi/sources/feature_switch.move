// sources/feature_switch.move
module lottery_multi::feature_switch {
    use std::signer;
    use std::table;

    use lottery_multi::errors;

    const FEATURE_MODE_DISABLED: u8 = 0;
    const FEATURE_MODE_ENABLED_ALL: u8 = 1;
    const FEATURE_MODE_PREMIUM_ONLY: u8 = 2;

    /// Reserved feature identifiers.
    const FEATURE_PURCHASE: u64 = 1;
    const FEATURE_CLOSE: u64 = 2;
    const FEATURE_DRAW: u64 = 3;
    const FEATURE_PAYOUT: u64 = 4;

    struct FeatureSwitchAdminCap has key {}

    struct FeatureRecord has store {
        mode: u8,
    }

    struct FeatureSwitchRegistry has key {
        force_enable_devnet: bool,
        entries: table::Table<u64, FeatureRecord>,
    }

    public entry fun init_feature_switch(admin: &signer, force_enable_devnet: bool) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(!exists<FeatureSwitchRegistry>(addr), errors::err_already_initialized());
        assert!(!exists<FeatureSwitchAdminCap>(addr), errors::err_already_initialized());
        let registry = FeatureSwitchRegistry {
            force_enable_devnet,
            entries: table::new(),
        };
        move_to(admin, registry);
        move_to(admin, FeatureSwitchAdminCap {});
    }

    public entry fun set_mode(
        admin: &signer,
        feature_id: u64,
        mode: u8,
    ) acquires FeatureSwitchRegistry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::err_registry_missing());
        assert!(is_mode_supported(mode), errors::err_feature_mode_invalid());
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<FeatureSwitchRegistry>(registry_addr);
        if (table::contains(&registry.entries, feature_id)) {
            let record = table::borrow_mut(&mut registry.entries, feature_id);
            record.mode = mode;
        } else {
            let record = FeatureRecord { mode };
            table::add(&mut registry.entries, feature_id, record);
        };
    }

    public fun is_enabled(feature_id: u64, has_premium: bool): bool acquires FeatureSwitchRegistry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<FeatureSwitchRegistry>(registry_addr);
        if (registry.force_enable_devnet) {
            return true
        };
        if (!table::contains(&registry.entries, feature_id)) {
            abort errors::err_feature_unknown()
        };
        let record = table::borrow(&registry.entries, feature_id);
        if (record.mode == FEATURE_MODE_DISABLED) {
            return false
        };
        if (record.mode == FEATURE_MODE_ENABLED_ALL) {
            return true
        };
        if (record.mode == FEATURE_MODE_PREMIUM_ONLY) {
            return has_premium
        };
        abort errors::err_feature_mode_invalid()
    }

    fun is_mode_supported(mode: u8): bool {
        mode == FEATURE_MODE_DISABLED
            || mode == FEATURE_MODE_ENABLED_ALL
            || mode == FEATURE_MODE_PREMIUM_ONLY
    }

    fun registry_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<FeatureSwitchRegistry>(addr)) {
            abort errors::err_registry_missing()
        };
        addr
    }

    public fun is_initialized(): bool {
        let addr = @lottery_multi;
        exists<FeatureSwitchRegistry>(addr)
    }

    //
    // Feature identifiers (Move v1 compatibility)
    //

    public fun feature_purchase_id(): u64 {
        FEATURE_PURCHASE
    }

    public fun feature_close_id(): u64 {
        FEATURE_CLOSE
    }

    public fun feature_draw_id(): u64 {
        FEATURE_DRAW
    }

    public fun feature_payout_id(): u64 {
        FEATURE_PAYOUT
    }
}

