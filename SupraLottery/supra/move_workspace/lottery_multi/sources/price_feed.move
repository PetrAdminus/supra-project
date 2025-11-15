// sources/price_feed.move
module lottery_multi::price_feed {
    use std::option;
    use std::signer;
    use std::table;

    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::math;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_PRICE: u8 = 6;

    const ASSET_SUPRA_USD: u64 = 1;
    const ASSET_USDT_USD: u64 = 2;

    const DEFAULT_STALENESS_WINDOW: u64 = 300;
    const DEFAULT_CLAMP_THRESHOLD_BPS: u64 = 2_000; // 20%

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

    //
    // Helpers (Move v1 compatibility)
    //

    public fun asset_supra_usd_id(): u64 {
        ASSET_SUPRA_USD
    }

    public fun price_view_price(view: &PriceFeedView): u64 {
        view.price
    }

    public fun price_view_decimals(view: &PriceFeedView): u8 {
        view.decimals
    }

    public fun price_view_last_updated(view: &PriceFeedView): u64 {
        view.last_updated_ts
    }

    public fun price_view_clamp_active(view: &PriceFeedView): bool {
        view.clamp_active
    }

    public fun price_view_asset_id(view: &PriceFeedView): u64 {
        view.asset_id
    }

    struct PriceFeedRegistry has key {
        version: u16,
        feeds: table::Table<u64, PriceFeedRecord>,
        updates: event::EventHandle<PriceFeedUpdatedEvent>,
        fallbacks: event::EventHandle<PriceFeedFallbackEvent>,
        clamps: event::EventHandle<PriceFeedClampEvent>,
        clamp_clears: event::EventHandle<PriceFeedClampClearedEvent>,
    }

    public entry fun init_price_feed(admin: &signer, version: u16) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(!exists<PriceFeedRegistry>(addr), errors::err_already_initialized());
        let registry = PriceFeedRegistry {
            version,
            feeds: table::new(),
            updates: account::new_event_handle<PriceFeedUpdatedEvent>(admin),
            fallbacks: account::new_event_handle<PriceFeedFallbackEvent>(admin),
            clamps: account::new_event_handle<PriceFeedClampEvent>(admin),
            clamp_clears: account::new_event_handle<PriceFeedClampClearedEvent>(admin),
        };
        move_to(admin, registry);
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
        assert_admin(admin);
        assert!(decimals <= 18, errors::err_price_decimals_invalid());
        let staleness = unwrap_or(staleness_window, DEFAULT_STALENESS_WINDOW);
        let clamp_threshold = unwrap_or(clamp_threshold_bps, DEFAULT_CLAMP_THRESHOLD_BPS);
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<PriceFeedRegistry>(registry_addr);
        assert!(!table::contains(&registry.feeds, asset_id), errors::err_price_feed_exists());
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

    public entry fun update_price(
        admin: &signer,
        asset_id: u64,
        price: u64,
        updated_ts: u64,
    ) acquires PriceFeedRegistry {
        assert_admin(admin);
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<PriceFeedRegistry>(registry_addr);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        let clamped = check_clamp(record, price, &mut registry.clamps);
        if (clamped) {
            return
        };
        record.price = price;
        record.last_updated_ts = updated_ts;
        record.fallback_active = false;
        record.fallback_reason = 0;
        emit_update(&mut registry.updates, asset_id, price, record.decimals, updated_ts);
    }

    public entry fun set_fallback(
        admin: &signer,
        asset_id: u64,
        active: bool,
        reason: u8,
    ) acquires PriceFeedRegistry {
        assert_admin(admin);
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<PriceFeedRegistry>(registry_addr);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        record.fallback_active = active;
        record.fallback_reason = reason;
        if (!active) {
            record.clamp_active = false;
        };
        emit_fallback(&mut registry.fallbacks, asset_id, active, reason);
    }

    public entry fun clear_clamp(
        admin: &signer,
        asset_id: u64,
        cleared_ts: u64,
    ) acquires PriceFeedRegistry {
        assert_admin(admin);
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<PriceFeedRegistry>(registry_addr);
        let record = borrow_record_mut(&mut registry.feeds, asset_id);
        assert!(record.clamp_active, errors::err_price_clamp_not_active());
        record.clamp_active = false;
        record.last_updated_ts = cleared_ts;
        emit_clamp_cleared(&mut registry.clamp_clears, asset_id, cleared_ts);
    }

    public fun latest_price(asset_id: u64, now_ts: u64): (u64, u8) acquires PriceFeedRegistry {
        let registry = borrow_global<PriceFeedRegistry>(@lottery_multi);
        let record = borrow_record_ref(&registry.feeds, asset_id);
        assert!(!record.fallback_active, errors::err_price_fallback_active());
        assert!(!record.clamp_active, errors::err_price_clamp_active());
        assert!(is_fresh(record, now_ts), errors::err_price_stale());
        (record.price, record.decimals)
    }

    public fun get_price_view(asset_id: u64): PriceFeedView acquires PriceFeedRegistry {
        let registry = borrow_global<PriceFeedRegistry>(@lottery_multi);
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

    public fun is_initialized(): bool {
        let addr = @lottery_multi;
        exists<PriceFeedRegistry>(addr)
    }

    fun unwrap_or(opt: option::Option<u64>, default: u64): u64 {
        let temp = opt;
        if (option::is_some(&temp)) {
            option::extract(&mut temp)
        } else {
            default
        }
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

    fun check_clamp(
        record: &mut PriceFeedRecord,
        new_price: u64,
        clamp_handle: &mut event::EventHandle<PriceFeedClampEvent>,
    ): bool {
        let old_price = record.price;
        if (old_price == 0) {
            return false
        };
        let threshold = record.clamp_threshold_bps;
        let diff = if (new_price > old_price) {
            new_price - old_price
        } else {
            old_price - new_price
        };
        let diff_scaled = math::widen_u128_from_u64(diff) * 10_000u128;
        let base =
            math::widen_u128_from_u64(old_price) * math::widen_u128_from_u64(threshold);
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

    fun registry_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<PriceFeedRegistry>(addr)) {
            abort errors::err_registry_missing()
        };
        addr
    }

    fun assert_admin(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
    }

    fun borrow_record_mut(
        feeds: &mut table::Table<u64, PriceFeedRecord>,
        asset_id: u64,
    ): &mut PriceFeedRecord {
        if (!table::contains(feeds, asset_id)) {
            abort errors::err_price_feed_not_found()
        };
        table::borrow_mut(feeds, asset_id)
    }

    fun borrow_record_ref(
        feeds: &table::Table<u64, PriceFeedRecord>,
        asset_id: u64,
    ): &PriceFeedRecord {
        if (!table::contains(feeds, asset_id)) {
            abort errors::err_price_feed_not_found()
        };
        table::borrow(feeds, asset_id)
    }
}
