#[test_only]
module lottery_rewards_engine::store_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use lottery_rewards_engine::store;

    #[test(lottery_admin = @lottery)]
    fun import_existing_items_restore_snapshot(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 101, @0xAA01);
        register_lottery(lottery_admin, 202, @0xBB02);

        let mut items = vector::empty<store::LegacyStoreItem>();
        vector::push_back(
            &mut items,
            store::LegacyStoreItem {
                lottery_id: 101,
                item_id: 1,
                price: 15,
                metadata: b"hoodie",
                available: true,
                stock: option::some(25),
                sold: 12,
            },
        );
        vector::push_back(
            &mut items,
            store::LegacyStoreItem {
                lottery_id: 202,
                item_id: 44,
                price: 50,
                metadata: b"poster",
                available: false,
                stock: option::none<u64>(),
                sold: 3,
            },
        );

        store::import_existing_items(lottery_admin, items);

        let snapshot_opt = store::get_store_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 1);
        assert!(vector::length(&snapshot.lotteries) == 2, 2);

        let hoodie_snapshot = store::get_lottery_snapshot(101);
        assert!(option::is_some(&hoodie_snapshot), 3);
        let hoodie = option::destroy_some(hoodie_snapshot);
        assert!(vector::length(&hoodie.items) == 1, 4);
        let first_item = *vector::borrow(&hoodie.items, 0);
        assert!(first_item.item_id == 1, 5);
        assert!(first_item.price == 15, 6);
        assert!(first_item.sold == 12, 7);
        assert!(first_item.available, 8);
        assert!(option::is_some(&first_item.stock), 9);
        assert!(*option::borrow(&first_item.stock) == 25, 10);
        assert!(vector::length(&first_item.metadata) == 6, 11);
        assert!(*vector::borrow(&first_item.metadata, 0) == 0x68, 12);

        let poster_snapshot = store::get_lottery_snapshot(202);
        assert!(option::is_some(&poster_snapshot), 13);
        let poster = option::destroy_some(poster_snapshot);
        assert!(vector::length(&poster.items) == 1, 14);
        let poster_item = *vector::borrow(&poster.items, 0);
        assert!(poster_item.item_id == 44, 15);
        assert!(poster_item.price == 50, 16);
        assert!(poster_item.sold == 3, 17);
        assert!(!poster_item.available, 18);
        assert!(option::is_none(&poster_item.stock), 19);
        assert!(vector::length(&poster_item.metadata) == 6, 20);
        assert!(*vector::borrow(&poster_item.metadata, 0) == 0x70, 21);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_records(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 303, @0xCC03);

        store::import_existing_item(
            lottery_admin,
            store::LegacyStoreItem {
                lottery_id: 303,
                item_id: 77,
                price: 99,
                metadata: b"t-shirt",
                available: true,
                stock: option::some(5),
                sold: 2,
            },
        );

        store::import_existing_item(
            lottery_admin,
            store::LegacyStoreItem {
                lottery_id: 303,
                item_id: 77,
                price: 135,
                metadata: b"deluxe-shirt",
                available: false,
                stock: option::none<u64>(),
                sold: 9,
            },
        );

        let snapshot_opt = store::get_lottery_snapshot(303);
        assert!(option::is_some(&snapshot_opt), 22);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(vector::length(&snapshot.items) == 1, 23);
        let item = *vector::borrow(&snapshot.items, 0);
        assert!(item.price == 135, 24);
        assert!(item.sold == 9, 25);
        assert!(!item.available, 26);
        assert!(option::is_none(&item.stock), 27);
        assert!(vector::length(&item.metadata) == 12, 28);
        assert!(*vector::borrow(&item.metadata, 0) == 0x64, 29);
    }

    fun bootstrap_prerequisites(lottery_admin: &signer) {
        treasury_multi::bootstrap_control_for_tests(lottery_admin);
        if (!instances::is_initialized()) {
            instances::init_registry(lottery_admin);
        };
        if (!store::is_initialized()) {
            store::init(lottery_admin);
        };
    }

    fun register_lottery(lottery_admin: &signer, lottery_id: u64, owner: address) {
        let record = instances::LegacyInstanceRecord {
            lottery_id,
            owner,
            lottery_address: owner,
            ticket_price: 1,
            jackpot_share_bps: 100,
            tickets_sold: 0,
            jackpot_accumulated: 0,
            active: true,
        };
        store_lottery_record(lottery_admin, record);
    }

    fun store_lottery_record(
        lottery_admin: &signer,
        record: instances::LegacyInstanceRecord,
    ) {
        instances::import_existing_instance(lottery_admin, record);
    }
}
