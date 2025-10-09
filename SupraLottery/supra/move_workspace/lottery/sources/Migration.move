module lottery::migration {
    use std::option;
    use std::signer;
    use std::vector;
    use lottery::instances;
    use lottery::main_v2;
    use lottery::rounds;
    use lottery::treasury_multi;
    use lottery_factory::registry;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSTANCE_MISSING: u64 = 2;
    const E_PENDING_REQUEST: u64 = 3;
    const E_ALREADY_MIGRATED: u64 = 4;


    public entry fun migrate_from_legacy(
        caller: &signer,
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };
        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_INSTANCE_MISSING
        };

        let (tickets, draw_scheduled, _next_ticket_id_old, pending_request, jackpot_amount) =
            main_v2::export_state_for_migration();

        if (option::is_some(&pending_request)) {
            abort E_PENDING_REQUEST
        };

        let pool_opt = treasury_multi::get_pool(lottery_id);
        if (option::is_some(&pool_opt)) {
            abort E_ALREADY_MIGRATED
        };

        treasury_multi::upsert_lottery_config(caller, lottery_id, prize_bps, jackpot_bps, operations_bps);

        let ticket_count = vector::length(&tickets);
        let next_ticket_id = ticket_count;
        let effective_draw = draw_scheduled && ticket_count > 0;

        treasury_multi::migrate_seed_pool(lottery_id, jackpot_amount, 0, 0);
        instances::migrate_override_stats(lottery_id, ticket_count, 0);
        rounds::migrate_import_round(lottery_id, tickets, effective_draw, next_ticket_id, pending_request);

        main_v2::clear_state_after_migration();
    }
}
