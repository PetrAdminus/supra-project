module lottery_rewards_engine::autopurchase {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_data::treasury_multi;
    use lottery_data::treasury_v1;
    use lottery_engine::sales;
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INVALID_AMOUNT: u64 = 4;
    const E_PLAN_NOT_FOUND: u64 = 5;
    const E_PLAN_INACTIVE: u64 = 6;
    const E_TICKETS_PER_DRAW_ZERO: u64 = 7;
    const E_INSUFFICIENT_BALANCE: u64 = 8;
    const E_UNKNOWN_LOTTERY: u64 = 9;
    const E_CAPS_UNAVAILABLE: u64 = 10;
    const E_MAX_TICKETS_EXCEEDED: u64 = 11;

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

    struct AutopurchaseAccess has key {
        rounds: rounds::AutopurchaseRoundCap,
        treasury: treasury_v1::AutopurchaseTreasuryCap,
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

    public entry fun init(caller: &signer) acquires AutopurchaseState {
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
                lotteries: table::new<u64, LotteryPlans>(),
                lottery_ids: vector::empty<u64>(),
                deposit_events: account::new_event_handle<AutopurchaseDepositEvent>(caller),
                config_events: account::new_event_handle<AutopurchaseConfigUpdatedEvent>(caller),
                executed_events: account::new_event_handle<AutopurchaseExecutedEvent>(caller),
                refund_events: account::new_event_handle<AutopurchaseRefundedEvent>(caller),
                snapshot_events: account::new_event_handle<AutopurchaseSnapshotUpdatedEvent>(caller),
            },
        );
        emit_all_snapshots();
    }

    public entry fun init_access(caller: &signer)
    acquires AutopurchaseAccess, AutopurchaseState, rounds::RoundControl, treasury_v1::TreasuryV1Control {
        ensure_admin(caller);
        if (exists<AutopurchaseAccess>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        let rounds_control = rounds::borrow_control_mut(@lottery);
        let rounds_cap_opt = rounds::extract_autopurchase_cap(rounds_control);
        if (!option::is_some(&rounds_cap_opt)) {
            abort E_CAPS_UNAVAILABLE;
        };
        let rounds_cap = option::destroy_some(rounds_cap_opt);

        let treasury_control = treasury_v1::borrow_control_mut(@lottery);
        let treasury_cap_opt = treasury_v1::extract_autopurchase_cap(treasury_control);
        if (!option::is_some(&treasury_cap_opt)) {
            rounds::restore_autopurchase_cap(rounds_control, rounds_cap);
            abort E_CAPS_UNAVAILABLE;
        };
        let treasury_cap = option::destroy_some(treasury_cap_opt);

        move_to(
            caller,
            AutopurchaseAccess { rounds: rounds_cap, treasury: treasury_cap },
        );
    }

    public entry fun release_access(caller: &signer)
    acquires AutopurchaseAccess, rounds::RoundControl, treasury_v1::TreasuryV1Control {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (!exists<AutopurchaseAccess>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let AutopurchaseAccess { rounds: rounds_cap, treasury: treasury_cap } =
            move_from<AutopurchaseAccess>(@lottery);
        let rounds_control = rounds::borrow_control_mut(@lottery);
        rounds::restore_autopurchase_cap(rounds_control, rounds_cap);
        let treasury_control = treasury_v1::borrow_control_mut(@lottery);
        treasury_v1::restore_autopurchase_cap(treasury_control, treasury_cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<AutopurchaseAccess>(@lottery)
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires AutopurchaseState {
        ensure_admin(caller);
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        state.admin = new_admin;
        emit_all_snapshots_internal(state);
    }

    public entry fun configure_plan(
        caller: &signer,
        lottery_id: u64,
        tickets_per_draw: u64,
        active: bool,
    ) acquires AutopurchaseState {
        ensure_lottery_known(lottery_id);
        ensure_autopurchase_initialized();
        let max_supported = sales::max_supported_tickets_per_purchase();
        if (tickets_per_draw > max_supported) {
            abort E_MAX_TICKETS_EXCEEDED;
        };
        if (active && tickets_per_draw == 0) {
            abort E_TICKETS_PER_DRAW_ZERO;
        };
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
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
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun deposit(caller: &signer, lottery_id: u64, amount: u64)
    acquires AutopurchaseState, treasury_v1::TokenState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT;
        };
        ensure_lottery_known(lottery_id);
        treasury_v1::deposit_from_user(caller, amount);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        let plans = ensure_lottery_plans(state, lottery_id);
        let player = signer::address_of(caller);
        let new_balance = if (!table::contains(&plans.plans, player)) {
            record_player(plans, player);
            table::add(
                &mut plans.plans,
                player,
                AutopurchasePlan { balance: amount, tickets_per_draw: 0, active: false },
            );
            amount
        } else {
            let plan = table::borrow_mut(&mut plans.plans, player);
            plan.balance = plan.balance + amount;
            plan.balance
        };
        plans.total_balance = plans.total_balance + amount;
        event::emit_event(
            &mut state.deposit_events,
            AutopurchaseDepositEvent { lottery_id, player, amount, new_balance },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun execute(caller: &signer, lottery_id: u64, player: address)
    acquires
        AutopurchaseAccess,
        AutopurchaseState,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry,
        treasury_multi::TreasuryState
    {
        ensure_executor(caller, player);
        ensure_lottery_known(lottery_id);
        ensure_autopurchase_initialized();
        ensure_caps_ready();
        let ticket_price = lottery_ticket_price(lottery_id);
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
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
        let max_supported = sales::max_supported_tickets_per_purchase();
        if (plan.tickets_per_draw > max_supported) {
            abort E_MAX_TICKETS_EXCEEDED;
        };
        let affordable = plan.balance / ticket_price;
        let desired = plan.tickets_per_draw;
        let tickets_to_buy = if (affordable < desired) { affordable } else { desired };
        if (tickets_to_buy == 0) {
            abort E_INSUFFICIENT_BALANCE;
        };
        let (_, spent_amount) = sales::record_prepaid_purchase(lottery_id, player, tickets_to_buy);
        plan.balance = plan.balance - spent_amount;
        plans.total_balance = plans.total_balance - spent_amount;
        event::emit_event(
            &mut state.executed_events,
            AutopurchaseExecutedEvent {
                lottery_id,
                player,
                tickets_bought: tickets_to_buy,
                spent_amount,
                remaining_balance: plan.balance,
            },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    public entry fun refund(
        caller: &signer,
        lottery_id: u64,
        amount: u64,
    ) acquires AutopurchaseAccess, AutopurchaseState, treasury_v1::TokenState {
        if (amount == 0) {
            abort E_INVALID_AMOUNT;
        };
        ensure_caps_ready();
        ensure_lottery_known(lottery_id);
        ensure_autopurchase_initialized();
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
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
        let access = borrow_global<AutopurchaseAccess>(@lottery);
        treasury_v1::payout_with_autopurchase_cap(&access.treasury, player, amount);
        event::emit_event(
            &mut state.refund_events,
            AutopurchaseRefundedEvent { lottery_id, player, amount, remaining_balance: plan.balance },
        );
        emit_autopurchase_snapshot(state, lottery_id);
    }

    #[view]
    public fun get_plan(lottery_id: u64, player: address): option::Option<AutopurchasePlan>
    acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return option::none<AutopurchasePlan>();
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
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
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<AutopurchaseLotterySummary>();
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        let total_players = vector::length(&plans.players);
        let active_players = count_active_players(plans, 0);
        option::some(AutopurchaseLotterySummary { total_balance: plans.total_balance, total_players, active_players })
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires AutopurchaseState {
        if (!exists<AutopurchaseState>(@lottery)) {
            return vector::empty<u64>();
        };
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    fun ensure_autopurchase_initialized() {
        if (!exists<AutopurchaseState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_admin(caller: &signer) acquires AutopurchaseState {
        ensure_autopurchase_initialized();
        let state = borrow_global<AutopurchaseState>(@lottery);
        let addr = signer::address_of(caller);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_executor(caller: &signer, player: address) acquires AutopurchaseState {
        let caller_addr = signer::address_of(caller);
        if (caller_addr == player) {
            return;
        };
        ensure_admin(caller);
    }

    fun ensure_caps_ready() {
        if (!exists<AutopurchaseAccess>(@lottery)) {
            abort E_CAPS_UNAVAILABLE;
        };
    }

    fun ensure_lottery_known(lottery_id: u64) {
        let registry = instances::borrow_registry(@lottery);
        if (!instances::contains(registry, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
    }

    fun ensure_lottery_plans(state: &mut AutopurchaseState, lottery_id: u64): &mut LotteryPlans {
        if (!table::contains(&state.lotteries, lottery_id)) {
            table::add(
                &mut state.lotteries,
                lottery_id,
                LotteryPlans { plans: table::new<address, AutopurchasePlan>(), players: vector::empty<address>(), total_balance: 0 },
            );
            vector::push_back(&mut state.lottery_ids, lottery_id);
        };
        table::borrow_mut(&mut state.lotteries, lottery_id)
    }

    fun record_player(plans: &mut LotteryPlans, player: address) {
        if (contains_player(&plans.players, player, 0)) {
            return;
        };
        vector::push_back(&mut plans.players, player);
    }

    fun contains_player(players: &vector<address>, player: address, index: u64): bool {
        if (index == vector::length(players)) {
            return false;
        };
        if (*vector::borrow(players, index) == player) {
            return true;
        };
        let next_index = index + 1;
        contains_player(players, player, next_index)
    }

    fun emit_all_snapshots() {
        if (!exists<AutopurchaseState>(@lottery)) {
            return;
        };
        let state = borrow_global_mut<AutopurchaseState>(@lottery);
        emit_all_snapshots_internal(state);
    }

    fun emit_all_snapshots_internal(state: &mut AutopurchaseState) {
        let len = vector::length(&state.lottery_ids);
        emit_snapshots_recursive(state, 0, len);
    }

    fun emit_snapshots_recursive(state: &mut AutopurchaseState, index: u64, len: u64) {
        if (index == len) {
            return;
        };
        let lottery_id = *vector::borrow(&state.lottery_ids, index);
        if (table::contains(&state.lotteries, lottery_id)) {
            emit_autopurchase_snapshot(state, lottery_id);
        };
        let next_index = index + 1;
        emit_snapshots_recursive(state, next_index, len);
    }

    fun emit_autopurchase_snapshot(state: &mut AutopurchaseState, lottery_id: u64) {
        if (!table::contains(&state.lotteries, lottery_id)) {
            return;
        };
        let plans = table::borrow(&state.lotteries, lottery_id);
        let mut players = vector::empty<AutopurchasePlayerSnapshot>();
        collect_player_snapshots(plans, 0, &mut players);
        let active_players = count_active_players(plans, 0);
        let snapshot = AutopurchaseLotterySnapshot {
            lottery_id,
            total_balance: plans.total_balance,
            total_players: vector::length(&plans.players),
            active_players,
            players,
        };
        event::emit_event(
            &mut state.snapshot_events,
            AutopurchaseSnapshotUpdatedEvent { admin: state.admin, snapshot },
        );
    }

    fun collect_player_snapshots(
        plans: &LotteryPlans,
        index: u64,
        target: &mut vector<AutopurchasePlayerSnapshot>,
    ) {
        if (index == vector::length(&plans.players)) {
            return;
        };
        let player = *vector::borrow(&plans.players, index);
        if (table::contains(&plans.plans, player)) {
            let plan = table::borrow(&plans.plans, player);
            vector::push_back(
                target,
                AutopurchasePlayerSnapshot {
                    player,
                    balance: plan.balance,
                    tickets_per_draw: plan.tickets_per_draw,
                    active: plan.active,
                },
            );
        };
        let next_index = index + 1;
        collect_player_snapshots(plans, next_index, target);
    }

    fun count_active_players(plans: &LotteryPlans, index: u64): u64 {
        if (index == vector::length(&plans.players)) {
            return 0;
        };
        let player = *vector::borrow(&plans.players, index);
        let remaining = count_active_players(plans, index + 1);
        if (!table::contains(&plans.plans, player)) {
            return remaining;
        };
        let plan = table::borrow(&plans.plans, player);
        if (plan.active && plan.tickets_per_draw > 0) {
            remaining + 1
        } else {
            remaining
        }
    }

    fun copy_u64_vector(source: &vector<u64>): vector<u64> {
        let mut result = vector::empty<u64>();
        copy_u64_vector_recursive(source, 0, &mut result);
        result
    }

    fun copy_u64_vector_recursive(source: &vector<u64>, index: u64, target: &mut vector<u64>) {
        if (index == vector::length(source)) {
            return;
        };
        let value = *vector::borrow(source, index);
        vector::push_back(target, value);
        let next_index = index + 1;
        copy_u64_vector_recursive(source, next_index, target);
    }

    fun lottery_ticket_price(lottery_id: u64): u64 {
        let registry = instances::borrow_registry(@lottery);
        let record = instances::instance(registry, lottery_id);
        record.ticket_price
    }
}
