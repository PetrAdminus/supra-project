module lottery_rewards_engine::vip {
    use std::option;
    use std::signer;
    use std::timestamp;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use lottery_data::treasury;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

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

    /// Переносимые контейнеры не читают данные напрямую из легаси-пакетов —
    /// скрипты миграции формируют payload оффчейн (из архивов devnet/testnet,
    /// снапшотов dry-run либо ручных констант) и подают его в import-entry,
    /// чтобы развернуть состояние без повторного списания средств.
    public struct LegacyVipSubscription has drop, store {
        player: address,
        expiry_ts: u64,
        bonus_tickets: u64,
    }

    public struct LegacyVipLottery has drop, store {
        lottery_id: u64,
        config: VipConfig,
        total_revenue: u64,
        bonus_tickets_issued: u64,
        members: vector<address>,
        subscriptions: vector<LegacyVipSubscription>,
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

    struct VipAccess has key {
        cap: treasury_multi::MultiTreasuryCap,
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

    public entry fun init(caller: &signer)
    acquires VipAccess, VipState, treasury_multi::TreasuryMultiControl {
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
                lotteries: table::new<u64, VipLottery>(),
                lottery_ids: vector::empty<u64>(),
                config_events: account::new_event_handle<VipConfigUpdatedEvent>(caller),
                subscribed_events: account::new_event_handle<VipSubscribedEvent>(caller),
                cancelled_events: account::new_event_handle<VipCancelledEvent>(caller),
                bonus_events: account::new_event_handle<VipBonusIssuedEvent>(caller),
                snapshot_events: account::new_event_handle<VipSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<VipState>(@lottery);
        emit_vip_snapshot(state);
        ensure_caps_initialized(caller);
    }

    public entry fun init_access(caller: &signer)
    acquires VipAccess, treasury_multi::TreasuryMultiControl, VipState {
        ensure_admin(caller);
        ensure_caps_initialized(caller);
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

    public entry fun import_existing_lottery(caller: &signer, lottery: LegacyVipLottery)
    acquires VipState {
        ensure_admin(caller);
        upsert_legacy_lottery(lottery);
    }

    public entry fun import_existing_lotteries(
        caller: &signer,
        mut lotteries: vector<LegacyVipLottery>,
    ) acquires VipState {
        ensure_admin(caller);
        import_existing_lotteries_recursive(&mut lotteries);
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
                    subscriptions: table::new<address, VipSubscription>(),
                    members: vector::empty<address>(),
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
    acquires VipAccess, VipState, treasury_multi::TreasuryMultiControl, treasury_multi::TreasuryState {
        let player = signer::address_of(caller);
        subscribe_internal(caller, lottery_id, player);
    }

    public entry fun subscribe_for(
        caller: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipAccess, VipState, treasury_multi::TreasuryMultiControl, treasury_multi::TreasuryState {
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
        let state = borrow_global<VipState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_lottery_summary(lottery_id: u64): option::Option<VipLotterySummary>
    acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipLotterySummary>();
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipLotterySummary>();
        };
        let snapshot = build_lottery_snapshot_for_view(&state, lottery_id);
        let VipLotterySnapshot {
            lottery_id: _,
            config,
            total_members,
            active_members,
            total_revenue,
            bonus_tickets_issued,
        } = snapshot;
        option::some(VipLotterySummary { config, total_members, active_members, total_revenue, bonus_tickets_issued })
    }

    #[view]
    public fun list_players(lottery_id: u64): option::Option<vector<address>> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<vector<address>>();
        };
        let state = borrow_global<VipState>(@lottery);
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
        let state = borrow_global<VipState>(@lottery);
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

    #[view]
    public fun get_lottery_snapshot(
        lottery_id: u64,
    ): option::Option<VipLotterySnapshot> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipLotterySnapshot>();
        };
        let state = borrow_global<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VipLotterySnapshot>();
        };
        option::some(build_lottery_snapshot_for_view(&state, lottery_id))
    }

    #[view]
    public fun get_vip_snapshot(): option::Option<VipSnapshot> acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return option::none<VipSnapshot>();
        };
        let state = borrow_global<VipState>(@lottery);
        option::some(build_vip_snapshot(&state))
    }

    public fun bonus_tickets_for(lottery_id: u64, player: address): u64 acquires VipState {
        if (!exists<VipState>(@lottery)) {
            return 0;
        };
        let state = borrow_global<VipState>(@lottery);
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

    public fun record_bonus_usage(lottery_id: u64, player: address, bonus_tickets: u64)
    acquires VipState {
        if (bonus_tickets == 0 || !exists<VipState>(@lottery)) {
            return;
        };
        let state = borrow_global_mut<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return;
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        lottery.bonus_tickets_issued = lottery.bonus_tickets_issued + bonus_tickets;
        event::emit_event(
            &mut state.bonus_events,
            VipBonusIssuedEvent { lottery_id, player, bonus_tickets },
        );
        emit_vip_snapshot(state);
    }

    public fun ensure_caps_initialized(admin: &signer)
    acquires VipAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(admin);
        if (exists<VipAccess>(@lottery)) {
            return;
        };
        let control = treasury_multi::borrow_control_mut(@lottery);
        let cap_opt = treasury_multi::extract_vip_cap(control);
        if (!option::is_some(&cap_opt)) {
            abort E_NOT_INITIALIZED;
        };
        let cap = option::destroy_some(cap_opt);
        move_to(admin, VipAccess { cap });
    }

    public fun release_caps(admin: &signer)
    acquires VipAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(admin);
        if (!exists<VipAccess>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let VipAccess { cap } = move_from<VipAccess>(@lottery);
        let control = treasury_multi::borrow_control_mut(@lottery);
        treasury_multi::restore_vip_cap(control, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<VipAccess>(@lottery)
    }

    fun subscribe_internal(
        payer: &signer,
        lottery_id: u64,
        player: address,
    ) acquires VipAccess, VipState, treasury_multi::TreasuryMultiControl, treasury_multi::TreasuryState {
        ensure_lottery_known(lottery_id);
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        if (!exists<VipAccess>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let access = borrow_global<VipAccess>(@lottery);
        treasury_multi::ensure_scope(&access.cap, treasury_multi::scope_vip());

        let state = borrow_global_mut<VipState>(@lottery);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
        let lottery = table::borrow_mut(&mut state.lotteries, lottery_id);
        let config_snapshot = lottery.config;
        let price = config_snapshot.price;
        treasury::deposit_from_user(payer, price);
        let treasury_state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_operations_income_with_cap(
            treasury_state,
            &access.cap,
            lottery_id,
            price,
            SOURCE_VIP_SUBSCRIPTION,
        );

        let duration_secs = config_snapshot.duration_secs;
        let bonus_tickets = config_snapshot.bonus_tickets;
        lottery.total_revenue = lottery.total_revenue + price;
        let now = timestamp::now_seconds();
        let expiry = now + duration_secs;
        let renewed = table::contains(&lottery.subscriptions, player);
        let actual_expiry;
        if (renewed) {
            let subscription = table::borrow_mut(&mut lottery.subscriptions, player);
            if (subscription.expiry_ts > now) {
                subscription.expiry_ts = subscription.expiry_ts + duration_secs;
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
            actual_expiry = expiry;
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
            abort E_NOT_INITIALIZED;
        };
        let state = borrow_global_mut<VipState>(@lottery);
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
        emit_vip_snapshot(state);
    }

    fun emit_vip_snapshot(state: &mut VipState) {
        let snapshot = build_vip_snapshot_from_mut(state);
        event::emit_event(&mut state.snapshot_events, VipSnapshotUpdatedEvent { snapshot });
    }

    fun build_vip_snapshot_from_mut(state: &mut VipState): VipSnapshot {
        build_vip_snapshot_internal(state.admin, &state.lotteries, &state.lottery_ids)
    }

    fun build_vip_snapshot(state: &VipState): VipSnapshot {
        build_vip_snapshot_internal(state.admin, &state.lotteries, &state.lottery_ids)
    }

    fun build_vip_snapshot_internal(
        admin: address,
        lotteries: &table::Table<u64, VipLottery>,
        lottery_ids: &vector<u64>,
    ): VipSnapshot {
        let now = timestamp::now_seconds();
        let snapshots = collect_lottery_snapshots(lotteries, lottery_ids, 0, vector::length(lottery_ids), now);
        VipSnapshot { admin, lotteries: snapshots }
    }

    fun build_lottery_snapshot_for_view(state: &VipState, lottery_id: u64): VipLotterySnapshot {
        let now = timestamp::now_seconds();
        let lottery = table::borrow(&state.lotteries, lottery_id);
        build_lottery_snapshot_internal(lottery_id, lottery, now)
    }

    fun build_lottery_snapshot_internal(
        lottery_id: u64,
        lottery: &VipLottery,
        now: u64,
    ): VipLotterySnapshot {
        let total_members = vector::length(&lottery.members);
        let active_members = count_active_members(&lottery.subscriptions, &lottery.members, now, 0);
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
        index: u64,
    ): u64 {
        let len = vector::length(members);
        if (index == len) {
            return 0;
        };
        let member = *vector::borrow(members, index);
        let tail = count_active_members(subscriptions, members, now, index + 1);
        if (!table::contains(subscriptions, member)) {
            return tail;
        };
        let subscription = table::borrow(subscriptions, member);
        if (subscription.expiry_ts > now) {
            tail + 1
        } else {
            tail
        }
    }

    fun collect_lottery_snapshots(
        lotteries: &table::Table<u64, VipLottery>,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
        now: u64,
    ): vector<VipLotterySnapshot> {
        if (index == len) {
            return vector::empty<VipLotterySnapshot>();
        };
        let lottery_id = *vector::borrow(lottery_ids, index);
        let mut current = vector::empty<VipLotterySnapshot>();
        if (table::contains(lotteries, lottery_id)) {
            let snapshot = build_lottery_snapshot_internal(lottery_id, table::borrow(lotteries, lottery_id), now);
            vector::push_back(&mut current, snapshot);
        };
        let tail = collect_lottery_snapshots(lotteries, lottery_ids, index + 1, len, now);
        append_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_snapshots(
        dst: &mut vector<VipLotterySnapshot>,
        src: &vector<VipLotterySnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_snapshots(dst, src, index + 1);
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        if (contains_u64(ids, lottery_id, 0)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun record_member(members: &mut vector<address>, member: address) {
        if (contains_address(members, member, 0)) {
            return;
        };
        vector::push_back(members, member);
    }

    fun import_existing_lotteries_recursive(lotteries: &mut vector<LegacyVipLottery>)
    acquires VipState {
        if (vector::is_empty(lotteries)) {
            return;
        };
        let lottery = vector::pop_back(lotteries);
        import_existing_lotteries_recursive(lotteries);
        upsert_legacy_lottery(lottery);
    }

    fun upsert_legacy_lottery(lottery: LegacyVipLottery) acquires VipState {
        ensure_initialized();
        let LegacyVipLottery {
            lottery_id,
            config,
            total_revenue,
            bonus_tickets_issued,
            members,
            mut subscriptions,
        } = lottery;
        ensure_lottery_known(lottery_id);
        let mut stored_members = copy_address_vector(&members);
        let mut subscription_table = table::new<address, VipSubscription>();
        restore_legacy_subscriptions(&mut subscription_table, &mut subscriptions);
        let state = borrow_global_mut<VipState>(@lottery);
        if (table::contains(&state.lotteries, lottery_id)) {
            let _ = table::remove(&mut state.lotteries, lottery_id);
        };
        let price = config.price;
        let duration_secs = config.duration_secs;
        let bonus_tickets = config.bonus_tickets;
        table::add(
            &mut state.lotteries,
            lottery_id,
            VipLottery {
                config,
                subscriptions: subscription_table,
                members: stored_members,
                total_revenue,
                bonus_tickets_issued,
            },
        );
        record_lottery_id(&mut state.lottery_ids, lottery_id);
        event::emit_event(
            &mut state.config_events,
            VipConfigUpdatedEvent { lottery_id, price, duration_secs, bonus_tickets },
        );
        emit_vip_snapshot(state);
    }

    fun restore_legacy_subscriptions(
        table_ref: &mut table::Table<address, VipSubscription>,
        subscriptions: &mut vector<LegacyVipSubscription>,
    ) {
        if (vector::is_empty(subscriptions)) {
            return;
        };
        let subscription = vector::pop_back(subscriptions);
        restore_legacy_subscriptions(table_ref, subscriptions);
        let LegacyVipSubscription { player, expiry_ts, bonus_tickets } = subscription;
        if (table::contains(table_ref, player)) {
            let existing = table::borrow_mut(table_ref, player);
            existing.expiry_ts = expiry_ts;
            existing.bonus_tickets = bonus_tickets;
        } else {
            table::add(table_ref, player, VipSubscription { expiry_ts, bonus_tickets });
        };
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        copy_u64_vector_from(values, 0)
    }

    fun copy_address_vector(values: &vector<address>): vector<address> {
        copy_address_vector_from(values, 0)
    }

    fun copy_u64_vector_from(values: &vector<u64>, index: u64): vector<u64> {
        let len = vector::length(values);
        if (index == len) {
            return vector::empty<u64>();
        };
        let mut current = vector::empty<u64>();
        vector::push_back(&mut current, *vector::borrow(values, index));
        let tail = copy_u64_vector_from(values, index + 1);
        append_u64(&mut current, &tail, 0);
        current
    }

    fun copy_address_vector_from(values: &vector<address>, index: u64): vector<address> {
        let len = vector::length(values);
        if (index == len) {
            return vector::empty<address>();
        };
        let mut current = vector::empty<address>();
        vector::push_back(&mut current, *vector::borrow(values, index));
        let tail = copy_address_vector_from(values, index + 1);
        append_addresses(&mut current, &tail, 0);
        current
    }

    fun append_u64(dst: &mut vector<u64>, src: &vector<u64>, index: u64) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_u64(dst, src, index + 1);
    }

    fun append_addresses(dst: &mut vector<address>, src: &vector<address>, index: u64) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };
        vector::push_back(dst, *vector::borrow(src, index));
        append_addresses(dst, src, index + 1);
    }

    fun contains_u64(values: &vector<u64>, target: u64, index: u64): bool {
        let len = vector::length(values);
        if (index == len) {
            return false;
        };
        if (*vector::borrow(values, index) == target) {
            return true;
        };
        contains_u64(values, target, index + 1)
    }

    fun contains_address(values: &vector<address>, target: address, index: u64): bool {
        let len = vector::length(values);
        if (index == len) {
            return false;
        };
        if (*vector::borrow(values, index) == target) {
            return true;
        };
        contains_address(values, target, index + 1)
    }

    fun ensure_admin(caller: &signer) acquires VipState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<VipState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_initialized() {
        if (!exists<VipState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_caps_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_lottery_known(lottery_id: u64)
    acquires instances::InstanceRegistry {
        let registry = instances::borrow_registry(@lottery);
        if (!instances::contains(registry, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };
    }
}
