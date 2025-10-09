module lottery::treasury_multi {
    friend lottery::rounds;
    friend lottery::jackpot;
    friend lottery::migration;
    friend lottery::referrals;
    friend lottery::vip;
    friend lottery::store;
    use std::option;
    use std::signer;
    use std::vector;
    use std::u128;
    use vrf_hub::table;
    use std::event;
    use std::math64;
    use lottery::treasury_v1;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_BASIS_POINTS: u64 = 4;
    const E_CONFIG_MISSING: u64 = 5;
    const E_POOL_MISSING: u64 = 6;
    const E_INSUFFICIENT_JACKPOT: u64 = 7;
    const E_POOL_ALREADY_EXISTS: u64 = 8;
    const E_INSUFFICIENT_OPERATIONS: u64 = 9;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;


    struct LotteryShareConfig has copy, drop, store {
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    }


    struct LotteryPool has copy, drop, store {
        prize_balance: u64,
        operations_balance: u64,
    }


    struct TreasuryState has key {
        admin: address,
        jackpot_recipient: address,
        operations_recipient: address,
        jackpot_balance: u64,
        configs: table::Table<u64, LotteryShareConfig>,
        pools: table::Table<u64, LotteryPool>,
        lottery_ids: vector<u64>,
        config_events: event::EventHandle<LotteryConfigUpdatedEvent>,
        allocation_events: event::EventHandle<AllocationRecordedEvent>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        recipient_events: event::EventHandle<RecipientsUpdatedEvent>,
        prize_events: event::EventHandle<PrizePaidEvent>,
        operations_events: event::EventHandle<OperationsWithdrawnEvent>,
        operations_income_events: event::EventHandle<OperationsIncomeRecordedEvent>,
        operations_bonus_events: event::EventHandle<OperationsBonusPaidEvent>,
        jackpot_events: event::EventHandle<JackpotPaidEvent>,
    }

    #[event]
    struct LotteryConfigUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    }

    #[event]
    struct AllocationRecordedEvent has drop, store, copy {
        lottery_id: u64,
        total_amount: u64,
        prize_amount: u64,
        jackpot_amount: u64,
        operations_amount: u64,
    }

    #[event]
    struct AdminUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    #[event]
    struct RecipientsUpdatedEvent has drop, store, copy {
        previous_jackpot: address,
        previous_operations: address,
        next_jackpot: address,
        next_operations: address,
    }

    #[event]
    struct PrizePaidEvent has drop, store, copy {
        lottery_id: u64,
        winner: address,
        amount: u64,
    }

    #[event]
    struct OperationsWithdrawnEvent has drop, store, copy {
        lottery_id: u64,
        recipient: address,
        amount: u64,
    }

    #[event]
    struct OperationsIncomeRecordedEvent has drop, store, copy {
        lottery_id: u64,
        amount: u64,
        source: vector<u8>,
    }

    #[event]
    struct OperationsBonusPaidEvent has drop, store, copy {
        lottery_id: u64,
        recipient: address,
        amount: u64,
    }

    #[event]
    struct JackpotPaidEvent has drop, store, copy {
        recipient: address,
        amount: u64,
    }

    struct LotterySummary has copy, drop, store {
        config: LotteryShareConfig,
        pool: LotteryPool,
    }


    public entry fun init(
        caller: &signer,
        jackpot_recipient: address,
        operations_recipient: address,
    ) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<TreasuryState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            TreasuryState {
                admin: addr,
                jackpot_recipient,
                operations_recipient,
                jackpot_balance: 0,
                configs: table::new(),
                pools: table::new(),
                lottery_ids: vector::empty<u64>(),
                config_events: event::new_event_handle<LotteryConfigUpdatedEvent>(caller),
                allocation_events: event::new_event_handle<AllocationRecordedEvent>(caller),
                admin_events: event::new_event_handle<AdminUpdatedEvent>(caller),
                recipient_events: event::new_event_handle<RecipientsUpdatedEvent>(caller),
                prize_events: event::new_event_handle<PrizePaidEvent>(caller),
                operations_events: event::new_event_handle<OperationsWithdrawnEvent>(caller),
                operations_income_events: event::new_event_handle<OperationsIncomeRecordedEvent>(caller),
                operations_bonus_events: event::new_event_handle<OperationsBonusPaidEvent>(caller),
                jackpot_events: event::new_event_handle<JackpotPaidEvent>(caller),
            },
        );
    }


    public fun is_initialized(): bool {
        exists<TreasuryState>(@lottery)
    }


    public fun admin(): address acquires TreasuryState {
        borrow_state().admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires TreasuryState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
    }


    public entry fun set_recipients(
        caller: &signer,
        jackpot_recipient: address,
        operations_recipient: address,
    ) acquires TreasuryState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        let previous_jackpot = state.jackpot_recipient;
        let previous_operations = state.operations_recipient;
        state.jackpot_recipient = jackpot_recipient;
        state.operations_recipient = operations_recipient;
        event::emit_event(
            &mut state.recipient_events,
            RecipientsUpdatedEvent {
                previous_jackpot,
                previous_operations,
                next_jackpot: jackpot_recipient,
                next_operations: operations_recipient,
            },
        );
    }


    public entry fun upsert_lottery_config(
        caller: &signer,
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ) acquires TreasuryState {
        ensure_admin(caller);
        let config = LotteryShareConfig { prize_bps, jackpot_bps, operations_bps };
        validate_basis_points(&config);
        let state = borrow_state_mut();
        if (table::contains(&state.configs, lottery_id)) {
            let entry = table::borrow_mut(&mut state.configs, lottery_id);
            *entry = config;
        } else {
            record_lottery_id(state, lottery_id);
            table::add(&mut state.configs, lottery_id, config);
        };
        event::emit_event(
            &mut state.config_events,
            LotteryConfigUpdatedEvent {
                lottery_id,
                prize_bps,
                jackpot_bps,
                operations_bps,
            },
        );
    }


    public entry fun record_allocation(
        caller: &signer,
        lottery_id: u64,
        amount: u64,
    ) acquires TreasuryState {
        ensure_admin(caller);
        apply_allocation(borrow_state_mut(), lottery_id, amount);
    }


    public(friend) fun record_allocation_internal(lottery_id: u64, amount: u64) acquires TreasuryState {
        apply_allocation(borrow_state_mut(), lottery_id, amount);
    }


    public(friend) fun migrate_seed_pool(
        lottery_id: u64,
        prize_balance: u64,
        operations_balance: u64,
        jackpot_balance: u64,
    ) acquires TreasuryState {
        let state = borrow_state_mut();
        if (table::contains(&state.pools, lottery_id)) {
            abort E_POOL_ALREADY_EXISTS;
        };
        table::add(
            &mut state.pools,
            lottery_id,
            LotteryPool { prize_balance, operations_balance },
        );
        state.jackpot_balance = state.jackpot_balance + jackpot_balance;
    }


    public entry fun distribute_prize(caller: &signer, lottery_id: u64, winner: address)
    acquires TreasuryState {
        ensure_admin(caller);
        let _ = distribute_prize_internal(lottery_id, winner);
    }


    public(friend) fun distribute_prize_internal(lottery_id: u64, winner: address): u64
    acquires TreasuryState {
        distribute_prize_impl(borrow_state_mut(), lottery_id, winner)
    }


    public entry fun withdraw_operations(caller: &signer, lottery_id: u64)
    acquires TreasuryState {
        ensure_admin(caller);
        let _ = withdraw_operations_internal(lottery_id);
    }


    public(friend) fun withdraw_operations_internal(lottery_id: u64): u64
    acquires TreasuryState {
        withdraw_operations_impl(borrow_state_mut(), lottery_id)
    }


    public(friend) fun pay_operations_bonus_internal(
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) acquires TreasuryState {
        pay_operations_bonus_impl(borrow_state_mut(), lottery_id, recipient, amount);
    }


    public(friend) fun record_operations_income_internal(
        lottery_id: u64,
        amount: u64,
        source: vector<u8>,
    ) acquires TreasuryState {
        if (amount == 0) {
            return;
        };
        let state = borrow_state_mut();
        if (!table::contains(&state.configs, lottery_id)) {
            abort E_CONFIG_MISSING;
        };
        if (table::contains(&state.pools, lottery_id)) {
            let pool = table::borrow_mut(&mut state.pools, lottery_id);
            pool.operations_balance = math64::checked_add(pool.operations_balance, amount);
        } else {
            table::add(
                &mut state.pools,
                lottery_id,
                LotteryPool { prize_balance: 0, operations_balance: amount },
            );
        };
        event::emit_event(
            &mut state.operations_income_events,
            OperationsIncomeRecordedEvent { lottery_id, amount, source },
        );
    }


    public entry fun distribute_jackpot(
        caller: &signer,
        recipient: address,
        amount: u64,
    ) acquires TreasuryState {
        ensure_admin(caller);
        distribute_jackpot_impl(borrow_state_mut(), recipient, amount);
    }


    public(friend) fun distribute_jackpot_internal(recipient: address, amount: u64)
    acquires TreasuryState {
        distribute_jackpot_impl(borrow_state_mut(), recipient, amount);
    }


    #[view]
    /// test-view: возвращает (prize_balance, operations_balance) как u128
    public fun get_pool_balances(lottery_id: u64): (u128, u128) acquires TreasuryState {
        let pool_opt = get_pool(lottery_id);
        if (!option::is_some(&pool_opt)) {
            abort E_POOL_MISSING;
        };
        let pool_ref = option::borrow(&pool_opt);
        (
            u128::from_u64(pool_ref.prize_balance),
            u128::from_u64(pool_ref.operations_balance),
        )
    }


    #[view]
    /// test-view: возвращает (prize_bps, jackpot_bps, operations_bps)
    public fun get_share_config(lottery_id: u64): (u64, u64, u64) acquires TreasuryState {
        let config_opt = get_config(lottery_id);
        if (!option::is_some(&config_opt)) {
            abort E_CONFIG_MISSING;
        };
        let config_ref = option::borrow(&config_opt);
        (
            config_ref.prize_bps,
            config_ref.jackpot_bps,
            config_ref.operations_bps,
        )
    }


    #[view]
    public fun get_config(lottery_id: u64): option::Option<LotteryShareConfig> acquires TreasuryState {
        let state = borrow_state();
        if (!table::contains(&state.configs, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.configs, lottery_id))
        }
    }


    #[view]
    public fun get_pool(lottery_id: u64): option::Option<LotteryPool> acquires TreasuryState {
        let state = borrow_state();
        if (!table::contains(&state.pools, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.pools, lottery_id))
        }
    }


    #[view]
    public fun jackpot_balance(): u64 acquires TreasuryState {
        borrow_state().jackpot_balance
    }


    #[view]
    public fun list_lottery_ids(): vector<u64> acquires TreasuryState {
        copy_u64_vector(&borrow_state().lottery_ids)
    }


    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<LotterySummary>
    acquires TreasuryState {
        let state = borrow_state();
        if (!table::contains(&state.configs, lottery_id)) {
            return option::none<LotterySummary>();
        };
        let config = *table::borrow(&state.configs, lottery_id);
        let pool = if (table::contains(&state.pools, lottery_id)) {
            *table::borrow(&state.pools, lottery_id)
        } else {
            LotteryPool { prize_balance: 0, operations_balance: 0 }
        };
        option::some(LotterySummary { config, pool })
    }

    fun validate_basis_points(config: &LotteryShareConfig) {
        let sum = config.prize_bps + config.jackpot_bps + config.operations_bps;
        if (sum != BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_BASIS_POINTS;
        };
    }

    fun apply_allocation(state: &mut TreasuryState, lottery_id: u64, amount: u64) {
        if (!table::contains(&state.configs, lottery_id)) {
            abort E_CONFIG_MISSING;
        };
        let config = *table::borrow(&state.configs, lottery_id);
        let prize_amount = math64::mul_div(amount, config.prize_bps, BASIS_POINT_DENOMINATOR);
        let jackpot_amount = math64::mul_div(amount, config.jackpot_bps, BASIS_POINT_DENOMINATOR);
        let operations_amount = amount - prize_amount - jackpot_amount;

        state.jackpot_balance = state.jackpot_balance + jackpot_amount;
        if (table::contains(&state.pools, lottery_id)) {
            let pool = table::borrow_mut(&mut state.pools, lottery_id);
            pool.prize_balance = pool.prize_balance + prize_amount;
            pool.operations_balance = pool.operations_balance + operations_amount;
        } else {
            table::add(
                &mut state.pools,
                lottery_id,
                LotteryPool { prize_balance: prize_amount, operations_balance: operations_amount },
            );
        };

        event::emit_event(
            &mut state.allocation_events,
            AllocationRecordedEvent {
                lottery_id,
                total_amount: amount,
                prize_amount,
                jackpot_amount,
                operations_amount,
            },
        );
    }

    fun distribute_prize_impl(state: &mut TreasuryState, lottery_id: u64, winner: address): u64 {
        if (!table::contains(&state.pools, lottery_id)) {
            abort E_POOL_MISSING;
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        let amount = pool.prize_balance;
        if (amount == 0) {
            return 0;
        };
        pool.prize_balance = 0;
        treasury_v1::payout_from_treasury(winner, amount);
        event::emit_event(
            &mut state.prize_events,
            PrizePaidEvent { lottery_id, winner, amount },
        );
        amount
    }

    fun withdraw_operations_impl(state: &mut TreasuryState, lottery_id: u64): u64 {
        if (!table::contains(&state.pools, lottery_id)) {
            abort E_POOL_MISSING;
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        let amount = pool.operations_balance;
        if (amount == 0) {
            return 0;
        };
        pool.operations_balance = 0;
        let recipient = state.operations_recipient;
        treasury_v1::payout_from_treasury(recipient, amount);
        event::emit_event(
            &mut state.operations_events,
            OperationsWithdrawnEvent { lottery_id, recipient, amount },
        );
        amount
    }

    fun pay_operations_bonus_impl(
        state: &mut TreasuryState,
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) {
        if (amount == 0) {
            return;
        };
        if (!table::contains(&state.pools, lottery_id)) {
            abort E_POOL_MISSING;
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        if (pool.operations_balance < amount) {
            abort E_INSUFFICIENT_OPERATIONS;
        };
        pool.operations_balance = pool.operations_balance - amount;
        treasury_v1::payout_from_treasury(recipient, amount);
        event::emit_event(
            &mut state.operations_bonus_events,
            OperationsBonusPaidEvent { lottery_id, recipient, amount },
        );
    }

    fun distribute_jackpot_impl(state: &mut TreasuryState, recipient: address, amount: u64) {
        if (amount == 0) {
            return;
        };
        if (amount > state.jackpot_balance) {
            abort E_INSUFFICIENT_JACKPOT;
        };
        state.jackpot_balance = state.jackpot_balance - amount;
        treasury_v1::payout_from_treasury(recipient, amount);
        event::emit_event(
            &mut state.jackpot_events,
            JackpotPaidEvent { recipient, amount },
        );
    }

    fun record_lottery_id(state: &mut TreasuryState, lottery_id: u64) {
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(&state.lottery_ids, idx) == lottery_id) {
                return;
            };
            idx = idx + 1;
        };
        vector::push_back(&mut state.lottery_ids, lottery_id);
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

    fun borrow_state(): &TreasuryState acquires TreasuryState {
        if (!exists<TreasuryState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<TreasuryState>(@lottery)
    }

    fun borrow_state_mut(): &mut TreasuryState acquires TreasuryState {
        if (!exists<TreasuryState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<TreasuryState>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires TreasuryState {
        if (signer::address_of(caller) != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }
}
