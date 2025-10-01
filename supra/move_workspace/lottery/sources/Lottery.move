// sources/Lottery.move
module lottery::main_v2 {
    use std::string;
    use std::bcs;
    use std::option;
    use std::hash;
    use 0x1::timestamp;
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::math64;
    use 0x1::event;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::supra_vrf;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit;
    use lottery::treasury_v1;

    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const MIN_REQUEST_WINDOW: u64 = 30;
    const E_TREASURY_NOT_INITIALIZED: u64 = 12;
    const E_PLAYER_STORE_NOT_REGISTERED: u64 = 13;

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
        rng_request_count: u64,
        rng_response_count: u64,
        last_request_payload_hash: option::Option<vector<u8>>,
    }

    #[event]
    struct TicketBought has store, copy, drop { buyer: address, ticket_id: u64, amount: u64 }
    #[event]
    struct WinnerSelected has store, copy, drop { winner: address, prize: u64 }
    #[event]
    struct SubscriptionConfiguredEvent has drop, store, copy { max_gas_fee: u64, min_balance: u64, initial_deposit: u64 }
    #[event]
    struct MinimumBalanceUpdatedEvent has drop, store, copy { max_gas_fee: u64, min_balance: u64 }
    #[event]
    struct GasConfigUpdatedEvent has drop, store, copy { max_gas_price: u128, max_gas_limit: u128, callback_gas_price: u128, callback_gas_limit: u128 }
    #[event]
    struct DrawRequestedEvent has drop, store, copy { nonce: u64, request_hash: vector<u8>, callback_gas_price: u128, callback_gas_limit: u128 }
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
    }

    fun build_request_envelope(nonce: u64, client_seed: u64, lottery: &LotteryData): VrfRequestEnvelope {
        VrfRequestEnvelope {
            nonce,
            client_seed,
            max_gas_price: lottery.max_gas_price,
            max_gas_limit: lottery.max_gas_limit,
            callback_gas_price: lottery.callback_gas_price,
            callback_gas_limit: lottery.callback_gas_limit,
        }
    }

    fun encode_request_envelope(envelope: &VrfRequestEnvelope): vector<u8> {
        bcs::to_bytes(envelope)
    }

    fun compute_request_payload_hash(nonce: u64, client_seed: u64, lottery: &LotteryData): vector<u8> {
        let envelope = build_request_envelope(nonce, client_seed, lottery);
        let encoded = encode_request_envelope(&envelope);
        hash::sha3_256(encoded)
    }

    public entry fun init(sender: &signer) {
        // Only the lottery contract address can initialize
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);
        assert!(!exists<LotteryData>(@lottery), E_ALREADY_INITIALIZED);
        assert!(treasury_v1::is_initialized(), E_TREASURY_NOT_INITIALIZED);

        // Store lottery data at the lottery contract address
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
            rng_request_count: 0,
            rng_response_count: 0,
            last_request_payload_hash: option::none(),
        });
    }

    public entry fun buy_ticket(user: &signer) acquires LotteryData {
        let user_addr = signer::address_of(user);
        let ticket_price = 10000000; // 0.01 SUPRA

        assert!(treasury_v1::store_registered(user_addr), E_PLAYER_STORE_NOT_REGISTERED);

        // Withdraw from user and add to contract pool
        treasury_v1::deposit_from_user(user, ticket_price);
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.jackpot_amount = lottery.jackpot_amount + ticket_price;

        vector::push_back(&mut lottery.tickets, user_addr);
        let ticket_id = lottery.next_ticket_id;
        lottery.next_ticket_id = lottery.next_ticket_id + 1;

        event::emit(TicketBought { buyer: user_addr, ticket_id, amount: ticket_price });

        // If 5+ tickets and draw not scheduled - mark as ready for draw
        if (vector::length(&lottery.tickets) >= 5 && !lottery.draw_scheduled) {
            lottery.draw_scheduled = true;
        }
    }

    public entry fun create_subscription(sender: &signer, max_gas_fee: u64, initial_deposit: u64) acquires LotteryData {
        // Only lottery admin can create subscription
        assert!(signer::address_of(sender) == @lottery, 1);

        let min_balance = calculate_min_balance(max_gas_fee);
        assert!(initial_deposit >= min_balance, 9);
        deposit::client_setting_minimum_balance(sender, min_balance);
        deposit::deposit_fund(sender, initial_deposit);
        deposit::add_contract_to_whitelist(sender, @lottery);
        event::emit(SubscriptionConfiguredEvent { max_gas_fee, min_balance, initial_deposit });

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.max_gas_fee = max_gas_fee;
    }

    public entry fun set_minimum_balance(sender: &signer, max_gas_fee: u64) acquires LotteryData {
        set_minimum_balance_internal(sender, max_gas_fee, true);
    }

    fun set_minimum_balance_internal(sender: &signer, max_gas_fee: u64, call_native: bool) acquires LotteryData {
        let admin = signer::address_of(sender);
        // Only lottery admin can update gas settings
        assert!(admin == @lottery, 1);

        let min_balance = calculate_min_balance(max_gas_fee);
        if (call_native) {
            deposit::client_setting_minimum_balance(sender, min_balance);
        };

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.max_gas_fee = max_gas_fee;
        event::emit(MinimumBalanceUpdatedEvent { max_gas_fee, min_balance });
    }

    #[test_only]
    public fun set_minimum_balance_for_test(sender: &signer, max_gas_fee: u64) acquires LotteryData {
        set_minimum_balance_internal(sender, max_gas_fee, false);
    }

    public entry fun configure_vrf_gas(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128
    ) acquires LotteryData {
        configure_vrf_gas_internal(sender, max_gas_price, max_gas_limit, callback_gas_price, callback_gas_limit);
    }

    fun configure_vrf_gas_internal(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128
    ) acquires LotteryData {
        let admin = signer::address_of(sender);
        assert!(admin == @lottery, 1);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.max_gas_price = max_gas_price;
        lottery.max_gas_limit = max_gas_limit;
        lottery.callback_gas_price = callback_gas_price;
        lottery.callback_gas_limit = callback_gas_limit;
        event::emit(GasConfigUpdatedEvent { max_gas_price, max_gas_limit, callback_gas_price, callback_gas_limit });
    }

    #[test_only]
    public fun configure_vrf_gas_for_test(
        sender: &signer,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128
    ) acquires LotteryData {
        configure_vrf_gas_internal(sender, max_gas_price, max_gas_limit, callback_gas_price, callback_gas_limit);
    }

    public entry fun withdraw_funds(sender: &signer, amount: u64) acquires LotteryData {
        withdraw_funds_internal(sender, amount, true);
    }

    fun withdraw_funds_internal(sender: &signer, amount: u64, call_native: bool) acquires LotteryData {
        let admin = signer::address_of(sender);
        // Only lottery admin can withdraw funds
        assert!(admin == @lottery, 1);

        let can_withdraw = {
            let lottery = borrow_global<LotteryData>(@lottery);
            option::is_none(&lottery.pending_request)
        };
        assert!(can_withdraw, 10);

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
        assert!(signer::address_of(sender) == @lottery, 1);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, 4); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, 2); // Must have tickets
        assert!(option::is_none(&lottery.pending_request), 6); // Prevent overlapping requests

        // Request random number for draw
        request_draw(lottery, sender);
    }

    public entry fun simple_draw(sender: &signer) acquires LotteryData {
        // Only lottery admin can trigger simple draw
        assert!(signer::address_of(sender) == @lottery, 1);

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, 4); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, 2); // Must have tickets
        assert!(option::is_none(&lottery.pending_request), 6); // Respect pending VRF request

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
        let callback_address = @lottery;
        let callback_module = string::utf8(b"main_v2");
        let callback_function = string::utf8(b"on_random_received");

        let nonce = supra_vrf::rng_request(
            sender,
            callback_address,
            callback_module,
            callback_function,
            1, // number of random values
            0, // client_seed
            1  // confirmations
        );

        let stored_hash = compute_request_payload_hash(nonce, 0, lottery);
        lottery.pending_request = option::some(nonce);
        lottery.last_request_payload_hash = option::some(stored_hash);
        let event_hash = compute_request_payload_hash(nonce, 0, lottery);
        lottery.rng_request_count = lottery.rng_request_count + 1;
        event::emit(DrawRequestedEvent {
            nonce,
            request_hash: event_hash,
            callback_gas_price: lottery.callback_gas_price,
            callback_gas_limit: lottery.callback_gas_limit,
        });
    }

    #[test_only]
    public fun set_pending_request_for_test(nonce: option::Option<u64>) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.pending_request = nonce;
        lottery.last_request_payload_hash = option::none();
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
    public fun minimum_balance_updated_fields(event: &MinimumBalanceUpdatedEvent): (u64, u64) {
        (event.max_gas_fee, event.min_balance)
    }

    #[test_only]
    public fun gas_config_updated_fields(event: &GasConfigUpdatedEvent): (u128, u128, u128, u128) {
        (
            event.max_gas_price,
            event.max_gas_limit,
            event.callback_gas_price,
            event.callback_gas_limit
        )
    }

    #[test_only]
    public fun draw_requested_fields(event: &DrawRequestedEvent): (u64, vector<u8>, u128, u128) {
        (
            event.nonce,
            event.request_hash,
            event.callback_gas_price,
            event.callback_gas_limit
        )
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
    public fun compute_request_payload_hash_for_test(nonce: u64, client_seed: u64): vector<u8> acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        compute_request_payload_hash(nonce, client_seed, lottery)
    }

    #[test_only]
    public fun rng_counters_for_test(): (u64, u64) acquires LotteryData {
        let lottery = borrow_global<LotteryData>(@lottery);
        (lottery.rng_request_count, lottery.rng_response_count)
    }

    public entry fun on_random_received(
        nonce: u64,
        message: vector<u8>,
        signature: vector<u8>,
        caller_address: address,
        rng_count: u8,
        client_seed: u64,
    ) acquires LotteryData {
        // Verify signature and get random values according to Supra dVRF v2 docs
        let verified_nums: vector<u256> = supra_vrf::verify_callback(
            nonce,
            message,
            signature,
            caller_address,
            rng_count,
            client_seed
        );

        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(vector::length(&lottery.tickets) > 0, 2);
        assert!(option::is_some(&lottery.pending_request), 6);
        let expected_nonce = *option::borrow(&lottery.pending_request);
        assert!(expected_nonce == nonce, 7);
        option::extract(&mut lottery.pending_request);
        assert!(option::is_some(&lottery.last_request_payload_hash), 11);
        option::extract(&mut lottery.last_request_payload_hash);

        let len = vector::length(&lottery.tickets);
        // Use the verified random number from Supra dVRF
        assert!(vector::length(&verified_nums) > 0, 5);
        let random_num = *vector::borrow(&verified_nums, 0);
        let random_bytes = bcs::to_bytes(&random_num);
        let idx_seed = first_u64_from_bytes(&random_bytes);
        let idx = idx_seed % len;
        let winner = *vector::borrow(&lottery.tickets, idx);

        // Transfer prize to winner and system vaults according to config
        let prize_amount = treasury_v1::distribute_payout(winner, lottery.jackpot_amount);

        lottery.rng_response_count = lottery.rng_response_count + 1;
        event::emit(WinnerSelected { winner, prize: prize_amount });
        event::emit(DrawHandledEvent { nonce, success: true });
        lottery.last_request_payload_hash = option::none();

        // Reset lottery
        lottery.tickets = vector::empty();
        lottery.jackpot_amount = 0;
        lottery.draw_scheduled = false;
        lottery.next_ticket_id = 1;
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
            let tickets = vector::empty<address>();
            let i = 0;
            let len = vector::length(&lottery.tickets);
            while (i < len) {
                let ticket = *vector::borrow(&lottery.tickets, i);
                vector::push_back(&mut tickets, ticket);
                i = i + 1;
            };
            tickets
        }
    }

    fun calculate_min_balance(max_gas_fee: u64): u64 {
        MIN_REQUEST_WINDOW * max_gas_fee
    }

    fun first_u64_from_bytes(bytes: &vector<u8>): u64 {
        assert!(vector::length(bytes) >= 8, 8);

        let value = 0;
        let multiplier = 1;
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(bytes, i);
            let term = math64::mul_div(u8_to_u64(byte), multiplier, 1);
            value = value + term;
            multiplier = math64::mul_div(multiplier, 256, 1);
            i = i + 1;
        };

        value
    }

    fun u8_to_u64(byte: u8): u64 {
        let result = 0;
        let remaining = byte;
        while (remaining > 0u8) {
            result = result + 1;
            remaining = remaining - 1u8;
        };

        result
    }
}
