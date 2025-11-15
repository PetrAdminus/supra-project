module lottery_engine::vrf_config {
    use std::option;
    use std::signer;
    use std::vector;

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

    fun ensure_admin(caller: &signer): &mut instances::InstanceRegistry acquires instances::InstanceRegistry {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry_mut(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);
        registry
    }

    fun ensure_no_pending_request(pending: &lottery_state::PendingRequest) {
        assert!(!option::is_some(&pending.request_id), E_REQUEST_PENDING);
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
