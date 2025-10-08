module lottery::store {
    use std::option;
    use std::vector;
    use std::event;
    use std::math64;
    use std::signer;
    use vrf_hub::table;
    use lottery::instances;
    use lottery::treasury_multi;
    use lottery::treasury_v1;

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

    struct ItemWithStats has copy, drop, store {
        item: StoreItem,
        sold: u64,
    }


    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<StoreState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            StoreState {
                admin: addr,
                lotteries: table::new(),
                lottery_ids: vector::empty<u64>(),
                admin_events: event::new_event_handle<AdminUpdatedEvent>(caller),
                item_events: event::new_event_handle<ItemConfiguredEvent>(caller),
                purchase_events: event::new_event_handle<ItemPurchasedEvent>(caller),
            },
        );
    }


    #[view]
    public fun is_initialized(): bool {
        exists<StoreState>(@lottery)
    }


    #[view]
    public fun admin() : address acquires StoreState {
        borrow_state().admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires StoreState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
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
            abort E_INVALID_STOCK;
        };
        if (option::is_some(&stock) && *option::borrow(&stock) == 0) {
            abort E_INVALID_STOCK;
        };
        let state_ref = borrow_state_mut();
        let store = borrow_or_add_store(state_ref, lottery_id);
        if (table::contains(&store.items, item_id)) {
            let mut record = table::borrow_mut(&mut store.items, item_id);
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
        event::emit_event(
            &mut state_ref.item_events,
            ItemConfiguredEvent { lottery_id, item_id, price, available, stock, metadata },
        );
    }


    public entry fun set_availability(
        caller: &signer,
        lottery_id: u64,
        item_id: u64,
        available: bool,
    ) acquires StoreState {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        let state_ref = borrow_state_mut();
        if (!table::contains(&state_ref.lotteries, lottery_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let mut store = table::borrow_mut(&mut state_ref.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let mut record = table::borrow_mut(&mut store.items, item_id);
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
    }


    public entry fun purchase(
        buyer: &signer,
        lottery_id: u64,
        item_id: u64,
        quantity: u64,
    ) acquires StoreState {
        assert!(quantity > 0, E_INVALID_QUANTITY);
        ensure_lottery_exists(lottery_id);
        let state_ref = borrow_state_mut();
        let store = borrow_store_mut(state_ref, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            abort E_ITEM_NOT_FOUND;
        };
        let mut record = table::borrow_mut(&mut store.items, item_id);
        if (!record.item.available) {
            abort E_ITEM_NOT_FOUND;
        };
        let stock_left = if (option::is_some(&record.item.stock)) {
            let remaining = *option::borrow(&record.item.stock);
            if (remaining < quantity) {
                abort E_INSUFFICIENT_STOCK;
            };
            option::some(remaining - quantity)
        } else {
            option::none()
        };
        let total_price = math64::checked_mul(record.item.price, quantity);
        treasury_v1::deposit_from_user(buyer, total_price);
        record.item.stock = stock_left;
        record.sold = math64::checked_add(record.sold, quantity);
        treasury_multi::record_operations_income_internal(lottery_id, total_price, source_tag());
        event::emit_event(
            &mut state_ref.purchase_events,
            ItemPurchasedEvent { lottery_id, item_id, buyer: signer::address_of(buyer), quantity, total_price },
        );
    }


    #[view]
    public fun get_item(lottery_id: u64, item_id: u64): option::Option<StoreItem> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none();
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            option::none()
        } else {
            option::some(table::borrow(&store.items, item_id).item)
        }
    }


    #[view]
    public fun get_item_with_stats(lottery_id: u64, item_id: u64): option::Option<ItemWithStats>
    acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return option::none();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none();
        };
        let store = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&store.items, item_id)) {
            option::none()
        } else {
            let record = table::borrow(&store.items, item_id);
            option::some(ItemWithStats { item: record.item, sold: record.sold })
        }
    }


    #[view]
    public fun list_lottery_ids(): vector<u64> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            vector::empty<u64>()
        } else {
            let state_ref = borrow_state();
            copy_vec_u64(&state_ref.lottery_ids)
        }
    }


    #[view]
    public fun list_item_ids(lottery_id: u64): vector<u64> acquires StoreState {
        if (!exists<StoreState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state_ref = borrow_state();
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
            return option::none();
        };
        let state_ref = borrow_state();
        if (!table::contains(&state_ref.lotteries, lottery_id)) {
            return option::none();
        };
        let store = table::borrow(&state_ref.lotteries, lottery_id);
        let mut result = vector::empty<ItemWithStats>();
        let mut idx = 0;
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

    fun ensure_admin(caller: &signer) acquires StoreState {
        if (signer::address_of(caller) != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_lottery_exists(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_LOTTERY_NOT_FOUND;
        };
    }

    fun borrow_state() : &StoreState acquires StoreState {
        borrow_global<StoreState>(@lottery)
    }

    fun borrow_state_mut() : &mut StoreState acquires StoreState {
        borrow_global_mut<StoreState>(@lottery)
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
            abort E_NOT_INITIALIZED;
        };
        table::borrow_mut(&mut state.lotteries, lottery_id)
    }

    fun copy_vec_u8(source: &vector<u8>): vector<u8> {
        let mut result = vector::empty<u8>();
        let mut i = 0;
        let len = vector::length(source);
        while (i < len) {
            vector::push_back(&mut result, *vector::borrow(source, i));
            i = i + 1;
        };
        result
    }

    fun copy_vec_u64(source: &vector<u64>): vector<u64> {
        let mut result = vector::empty<u64>();
        let mut i = 0;
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
