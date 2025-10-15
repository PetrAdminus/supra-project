module lottery::autopurchase {
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
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
        snapshot_events: event::EventHandle<AutopurchaseSnapshotUpdatedEvent>,
    }

    struct AutopurchaseLotterySummary has copy, drop, store {
        total_balance: u64,
        total_players: u64,
        active_players: u64,
    }

    struct AutopurchasePlayerSnapshot has copy, drop, store {
        player: address,
        balance: u64,
        tickets_per_draw: u64,
        active: bool,
    }

    struct AutopurchaseLotterySnapshot has copy, drop, store {
        lottery_id: u64,
        total_balance: u64,
        total_players: u64,
        active_players: u64,
        players: vector<AutopurchasePlayerSnapshot>,
    }

    struct AutopurchaseSnapshot has copy, drop, store {
        admin: address,
        lotteries: vector<AutopurchaseLotterySnapshot>,
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

    #[event]
    struct AutopurchaseSnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        snapshot: AutopurchaseLotterySnapshot,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<AutopurchaseState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            AutopurchaseState {
                admin: addr,
                lotteries: table::new(),
                lottery_ids: vector::empty(),
                deposit_events: account::new_event_handle<AutopurchaseDepositEvent>(caller),
                config_events: account::new_event_handle<AutopurchaseConfigUpdatedEvent>(caller),
                executed_events: account::new_event_handle<AutopurchaseExecutedEvent>(caller),
                refund_events: account::new_event_handle<AutopurchaseRefundedEvent>(caller),
                snapshot_events: account::new_event_handle<AutopurchaseSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        emit_all_snapshots(state);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<AutopurchaseState>(@lottery)
    }

    public fun admin(): address acquires AutopurchaseState {
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires AutopurchaseState {
        ensure_admin(caller);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        state.admin = new_admin;
        emit_all_snapshots(state);
    }

    public entry fun configure_plan(
        caller: &signer,
        lottery_id: u64,
        tickets_per_draw: u64,
        active: bool,
    ) acquires AutopurchaseState {
        ensure_lottery_known(lottery_id);
        if (active && tickets_per_draw == 0) {
            abort E_TICKETS_PER_DRAW_ZERO
        };
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        {
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
        };
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun deposit(caller: &signer, lottery_id: u64, amount: u64)
    acquires AutopurchaseState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT
        };
        ensure_lottery_known(lottery_id);
        treasury_v1::deposit_from_user(caller, amount);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        let new_balance = {
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
                plan.balance = plan.balance + amount;
            };
            plans.total_balance = plans.total_balance + amount;
            let plan_ref = table::borrow(&plans.plans, player);
            plan_ref.balance
        };
        event::emit_event(
            &mut state.deposit_events,
            AutopurchaseDepositEvent {
                lottery_id,
                player: signer::address_of(caller),
                amount,
                new_balance,
            },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun execute(caller: &signer, lottery_id: u64, player: address)
    acquires AutopurchaseState {
        ensure_executor(caller, player);
        ensure_lottery_known(lottery_id);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        let info_opt = instances::get_lottery_info(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_UNKNOWN_LOTTERY
        };
        let info_ref = option::borrow(&info_opt);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        assert!(ticket_price > 0, E_TICKETS_PER_DRAW_ZERO);
        let (tickets_to_buy, spent, remaining_balance) = {
            let plans = ensure_lottery_plans(state, lottery_id);
            if (!table::contains(&plans.plans, player)) {
                abort E_PLAN_NOT_FOUND
            };
            let plan_ref = table::borrow_mut(&mut plans.plans, player);
            if (!plan_ref.active) {
                abort E_PLAN_INACTIVE
            };
            if (plan_ref.tickets_per_draw == 0) {
                abort E_TICKETS_PER_DRAW_ZERO
            };
            let affordable = plan_ref.balance / ticket_price;
            let desired = plan_ref.tickets_per_draw;
            let tickets_to_buy_local = if (affordable < desired) {
                affordable
            } else {
                desired
            };
            if (tickets_to_buy_local == 0) {
                abort E_INSUFFICIENT_BALANCE
            };
            let spent_local = rounds::record_prepaid_purchase(lottery_id, player, tickets_to_buy_local);
            plan_ref.balance = plan_ref.balance - spent_local;
            plans.total_balance = plans.total_balance - spent_local;
            (tickets_to_buy_local, spent_local, plan_ref.balance)
        };
        event::emit_event(
            &mut state.executed_events,
            AutopurchaseExecutedEvent {
                lottery_id,
                player,
                tickets_bought: tickets_to_buy,
                spent_amount: spent,
                remaining_balance,
            },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun refund(
        caller: &signer,
        lottery_id: u64,
        amount: u64,
    ) acquires AutopurchaseState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT
        };
        ensure_lottery_known(lottery_id);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        let player = signer::address_of(caller);
        let remaining_balance = {
            let plans = ensure_lottery_plans(state, lottery_id);
            if (!table::contains(&plans.plans, player)) {
                abort E_PLAN_NOT_FOUND
            };
            let plan_ref = table::borrow_mut(&mut plans.plans, player);
            if (plan_ref.balance < amount) {
                abort E_INSUFFICIENT_BALANCE
            };
            plan_ref.balance = plan_ref.balance - amount;
            plans.total_balance = plans.total_balance - amount;
            plan_ref.balance
        };
        treasury_v1::payout_from_treasury(player, amount);
        event::emit_event(
            &mut state.refund_events,
            AutopurchaseRefundedEvent { lottery_id, player, amount, remaining_balance },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    #[view]
    public fun get_plan(lottery_id: u64, player: address): option::Option<AutopurchasePlan>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchasePlan>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchasePlan>()
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
            return option::none<AutopurchaseLotterySummary>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchaseLotterySummary>()
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
            return vector::empty<u64>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun list_players(lottery_id: u64): option::Option<vector<address>>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<vector<address>>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<vector<address>>()
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        option::some(copy_address_vector(&plans.players))
    }

    #[view]
    public fun get_lottery_snapshot(lottery_id: u64): option::Option<AutopurchaseLotterySnapshot>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchaseLotterySnapshot>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchaseLotterySnapshot>()
        };
        option::some(build_lottery_snapshot(state, lottery_id))
    }

    #[view]
    public fun get_autopurchase_snapshot(): option::Option<AutopurchaseSnapshot>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchaseSnapshot>()
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        option::some(build_autopurchase_snapshot(state))
    }

    fun ensure_lottery_known(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
    }

    fun ensure_executor(caller: &signer, player: address) acquires AutopurchaseState {
        let caller_addr = signer::address_of(caller);
        if (caller_addr == player) {
            return
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (caller_addr != state.admin) {
            abort E_NOT_AUTHORIZED
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
                return
            };
            idx = idx + 1;
        };
        vector::push_back(&mut plans.players, player);
    }

    fun ensure_admin(caller: &signer) acquires AutopurchaseState {
        ensure_autopurchase_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_autopurchase_initialized() {
        if (!exists<AutopurchaseState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    #[test_only]
    public fun plan_fields_for_test(plan: &AutopurchasePlan): (u64, u64, bool) {
        (plan.balance, plan.tickets_per_draw, plan.active)
    }

    #[test_only]
    public fun summary_fields_for_test(summary: &AutopurchaseLotterySummary): (u64, u64, u64) {
        (summary.total_balance, summary.total_players, summary.active_players)
    }

    #[test_only]
    public fun lottery_snapshot_fields_for_test(
        snapshot: &AutopurchaseLotterySnapshot,
    ): (u64, u64, u64, vector<AutopurchasePlayerSnapshot>) {
        (
            snapshot.total_balance,
            snapshot.total_players,
            snapshot.active_players,
            copy_player_snapshot_vector(&snapshot.players),
        )
    }

    #[test_only]
    public fun player_snapshot_fields_for_test(
        snapshot: &AutopurchasePlayerSnapshot,
    ): (address, u64, u64, bool) {
        (snapshot.player, snapshot.balance, snapshot.tickets_per_draw, snapshot.active)
    }

    #[test_only]
    public fun autopurchase_snapshot_fields_for_test(
        snapshot: &AutopurchaseSnapshot,
    ): (address, vector<AutopurchaseLotterySnapshot>) {
        (snapshot.admin, copy_lottery_snapshot_vector(&snapshot.lotteries))
    }

    #[test_only]
    public fun autopurchase_snapshot_event_fields_for_test(
        event: &AutopurchaseSnapshotUpdatedEvent,
    ): (address, AutopurchaseLotterySnapshot) {
        (event.admin, copy_lottery_snapshot(&event.snapshot))
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

    fun copy_player_snapshot_vector(
        values: &vector<AutopurchasePlayerSnapshot>,
    ): vector<AutopurchasePlayerSnapshot> {
        let out = vector::empty<AutopurchasePlayerSnapshot>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun copy_lottery_snapshot_vector(
        values: &vector<AutopurchaseLotterySnapshot>,
    ): vector<AutopurchaseLotterySnapshot> {
        let out = vector::empty<AutopurchaseLotterySnapshot>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun copy_lottery_snapshot(snapshot: &AutopurchaseLotterySnapshot): AutopurchaseLotterySnapshot {
        AutopurchaseLotterySnapshot {
            lottery_id: snapshot.lottery_id,
            total_balance: snapshot.total_balance,
            total_players: snapshot.total_players,
            active_players: snapshot.active_players,
            players: copy_player_snapshot_vector(&snapshot.players),
        }
    }

    fun build_autopurchase_snapshot(state: &AutopurchaseState): AutopurchaseSnapshot {
        let lotteries = vector::empty<AutopurchaseLotterySnapshot>();
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.lotteries, lottery_id)) {
                vector::push_back(&mut lotteries, build_lottery_snapshot(state, lottery_id));
            };
            idx = idx + 1;
        };
        AutopurchaseSnapshot { admin: state.admin, lotteries }
    }

    fun build_lottery_snapshot_from_mut(
        state: &mut AutopurchaseState,
        lottery_id: u64,
    ): AutopurchaseLotterySnapshot {
        build_lottery_snapshot_internal(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot(
        state: &AutopurchaseState,
        lottery_id: u64,
    ): AutopurchaseLotterySnapshot {
        build_lottery_snapshot_internal(&state.lotteries, lottery_id)
    }

    fun build_lottery_snapshot_internal(
        lotteries: &table::Table<u64, LotteryPlans>,
        lottery_id: u64,
    ): AutopurchaseLotterySnapshot {
        let plans = table::borrow(lotteries, lottery_id);
        let players = vector::empty<AutopurchasePlayerSnapshot>();
        let total_players = vector::length(&plans.players);
        let idx = 0;
        let active_players = 0;
        while (idx < total_players) {
            let player = *vector::borrow(&plans.players, idx);
            if (table::contains(&plans.plans, player)) {
                let plan = table::borrow(&plans.plans, player);
                if (plan.active && plan.tickets_per_draw > 0) {
                    active_players = active_players + 1;
                };
                vector::push_back(
                    &mut players,
                    AutopurchasePlayerSnapshot {
                        player,
                        balance: plan.balance,
                        tickets_per_draw: plan.tickets_per_draw,
                        active: plan.active,
                    },
                );
            };
            idx = idx + 1;
        };
        AutopurchaseLotterySnapshot {
            lottery_id,
            total_balance: plans.total_balance,
            total_players,
            active_players,
            players,
        }
    }

    fun emit_all_snapshots(state: &mut AutopurchaseState) {
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.lotteries, lottery_id)) {
                emit_autopurchase_snapshot(state, lottery_id);
            };
            idx = idx + 1;
        };
    }

    fun emit_autopurchase_snapshot(state: &mut AutopurchaseState, lottery_id: u64) {
        if (!table::contains(&state.lotteries, lottery_id)) {
            return
        };
        let snapshot = build_lottery_snapshot_from_mut(state, lottery_id);
        event::emit_event(
            &mut state.snapshot_events,
            AutopurchaseSnapshotUpdatedEvent { admin: state.admin, snapshot },
        );
    }
}
