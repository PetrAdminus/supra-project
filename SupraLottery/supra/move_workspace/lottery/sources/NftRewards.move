module lottery::nft_rewards {
    friend lottery::nft_rewards_tests;
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use std::event;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_BADGE_NOT_FOUND: u64 = 4;


    struct WinnerBadgeData has copy, drop, store {
        badge_id: u64,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
        minted_by: address,
    }


    struct UserBadges has store {
        badges: table::Table<u64, WinnerBadgeData>,
        badge_ids: vector<u64>,
    }


    struct BadgeAuthority has key {
        admin: address,
        next_badge_id: u64,
        users: table::Table<address, UserBadges>,
        mint_events: event::EventHandle<BadgeMintedEvent>,
        burn_events: event::EventHandle<BadgeBurnedEvent>,
    }

    #[event]
    struct BadgeMintedEvent has drop, store, copy {
        badge_id: u64,
        owner: address,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
    }

    #[event]
    struct BadgeBurnedEvent has drop, store, copy {
        badge_id: u64,
        owner: address,
    }


    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<BadgeAuthority>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            BadgeAuthority {
                admin: addr,
                next_badge_id: 1,
                users: table::new(),
                mint_events: event::new_event_handle<BadgeMintedEvent>(caller),
                burn_events: event::new_event_handle<BadgeBurnedEvent>(caller),
            },
        );
    }


    public fun is_initialized(): bool {
        exists<BadgeAuthority>(@lottery)
    }


    public fun admin(): address acquires BadgeAuthority {
        borrow_authority().admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires BadgeAuthority {
        ensure_admin(caller);
        let state = borrow_authority_mut();
        state.admin = new_admin;
    }


    public entry fun mint_badge(
        caller: &signer,
        owner: address,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
    ) acquires BadgeAuthority {
        ensure_admin(caller);
        let state = borrow_authority_mut();
        let badge_id = state.next_badge_id;
        state.next_badge_id = badge_id + 1;
        let metadata_for_event = clone_bytes(&metadata_uri);

        let collection = borrow_or_create_user(&mut state.users, owner);
        let data = WinnerBadgeData {
            badge_id,
            lottery_id,
            draw_id,
            metadata_uri,
            minted_by: signer::address_of(caller),
        };
        table::add(&mut collection.badges, badge_id, data);
        vector::push_back(&mut collection.badge_ids, badge_id);
        event::emit_event(
            &mut state.mint_events,
            BadgeMintedEvent {
                badge_id,
                owner,
                lottery_id,
                draw_id,
                metadata_uri: metadata_for_event,
            },
        );
    }


    public entry fun burn_badge(caller: &signer, owner: address, badge_id: u64)
    acquires BadgeAuthority {
        let caller_addr = signer::address_of(caller);
        let state = borrow_authority_mut();
        let is_admin = caller_addr == state.admin;
        if (!is_admin && caller_addr != owner) {
            abort E_NOT_AUTHORIZED;
        };
        let removed = remove_badge_internal(&mut state.users, owner, badge_id);
        if (!option::is_some(&removed)) {
            abort E_BADGE_NOT_FOUND;
        };
        event::emit_event(&mut state.burn_events, BadgeBurnedEvent { badge_id, owner });
    }


    public fun has_badge(owner: address, badge_id: u64): bool acquires BadgeAuthority {
        let state = borrow_authority();
        if (!table::contains(&state.users, owner)) {
            return false;
        };
        let collection = table::borrow(&state.users, owner);
        table::contains(&collection.badges, badge_id)
    }


    public fun list_badges(owner: address): vector<u64> acquires BadgeAuthority {
        let state = borrow_authority();
        if (!table::contains(&state.users, owner)) {
            return vector::empty<u64>();
        };
        let collection = table::borrow(&state.users, owner);
        clone_u64_vector(&collection.badge_ids)
    }


    public fun get_badge(owner: address, badge_id: u64): option::Option<WinnerBadgeData> acquires BadgeAuthority {
        let state = borrow_authority();
        if (!table::contains(&state.users, owner)) {
            return option::none<WinnerBadgeData>();
        };
        let collection = table::borrow(&state.users, owner);
        if (!table::contains(&collection.badges, badge_id)) {
            option::none<WinnerBadgeData>()
        } else {
            option::some(*table::borrow(&collection.badges, badge_id))
        };
    }


    fun remove_badge_internal(
        users: &mut table::Table<address, UserBadges>,
        owner: address,
        badge_id: u64,
    ): option::Option<WinnerBadgeData> {
        if (!table::contains(users, owner)) {
            return option::none<WinnerBadgeData>();
        };
        let collection = table::borrow_mut(users, owner);
        if (!table::contains(&collection.badges, badge_id)) {
            return option::none<WinnerBadgeData>();
        };
        let data = table::remove(&mut collection.badges, badge_id);
        remove_badge_id(&mut collection.badge_ids, badge_id);
        option::some(data)
    }


    fun borrow_or_create_user(
        users: &mut table::Table<address, UserBadges>,
        owner: address,
    ): &mut UserBadges {
        if (!table::contains(users, owner)) {
            table::add(users, owner, UserBadges { badges: table::new(), badge_ids: vector::empty<u64>() });
        };
        table::borrow_mut(users, owner)
    }


    fun remove_badge_id(ids: &mut vector<u64>, badge_id: u64) {
        let len = vector::length(ids);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(ids, i) == badge_id) {
                vector::remove(ids, i);
                return;
            };
            i = i + 1;
        };
    }

    fun borrow_authority(): &BadgeAuthority acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<BadgeAuthority>(@lottery)
    }

    fun borrow_authority_mut(): &mut BadgeAuthority acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global_mut<BadgeAuthority>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires BadgeAuthority {
        let addr = signer::address_of(caller);
        let state = borrow_authority();
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let out = vector::empty<u8>();
        let len = vector::length(data);
        let i = 0;
        while (i < len) {
            vector::push_back(&mut out, *vector::borrow(data, i));
            i = i + 1;
        };
        out
    }

    fun clone_u64_vector(data: &vector<u64>): vector<u64> {
        let out = vector::empty<u64>();
        let len = vector::length(data);
        let i = 0;
        while (i < len) {
            vector::push_back(&mut out, *vector::borrow(data, i));
            i = i + 1;
        };
        out
    }
}
