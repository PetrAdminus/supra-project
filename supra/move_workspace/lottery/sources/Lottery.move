// sources/Lottery.move
module lottery::main_v2 {
    use std::string;
    use std::bcs;
    use std::option;
    use 0x1::timestamp;
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::event;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::supra_vrf;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit;
    use 0x1::supra_coin::SupraCoin;

    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const MIN_REQUEST_WINDOW: u64 = 30;

    struct LotteryData has key {
        tickets: vector<address>,
        bank: coin::Coin<SupraCoin>,
        jackpot_amount: u64,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
        max_gas_fee: u64,
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
    struct DrawRequestedEvent has drop, store { nonce: u64 }
    #[event]
    struct FundsWithdrawnEvent has drop, store, copy { admin: address, amount: u64 }

    public entry fun init(sender: &signer) {
        // Only the lottery contract address can initialize
        assert!(signer::address_of(sender) == @lottery, E_NOT_OWNER);
        assert!(!exists<LotteryData>(@lottery), E_ALREADY_INITIALIZED);

        // Store lottery data at the lottery contract address
        move_to(sender, LotteryData {
            tickets: vector::empty(),
            bank: coin::zero<SupraCoin>(),
            jackpot_amount: 0,
            draw_scheduled: false,
            next_ticket_id: 1,
            pending_request: option::none(),
            max_gas_fee: 0,
        });
    }

    public entry fun buy_ticket(user: &signer) acquires LotteryData {
        let user_addr = signer::address_of(user);
        let ticket_price = 10000000; // 0.01 SUPRA

        // Withdraw from user and add to contract pool
        let payment = coin::withdraw<SupraCoin>(user, ticket_price);
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        coin::merge(&mut lottery.bank, payment);
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

        // Transfer prize to winner
        let prize = coin::extract(&mut lottery.bank, lottery.jackpot_amount);
        coin::deposit<SupraCoin>(winner, prize);

        event::emit(WinnerSelected { winner, prize: lottery.jackpot_amount });

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
        lottery.pending_request = option::some(nonce);
        event::emit(DrawRequestedEvent { nonce });
    }

    #[test_only]
    public fun set_pending_request_for_test(nonce: option::Option<u64>) acquires LotteryData {
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        lottery.pending_request = nonce;
    }
    #[test_only]
    public fun ticket_bought_fields(event: &TicketBought): (address, u64, u64) {
        (event.buyer, event.ticket_id, event.amount)
    }

    #[test_only]
    public fun funds_withdrawn_fields(event: &FundsWithdrawnEvent): (address, u64) {
        (event.admin, event.amount)
    }

    #[test_only]
    public fun minimum_balance_updated_fields(event: &MinimumBalanceUpdatedEvent): (u64, u64) {
        (event.max_gas_fee, event.min_balance)
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

        let len = vector::length(&lottery.tickets);
        // Use the verified random number from Supra dVRF
        assert!(vector::length(&verified_nums) > 0, 5);
        let random_num = *vector::borrow(&verified_nums, 0);
        let random_bytes = bcs::to_bytes(&random_num);
        let idx_seed = first_u64_from_bytes(&random_bytes);
        let idx = idx_seed % len;
        let winner = *vector::borrow(&lottery.tickets, idx);

        // Transfer prize to winner
        let prize = coin::extract(&mut lottery.bank, lottery.jackpot_amount);
        coin::deposit<SupraCoin>(winner, prize);

        event::emit(WinnerSelected { winner, prize: lottery.jackpot_amount });

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
        let acc = 0;
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(bytes, i);
            let shift = (i as u8) * 8u8;
            let term = ((byte as u64) << shift);
            acc = acc + term;
            i = i + 1;
        };
        acc
    }
}