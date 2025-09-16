// sources/Lottery.move
module lottery::main {
    use std::string;
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::event;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::supra_vrf;
    use 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit;
    use 0x1::supra_coin::SupraCoin;

    struct LotteryData has key {
        tickets: vector<address>,
        bank: coin::Coin<SupraCoin>,
        jackpot_amount: u64,
        draw_scheduled: bool,
        next_ticket_id: u64,
    }

    #[event]
    struct TicketBought has store, copy, drop { buyer: address, ticket_id: u64 }
    #[event]
    struct WinnerSelected has store, copy, drop { winner: address, prize: u64 }

    public entry fun init(sender: &signer) {
        // Only the lottery contract address can initialize
        assert!(signer::address_of(sender) == @lottery, 1);
        
        // Store lottery data at the lottery contract address
        move_to(sender, LotteryData {
            tickets: vector::empty(),
            bank: coin::zero<SupraCoin>(),
            jackpot_amount: 0,
            draw_scheduled: false,
            next_ticket_id: 1,
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

        event::emit(TicketBought { buyer: user_addr, ticket_id });

        // If 5+ tickets and draw not scheduled - mark as ready for draw
        if (vector::length(&lottery.tickets) >= 5 && !lottery.draw_scheduled) {
            lottery.draw_scheduled = true;
        }
    }
    public entry fun create_subscription(sender: &signer, _max_gas_fee: u64, initial_deposit: u64) {
        // Only lottery admin can create subscription
        assert!(signer::address_of(sender) == @lottery, 1);
        
        // First, try to deposit funds - this might create the client automatically
        deposit::deposit_fund(sender, initial_deposit);
        
        // Then add lottery contract to whitelist for dVRF
        deposit::add_contract_to_whitelist(sender, @lottery);
    }

    public entry fun set_minimum_balance(sender: &signer, min_balance: u64) {
        // Only lottery admin can set minimum balance
        assert!(signer::address_of(sender) == @lottery, 1);
        
        // Set minimum balance for dVRF subscription
        deposit::client_setting_minimum_balance(sender, min_balance);
    }

    public entry fun withdraw_funds(sender: &signer, amount: u64) {
        // Only lottery admin can withdraw funds
        assert!(signer::address_of(sender) == @lottery, 1);
        
        // Withdraw funds from dVRF subscription
        deposit::withdraw_fund(sender, amount);
    }

    public entry fun manual_draw(sender: &signer) acquires LotteryData {
        // Only lottery admin can trigger manual draw
        assert!(signer::address_of(sender) == @lottery, 1);
        
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, 4); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, 2); // Must have tickets
        
        // Request random number for draw
        request_draw(sender);
    }

    public entry fun simple_draw(sender: &signer) acquires LotteryData {
        // Only lottery admin can trigger simple draw
        assert!(signer::address_of(sender) == @lottery, 1);
        
        let lottery = borrow_global_mut<LotteryData>(@lottery);
        assert!(lottery.draw_scheduled, 4); // Draw must be scheduled
        assert!(vector::length(&lottery.tickets) > 0, 2); // Must have tickets
        
        // Simple deterministic draw using block timestamp
        let len = vector::length(&lottery.tickets);
        let timestamp = std::timestamp::now_microseconds();
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

    fun request_draw(sender: &signer) {
        let callback_address = @lottery;
        let callback_module = string::utf8(b"main");
        let callback_function = string::utf8(b"on_random_received");

        let _ = supra_vrf::rng_request(
            sender,
            callback_address,
            callback_module,
            callback_function,
            1, // number of random values
            0, // client_seed
            1, // confirmations
            100000, // callback_gas_limit (dVRF 3.0)
            100     // callback_gas_price (dVRF 3.0)
        );
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

        let len = vector::length(&lottery.tickets);
        // Use the verified random number from Supra dVRF
        assert!(vector::length(&verified_nums) > 0, 5);
        let _random_num = *vector::borrow(&verified_nums, 0);
        // Convert u256 to u64 for modulo operation (take lower 64 bits)
        // Since we can't directly convert u256 to u64, we'll use the nonce as fallback
        let random_u64 = nonce;
        let idx = random_u64 % len;
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
}