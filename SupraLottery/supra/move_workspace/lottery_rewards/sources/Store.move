module lottery_rewards::store {
    use std::option;
    use std::vector;
    use std::signer;
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;
    use lottery_core::instances;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use lottery_core::treasury_v1;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_LOTTERY_NOT_FOUND: u64 = 4;
    const E_ITEM_NOT_FOUND: u64 = 5;
    const E_INVALID_STOCK: u64 = 6;
    const E_INSUFFICIENT_STOCK: u64 = 7;
    const E_INVALID_QUANTITY: u64 = 8;

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

    struct StoreAccess has key { cap: MultiTreasuryCap }

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

    public entry fun init(caller: &signer) acquires StoreState {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<StoreState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            StoreState {
                admin: addr,
                lotteries: table::new(),
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
        ensure_lottery_exists(lottery_id);
        if (price == 0) {
            abort E_INVALID_STOCK
        };
        if (option::is_some(&stock) && *option::borrow(&stock) == 0) {
            abort E_INVALID_STOCK
        };
        let state_ref = borrow_global_mut<StoreState>(@lottery);
        {
            let store = borrow_or_add_store(state_ref, lottery_id);
            if (table::contains(&store.items, item_id)) {
                let record = table::borrow_mut(&mut store.items, item_id);
                let metadata_for_record = copy_vec_u8(&metadata);
                record.item = StoreItem { price, metadata: metadata_for_record, available, stock };
            } else {
                let metadata_for_record = copy_vec_u8(&metadata);
                table::add(
                    &mut store.items,
                    item_id,
                    StoreRecord { item: StoreItem { price, metadata: metadata_for_record, available, stock }, sold: 0 },
                );
                vector::push_back(&mut store.item_ids, item_id);
            };
        };
        event::emit_event(
            &mut state_ref.item_events,
            ItemConfiguredEvent { lottery_id, item_id, price, available, stock, metadata },
        );
        emit_store_snapshot(state_ref, lottery_id);
    }

    public entry fun set_availability(
        caller: &signer,
        lottery_id: u64,
        item_id: u64,
        available: bool,
    ) acquires StoreState {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        let state_ref = borrow_global_mut<StoreState>(@lottery);
        if (!table::contains(&state_ref.lotteries, lottery_id)) {
            abort E_ITEM_NOT_FOUND
        };
        {
            let store = table::borrow_mut(&mut state_ref.lotteries, lottery_id);
            if (!table::contains(&store.items, item_id)) {
                abort E_ITEM_NOT_FOUND
            };
            let record = table::borrow_mut(&mut store.items, item_id);
            record.item.available = available;
            event::emit_event(
                &mut state_ref.item_events,
                ItemConfiguredEvent {
                    lottery_id,
                    item_id,
                    price: record.item.price,
                    available,
                    stock: record.item.stock,
                    metadata: copy_vec_u8(&record.item.metadata),
                },
            );
        };
        emit_store_snapshot(state_ref, lottery_id);
    }

    public entry fun purchase(
        buyer: &signer,
        lottery_id: u64,
        item_id: u64,
        quantity: u64,
    ) acquires StoreAccess, StoreState {
        assert!(quantity > 0, E_INVALID_QUANTITY);
        ensure_lottery_exists(lottery_id);
        let state_ref = borrow_global_mut<StoreState>(@lottery);
        let total_price;
        {
            let store = borrow_store_mut(state_ref, lottery_id);
            if (!table::contains(&store.items, item_id)) {
                abort E_ITEM_NOT_FOUND
            };
            let record = table::borrow_mut(&mut store.items, item_id);
            if (!record.item.available) {
                abort E_ITEM_NOT_FOUND
            };
            let stock_left = if (option::is_some(&record.item.stock)) {
                let remaining = *option::borrow(&record.item.stock);
                if (remaining < quantity) {
                    abort E_INSUFFICIENT_STOCK
                };
                option::some(remaining - quantity)
            } else {
                option::none<u64>()
            };
            total_price = record.item.price * quantity;
            treasury_v1::deposit_from_user(buyer, total_price);
            record.item.stock = stock_left;
            record.sold = record.sold + quantity;
        };
        let access = borrow_global<StoreAccess>(@lottery);
        treasury_multi::record_operations_income_with_cap(
            &access.cap,
            lottery_id,
            total_price,
            source_tag(),
        );
        event::emit_event(
            &mut state_ref.purchase_events,
            ItemPurchasedEvent { lottery_id, item_id, buyer: signer::address_of(buyer), quantity, total_price },
        );
        emit_store_snapshot(state_ref, lottery_id);
    }

    #[view]
    public fun get_item(lottery_id: u64, item_id: u64): option::Option<StoreItem> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreItem>()
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<StoreItem>()
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            option::none<StoreItem>()
        } else {
            option::some(table::borrow(&store.items, item_id).item)
        }
    }

    #[view]
    public fun get_item_with_stats(lottery_id: u64, item_id: u64): option::Option<ItemWithStats>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<ItemWithStats>()
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<ItemWithStats>()
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
            return vector::empty<u64>()
        };
        let state_ref = borrow_global<StoreState>(@lottery);
        copy_vec_u64(&state_ref.lottery_ids)
    }

    #[view]
    public fun list_item_ids(lottery_id: u64): vector<u64> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return vector::empty<u64>()
        };
        let state_ref = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state_ref.lotteries, lottery_id)) {
            vector::empty<u64>()
        } else {
            copy_vec_u64(&table::borrow(&state_ref.lotteries, lottery_id).item_ids)
        }
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<vector<ItemWithStats>>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<vector<ItemWithStats>>()
        };
        let state_ref = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state_ref.lotteries, lottery_id)) {
            return option::none<vector<ItemWithStats>>()
        };
        let store = table::borrow(&state_ref.lotteries, lottery_id);
        let result = vector::empty<ItemWithStats>();
        let idx = 0;
        let len = vector::length(&store.item_ids);
        while (idx < len) {
            let item_id = *vector::borrow(&store.item_ids, idx);
            if (table::contains(&store.items, item_id)) {
                let record = table::borrow(&store.items, item_id);
                vector::push_back(&mut result, ItemWithStats { item: record.item, sold: record.sold });
            };
            idx = idx + 1;
        };
        option::some(result)
    }

    #[view]
    public fun get_lottery_snapshot(lottery_id: u64): option::Option<StoreLotterySnapshot>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreLotterySnapshot>()
        };
        let state = borrow_global<StoreState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<StoreLotterySnapshot>()
        };
        option::some(build_lottery_snapshot(state, lottery_id))
    }

    #[view]
    public fun get_store_snapshot(): option::Option<StoreSnapshot> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none<StoreSnapshot>()
        };
        let state = borrow_global<StoreState>(@lottery);
        option::some(build_store_snapshot(state))
    }

    public fun ensure_caps_initialized(admin: &signer) {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<StoreAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_store(),
        );
        move_to(admin, StoreAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires StoreAccess {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<StoreAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let StoreAccess { cap } = move_from<StoreAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<StoreAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_store()
    }

    fun ensure_admin(caller: &signer) acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<StoreState>(@lottery);
        if (signer::address_of(caller) != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_lottery_exists(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_LOTTERY_NOT_FOUND
        };
    }

    #[test_only]
    public fun item_with_stats_components_for_test(item_stats: &ItemWithStats): (StoreItem, u64) {
        (item_stats.item, item_stats.sold)
    }

    #[test_only]
    public fun store_item_stock_for_test(item: &StoreItem): option::Option<u64> {
        item.stock
    }

    #[test_only]
    public fun store_snapshot_event_fields_for_test(
        event: &StoreSnapshotUpdatedEvent
    ): (address, StoreLotterySnapshot) {
        (event.admin, event.snapshot)
    }

    #[test_only]
    public fun store_lottery_snapshot_fields_for_test(
        snapshot: &StoreLotterySnapshot
    ): (u64, vector<StoreItemSnapshot>) {
        (snapshot.lottery_id, snapshot.items)
    }

    #[test_only]
    public fun store_item_snapshot_fields_for_test(
        snapshot: &StoreItemSnapshot
    ): (u64, u64, bool, option::Option<u64>, u64, vector<u8>) {
        (
            snapshot.item_id,
            snapshot.price,
            snapshot.available,
            snapshot.stock,
            snapshot.sold,
            copy_vec_u8(&snapshot.metadata),
        )
    }

    #[test_only]
    public fun store_snapshot_fields_for_test(
        snapshot: &StoreSnapshot
    ): (address, vector<StoreLotterySnapshot>) {
        (snapshot.admin, snapshot.lotteries)
    }

    fun borrow_or_add_store(state: &mut StoreState, lottery_id: u64): &mut LotteryStore {
        if (table::contains(&state.lotteries, lottery_id)) {
            table::borrow_mut(&mut state.lotteries, lottery_id)
        } else {
            table::add(&mut state.lotteries, lottery_id, LotteryStore { items: table::new(), item_ids: vector::empty<u64>() });
            vector::push_back(&mut state.lottery_ids, lottery_id);
            table::borrow_mut(&mut state.lotteries, lottery_id)
        }
    }

    fun borrow_store_mut(state: &mut StoreState, lottery_id: u64): &mut LotteryStore {
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_NOT_INITIALIZED
        };
        table::borrow_mut(&mut state.lotteries, lottery_id)
    }

    fun build_store_snapshot(state: &StoreState): StoreSnapshot {
        let snapshots = vector::empty<StoreLotterySnapshot>();
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.lotteries, lottery_id)) {
                vector::push_back(&mut snapshots, build_lottery_snapshot(state, lottery_id));
            };
            idx = idx + 1;
        };
        StoreSnapshot { admin: state.admin, lotteries: snapshots }
    }

    fun build_lottery_snapshot_from_mut(
        state: &mut StoreState,
        lottery_id: u64,
    ): StoreLotterySnapshot {
        build_lottery_snapshot_from_table(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot(state: &StoreState, lottery_id: u64): StoreLotterySnapshot {
        build_lottery_snapshot_from_table(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot_from_table(
        lotteries: &table::Table<u64, LotteryStore>,
        lottery_id: u64,
    ): StoreLotterySnapshot {
        let store = table::borrow(lotteries, lottery_id);
        let items = vector::empty<StoreItemSnapshot>();
        let len = vector::length(&store.item_ids);
        let idx = 0;
        while (idx < len) {
            let item_id = *vector::borrow(&store.item_ids, idx);
            if (table::contains(&store.items, item_id)) {
                let record = table::borrow(&store.items, item_id);
                vector::push_back(&mut items, build_item_snapshot(item_id, record));
            };
            idx = idx + 1;
        };
        StoreLotterySnapshot { lottery_id, items }
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
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.lotteries, lottery_id)) {
                emit_store_snapshot(state, lottery_id);
            };
            idx = idx + 1;
        };
    }

    fun emit_store_snapshot(state: &mut StoreState, lottery_id: u64) {
        if (!table::contains(&state.lotteries, lottery_id)) {
            return
        };
        let snapshot = build_lottery_snapshot_from_mut(state, lottery_id);
        event::emit_event(
            &mut state.snapshot_events,
            StoreSnapshotUpdatedEvent { admin: state.admin, snapshot },
        );
    }

    fun copy_vec_u8(source: &vector<u8>): vector<u8> {
        let result = vector::empty<u8>();
        let i = 0;
        let len = vector::length(source);
        while (i < len) {
            vector::push_back(&mut result, *vector::borrow(source, i));
            i = i + 1;
        };
        result
    }

    fun copy_vec_u64(source: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(source);
        while (i < len) {
            vector::push_back(&mut result, *vector::borrow(source, i));
            i = i + 1;
        };
        result
    }

    fun source_tag(): vector<u8> {
        SOURCE_STORE
    }
}
