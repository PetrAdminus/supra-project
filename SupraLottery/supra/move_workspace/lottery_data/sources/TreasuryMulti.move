module lottery_data::treasury_multi {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_LOTTERY_EXISTS: u64 = 3;
    const E_BALANCE_UNDERFLOW: u64 = 4;
    const E_OVERFLOW: u64 = 5;
    const E_UNKNOWN_LOTTERY: u64 = 6;
    const E_CAP_MISSING: u64 = 7;
    const E_CAP_ALREADY_PRESENT: u64 = 8;
    const E_SCOPE_MISMATCH: u64 = 9;

    const SCOPE_JACKPOT: u64 = 20;
    const SCOPE_REFERRALS: u64 = 21;
    const SCOPE_STORE: u64 = 22;
    const SCOPE_VIP: u64 = 23;

    public struct LegacyMultiTreasuryState has drop, store {
        jackpot_recipient: address,
        operations_recipient: address,
        jackpot_balance: u64,
    }

    public struct LegacyMultiTreasuryLottery has drop, store {
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
        prize_balance: u64,
        operations_balance: u64,
    }

    struct LotteryShareConfig has copy, drop, store {
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    }

    struct LotteryPool has copy, drop, store {
        prize_balance: u64,
        operations_balance: u64,
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

    struct MultiTreasuryCap has store {
        scope: u64,
    }

    struct TreasuryMultiControl has key {
        admin: address,
        jackpot_cap: option::Option<MultiTreasuryCap>,
        referrals_cap: option::Option<MultiTreasuryCap>,
        store_cap: option::Option<MultiTreasuryCap>,
        vip_cap: option::Option<MultiTreasuryCap>,
    }

    public entry fun import_existing_state(caller: &signer, payload: LegacyMultiTreasuryState)
    acquires TreasuryState {
        ensure_admin_signer(caller);
        apply_legacy_state(payload);
    }

    public entry fun import_existing_lottery(caller: &signer, record: LegacyMultiTreasuryLottery)
    acquires TreasuryState {
        ensure_admin_signer(caller);
        upsert_legacy_lottery(record);
    }

    public entry fun import_existing_lotteries(
        caller: &signer,
        mut records: vector<LegacyMultiTreasuryLottery>,
    ) acquires TreasuryState {
        ensure_admin_signer(caller);
        import_existing_lotteries_recursive(&mut records);
    }

    public entry fun init_state(
        caller: &signer,
        jackpot_recipient: address,
        operations_recipient: address,
    ) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<TreasuryState>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            TreasuryState {
                admin: caller_address,
                jackpot_recipient,
                operations_recipient,
                jackpot_balance: 0,
                configs: table::new<u64, LotteryShareConfig>(),
                pools: table::new<u64, LotteryPool>(),
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
            },
        );
    }

    public entry fun init_control(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<TreasuryMultiControl>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            TreasuryMultiControl {
                admin: caller_address,
                jackpot_cap: option::none<MultiTreasuryCap>(),
                referrals_cap: option::none<MultiTreasuryCap>(),
                store_cap: option::none<MultiTreasuryCap>(),
                vip_cap: option::none<MultiTreasuryCap>(),
            },
        );
    }

    public fun borrow_state(addr: address): &TreasuryState acquires TreasuryState {
        borrow_global<TreasuryState>(addr)
    }

    public fun borrow_state_mut(addr: address): &mut TreasuryState acquires TreasuryState {
        borrow_global_mut<TreasuryState>(addr)
    }

    public fun borrow_control(addr: address): &TreasuryMultiControl acquires TreasuryMultiControl {
        borrow_global<TreasuryMultiControl>(addr)
    }

    public fun borrow_control_mut(addr: address): &mut TreasuryMultiControl acquires TreasuryMultiControl {
        borrow_global_mut<TreasuryMultiControl>(addr)
    }

    #[view]
    public fun scope_jackpot(): u64 { SCOPE_JACKPOT }

    #[view]
    public fun scope_referrals(): u64 { SCOPE_REFERRALS }

    #[view]
    public fun scope_store(): u64 { SCOPE_STORE }

    #[view]
    public fun scope_vip(): u64 { SCOPE_VIP }

    public fun extract_jackpot_cap(control: &mut TreasuryMultiControl): option::Option<MultiTreasuryCap> {
        extract_cap(control, SCOPE_JACKPOT)
    }

    public fun extract_referrals_cap(control: &mut TreasuryMultiControl): option::Option<MultiTreasuryCap> {
        extract_cap(control, SCOPE_REFERRALS)
    }

    public fun extract_store_cap(control: &mut TreasuryMultiControl): option::Option<MultiTreasuryCap> {
        extract_cap(control, SCOPE_STORE)
    }

    public fun extract_vip_cap(control: &mut TreasuryMultiControl): option::Option<MultiTreasuryCap> {
        extract_cap(control, SCOPE_VIP)
    }

    public fun restore_jackpot_cap(control: &mut TreasuryMultiControl, cap: MultiTreasuryCap) {
        restore_cap(control, cap, SCOPE_JACKPOT);
    }

    public fun restore_referrals_cap(control: &mut TreasuryMultiControl, cap: MultiTreasuryCap) {
        restore_cap(control, cap, SCOPE_REFERRALS);
    }

    public fun restore_store_cap(control: &mut TreasuryMultiControl, cap: MultiTreasuryCap) {
        restore_cap(control, cap, SCOPE_STORE);
    }

    public fun restore_vip_cap(control: &mut TreasuryMultiControl, cap: MultiTreasuryCap) {
        restore_cap(control, cap, SCOPE_VIP);
    }

    public fun has_scope_cap(control: &TreasuryMultiControl, scope: u64): bool {
        option::is_some(cap_slot(control, scope))
    }

    public fun ensure_scope(cap: &MultiTreasuryCap, expected: u64) {
        assert!(cap.scope == expected, E_SCOPE_MISMATCH);
    }

    public fun ensure_scope_for_operations_income(cap: &MultiTreasuryCap) {
        let scope = cap.scope;
        assert!(scope == SCOPE_STORE || scope == SCOPE_VIP, E_SCOPE_MISMATCH);
    }

    public fun admin(state: &TreasuryState): address {
        state.admin
    }

    public fun set_admin(state: &mut TreasuryState, new_admin: address) {
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
    }

    public fun jackpot_recipient(state: &TreasuryState): address {
        state.jackpot_recipient
    }

    public fun operations_recipient(state: &TreasuryState): address {
        state.operations_recipient
    }

    public fun set_recipients(
        state: &mut TreasuryState,
        jackpot_recipient: address,
        operations_recipient: address,
    ) {
        let previous_jackpot = RecipientStatus {
            recipient: state.jackpot_recipient,
            registered: true,
            frozen: false,
            store: option::none<address>(),
            balance: 0,
        };
        let previous_operations = RecipientStatus {
            recipient: state.operations_recipient,
            registered: true,
            frozen: false,
            store: option::none<address>(),
            balance: 0,
        };

        state.jackpot_recipient = jackpot_recipient;
        state.operations_recipient = operations_recipient;

        event::emit_event(
            &mut state.recipient_events,
            RecipientsUpdatedEvent {
                previous_jackpot: option::some(previous_jackpot),
                previous_operations: option::some(previous_operations),
                next_jackpot: RecipientStatus {
                    recipient: jackpot_recipient,
                    registered: true,
                    frozen: false,
                    store: option::none<address>(),
                    balance: 0,
                },
                next_operations: RecipientStatus {
                    recipient: operations_recipient,
                    registered: true,
                    frozen: false,
                    store: option::none<address>(),
                    balance: 0,
                },
            },
        );
    }

    public fun ensure_lottery(state: &mut TreasuryState, lottery_id: u64) {
        if (!table::contains(&state.configs, lottery_id)) {
            table::add(
                &mut state.configs,
                lottery_id,
                LotteryShareConfig {
                    prize_bps: 0,
                    jackpot_bps: 0,
                    operations_bps: 0,
                },
            );
            table::add(
                &mut state.pools,
                lottery_id,
                LotteryPool { prize_balance: 0, operations_balance: 0 },
            );
            vector::push_back(&mut state.lottery_ids, lottery_id);
        };
    }

    public fun config(state: &TreasuryState, lottery_id: u64): &LotteryShareConfig {
        assert!(table::contains(&state.configs, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow(&state.configs, lottery_id)
    }

    public fun config_mut(state: &mut TreasuryState, lottery_id: u64): &mut LotteryShareConfig {
        assert!(table::contains(&state.configs, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow_mut(&mut state.configs, lottery_id)
    }

    public fun pool(state: &TreasuryState, lottery_id: u64): &LotteryPool {
        assert!(table::contains(&state.pools, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow(&state.pools, lottery_id)
    }

    public fun pool_mut(state: &mut TreasuryState, lottery_id: u64): &mut LotteryPool {
        assert!(table::contains(&state.pools, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow_mut(&mut state.pools, lottery_id)
    }

    #[view]
    public fun operations_balance(state: &TreasuryState, lottery_id: u64): u64 {
        let record = pool(state, lottery_id);
        record.operations_balance
    }

    public fun share_config(state: &TreasuryState, lottery_id: u64): (u64, u64, u64) {
        let record = config(state, lottery_id);
        (record.prize_bps, record.jackpot_bps, record.operations_bps)
    }

    public fun update_config(
        state: &mut TreasuryState,
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ) {
        ensure_lottery(state, lottery_id);
        let record = config_mut(state, lottery_id);
        record.prize_bps = prize_bps;
        record.jackpot_bps = jackpot_bps;
        record.operations_bps = operations_bps;
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

    public fun record_allocation(
        state: &mut TreasuryState,
        lottery_id: u64,
        total_amount: u64,
        prize_amount: u64,
        jackpot_amount: u64,
        operations_amount: u64,
    ) {
        ensure_lottery(state, lottery_id);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.prize_balance = add(pool_record.prize_balance, prize_amount);
        pool_record.operations_balance = add(pool_record.operations_balance, operations_amount);
        state.jackpot_balance = add(state.jackpot_balance, jackpot_amount);
        event::emit_event(
            &mut state.allocation_events,
            AllocationRecordedEvent {
                lottery_id,
                total_amount,
                prize_amount,
                jackpot_amount,
                operations_amount,
            },
        );
    }

    public fun record_prize_payout(state: &mut TreasuryState, lottery_id: u64, winner: address, amount: u64) {
        ensure_lottery(state, lottery_id);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.prize_balance = subtract(pool_record.prize_balance, amount);
        event::emit_event(
            &mut state.prize_events,
            PrizePaidEvent { lottery_id, winner, amount },
        );
    }

    public fun record_operations_withdrawal(
        state: &mut TreasuryState,
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) {
        ensure_lottery(state, lottery_id);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.operations_balance = subtract(pool_record.operations_balance, amount);
        event::emit_event(
            &mut state.operations_events,
            OperationsWithdrawnEvent { lottery_id, recipient, amount },
        );
    }

    public fun record_operations_income(state: &mut TreasuryState, lottery_id: u64, amount: u64, source: vector<u8>) {
        ensure_lottery(state, lottery_id);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.operations_balance = add(pool_record.operations_balance, amount);
        event::emit_event(
            &mut state.operations_income_events,
            OperationsIncomeRecordedEvent { lottery_id, amount, source },
        );
    }

    public fun record_operations_bonus(
        state: &mut TreasuryState,
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) {
        ensure_lottery(state, lottery_id);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.operations_balance = subtract(pool_record.operations_balance, amount);
        event::emit_event(
            &mut state.operations_bonus_events,
            OperationsBonusPaidEvent { lottery_id, recipient, amount },
        );
    }

    public fun record_operations_income_with_cap(
        state: &mut TreasuryState,
        cap: &MultiTreasuryCap,
        lottery_id: u64,
        amount: u64,
        source: vector<u8>,
    ) {
        ensure_scope_for_operations_income(cap);
        record_operations_income(state, lottery_id, amount, source);
    }

    public fun record_jackpot_payment(state: &mut TreasuryState, recipient: address, amount: u64) {
        state.jackpot_balance = subtract(state.jackpot_balance, amount);
        event::emit_event(
            &mut state.jackpot_events,
            JackpotPaidEvent { recipient, amount },
        );
    }

    public fun jackpot_balance(state: &TreasuryState): u64 {
        state.jackpot_balance
    }

    fun extract_cap(control: &mut TreasuryMultiControl, scope: u64): option::Option<MultiTreasuryCap> {
        let slot = cap_slot_mut(control, scope);
        if (!option::is_some(slot)) {
            option::none<MultiTreasuryCap>()
        } else {
            option::some(option::extract(slot))
        }
    }

    fun restore_cap(control: &mut TreasuryMultiControl, cap: MultiTreasuryCap, scope: u64) {
        ensure_scope(&cap, scope);
        let slot = cap_slot_mut(control, scope);
        if (option::is_some(slot)) {
            abort E_CAP_ALREADY_PRESENT;
        };
        option::fill(slot, cap);
    }

    fun cap_slot(control: &TreasuryMultiControl, scope: u64): &option::Option<MultiTreasuryCap> {
        if (scope == SCOPE_JACKPOT) {
            &control.jackpot_cap
        } else if (scope == SCOPE_REFERRALS) {
            &control.referrals_cap
        } else if (scope == SCOPE_STORE) {
            &control.store_cap
        } else if (scope == SCOPE_VIP) {
            &control.vip_cap
        } else {
            abort E_CAP_MISSING
        }
    }

    fun cap_slot_mut(control: &mut TreasuryMultiControl, scope: u64): &mut option::Option<MultiTreasuryCap> {
        if (scope == SCOPE_JACKPOT) {
            &mut control.jackpot_cap
        } else if (scope == SCOPE_REFERRALS) {
            &mut control.referrals_cap
        } else if (scope == SCOPE_STORE) {
            &mut control.store_cap
        } else if (scope == SCOPE_VIP) {
            &mut control.vip_cap
        } else {
            abort E_CAP_MISSING
        }
    }

    fun import_existing_lotteries_recursive(records: &mut vector<LegacyMultiTreasuryLottery>)
    acquires TreasuryState {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        import_existing_lotteries_recursive(records);
        upsert_legacy_lottery(record);
    }

    fun upsert_legacy_lottery(record: LegacyMultiTreasuryLottery) acquires TreasuryState {
        let LegacyMultiTreasuryLottery {
            lottery_id,
            prize_bps,
            jackpot_bps,
            operations_bps,
            prize_balance,
            operations_balance,
        } = record;
        let state = borrow_state_mut(@lottery);
        update_config(state, lottery_id, prize_bps, jackpot_bps, operations_bps);
        let pool_record = pool_mut(state, lottery_id);
        pool_record.prize_balance = prize_balance;
        pool_record.operations_balance = operations_balance;
        event::emit_event(
            &mut state.allocation_events,
            AllocationRecordedEvent {
                lottery_id,
                total_amount: add(prize_balance, operations_balance),
                prize_amount: prize_balance,
                jackpot_amount: 0,
                operations_amount: operations_balance,
            },
        );
    }

    fun apply_legacy_state(payload: LegacyMultiTreasuryState) acquires TreasuryState {
        let LegacyMultiTreasuryState {
            jackpot_recipient,
            operations_recipient,
            jackpot_balance,
        } = payload;
        let state = borrow_state_mut(@lottery);
        set_recipients(state, jackpot_recipient, operations_recipient);
        state.jackpot_balance = jackpot_balance;
    }

    fun ensure_admin_signer(caller: &signer) acquires TreasuryState {
        let state = borrow_state(@lottery);
        if (signer::address_of(caller) != state.admin) {
            abort E_UNAUTHORIZED;
        };
    }

    fun add(current: u64, amount: u64): u64 {
        let sum = (current as u128) + (amount as u128);
        assert!(sum <= 18446744073709551615, E_OVERFLOW);
        sum as u64
    }

    fun subtract(current: u64, amount: u64): u64 {
        assert!(current >= amount, E_BALANCE_UNDERFLOW);
        current - amount
    }
}
