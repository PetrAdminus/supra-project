module lottery_rewards::rewards_nft {
    use std::option;
    use std::signer;
    use std::vector;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
    
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
        owners: vector<address>,
        mint_events: event::EventHandle<BadgeMintedEvent>,
        burn_events: event::EventHandle<BadgeBurnedEvent>,
        snapshot_events: event::EventHandle<NftRewardsSnapshotUpdatedEvent>,
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


    struct BadgeSnapshot has copy, drop, store {
        badge_id: u64,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
        minted_by: address,
    }


    struct BadgeOwnerSnapshot has copy, drop, store {
        owner: address,
        badges: vector<BadgeSnapshot>,
    }


    struct NftRewardsSnapshot has copy, drop, store {
        admin: address,
        next_badge_id: u64,
        owners: vector<BadgeOwnerSnapshot>,
    }

    #[event]
    struct NftRewardsSnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        next_badge_id: u64,
        snapshot: BadgeOwnerSnapshot,
    }


    public entry fun init(caller: &signer) acquires BadgeAuthority {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<BadgeAuthority>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            BadgeAuthority {
                admin: addr,
                next_badge_id: 1,
                users: table::new(),
                owners: vector::empty<address>(),
                mint_events: account::new_event_handle<BadgeMintedEvent>(caller),
                burn_events: account::new_event_handle<BadgeBurnedEvent>(caller),
                snapshot_events: account::new_event_handle<NftRewardsSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<BadgeAuthority>(@lottery);
        emit_all_snapshots(state);
    }


    #[view]
    public fun is_initialized(): bool {
        exists<BadgeAuthority>(@lottery)
    }


    #[view]
    public fun admin(): address acquires BadgeAuthority {
        let state = borrow_global<BadgeAuthority>(@lottery);
        state.admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires BadgeAuthority {
        ensure_admin(caller);
        let state = borrow_global_mut<BadgeAuthority>(@lottery);
        state.admin = new_admin;
        emit_all_snapshots(state);
    }


    public entry fun mint_badge(
        caller: &signer,
        owner: address,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
    ) acquires BadgeAuthority {
        ensure_admin(caller);
        let state = borrow_global_mut<BadgeAuthority>(@lottery);
        let badge_id = state.next_badge_id;
        state.next_badge_id = badge_id + 1;
        let metadata_for_event = clone_bytes(&metadata_uri);

        let collection = borrow_or_create_user(&mut state.users, &mut state.owners, owner);
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
        emit_owner_snapshot(state, owner);
    }


    public entry fun burn_badge(caller: &signer, owner: address, badge_id: u64)
    acquires BadgeAuthority {
        let caller_addr = signer::address_of(caller);
        let state = borrow_global_mut<BadgeAuthority>(@lottery);
        let is_admin = caller_addr == state.admin;
        if (!is_admin && caller_addr != owner) {
            abort E_NOT_AUTHORIZED
        };
        let removed = remove_badge_internal(&mut state.users, owner, badge_id);
        if (!option::is_some(&removed)) {
            abort E_BADGE_NOT_FOUND
        };
        event::emit_event(&mut state.burn_events, BadgeBurnedEvent { badge_id, owner });
        emit_owner_snapshot(state, owner);
    }


    #[view]
    public fun has_badge(owner: address, badge_id: u64): bool acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return false
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&state.users, owner)) {
            return false
        };
        let collection = table::borrow(&state.users, owner);
        table::contains(&collection.badges, badge_id)
    }


    #[view]
    public fun list_badges(owner: address): vector<u64> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&state.users, owner)) {
            return vector::empty<u64>()
        };
        let collection = table::borrow(&state.users, owner);
        clone_u64_vector(&collection.badge_ids)
    }


    #[view]
    public fun get_badge(owner: address, badge_id: u64): option::Option<WinnerBadgeData> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return option::none<WinnerBadgeData>()
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&state.users, owner)) {
            return option::none<WinnerBadgeData>()
        };
        let collection = table::borrow(&state.users, owner);
        if (!table::contains(&collection.badges, badge_id)) {
            option::none<WinnerBadgeData>()
        } else {
            option::some(*table::borrow(&collection.badges, badge_id))
        }
    }


    #[view]
    public fun list_owner_addresses(): vector<address> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return vector::empty<address>()
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        clone_address_vector(&state.owners)
    }


    #[view]
    public fun get_owner_snapshot(owner: address): option::Option<BadgeOwnerSnapshot>
    acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return option::none<BadgeOwnerSnapshot>()
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&state.users, owner)) {
            return option::none<BadgeOwnerSnapshot>()
        };
        option::some(build_owner_snapshot(state, owner))
    }


    #[view]
    public fun get_snapshot(): option::Option<NftRewardsSnapshot> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return option::none<NftRewardsSnapshot>()
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        option::some(build_snapshot(state))
    }


    #[test_only]
    public fun badge_fields_for_test(
        badge: &WinnerBadgeData
    ): (u64, u64, vector<u8>, address) {
        (badge.lottery_id, badge.draw_id, badge.metadata_uri, badge.minted_by)
    }


    #[test_only]
    public fun badge_snapshot_fields_for_test(
        snapshot: &BadgeSnapshot
    ): (u64, u64, u64, vector<u8>, address) {
        (
            snapshot.badge_id,
            snapshot.lottery_id,
            snapshot.draw_id,
            snapshot.metadata_uri,
            snapshot.minted_by,
        )
    }


    #[test_only]
    public fun owner_snapshot_fields_for_test(
        snapshot: &BadgeOwnerSnapshot
    ): (address, vector<BadgeSnapshot>) {
        (snapshot.owner, clone_badge_snapshot_vector(&snapshot.badges))
    }


    #[test_only]
    public fun rewards_snapshot_fields_for_test(
        snapshot: &NftRewardsSnapshot
    ): (address, u64, vector<BadgeOwnerSnapshot>) {
        (
            snapshot.admin,
            snapshot.next_badge_id,
            clone_owner_snapshot_vector(&snapshot.owners),
        )
    }


    #[test_only]
    public fun snapshot_event_fields_for_test(
        event: &NftRewardsSnapshotUpdatedEvent
    ): (address, u64, BadgeOwnerSnapshot) {
        (
            event.admin,
            event.next_badge_id,
            copy_owner_snapshot(&event.snapshot),
        )
    }


    fun remove_badge_internal(
        users: &mut table::Table<address, UserBadges>,
        owner: address,
        badge_id: u64,
    ): option::Option<WinnerBadgeData> {
        if (!table::contains(users, owner)) {
            return option::none<WinnerBadgeData>()
        };
        let collection = table::borrow_mut(users, owner);
        if (!table::contains(&collection.badges, badge_id)) {
            return option::none<WinnerBadgeData>()
        };
        let data = table::remove(&mut collection.badges, badge_id);
        remove_badge_id(&mut collection.badge_ids, badge_id);
        option::some(data)
    }


    fun borrow_or_create_user(
        users: &mut table::Table<address, UserBadges>,
        owners: &mut vector<address>,
        owner: address,
    ): &mut UserBadges {
        if (!table::contains(users, owner)) {
            table::add(users, owner, UserBadges { badges: table::new(), badge_ids: vector::empty<u64>() });
            vector::push_back(owners, owner);
        };
        table::borrow_mut(users, owner)
    }


    fun remove_badge_id(ids: &mut vector<u64>, badge_id: u64) {
        let len = vector::length(ids);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(ids, i) == badge_id) {
                vector::remove(ids, i);
                return
            } else {
                i = i + 1;
            }
        };
    }

    fun ensure_admin(caller: &signer) acquires BadgeAuthority {
        let addr = signer::address_of(caller);
        if (!exists<BadgeAuthority>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<BadgeAuthority>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }


    fun build_snapshot_from_mut(state: &mut BadgeAuthority): NftRewardsSnapshot {
        build_snapshot_internal(state.admin, state.next_badge_id, &state.owners, &state.users)
    }

    fun build_snapshot(state: &BadgeAuthority): NftRewardsSnapshot {
        build_snapshot_internal(state.admin, state.next_badge_id, &state.owners, &state.users)
    }

    fun build_snapshot_internal(
        admin: address,
        next_badge_id: u64,
        owners_list: &vector<address>,
        users: &table::Table<address, UserBadges>,
    ): NftRewardsSnapshot {
        let owners = vector::empty<BadgeOwnerSnapshot>();
        let len = vector::length(owners_list);
        let idx = 0;
        while (idx < len) {
            let owner = *vector::borrow(owners_list, idx);
            if (table::contains(users, owner)) {
                vector::push_back(
                    &mut owners,
                    build_owner_snapshot_from_table(users, owner),
                );
            };
            idx = idx + 1;
        };
        NftRewardsSnapshot { admin, next_badge_id, owners }
    }


    fun build_owner_snapshot_from_mut(
        state: &mut BadgeAuthority,
        owner: address,
    ): BadgeOwnerSnapshot {
        build_owner_snapshot_from_table(&state.users, owner)
    }

    fun build_owner_snapshot(state: &BadgeAuthority, owner: address): BadgeOwnerSnapshot {
        build_owner_snapshot_from_table(&state.users, owner)
    }

    fun build_owner_snapshot_from_table(
        users: &table::Table<address, UserBadges>,
        owner: address,
    ): BadgeOwnerSnapshot {
        if (!table::contains(users, owner)) {
            return BadgeOwnerSnapshot { owner, badges: vector::empty<BadgeSnapshot>() }
        };
        let collection = table::borrow(users, owner);
        let len = vector::length(&collection.badge_ids);
        let idx = 0;
        let badges = vector::empty<BadgeSnapshot>();
        while (idx < len) {
            let badge_id = *vector::borrow(&collection.badge_ids, idx);
            if (table::contains(&collection.badges, badge_id)) {
                let data = table::borrow(&collection.badges, badge_id);
                vector::push_back(&mut badges, build_badge_snapshot(badge_id, data));
            };
            idx = idx + 1;
        };
        BadgeOwnerSnapshot { owner, badges }
    }


    fun build_badge_snapshot(badge_id: u64, data: &WinnerBadgeData): BadgeSnapshot {
        BadgeSnapshot {
            badge_id,
            lottery_id: data.lottery_id,
            draw_id: data.draw_id,
            metadata_uri: clone_bytes(&data.metadata_uri),
            minted_by: data.minted_by,
        }
    }


    fun emit_owner_snapshot(state: &mut BadgeAuthority, owner: address) {
        let snapshot = build_owner_snapshot_from_mut(state, owner);
        event::emit_event(
            &mut state.snapshot_events,
            NftRewardsSnapshotUpdatedEvent {
                admin: state.admin,
                next_badge_id: state.next_badge_id,
                snapshot,
            },
        );
    }


    fun emit_all_snapshots(state: &mut BadgeAuthority) {
        let len = vector::length(&state.owners);
        let idx = 0;
        while (idx < len) {
            let owner = *vector::borrow(&state.owners, idx);
            if (table::contains(&state.users, owner)) {
                emit_owner_snapshot(state, owner);
            };
            idx = idx + 1;
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


    fun clone_badge_snapshot_vector(values: &vector<BadgeSnapshot>): vector<BadgeSnapshot> {
        let out = vector::empty<BadgeSnapshot>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }


    fun clone_owner_snapshot_vector(values: &vector<BadgeOwnerSnapshot>): vector<BadgeOwnerSnapshot> {
        let out = vector::empty<BadgeOwnerSnapshot>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, copy_owner_snapshot(vector::borrow(values, idx)));
            idx = idx + 1;
        };
        out
    }


    fun copy_owner_snapshot(snapshot: &BadgeOwnerSnapshot): BadgeOwnerSnapshot {
        BadgeOwnerSnapshot { owner: snapshot.owner, badges: clone_badge_snapshot_vector(&snapshot.badges) }
    }


    fun clone_address_vector(values: &vector<address>): vector<address> {
        let out = vector::empty<address>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }
}


