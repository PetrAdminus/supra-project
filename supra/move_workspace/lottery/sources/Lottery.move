// sources/Lottery.move
module lottery::main_v2 {
    use std::string;
    use std::bcs;
    use std::option;
    use std::hash;
    use 0x1::timestamp;
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::event;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::supra_vrf;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit;
    use lottery::treasury_v1;

    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NO_TICKETS_AVAILABLE: u64 = 3;
    const E_DRAW_NOT_SCHEDULED: u64 = 4;
    const E_PENDING_REQUEST_STATE: u64 = 6;
    const E_NONCE_MISMATCH: u64 = 7;
    const E_RANDOM_BYTES_TOO_SHORT: u64 = 8;
    const E_INITIAL_DEPOSIT_TOO_LOW: u64 = 9;
    const E_WITHDRAWAL_PENDING_REQUEST: u64 = 10;
    const MIN_REQUEST_WINDOW: u64 = 30;
    const MIN_REQUEST_WINDOW_U128: u128 = 30;
    const EXPECTED_RNG_COUNT: u8 = 1;
    const EXPECTED_RNG_COUNT_U64: u64 = 1;
    const E_TREASURY_NOT_INITIALIZED: u64 = 12;
    const E_PLAYER_STORE_NOT_REGISTERED: u64 = 13;
    const E_INVALID_CALLBACK_PAYLOAD: u64 = 14;
    const E_MIN_BALANCE_OVERFLOW: u64 = 15;
    const E_GAS_CONFIG_NOT_SET: u64 = 16;
    const E_REQUEST_STILL_PENDING: u64 = 17;
    const E_UNEXPECTED_RNG_COUNT: u64 = 18;
    const E_CLIENT_SEED_OVERFLOW: u64 = 19;
    const E_CALLBACK_SOURCE_NOT_SET: u64 = 20;
    const E_CALLBACK_CALLER_NOT_ALLOWED: u64 = 21;
    const E_CONSUMER_ALREADY_WHITELISTED: u64 = 22;
    const E_CONSUMER_NOT_WHITELISTED: u64 = 23;
    const E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH: u64 = 24;
    const E_CONSUMER_WHITELIST_SNAPSHOT_MISMATCH: u64 = 25;
    const E_INVALID_REQUEST_CONFIG: u64 = 26;
    const E_CLIENT_SEED_REGRESSION: u64 = 27;
    const E_GAS_MATH_OVERFLOW: u64 = 28;
    const E_INVALID_GAS_CONFIG: u64 = 29;
    const E_INVALID_CALLBACK_SENDER: u64 = 30;
    const E_INVALID_CONSUMER_ADDRESS: u64 = 31;
    const E_JACKPOT_OVERFLOW: u64 = 32;
    const E_TICKET_ID_OVERFLOW: u64 = 33;
    const E_RNG_REQUEST_OVERFLOW: u64 = 34;
    const E_RNG_RESPONSE_OVERFLOW: u64 = 35;
    const E_RANDOM_INDEX_OVERFLOW: u64 = 36;
    const E_CANNOT_REMOVE_DEFAULT_CONSUMER: u64 = 37;
    const U64_MAX: u64 = 18446744073709551615;
    const U64_MAX_AS_U128: u128 = 18446744073709551615;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;
    const TICKET_PRICE: u64 = 10000000; // 0.01 SUPRA

    struct ClientWhitelistSnapshot has copy, drop, store {
        max_gas_price: u128,
        max_gas_limit: u128,
        min_balance_limit: u128,
    }

    struct ConsumerWhitelistSnapshot has copy, drop, store {
        callback_gas_price: u128,
        callback_gas_limit: u128,
    }

    struct VrfRequestConfig has copy, drop, store {
        rng_count: u8,
        client_seed: u64,
    }

    struct WhitelistStatus has copy, drop {
        aggregator: option::Option<address>,
        consumers: vector<address>,
    }

    struct LotteryData has key {
        tickets: vector<address>,
        jackpot_amount: u64,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
        max_gas_fee: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
        rng_request_count: u64,
        rng_response_count: u64,
        last_request_payload_hash: option::Option<vector<u8>>,
        last_requester: option::Option<address>,
        next_client_seed: u64,
        whitelisted_consumers: vector<address>,
        whitelisted_callback_sender: option::Option<address>,
        client_whitelist_snapshot: option::Option<ClientWhitelistSnapshot>,
        consumer_whitelist_snapshot: option::Option<ConsumerWhitelistSnapshot>,
        vrf_request_config: option::Option<VrfRequestConfig>,
    }

    #[event]
    struct TicketBought has store, copy, drop { buyer: address, ticket_id: u64, amount: u64 }
    #[event]
    struct WinnerSelected has store, copy, drop { winner: address, prize: u64 }
    #[event]
    struct SubscriptionConfiguredEvent has drop, store, copy {
        min_balance: u64,
        per_request_fee: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128,
        initial_deposit: u64,
        callback_sender: option::Option<address>,
        consumer_count: u64,
        pending_request: option::Option<u64>,
    }
    #[event]
    struct MinimumBalanceUpdatedEvent has drop, store, copy {
        min_balance: u64,
        per_request_fee: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128,
        callback_sender: option::Option<address>,
        consumer_count: u64,
        pending_request: option::Option<u64>,
    }
    #[event]
    struct ClientWhitelistRecordedEvent has drop, store, copy {
        max_gas_price: u128,
        max_gas_limit: u128,
        min_balance_limit: u128,
    }
    #[event]
    struct ConsumerWhitelistSnapshotRecordedEvent has drop, store, copy {
        callback_gas_price: u128,
        callback_gas_limit: u128,
    }
    #[event]
    struct VrfRequestConfigUpdatedEvent has drop, store, copy { rng_count: u8, client_seed: u64 }
    #[event]
    struct GasConfigUpdatedEvent has drop, store, copy {
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
        per_request_fee: u64,
        callback_sender: option::Option<address>,
        consumer_count: u64,
        pending_request: option::Option<u64>,
    }
    #[event]
    struct AggregatorWhitelistedEvent has drop, store, copy { aggregator: address }
    #[event]
    struct AggregatorRevokedEvent has drop, store, copy { aggregator: address }
    #[event]
    struct ConsumerWhitelistedEvent has drop, store, copy { consumer: address }
    #[event]
    struct ConsumerRemovedEvent has drop, store, copy { consumer: address }
    #[event]
    struct DrawRequestedEvent has drop, store, copy {
        nonce: u64,
        client_seed: u64,
        request_hash: vector<u8>,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        requester: address,
    }
    #[event]
    struct DrawHandledEvent has drop, store, copy { nonce: u64, success: bool }
    #[event]
    struct FundsWithdrawnEvent has drop, store, copy { admin: address, amount: u64 }

