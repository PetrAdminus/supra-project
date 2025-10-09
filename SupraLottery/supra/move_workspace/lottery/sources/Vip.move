module lottery::vip {
    friend lottery::rounds;
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;
    use std::math64;
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

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<VipState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            VipState {
                admin: addr,
                lotteries: table::new(),
                lottery_ids: vector::empty(),
                config_events: event::new_event_handle<VipConfigUpdatedEvent>(caller),
                subscribed_events: event::new_event_handle<VipSubscribedEvent>(caller),
                cancelled_events: event::new_event_handle<VipCancelledEvent>(caller),
                bonus_events: event::new_event_handle<VipBonusIssuedEvent>(caller),
            },
        );
    }

    #[view]
    public fun is_initialized(): bool {
        exists<VipState>(@lottery)
    }

    public fun admin(): address acquires VipState {
        borrow_state().admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires VipState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        state.admin = new_admin;
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
            abort E_INVALID_PRICE;
        };
        if (duration_secs == 0) {
            abort E_INVALID_DURATION;
        };
        let state = borrow_state_mut();
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
            return vector::empty<u64>();
        };
        copy_u64_vector(&borrow_state().lottery_ids)
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<VipLotterySummary>
    acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipLotterySummary>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipLotterySummary>();
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        let total_members = vector::length(&lottery.members);
        let now = timestamp::now_seconds();
        let active_members = 0;
        let len = total_members;
        let idx = 0;
        while (idx < len) {
            let member = *vector::borrow(&lottery.members, idx);
            if (table::contains(&lottery.subscriptions, member)) {
                let subscription = table::borrow(&lottery.subscriptions, member);
                if (subscription.expiry_ts > now) {
                    active_members = active_members + 1;
                };
            };
            idx = idx + 1;
        };
        option::some(VipLotterySummary {
            config: lottery.config,
            total_members,
            active_members,
            total_revenue: lottery.total_revenue,
            bonus_tickets_issued: lottery.bonus_tickets_issued,
        })
    }

    #[view]
    public fun list_players(lottery_id: u64): option::Option<vector<address>> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<vector<address>>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<vector<address>>();
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
            return option::none<VipSubscriptionView>();
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipSubscriptionView>();
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            return option::none<VipSubscriptionView>();
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

    public(friend) fun bonus_tickets_for(lottery_id: u64, player: address): u64 acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return 0;
        };
        let state = borrow_state();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return 0;
        };
        let lottery = table::borrow(&state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            return 0;
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
            return;
        };
        let state = borrow_state_mut();
        if (!table::contains(&state.lotteries, lottery_id)) {
            return;
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        lottery.bonus_tickets_issued = math64::checked_add(lottery.bonus_tickets_issued, bonus_tickets);
        event::emit_event(
            &mut state.bonus_events,
            VipBonusIssuedEvent { lottery_id, player, bonus_tickets },
        );
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

    fun subscribe_internal(
        payer: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipState {
        ensure_lottery_known(lottery_id);
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let state = borrow_state_mut();
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
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
        lottery.total_revenue = math64::checked_add(lottery.total_revenue, price);
        let now = timestamp::now_seconds();
        let expiry = math64::checked_add(now, duration_secs);
        let renewed = table::contains(&lottery.subscriptions, player);
        let actual_expiry = expiry;
        if (renewed) {
            let subscription = table::borrow_mut(&mut lottery.subscriptions, player);
            if (subscription.expiry_ts > now) {
                subscription.expiry_ts = math64::checked_add(subscription.expiry_ts, duration_secs);
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
    }

    fun cancel_internal(
        caller_addr: address,
        player: address,
        lottery_id: u64,
    ) acquires VipState {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let state = borrow_state_mut();
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        if (!table::contains(&lottery.subscriptions, player)) {
            abort E_SUBSCRIPTION_NOT_FOUND;
        };
        let caller_is_player = caller_addr == player;
        if (!caller_is_player && caller_addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
        let subscription = table::borrow_mut(&mut lottery.subscriptions, player);
        subscription.expiry_ts = timestamp::now_seconds();
        subscription.bonus_tickets = 0;
        event::emit_event(
            &mut state.cancelled_events,
            VipCancelledEvent { lottery_id, player },
        );
    }

    fun ensure_lottery_known(lottery_id: u64) {
        if (!instances::contains_instance(lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return;
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
                return;
            };
            idx = idx + 1;
        };
        vector::push_back(members, member);
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

    fun borrow_state(): &VipState acquires VipState {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<VipState>(@lottery)
    }

    fun borrow_state_mut(): &mut VipState acquires VipState {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<VipState>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires VipState {
        if (signer::address_of(caller) != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }
}
