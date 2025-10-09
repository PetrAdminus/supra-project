module lottery::referrals {
    friend lottery::rounds;
    friend lottery::migration;

    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;
    use std::math64;
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
        config_events: event::EventHandle<ReferralConfigUpdatedEvent>,
        register_events: event::EventHandle<ReferralRegisteredEvent>,
        cleared_events: event::EventHandle<ReferralClearedEvent>,
        reward_events: event::EventHandle<ReferralRewardPaidEvent>,
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
            abort E_NOT_AUTHORIZED;
        };
        if (exists<ReferralState>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
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
                config_events: event::new_event_handle<ReferralConfigUpdatedEvent>(caller),
                register_events: event::new_event_handle<ReferralRegisteredEvent>(caller),
                cleared_events: event::new_event_handle<ReferralClearedEvent>(caller),
                reward_events: event::new_event_handle<ReferralRewardPaidEvent>(caller),
            },
        );
    }

    #[view]
    public fun is_initialized(): bool {
        exists<ReferralState>(@lottery)
    }

    #[view]
    public fun admin(): address acquires ReferralState {
        borrow_state().admin
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        state.admin = new_admin;
    }

    public entry fun set_lottery_config(
        caller: &signer,
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
    ) acquires ReferralState {
        ensure_admin(caller);
        if (referrer_bps + referee_bps > BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_CONFIG;
        };
        let treasury_config_opt = treasury_multi::get_config(lottery_id);
        if (!option::is_some(&treasury_config_opt)) {
            abort E_TREASURY_CONFIG_MISSING;
        };
        let share_config = *option::borrow(&treasury_config_opt);
        let operations_bps = share_config.operations_bps;
        if (referrer_bps + referee_bps > operations_bps) {
            abort E_INVALID_CONFIG;
        };
        let state = borrow_state_mut();
        let config = ReferralConfig { referrer_bps, referee_bps };
        if (table::contains(&state.configs, lottery_id)) {
            *table::borrow_mut(&mut state.configs, lottery_id) = config;
        } else {
            table::add(&mut state.configs, lottery_id, config);
            record_lottery_id(&mut state.lottery_ids, lottery_id);
        };
        event::emit_event(
            &mut state.config_events,
            ReferralConfigUpdatedEvent { lottery_id, referrer_bps, referee_bps },
        );
    }

    public entry fun register_referrer(caller: &signer, referrer: address) acquires ReferralState {
        let player = signer::address_of(caller);
        if (player == referrer) {
            abort E_SELF_REFERRAL;
        };
        let state = borrow_state_mut();
        if (table::contains(&state.referrers, player)) {
            abort E_ALREADY_REGISTERED;
        };
        table::add(&mut state.referrers, player, referrer);
        state.total_registered = state.total_registered + 1;
        event::emit_event(
            &mut state.register_events,
            ReferralRegisteredEvent { player, referrer, by_admin: false },
        );
    }

    public entry fun admin_set_referrer(
        caller: &signer,
        player: address,
        referrer: address,
    ) acquires ReferralState {
        ensure_admin(caller);
        if (player == referrer) {
            abort E_SELF_REFERRAL;
        };
        let state = borrow_state_mut();
        if (table::contains(&state.referrers, player)) {
            *table::borrow_mut(&mut state.referrers, player) = referrer;
        } else {
            table::add(&mut state.referrers, player, referrer);
            state.total_registered = state.total_registered + 1;
        };
        event::emit_event(
            &mut state.register_events,
            ReferralRegisteredEvent { player, referrer, by_admin: true },
        );
    }

    public entry fun admin_clear_referrer(caller: &signer, player: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_state_mut();
        if (table::contains(&state.referrers, player)) {
            table::remove(&mut state.referrers, player);
            event::emit_event(
                &mut state.cleared_events,
                ReferralClearedEvent { player, by_admin: true },
            );
        };
    }

    #[view]
    public fun total_registered(): u64 acquires ReferralState {
        borrow_state().total_registered
    }

    #[view]
    public fun get_referrer(player: address): option::Option<address> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<address>();
        };
        let state = borrow_state();
        if (table::contains(&state.referrers, player)) {
            option::some(*table::borrow(&state.referrers, player))
        } else {
            option::none<address>()
        }
    }

    #[view]
    public fun get_lottery_config(lottery_id: u64): option::Option<ReferralConfig> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralConfig>();
        };
        let state = borrow_state();
        if (table::contains(&state.configs, lottery_id)) {
            option::some(*table::borrow(&state.configs, lottery_id))
        } else {
            option::none<ReferralConfig>()
        }
    }

    #[view]
    public fun get_lottery_stats(lottery_id: u64): option::Option<ReferralStats> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralStats>();
        };
        let state = borrow_state();
        if (table::contains(&state.stats, lottery_id)) {
            option::some(*table::borrow(&state.stats, lottery_id))
        } else {
            option::none<ReferralStats>()
        }
    }

    #[view]
    /// test-view: возвращает (rewarded_purchases, total_referrer_rewards, total_referee_rewards)
    public fun get_lottery_stats_view(
        lottery_id: u64,
    ): option::Option<(u64, u64, u64)> acquires ReferralState {
        let stats_opt = get_lottery_stats(lottery_id);
        if (option::is_some(&stats_opt)) {
            let stats_ref = option::borrow(&stats_opt);
            option::some((
                stats_ref.rewarded_purchases,
                stats_ref.total_referrer_rewards,
                stats_ref.total_referee_rewards,
            ))
        } else {
            option::none<(u64, u64, u64)>()
        }
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_state();
        copy_u64_vector(&state.lottery_ids)
    }

    public(friend) fun record_purchase(
        lottery_id: u64,
        buyer: address,
        amount: u64,
    ) acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return;
        };
        if (amount == 0) {
            return;
        };
        let state = borrow_state_mut();
        if (!table::contains(&state.configs, lottery_id)) {
            return;
        };
        if (!table::contains(&state.referrers, buyer)) {
            return;
        };
        let referrer = *table::borrow(&state.referrers, buyer);
        if (referrer == buyer) {
            return;
        };
        let config_snapshot = *table::borrow(&state.configs, lottery_id);
        let referrer_bps = config_snapshot.referrer_bps;
        let referee_bps = config_snapshot.referee_bps;
        if (referrer_bps == 0 && referee_bps == 0) {
            return;
        };
        let summary_opt = treasury_multi::get_lottery_summary(lottery_id);
        if (!option::is_some(&summary_opt)) {
            return;
        };
        let summary = *option::borrow(&summary_opt);
        let pool = summary.pool;
        let operations_balance = pool.operations_balance;
        if (operations_balance == 0) {
            return;
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
            return;
        };

        let stats = ensure_stats(state, lottery_id);
        stats.rewarded_purchases = stats.rewarded_purchases + 1;
        stats.total_referrer_rewards = stats.total_referrer_rewards + referrer_paid;
        stats.total_referee_rewards = stats.total_referee_rewards + referee_paid;

        event::emit_event(
            &mut state.reward_events,
            ReferralRewardPaidEvent {
                lottery_id,
                buyer,
                referrer,
                referrer_amount: referrer_paid,
                referee_amount: referee_paid,
                total_amount: amount,
            },
        );
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

    fun borrow_state(): &ReferralState acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<ReferralState>(@lottery)
    }

    fun borrow_state_mut(): &mut ReferralState acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<ReferralState>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires ReferralState {
        let addr = signer::address_of(caller);
        if (addr != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
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
}