    struct LotteryStatus has copy, drop {
        ticket_count: u64,
        draw_scheduled: bool,
        pending_request: bool,
        jackpot_amount: u64,
        rng_request_count: u64,
        rng_response_count: u64,
    }

    struct VrfRequestEnvelope has copy, drop, store {
        nonce: u64,
        client_seed: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
        requester: address,
    }

    fun copy_option_address(opt: &option::Option<address>): option::Option<address> {
        if (option::is_some(opt)) {
            option::some(*option::borrow(opt))
        } else {
            option::none()
        }
    }

    fun copy_option_u64(opt: &option::Option<u64>): option::Option<u64> {
        if (option::is_some(opt)) {
            option::some(*option::borrow(opt))
        } else {
            option::none()
        }
    }

    fun build_request_envelope(
        nonce: u64,
        client_seed: u64,
        requester: address,
        lottery: &LotteryData
    ): VrfRequestEnvelope {
        VrfRequestEnvelope {
            nonce,
            client_seed,
            max_gas_price: lottery.max_gas_price,
            max_gas_limit: lottery.max_gas_limit,
            callback_gas_price: lottery.callback_gas_price,
            callback_gas_limit: lottery.callback_gas_limit,
            verification_gas_value: lottery.verification_gas_value,
            requester,
        }
    }

    fun encode_request_envelope(envelope: &VrfRequestEnvelope): vector<u8> {
        bcs::to_bytes(envelope)
    }

    fun compute_request_payload_hash(
        nonce: u64,
        client_seed: u64,
        requester: address,
        lottery: &LotteryData
    ): vector<u8> {
        let envelope = build_request_envelope(nonce, client_seed, requester, lottery);
        let encoded = encode_request_envelope(&envelope);
        hash::sha3_256(encoded)
    }

    public entry fun init(sender: &signer) {
        // Only the lottery contract address can initialize
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);
        assert!(!exists<LotteryData>(@lottery), E_ALREADY_INITIALIZED);
        assert!(treasury_v1::is_initialized(), E_TREASURY_NOT_INITIALIZED);

        // Store lottery data at the lottery contract address
        let default_consumers = vector[@lottery];
        move_to(sender, LotteryData {
            tickets: vector::empty(),
            jackpot_amount: 0,
            draw_scheduled: false,
            next_ticket_id: 1,
            pending_request: option::none(),
            max_gas_fee: 0,
            max_gas_price: 0,
            max_gas_limit: 0,
            callback_gas_price: 0,
            callback_gas_limit: 0,
            verification_gas_value: 0,
            rng_request_count: 0,
            rng_response_count: 0,
            last_request_payload_hash: option::none(),
            last_requester: option::none(),
            next_client_seed: 0,
            whitelisted_consumers: default_consumers,
            whitelisted_callback_sender: option::none(),
            client_whitelist_snapshot: option::none(),
            consumer_whitelist_snapshot: option::none(),
            vrf_request_config: option::none(),
        });

