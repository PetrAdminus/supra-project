#[test_only]
module lottery::store_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::instances;
    use lottery::rounds;
    use lottery::store;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    const ITEM_PRICE: u64 = 150;
    const ITEM_STOCK: u64 = 5;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        test_utils::ensure_core_accounts();
        treasury_v1::init_token(
            lottery_admin,
            b"store_seed",
            b"Store Token",
            b"STORE",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(buyer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 10_000);
    }

    fun setup_lottery(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ): u64 {
        test_utils::ensure_core_accounts();
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        store::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);

        let blueprint = registry::new_blueprint(100, 1_000);
        registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            b"store-test",
        )
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player1,
    )]
    fun purchase_updates_stock_and_operations(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        setup_token(lottery_admin, buyer);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        store::upsert_item(
            lottery_admin,
            lottery_id,
            1,
            ITEM_PRICE,
            b"avatar-premium",
            true,
            option::some(ITEM_STOCK),
        );

        let _ = test_utils::drain_events<store::StoreSnapshotUpdatedEvent>();
        store::purchase(buyer, lottery_id, 1, 2);

        let item_stats_opt = store::get_item_with_stats(lottery_id, 1);
        let item_stats = test_utils::unwrap(&mut item_stats_opt);
        let (item, sold) = store::item_with_stats_components_for_test(&item_stats);
        let stock = store::store_item_stock_for_test(&item);
        assert!(sold == 2, 0);
        let remaining = test_utils::unwrap(&mut stock);
        assert!(remaining == ITEM_STOCK - 2, 1);

        let summary_opt = treasury_multi::get_lottery_summary(lottery_id);
        let summary = test_utils::unwrap(&mut summary_opt);
        let (_config, pool) = treasury_multi::summary_components_for_test(&summary);
        let (_prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(operations_balance == ITEM_PRICE * 2, 2);

        let lottery_snapshot_opt = store::get_lottery_snapshot(lottery_id);
        let lottery_snapshot = test_utils::unwrap(&mut lottery_snapshot_opt);
        let (snapshot_lottery_id, item_snapshots) =
            store::store_lottery_snapshot_fields_for_test(&lottery_snapshot);
        assert!(snapshot_lottery_id == lottery_id, 20);
        assert!(vector::length(&item_snapshots) == 1, 21);
        let item_snapshot = vector::borrow(&item_snapshots, 0);
        let (
            snapshot_item_id,
            snapshot_price,
            snapshot_available,
            snapshot_stock,
            snapshot_sold,
            snapshot_metadata,
        ) = store::store_item_snapshot_fields_for_test(item_snapshot);
        assert!(snapshot_item_id == 1, 22);
        assert!(snapshot_price == ITEM_PRICE, 23);
        assert!(snapshot_available, 24);
        let snapshot_stock_local = snapshot_stock;
        let remaining_snapshot = test_utils::unwrap(&mut snapshot_stock_local);
        assert!(remaining_snapshot == ITEM_STOCK - 2, 25);
        assert!(snapshot_sold == 2, 26);
        let expected_metadata = b"avatar-premium";
        let metadata_len = vector::length(&snapshot_metadata);
        assert!(metadata_len == vector::length(&expected_metadata), 27);
        let metadata_idx = 0;
        while (metadata_idx < metadata_len) {
            assert!(
                *vector::borrow(&snapshot_metadata, metadata_idx)
                    == *vector::borrow(&expected_metadata, metadata_idx),
                28,
            );
            metadata_idx = metadata_idx + 1;
        };

        let store_snapshot_before_opt = store::get_store_snapshot();
        let store_snapshot_before = test_utils::unwrap(&mut store_snapshot_before_opt);
        let (store_admin_before, store_lotteries_before) =
            store::store_snapshot_fields_for_test(&store_snapshot_before);
        assert!(store_admin_before == signer::address_of(lottery_admin), 29);
        assert!(vector::length(&store_lotteries_before) == 1, 30);

        let _ = test_utils::drain_events<store::StoreSnapshotUpdatedEvent>();

        store::set_admin(lottery_admin, @lottery_owner);

        let store_snapshot_after_opt = store::get_store_snapshot();
        let store_snapshot_after = test_utils::unwrap(&mut store_snapshot_after_opt);
        let (store_admin_after, _) = store::store_snapshot_fields_for_test(&store_snapshot_after);
        assert!(store_admin_after == @lottery_owner, 31);

        let snapshot_events =
            test_utils::drain_events<store::StoreSnapshotUpdatedEvent>();
        if (vector::is_empty(&snapshot_events)) {
            return;
        };
        let snapshot_events_len = vector::length(&snapshot_events);
        let last_event = test_utils::last_event_ref(&snapshot_events);
        let (event_admin, event_snapshot) = store::store_snapshot_event_fields_for_test(last_event);
        assert!(event_admin == @lottery_owner, 33);
        let (event_lottery_id, event_items) =
            store::store_lottery_snapshot_fields_for_test(&event_snapshot);
        assert!(event_lottery_id == lottery_id, 34);
        assert!(vector::length(&event_items) == 1, 35);
        let event_item = vector::borrow(&event_items, 0);
        let (_, _, event_available, event_stock, event_sold, _) =
            store::store_item_snapshot_fields_for_test(event_item);
        assert!(event_available, 36);
        let event_remaining = test_utils::unwrap(&mut event_stock);
        assert!(event_remaining == ITEM_STOCK - 2, 37);
        assert!(event_sold == 2, 38);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player2,
    )]
    #[expected_failure(location = lottery::store, abort_code = store::E_INSUFFICIENT_STOCK)]
    fun purchase_more_than_stock_aborts(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        setup_token(lottery_admin, buyer);
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        store::upsert_item(
            lottery_admin,
            lottery_id,
            7,
            ITEM_PRICE,
            b"limited-nft",
            true,
            option::some(1),
        );

        store::purchase(buyer, lottery_id, 7, 2);
    }
}
