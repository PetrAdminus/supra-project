module lottery_utils::price_feed {
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    use lottery_utils::math;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_PRICE: u8 = 6;

    const E_NOT_ADMIN: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_REGISTRY_MISSING: u64 = 3;
    const E_FEED_EXISTS: u64 = 4;
    const E_FEED_UNKNOWN: u64 = 5;
    const E_DECIMALS_INVALID: u64 = 6;
    const E_FALLBACK_ACTIVE: u64 = 7;
    const E_CLAMP_ACTIVE: u64 = 8;
    const E_PRICE_STALE: u64 = 9;
    const E_CLAMP_NOT_ACTIVE: u64 = 10;
    const E_INVALID_ADMIN: u64 = 11;

    const DEFAULT_VERSION: u16 = 1;

    const DEFAULT_STALENESS_WINDOW: u64 = 300;
    const DEFAULT_CLAMP_THRESHOLD_BPS: u64 = 2_000;
    const BPS_BASE: u64 = 10_000;

    struct PriceFeedRecord has store {
        asset_id: u64,
        price: u64,
        decimals: u8,
        last_updated_ts: u64,
        staleness_window: u64,
        clamp_threshold_bps: u64,
        fallback_active: bool,
        fallback_reason: u8,
        clamp_active: bool,
    }

    struct PriceFeedUpdatedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        asset_id: u64,
        price: u64,
        decimals: u8,
        updated_ts: u64,
    }

    struct PriceFeedFallbackEvent has drop, store {
        event_version: u16,
        event_category: u8,
        asset_id: u64,
        fallback_active: bool,
        reason: u8,
    }

    struct PriceFeedClampEvent has drop, store {
        event_version: u16,
        event_category: u8,
        asset_id: u64,
        old_price: u64,
        new_price: u64,
        threshold_bps: u64,
    }

    struct PriceFeedClampClearedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        asset_id: u64,
        cleared_ts: u64,
    }

    struct PriceFeedRegistrySnapshot has drop, store {
        admin: address,
        version: u16,
        feeds: vector<PriceFeedView>,
    }

    struct PriceFeedView has drop, store {
        asset_id: u64,
        price: u64,
        decimals: u8,
        last_updated_ts: u64,
        staleness_window: u64,
        clamp_threshold_bps: u64,
        fallback_active: bool,
        fallback_reason: u8,
        clamp_active: bool,
    }

    public struct LegacyPriceFeedRecord has drop, store {
        asset_id: u64,
        price: u64,
        decimals: u8,
        last_updated_ts: u64,
        staleness_window: u64,
        clamp_threshold_bps: u64,
        fallback_active: bool,
        fallback_reason: u8,
        clamp_active: bool,
    }

    public struct LegacyPriceFeedRegistry has drop, store {
        admin: address,
        version: u16,
        feeds: vector<LegacyPriceFeedRecord>,
    }

    struct PriceFeedRegistry has key {
        admin: address,
        version: u16,
        feeds: table::Table<u64, PriceFeedRecord>,
        updates: event::EventHandle<PriceFeedUpdatedEvent>,
        fallbacks: event::EventHandle<PriceFeedFallbackEvent>,
        clamps: event::EventHandle<PriceFeedClampEvent>,
        clamp_clears: event::EventHandle<PriceFeedClampClearedEvent>,
    }

    public entry fun init(admin: &signer, version: u16) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery, E_NOT_ADMIN);
        if (exists<PriceFeedRegistry>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            admin,
            PriceFeedRegistry {
                admin: addr,
                version,
                feeds: table::new(),
                updates: account::new_event_handle<PriceFeedUpdatedEvent>(admin),
                fallbacks: account::new_event_handle<PriceFeedFallbackEvent>(admin),
                clamps: account::new_event_handle<PriceFeedClampEvent>(admin),
                clamp_clears: account::new_event_handle<PriceFeedClampClearedEvent>(admin),
            },
        );
    }

    public entry fun import_existing_feed(admin: &signer, feed: LegacyPriceFeedRecord)
    acquires PriceFeedRegistry {
        ensure_registry(admin, DEFAULT_VERSION, feed.asset_id);
        let registry = borrow_registry_mut(admin);
        apply_legacy_feed(registry, feed);
    }

    public entry fun import_existing_feeds(admin: &signer, mut feeds: vector<LegacyPriceFeedRecord>)
    acquires PriceFeedRegistry {
        let sample = if (vector::length(&feeds) > 0) {
            let last = *vector::borrow(&feeds, vector::length(&feeds) - 1);
            last.asset_id
        } else {
            0
        };
        ensure_registry(admin, DEFAULT_VERSION, sample);
        import_feeds_recursive(admin, &mut feeds);
    }

    public entry fun import_existing_registry(admin: &signer, payload: LegacyPriceFeedRegistry)
    acquires PriceFeedRegistry {
        let LegacyPriceFeedRegistry { admin: new_admin, version, feeds } = payload;
        ensure_migration_signer(admin, new_admin);
        reset_registry(admin, new_admin, version);
        import_feeds_from_vector(admin, &feeds);
    }

    public entry fun register_feed(
        admin: &signer,
        asset_id: u64,
        price: u64,
        decimals: u8,
        staleness_window: option::Option<u64>,
        clamp_threshold_bps: option::Option<u64>,
        updated_ts: u64,
    ) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        assert!(decimals <= 18, E_DECIMALS_INVALID);
        if (table::contains(&registry.feeds, asset_id)) {
            abort E_FEED_EXISTS
        };
        let staleness = unwrap_or(staleness_window, DEFAULT_STALENESS_WINDOW);
        let clamp_threshold = unwrap_or(clamp_threshold_bps, DEFAULT_CLAMP_THRESHOLD_BPS);
        let record = PriceFeedRecord {
            asset_id,
            price,
            decimals,
            last_updated_ts: updated_ts,
            staleness_window: staleness,
            clamp_threshold_bps: clamp_threshold,
            fallback_active: false,
            fallback_reason: 0,
            clamp_active: false,
        };
        table::add(&mut registry.feeds, asset_id, record);
        emit_update(&mut registry.updates, asset_id, price, decimals, updated_ts);
    }

    public entry fun update_price(admin: &signer, asset_id: u64, price: u64, updated_ts: u64) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        if (check_clamp(record, price, &mut registry.clamps)) {
            return
        };
        record.price = price;
        record.last_updated_ts = updated_ts;
        record.fallback_active = false;
        record.fallback_reason = 0;
        emit_update(&mut registry.updates, asset_id, price, record.decimals, updated_ts);
    }

    public entry fun set_fallback(admin: &signer, asset_id: u64, active: bool, reason: u8) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        record.fallback_active = active;
        record.fallback_reason = reason;
        if (!active) {
            record.clamp_active = false;
        };
        emit_fallback(&mut registry.fallbacks, asset_id, active, reason);
    }

    public entry fun set_staleness_window(admin: &signer, asset_id: u64, window: u64) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        record.staleness_window = window;
    }

    public entry fun set_clamp_threshold(admin: &signer, asset_id: u64, threshold_bps: u64) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        record.clamp_threshold_bps = threshold_bps;
    }

    public entry fun clear_clamp(admin: &signer, asset_id: u64, cleared_ts: u64) acquires PriceFeedRegistry {
        let registry = borrow_registry_mut(admin);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        if (!record.clamp_active) {
            abort E_CLAMP_NOT_ACTIVE
        };
        record.clamp_active = false;
        record.last_updated_ts = cleared_ts;
        emit_clamp_cleared(&mut registry.clamp_clears, asset_id, cleared_ts);
    }

    public fun latest_price(asset_id: u64, now_ts: u64): (u64, u8) acquires PriceFeedRegistry {
        let registry = borrow_registry_ref();
        let record = borrow_record_ref(&registry.feeds, asset_id);
        assert!(!record.fallback_active, E_FALLBACK_ACTIVE);
        assert!(!record.clamp_active, E_CLAMP_ACTIVE);
        assert!(is_fresh(record, now_ts), E_PRICE_STALE);
        (record.price, record.decimals)
    }

    public fun get_price_view(asset_id: u64): PriceFeedView acquires PriceFeedRegistry {
        let registry = borrow_registry_ref();
        let record = borrow_record_ref(&registry.feeds, asset_id);
        PriceFeedView {
            asset_id,
            price: record.price,
            decimals: record.decimals,
            last_updated_ts: record.last_updated_ts,
            staleness_window: record.staleness_window,
            clamp_threshold_bps: record.clamp_threshold_bps,
            fallback_active: record.fallback_active,
            fallback_reason: record.fallback_reason,
            clamp_active: record.clamp_active,
        }
    }

    #[view]
    public fun registry_snapshot(): option::Option<PriceFeedRegistrySnapshot> {
        if (!exists<PriceFeedRegistry>(@lottery)) {
            return option::none<PriceFeedRegistrySnapshot>()
        };
        let registry = borrow_registry_ref();
        let keys = table::keys(&registry.feeds);
        let feeds = collect_feed_views(&registry.feeds, &keys, 0, vector::length(&keys));
        option::some(
            PriceFeedRegistrySnapshot { admin: registry.admin, version: registry.version, feeds },
        )
    }

    public fun is_initialized(): bool {
        exists<PriceFeedRegistry>(@lottery)
    }

    public fun registry_version(): u16 acquires PriceFeedRegistry {
        let registry = borrow_registry_ref();
        registry.version
    }

    fun borrow_registry_mut(admin: &signer): &mut PriceFeedRegistry acquires PriceFeedRegistry {
        let caller = signer::address_of(admin);
        if (caller != @lottery) {
            abort E_NOT_ADMIN
        };
        if (!exists<PriceFeedRegistry>(@lottery)) {
            abort E_REGISTRY_MISSING
        };
        borrow_global_mut<PriceFeedRegistry>(@lottery)
    }

    fun borrow_registry_ref(): &PriceFeedRegistry {
        if (!exists<PriceFeedRegistry>(@lottery)) {
            abort E_REGISTRY_MISSING
        };
        borrow_global<PriceFeedRegistry>(@lottery)
    }

    fun collect_feed_views(
        feeds: &table::Table<u64, PriceFeedRecord>,
        keys: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<PriceFeedView> {
        if (index >= len) {
            return vector::empty<PriceFeedView>()
        };
        let asset_id = *vector::borrow(keys, index);
        let feed = table::borrow(feeds, asset_id);
        let mut current = vector::singleton(build_view(asset_id, feed));
        let tail = collect_feed_views(feeds, keys, index + 1, len);
        append_feed_views(&mut current, &tail, 0);
        current
    }

    fun append_feed_views(dst: &mut vector<PriceFeedView>, src: &vector<PriceFeedView>, index: u64) {
        let len = vector::length(src);
        if (index >= len) {
            return
        };
        let item = *vector::borrow(src, index);
        vector::push_back(dst, item);
        append_feed_views(dst, src, index + 1)
    }

    fun build_view(asset_id: u64, feed: &PriceFeedRecord): PriceFeedView {
        let record = *feed;
        PriceFeedView {
            asset_id,
            price: record.price,
            decimals: record.decimals,
            last_updated_ts: record.last_updated_ts,
            staleness_window: record.staleness_window,
            clamp_threshold_bps: record.clamp_threshold_bps,
            fallback_active: record.fallback_active,
            fallback_reason: record.fallback_reason,
            clamp_active: record.clamp_active,
        }
    }

    fun borrow_record_mut(
        feeds: &mut table::Table<u64, PriceFeedRecord>,
        asset_id: u64,
    ): &mut PriceFeedRecord {
        if (!table::contains(feeds, asset_id)) {
            abort E_FEED_UNKNOWN
        };
        table::borrow_mut(feeds, asset_id)
    }

    fun borrow_record_ref(
        feeds: &table::Table<u64, PriceFeedRecord>,
        asset_id: u64,
    ): &PriceFeedRecord {
        if (!table::contains(feeds, asset_id)) {
            abort E_FEED_UNKNOWN
        };
        table::borrow(feeds, asset_id)
    }

    fun ensure_registry(admin: &signer, version: u16, sample_asset_id: u64) acquires PriceFeedRegistry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery, E_NOT_ADMIN);
        if (exists<PriceFeedRegistry>(@lottery)) {
            return
        };
        let mut feeds = table::new();
        if (sample_asset_id > 0) {
            let placeholder = PriceFeedRecord {
                asset_id: sample_asset_id,
                price: 0,
                decimals: 0,
                last_updated_ts: 0,
                staleness_window: DEFAULT_STALENESS_WINDOW,
                clamp_threshold_bps: DEFAULT_CLAMP_THRESHOLD_BPS,
                fallback_active: false,
                fallback_reason: 0,
                clamp_active: false,
            };
            table::add(&mut feeds, sample_asset_id, placeholder);
        };
        move_to(
            admin,
            PriceFeedRegistry {
                admin: caller,
                version,
                feeds,
                updates: account::new_event_handle<PriceFeedUpdatedEvent>(admin),
                fallbacks: account::new_event_handle<PriceFeedFallbackEvent>(admin),
                clamps: account::new_event_handle<PriceFeedClampEvent>(admin),
                clamp_clears: account::new_event_handle<PriceFeedClampClearedEvent>(admin),
            },
        );
    }

    fun reset_registry(admin: &signer, new_admin: address, version: u16) acquires PriceFeedRegistry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery, E_NOT_ADMIN);
        if (new_admin != @lottery) {
            abort E_INVALID_ADMIN
        };
        if (exists<PriceFeedRegistry>(@lottery)) {
            let _old = move_from<PriceFeedRegistry>(@lottery);
        };
        move_to(
            admin,
            PriceFeedRegistry {
                admin: new_admin,
                version,
                feeds: table::new(),
                updates: account::new_event_handle<PriceFeedUpdatedEvent>(admin),
                fallbacks: account::new_event_handle<PriceFeedFallbackEvent>(admin),
                clamps: account::new_event_handle<PriceFeedClampEvent>(admin),
                clamp_clears: account::new_event_handle<PriceFeedClampClearedEvent>(admin),
            },
        );
    }

    fun apply_legacy_feed(registry: &mut PriceFeedRegistry, feed: LegacyPriceFeedRecord) {
        let LegacyPriceFeedRecord {
            asset_id,
            price,
            decimals,
            last_updated_ts,
            staleness_window,
            clamp_threshold_bps,
            fallback_active,
            fallback_reason,
            clamp_active,
        } = feed;
        assert!(decimals <= 18, E_DECIMALS_INVALID);
        let had_record = table::contains(&registry.feeds, asset_id);
        let old_price = if (had_record) {
            let existing = borrow_record_mut(&mut registry.feeds, asset_id);
            let previous_price = existing.price;
            *existing = PriceFeedRecord {
                asset_id,
                price,
                decimals,
                last_updated_ts,
                staleness_window,
                clamp_threshold_bps,
                fallback_active,
                fallback_reason,
                clamp_active,
            };
            previous_price
        } else {
            let record = PriceFeedRecord {
                asset_id,
                price,
                decimals,
                last_updated_ts,
                staleness_window,
                clamp_threshold_bps,
                fallback_active,
                fallback_reason,
                clamp_active,
            };
            table::add(&mut registry.feeds, asset_id, record);
            0
        };
        emit_update(&mut registry.updates, asset_id, price, decimals, last_updated_ts);
        if (fallback_active) {
            emit_fallback(&mut registry.fallbacks, asset_id, true, fallback_reason);
        };
        if (clamp_active) {
            let previous = if (had_record) { old_price } else { price };
            emit_clamp(&mut registry.clamps, asset_id, previous, price, clamp_threshold_bps);
        } else if (had_record && old_price != price) {
            emit_clamp_cleared(&mut registry.clamp_clears, asset_id, last_updated_ts);
        };
    }

    fun import_feeds_recursive(admin: &signer, feeds: &mut vector<LegacyPriceFeedRecord>) acquires PriceFeedRegistry {
        let len = vector::length(feeds);
        if (len == 0) {
            return
        };
        let last = vector::pop_back(feeds);
        import_feeds_recursive(admin, feeds);
        let registry = borrow_registry_mut(admin);
        apply_legacy_feed(registry, last);
    }

    fun import_feeds_from_vector(admin: &signer, feeds: &vector<LegacyPriceFeedRecord>) acquires PriceFeedRegistry {
        let len = vector::length(feeds);
        let mut idx = 0;
        while (idx < len) {
            let record = *vector::borrow(feeds, idx);
            let registry = borrow_registry_mut(admin);
            apply_legacy_feed(registry, record);
            idx = idx + 1;
        };
    }

    fun ensure_migration_signer(admin: &signer, target_admin: address) {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery, E_NOT_ADMIN);
        assert!(target_admin == @lottery, E_INVALID_ADMIN);
    }

    fun unwrap_or(opt: option::Option<u64>, default: u64): u64 {
        if (option::is_some(&opt)) {
            option::destroy_some(opt)
        } else {
            option::destroy_none(opt);
            default
        }
    }

    fun check_clamp(
        record: &mut PriceFeedRecord,
        new_price: u64,
        clamp_handle: &mut event::EventHandle<PriceFeedClampEvent>,
    ): bool {
        let old_price = record.price;
        if (old_price == 0u64) {
            return false
        };
        let threshold = record.clamp_threshold_bps;
        if (threshold == 0u64) {
            return false
        };
        let diff = if (new_price > old_price) {
            new_price - old_price
        } else {
            old_price - new_price
        };
        let diff_scaled = math::widen_u128_from_u64(diff) * math::widen_u128_from_u64(BPS_BASE);
        let base = math::widen_u128_from_u64(old_price) * math::widen_u128_from_u64(threshold);
        if (diff_scaled > base) {
            record.clamp_active = true;
            emit_clamp(clamp_handle, record.asset_id, old_price, new_price, threshold);
            true
        } else {
            false
        }
    }

    fun is_fresh(record: &PriceFeedRecord, now_ts: u64): bool {
        now_ts - record.last_updated_ts <= record.staleness_window
    }

    fun emit_update(
        handle: &mut event::EventHandle<PriceFeedUpdatedEvent>,
        asset_id: u64,
        price: u64,
        decimals: u8,
        updated_ts: u64,
    ) {
        event::emit_event(handle, PriceFeedUpdatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PRICE,
            asset_id,
            price,
            decimals,
            updated_ts,
        });
    }

    fun emit_fallback(
        handle: &mut event::EventHandle<PriceFeedFallbackEvent>,
        asset_id: u64,
        active: bool,
        reason: u8,
    ) {
        event::emit_event(handle, PriceFeedFallbackEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PRICE,
            asset_id,
            fallback_active: active,
            reason,
        });
    }

    fun emit_clamp(
        handle: &mut event::EventHandle<PriceFeedClampEvent>,
        asset_id: u64,
        old_price: u64,
        new_price: u64,
        threshold_bps: u64,
    ) {
        event::emit_event(handle, PriceFeedClampEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PRICE,
            asset_id,
            old_price,
            new_price,
            threshold_bps,
        });
    }

    fun emit_clamp_cleared(
        handle: &mut event::EventHandle<PriceFeedClampClearedEvent>,
        asset_id: u64,
        cleared_ts: u64,
    ) {
        event::emit_event(handle, PriceFeedClampClearedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PRICE,
            asset_id,
            cleared_ts,
        });
    }
}
