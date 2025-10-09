module lottery_factory::registry {
    use std::option;
    use std::signer;
    use vrf_hub::table;
    use std::event;
    use vrf_hub::hub;


    const E_ALREADY_INIT: u64 = 1;

    const E_NOT_INITIALIZED: u64 = 2;

    const E_NOT_AUTHORIZED: u64 = 3;

    const E_UNKNOWN_LOTTERY: u64 = 4;


    struct LotteryBlueprint has copy, drop, store {
        ticket_price: u64,
        jackpot_share_bps: u16,
    }


    struct LotteryInfo has copy, drop, store {
        owner: address,
        lottery: address,
        blueprint: LotteryBlueprint,
    }


    struct FactoryState has key {
        admin: address,
        lotteries: table::Table<u64, LotteryInfo>,
        planned_events: event::EventHandle<LotteryPlannedEvent>,
        activated_events: event::EventHandle<LotteryActivatedEvent>,
    }

    #[event]
    struct LotteryPlannedEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
    }

    #[event]
    struct LotteryActivatedEvent has drop, store, copy {
        lottery_id: u64,
        lottery: address,
    }


    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery_factory) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<FactoryState>(@lottery_factory)) {
            abort E_ALREADY_INIT;
        };
        move_to(
            caller,
            FactoryState {
                admin: addr,
                lotteries: table::new(),
                planned_events: event::new_event_handle<LotteryPlannedEvent>(caller),
                activated_events: event::new_event_handle<LotteryActivatedEvent>(caller),
            },
        );
    }


    #[view]
    public fun is_initialized(): bool {
        exists<FactoryState>(@lottery_factory)
    }


    #[view]
    public fun new_blueprint(ticket_price: u64, jackpot_share_bps: u16): LotteryBlueprint {
        LotteryBlueprint { ticket_price, jackpot_share_bps }
    }


    public entry fun create_lottery(
        caller: &signer,
        owner: address,
        lottery: address,
        blueprint: LotteryBlueprint,
        metadata: vector<u8>,
    ): u64 acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        let lottery_id = hub::register_lottery(caller, owner, lottery, metadata);
        table::add(
            &mut state.lotteries,
            lottery_id,
            LotteryInfo { owner, lottery, blueprint },
        );
        event::emit_event(&mut state.planned_events, LotteryPlannedEvent { lottery_id, owner });
        event::emit_event(&mut state.activated_events, LotteryActivatedEvent { lottery_id, lottery });
        lottery_id
    }


    public entry fun update_blueprint(
        caller: &signer,
        lottery_id: u64,
        blueprint: LotteryBlueprint,
    ) acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
        let info = table::borrow_mut(&mut state.lotteries, lottery_id);
        info.blueprint = blueprint;
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        state.admin = new_admin;
    }


    #[view]
    public fun get_lottery(lottery_id: u64): option::Option<LotteryInfo> acquires FactoryState {
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.lotteries, lottery_id))
        }
    }


    #[view]
    /// test-view: возвращает owner, lottery, ticket_price, jackpot_share_bps
    public fun get_lottery_summary(
        lottery_id: u64,
    ): option::Option<(address, address, u64, u16)> acquires FactoryState {
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            option::none()
        } else {
            let info = table::borrow(&state.lotteries, lottery_id);
            option::some((
                info.owner,
                info.lottery,
                info.blueprint.ticket_price,
                info.blueprint.jackpot_share_bps,
            ))
        }
    }


    #[view]
    public fun lottery_count(): u64 acquires FactoryState {
        table::length(&borrow_state().lotteries)
    }

    fun borrow_state(): &FactoryState acquires FactoryState {
        if (!exists<FactoryState>(@lottery_factory)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<FactoryState>(@lottery_factory)
    }

    fun ensure_admin(caller: &signer) acquires FactoryState {
        let addr = signer::address_of(caller);
        let state = borrow_state();
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }
}
