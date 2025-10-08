module lottery::rounds_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use std::account;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    fun setup_token(lottery_admin: &signer, buyer: &signer) {
        account::create_account_for_test(@jackpot_pool);
        account::create_account_for_test(@operations_pool);
        treasury_v1::init_token(
            lottery_admin,
            b"rounds_seed",
            b"Rounds Token",
            b"RND",
            6,
            b"",
            b"",
        );
        treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
        treasury_v1::register_store_for(lottery_admin, @operations_pool);
        treasury_v1::register_store(buyer);
        treasury_v1::mint_to(lottery_admin, signer::address_of(buyer), 10_000);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player1,
    )]
    fun ticket_purchase_updates_state(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

        let blueprint = registry::new_blueprint(100, 2000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::buy_ticket(buyer, lottery_id);

        let stats_opt = instances::get_instance_stats(lottery_id);
        let stats_snapshot = option::extract(stats_opt);
        let tickets_sold = stats_snapshot.tickets_sold;
        let jackpot_accumulated = stats_snapshot.jackpot_accumulated;
        let active = stats_snapshot.active;
        assert!(tickets_sold == 1, 0);
        assert!(jackpot_accumulated == 20, 1);
        assert!(active, 2);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_data = option::extract(snapshot_opt);
        let ticket_count = snapshot_data.ticket_count;
        let draw_scheduled = snapshot_data.draw_scheduled;
        let has_pending_request = snapshot_data.has_pending_request;
        let next_ticket_id = snapshot_data.next_ticket_id;
        assert!(ticket_count == 1, 3);
        assert!(!draw_scheduled, 4);
        assert!(!has_pending_request, 5);
        assert!(next_ticket_id == 1, 6);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        let pool_snapshot = option::extract(pool_opt);
        let prize_balance = pool_snapshot.prize_balance;
        let operations_balance = pool_snapshot.operations_balance;
        assert!(prize_balance == 70, 7);
        assert!(operations_balance == 10, 8);
        assert!(treasury_multi::jackpot_balance() == 20, 9);
        assert!(treasury_v1::balance_of(signer::address_of(buyer)) == 9_900, 10);
        assert!(treasury_v1::treasury_balance() == 100, 11);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player4,
    )]
    #[expected_failure(abort_code = 12)]
    fun cannot_buy_ticket_when_inactive(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

        let blueprint = registry::new_blueprint(100, 2000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        hub::set_lottery_active(vrf_admin, lottery_id, false);
        instances::set_instance_active(lottery_admin, lottery_id, false);

        rounds::buy_ticket(buyer, lottery_id);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player2,
    )]
    fun schedule_and_reset_round(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

        let blueprint = registry::new_blueprint(50, 1000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::buy_ticket(buyer, lottery_id);
        rounds::schedule_draw(lottery_admin, lottery_id);

        let scheduled_snapshot = option::extract(rounds::get_round_snapshot(lottery_id));
        let is_scheduled = scheduled_snapshot.draw_scheduled;
        assert!(is_scheduled, 0);

        rounds::reset_round(lottery_admin, lottery_id);
        let reset_snapshot = option::extract(rounds::get_round_snapshot(lottery_id));
        let ticket_count = reset_snapshot.ticket_count;
        let draw_scheduled = reset_snapshot.draw_scheduled;
        let next_ticket_id = reset_snapshot.next_ticket_id;
        assert!(ticket_count == 0, 1);
        assert!(!draw_scheduled, 2);
        assert!(next_ticket_id == 0, 3);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
        buyer = @player3,
        aggregator = @0x45,
    )]
    fun request_and_fulfill_draw(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
        buyer: &signer,
        aggregator: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, buyer);

        let blueprint = registry::new_blueprint(100, 2000);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::buy_ticket(buyer, lottery_id);
        rounds::buy_ticket(buyer, lottery_id);
        rounds::schedule_draw(lottery_admin, lottery_id);

        hub::set_callback_sender(vrf_admin, signer::address_of(aggregator));

        rounds::request_randomness(lottery_admin, lottery_id, b"payload");
        let request_opt = rounds::pending_request_id(lottery_id);
        let request_id = option::extract(request_opt);

        let randomness = vector::empty<u8>();
        vector::push_back(&mut randomness, 5);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);
        vector::push_back(&mut randomness, 0);

        rounds::fulfill_draw(aggregator, request_id, randomness);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        let snapshot_values = option::extract(snapshot_opt);
        let ticket_count = snapshot_values.ticket_count;
        let draw_scheduled = snapshot_values.draw_scheduled;
        let has_pending_request = snapshot_values.has_pending_request;
        let next_ticket_id = snapshot_values.next_ticket_id;
        assert!(ticket_count == 0, 0);
        assert!(!draw_scheduled, 1);
        assert!(!has_pending_request, 2);
        assert!(next_ticket_id == 0, 3);


        let buyer_addr = signer::address_of(buyer);
        assert!(treasury_v1::balance_of(buyer_addr) == 9_940, 4);

        assert!(treasury_v1::treasury_balance() == 60, 5);
        let pool = option::extract(treasury_multi::get_pool(lottery_id));
        let prize_balance = pool.prize_balance;
        let operations_balance = pool.operations_balance;
        assert!(prize_balance == 0, 6);
        assert!(operations_balance == 20, 7);
        assert!(treasury_multi::jackpot_balance() == 40, 8);
    }

    #[test(
        vrf_admin = @vrf_hub,
        factory_admin = @lottery_factory,
        lottery_admin = @lottery,
    )]
    #[expected_failure(abort_code = 7)]
    fun schedule_without_tickets_fails(
        vrf_admin: &signer,
        factory_admin: &signer,
        lottery_admin: &signer,
    ) {
        hub::init(vrf_admin);
        registry::init(factory_admin);
        instances::init(lottery_admin, @vrf_hub);
        rounds::init(lottery_admin);
        treasury_multi::init(lottery_admin, @jackpot_pool, @operations_pool);
        setup_token(lottery_admin, lottery_admin);

        let blueprint = registry::new_blueprint(25, 500);
        let lottery_id = registry::create_lottery(
            factory_admin,
            @lottery_owner,
            @lottery_contract,
            blueprint,
            vector::empty<u8>(),
        );
        instances::create_instance(lottery_admin, lottery_id);
        treasury_multi::upsert_lottery_config(lottery_admin, lottery_id, 7000, 2000, 1000);

        rounds::schedule_draw(lottery_admin, lottery_id);
    }
}
