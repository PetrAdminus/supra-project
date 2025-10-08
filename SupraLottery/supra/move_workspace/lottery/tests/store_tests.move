module lottery::store_tests {
    use std::option;
    use std::account;
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
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
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
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, buyer);

        store::upsert_item(
            lottery_admin,
            lottery_id,
            1,
            ITEM_PRICE,
            b"avatar-premium",
            true,
            option::some(ITEM_STOCK),
        );

        store::purchase(buyer, lottery_id, 1, 2);

        let item_stats = test_utils::unwrap(store::get_item_with_stats(lottery_id, 1));
        let item = item_stats.item;
        let sold = item_stats.sold;
        let stock = item.stock;
        assert!(sold == 2, 0);
        let remaining = test_utils::unwrap(stock);
        assert!(remaining == ITEM_STOCK - 2, 1);

        let summary = test_utils::unwrap(treasury_multi::get_lottery_summary(lottery_id));
        let pool = summary.pool;
        let operations_balance = pool.operations_balance;
        assert!(operations_balance == ITEM_PRICE * 2, 2);
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
        let lottery_id = setup_lottery(vrf_admin, factory_admin, lottery_admin);
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);
        setup_token(lottery_admin, buyer);

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
