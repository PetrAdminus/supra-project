module lottery::autopurchase {
    use std::option;
    use std::signer;
    use std::vector;
    use std::u128;
    use vrf_hub::table;
    use std::event;
    use std::math64;
    use lottery::instances;
    use lottery::rounds;
    use lottery::treasury_v1;
    use lottery_factory::registry;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INVALID_AMOUNT: u64 = 4;
    const E_PLAN_NOT_FOUND: u64 = 5;
    const E_PLAN_INACTIVE: u64 = 6;
    const E_TICKETS_PER_DRAW_ZERO: u64 = 7;
    const E_INSUFFICIENT_BALANCE: u64 = 8;
    const E_UNKNOWN_LOTTERY: u64 = 9;

    struct AutopurchasePlan has copy, drop, store {
        balance: u64,
        tickets_per_draw: u64,
        active: bool,
    }

    struct LotteryPlans has store {
        plans: table::Table<address, AutopurchasePlan>,
        players: vector<address>,
        total_balance: u64,
    }

    struct AutopurchaseState has key {
        admin: address,
        lotteries: table::Table<u64, LotteryPlans>,
        lottery_ids: vector<u64>,
        deposit_events: event::EventHandle<AutopurchaseDepositEvent>,
        config_events: event::EventHandle<AutopurchaseConfigUpdatedEvent>,
        executed_events: event::EventHandle<AutopurchaseExecutedEvent>,
        refund_events: event::EventHandle<AutopurchaseRefundedEvent>,
    }

    struct AutopurchaseLotterySummary has copy, drop, store {
        total_balance: u64,
        total_players: u64,
        active_players: u64,
    }

    #[event]
    struct AutopurchaseDepositEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        amount: u64,
        new_balance: u64,
    }

    #[event]
    struct AutopurchaseConfigUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        tickets_per_draw: u64,
        active: bool,
    }

    #[event]
    struct AutopurchaseExecutedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        tickets_bought: u64,
        spent_amount: u64,
        remaining_balance: u64,
    }

    #[event]
    struct AutopurchaseRefundedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        amount: u64,
        remaining_balance: u64,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<AutopurchaseState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            AutopurchaseState {
                admin: addr,
                lotteries: table::new(),
                lottery_ids: vector::empty(),
                deposit_events: event::new_event_handle<AutopurchaseDepositEvent>(caller),
                config_events: event::new_event_handle<AutopurchaseConfigUpdatedEvent>(caller),
                executed_events: event::new_event_handle<AutopurchaseExecutedEvent>(caller),
                refund_events: event::new_event_handle<AutopurchaseRefundedEvent>(caller),
            },
        );
    }

    #[view]
    public fun is_initialized(): bool {
        exists<AutopurchaseState>(@lottery)
    }

    public fun admin(): address acquires AutopurchaseState {
        borrow_state().admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires AutopurchaseState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        state.admin = new_admin;
    }

    public entry fun configure_plan(
        caller: &signer,
        lottery_id: u64,
        tickets_per_draw: u64,
        active: bool,
    ) acquires AutopurchaseState {
        ensure_lottery_known(lottery_id);
        if (active && tickets_per_draw == 0) {
            abort E_TICKETS_PER_DRAW_ZERO;
        };
        let state = borrow_state_mut();
        let plans = ensure_lottery_plans(state, lottery_id);
        let player = signer::address_of(caller);
        if (!table::contains(&plans.plans, player)) {
            record_player(plans, player);
            table::add(
                &mut plans.plans,
                player,
                AutopurchasePlan { balance: 0, tickets_per_draw, active },
            );
        } else {
            let plan = table::borrow_mut(&mut plans.plans, player);
            plan.tickets_per_draw = tickets_per_draw;
            plan.active = active;
        };
        event::emit_event(
            &mut state.config_events,
            AutopurchaseConfigUpdatedEvent { lottery_id, player, tickets_per_draw, active },
        );
    }

    public entry fun deposit(caller: &signer, lottery_id: u64, amount: u64)
    acquires AutopurchaseState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT;
        };
        ensure_lottery_known(lottery_id);
        treasury_v1::deposit_from_user(caller, amount);
        let state = borrow_state_mut();
        let plans = ensure_lottery_plans(state, lottery_id);
        let player = signer::address_of(caller);
        if (!table::contains(&plans.plans, player)) {
            record_player(plans, player);
            table::add(
                &mut plans.plans,
                player,
                AutopurchasePlan { balance: amount, tickets_per_draw: 0, active: false },
            );
        } else {
            let plan = table::borrow_mut(&mut plans.plans, player);
            plan.balance = math64::checked_add(plan.balance, amount);
        };
        plans.total_balance = math64::checked_add(plans.total_balance, amount);
        let plan = table::borrow(&plans.plans, player);
        event::emit_event(
            &mut state.deposit_events,
            AutopurchaseDepositEvent {
                lottery_id,
                player,
                amount,
                new_balance: plan.balance,
            },
        );
    }

    public entry fun execute(caller: &signer, lottery_id: u64, player: address)
    acquires AutopurchaseState {
        ensure_executor(caller, player);
        ensure_lottery_known(lottery_id);
        let state = borrow_state_mut();
        let plans = ensure_lottery_plans(state, lottery_id);
        if (!table::contains(&plans.plans, player)) {
            abort E_PLAN_NOT_FOUND;
        };
        let plan = table::borrow_mut(&mut plans.plans, player);
        if (!plan.active) {
            abort E_PLAN_INACTIVE;
        };
        if (plan.tickets_per_draw == 0) {
            abort E_TICKETS_PER_DRAW_ZERO;
        };
        let info_opt = instances::get_lottery_info(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_UNKNOWN_LOTTERY;
        };
        let info = *option::borrow(&info_opt);
        let blueprint = info.blueprint;
        let ticket_price = blueprint.ticket_price;
        assert!(ticket_price > 0, E_TICKETS_PER_DRAW_ZERO);
        let affordable = plan.balance / ticket_price;
        let tickets_to_buy = plan.tickets_per_draw;
        if (affordable < tickets_to_buy) {
            tickets_to_buy = affordable;
        };
        if (tickets_to_buy == 0) {
            abort E_INSUFFICIENT_BALANCE;
        };
        let spent = rounds::record_prepaid_purchase(lottery_id, player, tickets_to_buy);
        plan.balance = plan.balance - spent;
        plans.total_balance = plans.total_balance - spent;
        event::emit_event(
            &mut state.executed_events,
            AutopurchaseExecutedEvent {
                lottery_id,
                player,
                tickets_bought: tickets_to_buy,
                spent_amount: spent,
                remaining_balance: plan.balance,
            },
        );
    }

    public entry fun refund(
        caller: &signer,
        lottery_id: u64,
        amount: u64,
    ) acquires AutopurchaseState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT;
        };
        ensure_lottery_known(lottery_id);
        let state = borrow_state_mut();
        let plans = ensure_lottery_plans(state, lottery_id);
        let player = signer::address_of(caller);
        if (!table::contains(&plans.plans, player)) {
            abort E_PLAN_NOT_FOUND;
        };
        let plan = table::borrow_mut(&mut plans.plans, player);
        if (plan.balance < amount) {
            abort E_INSUFFICIENT_BALANCE;
        };
        plan.balance = plan.balance - amount;
        plans.total_balance = plans.total_balance - amount;
        treasury_v1::payout_from_treasury(player, amount);
        event::emit_event(
            &mut state.refund_events,
            AutopurchaseRefundedEvent { lottery_id, player, amount, remaining_balance: plan.balance },
        );
    }

    #[view]
    public fun get_plan(lottery_id: u64, player: address): option::Option<AutopurchasePlan>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchasePlan>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchasePlan>();
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&plans.plans, player)) {
            option::none<AutopurchasePlan>()
        } else {
            option::some(*table::borrow(&plans.plans, player))
        }
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<AutopurchaseLotterySummary>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchaseLotterySummary>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchaseLotterySummary>();
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        let total_players = vector::length(&plans.players);
        let active_players = 0;
        let idx = 0;
        while (idx < total_players) {
            let player = *vector::borrow(&plans.players, idx);
            if (table::contains(&plans.plans, player)) {
                let plan_snapshot = *table::borrow(&plans.plans, player);
                let active = plan_snapshot.active;
                let tickets_per_draw = plan_snapshot.tickets_per_draw;
                if (active && tickets_per_draw > 0) {
                    active_players = active_players + 1;
                };
            };
            idx = idx + 1;
        };
        option::some(AutopurchaseLotterySummary {
            total_balance: plans.total_balance,
            total_players,
            active_players,
        })
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_state();
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun list_players(lottery_id: u64): option::Option<vector<address>>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<vector<address>>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<vector<address>>();
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        option::some(copy_address_vector(&plans.players))
    }

    #[view]
    /// test-view: возвращает баланс плана как u128
    public fun get_plan_balance(player: address, lottery_id: u64): u128
    acquires AutopurchaseState {
        let plan_opt = get_plan(lottery_id, player);
        if (!option::is_some(&plan_opt)) {
            abort E_PLAN_NOT_FOUND;
        };
        let plan_ref = option::borrow(&plan_opt);
        u128::from_u64(plan_ref.balance)
    }


    #[view]
    /// test-view: возвращает (total_players, active_players, total_balance)
    public fun get_lottery_summary_view(lottery_id: u64): (u64, u64, u128)
    acquires AutopurchaseState {
        let summary_opt = get_lottery_summary(lottery_id);
        if (!option::is_some(&summary_opt)) {
            abort E_UNKNOWN_LOTTERY;
        };
        let summary_ref = option::borrow(&summary_opt);
        (
            summary_ref.total_players,
            summary_ref.active_players,
            u128::from_u64(summary_ref.total_balance),
        )
    }


    fun ensure_lottery_known(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
    }

    fun ensure_executor(caller: &signer, player: address) acquires AutopurchaseState {
        let caller_addr = signer::address_of(caller);
        if (caller_addr == player) {
            return;
        };
        let state = borrow_state();
        if (caller_addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_lottery_plans(state: &mut AutopurchaseState, lottery_id: u64): &mut LotteryPlans {
        if (!table::contains(&state.lotteries, lottery_id)) {
            table::add(
                &mut state.lotteries,
                lottery_id,
                LotteryPlans { plans: table::new(), players: vector::empty(), total_balance: 0 },
            );
            vector::push_back(&mut state.lottery_ids, lottery_id);
        };
        table::borrow_mut(&mut state.lotteries, lottery_id)
    }

    fun record_player(plans: &mut LotteryPlans, player: address) {
        let len = vector::length(&plans.players);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(&plans.players, idx) == player) {
                return;
            };
            idx = idx + 1;
        };
        vector::push_back(&mut plans.players, player);
    }

    fun borrow_state(): &AutopurchaseState acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<AutopurchaseState>(@lottery)
    }

    fun borrow_state_mut(): &mut AutopurchaseState acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<AutopurchaseState>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires AutopurchaseState {
        let addr = signer::address_of(caller);
        if (addr != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        let out = vector::empty<u64>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun copy_address_vector(values: &vector<address>): vector<address> {
        let out = vector::empty<address>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }
}
