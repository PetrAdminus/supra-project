// sources/feature_switch.move
module lottery_multi::feature_switch {
    use std::signer;
    use std::table;

    use lottery_multi::errors;

    pub const FEATURE_MODE_DISABLED: u8 = 0;
    pub const FEATURE_MODE_ENABLED_ALL: u8 = 1;
    pub const FEATURE_MODE_PREMIUM_ONLY: u8 = 2;

    /// Reserved feature identifiers.
    pub const FEATURE_PURCHASE: u64 = 1;
    pub const FEATURE_CLOSE: u64 = 2;
    pub const FEATURE_DRAW: u64 = 3;
    pub const FEATURE_PAYOUT: u64 = 4;

    pub struct FeatureSwitchAdminCap has store {}

    struct FeatureRecord has store {
        mode: u8,
    }

    struct FeatureSwitchRegistry has key {
        force_enable_devnet: bool,
        entries: table::Table<u64, FeatureRecord>,
    }

    public entry fun init_feature_switch(admin: &signer, force_enable_devnet: bool) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(!exists<FeatureSwitchRegistry>(addr), errors::E_ALREADY_INITIALIZED);
        assert!(!exists<FeatureSwitchAdminCap>(addr), errors::E_ALREADY_INITIALIZED);
        let registry = FeatureSwitchRegistry {
            force_enable_devnet,
            entries: table::new(),
        };
        move_to(admin, registry);
        move_to(admin, FeatureSwitchAdminCap {});
    }

    public entry fun set_mode(
        admin: &signer,
        _cap: &FeatureSwitchAdminCap,
        feature_id: u64,
        mode: u8,
    ) acquires FeatureSwitchRegistry {
        assert!(is_mode_supported(mode), errors::E_FEATURE_MODE_INVALID);
        let registry = borrow_registry_mut();
        if (table::contains(&registry.entries, feature_id)) {
            let record = table::borrow_mut(&mut registry.entries, feature_id);
            record.mode = mode;
        } else {
            let record = FeatureRecord { mode };
            table::add(&mut registry.entries, feature_id, record);
        };
    }

    public fun is_enabled(feature_id: u64, has_premium: bool): bool acquires FeatureSwitchRegistry {
        let registry = borrow_registry_ref();
        if (registry.force_enable_devnet) {
            return true;
        };
        if (!table::contains(&registry.entries, feature_id)) {
            abort errors::E_FEATURE_UNKNOWN;
        };
        let record = table::borrow(&registry.entries, feature_id);
        if (record.mode == FEATURE_MODE_DISABLED) {
            return false;
        };
        if (record.mode == FEATURE_MODE_ENABLED_ALL) {
            return true;
        };
        if (record.mode == FEATURE_MODE_PREMIUM_ONLY) {
            return has_premium;
        };
        abort errors::E_FEATURE_MODE_INVALID;
    }

    fun is_mode_supported(mode: u8): bool {
        mode == FEATURE_MODE_DISABLED
            || mode == FEATURE_MODE_ENABLED_ALL
            || mode == FEATURE_MODE_PREMIUM_ONLY
    }

    fun borrow_registry_mut(): &mut FeatureSwitchRegistry acquires FeatureSwitchRegistry {
        let addr = @lottery_multi;
        if (!exists<FeatureSwitchRegistry>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global_mut<FeatureSwitchRegistry>(addr)
    }

    fun borrow_registry_ref(): &FeatureSwitchRegistry acquires FeatureSwitchRegistry {
        let addr = @lottery_multi;
        if (!exists<FeatureSwitchRegistry>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global<FeatureSwitchRegistry>(addr)
    }

    public fun is_initialized(): bool {
        let addr = @lottery_multi;
        exists<FeatureSwitchRegistry>(addr)
    }
}