        event::emit(ConsumerWhitelistedEvent { consumer: @lottery });
    }

    public entry fun buy_ticket(user: &signer) acquires LotteryData {
        let user_addr = signer::address_of(user);
        let ticket_price = TICKET_PRICE; // 0.01 SUPRA

        assert!(treasury_v1::store_registered(user_addr), E_PLAYER_STORE_NOT_REGISTERED);

        // Withdraw from user and add to contract pool
        treasury_v1::deposit_from_user(user, ticket_price);
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        let new_jackpot = safe_add_u64(lottery.jackpot_amount, ticket_price, E_JACKPOT_OVERFLOW);
        lottery.jackpot_amount = new_jackpot;

        vector::push_back(&mut lottery.tickets, user_addr);
        let ticket_id = lottery.next_ticket_id;
        let next_ticket_id = safe_add_u64(ticket_id, 1, E_TICKET_ID_OVERFLOW);
        lottery.next_ticket_id = next_ticket_id;

        event::emit(TicketBought { buyer: user_addr, ticket_id, amount: ticket_price });

        // If 5+ tickets and draw not scheduled - mark as ready for draw
        if (vector::length(&lottery.tickets) >= 5 && !lottery.draw_scheduled) {
            lottery.draw_scheduled = true;
        }
    }

    public entry fun create_subscription(sender: &signer, initial_deposit: u64) acquires LotteryData {
        create_subscription_internal(sender, initial_deposit, true);
    }

    fun create_subscription_internal(
        sender: &signer,
        initial_deposit: u64,
        call_native: bool
    ) acquires LotteryData {
        // Only lottery admin can create subscription
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);

        let (
            min_balance,
            per_request_fee,
            max_gas_price,
            max_gas_limit,
            verification_gas_value,
            callback_sender,
            consumer_count,
            pending_request
        ) = {
            let lottery = borrow_global<LotteryData>(@lottery);
            ensure_gas_configured(lottery);
            let max_gas_price = lottery.max_gas_price;
            let max_gas_limit = lottery.max_gas_limit;
            let verification_gas_value = lottery.verification_gas_value;
            (
                calculate_min_balance(max_gas_price, max_gas_limit, verification_gas_value),
                calculate_per_request_gas_fee(max_gas_price, max_gas_limit, verification_gas_value),
                max_gas_price,
                max_gas_limit,
                verification_gas_value,
                copy_option_address(&lottery.whitelisted_callback_sender),
                vector::length(&lottery.whitelisted_consumers),
                copy_option_u64(&lottery.pending_request),
            )
        };
        let per_request_fee_u64 = checked_u64_from_u128(per_request_fee, E_MIN_BALANCE_OVERFLOW);
        assert!(initial_deposit >= min_balance, E_INITIAL_DEPOSIT_TOO_LOW);
        if (call_native) {
            deposit::client_setting_minimum_balance(sender, min_balance);
            deposit::deposit_fund(sender, initial_deposit);
            deposit::add_contract_to_whitelist(sender, @lottery);
        };
        event::emit(SubscriptionConfiguredEvent {
            min_balance,
            per_request_fee: per_request_fee_u64,
            max_gas_price,
            max_gas_limit,
            verification_gas_value,
            initial_deposit,
            callback_sender,
            consumer_count,
            pending_request,
        });

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.max_gas_fee = per_request_fee_u64;
    }

    #[test_only]
    public fun create_subscription_for_test(sender: &signer, initial_deposit: u64) acquires LotteryData {
        create_subscription_internal(sender, initial_deposit, false);
    }

    public entry fun whitelist_callback_sender(sender: &signer, aggregator: address) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(option::is_none(&lottery.pending_request), E_REQUEST_STILL_PENDING);
        assert!(aggregator != @0x0, E_INVALID_CALLBACK_SENDER);
        lottery.whitelisted_callback_sender = option::some(aggregator);
        event::emit(AggregatorWhitelistedEvent { aggregator });
    }

    public entry fun revoke_callback_sender(sender: &signer) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(option::is_none(&lottery.pending_request), E_REQUEST_STILL_PENDING);
        assert!(option::is_some(&lottery.whitelisted_callback_sender), E_CALLBACK_SOURCE_NOT_SET);
        let aggregator = option::extract(&mut lottery.whitelisted_callback_sender);
        event::emit(AggregatorRevokedEvent { aggregator });
    }

    public entry fun whitelist_consumer(sender: &signer, consumer: address) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(consumer != @0x0, E_INVALID_CONSUMER_ADDRESS);
        assert!(!is_consumer_whitelisted(&lottery.whitelisted_consumers, consumer), E_CONSUMER_ALREADY_WHITELISTED);
        vector::push_back(&mut lottery.whitelisted_consumers, consumer);
        event::emit(ConsumerWhitelistedEvent { consumer });
    }

    public entry fun remove_consumer(sender: &signer, consumer: address) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(consumer != @lottery, E_CANNOT_REMOVE_DEFAULT_CONSUMER);
        let removed = remove_consumer_from_list(&mut lottery.whitelisted_consumers, consumer);
        assert!(removed, E_CONSUMER_NOT_WHITELISTED);
        event::emit(ConsumerRemovedEvent { consumer });
    }

    public entry fun set_minimum_balance(sender: &signer) acquires LotteryData {
        set_minimum_balance_internal(sender, true);
    }

    fun set_minimum_balance_internal(sender: &signer, call_native: bool) acquires LotteryData {
        let admin = signer::address_of(sender);
        // Only lottery admin can update gas settings
        assert!(admin == @lottery, E_NOT_OWNER);

        let (min_balance, per_request_fee, max_gas_price, max_gas_limit, verification_gas_value) = {
            let lottery = borrow_global<LotteryData>(@lottery);
            ensure_gas_configured(lottery);
            let max_gas_price = lottery.max_gas_price;
            let max_gas_limit = lottery.max_gas_limit;
            let verification_gas_value = lottery.verification_gas_value;
            (
                calculate_min_balance(max_gas_price, max_gas_limit, verification_gas_value),
                calculate_per_request_gas_fee(max_gas_price, max_gas_limit, verification_gas_value),
                max_gas_price,
                max_gas_limit,
                verification_gas_value
            )
        };
        let per_request_fee_u64 = checked_u64_from_u128(per_request_fee, E_MIN_BALANCE_OVERFLOW);
        if (call_native) {
            deposit::client_setting_minimum_balance(sender, min_balance);
        };

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.max_gas_fee = per_request_fee_u64;
        let callback_sender = copy_option_address(&lottery.whitelisted_callback_sender);
        let consumer_count = vector::length(&lottery.whitelisted_consumers);
        let pending_request = copy_option_u64(&lottery.pending_request);
        event::emit(MinimumBalanceUpdatedEvent {
            min_balance,
            per_request_fee: per_request_fee_u64,
            max_gas_price,
            max_gas_limit,
            verification_gas_value,
            callback_sender,
            consumer_count,
            pending_request,
        });
    }

    #[test_only]
    public fun set_minimum_balance_for_test(sender: &signer) acquires LotteryData {
        set_minimum_balance_internal(sender, false);
    }

    public entry fun configure_vrf_gas(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128
    ) acquires LotteryData {
        configure_vrf_gas_internal(
            sender,
            max_gas_price,
            max_gas_limit,
            callback_gas_price,
            callback_gas_limit,
            verification_gas_value
        );
    }

    public entry fun record_client_whitelist_snapshot(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        min_balance_limit: u128
    ) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        ensure_gas_configured_values(
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.verification_gas_value,
        );
        assert!(lottery.max_gas_price == max_gas_price, E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH);
        assert!(lottery.max_gas_limit == max_gas_limit, E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH);

        let computed_min_balance = calculate_min_balance(
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.verification_gas_value,
        );
        let min_balance_limit_u64 = checked_u64_from_u128(
            min_balance_limit,
            E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH,
        );
        assert!(min_balance_limit_u64 >= computed_min_balance, E_CLIENT_WHITELIST_SNAPSHOT_MISMATCH);

        let snapshot = ClientWhitelistSnapshot {
            max_gas_price,
            max_gas_limit,
            min_balance_limit,
        };
        lottery.client_whitelist_snapshot = option::some(snapshot);

        event::emit(ClientWhitelistRecordedEvent {
            max_gas_price,
            max_gas_limit,
            min_balance_limit,
        });
    }

    public entry fun record_consumer_whitelist_snapshot(
        sender: &signer,
        callback_gas_price: u128,
        callback_gas_limit: u128
    ) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.callback_gas_price == callback_gas_price, E_CONSUMER_WHITELIST_SNAPSHOT_MISMATCH);
        assert!(lottery.callback_gas_limit == callback_gas_limit, E_CONSUMER_WHITELIST_SNAPSHOT_MISMATCH);

        let snapshot = ConsumerWhitelistSnapshot {
            callback_gas_price,
            callback_gas_limit,
        };
        lottery.consumer_whitelist_snapshot = option::some(snapshot);

        event::emit(ConsumerWhitelistSnapshotRecordedEvent {
            callback_gas_price,
            callback_gas_limit,
        });
    }

    public entry fun configure_vrf_request(
        sender: &signer,
        rng_count: u8,
        client_seed: u64
    ) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(option::is_none(&lottery.pending_request), E_REQUEST_STILL_PENDING);
        assert!(rng_count == EXPECTED_RNG_COUNT, E_INVALID_REQUEST_CONFIG);
        assert!(client_seed < U64_MAX, E_CLIENT_SEED_OVERFLOW);

        let current_seed = lottery.next_client_seed;
        assert!(client_seed >= current_seed, E_CLIENT_SEED_REGRESSION);

        lottery.next_client_seed = client_seed;
        lottery.vrf_request_config = option::some(VrfRequestConfig { rng_count, client_seed });

        event::emit(VrfRequestConfigUpdatedEvent { rng_count, client_seed });
    }

    fun configure_vrf_gas_internal(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128
    ) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(option::is_none(&lottery.pending_request), E_REQUEST_STILL_PENDING);
        assert!(max_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(max_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_price > 0, E_INVALID_GAS_CONFIG);
        assert!(callback_gas_limit > 0, E_INVALID_GAS_CONFIG);
        assert!(verification_gas_value > 0, E_INVALID_GAS_CONFIG);
        lottery.max_gas_price = max_gas_price;
        lottery.max_gas_limit = max_gas_limit;
        lottery.callback_gas_price = callback_gas_price;
        lottery.callback_gas_limit = callback_gas_limit;
        lottery.verification_gas_value = verification_gas_value;
        let per_request_fee = calculate_per_request_gas_fee(
            max_gas_price,
            max_gas_limit,
            verification_gas_value,
        );
        let per_request_fee_u64 = checked_u64_from_u128(per_request_fee, E_MIN_BALANCE_OVERFLOW);
        lottery.max_gas_fee = per_request_fee_u64;
        let callback_sender = copy_option_address(&lottery.whitelisted_callback_sender);
        let consumer_count = vector::length(&lottery.whitelisted_consumers);
        let pending_request = copy_option_u64(&lottery.pending_request);
        event::emit(GasConfigUpdatedEvent {
            max_gas_price,
            max_gas_limit,
            callback_gas_price,
            callback_gas_limit,
            verification_gas_value,
            per_request_fee: per_request_fee_u64,
            callback_sender,
            consumer_count,
            pending_request,
        });
    }

    #[test_only]
    public fun configure_vrf_gas_for_test(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128
    ) acquires LotteryData {
        configure_vrf_gas_internal(
            sender,
            max_gas_price,
            max_gas_limit,
            callback_gas_price,
            callback_gas_limit,
            verification_gas_value
        );
    }

    public entry fun withdraw_funds(sender: &signer, amount: u64) acquires LotteryData {
        withdraw_funds_internal(sender, amount, true);
    }

    fun withdraw_funds_internal(sender: &signer, amount: u64, call_native: bool) acquires LotteryData {
        let admin = signer::address_of(sender);
        // Only lottery admin can withdraw funds
        assert!(admin == @lottery, E_NOT_OWNER);

        let can_withdraw = {
            let lottery = borrow_global<LotteryData>(@lottery);
            option::is_none(&lottery.pending_request)
        };
        assert!(can_withdraw, E_WITHDRAWAL_PENDING_REQUEST);

        if (call_native) {
            deposit::withdraw_fund(sender, amount);
        };

        event::emit(FundsWithdrawnEvent { admin, amount });
    }

    #[test_only]
    public fun withdraw_funds_for_test(sender: &signer, amount: u64) acquires LotteryData {
        withdraw_funds_internal(sender, amount, false);
    }

    public entry fun manual_draw(sender: &signer) acquires LotteryData {
        // Only lottery admin can trigger manual draw
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, E_DRAW_NOT_SCHEDULED); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, E_NO_TICKETS_AVAILABLE); // Must have tickets
        assert!(option::is_none(&lottery.pending_request), E_PENDING_REQUEST_STATE); // Prevent overlapping requests

        // Request random number for draw
        request_draw(lottery, sender);
    }

    public entry fun simple_draw(sender: &signer) acquires LotteryData {
        // Only lottery admin can trigger simple draw
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, E_DRAW_NOT_SCHEDULED); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, E_NO_TICKETS_AVAILABLE); // Must have tickets
        assert!(option::is_none(&lottery.pending_request), E_PENDING_REQUEST_STATE); // Respect pending VRF request

        // Simple deterministic draw using block timestamp
        let len = vector::length(&lottery.tickets);
        let timestamp = timestamp::now_microseconds();
        let idx = timestamp % len;
        let winner = *vector::borrow(&lottery.tickets, idx);

        // Transfer prize to winner and system vaults according to config
        let prize_amount = treasury_v1::distribute_payout(winner, lottery.jackpot_amount);

        event::emit(WinnerSelected { winner, prize: prize_amount });

        // Reset lottery
        lottery.tickets = vector::empty();
        lottery.jackpot_amount = 0;
        lottery.draw_scheduled = false;
        lottery.next_ticket_id = 1;
    }

    fun request_draw(lottery: &mut LotteryData, sender: &signer) {
        ensure_gas_configured_values(
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.verification_gas_value,
        );
        ensure_callback_sender_configured_internal(&lottery.whitelisted_callback_sender);
        let requester = signer::address_of(sender);
        ensure_consumer_whitelisted_internal(&lottery.whitelisted_consumers, requester);

        let client_seed = next_client_seed(lottery);

        let callback_address = @lottery;
        let callback_module = string::utf8(b"main_v2");
        let callback_function = string::utf8(b"on_random_received");

        let nonce = supra_vrf::rng_request(
            sender,
            callback_address,
            callback_module,
            callback_function,
            EXPECTED_RNG_COUNT, // number of random values
            client_seed, // client_seed
            1  // confirmations
        );

        record_vrf_request(lottery, nonce, client_seed, requester);
    }

    fun next_client_seed(lottery: &mut LotteryData): u64 {
        let current = lottery.next_client_seed;
        assert!(current < U64_MAX, E_CLIENT_SEED_OVERFLOW);
        lottery.next_client_seed = current + 1;
        current
    }

    fun record_vrf_request(
        lottery: &mut LotteryData,
        nonce: u64,
        client_seed: u64,
        requester: address
    ) {
        let envelope = build_request_envelope(nonce, client_seed, requester, lottery);
        let payload = encode_request_envelope(&envelope);
        let stored_hash = hash::sha3_256(copy payload);
        let event_hash = copy stored_hash;
        lottery.pending_request = option::some(nonce);
        lottery.last_request_payload_hash = option::some(stored_hash);
        lottery.last_requester = option::some(requester);
        lottery.vrf_request_config = option::some(VrfRequestConfig {
            rng_count: EXPECTED_RNG_COUNT,
            client_seed,
        });
        lottery.rng_request_count = safe_add_u64(
            lottery.rng_request_count,
            1,
            E_RNG_REQUEST_OVERFLOW,
        );
        event::emit(DrawRequestedEvent {
            nonce,
            client_seed,
            request_hash: event_hash,
            callback_gas_price: lottery.callback_gas_price,
            callback_gas_limit: lottery.callback_gas_limit,
            requester,
        });
    }

    #[test_only]
    public fun set_pending_request_for_test(nonce: option::Option<u64>) acquires LotteryData {
        set_pending_request_and_hash_for_test(nonce, option::none(), option::none());
    }

    #[test_only]
    public fun set_pending_request_and_hash_for_test(
        nonce: option::Option<u64>,
        payload_hash: option::Option<vector<u8>>,
        requester: option::Option<address>
    ) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.pending_request = nonce;
        lottery.last_request_payload_hash = payload_hash;
        lottery.last_requester = requester;
    }

    #[test_only]
    public fun clear_pending_request_state_for_test() acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        clear_pending_request_state(lottery);
    }

    #[test_only]
    public fun set_draw_state_for_test(draw_scheduled: bool, tickets: vector<address>) acquires LotteryData {
        let ticket_count = vector::length(&tickets);
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.draw_scheduled = draw_scheduled;
        lottery.tickets = tickets;
        lottery.next_ticket_id = safe_add_u64(ticket_count, 1, E_TICKET_ID_OVERFLOW);
    }

    #[test_only]
    public fun set_jackpot_amount_for_test(amount: u64) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.jackpot_amount = amount;
    }

    #[test_only]
    public fun set_next_ticket_id_for_test(next_id: u64) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.next_ticket_id = next_id;
    }

    #[test_only]
    public fun next_ticket_id_for_test(): u64 acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        lottery.next_ticket_id
    }

    #[test_only]
    public fun handle_verified_random_for_test(
        nonce: u64,
        message: vector<u8>,
        verified_nums: vector<u256>,
        rng_count: u8,
        client_seed: u64,
        caller_address: address
    ) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        handle_verified_random(lottery, nonce, message, verified_nums, rng_count, client_seed, caller_address);
    }
    #[test_only]
    public fun ticket_bought_fields(event: &TicketBought): (address, u64, u64) {
        (event.buyer, event.ticket_id, event.amount)
    }

    #[test_only]
    public fun winner_selected_fields(event: &WinnerSelected): (address, u64) {
        (event.winner, event.prize)
    }

    #[test_only]
    public fun funds_withdrawn_fields(event: &FundsWithdrawnEvent): (address, u64) {
        (event.admin, event.amount)
    }

    #[test_only]
    public fun minimum_balance_updated_fields(event: &MinimumBalanceUpdatedEvent): (u64, u64, u128, u128, u128) {
        (
            event.min_balance,
            event.per_request_fee,
            event.max_gas_price,
            event.max_gas_limit,
            event.verification_gas_value
        )
    }

    #[test_only]
    public fun minimum_balance_event_context(
        event: &MinimumBalanceUpdatedEvent
    ): (option::Option<address>, u64, option::Option<u64>) {
        (event.callback_sender, event.consumer_count, event.pending_request)
    }

    #[test_only]
    public fun client_whitelist_recorded_fields(event: &ClientWhitelistRecordedEvent): (u128, u128, u128) {
        (
            event.max_gas_price,
            event.max_gas_limit,
            event.min_balance_limit,
        )
    }

    #[test_only]
    public fun consumer_whitelist_snapshot_fields(event: &ConsumerWhitelistSnapshotRecordedEvent): (u128, u128) {
        (event.callback_gas_price, event.callback_gas_limit)
    }

    #[test_only]
    public fun vrf_request_config_fields(event: &VrfRequestConfigUpdatedEvent): (u8, u64) {
        (event.rng_count, event.client_seed)
    }

    #[test_only]
    public fun consumer_whitelisted_fields(event: &ConsumerWhitelistedEvent): address {
        event.consumer
    }

    #[test_only]
    public fun consumer_removed_fields(event: &ConsumerRemovedEvent): address {
        event.consumer
    }

    #[test_only]
    public fun aggregator_whitelisted_fields(event: &AggregatorWhitelistedEvent): address {
        event.aggregator
    }

    #[test_only]
    public fun aggregator_revoked_fields(event: &AggregatorRevokedEvent): address {
        event.aggregator
    }

    #[test_only]
    public fun gas_config_updated_fields(event: &GasConfigUpdatedEvent): (u128, u128, u128, u128, u128, u64) {
        (
            event.max_gas_price,
            event.max_gas_limit,
            event.callback_gas_price,
            event.callback_gas_limit,
            event.verification_gas_value,
            event.per_request_fee
        )
    }

    #[test_only]
    public fun gas_config_event_context(
        event: &GasConfigUpdatedEvent
    ): (option::Option<address>, u64, option::Option<u64>) {
        (event.callback_sender, event.consumer_count, event.pending_request)
    }

    #[test_only]
    public fun subscription_configured_context(
        event: &SubscriptionConfiguredEvent
    ): (option::Option<address>, u64, option::Option<u64>) {
        (event.callback_sender, event.consumer_count, event.pending_request)
    }

    #[test_only]
    public fun subscription_configured_fields(
        event: &SubscriptionConfiguredEvent
    ): (u64, u64, u128, u128, u128, u64) {
        (
            event.min_balance,
            event.per_request_fee,
            event.max_gas_price,
            event.max_gas_limit,
            event.verification_gas_value,
            event.initial_deposit,
        )
    }

    #[test_only]
    public fun whitelist_status_fields(
        status: &WhitelistStatus
    ): (option::Option<address>, vector<address>) {
        let mut consumers = vector::empty<address>();
        let mut i = 0;
        let len = vector::length(&status.consumers);
        while (i < len) {
            let consumer = *vector::borrow(&status.consumers, i);
            vector::push_back(&mut consumers, consumer);
            i = i + 1;
        };
        (status.aggregator, consumers)
    }

    #[test_only]
    public fun client_whitelist_snapshot_fields(
        snapshot_opt: &option::Option<ClientWhitelistSnapshot>
    ): option::Option<(u128, u128, u128)> {
        if (option::is_some(snapshot_opt)) {
            let snapshot = option::borrow(snapshot_opt);
            option::some((
                snapshot.max_gas_price,
                snapshot.max_gas_limit,
                snapshot.min_balance_limit,
            ))
        } else {
            option::none()
        }
    }

    #[test_only]
    public fun consumer_whitelist_snapshot_fields(
        snapshot_opt: &option::Option<ConsumerWhitelistSnapshot>
    ): option::Option<(u128, u128)> {
        if (option::is_some(snapshot_opt)) {
            let snapshot = option::borrow(snapshot_opt);
            option::some((
                snapshot.callback_gas_price,
                snapshot.callback_gas_limit,
            ))
        } else {
            option::none()
        }
    }

    #[test_only]
    public fun vrf_request_config_fields(
        config_opt: &option::Option<VrfRequestConfig>
    ): option::Option<(u8, u64)> {
        if (option::is_some(config_opt)) {
            let config = option::borrow(config_opt);
            option::some((config.rng_count, config.client_seed))
        } else {
            option::none()
        }
    }

    #[test_only]
    public fun draw_requested_fields(event: &DrawRequestedEvent): (u64, u64, vector<u8>, u128, u128, address) {
        (
            event.nonce,
            event.client_seed,
            event.request_hash,
            event.callback_gas_price,
            event.callback_gas_limit,
            event.requester
        )
    }

    #[test_only]
    public fun record_request_for_test(nonce: u64, requester: address) acquires LotteryData {
        {
            let lottery_view = borrow_global<LotteryData>(@lottery);
            ensure_gas_configured(lottery_view);
            ensure_callback_sender_configured(lottery_view);
            ensure_consumer_whitelisted(lottery_view, requester);
        };
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        let client_seed = next_client_seed(lottery);
        record_vrf_request(lottery, nonce, client_seed, requester);
    }

    #[test_only]
    public fun draw_handled_fields(event: &DrawHandledEvent): (u64, bool) {
        (event.nonce, event.success)
    }

    #[test_only]
    public fun validate_payload_hash_for_test(
        nonce: u64,
        client_seed: u64,
        message: vector<u8>
    ) acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        assert!(option::is_some(&lottery.last_requester), E_INVALID_CALLBACK_PAYLOAD);
        let requester = *option::borrow(&lottery.last_requester);
        ensure_payload_hash_matches(
            &lottery.last_request_payload_hash,
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.callback_gas_price,
            lottery.callback_gas_limit,
            lottery.verification_gas_value,
            nonce,
            client_seed,
            requester,
            message,
        );
    }

    #[test_only]
    public fun request_payload_message_for_test(
        nonce: u64,
        client_seed: u64,
        requester: address
    ): vector<u8> acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        let envelope = build_request_envelope(nonce, client_seed, requester, lottery);
        encode_request_envelope(&envelope)
    }

    #[test_only]
    public fun lottery_status_fields(status: &LotteryStatus): (u64, bool, bool, u64, u64, u64) {
        (
            status.ticket_count,
            status.draw_scheduled,
            status.pending_request,
            status.jackpot_amount,
            status.rng_request_count,
            status.rng_response_count
        )
    }

    #[test_only]
    public fun compute_request_payload_hash_for_test(
        nonce: u64,
        client_seed: u64,
        requester: address
    ): vector<u8> acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        compute_request_payload_hash(nonce, client_seed, requester, lottery)
    }

    #[test_only]
    public fun rng_counters_for_test(): (u64, u64) acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        (lottery.rng_request_count, lottery.rng_response_count)
    }

    #[test_only]
    public fun set_rng_counters_for_test(requests: u64, responses: u64) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.rng_request_count = requests;
        lottery.rng_response_count = responses;
    }

    #[test_only]
    public fun set_callback_aggregator_for_test(value: option::Option<address>) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.whitelisted_callback_sender = value;
    }

    #[test_only]
    public fun next_client_seed_for_test(): u64 acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        lottery.next_client_seed
    }

    fun handle_verified_random(
        lottery: &mut LotteryData,
        nonce: u64,
        message: vector<u8>,
        verified_nums: vector<u256>,
        rng_count: u8,
        client_seed: u64,
        caller_address: address,
    ) {
        assert!(vector::length(&lottery.tickets) > 0, E_NO_TICKETS_AVAILABLE);
        assert!(option::is_some(&lottery.pending_request), E_PENDING_REQUEST_STATE);
        assert!(lottery.draw_scheduled, E_DRAW_NOT_SCHEDULED);
        let expected_nonce = *option::borrow(&lottery.pending_request);
        assert!(expected_nonce == nonce, E_NONCE_MISMATCH);
        ensure_callback_caller_allowed_internal(&lottery.whitelisted_callback_sender, caller_address);
        assert!(option::is_some(&lottery.last_requester), E_INVALID_CALLBACK_PAYLOAD);
        let expected_requester = *option::borrow(&lottery.last_requester);
        ensure_payload_hash_matches(
            &lottery.last_request_payload_hash,
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.callback_gas_price,
            lottery.callback_gas_limit,
            lottery.verification_gas_value,
            nonce,
            client_seed,
            expected_requester,
            message,
        );

        assert!(rng_count == EXPECTED_RNG_COUNT, E_UNEXPECTED_RNG_COUNT);
        let actual_len = vector::length(&verified_nums);
        assert!(actual_len == EXPECTED_RNG_COUNT_U64, E_UNEXPECTED_RNG_COUNT);

        clear_pending_request_state(lottery);

        let len = vector::length(&lottery.tickets);
        let random_num = *vector::borrow(&verified_nums, 0);
        let random_bytes = bcs::to_bytes(&random_num);
        let idx_seed = first_u64_from_bytes(&random_bytes);
        let idx = idx_seed % len;
        let winner = *vector::borrow(&lottery.tickets, idx);

        let prize_amount = treasury_v1::distribute_payout(winner, lottery.jackpot_amount);

        lottery.rng_response_count = safe_add_u64(
            lottery.rng_response_count,
            1,
            E_RNG_RESPONSE_OVERFLOW,
        );
        event::emit(WinnerSelected { winner, prize: prize_amount });
        event::emit(DrawHandledEvent { nonce, success: true });

        lottery.tickets = vector::empty();
        lottery.jackpot_amount = 0;
        lottery.draw_scheduled = false;
        lottery.next_ticket_id = 1;
    }

    public entry fun on_random_received(
        nonce: u64,
        message: vector<u8>,
        signature: vector<u8>,
        caller_address: address,
        rng_count: u8,
        client_seed: u64,
    ) acquires LotteryData {
        let message_for_verification = copy message;
        let verified_nums: vector<u256> = supra_vrf::verify_callback(
            nonce,
            message_for_verification,
            signature,
            caller_address,
            rng_count,
            client_seed
        );

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        let caller = caller_address;
        handle_verified_random(lottery, nonce, message, verified_nums, rng_count, client_seed, caller);
    }

    #[view]
    public fun get_ticket_price(): u64 {
        TICKET_PRICE
    }

    #[view]
    public fun get_ticket_count(): u64 acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            0
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            vector::length(&lottery.tickets)
        }
    }

    #[view]
    public fun get_jackpot_amount(): u64 acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            0
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            lottery.jackpot_amount
        }
    }

    #[view]
    public fun is_vrf_request_pending(): bool acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            false
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            option::is_some(&lottery.pending_request)
        }
    }

    #[view]
    public fun get_max_gas_fee(): u64 acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            0
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            lottery.max_gas_fee
        }
    }

    #[view]
    public fun get_vrf_gas_config(): (u128, u128) acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            (0, 0)
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            (lottery.max_gas_price, lottery.max_gas_limit)
        }
    }

    #[view]
    public fun get_verification_gas_value(): u128 acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            0
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            lottery.verification_gas_value
        }
    }

    #[view]
    public fun get_callback_gas_config(): (u128, u128) acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            (0, 0)
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            (lottery.callback_gas_price, lottery.callback_gas_limit)
        }
    }

    #[view]
    public fun get_rng_counters(): (u64, u64) acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            (0, 0)
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            (lottery.rng_request_count, lottery.rng_response_count)
        }
    }

    #[view]
    public fun get_lottery_status(): LotteryStatus acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            LotteryStatus {
                ticket_count: 0,
                draw_scheduled: false,
                pending_request: false,
                jackpot_amount: 0,
                rng_request_count: 0,
                rng_response_count: 0,
            }
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            LotteryStatus {
                ticket_count: vector::length(&lottery.tickets),
                draw_scheduled: lottery.draw_scheduled,
                pending_request: option::is_some(&lottery.pending_request),
                jackpot_amount: lottery.jackpot_amount,
                rng_request_count: lottery.rng_request_count,
                rng_response_count: lottery.rng_response_count,
            }
        }
    }

    #[view]
    public fun get_registered_tickets(): vector<address> acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            vector::empty<address>()
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            let mut tickets = vector::empty<address>();
            let mut i = 0;
            let len = vector::length(&lottery.tickets);
            while (i < len) {
                let ticket = *vector::borrow(&lottery.tickets, i);
                vector::push_back(&mut tickets, ticket);
                i = i + 1;
            };
            tickets
        }
    }

    #[view]
    public fun get_whitelist_status(): WhitelistStatus acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            WhitelistStatus {
                aggregator: option::none(),
                consumers: vector::empty<address>(),
            }
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            let mut consumers = vector::empty<address>();
            let len = vector::length(&lottery.whitelisted_consumers);
            let mut i = 0;
            while (i < len) {
                let consumer = *vector::borrow(&lottery.whitelisted_consumers, i);
                vector::push_back(&mut consumers, consumer);
                i = i + 1;
            };

            let aggregator = if (option::is_some(&lottery.whitelisted_callback_sender)) {
                option::some(*option::borrow(&lottery.whitelisted_callback_sender))
            } else {
                option::none()
            };

            WhitelistStatus { aggregator, consumers }
        }
    }

    #[view]
    public fun get_client_whitelist_snapshot(): option::Option<ClientWhitelistSnapshot> acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            option::none()
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            if (option::is_some(&lottery.client_whitelist_snapshot)) {
                let snapshot = *option::borrow(&lottery.client_whitelist_snapshot);
                option::some(snapshot)
            } else {
                option::none()
            }
        }
    }

    #[view]
    public fun get_min_balance_limit_snapshot(): option::Option<u128> acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            option::none()
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            if (option::is_some(&lottery.client_whitelist_snapshot)) {
                let snapshot = option::borrow(&lottery.client_whitelist_snapshot);
                option::some(snapshot.min_balance_limit)
            } else {
                option::none()
            }
        }
    }

    #[view]
    public fun get_consumer_whitelist_snapshot(): option::Option<ConsumerWhitelistSnapshot> acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            option::none()
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            if (option::is_some(&lottery.consumer_whitelist_snapshot)) {
                let snapshot = *option::borrow(&lottery.consumer_whitelist_snapshot);
                option::some(snapshot)
            } else {
                option::none()
            }
        }
    }

    #[view]
    public fun get_vrf_request_config(): option::Option<VrfRequestConfig> acquires LotteryData {
        if (!exists<LotteryData>(@lottery)) {
            option::none()
        } else {
            let lottery = borrow_global<LotteryData>(@lottery);
            if (option::is_some(&lottery.vrf_request_config)) {
                let config = *option::borrow(&lottery.vrf_request_config);
                option::some(config)
            } else {
                option::none()
            }
        }
    }

    fun ensure_gas_configured(lottery: &LotteryData) {
        ensure_gas_configured_values(
            lottery.max_gas_price,
            lottery.max_gas_limit,
            lottery.verification_gas_value,
        );
    }

    fun ensure_gas_configured_values(
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128
    ) {
        assert!(max_gas_price > 0, E_GAS_CONFIG_NOT_SET);
        assert!(max_gas_limit > 0, E_GAS_CONFIG_NOT_SET);
        assert!(verification_gas_value > 0, E_GAS_CONFIG_NOT_SET);
    }

    fun ensure_callback_sender_configured(lottery: &LotteryData): address {
        ensure_callback_sender_configured_internal(&lottery.whitelisted_callback_sender)
    }

    fun ensure_callback_caller_allowed(lottery: &LotteryData, caller_address: address) {
        let aggregator = ensure_callback_sender_configured(lottery);
        assert!(aggregator == caller_address, E_CALLBACK_CALLER_NOT_ALLOWED);
    }

    fun ensure_callback_sender_configured_internal(
        callback_sender: &option::Option<address>
    ): address {
        assert!(option::is_some(callback_sender), E_CALLBACK_SOURCE_NOT_SET);
        *option::borrow(callback_sender)
    }

    fun ensure_callback_caller_allowed_internal(
        callback_sender: &option::Option<address>,
        caller_address: address
    ) {
        let aggregator = ensure_callback_sender_configured_internal(callback_sender);
        assert!(aggregator == caller_address, E_CALLBACK_CALLER_NOT_ALLOWED);
    }

    fun ensure_consumer_whitelisted(lottery: &LotteryData, consumer: address) {
        ensure_consumer_whitelisted_internal(&lottery.whitelisted_consumers, consumer);
    }

    fun ensure_consumer_whitelisted_internal(consumers: &vector<address>, consumer: address) {
        assert!(is_consumer_whitelisted(consumers, consumer), E_CONSUMER_NOT_WHITELISTED);
    }

    fun is_consumer_whitelisted(consumers: &vector<address>, target: address): bool {
        let mut i = 0;
        let len = vector::length(consumers);
        while (i < len) {
            if (*vector::borrow(consumers, i) == target) {
                return true;
            };
            i = i + 1;
        };
        false
    }

    fun remove_consumer_from_list(consumers: &mut vector<address>, target: address): bool {
        let len = vector::length(consumers);
        let mut i = 0;
        while (i < len) {
            if (*vector::borrow(consumers, i) == target) {
                vector::swap_remove(consumers, i);
                return true;
            };
            i = i + 1;
        };
        false
    }

    fun clear_pending_request_state(lottery: &mut LotteryData) {
        lottery.pending_request = option::none();
        lottery.last_request_payload_hash = option::none();
        lottery.last_requester = option::none();
        lottery.vrf_request_config = option::none();
    }

    fun calculate_per_request_gas_fee(
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128
    ): u128 {
        let gas_sum = safe_add_u128(
            max_gas_limit,
            verification_gas_value,
            E_GAS_MATH_OVERFLOW,
        );
        safe_mul_u128(max_gas_price, gas_sum, E_GAS_MATH_OVERFLOW)
    }

    fun calculate_min_balance(
        max_gas_price: u128,
        max_gas_limit: u128,
        verification_gas_value: u128
    ): u64 {
        let per_request_fee = calculate_per_request_gas_fee(
            max_gas_price,
            max_gas_limit,
            verification_gas_value,
        );
        let min_balance_u128 = safe_mul_u128(
            MIN_REQUEST_WINDOW_U128,
            per_request_fee,
            E_GAS_MATH_OVERFLOW,
        );
        checked_u64_from_u128(min_balance_u128, E_MIN_BALANCE_OVERFLOW)
    }

    fun checked_u64_from_u128(value: u128, abort_code: u64): u64 {
        assert!(value <= U64_MAX_AS_U128, abort_code);
        let mut result = 0;
        let mut temp = value;
        let mut base = 1;
        while (temp > 0) {
            let bit = temp % 2;
            if (bit == 1) {
                result = safe_add_u64(result, base, abort_code);
            };
            temp = temp / 2;
            if (temp > 0) {
                base = safe_mul_u64(base, 2, abort_code);
            };
        };
        result
    }

    fun safe_add_u64(a: u64, b: u64, abort_code: u64): u64 {
        assert!(b <= U64_MAX - a, abort_code);
        a + b
    }

    fun safe_mul_u64(a: u64, b: u64, abort_code: u64): u64 {
        if (a == 0 || b == 0) {
            0
        } else {
            assert!(a <= U64_MAX / b, abort_code);
            a * b
        }
    }

    fun safe_add_u128(a: u128, b: u128, abort_code: u64): u128 {
        assert!(b <= U128_MAX - a, abort_code);
        a + b
    }

    fun safe_mul_u128(a: u128, b: u128, abort_code: u64): u128 {
        if (a == 0 || b == 0) {
            0
        } else {
            assert!(a <= U128_MAX / b, abort_code);
            a * b
        }
    }

    fun ensure_payload_hash_matches(
        stored_hash_opt: &option::Option<vector<u8>>,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
        nonce: u64,
        client_seed: u64,
        expected_requester: address,
        message: vector<u8>
    ) {
        assert!(option::is_some(stored_hash_opt), E_INVALID_CALLBACK_PAYLOAD);
        let stored_hash = option::borrow(stored_hash_opt);
        let payload_hash = hash::sha3_256(copy message);
        assert!(vector_equals(stored_hash, &payload_hash), E_INVALID_CALLBACK_PAYLOAD);

        let envelope = VrfRequestEnvelope {
            nonce,
            client_seed,
            max_gas_price,
            max_gas_limit,
            callback_gas_price,
            callback_gas_limit,
            verification_gas_value,
            requester: expected_requester,
        };
        let expected_payload = encode_request_envelope(&envelope);
        let expected_hash = hash::sha3_256(copy expected_payload);
        assert!(vector_equals(&payload_hash, &expected_hash), E_INVALID_CALLBACK_PAYLOAD);
        assert!(vector_equals(&message, &expected_payload), E_INVALID_CALLBACK_PAYLOAD);
    }

    fun vector_equals(lhs: &vector<u8>, rhs: &vector<u8>): bool {
        if (vector::length(lhs) != vector::length(rhs)) {
            return false;
        };

        let mut i = 0;
        let len = vector::length(lhs);
        while (i < len) {
            if (*vector::borrow(lhs, i) != *vector::borrow(rhs, i)) {
                return false;
            };
            i = i + 1;
        };

        true
    }

    fun first_u64_from_bytes(bytes: &vector<u8>): u64 {
        assert!(vector::length(bytes) >= 8, E_RANDOM_BYTES_TOO_SHORT);

        let mut value = 0;
        let mut i = 8;
        while (i > 0) {
            i = i - 1;
            let byte = *vector::borrow(bytes, i);
            value = safe_mul_u64(value, 256, E_RANDOM_INDEX_OVERFLOW);
            value = safe_add_u64(value, u8_to_u64(byte), E_RANDOM_INDEX_OVERFLOW);
        };

        value
    }

    fun u8_to_u64(byte: u8): u64 {
        let mut result = 0;
        let mut temp = byte;
        let mut base = 1;
        while (temp > 0) {
            let bit = temp % 2;
            if (bit == 1) {
                result = result + base;
            };
            temp = temp / 2;
            base = base * 2;
        };
        result
    }

    #[test_only]
    public fun first_u64_from_bytes_for_test(bytes: vector<u8>): u64 {
        first_u64_from_bytes(&bytes)
    }
}
