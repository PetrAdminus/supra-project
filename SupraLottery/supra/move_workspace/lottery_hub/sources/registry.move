module lottery_hub::registry {
    use std::signer;
    use std::vector;
    use std::option;

    // Error codes (temporary)
    const E_ALREADY_INIT: u64 = 1;
    const E_NOT_ADMIN: u64 = 2;
    const E_INVALID_CONFIG: u64 = 3;

    //
    // Base Lottery object
    // No Cyrillic, ASCII only.
    //
    struct Lottery has copy, drop, store {
        id: u64,
        ticket_price: u64,
        min_players: u64,
        max_players: u64,
        sales_start_ts: u64,
        sales_end_ts: u64,
    }

    //
    // Registry for one admin (hub owner)
    //
    struct Registry has key {
        admin: address,
        next_id: u64,
        lotteries: vector<Lottery>,
    }

    //
    // One-time init for specific admin address
    //
    public entry fun init(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        if (exists<Registry>(admin_addr)) {
            abort E_ALREADY_INIT;
        };

        move_to(
            admin,
            Registry {
                admin: admin_addr,
                next_id: 1,
                lotteries: vector::empty<Lottery>(),
            },
        );
    }

    //
    // Internal check for owner
    //
    fun assert_admin(reg: &Registry, signer_addr: address) {
        if (reg.admin != signer_addr) {
            abort E_NOT_ADMIN;
        };
    }

    //
    // Config validator
    //
    fun is_valid_config(
        ticket_price: u64,
        min_players: u64,
        max_players: u64,
        sales_start_ts: u64,
        sales_end_ts: u64,
    ): bool {
        if (ticket_price == 0) {
            return false;
        };

        if (min_players == 0) {
            return false;
        };

        if (max_players < min_players) {
            return false;
        };

        if (!(sales_start_ts < sales_end_ts)) {
            return false;
        };

        true
    }

    //
    // Create new base lottery
    //
    public entry fun create_lottery(
        admin: &signer,
        ticket_price: u64,
        min_players: u64,
        max_players: u64,
        sales_start_ts: u64,
        sales_end_ts: u64,
    ) acquires Registry {
        let admin_addr = signer::address_of(admin);
        let reg = borrow_global_mut<Registry>(admin_addr);
        assert_admin(reg, admin_addr);

        if (!is_valid_config(
            ticket_price,
            min_players,
            max_players,
            sales_start_ts,
            sales_end_ts,
        )) {
            abort E_INVALID_CONFIG;
        };

        let id = reg.next_id;
        reg.next_id = id + 1;

        let lottery = Lottery {
            id: id,
            ticket_price: ticket_price,
            min_players: min_players,
            max_players: max_players,
            sales_start_ts: sales_start_ts,
            sales_end_ts: sales_end_ts,
        };

        vector::push_back(&mut reg.lotteries, lottery);
    }

    //
    // View: get lottery by id
    //
    public fun get_lottery(
        hub_owner: address,
        id: u64,
    ): option::Option<Lottery> acquires Registry {
        let reg = borrow_global<Registry>(hub_owner);

        let len = vector::length(&reg.lotteries);
        let i = 0;
        while (i < len) {
            let l_ref = vector::borrow(&reg.lotteries, i);
            if ((*l_ref).id == id) {
                let copy = *l_ref;
                return option::some<Lottery>(copy);
            };
            i = i + 1;
        };

        option::none<Lottery>()
    }
}
