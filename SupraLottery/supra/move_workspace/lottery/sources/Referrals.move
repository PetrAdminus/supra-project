module lottery::referrals {
    friend lottery::rounds;

    use supra_framework::event;
    use std::math64;
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use lottery::treasury_multi;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INVALID_CONFIG: u64 = 4;
    const E_SELF_REFERRAL: u64 = 5;
    const E_ALREADY_REGISTERED: u64 = 6;
    const E_TREASURY_CONFIG_MISSING: u64 = 7;

    struct ReferralConfig has copy, drop, store {
        referrer_bps: u64,
        referee_bps: u64,
    }

    struct ReferralStats has copy, drop, store {
        rewarded_purchases: u64,
        total_referrer_rewards: u64,
        total_referee_rewards: u64,
    }

    struct ReferralState has key {
        admin: address,
        configs: table::Table<u64, ReferralConfig>,
        stats: table::Table<u64, ReferralStats>,
        referrers: table::Table<address, address>,
        lottery_ids: vector<u64>,
        total_registered: u64,
    }

    struct LotteryReferralSnapshot has copy, drop, store {
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
        rewarded_purchases: u64,
        total_referrer_rewards: u64,
        total_referee_rewards: u64,
    }

    struct ReferralSnapshot has copy, drop, store {
        admin: address,
        total_registered: u64,
        lotteries: vector<LotteryReferralSnapshot>,
    }

    #[event]
    struct ReferralSnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<ReferralSnapshot>,
        current: ReferralSnapshot,
    }

    #[event]
    struct ReferralConfigUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
    }

    #[event]
    struct ReferralRegisteredEvent has drop, store, copy {
        player: address,
        referrer: address,
        by_admin: bool,
    }

    #[event]
    struct ReferralClearedEvent has drop, store, copy {
        player: address,
        by_admin: bool,
    }

    #[event]
    struct ReferralRewardPaidEvent has drop, store, copy {
        lottery_id: u64,
        buyer: address,
        referrer: address,
        referrer_amount: u64,
        referee_amount: u64,
        total_amount: u64,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<ReferralState>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            ReferralState {
                admin: addr,
                configs: table::new(),
                stats: table::new(),
                referrers: table::new(),
                lottery_ids: vector::empty(),
                total_registered: 0,
            },
        );

        let state = borrow_global_mut<ReferralState>(@lottery);
        emit_snapshot_event(state, option::none());
    }

    #[view]
    public fun is_initialized(): bool {
        exists<ReferralState>(@lottery)
    }

    #[view]
    public fun admin(): address acquires ReferralState {
        let state = borrow_global<ReferralState>(@lottery);
        state.admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot(&*state));
        state.admin = new_admin;
        emit_snapshot_event(state, previous);
    }

    public entry fun set_lottery_config(
        caller: &signer,
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
    ) acquires ReferralState {
        ensure_admin(caller);
        if (referrer_bps + referee_bps > BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_CONFIG
        };
        let treasury_config_opt = treasury_multi::get_config(lottery_id);
        if (!option::is_some(&treasury_config_opt)) {
            abort E_TREASURY_CONFIG_MISSING
        };
        let share_config = *option::borrow(&treasury_config_opt);
        let operations_bps = treasury_multi::share_config_operations_bps(&share_config);
        if (referrer_bps + referee_bps > operations_bps) {
            abort E_INVALID_CONFIG
        };

        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot(&*state));
        let config = ReferralConfig { referrer_bps, referee_bps };
        if (table::contains(&state.configs, lottery_id)) {
            *table::borrow_mut(&mut state.configs, lottery_id) = config;
        } else {
            table::add(&mut state.configs, lottery_id, config);
            record_lottery_id(&mut state.lottery_ids, lottery_id);
        };
        event::emit(ReferralConfigUpdatedEvent { lottery_id, referrer_bps, referee_bps });
        emit_snapshot_event(state, previous);
    }

    public entry fun register_referrer(caller: &signer, referrer: address) acquires ReferralState {
        let player = signer::address_of(caller);
        if (player == referrer) {
            abort E_SELF_REFERRAL
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        if (table::contains(&state.referrers, player)) {
            abort E_ALREADY_REGISTERED
        };
        let previous = option::some(build_referral_snapshot(&*state));
        table::add(&mut state.referrers, player, referrer);
        state.total_registered = state.total_registered + 1;
        event::emit(ReferralRegisteredEvent { player, referrer, by_admin: false });
        emit_snapshot_event(state, previous);
    }

    public entry fun admin_set_referrer(
        caller: &signer,
        player: address,
        referrer: address,
    ) acquires ReferralState {
        ensure_admin(caller);
        if (player == referrer) {
            abort E_SELF_REFERRAL
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot(&*state));
        if (table::contains(&state.referrers, player)) {
            *table::borrow_mut(&mut state.referrers, player) = referrer;
        } else {
            table::add(&mut state.referrers, player, referrer);
            state.total_registered = state.total_registered + 1;
        };
        event::emit(ReferralRegisteredEvent { player, referrer, by_admin: true });
        emit_snapshot_event(state, previous);
    }

    public entry fun admin_clear_referrer(caller: &signer, player: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_global_mut<ReferralState>(@lottery);
        if (!table::contains(&state.referrers, player)) {
            return
        };
        let previous = option::some(build_referral_snapshot(&*state));
        table::remove(&mut state.referrers, player);
        event::emit(ReferralClearedEvent { player, by_admin: true });
        emit_snapshot_event(state, previous);
    }

    #[view]
    public fun total_registered(): u64 acquires ReferralState {
        let state = borrow_global<ReferralState>(@lottery);
        state.total_registered
    }

    #[view]
    public fun get_referrer(player: address): option::Option<address> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<address>()
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (table::contains(&state.referrers, player)) {
            option::some(*table::borrow(&state.referrers, player))
        } else {
            option::none<address>()
        }
    }

    #[view]
    public fun get_lottery_config(lottery_id: u64): option::Option<ReferralConfig> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralConfig>()
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (table::contains(&state.configs, lottery_id)) {
            option::some(*table::borrow(&state.configs, lottery_id))
        } else {
            option::none<ReferralConfig>()
        }
    }

    #[view]
    public fun get_lottery_stats(lottery_id: u64): option::Option<ReferralStats> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralStats>()
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (table::contains(&state.stats, lottery_id)) {
            option::some(*table::borrow(&state.stats, lottery_id))
        } else {
            option::none<ReferralStats>()
        }
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<ReferralState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    public(friend) fun record_purchase(
        lottery_id: u64,
        buyer: address,
        amount: u64,
    ) acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return
        };
        if (amount == 0) {
            return
        };

        let state = borrow_global_mut<ReferralState>(@lottery);
        if (!table::contains(&state.configs, lottery_id)) {
            return
        };
        if (!table::contains(&state.referrers, buyer)) {
            return
        };
        let referrer = *table::borrow(&state.referrers, buyer);
        if (referrer == buyer) {
            return
        };

        let config_snapshot = *table::borrow(&state.configs, lottery_id);
        let referrer_bps = config_snapshot.referrer_bps;
        let referee_bps = config_snapshot.referee_bps;
        if (referrer_bps == 0 && referee_bps == 0) {
            return
        };

        let summary_opt = treasury_multi::get_lottery_summary(lottery_id);
        if (!option::is_some(&summary_opt)) {
            return
        };
        let summary = *option::borrow(&summary_opt);
        let pool = treasury_multi::summary_pool(&summary);
        let operations_balance = treasury_multi::pool_operations_balance(&pool);
        if (operations_balance == 0) {
            return
        };

        let available_before_referrer = operations_balance;
        let desired_referrer = math64::mul_div(amount, referrer_bps, BASIS_POINT_DENOMINATOR);
        let desired_referee = math64::mul_div(amount, referee_bps, BASIS_POINT_DENOMINATOR);

        let referrer_paid;
        let available_after_referrer;
        if (desired_referrer > 0 && available_before_referrer > 0) {
            let pay_referrer = if (desired_referrer > available_before_referrer) {
                available_before_referrer
            } else {
                desired_referrer
            };
            if (pay_referrer > 0) {
                treasury_multi::pay_operations_bonus_internal(lottery_id, referrer, pay_referrer);
                referrer_paid = pay_referrer;
                available_after_referrer = available_before_referrer - pay_referrer;
            } else {
                referrer_paid = 0;
                available_after_referrer = available_before_referrer;
            };
        } else {
            referrer_paid = 0;
            available_after_referrer = available_before_referrer;
        };

        let referee_paid;
        if (desired_referee > 0 && available_after_referrer > 0) {
            let pay_referee = if (desired_referee > available_after_referrer) {
                available_after_referrer
            } else {
                desired_referee
            };
            if (pay_referee > 0) {
                treasury_multi::pay_operations_bonus_internal(lottery_id, buyer, pay_referee);
                referee_paid = pay_referee;
            } else {
                referee_paid = 0;
            };
        } else {
            referee_paid = 0;
        };

        if (referrer_paid == 0 && referee_paid == 0) {
            return
        };

        let previous = option::some(build_referral_snapshot(&*state));
        let stats = ensure_stats(state, lottery_id);
        stats.rewarded_purchases = stats.rewarded_purchases + 1;
        stats.total_referrer_rewards = stats.total_referrer_rewards + referrer_paid;
        stats.total_referee_rewards = stats.total_referee_rewards + referee_paid;

        event::emit(ReferralRewardPaidEvent {
            lottery_id,
            buyer,
            referrer,
            referrer_amount: referrer_paid,
            referee_amount: referee_paid,
            total_amount: amount,
        });
        emit_snapshot_event(state, previous);
    }

    fun ensure_stats(state: &mut ReferralState, lottery_id: u64): &mut ReferralStats {
        if (!table::contains(&state.stats, lottery_id)) {
            table::add(
                &mut state.stats,
                lottery_id,
                ReferralStats { rewarded_purchases: 0, total_referrer_rewards: 0, total_referee_rewards: 0 },
            );
        };
        table::borrow_mut(&mut state.stats, lottery_id)
    }

    fun ensure_admin(caller: &signer) acquires ReferralState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<ReferralState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_initialized() {
        if (!exists<ReferralState>(@lottery)) {
            abort E_NOT_INITIALIZED
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

    #[test_only]
    public fun referral_stats_for_test(
        stats: &ReferralStats
    ): (u64, u64, u64) {
        (
            stats.rewarded_purchases,
            stats.total_referrer_rewards,
            stats.total_referee_rewards,
        )
    }

    #[view]
    public fun get_referral_snapshot(): ReferralSnapshot acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return empty_snapshot()
        };
        let state = borrow_global<ReferralState>(@lottery);
        build_referral_snapshot(&state)
    }

    #[test_only]
    public fun referral_snapshot_admin(snapshot: &ReferralSnapshot): address {
        snapshot.admin
    }

    #[test_only]
    public fun referral_snapshot_total_registered(snapshot: &ReferralSnapshot): u64 {
        snapshot.total_registered
    }

    #[test_only]
    public fun referral_snapshot_lottery_count(snapshot: &ReferralSnapshot): u64 {
        vector::length(&snapshot.lotteries)
    }

    #[test_only]
    public fun referral_snapshot_lottery_at(
        snapshot: &ReferralSnapshot,
        index: u64,
    ): LotteryReferralSnapshot {
        *vector::borrow(&snapshot.lotteries, index)
    }

    #[test_only]
    public fun lottery_referral_snapshot_fields_for_test(
        entry: &LotteryReferralSnapshot
    ): (u64, u64, u64, u64, u64, u64) {
        (
            entry.lottery_id,
            entry.referrer_bps,
            entry.referee_bps,
            entry.rewarded_purchases,
            entry.total_referrer_rewards,
            entry.total_referee_rewards,
        )
    }

    #[test_only]
    public fun referral_snapshot_event_previous_for_test(
        event: &ReferralSnapshotUpdatedEvent
    ): option::Option<ReferralSnapshot> {
        copy_option_snapshot(&event.previous)
    }

    #[test_only]
    public fun referral_snapshot_event_current_for_test(
        event: &ReferralSnapshotUpdatedEvent
    ): ReferralSnapshot {
        event.current
    }

    fun build_referral_snapshot(state: &ReferralState): ReferralSnapshot {
        ReferralSnapshot {
            admin: state.admin,
            total_registered: state.total_registered,
            lotteries: build_lottery_snapshots(state),
        }
    }

    fun build_lottery_snapshots(state: &ReferralState): vector<LotteryReferralSnapshot> {
        let snapshots = vector::empty<LotteryReferralSnapshot>();
        let total = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < total) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.configs, lottery_id)) {
                let config = *table::borrow(&state.configs, lottery_id);
                let stats = if (table::contains(&state.stats, lottery_id)) {
                    *table::borrow(&state.stats, lottery_id)
                } else {
                    ReferralStats {
                        rewarded_purchases: 0,
                        total_referrer_rewards: 0,
                        total_referee_rewards: 0,
                    }
                };
                vector::push_back(
                    &mut snapshots,
                    LotteryReferralSnapshot {
                        lottery_id,
                        referrer_bps: config.referrer_bps,
                        referee_bps: config.referee_bps,
                        rewarded_purchases: stats.rewarded_purchases,
                        total_referrer_rewards: stats.total_referrer_rewards,
                        total_referee_rewards: stats.total_referee_rewards,
                    },
                );
            };
            idx = idx + 1;
        };
        snapshots
    }

    fun emit_snapshot_event(
        state: &mut ReferralState,
        previous: option::Option<ReferralSnapshot>,
    ) {
        let current = build_referral_snapshot(&*state);
        event::emit(ReferralSnapshotUpdatedEvent { previous, current });
    }

    fun empty_snapshot(): ReferralSnapshot {
        ReferralSnapshot {
            admin: @lottery,
            total_registered: 0,
            lotteries: vector::empty<LotteryReferralSnapshot>(),
        }
    }

    fun copy_option_snapshot(
        value: &option::Option<ReferralSnapshot>
    ): option::Option<ReferralSnapshot> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<ReferralSnapshot>()
        }
    }
}
