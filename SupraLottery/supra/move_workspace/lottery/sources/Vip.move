module lottery::vip {
    friend lottery::rounds;

    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
    use std::timestamp;
    use lottery::instances;
    use lottery::treasury_multi;
    use lottery::treasury_v1;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;
    const E_INVALID_PRICE: u64 = 5;
    const E_INVALID_DURATION: u64 = 6;
    const E_SUBSCRIPTION_NOT_FOUND: u64 = 7;
    const E_ARITHMETIC_OVERFLOW: u64 = 8;

    const SOURCE_VIP_SUBSCRIPTION: vector<u8> = b"vip_subscription";

    struct VipConfig has copy, drop, store {
        price: u64,
        duration_secs: u64,
        bonus_tickets: u64,
    }

    struct VipSubscription has copy, drop, store {
        expiry_ts: u64,
        bonus_tickets: u64,
    }

    struct VipLottery has store {
        config: VipConfig,
        subscriptions: table::Table<address, VipSubscription>,
        members: vector<address>,
        total_revenue: u64,
        bonus_tickets_issued: u64,
    }

    struct VipState has key {
        admin: address,
        lotteries: table::Table<u64, VipLottery>,
        lottery_ids: vector<u64>,
        config_events: event::EventHandle<VipConfigUpdatedEvent>,
        subscribed_events: event::EventHandle<VipSubscribedEvent>,
        cancelled_events: event::EventHandle<VipCancelledEvent>,
        bonus_events: event::EventHandle<VipBonusIssuedEvent>,
        snapshot_events: event::EventHandle<VipSnapshotUpdatedEvent>,
    }

    #[event]
    struct VipConfigUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        price: u64,
        duration_secs: u64,
        bonus_tickets: u64,
    }

    #[event]
    struct VipSubscribedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        expiry_ts: u64,
        bonus_tickets: u64,
        amount_paid: u64,
        renewed: bool,
    }

    #[event]
    struct VipCancelledEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
    }

    #[event]
    struct VipBonusIssuedEvent has drop, store, copy {
        lottery_id: u64,
        player: address,
        bonus_tickets: u64,
    }

    struct VipLotterySnapshot has copy, drop, store {
        lottery_id: u64,
        config: VipConfig,
        total_members: u64,
        active_members: u64,
        total_revenue: u64,
        bonus_tickets_issued: u64,
    }

    struct VipSnapshot has copy, drop, store {
        admin: address,
        lotteries: vector<VipLotterySnapshot>,
    }

    #[event]
    struct VipSnapshotUpdatedEvent has drop, store, copy {
        snapshot: VipSnapshot,
    }

    struct VipSubscriptionView has copy, drop, store {
        expiry_ts: u64,
        is_active: bool,
        bonus_tickets: u64,
    }

    struct VipLotterySummary has copy, drop, store {
        config: VipConfig,
        total_members: u64,
        active_members: u64,
        total_revenue: u64,
        bonus_tickets_issued: u64,
    }

    public fun vip_config_price(config: &VipConfig): u64 {
        config.price
    }

    public fun vip_config_duration_secs(config: &VipConfig): u64 {
        config.duration_secs
    }

    public fun vip_config_bonus_tickets(config: &VipConfig): u64 {
        config.bonus_tickets
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<VipState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            VipState {
                admin: addr,
                lotteries: table::new(),
                lottery_ids: vector::empty(),
                config_events: account::new_event_handle<VipConfigUpdatedEvent>(caller),
                subscribed_events: account::new_event_handle<VipSubscribedEvent>(caller),
                cancelled_events: account::new_event_handle<VipCancelledEvent>(caller),
                bonus_events: account::new_event_handle<VipBonusIssuedEvent>(caller),
                snapshot_events: account::new_event_handle<VipSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<VipState>(@lottery);
        emit_vip_snapshot(state);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<VipState>(@lottery)
    }

    public fun admin(): address acquires VipState {
        ensure_initialized();
        let state = borrow_global<VipState>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires VipState {
        ensure_admin(caller);
        let state = borrow_global_mut<VipState>(@lottery);
        state.admin = new_admin;
        emit_vip_snapshot(state);
    }

    public entry fun upsert_config(
        caller: &signer,
        lottery_id: u64,
        price: u64,
        duration_secs: u64,
        bonus_tickets: u64,
    ) acquires VipState {
        ensure_admin(caller);
        ensure_lottery_known(lottery_id);
        if (price == 0) {
            abort E_INVALID_PRICE
        };
        if (duration_secs == 0) {
            abort E_INVALID_DURATION
        };
        let state = borrow_global_mut<VipState>(@lottery);
        let config = VipConfig { price, duration_secs, bonus_tickets };
        if (table::contains(&state.lotteries, lottery_id)) {
            let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
            lottery.config = config;
        } else {
            table::add(
                &mut state.lotteries,
                lottery_id,
                VipLottery {
                    config,
                    subscriptions: table::new(),
                    members: vector::empty(),
                    total_revenue: 0,
                    bonus_tickets_issued: 0,
                },
            );
            record_lottery_id(&mut state.lottery_ids, lottery_id);
        };
        event::emit_event(
            &mut state.config_events,
            VipConfigUpdatedEvent { lottery_id, price, duration_secs, bonus_tickets },
        );
        emit_vip_snapshot(state);
    }

    public entry fun subscribe(caller: &signer, lottery_id: u64)
    acquires VipState {
        let player = signer::address_of(caller);
        subscribe_internal(caller, lottery_id, player);
    }

    public entry fun subscribe_for(
        caller: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipState {
        ensure_admin(caller);
        subscribe_internal(caller, lottery_id, player);
    }

    public entry fun cancel(caller: &signer, lottery_id: u64) acquires VipState {
        let player = signer::address_of(caller);
        cancel_internal(player, player, lottery_id);
    }

    public entry fun cancel_for(
        caller: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipState {
        ensure_admin(caller);
        cancel_internal(signer::address_of(caller), player, lottery_id);
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<VipState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<VipLotterySummary>
    acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipLotterySummary>()
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipLotterySummary>()
        };
        let snapshot = build_lottery_snapshot_for_view(state, lottery_id);
        let VipLotterySnapshot {
            lottery_id: _ignored,
            config,
            total_members,
            active_members,
            total_revenue,
            bonus_tickets_issued,
        } = snapshot;
        option::some(VipLotterySummary {
            config,
            total_members,
            active_members,
            total_revenue,
            bonus_tickets_issued,
        })
    }

    #[view]
    public fun list_players(lottery_id: u64): option::Option<vector<address>> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<vector<address>>()
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<vector<address>>()
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        option::some(copy_address_vector(&lottery.members))
    }

    #[view]
    public fun get_subscription(
        lottery_id: u64,
        player: address,
    ): option::Option<VipSubscriptionView> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipSubscriptionView>()
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipSubscriptionView>()
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            return option::none<VipSubscriptionView>()
        };
        let subscription = table::borrow(&lottery.subscriptions, player);
        let now = timestamp::now_seconds();
        let is_active = subscription.expiry_ts > now;
        option::some(VipSubscriptionView {
            expiry_ts: subscription.expiry_ts,
            is_active,
            bonus_tickets: subscription.bonus_tickets,
        })
    }

    #[view]
    public fun get_lottery_snapshot(
        lottery_id: u64,
    ): option::Option<VipLotterySnapshot> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipLotterySnapshot>()
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipLotterySnapshot>()
        };
        option::some(build_lottery_snapshot_for_view(state, lottery_id))
    }

    #[view]
    public fun get_vip_snapshot(): option::Option<VipSnapshot> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipSnapshot>()
        };
        let state = borrow_global<VipState>(@lottery);
        option::some(build_vip_snapshot(state))
    }

    public(friend) fun bonus_tickets_for(lottery_id: u64, player: address): u64 acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return 0
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return 0
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            return 0
        };
        let subscription = table::borrow(&lottery.subscriptions, player);
        let now = timestamp::now_seconds();
        if (subscription.expiry_ts <= now) {
            0
        } else {
            subscription.bonus_tickets
        }
    }

    public(friend) fun record_bonus_usage(
        lottery_id: u64,
        player: address,
        bonus_tickets: u64,
    ) acquires VipState {
        if (bonus_tickets == 0 || !exists<VipState>(@lottery)) {
            return
        };
        let state = borrow_global_mut<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        lottery.bonus_tickets_issued = safe_add(lottery.bonus_tickets_issued, bonus_tickets);
        event::emit_event(
            &mut state.bonus_events,
            VipBonusIssuedEvent { lottery_id, player, bonus_tickets },
        );
        emit_vip_snapshot(state);
    }

    #[test_only]
    public fun subscription_fields_for_test(
        subscription: &VipSubscriptionView
    ): (u64, bool, u64) {
        (subscription.expiry_ts, subscription.is_active, subscription.bonus_tickets)
    }

    #[test_only]
    public fun summary_fields_for_test(
        summary: &VipLotterySummary
    ): (VipConfig, u64, u64, u64, u64) {
        (summary.config, summary.total_members, summary.active_members, summary.total_revenue, summary.bonus_tickets_issued)
    }

    #[test_only]
    public fun vip_snapshot_fields_for_test(
        snapshot: &VipSnapshot
    ): (address, vector<VipLotterySnapshot>) {
        (snapshot.admin, copy_vip_lottery_snapshots(&snapshot.lotteries))
    }

    #[test_only]
    public fun vip_lottery_snapshot_fields_for_test(
        snapshot: &VipLotterySnapshot
    ): (u64, VipConfig, u64, u64, u64, u64) {
        (
            snapshot.lottery_id,
            snapshot.config,
            snapshot.total_members,
            snapshot.active_members,
            snapshot.total_revenue,
            snapshot.bonus_tickets_issued,
        )
    }

    #[test_only]
    public fun vip_snapshot_event_fields_for_test(
        event: &VipSnapshotUpdatedEvent
    ): (address, vector<VipLotterySnapshot>) {
        vip_snapshot_fields_for_test(&event.snapshot)
    }

    fun subscribe_internal(
        payer: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipState {
        ensure_lottery_known(lottery_id);
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global_mut<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        let config_snapshot = lottery.config;
        let price = config_snapshot.price;
        let duration_secs = config_snapshot.duration_secs;
        let bonus_tickets = config_snapshot.bonus_tickets;
        treasury_v1::deposit_from_user(payer, price);
        treasury_multi::record_operations_income_internal(
            lottery_id,
            price,
            SOURCE_VIP_SUBSCRIPTION,
        );
        lottery.total_revenue = safe_add(lottery.total_revenue, price);
        let now = timestamp::now_seconds();
        let expiry = safe_add(now, duration_secs);
        let renewed = table::contains(&lottery.subscriptions, player);
        let actual_expiry = expiry;
        if (renewed) {
            let subscription = table::borrow_mut(&mut lottery.subscriptions, player);
            if (subscription.expiry_ts > now) {
                subscription.expiry_ts = safe_add(subscription.expiry_ts, duration_secs);
            } else {
                subscription.expiry_ts = expiry;
            };
            subscription.bonus_tickets = bonus_tickets;
            actual_expiry = subscription.expiry_ts;
        } else {
            table::add(
                &mut lottery.subscriptions,
                player,
                VipSubscription { expiry_ts: expiry, bonus_tickets },
            );
            record_member(&mut lottery.members, player);
        };
        event::emit_event(
            &mut state.subscribed_events,
            VipSubscribedEvent {
                lottery_id,
                player,
                expiry_ts: actual_expiry,
                bonus_tickets,
                amount_paid: price,
                renewed,
            },
        );
        emit_vip_snapshot(state);
    }

    fun cancel_internal(
        caller_addr: address,
        player: address,
        lottery_id: u64,
    ) acquires VipState {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global_mut<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            abort E_SUBSCRIPTION_NOT_FOUND
        };
        let caller_is_player = caller_addr == player;
        if (!caller_is_player && caller_addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
        let subscription = table::borrow_mut(&mut lottery.subscriptions, player);
        subscription.expiry_ts = timestamp::now_seconds();
        subscription.bonus_tickets = 0;
        event::emit_event(
            &mut state.cancelled_events,
            VipCancelledEvent { lottery_id, player },
        );
        emit_vip_snapshot(state);
    }

    fun emit_vip_snapshot(state: &mut VipState) {
        let snapshot = build_vip_snapshot(&*state);
        event::emit_event(
            &mut state.snapshot_events,
            VipSnapshotUpdatedEvent { snapshot },
        );
    }

    fun build_vip_snapshot(state: &VipState): VipSnapshot {
        let now = timestamp::now_seconds();
        VipSnapshot {
            admin: state.admin,
            lotteries: build_all_lottery_snapshots(state, now),
        }
    }

    fun build_all_lottery_snapshots(
        state: &VipState,
        now: u64,
    ): vector<VipLotterySnapshot> {
        let snapshots = vector::empty<VipLotterySnapshot>();
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.lotteries, lottery_id)) {
                let snapshot = build_lottery_snapshot_with_now(state, lottery_id, now);
                vector::push_back(&mut snapshots, snapshot);
            };
            idx = idx + 1;
        };
        snapshots
    }

    fun build_lottery_snapshot_for_view(
        state: &VipState,
        lottery_id: u64,
    ): VipLotterySnapshot {
        let now = timestamp::now_seconds();
        build_lottery_snapshot_with_now(state, lottery_id, now)
    }

    fun build_lottery_snapshot_with_now(
        state: &VipState,
        lottery_id: u64,
        now: u64,
    ): VipLotterySnapshot {
        let lottery = table::borrow(&state.lotteries, lottery_id);
        build_lottery_snapshot_internal(lottery_id, lottery, now)
    }

    fun build_lottery_snapshot_internal(
        lottery_id: u64,
        lottery: &VipLottery,
        now: u64,
    ): VipLotterySnapshot {
        let total_members = vector::length(&lottery.members);
        let active_members = count_active_members(&lottery.subscriptions, &lottery.members, now);
        VipLotterySnapshot {
            lottery_id,
            config: lottery.config,
            total_members,
            active_members,
            total_revenue: lottery.total_revenue,
            bonus_tickets_issued: lottery.bonus_tickets_issued,
        }
    }

    fun count_active_members(
        subscriptions: &table::Table<address, VipSubscription>,
        members: &vector<address>,
        now: u64,
    ): u64 {
        let len = vector::length(members);
        let idx = 0;
        let active_members = 0;
        while (idx < len) {
            let member = *vector::borrow(members, idx);
            if (table::contains(subscriptions, member)) {
                let subscription = table::borrow(subscriptions, member);
                if (subscription.expiry_ts > now) {
                    active_members = active_members + 1;
                };
            };
            idx = idx + 1;
        };
        active_members
    }

    fun ensure_lottery_known(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(ids, lottery_id);
    }

    fun record_member(members: &mut vector<address>, member: address) {
        let len = vector::length(members);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(members, idx) == member) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(members, member);
    }

    fun safe_add(lhs: u64, rhs: u64): u64 {
        let sum = lhs + rhs;
        assert!(sum >= lhs, E_ARITHMETIC_OVERFLOW);
        sum
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

    fun copy_vip_lottery_snapshots(
        values: &vector<VipLotterySnapshot>
    ): vector<VipLotterySnapshot> {
        let out = vector::empty<VipLotterySnapshot>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun ensure_admin(caller: &signer) acquires VipState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<VipState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_initialized() {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }
}
