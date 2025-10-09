#[test_only]
module lottery::migration_tests {
    use std::option;
    use std::signer;
    use std::vector;
    use lottery::instances;
    use lottery::main_v2;
    use lottery::migration;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery::test_utils;
    use lottery::treasury_v1;
    use lottery_factory::registry;
    use vrf_hub::hub;

    #[test(lottery = @lottery, lottery_owner = @player1, lottery_contract = @player2)]
    fun migrate_legacy_state(
        lottery: &signer,
        lottery_owner: &signer,
        lottery_contract: &signer,
    ) {
        setup_environment(lottery);

        let metadata = vector::empty<u8>();
        let blueprint = registry::new_blueprint(100, 1_000);
        let lottery_id = registry::create_lottery(
            lottery,
            signer::address_of(lottery),
            signer::address_of(lottery),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery, lottery_id);

        let tickets = vector::empty<address>();
        vector::push_back(&mut tickets, signer::address_of(lottery_owner));
        vector::push_back(&mut tickets, signer::address_of(lottery_contract));
        main_v2::set_draw_state_for_test(true, tickets);
        main_v2::set_jackpot_amount_for_test(500);
        main_v2::set_next_ticket_id_for_test(3);
        main_v2::set_pending_request_for_test(option::none());

        migration::migrate_from_legacy(lottery, lottery_id, 9_000, 1_000, 0);

        let stats_opt = instances::get_instance_stats(lottery_id);
        assert!(option::is_some(&stats_opt), 0);
        let stats = test_utils::unwrap(stats_opt);
        let (tickets_sold, jackpot_accumulated, active) =
            instances::instance_stats_for_test(&stats);
        assert!(tickets_sold == 2, tickets_sold);
        assert!(jackpot_accumulated == 0, jackpot_accumulated);
        assert!(active, 6);

        let snapshot_opt = rounds::get_round_snapshot(lottery_id);
        assert!(option::is_some(&snapshot_opt), 1);
        let snapshot = test_utils::unwrap(snapshot_opt);
        let (ticket_count, draw_scheduled, has_pending_request, next_ticket_id) =
            rounds::round_snapshot_fields_for_test(&snapshot);
        assert!(ticket_count == 2, ticket_count);
        assert!(draw_scheduled, 2);
        assert!(!has_pending_request, 3);
        assert!(next_ticket_id == 2, next_ticket_id);

        let pool_opt = treasury_multi::get_pool(lottery_id);
        assert!(option::is_some(&pool_opt), 4);
        let pool = test_utils::unwrap(pool_opt);
        let (prize_balance, operations_balance) = treasury_multi::pool_balances_for_test(&pool);
        assert!(prize_balance == 500, prize_balance);
        assert!(operations_balance == 0, operations_balance);
        assert!(treasury_multi::jackpot_balance() == 0, treasury_multi::jackpot_balance());

        let config_opt = treasury_multi::get_config(lottery_id);
        assert!(option::is_some(&config_opt), 5);
        assert!(main_v2::get_jackpot_amount() == 0, main_v2::get_jackpot_amount());
    }

    #[test(lottery = @lottery)]
    #[expected_failure(abort_code = migration::E_PENDING_REQUEST)]
    fun migration_rejects_pending_request(lottery: &signer) {
        setup_environment(lottery);

        let blueprint = registry::new_blueprint(100, 1_000);
        let metadata = vector::empty<u8>();
        let lottery_id = registry::create_lottery(
            lottery,
            signer::address_of(lottery),
            signer::address_of(lottery),
            blueprint,
            metadata,
        );
        instances::create_instance(lottery, lottery_id);

        main_v2::set_draw_state_for_test(false, vector::empty<address>());
        main_v2::set_jackpot_amount_for_test(0);
        main_v2::set_pending_request_for_test(option::some(7));

        migration::migrate_from_legacy(lottery, lottery_id, 10_000, 0, 0);
    }

    fun setup_environment(lottery: &signer) {
        if (!treasury_v1::is_initialized()) {
            treasury_v1::init_token(
                lottery,
                b"seed",
                b"Legacy Token",
                b"LEG",
                6,
                b"",
                b"",
            );
        };
        if (!main_v2::is_initialized()) {
            main_v2::init(lottery);
        };
        if (!treasury_multi::is_initialized()) {
            treasury_multi::init(
                lottery,
                signer::address_of(lottery),
                signer::address_of(lottery),
            );
        };
        if (!hub::is_initialized()) {
            hub::init(lottery);
        };
        if (!registry::is_initialized()) {
            registry::init(lottery);
        };
        if (!instances::is_initialized()) {
            instances::init(lottery, signer::address_of(lottery));
        };
        if (!rounds::is_initialized()) {
            rounds::init(lottery);
        };
    }
}
