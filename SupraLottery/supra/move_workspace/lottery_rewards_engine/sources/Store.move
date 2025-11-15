module lottery_rewards_engine::store {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use lottery_data::treasury_v1;
    use lottery_utils::math;
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;
    const E_ITEM_NOT_FOUND: u64 = 5;
    const E_INVALID_STOCK: u64 = 6;
    const E_INSUFFICIENT_STOCK: u64 = 7;
    const E_INVALID_QUANTITY: u64 = 8;
    const E_PRICE_OVERFLOW: u64 = 9;
    const E_SOLD_OVERFLOW: u64 = 10;

    const SOURCE_STORE: vector<u8> = b"store";

    struct StoreItem has copy, drop, store {
        price: u64,
        metadata: vector<u8>,
        available: bool,
        stock: option::Option<u64>,
    }

    struct StoreRecord has store {
        item: StoreItem,
        sold: u64,
    }

    struct LotteryStore has store {
        items: table::Table<u64, StoreRecord>,
        item_ids: vector<u64>,
    }

    struct StoreState has key {
        admin: address,
        lotteries: table::Table<u64, LotteryStore>,
        lottery_ids: vector<u64>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        item_events: event::EventHandle<ItemConfiguredEvent>,
        purchase_events: event::EventHandle<ItemPurchasedEvent>,
        snapshot_events: event::EventHandle<StoreSnapshotUpdatedEvent>,
    }

    struct StoreAccess has key {
        cap: treasury_multi::MultiTreasuryCap,
    }

    #[event]
    struct AdminUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    #[event]
    struct ItemConfiguredEvent has drop, store, copy {
        lottery_id: u64,
        item_id: u64,
        price: u64,
        available: bool,
        stock: option::Option<u64>,
        metadata: vector<u8>,
    }

    #[event]
    struct ItemPurchasedEvent has drop, store, copy {
        lottery_id: u64,
        item_id: u64,
        buyer: address,
        quantity: u64,
        total_price: u64,
    }

    struct StoreItemSnapshot has copy, drop, store {
        item_id: u64,
        price: u64,
        available: bool,
        stock: option::Option<u64>,
        sold: u64,
        metadata: vector<u8>,
    }

    struct StoreLotterySnapshot has copy, drop, store {
        lottery_id: u64,
        items: vector<StoreItemSnapshot>,
    }

    struct StoreSnapshot has copy, drop, store {
        admin: address,
        lotteries: vector<StoreLotterySnapshot>,
    }

    #[event]
    struct StoreSnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        snapshot: StoreLotterySnapshot,
    }

    struct ItemWithStats has copy, drop, store {
        item: StoreItem,
        sold: u64,
    }

    public entry fun init(caller: &signer)
    acquires StoreAccess, StoreState, treasury_multi::TreasuryMultiControl {
        ensure_admin_signer(caller);
        if (exists<StoreState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            StoreState {
                admin: signer::address_of(caller),
                lotteries: table::new<u64, LotteryStore>(),
                lottery_ids: vector::empty<u64>(),
                admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
                item_events: account::new_event_handle<ItemConfiguredEvent>(caller),
                purchase_events: account::new_event_handle<ItemPurchasedEvent>(caller),
                snapshot_events: account::new_event_handle<StoreSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<StoreState>(@lottery);
        emit_all_snapshots(state);
        if (!exists<StoreAccess>(@lottery)) {
            ensure_caps_initialized(caller);
        };
    }

    #[view]
    public fun is_initialized(): bool {
        exists<StoreState>(@lottery)
    }

    #[view]
    public fun admin(): address acquires StoreState {
        ensure_initialized();
        let state = borrow_global<StoreState>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires StoreState {
        ensure_admin(caller);
        let state = borrow_global_mut<StoreState>(@lottery);
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
        emit_all_snapshots(state);
    }

    public entry fun upsert_item(
        caller: &signer,
        lottery_id: u64,
        item_id: u64,
        price: u64,
        metadata: vector<u8>,
        available: bool,
        stock: option::Option<u64>,
    ) acquires StoreState {
        ensure_admin(caller);
        ensure_lottery_known(lottery_id);
        if (price == 0) {
            abort E_INVALID_STOCK;
        };
        if (option::is_some(&stock) && *option::borrow(&stock) == 0) {
            abort E_INVALID_STOCK;
        };
        let stored_metadata = copy_vec_u8(&metadata);
        let event_metadata = copy_vec_u8(&metadata);
        let state = borrow_global_mut<StoreState>(@lottery);
        let store = borrow_or_add_store(state, lottery_id);
        if (table::contains(&store.items, item_id)) {
            let record = table::borrow_mut(&mut store.items, item_id);
            record.item = StoreItem { price, metadata: stored_metadata, available, stock };
        } else {
            table::add(
                &mut store.items,
                item_id,
                StoreRecord { item: StoreItem { price, metadata: stored_metadata, available, stock }, sold: 0 },
            );
            record_item_id(&mut store.item_ids, item_id);
        };
        event::emit_event(
            &mut state.item_events,
            ItemConfiguredEvent { lottery_id, item_id, price, available, stock, metadata: event_metadata },
        );
        emit_store_snapshot(state, lottery_id);
    }

    public entry fun set_availability(
        caller: &signer,
        lottery_id: u64,
        item_id: u64,
        available: bool,
    ) acquires StoreState {
        ensure_admin(caller);
        ensure_lottery_known(lottery_id);
        ensure_initialized();
        let state = borrow_global_mut<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let store = table::borrow_mut(&mut state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let record = table::borrow_mut(&mut store.items, item_id);
        record.item.available = available;
        let metadata_copy = copy_vec_u8(&record.item.metadata);
        event::emit_event(
            &mut state.item_events,
            ItemConfiguredEvent {
                lottery_id,
                item_id,
                price: record.item.price,
                available,
                stock: record.item.stock,
                metadata: metadata_copy,
            },
        );
        emit_store_snapshot(state, lottery_id);
    }

    public entry fun purchase(
        buyer: &signer,
        lottery_id: u64,
        item_id: u64,
        quantity: u64,
    ) acquires StoreAccess, StoreState, treasury_multi::TreasuryState, treasury_v1::TokenState {
        if (quantity == 0) {
            abort E_INVALID_QUANTITY;
        };
        ensure_lottery_known(lottery_id);
        ensure_initialized();
        ensure_caps_ready();
        let buyer_addr = signer::address_of(buyer);
        let state = borrow_global_mut<StoreState>(@lottery);
        let total_price = process_purchase(state, buyer, lottery_id, item_id, quantity);
        let access = borrow_global<StoreAccess>(@lottery);
        treasury_multi::ensure_scope(&access.cap, treasury_multi::scope_store());
        let treasury_state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_operations_income_with_cap(
            treasury_state,
            &access.cap,
            lottery_id,
            total_price,
            SOURCE_STORE,
        );
        event::emit_event(
            &mut state.purchase_events,
            ItemPurchasedEvent { lottery_id, item_id, buyer: buyer_addr, quantity, total_price },
        );
        emit_store_snapshot(state, lottery_id);
    }

    #[view]
    public fun get_item(lottery_id: u64, item_id: u64): option::Option<StoreItem> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreItem>();
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<StoreItem>();
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            option::none<StoreItem>()
        } else {
            let record = table::borrow(&store.items, item_id);
            option::some(record.item)
        }
    }

    #[view]
    public fun get_item_with_stats(lottery_id: u64, item_id: u64): option::Option<ItemWithStats>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<ItemWithStats>();
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<ItemWithStats>();
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            option::none<ItemWithStats>()
        } else {
            let record = table::borrow(&store.items, item_id);
            option::some(ItemWithStats { item: record.item, sold: record.sold })
        }
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_global<StoreState>(@lottery);
        copy_vec_u64(&state.lottery_ids)
    }

    #[view]
    public fun list_item_ids(lottery_id: u64): vector<u64> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            vector::empty<u64>()
        } else {
            let store = table::borrow(&state.lotteries, lottery_id);
            copy_vec_u64(&store.item_ids)
        }
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<vector<ItemWithStats>>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<vector<ItemWithStats>>();
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<vector<ItemWithStats>>();
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        let stats = collect_item_stats(&store.items, &store.item_ids, 0, vector::length(&store.item_ids));
        option::some(stats)
    }

    #[view]
    public fun get_lottery_snapshot(lottery_id: u64): option::Option<StoreLotterySnapshot>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreLotterySnapshot>();
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<StoreLotterySnapshot>();
        };
        option::some(build_lottery_snapshot(&state, lottery_id))
    }

    #[view]
    public fun get_store_snapshot(): option::Option<StoreSnapshot> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreSnapshot>();
        };
        let state = borrow_global<StoreState>(@lottery);
        option::some(build_store_snapshot(&state))
    }

    public fun ensure_caps_initialized(admin: &signer)
    acquires StoreAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(admin);
        if (exists<StoreAccess>(@lottery)) {
            return;
        };
        let control = treasury_multi::borrow_control_mut(@lottery);
        let cap_opt = treasury_multi::extract_store_cap(control);
        if (!option::is_some(&cap_opt)) {
            abort E_NOT_INITIALIZED;
        };
        let cap = option::destroy_some(cap_opt);
        move_to(admin, StoreAccess { cap });
    }

    public fun release_caps(admin: &signer)
    acquires StoreAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(admin);
        if (!exists<StoreAccess>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let StoreAccess { cap } = move_from<StoreAccess>(@lottery);
        let control = treasury_multi::borrow_control_mut(@lottery);
        treasury_multi::restore_store_cap(control, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<StoreAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_store()
    }

    fun process_purchase(
        state: &mut StoreState,
        buyer: &signer,
        lottery_id: u64,
        item_id: u64,
        quantity: u64,
    ): u64 acquires treasury_v1::TokenState {
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let store = table::borrow_mut(&mut state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let record = table::borrow_mut(&mut store.items, item_id);
        if (!record.item.available) {
            abort E_ITEM_NOT_FOUND;
        };
        let new_stock = next_stock(&record.item.stock, quantity);
        let total_price = math::safe_mul_u64(record.item.price, quantity, E_PRICE_OVERFLOW);
        treasury_v1::deposit_from_user(buyer, total_price);
        record.item.stock = new_stock;
        record.sold = math::safe_add_u64(record.sold, quantity, E_SOLD_OVERFLOW);
        total_price
    }

    fun next_stock(stock: &option::Option<u64>, quantity: u64): option::Option<u64> {
        if (!option::is_some(stock)) {
            option::none<u64>()
        } else {
            let remaining = *option::borrow(stock);
            if (remaining < quantity) {
                abort E_INSUFFICIENT_STOCK;
            };
            option::some(remaining - quantity)
        }
    }

    fun borrow_or_add_store(state: &mut StoreState, lottery_id: u64): &mut LotteryStore {
        if (table::contains(&state.lotteries, lottery_id)) {
            table::borrow_mut(&mut state.lotteries, lottery_id)
        } else {
            table::add(
                &mut state.lotteries,
                lottery_id,
                LotteryStore { items: table::new<u64, StoreRecord>(), item_ids: vector::empty<u64>() },
            );
            record_lottery_id(&mut state.lottery_ids, lottery_id);
            table::borrow_mut(&mut state.lotteries, lottery_id)
        }
    }

    fun build_store_snapshot(state: &StoreState): StoreSnapshot {
        let len = vector::length(&state.lottery_ids);
        let lotteries = collect_lottery_snapshots(&state.lotteries, &state.lottery_ids, 0, len);
        StoreSnapshot { admin: state.admin, lotteries }
    }

    fun build_lottery_snapshot(state: &StoreState, lottery_id: u64): StoreLotterySnapshot {
        build_lottery_snapshot_from_table(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot_from_mut(state: &mut StoreState, lottery_id: u64): StoreLotterySnapshot {
        build_lottery_snapshot_from_table(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot_from_table(
        lotteries: &table::Table<u64, LotteryStore>,
        lottery_id: u64,
    ): StoreLotterySnapshot {
        let store = table::borrow(lotteries, lottery_id);
        let items = collect_item_snapshots(&store.items, &store.item_ids, 0, vector::length(&store.item_ids));
        StoreLotterySnapshot { lottery_id, items }
    }

    fun collect_lottery_snapshots(
        lotteries: &table::Table<u64, LotteryStore>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<StoreLotterySnapshot> {
        if (index == len) {
            return vector::empty<StoreLotterySnapshot>();
        };
        let lottery_id = *vector::borrow(lottery_ids, index);
        let mut current = vector::empty<StoreLotterySnapshot>();
        if (table::contains(lotteries, lottery_id)) {
            let snapshot = build_lottery_snapshot_from_table(lotteries, lottery_id);
            vector::push_back(&mut current, snapshot);
        };
        let tail = collect_lottery_snapshots(lotteries, lottery_ids, index + 1, len);
        append_lottery_snapshots(&mut current, &tail, 0);
        current
    }

    fun collect_item_snapshots(
        items: &table::Table<u64, StoreRecord>,
        item_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<StoreItemSnapshot> {
        if (index == len) {
            return vector::empty<StoreItemSnapshot>();
        };
        let item_id = *vector::borrow(item_ids, index);
        let mut current = vector::empty<StoreItemSnapshot>();
        if (table::contains(items, item_id)) {
            let record = table::borrow(items, item_id);
            vector::push_back(&mut current, build_item_snapshot(item_id, record));
        };
        let tail = collect_item_snapshots(items, item_ids, index + 1, len);
        append_item_snapshots(&mut current, &tail, 0);
        current
    }

    fun collect_item_stats(
        items: &table::Table<u64, StoreRecord>,
        item_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<ItemWithStats> {
        if (index == len) {
            return vector::empty<ItemWithStats>();
        };
        let item_id = *vector::borrow(item_ids, index);
        let mut current = vector::empty<ItemWithStats>();
        if (table::contains(items, item_id)) {
            let record = table::borrow(items, item_id);
            vector::push_back(&mut current, ItemWithStats { item: record.item, sold: record.sold });
        };
        let tail = collect_item_stats(items, item_ids, index + 1, len);
        append_item_stats(&mut current, &tail, 0);
        current
    }

    fun build_item_snapshot(item_id: u64, record: &StoreRecord): StoreItemSnapshot {
        StoreItemSnapshot {
            item_id,
            price: record.item.price,
            available: record.item.available,
            stock: record.item.stock,
            sold: record.sold,
            metadata: copy_vec_u8(&record.item.metadata),
        }
    }

    fun emit_all_snapshots(state: &mut StoreState) {
        let len = vector::length(&state.lottery_ids);
        emit_snapshots_from(state, 0, len);
    }

    fun emit_snapshots_from(state: &mut StoreState, index: u64, len: u64) {
        if (index == len) {
            return;
        };
        let lottery_id = *vector::borrow(&state.lottery_ids, index);
        if (table::contains(&state.lotteries, lottery_id)) {
            emit_store_snapshot(state, lottery_id);
        };
        emit_snapshots_from(state, index + 1, len);
    }

    fun emit_store_snapshot(state: &mut StoreState, lottery_id: u64) {
        if (!table::contains(&state.lotteries, lottery_id)) {
            return;
        };
        let snapshot = build_lottery_snapshot_from_mut(state, lottery_id);
        event::emit_event(
            &mut state.snapshot_events,
            StoreSnapshotUpdatedEvent { admin: state.admin, snapshot },
        );
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        if (contains_u64(ids, lottery_id, 0)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun record_item_id(ids: &mut vector<u64>, item_id: u64) {
        if (contains_u64(ids, item_id, 0)) {
            return;
        };
        vector::push_back(ids, item_id);
    }

    fun copy_vec_u64(values: &vector<u64>): vector<u64> {
        copy_vec_u64_from(values, 0)
    }

    fun copy_vec_u64_from(values: &vector<u64>, index: u64): vector<u64> {
        let len = vector::length(values);
        if (index == len) {
            return vector::empty<u64>();
        };
        let mut current = vector::empty<u64>();
        vector::push_back(&mut current, *vector::borrow(values, index));
        let tail = copy_vec_u64_from(values, index + 1);
        append_u64(&mut current, &tail, 0);
        current
    }

    fun copy_vec_u8(values: &vector<u8>): vector<u8> {
        copy_vec_u8_from(values, 0)
    }

    fun copy_vec_u8_from(values: &vector<u8>, index: u64): vector<u8> {
        let len = vector::length(values);
        if (index == len) {
            return vector::empty<u8>();
        };
        let mut current = vector::empty<u8>();
        vector::push_back(&mut current, *vector::borrow(values, index));
        let tail = copy_vec_u8_from(values, index + 1);
        append_u8(&mut current, &tail, 0);
        current
    }

    fun append_lottery_snapshots(
        dst: &mut vector<StoreLotterySnapshot>,
        src: &vector<StoreLotterySnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_lottery_snapshots(dst, src, index + 1);
    }

    fun append_item_snapshots(
        dst: &mut vector<StoreItemSnapshot>,
        src: &vector<StoreItemSnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_item_snapshots(dst, src, index + 1);
    }

    fun append_item_stats(
        dst: &mut vector<ItemWithStats>,
        src: &vector<ItemWithStats>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_item_stats(dst, src, index + 1);
    }

    fun append_u64(dst: &mut vector<u64>, src: &vector<u64>, index: u64) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_u64(dst, src, index + 1);
    }

    fun append_u8(dst: &mut vector<u8>, src: &vector<u8>, index: u64) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_u8(dst, src, index + 1);
    }

    fun contains_u64(values: &vector<u64>, target: u64, index: u64): bool {
        let len = vector::length(values);
        if (index == len) {
            return false;
        };
        if (*vector::borrow(values, index) == target) {
            return true;
        };
        contains_u64(values, target, index + 1)
    }

    fun ensure_admin(caller: &signer) acquires StoreState {
        ensure_initialized();
        let state = borrow_global<StoreState>(@lottery);
        if (signer::address_of(caller) != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_admin_signer(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_caps_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_caps_ready() {
        if (!exists<StoreAccess>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_initialized() {
        if (!exists<StoreState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_lottery_known(lottery_id: u64) acquires instances::InstanceRegistry {
        let registry = instances::borrow_registry(@lottery);
        if (!instances::contains(registry, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
    }
}
