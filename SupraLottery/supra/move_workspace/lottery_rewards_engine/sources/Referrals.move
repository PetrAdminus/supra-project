module lottery_rewards_engine::referrals {
    use lottery_data::instances;
    use lottery_data::treasury_multi;
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INVALID_CONFIG: u64 = 4;
    const E_SELF_REFERRAL: u64 = 5;
    const E_ALREADY_REGISTERED: u64 = 6;
    const E_TREASURY_CONFIG_MISSING: u64 = 7;
    const E_CAPS_UNAVAILABLE: u64 = 8;

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
        snapshot_events: event::EventHandle<ReferralSnapshotUpdatedEvent>,
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

    struct ReferralRegistrationSnapshot has copy, drop, store {
        player: address,
        referrer: address,
    }

    struct ReferralLedgerSnapshot has copy, drop, store {
        summary: ReferralSnapshot,
        registrations: vector<ReferralRegistrationSnapshot>,
    }

    struct ReferralsControl has key {
        treasury_cap: treasury_multi::MultiTreasuryCap,
    }

    public struct LegacyReferralLottery has drop, store {
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
        rewarded_purchases: u64,
        total_referrer_rewards: u64,
        total_referee_rewards: u64,
    }

    public struct LegacyReferralRegistration has drop, store {
        player: address,
        referrer: address,
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

    #[view]
    public fun is_initialized(): bool {
        exists<ReferralState>(@lottery)
    }

    public entry fun init(caller: &signer) acquires ReferralState {
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
                configs: table::new<u64, ReferralConfig>(),
                stats: table::new<u64, ReferralStats>(),
                referrers: table::new<address, address>(),
                lottery_ids: vector::empty<u64>(),
                total_registered: 0,
                config_events: account::new_event_handle<ReferralConfigUpdatedEvent>(caller),
                register_events: account::new_event_handle<ReferralRegisteredEvent>(caller),
                cleared_events: account::new_event_handle<ReferralClearedEvent>(caller),
                reward_events: account::new_event_handle<ReferralRewardPaidEvent>(caller),
                snapshot_events: account::new_event_handle<ReferralSnapshotUpdatedEvent>(caller),
            },
        );
        emit_snapshot_after_init();
    }

    public entry fun init_access(caller: &signer)
    acquires ReferralsControl, treasury_multi::TreasuryMultiControl {
        ensure_lottery_signer(caller);
        if (exists<ReferralsControl>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        let control = treasury_multi::borrow_control_mut(@lottery);
        let cap_opt = treasury_multi::extract_referrals_cap(control);
        if (!option::is_some(&cap_opt)) {
            abort E_CAPS_UNAVAILABLE;
        };
        let cap = option::destroy_some(cap_opt);
        move_to(caller, ReferralsControl { treasury_cap: cap });
    }

    public entry fun release_access(caller: &signer)
    acquires ReferralsControl, treasury_multi::TreasuryMultiControl {
        ensure_lottery_signer(caller);
        if (!exists<ReferralsControl>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let ReferralsControl { treasury_cap } = move_from<ReferralsControl>(@lottery);
        let control = treasury_multi::borrow_control_mut(@lottery);
        treasury_multi::restore_referrals_cap(control, treasury_cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<ReferralsControl>(@lottery)
    }

    public entry fun import_existing_lottery(caller: &signer, lottery: LegacyReferralLottery)
    acquires ReferralState, treasury_multi::TreasuryState {
        ensure_admin(caller);
        upsert_legacy_lottery(lottery);
    }

    public entry fun import_existing_lotteries(
        caller: &signer,
        mut lotteries: vector<LegacyReferralLottery>,
    ) acquires ReferralState, treasury_multi::TreasuryState {
        ensure_admin(caller);
        import_existing_lotteries_recursive(&mut lotteries);
    }

    public entry fun import_existing_registration(
        caller: &signer,
        registration: LegacyReferralRegistration,
    ) acquires ReferralState {
        ensure_admin(caller);
        upsert_legacy_registration(registration);
    }

    public entry fun import_existing_registrations(
        caller: &signer,
        mut registrations: vector<LegacyReferralRegistration>,
    ) acquires ReferralState {
        ensure_admin(caller);
        import_existing_registrations_recursive(&mut registrations);
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot_from_mut(state));
        state.admin = new_admin;
        emit_snapshot_event(state, previous);
    }

    public entry fun set_lottery_config(
        caller: &signer,
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
    ) acquires ReferralState, treasury_multi::TreasuryState {
        ensure_admin(caller);
        ensure_lottery_known(lottery_id);
        let total_bps = referrer_bps + referee_bps;
        if (total_bps > BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_CONFIG;
        };
        let operations_bps = read_operations_share(lottery_id);
        if (total_bps > operations_bps) {
            abort E_INVALID_CONFIG;
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot_from_mut(state));
        upsert_config(state, lottery_id, referrer_bps, referee_bps);
        event::emit_event(
            &mut state.config_events,
            ReferralConfigUpdatedEvent { lottery_id, referrer_bps, referee_bps },
        );
        emit_snapshot_event(state, previous);
    }

    public entry fun register_referrer(caller: &signer, referrer: address) acquires ReferralState {
        let player = signer::address_of(caller);
        if (player == referrer) {
            abort E_SELF_REFERRAL;
        };
        ensure_initialized();
        let state = borrow_global_mut<ReferralState>(@lottery);
        if (table::contains(&state.referrers, player)) {
            abort E_ALREADY_REGISTERED;
        };
        let previous = option::some(build_referral_snapshot_from_mut(state));
        table::add(&mut state.referrers, player, referrer);
        state.total_registered = state.total_registered + 1;
        event::emit_event(
            &mut state.register_events,
            ReferralRegisteredEvent { player, referrer, by_admin: false },
        );
        emit_snapshot_event(state, previous);
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
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot_from_mut(state));
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
        emit_snapshot_event(state, previous);
    }

    public entry fun admin_clear_referrer(caller: &signer, player: address) acquires ReferralState {
        ensure_admin(caller);
        let state = borrow_global_mut<ReferralState>(@lottery);
        if (!table::contains(&state.referrers, player)) {
            return;
        };
        let previous = option::some(build_referral_snapshot_from_mut(state));
        table::remove(&mut state.referrers, player);
        event::emit_event(
            &mut state.cleared_events,
            ReferralClearedEvent { player, by_admin: true },
        );
        emit_snapshot_event(state, previous);
    }

    public entry fun record_reward(
        caller: &signer,
        lottery_id: u64,
        buyer: address,
        amount: u64,
    ) acquires ReferralsControl, ReferralState, treasury_multi::TreasuryState {
        ensure_admin(caller);
        ensure_caps_ready();
        record_purchase_internal(lottery_id, buyer, amount);
    }

    #[view]
    public fun total_registered(): u64 acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return 0;
        };
        let state = borrow_global<ReferralState>(@lottery);
        state.total_registered
    }

    #[view]
    public fun get_referrer(player: address): option::Option<address> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<address>();
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (!table::contains(&state.referrers, player)) {
            option::none<address>()
        } else {
            option::some(*table::borrow(&state.referrers, player))
        }
    }

    #[view]
    public fun get_lottery_config(lottery_id: u64): option::Option<ReferralConfig>
    acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralConfig>();
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (!table::contains(&state.configs, lottery_id)) {
            option::none<ReferralConfig>()
        } else {
            option::some(*table::borrow(&state.configs, lottery_id))
        }
    }

    #[view]
    public fun get_lottery_stats(lottery_id: u64): option::Option<ReferralStats>
    acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return option::none<ReferralStats>();
        };
        let state = borrow_global<ReferralState>(@lottery);
        if (!table::contains(&state.stats, lottery_id)) {
            option::none<ReferralStats>()
        } else {
            option::some(*table::borrow(&state.stats, lottery_id))
        }
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return vector::empty<u64>();
        };
        let state = borrow_global<ReferralState>(@lottery);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_referral_snapshot(): ReferralSnapshot acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return empty_snapshot();
        };
        let state = borrow_global<ReferralState>(@lottery);
        build_referral_snapshot(state)
    }

    #[view]
    public fun ledger_snapshot(): ReferralLedgerSnapshot acquires ReferralState {
        if (!exists<ReferralState>(@lottery)) {
            return empty_ledger_snapshot();
        };
        let state = borrow_global<ReferralState>(@lottery);
        build_ledger_snapshot(state)
    }

    fun record_purchase_internal(
        lottery_id: u64,
        buyer: address,
        amount: u64,
    ) acquires ReferralsControl, ReferralState, treasury_multi::TreasuryState {
        if (!exists<ReferralState>(@lottery)) {
            return;
        };
        if (amount == 0) {
            return;
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
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
        let available_before_referrer = operations_balance_snapshot(lottery_id);
        if (available_before_referrer == 0) {
            return;
        };
        let desired_referrer = multiply_bps(amount, referrer_bps);
        let referrer_paid = clamp_amount(desired_referrer, available_before_referrer);
        let available_after_referrer = available_before_referrer - referrer_paid;
        let desired_referee = multiply_bps(amount, referee_bps);
        let referee_paid = clamp_amount(desired_referee, available_after_referrer);
        if (referrer_paid == 0 && referee_paid == 0) {
            return;
        };
        let control = borrow_global<ReferralsControl>(@lottery);
        treasury_multi::ensure_scope(&control.treasury_cap, treasury_multi::scope_referrals());
        let treasury_state = treasury_multi::borrow_state_mut(@lottery);
        if (referrer_paid > 0) {
            treasury_multi::record_operations_bonus(treasury_state, lottery_id, referrer, referrer_paid);
        };
        if (referee_paid > 0) {
            treasury_multi::record_operations_bonus(treasury_state, lottery_id, buyer, referee_paid);
        };
        let previous = option::some(build_referral_snapshot_from_mut(state));
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
        emit_snapshot_event(state, previous);
    }

    fun ensure_stats(state: &mut ReferralState, lottery_id: u64): &mut ReferralStats {
        if (!table::contains(&state.stats, lottery_id)) {
            table::add(
                &mut state.stats,
                lottery_id,
                ReferralStats {
                    rewarded_purchases: 0,
                    total_referrer_rewards: 0,
                    total_referee_rewards: 0,
                },
            );
        };
        table::borrow_mut(&mut state.stats, lottery_id)
    }

    fun import_existing_lotteries_recursive(
        lotteries: &mut vector<LegacyReferralLottery>,
    ) acquires ReferralState, treasury_multi::TreasuryState {
        if (vector::is_empty(lotteries)) {
            return;
        };
        let lottery = vector::pop_back(lotteries);
        import_existing_lotteries_recursive(lotteries);
        upsert_legacy_lottery(lottery);
    }

    fun upsert_legacy_lottery(lottery: LegacyReferralLottery)
    acquires ReferralState, treasury_multi::TreasuryState {
        ensure_initialized();
        let LegacyReferralLottery {
            lottery_id,
            referrer_bps,
            referee_bps,
            rewarded_purchases,
            total_referrer_rewards,
            total_referee_rewards,
        } = lottery;
        ensure_lottery_known(lottery_id);
        let total_bps = referrer_bps + referee_bps;
        if (total_bps > BASIS_POINT_DENOMINATOR) {
            abort E_INVALID_CONFIG;
        };
        let operations_bps = read_operations_share(lottery_id);
        if (total_bps > operations_bps) {
            abort E_INVALID_CONFIG;
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot_from_mut(state));
        upsert_config(state, lottery_id, referrer_bps, referee_bps);
        let stats = ensure_stats(state, lottery_id);
        stats.rewarded_purchases = rewarded_purchases;
        stats.total_referrer_rewards = total_referrer_rewards;
        stats.total_referee_rewards = total_referee_rewards;
        event::emit_event(
            &mut state.config_events,
            ReferralConfigUpdatedEvent { lottery_id, referrer_bps, referee_bps },
        );
        emit_snapshot_event(state, previous);
    }

    fun import_existing_registrations_recursive(
        registrations: &mut vector<LegacyReferralRegistration>,
    ) acquires ReferralState {
        if (vector::is_empty(registrations)) {
            return;
        };
        let registration = vector::pop_back(registrations);
        import_existing_registrations_recursive(registrations);
        upsert_legacy_registration(registration);
    }

    fun upsert_legacy_registration(registration: LegacyReferralRegistration)
    acquires ReferralState {
        ensure_initialized();
        let LegacyReferralRegistration { player, referrer } = registration;
        if (player == referrer) {
            abort E_SELF_REFERRAL;
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        let previous = option::some(build_referral_snapshot_from_mut(state));
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
        emit_snapshot_event(state, previous);
    }

    fun read_operations_share(lottery_id: u64): u64 acquires treasury_multi::TreasuryState {
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::ensure_lottery(state, lottery_id);
        let (_, _, operations_bps) = treasury_multi::share_config(state, lottery_id);
        operations_bps
    }

    fun operations_balance_snapshot(lottery_id: u64): u64 acquires treasury_multi::TreasuryState {
        let state = treasury_multi::borrow_state(@lottery);
        treasury_multi::operations_balance(state, lottery_id)
    }

    fun upsert_config(
        state: &mut ReferralState,
        lottery_id: u64,
        referrer_bps: u64,
        referee_bps: u64,
    ) {
        let config = ReferralConfig { referrer_bps, referee_bps };
        if (table::contains(&state.configs, lottery_id)) {
            *table::borrow_mut(&mut state.configs, lottery_id) = config;
        } else {
            table::add(&mut state.configs, lottery_id, config);
            record_lottery_id(&mut state.lottery_ids, lottery_id);
        };
    }

    fun ensure_admin(caller: &signer) acquires ReferralState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<ReferralState>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_initialized() {
        if (!exists<ReferralState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_caps_ready() {
        if (!exists<ReferralsControl>(@lottery)) {
            abort E_CAPS_UNAVAILABLE;
        };
    }

    fun ensure_lottery_signer(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_lottery_known(lottery_id: u64) {
        let registry = instances::borrow_registry(@lottery);
        if (!instances::contains(registry, lottery_id)) {
            abort E_TREASURY_CONFIG_MISSING;
        };
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        if (contains_lottery_id(ids, lottery_id, 0)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun contains_lottery_id(ids: &vector<u64>, lottery_id: u64, index: u64): bool {
        if (index == vector::length(ids)) {
            return false;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            return true;
        };
        let next_index = index + 1;
        contains_lottery_id(ids, lottery_id, next_index)
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        let acc = vector::empty<u64>();
        copy_u64_vector_recursive(values, 0, acc)
    }

    fun copy_u64_vector_recursive(
        values: &vector<u64>,
        index: u64,
        acc: vector<u64>,
    ): vector<u64> {
        if (index == vector::length(values)) {
            acc
        } else {
            let value = *vector::borrow(values, index);
            let mut next_acc = acc;
            vector::push_back(&mut next_acc, value);
            let next_index = index + 1;
            copy_u64_vector_recursive(values, next_index, next_acc)
        }
    }

    fun build_referral_snapshot_from_mut(state: &mut ReferralState): ReferralSnapshot {
        build_referral_snapshot_internal(
            state.admin,
            state.total_registered,
            &state.lottery_ids,
            &state.configs,
            &state.stats,
        )
    }

    fun build_referral_snapshot(state: &ReferralState): ReferralSnapshot {
        build_referral_snapshot_internal(
            state.admin,
            state.total_registered,
            &state.lottery_ids,
            &state.configs,
            &state.stats,
        )
    }

    fun build_referral_snapshot_internal(
        admin: address,
        total_registered: u64,
        lottery_ids: &vector<u64>,
        configs: &table::Table<u64, ReferralConfig>,
        stats: &table::Table<u64, ReferralStats>,
    ): ReferralSnapshot {
        ReferralSnapshot {
            admin,
            total_registered,
            lotteries: build_lottery_snapshots_from_tables(lottery_ids, configs, stats),
        }
    }

    fun build_ledger_snapshot(state: &ReferralState): ReferralLedgerSnapshot {
        ReferralLedgerSnapshot {
            summary: build_referral_snapshot(state),
            registrations: build_registration_snapshots(&state.referrers),
        }
    }

    fun build_lottery_snapshots_from_tables(
        lottery_ids: &vector<u64>,
        configs: &table::Table<u64, ReferralConfig>,
        stats: &table::Table<u64, ReferralStats>,
    ): vector<LotteryReferralSnapshot> {
        let acc = vector::empty<LotteryReferralSnapshot>();
        build_lottery_snapshots_recursive(lottery_ids, configs, stats, 0, acc)
    }

    fun build_lottery_snapshots_recursive(
        lottery_ids: &vector<u64>,
        configs: &table::Table<u64, ReferralConfig>,
        stats: &table::Table<u64, ReferralStats>,
        index: u64,
        acc: vector<LotteryReferralSnapshot>,
    ): vector<LotteryReferralSnapshot> {
        if (index == vector::length(lottery_ids)) {
            acc
        } else {
            let mut next_acc = acc;
            let lottery_id = *vector::borrow(lottery_ids, index);
            if (table::contains(configs, lottery_id)) {
                let config = *table::borrow(configs, lottery_id);
                let stats_entry = if (table::contains(stats, lottery_id)) {
                    *table::borrow(stats, lottery_id)
                } else {
                    ReferralStats {
                        rewarded_purchases: 0,
                        total_referrer_rewards: 0,
                        total_referee_rewards: 0,
                    }
                };
                vector::push_back(
                    &mut next_acc,
                    LotteryReferralSnapshot {
                        lottery_id,
                        referrer_bps: config.referrer_bps,
                        referee_bps: config.referee_bps,
                        rewarded_purchases: stats_entry.rewarded_purchases,
                        total_referrer_rewards: stats_entry.total_referrer_rewards,
                        total_referee_rewards: stats_entry.total_referee_rewards,
                    },
                );
            };
            let next_index = index + 1;
            build_lottery_snapshots_recursive(lottery_ids, configs, stats, next_index, next_acc)
        }
    }

    fun emit_snapshot_event(state: &mut ReferralState, previous: option::Option<ReferralSnapshot>) {
        let current = build_referral_snapshot_from_mut(state);
        event::emit_event(
            &mut state.snapshot_events,
            ReferralSnapshotUpdatedEvent { previous, current },
        );
    }

    fun emit_snapshot_after_init() {
        if (!exists<ReferralState>(@lottery)) {
            return;
        };
        let state = borrow_global_mut<ReferralState>(@lottery);
        let snapshot = build_referral_snapshot_from_mut(state);
        event::emit_event(
            &mut state.snapshot_events,
            ReferralSnapshotUpdatedEvent { previous: option::none<ReferralSnapshot>(), current: snapshot },
        );
    }

    fun empty_snapshot(): ReferralSnapshot {
        ReferralSnapshot { admin: @lottery, total_registered: 0, lotteries: vector::empty<LotteryReferralSnapshot>() }
    }

    fun empty_ledger_snapshot(): ReferralLedgerSnapshot {
        ReferralLedgerSnapshot { summary: empty_snapshot(), registrations: vector::empty<ReferralRegistrationSnapshot>() }
    }

    fun build_registration_snapshots(referrers: &table::Table<address, address>): vector<ReferralRegistrationSnapshot> {
        let keys = table::keys(referrers);
        collect_registration_snapshots(&keys, referrers, 0)
    }

    fun collect_registration_snapshots(
        keys: &vector<address>,
        referrers: &table::Table<address, address>,
        index: u64,
    ): vector<ReferralRegistrationSnapshot> {
        if (index == vector::length(keys)) {
            return vector::empty<ReferralRegistrationSnapshot>();
        };
        let mut snapshots = collect_registration_snapshots(keys, referrers, index + 1);
        let player = *vector::borrow(keys, index);
        if (table::contains(referrers, player)) {
            let referrer = *table::borrow(referrers, player);
            vector::push_back(&mut snapshots, ReferralRegistrationSnapshot { player, referrer });
        };
        snapshots
    }

    fun multiply_bps(amount: u64, bps: u64): u64 {
        if (bps == 0) {
            return 0;
        };
        let numerator = (amount as u128) * (bps as u128);
        (numerator / (BASIS_POINT_DENOMINATOR as u128)) as u64
    }

    fun clamp_amount(desired: u64, available: u64): u64 {
        if (desired > available) {
            available
        } else {
            desired
        }
    }
}
