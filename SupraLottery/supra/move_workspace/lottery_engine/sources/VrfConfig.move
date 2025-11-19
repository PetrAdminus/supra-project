module lottery_engine::vrf_config {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::table;

    use lottery_data::instances;
    use lottery_data::lottery_state;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_INVALID_GAS_CONFIG: u64 = 2;
    const E_REQUEST_PENDING: u64 = 3;
    const E_INVALID_CALLBACK_SENDER: u64 = 4;
    const E_CALLBACK_SENDER_NOT_SET: u64 = 5;
    const E_CONSUMER_ALREADY_REGISTERED: u64 = 6;
    const E_CONSUMER_NOT_REGISTERED: u64 = 7;
    const E_INVALID_CONSUMER: u64 = 8;
    const E_INVALID_REQUEST_CONFIG: u64 = 9;
    const E_CLIENT_SEED_REGRESSION: u64 = 10;
    const E_CLIENT_SEED_OVERFLOW: u64 = 11;

    const EXPECTED_RNG_COUNT: u8 = 1;
    const MAX_CONFIRMATIONS: u64 = 20;
    const U64_MAX: u64 = 18446744073709551615;
    const U64_MAX_AS_U128: u128 = 18446744073709551615;

    struct VrfConfigSnapshot has copy, drop, store {
        lottery_id: u64,
        gas: lottery_state::GasBudget,
        whitelist: lottery_state::WhitelistState,
        request_config: option::Option<lottery_state::VrfRequestConfig>,
        pending_request: lottery_state::PendingRequestSnapshot,
        vrf_stats: lottery_state::VrfStats,
    }

    struct LegacyWhitelistImport has drop, store {
        callback_sender: option::Option<address>,
        consumers: vector<address>,
        client_snapshot: option::Option<lottery_state::ClientWhitelistSnapshot>,
        consumer_snapshot: option::Option<lottery_state::ConsumerWhitelistSnapshot>,
    }

    struct LegacyVrfConfigImport has drop, store {
        lottery_id: u64,
        gas: lottery_state::GasBudget,
        whitelist: LegacyWhitelistImport,
        request_config: option::Option<lottery_state::VrfRequestConfig>,
        vrf_stats: lottery_state::VrfStats,
        pending_request: lottery_state::PendingRequest,
    }

    #[view]
    public fun is_initialized(): bool {
        instances::is_initialized() && lottery_state::is_initialized()
    }

    public entry fun configure_gas_budget(
        caller: &signer,
        lottery_id: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        ensure_no_pending_request(&runtime.pending_request);

        assert!(max_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(max_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(verification_gas_value > 0, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_price <= max_gas_price, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_limit <= max_gas_limit, E_INVALID_GAS_CONFIG);

        let max_fee_u64 = compute_per_request_fee(max_gas_price, max_gas_limit, verification_gas_value);

        runtime.gas.max_gas_price = max_gas_price;
        runtime.gas.max_gas_limit = max_gas_limit;
        runtime.gas.callback_gas_price = callback_gas_price;
        runtime.gas.callback_gas_limit = callback_gas_limit;
        runtime.gas.verification_gas_value = verification_gas_value;
        runtime.gas.max_fee = max_fee_u64;

        if (option::is_some(&runtime.whitelist.client_snapshot)) {
            runtime.whitelist.client_snapshot = option::some(lottery_state::ClientWhitelistSnapshot {
                max_gas_price,
                max_gas_limit,
                min_balance_limit: compute_min_balance(max_gas_price, max_gas_limit, verification_gas_value),
            });
        };

        if (option::is_some(&runtime.whitelist.consumer_snapshot)) {
            runtime.whitelist.consumer_snapshot = option::some(lottery_state::ConsumerWhitelistSnapshot {
                callback_gas_price,
                callback_gas_limit,
            });
        };

        lottery_state::emit_vrf_gas_budget(state, lottery_id);
        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun set_callback_sender(
        caller: &signer,
        lottery_id: u64,
        sender: address,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        assert!(sender != 0x0, E_INVALID_CALLBACK_SENDER);
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        ensure_no_pending_request(&runtime.pending_request);

        runtime.whitelist.callback_sender = option::some(sender);
        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun clear_callback_sender(
        caller: &signer,
        lottery_id: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        ensure_no_pending_request(&runtime.pending_request);
        assert!(option::is_some(&runtime.whitelist.callback_sender), E_CALLBACK_SENDER_NOT_SET);

        runtime.whitelist.callback_sender = option::none<address>();
        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun add_consumer(
        caller: &signer,
        lottery_id: u64,
        consumer: address,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        assert!(consumer != 0x0, E_INVALID_CONSUMER);
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        let consumers = &mut runtime.whitelist.consumers;
        assert!(!contains_address(consumers, consumer), E_CONSUMER_ALREADY_REGISTERED);
        vector::push_back(consumers, consumer);

        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun remove_consumer(
        caller: &signer,
        lottery_id: u64,
        consumer: address,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        assert!(consumer != 0x0, E_INVALID_CONSUMER);
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        let consumers = &mut runtime.whitelist.consumers;
        let removed = remove_address(consumers, consumer);
        assert!(removed, E_CONSUMER_NOT_REGISTERED);

        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_snapshot(state, lottery_id);
    }

    public entry fun record_client_whitelist_snapshot(
        caller: &signer,
        lottery_id: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        min_balance_limit: u128,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);

        assert!(runtime.gas.max_gas_price == max_gas_price, E_INVALID_GAS_CONFIG);
        assert!(runtime.gas.max_gas_limit == max_gas_limit, E_INVALID_GAS_CONFIG);

        let min_balance = compute_min_balance(max_gas_price, max_gas_limit, runtime.gas.verification_gas_value);
        assert!(min_balance_limit >= min_balance, E_INVALID_GAS_CONFIG);

        runtime.whitelist.client_snapshot = option::some(lottery_state::ClientWhitelistSnapshot {
            max_gas_price,
            max_gas_limit,
            min_balance_limit,
        });

        lottery_state::emit_vrf_whitelist(state, lottery_id);
    }

    public entry fun record_consumer_whitelist_snapshot(
        caller: &signer,
        lottery_id: u64,
        callback_gas_price: u128,
        callback_gas_limit: u128,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);

        assert!(runtime.gas.callback_gas_price == callback_gas_price, E_INVALID_GAS_CONFIG);
        assert!(runtime.gas.callback_gas_limit == callback_gas_limit, E_INVALID_GAS_CONFIG);

        runtime.whitelist.consumer_snapshot = option::some(lottery_state::ConsumerWhitelistSnapshot {
            callback_gas_price,
            callback_gas_limit,
        });

        lottery_state::emit_vrf_whitelist(state, lottery_id);
    }

    public entry fun configure_request(
        caller: &signer,
        lottery_id: u64,
        rng_count: u8,
        num_confirmations: u64,
        client_seed: u64,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let _ = instances::instance(registry, lottery_id);

        let state = lottery_state::borrow_mut(@lottery);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        ensure_no_pending_request(&runtime.pending_request);

        assert!(rng_count == EXPECTED_RNG_COUNT, E_INVALID_REQUEST_CONFIG);
        assert!(num_confirmations > 0, E_INVALID_REQUEST_CONFIG);
        assert!(num_confirmations <= MAX_CONFIRMATIONS, E_INVALID_REQUEST_CONFIG);
        assert!(client_seed < U64_MAX, E_CLIENT_SEED_OVERFLOW);

        let current_seed = runtime.vrf_stats.next_client_seed;
        assert!(client_seed >= current_seed, E_CLIENT_SEED_REGRESSION);

        runtime.vrf_stats.next_client_seed = client_seed;
        runtime.request_config = option::some(lottery_state::VrfRequestConfig {
            rng_count,
            num_confirmations,
            client_seed,
        });

        lottery_state::emit_vrf_request_config(state, lottery_id);
    }

    public entry fun import_existing_vrf_config(
        caller: &signer,
        config: LegacyVrfConfigImport,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let state = lottery_state::borrow_mut(@lottery);
        import_single_config(registry, state, config);
    }

    public entry fun import_existing_vrf_configs(
        caller: &signer,
        configs: vector<LegacyVrfConfigImport>,
    ) acquires instances::InstanceRegistry, lottery_state::LotteryState {
        let registry = ensure_admin(caller);
        let state = lottery_state::borrow_mut(@lottery);
        let len = vector::length(&configs);
        import_configs_from_index(registry, state, &configs, 0, len);
    }

    #[view]
    public fun vrf_config_snapshot(lottery_id: u64): option::Option<VrfConfigSnapshot>
    acquires instances::InstanceRegistry, lottery_state::LotteryState {
        if (!instances::is_initialized()) {
            return option::none<VrfConfigSnapshot>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<VrfConfigSnapshot>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        if (!table::contains(&registry.instances, lottery_id)) {
            return option::none<VrfConfigSnapshot>();
        };
        if (!table::contains(&state.lotteries, lottery_id)) {
            return option::none<VrfConfigSnapshot>();
        };

        let runtime_snapshot = lottery_state::runtime_snapshot(lottery_id);
        if (!option::is_some(&runtime_snapshot)) {
            return option::none<VrfConfigSnapshot>();
        };

        let runtime_ref = option::borrow(&runtime_snapshot);
        let snapshot = build_vrf_config_snapshot(runtime_ref);
        option::some(snapshot)
    }

    #[view]
    public fun vrf_config_snapshots(): option::Option<vector<VrfConfigSnapshot>>
    acquires instances::InstanceRegistry, lottery_state::LotteryState {
        if (!instances::is_initialized()) {
            return option::none<vector<VrfConfigSnapshot>>();
        };
        if (!lottery_state::is_initialized()) {
            return option::none<vector<VrfConfigSnapshot>>();
        };

        let registry = instances::borrow_registry(@lottery);
        let state = lottery_state::borrow(@lottery);
        let len = vector::length(&registry.lottery_ids);
        let snapshots = collect_vrf_config_snapshots(&state, &registry.lottery_ids, 0, len);
        option::some(snapshots)
    }

    fun ensure_admin(caller: &signer): &mut instances::InstanceRegistry acquires instances::InstanceRegistry {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);
        registry
    }

    fun ensure_no_pending_request(pending: &lottery_state::PendingRequest) {
        assert!(!option::is_some(&pending.request_id), E_REQUEST_PENDING);
    }

    fun build_vrf_config_snapshot(runtime: &lottery_state::LotteryRuntimeSnapshot): VrfConfigSnapshot {
        let pending_request = lottery_state::PendingRequestSnapshot {
            request_id: runtime.pending_request.request_id,
            last_request_payload_hash: clone_option_bytes(&runtime.pending_request.last_request_payload_hash),
            last_requester: runtime.pending_request.last_requester,
        };
        let whitelist = lottery_state::WhitelistState {
            callback_sender: runtime.whitelist.callback_sender,
            consumers: clone_addresses(&runtime.whitelist.consumers),
            client_snapshot: clone_option_client_snapshot(&runtime.whitelist.client_snapshot),
            consumer_snapshot: clone_option_consumer_snapshot(&runtime.whitelist.consumer_snapshot),
        };
        let request_config = clone_option_request_config(&runtime.request_config);

        VrfConfigSnapshot {
            lottery_id: runtime.lottery_id,
            gas: runtime.gas,
            whitelist,
            request_config,
            pending_request,
            vrf_stats: runtime.vrf_stats,
        }
    }

    fun collect_vrf_config_snapshots(
        state: &lottery_state::LotteryState,
        lottery_ids: &vector<u64>,
        index: u64,
        len: u64,
    ): vector<VrfConfigSnapshot> {
        if (index == len) {
            return vector::empty<VrfConfigSnapshot>();
        };

        let lottery_id = *vector::borrow(lottery_ids, index);
        let mut current = vector::empty<VrfConfigSnapshot>();
        vector::push_back(&mut current, build_vrf_config_snapshot_internal(state, lottery_id));
        let tail = collect_vrf_config_snapshots(state, lottery_ids, index + 1, len);
        append_vrf_config_snapshots(&current, &tail, 0);
        current
    }

    fun build_vrf_config_snapshot_internal(
        state: &lottery_state::LotteryState,
        lottery_id: u64,
    ): VrfConfigSnapshot {
        let runtime_snapshot = lottery_state::runtime_snapshot(lottery_id);
        if (!option::is_some(&runtime_snapshot)) {
            return VrfConfigSnapshot {
                lottery_id,
                gas: lottery_state::GasBudget {
                    max_fee: 0,
                    max_gas_price: 0,
                    max_gas_limit: 0,
                    callback_gas_price: 0,
                    callback_gas_limit: 0,
                    verification_gas_value: 0,
                },
                whitelist: lottery_state::WhitelistState {
                    callback_sender: option::none<address>(),
                    consumers: vector::empty<address>(),
                    client_snapshot: option::none<lottery_state::ClientWhitelistSnapshot>(),
                    consumer_snapshot: option::none<lottery_state::ConsumerWhitelistSnapshot>(),
                },
                request_config: option::none<lottery_state::VrfRequestConfig>(),
                pending_request: lottery_state::PendingRequestSnapshot {
                    request_id: option::none<u64>(),
                    last_request_payload_hash: option::none<vector<u8>>(),
                    last_requester: option::none<address>(),
                },
                vrf_stats: lottery_state::VrfStats {
                    request_count: 0,
                    response_count: 0,
                    next_client_seed: 0,
                },
            };
        };

        let runtime_ref = option::borrow(&runtime_snapshot);
        build_vrf_config_snapshot(runtime_ref)
    }

    fun append_vrf_config_snapshots(
        dst: &vector<VrfConfigSnapshot>,
        src: &vector<VrfConfigSnapshot>,
        index: u64,
    ) {
        let len = vector::length(src);
        if (index == len) {
            return;
        };

        vector::push_back(dst, *vector::borrow(src, index));
        append_vrf_config_snapshots(dst, src, index + 1);
    }

    fun clone_addresses(source: &vector<address>): vector<address> {
        let len = vector::length(source);
        clone_addresses_recursive(source, len)
    }

    fun clone_addresses_recursive(source: &vector<address>, remaining: u64): vector<address> {
        if (remaining == 0) {
            return vector::empty<address>();
        };

        let index = remaining - 1;
        let current = clone_addresses_recursive(source, index);
        vector::push_back(&mut current, *vector::borrow(source, index));
        current
    }

    fun clone_option_client_snapshot(
        value: &option::Option<lottery_state::ClientWhitelistSnapshot>,
    ): option::Option<lottery_state::ClientWhitelistSnapshot> {
        if (option::is_some(value)) {
            let snapshot = option::borrow(value);
            option::some(*snapshot)
        } else {
            option::none<lottery_state::ClientWhitelistSnapshot>()
        }
    }

    fun clone_option_consumer_snapshot(
        value: &option::Option<lottery_state::ConsumerWhitelistSnapshot>,
    ): option::Option<lottery_state::ConsumerWhitelistSnapshot> {
        if (option::is_some(value)) {
            let snapshot = option::borrow(value);
            option::some(*snapshot)
        } else {
            option::none<lottery_state::ConsumerWhitelistSnapshot>()
        }
    }

    fun clone_option_request_config(
        value: &option::Option<lottery_state::VrfRequestConfig>,
    ): option::Option<lottery_state::VrfRequestConfig> {
        if (option::is_some(value)) {
            let config = option::borrow(value);
            option::some(*config)
        } else {
            option::none<lottery_state::VrfRequestConfig>()
        }
    }

    fun clone_option_bytes(value: &option::Option<vector<u8>>): option::Option<vector<u8>> {
        if (option::is_some(value)) {
            let bytes_ref = option::borrow(value);
            option::some(clone_bytes(bytes_ref))
        } else {
            option::none<vector<u8>>()
        }
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        clone_bytes_recursive(source, len)
    }

    fun clone_bytes_recursive(source: &vector<u8>, remaining: u64): vector<u8> {
        if (remaining == 0) {
            return vector::empty<u8>();
        };

        let index = remaining - 1;
        let current = clone_bytes_recursive(source, index);
        vector::push_back(&mut current, *vector::borrow(source, index));
        current
    }

    fun contains_address(list: &vector<address>, target: address): bool {
        let len = vector::length(list);
        contains_from_index(list, target, 0, len)
    }

    fun contains_from_index(
        list: &vector<address>,
        target: address,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            false
        } else {
            let current = *vector::borrow(list, index);
            if (current == target) {
                true
            } else {
                let next_index = index + 1;
                contains_from_index(list, target, next_index, len)
            }
        }
    }

    fun remove_address(list: &mut vector<address>, target: address): bool {
        let len = vector::length(list);
        remove_from_index(list, target, 0, len)
    }

    fun remove_from_index(
        list: &mut vector<address>,
        target: address,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            false
        } else {
            let current = *vector::borrow(list, index);
            if (current == target) {
                vector::swap_remove(list, index);
                true
            } else {
                let next_index = index + 1;
                remove_from_index(list, target, next_index, len)
            }
        }
    }

    fun compute_per_request_fee(
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128,
    ): u64 {
        let gas_sum = safe_add_u128(max_gas_limit, verification_gas_value, E_INVALID_GAS_CONFIG);
        let fee = safe_mul_u128(max_gas_price, gas_sum, E_INVALID_GAS_CONFIG);
        ensure_u128_to_u64(fee, E_INVALID_GAS_CONFIG)
    }

    fun import_single_config(
        registry: &mut instances::InstanceRegistry,
        state: &mut lottery_state::LotteryState,
        config: LegacyVrfConfigImport,
    ) {
        let lottery_id = config.lottery_id;
        let _ = instances::instance(registry, lottery_id);
        validate_import(&config);
        let runtime = lottery_state::runtime_mut(state, lottery_id);
        runtime.gas = normalize_gas_budget(config.gas);
        runtime.whitelist = build_whitelist_state(config.whitelist);
        runtime.request_config = config.request_config;
        runtime.vrf_stats = config.vrf_stats;
        runtime.pending_request = config.pending_request;
        lottery_state::emit_vrf_gas_budget(state, lottery_id);
        lottery_state::emit_vrf_whitelist(state, lottery_id);
        lottery_state::emit_vrf_request_config(state, lottery_id);
    }

    fun import_configs_from_index(
        registry: &mut instances::InstanceRegistry,
        state: &mut lottery_state::LotteryState,
        configs: &vector<LegacyVrfConfigImport>,
        index: u64,
        len: u64,
    ) {
        if (index == len) {
            return;
        };
        let current = *vector::borrow(configs, index);
        import_single_config(registry, state, current);
        import_configs_from_index(registry, state, configs, index + 1, len);
    }

    fun validate_import(config: &LegacyVrfConfigImport) {
        validate_gas_budget(&config.gas);
        validate_whitelist(&config.whitelist, &config.gas);
        validate_request_config(&config.request_config, &config.vrf_stats);
        validate_pending_request(&config.pending_request, &config.request_config);
    }

    fun validate_gas_budget(gas: &lottery_state::GasBudget) {
        assert!(gas.max_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(gas.max_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(gas.callback_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(gas.callback_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(gas.verification_gas_value > 0, E_INVALID_GAS_CONFIG);
        assert!(gas.callback_gas_price <= gas.max_gas_price, E_INVALID_GAS_CONFIG);
        assert!(gas.callback_gas_limit <= gas.max_gas_limit, E_INVALID_GAS_CONFIG);
        let expected_max_fee = compute_per_request_fee(gas.max_gas_price, gas.max_gas_limit, gas.verification_gas_value);
        assert!(gas.max_fee == expected_max_fee, E_INVALID_GAS_CONFIG);
    }

    fun validate_whitelist(
        whitelist: &LegacyWhitelistImport,
        gas: &lottery_state::GasBudget,
    ) {
        assert!(option::is_none(&whitelist.callback_sender) || option::borrow(&whitelist.callback_sender) != &0x0, E_INVALID_CALLBACK_SENDER);
        if (option::is_some(&whitelist.client_snapshot)) {
            let snapshot = option::borrow(&whitelist.client_snapshot);
            assert!(snapshot.max_gas_price == gas.max_gas_price, E_INVALID_GAS_CONFIG);
            assert!(snapshot.max_gas_limit == gas.max_gas_limit, E_INVALID_GAS_CONFIG);
            let min_balance = compute_min_balance(gas.max_gas_price, gas.max_gas_limit, gas.verification_gas_value);
            assert!(snapshot.min_balance_limit >= min_balance, E_INVALID_GAS_CONFIG);
        };
        if (option::is_some(&whitelist.consumer_snapshot)) {
            let snapshot = option::borrow(&whitelist.consumer_snapshot);
            assert!(snapshot.callback_gas_price == gas.callback_gas_price, E_INVALID_GAS_CONFIG);
            assert!(snapshot.callback_gas_limit == gas.callback_gas_limit, E_INVALID_GAS_CONFIG);
        };
        ensure_unique_consumers(&whitelist.consumers, 0, vector::length(&whitelist.consumers));
    }

    fun validate_request_config(
        request_config: &option::Option<lottery_state::VrfRequestConfig>,
        stats: &lottery_state::VrfStats,
    ) {
        if (option::is_some(request_config)) {
            let cfg = option::borrow(request_config);
            assert!(cfg.rng_count == EXPECTED_RNG_COUNT, E_INVALID_REQUEST_CONFIG);
            assert!(cfg.num_confirmations > 0, E_INVALID_REQUEST_CONFIG);
            assert!(cfg.num_confirmations <= MAX_CONFIRMATIONS, E_INVALID_REQUEST_CONFIG);
            assert!(cfg.client_seed < U64_MAX, E_CLIENT_SEED_OVERFLOW);
            assert!(stats.next_client_seed >= cfg.client_seed, E_CLIENT_SEED_REGRESSION);
        };
    }

    fun validate_pending_request(
        pending_request: &lottery_state::PendingRequest,
        request_config: &option::Option<lottery_state::VrfRequestConfig>,
    ) {
        if (option::is_some(&pending_request.request_id)) {
            assert!(option::is_some(request_config), E_INVALID_REQUEST_CONFIG);
            assert!(option::is_some(&pending_request.last_requester), E_REQUEST_PENDING);
            assert!(option::is_some(&pending_request.last_request_payload_hash), E_REQUEST_PENDING);
        };
    }

    fun normalize_gas_budget(gas: lottery_state::GasBudget): lottery_state::GasBudget {
        let max_fee = compute_per_request_fee(gas.max_gas_price, gas.max_gas_limit, gas.verification_gas_value);
        lottery_state::GasBudget {
            max_fee,
            max_gas_price: gas.max_gas_price,
            max_gas_limit: gas.max_gas_limit,
            callback_gas_price: gas.callback_gas_price,
            callback_gas_limit: gas.callback_gas_limit,
            verification_gas_value: gas.verification_gas_value,
        }
    }

    fun build_whitelist_state(whitelist: LegacyWhitelistImport): lottery_state::WhitelistState {
        lottery_state::WhitelistState {
            callback_sender: whitelist.callback_sender,
            consumers: whitelist.consumers,
            client_snapshot: whitelist.client_snapshot,
            consumer_snapshot: whitelist.consumer_snapshot,
        }
    }

    fun ensure_unique_consumers(consumers: &vector<address>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let current = *vector::borrow(consumers, index);
        let has_duplicate = contains_from_index(consumers, current, index + 1, len);
        assert!(!has_duplicate, E_CONSUMER_ALREADY_REGISTERED);
        ensure_unique_consumers(consumers, index + 1, len);
    }


    fun compute_min_balance(
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128,
    ): u128 {
        let gas_sum = safe_add_u128(max_gas_limit, verification_gas_value, E_INVALID_GAS_CONFIG);
        let per_request_fee = safe_mul_u128(max_gas_price, gas_sum, E_INVALID_GAS_CONFIG);
        safe_mul_u128(30u128, per_request_fee, E_INVALID_GAS_CONFIG)
    }

    fun safe_add_u128(a: u128, b: u128, code: u64): u128 {
        let result = a + b;
        assert!(result >= a, code);
        result
    }

    fun safe_mul_u128(a: u128, b: u128, code: u64): u128 {
        if (a == 0 || b == 0) {
            0
        } else {
            let result = a * b;
            assert!(result / a == b, code);
            result
        }
    }

    fun ensure_u128_to_u64(value: u128, code: u64): u64 {
        assert!(value <= U64_MAX_AS_U128, code);
        value as u64
    }
}
