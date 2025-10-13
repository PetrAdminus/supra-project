module lottery::treasury_multi {
    friend lottery::jackpot;
    friend lottery::migration;
    friend lottery::referrals;
    friend lottery::rounds;
    friend lottery::store;
    friend lottery::treasury_multi_tests;
    friend lottery::vip;

    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
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
    const E_TREASURY_NOT_READY: u64 = 10;
    const E_JACKPOT_RECIPIENT_UNREGISTERED: u64 = 11;
    const E_OPERATIONS_RECIPIENT_UNREGISTERED: u64 = 12;
    const E_JACKPOT_RECIPIENT_FROZEN: u64 = 13;
    const E_OPERATIONS_RECIPIENT_FROZEN: u64 = 14;
    const E_BONUS_RECIPIENT_UNREGISTERED: u64 = 15;
    const E_BONUS_RECIPIENT_FROZEN: u64 = 16;
    const E_JACKPOT_WINNER_UNREGISTERED: u64 = 17;
    const E_JACKPOT_WINNER_FROZEN: u64 = 18;
    const E_ARITHMETIC_OVERFLOW: u64 = 19;

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

    struct RecipientStatus has copy, drop, store {
        recipient: address,
        registered: bool,
        frozen: bool,
        store: option::Option<address>,
        balance: u64,
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
        previous_jackpot: option::Option<RecipientStatus>,
        previous_operations: option::Option<RecipientStatus>,
        next_jackpot: RecipientStatus,
        next_operations: RecipientStatus,
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
        ensure_treasury_ready();
        ensure_recipient_ready_for_payout(
            jackpot_recipient,
            E_JACKPOT_RECIPIENT_UNREGISTERED,
            E_JACKPOT_RECIPIENT_FROZEN,
        );
        ensure_recipient_ready_for_payout(
            operations_recipient,
            E_OPERATIONS_RECIPIENT_UNREGISTERED,
            E_OPERATIONS_RECIPIENT_FROZEN,
        );
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<TreasuryState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        let state = TreasuryState {
            admin: addr,
            jackpot_recipient,
            operations_recipient,
            jackpot_balance: 0,
            configs: table::new(),
            pools: table::new(),
            lottery_ids: vector::empty<u64>(),
            config_events: account::new_event_handle<LotteryConfigUpdatedEvent>(caller),
            allocation_events: account::new_event_handle<AllocationRecordedEvent>(caller),
            admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
            recipient_events: account::new_event_handle<RecipientsUpdatedEvent>(caller),
            prize_events: account::new_event_handle<PrizePaidEvent>(caller),
            operations_events: account::new_event_handle<OperationsWithdrawnEvent>(caller),
            operations_income_events: account::new_event_handle<OperationsIncomeRecordedEvent>(caller),
            operations_bonus_events: account::new_event_handle<OperationsBonusPaidEvent>(caller),
            jackpot_events: account::new_event_handle<JackpotPaidEvent>(caller),
        };

        emit_recipients_event(
            &mut state,
            option::none(),
            option::none(),
        );

        move_to(caller, state);
    }


    public fun is_initialized(): bool {
        exists<TreasuryState>(@lottery)
    }


    public fun admin(): address acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global<TreasuryState>(@lottery);
        state.admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires TreasuryState {
        ensure_admin(caller);
        let state = borrow_global_mut<TreasuryState>(@lottery);
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
        ensure_treasury_ready();
        ensure_recipient_ready_for_payout(
            jackpot_recipient,
            E_JACKPOT_RECIPIENT_UNREGISTERED,
            E_JACKPOT_RECIPIENT_FROZEN,
        );
        ensure_recipient_ready_for_payout(
            operations_recipient,
            E_OPERATIONS_RECIPIENT_UNREGISTERED,
            E_OPERATIONS_RECIPIENT_FROZEN,
        );
        let state = borrow_global_mut<TreasuryState>(@lottery);
        let previous_jackpot = state.jackpot_recipient;
        let previous_operations = state.operations_recipient;
        let previous_jackpot_status = option::some(build_recipient_status(previous_jackpot));
        let previous_operations_status = option::some(build_recipient_status(previous_operations));
        state.jackpot_recipient = jackpot_recipient;
        state.operations_recipient = operations_recipient;
        emit_recipients_event(
            state,
            previous_jackpot_status,
            previous_operations_status,
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
        let state = borrow_global_mut<TreasuryState>(@lottery);
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
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        apply_allocation(state, lottery_id, amount);
    }


    public(friend) fun record_allocation_internal(lottery_id: u64, amount: u64) acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        apply_allocation(state, lottery_id, amount);
    }


    public(friend) fun migrate_seed_pool(
        lottery_id: u64,
        prize_balance: u64,
        operations_balance: u64,
        jackpot_balance: u64,
    ) acquires TreasuryState {
        let state = borrow_global_mut<TreasuryState>(@lottery);
        if (table::contains(&state.pools, lottery_id)) {
            abort E_POOL_ALREADY_EXISTS
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
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        distribute_prize_impl(state, lottery_id, winner)
    }


    public entry fun withdraw_operations(caller: &signer, lottery_id: u64)
    acquires TreasuryState {
        ensure_admin(caller);
        let _ = withdraw_operations_internal(lottery_id);
    }


    fun withdraw_operations_internal(lottery_id: u64): u64
    acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        withdraw_operations_impl(state, lottery_id)
    }


    public(friend) fun pay_operations_bonus_internal(
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        pay_operations_bonus_impl(state, lottery_id, recipient, amount);
    }


    public(friend) fun record_operations_income_internal(
        lottery_id: u64,
        amount: u64,
        source: vector<u8>,
    ) acquires TreasuryState {
        if (amount == 0) {
            return
        };
        let state = borrow_global_mut<TreasuryState>(@lottery);
        if (!table::contains(&state.configs, lottery_id)) {
            abort E_CONFIG_MISSING
        };
        if (table::contains(&state.pools, lottery_id)) {
            let pool = table::borrow_mut(&mut state.pools, lottery_id);
            pool.operations_balance = safe_add(pool.operations_balance, amount);
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
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        distribute_jackpot_impl(state, recipient, amount);
    }


    public(friend) fun distribute_jackpot_internal(recipient: address, amount: u64)
    acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global_mut<TreasuryState>(@lottery);
        distribute_jackpot_impl(state, recipient, amount);
    }


    #[view]
    public fun get_config(lottery_id: u64): option::Option<LotteryShareConfig> acquires TreasuryState {
        let state = borrow_global<TreasuryState>(@lottery);
        if (!table::contains(&state.configs, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.configs, lottery_id))
        }
    }


    #[view]
    public fun get_pool(lottery_id: u64): option::Option<LotteryPool> acquires TreasuryState {
        let state = borrow_global<TreasuryState>(@lottery);
        if (!table::contains(&state.pools, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.pools, lottery_id))
        }
    }

    #[view]
    public fun get_recipients(): (address, address) acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global<TreasuryState>(@lottery);
        (state.jackpot_recipient, state.operations_recipient)
    }


    #[view]
    public fun get_recipient_statuses(): (RecipientStatus, RecipientStatus) acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global<TreasuryState>(@lottery);
        (
            build_recipient_status(state.jackpot_recipient),
            build_recipient_status(state.operations_recipient),
        )
    }


    #[view]
    public fun jackpot_balance(): u64 acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global<TreasuryState>(@lottery);
        state.jackpot_balance
    }


    #[view]
    public fun list_lottery_ids(): vector<u64> acquires TreasuryState {
        ensure_initialized();
        let state = borrow_global<TreasuryState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }


    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<LotterySummary>
    acquires TreasuryState {
        let state = borrow_global<TreasuryState>(@lottery);
        if (!table::contains(&state.configs, lottery_id)) {
            return option::none<LotterySummary>()
        };
        let config = *table::borrow(&state.configs, lottery_id);
        let pool = if (table::contains(&state.pools, lottery_id)) {
            *table::borrow(&state.pools, lottery_id)
        } else {
            LotteryPool { prize_balance: 0, operations_balance: 0 }
        };
        option::some(LotterySummary { config, pool })
    }

    fun pool_prize_balance(pool: &LotteryPool): u64 {
        pool.prize_balance
    }

    public(friend) fun pool_operations_balance(pool: &LotteryPool): u64 {
        pool.operations_balance
    }

    fun share_config_prize_bps(config: &LotteryShareConfig): u64 {
        config.prize_bps
    }

    fun share_config_jackpot_bps(config: &LotteryShareConfig): u64 {
        config.jackpot_bps
    }

    public(friend) fun share_config_operations_bps(config: &LotteryShareConfig): u64 {
        config.operations_bps
    }

    fun summary_config(summary: &LotterySummary): LotteryShareConfig {
        summary.config
    }

    public(friend) fun summary_pool(summary: &LotterySummary): LotteryPool {
        summary.pool
    }

    #[test_only]
    public fun pool_balances_for_test(pool: &LotteryPool): (u64, u64) {
        (pool_prize_balance(pool), pool_operations_balance(pool))
    }

    #[test_only]
    public fun share_config_bps_for_test(config: &LotteryShareConfig): (u64, u64, u64) {
        (
            share_config_prize_bps(config),
            share_config_jackpot_bps(config),
            share_config_operations_bps(config),
        )
    }

    #[test_only]
    public fun summary_components_for_test(summary: &LotterySummary): (LotteryShareConfig, LotteryPool) {
        (summary_config(summary), summary_pool(summary))
    }

    #[test_only]
    public fun recipient_status_fields_for_test(
        status: &RecipientStatus
    ): (address, bool, bool, option::Option<address>, u64) {
        (
            status.recipient,
            status.registered,
            status.frozen,
            status.store,
            status.balance,
        )
    }

    fun validate_basis_points(config: &LotteryShareConfig) {
        let sum = config.prize_bps + config.jackpot_bps + config.operations_bps;
        if (sum != BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_BASIS_POINTS
        };
    }

    fun ensure_recipient_ready_for_payout(
        recipient: address,
        not_registered_error: u64,
        frozen_error: u64,
    ) {
        let (registered, frozen, _store, _balance) = treasury_v1::account_extended_status(recipient);
        assert!(registered, not_registered_error);
        assert!(!frozen, frozen_error);
    }

    fun mul_div(amount: u64, basis_points: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_INVALID_BASIS_POINTS);
        if (amount == 0 || basis_points == 0) {
            return 0
        };

        let quotient = amount / denominator;
        let remainder = amount % denominator;
        let scaled_quotient = safe_mul(quotient, basis_points);
        let scaled_remainder = safe_mul(remainder, basis_points) / denominator;
        safe_add(scaled_quotient, scaled_remainder)
    }

    fun safe_add(lhs: u64, rhs: u64): u64 {
        let sum = lhs + rhs;
        assert!(sum >= lhs, E_ARITHMETIC_OVERFLOW);
        sum
    }

    fun safe_mul(lhs: u64, rhs: u64): u64 {
        if (lhs == 0 || rhs == 0) {
            return 0
        };

        let product = lhs * rhs;
        assert!(product / lhs == rhs, E_ARITHMETIC_OVERFLOW);
        product
    }

    fun apply_allocation(state: &mut TreasuryState, lottery_id: u64, amount: u64) {
        if (!table::contains(&state.configs, lottery_id)) {
            abort E_CONFIG_MISSING
        };
        let config = *table::borrow(&state.configs, lottery_id);
        let prize_amount = mul_div(amount, config.prize_bps, BASIS_POINT_DENOMINATOR);
        let jackpot_amount = mul_div(amount, config.jackpot_bps, BASIS_POINT_DENOMINATOR);
        let operations_amount = amount - prize_amount - jackpot_amount;

        state.jackpot_balance = safe_add(state.jackpot_balance, jackpot_amount);
        if (table::contains(&state.pools, lottery_id)) {
            let pool = table::borrow_mut(&mut state.pools, lottery_id);
            pool.prize_balance = safe_add(pool.prize_balance, prize_amount);
            pool.operations_balance = safe_add(pool.operations_balance, operations_amount);
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
            abort E_POOL_MISSING
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        let amount = pool.prize_balance;
        if (amount == 0) {
            return 0
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
            abort E_POOL_MISSING
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        let amount = pool.operations_balance;
        if (amount == 0) {
            return 0
        };
        let recipient = state.operations_recipient;
        ensure_recipient_ready_for_payout(
            recipient,
            E_OPERATIONS_RECIPIENT_UNREGISTERED,
            E_OPERATIONS_RECIPIENT_FROZEN,
        );
        pool.operations_balance = 0;
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
            return
        };
        if (!table::contains(&state.pools, lottery_id)) {
            abort E_POOL_MISSING
        };
        let pool = table::borrow_mut(&mut state.pools, lottery_id);
        if (pool.operations_balance < amount) {
            abort E_INSUFFICIENT_OPERATIONS
        };
        ensure_recipient_ready_for_payout(
            recipient,
            E_BONUS_RECIPIENT_UNREGISTERED,
            E_BONUS_RECIPIENT_FROZEN,
        );
        pool.operations_balance = pool.operations_balance - amount;
        treasury_v1::payout_from_treasury(recipient, amount);
        event::emit_event(
            &mut state.operations_bonus_events,
            OperationsBonusPaidEvent { lottery_id, recipient, amount },
        );
    }

    fun distribute_jackpot_impl(state: &mut TreasuryState, recipient: address, amount: u64) {
        if (amount == 0) {
            return
        };
        if (amount > state.jackpot_balance) {
            abort E_INSUFFICIENT_JACKPOT
        };
        ensure_recipient_ready_for_payout(
            recipient,
            E_JACKPOT_WINNER_UNREGISTERED,
            E_JACKPOT_WINNER_FROZEN,
        );
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
                return
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

    fun emit_recipients_event(
        state: &mut TreasuryState,
        previous_jackpot: option::Option<RecipientStatus>,
        previous_operations: option::Option<RecipientStatus>,
    ) {
        event::emit_event(
            &mut state.recipient_events,
            RecipientsUpdatedEvent {
                previous_jackpot,
                previous_operations,
                next_jackpot: build_recipient_status(state.jackpot_recipient),
                next_operations: build_recipient_status(state.operations_recipient),
            },
        );
    }

    fun build_recipient_status(recipient: address): RecipientStatus {
        let (registered, frozen, store_opt, balance) =
            treasury_v1::account_extended_status(recipient);
        RecipientStatus { recipient, registered, frozen, store: store_opt, balance }
    }

    #[test_only]
    public fun recipient_event_fields_for_test(
        event: &RecipientsUpdatedEvent
    ): (
        option::Option<RecipientStatus>,
        option::Option<RecipientStatus>,
        RecipientStatus,
        RecipientStatus,
    ) {
        let previous_jackpot = event.previous_jackpot;
        let previous_operations = event.previous_operations;
        let next_jackpot = event.next_jackpot;
        let next_operations = event.next_operations;
        (
            previous_jackpot,
            previous_operations,
            next_jackpot,
            next_operations,
        )
    }

    fun ensure_admin(caller: &signer) acquires TreasuryState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<TreasuryState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_initialized() {
        if (!exists<TreasuryState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun ensure_treasury_ready() {
        if (!treasury_v1::is_initialized()) {
            abort E_TREASURY_NOT_READY
        };
    }

}
