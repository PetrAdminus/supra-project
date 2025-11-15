module lottery_engine::ticketing {
    use std::option;
    use std::signer;

    use lottery_data::instances;
    use lottery_data::jackpot;
    use lottery_data::lottery_state;
    use lottery_data::rounds;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_INVALID_TICKET_PRICE: u64 = 2;
    const E_INVALID_DRAW_THRESHOLD: u64 = 3;
    const E_INVALID_JACKPOT_SHARE: u64 = 4;

    const MIN_TICKET_PRICE: u64 = 1_000_000; // 0.001 SUPRA
    const MAX_TICKET_PRICE: u64 = 1_000_000_000_000; // 10 SUPRA
    const MIN_AUTO_DRAW_THRESHOLD: u64 = 1;
    const MAX_AUTO_DRAW_THRESHOLD: u64 = 1_000;
    const MAX_JACKPOT_SHARE_BPS: u16 = 10_000;

    public entry fun create_lottery(
        caller: &signer,
        lottery_id: u64,
        owner: address,
        ticket_price: u64,
        auto_draw_threshold: u64,
        jackpot_share_bps: u16,
    ) acquires instances::InstanceRegistry, jackpot::JackpotRegistry, lottery_state::LotteryState, rounds::RoundRegistry {
        validate_price(ticket_price);
        validate_threshold(auto_draw_threshold);
        assert!(jackpot_share_bps <= MAX_JACKPOT_SHARE_BPS, E_INVALID_JACKPOT_SHARE);

        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);

        instances::register_instance(
            registry,
            lottery_id,
            instances::InstanceRecord {
                owner,
                lottery_address: admin,
                ticket_price,
                jackpot_share_bps,
                tickets_sold: 0,
                jackpot_accumulated: 0,
                active: true,
            },
        );
        instances::emit_owner_record(registry, lottery_id, option::none<address>(), owner);

        let runtime = lottery_state::empty_runtime(ticket_price, auto_draw_threshold);
        let state = lottery_state::borrow_mut(@lottery);
        lottery_state::register_lottery(state, lottery_id, runtime);
        lottery_state::emit_snapshot(state, lottery_id);

        let rounds_registry = rounds::borrow_registry_mut(@lottery);
        rounds::register_round(rounds_registry, lottery_id, rounds::empty_round());
        rounds::emit_snapshot(rounds_registry, lottery_id);

        let jackpot_registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::register_jackpot(jackpot_registry, lottery_id);

        let record = instances::instance(registry, lottery_id);
        instances::emit_creation(registry, lottery_id, record);
        instances::emit_blueprint(registry, lottery_id, ticket_price, jackpot_share_bps);
        instances::emit_status(registry, lottery_id, true);
        instances::emit_snapshot(registry, lottery_id);
    }

    public entry fun update_ticket_price(
        caller: &signer,
        lottery_id: u64,
        new_ticket_price: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        validate_price(new_ticket_price);

        let caller_addr = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        let jackpot_share_bps = update_instance_price(registry, lottery_id, caller_addr, new_ticket_price);
        instances::emit_blueprint(registry, lottery_id, new_ticket_price, jackpot_share_bps);
        instances::emit_snapshot(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        update_runtime_price(state, lottery_id, new_ticket_price);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    fun validate_price(price: u64) {
        assert!(price >= MIN_TICKET_PRICE, E_INVALID_TICKET_PRICE);
        assert!(price <= MAX_TICKET_PRICE, E_INVALID_TICKET_PRICE);
    }

    fun validate_threshold(threshold: u64) {
        assert!(threshold >= MIN_AUTO_DRAW_THRESHOLD, E_INVALID_DRAW_THRESHOLD);
        assert!(threshold <= MAX_AUTO_DRAW_THRESHOLD, E_INVALID_DRAW_THRESHOLD);
    }

    fun update_instance_price(
        registry: &mut instances::InstanceRegistry,
        lottery_id: u64,
        caller: address,
        new_ticket_price: u64,
    ): u16 acquires instances::InstanceRegistry {
        let record = instances::instance_mut(registry, lottery_id);
        let owner = record.owner;
        assert!(caller == registry.admin || caller == owner, E_UNAUTHORIZED_ADMIN);
        record.ticket_price = new_ticket_price;
        record.jackpot_share_bps
    }

    fun update_runtime_price(
        state: &mut lottery_state::LotteryState,
        lottery_id: u64,
        new_ticket_price: u64,
    ) acquires lottery_state::LotteryState {
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        runtime.ticket_price = new_ticket_price;
    }
}
