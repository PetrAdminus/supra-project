module lottery_rewards_engine::nft {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_BADGE_NOT_FOUND: u64 = 4;

    struct WinnerBadgeData has copy, drop, store {
        badge_id: u64,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
        minted_by: address,
    }

    struct UserBadges has drop, store {
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

    /// Legacy payloads are prepared off-chain (devnet/testnet archives,
    /// dry-run reports or manual constants) and allow restoring state
    /// without calling legacy modules.
    public struct LegacyBadge has drop, store {
        badge_id: u64,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
        minted_by: address,
    }

    public struct LegacyBadgeOwner has drop, store {
        owner: address,
        badges: vector<LegacyBadge>,
    }

    public struct LegacyBadgeAuthority has drop, store {
        admin: address,
        next_badge_id: u64,
        owners: vector<LegacyBadgeOwner>,
    }

    public entry fun init(caller: &signer) acquires BadgeAuthority {
        ensure_admin_signer(caller);
        if (exists<BadgeAuthority>(@lottery)) {
            abort E_ALREADY_INITIALIZED;
        };
        move_to(
            caller,
            BadgeAuthority {
                admin: signer::address_of(caller),
                next_badge_id: 1,
                users: table::new<address, UserBadges>(),
                owners: vector::empty<address>(),
                mint_events: account::new_event_handle<BadgeMintedEvent>(caller),
                burn_events: account::new_event_handle<BadgeBurnedEvent>(caller),
                snapshot_events: account::new_event_handle<NftRewardsSnapshotUpdatedEvent>(caller),
            },
        );
        emit_all_snapshots();
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires BadgeAuthority {
        ensure_admin(caller);
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        authority.admin = new_admin;
        emit_all_snapshots_internal(authority);
    }

    public entry fun mint_badge(
        caller: &signer,
        owner: address,
        lottery_id: u64,
        draw_id: u64,
        metadata_uri: vector<u8>,
    ) acquires BadgeAuthority {
        ensure_admin(caller);
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        let badge_id = authority.next_badge_id;
        authority.next_badge_id = badge_id + 1;
        let metadata_for_event = clone_bytes(&metadata_uri);
        let collection = borrow_or_create_user(&mut authority.users, &mut authority.owners, owner);
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
            &mut authority.mint_events,
            BadgeMintedEvent {
                badge_id,
                owner,
                lottery_id,
                draw_id,
                metadata_uri: metadata_for_event,
            },
        );
        emit_owner_snapshot(authority, owner);
    }

    public entry fun burn_badge(caller: &signer, owner: address, badge_id: u64)
    acquires BadgeAuthority {
        ensure_admin_or_owner(caller, owner);
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        let removed = remove_badge_internal(&mut authority.users, badge_id, owner);
        if (!option::is_some(&removed)) {
            abort E_BADGE_NOT_FOUND;
        };
        event::emit_event(
            &mut authority.burn_events,
            BadgeBurnedEvent { badge_id, owner },
        );
        emit_owner_snapshot(authority, owner);
    }

    public entry fun import_existing_badge_authority(
        caller: &signer,
        payload: LegacyBadgeAuthority,
    ) acquires BadgeAuthority {
        ensure_admin(caller);
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        apply_legacy_authority(authority, payload);
        emit_all_snapshots_internal(authority);
    }

    public entry fun import_existing_badge_authorities(
        caller: &signer,
        mut payloads: vector<LegacyBadgeAuthority>,
    ) acquires BadgeAuthority {
        ensure_admin(caller);
        import_authorities_recursive(&mut payloads);
    }

    #[view]
    public fun ready(): bool acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return false;
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        let owners_len = vector::length(&authority.owners);
        if (authority.admin != @lottery) {
            return false;
        };
        if (!owners_unique(&authority.owners, 0, owners_len)) {
            return false;
        };
        if (table::length(&authority.users) != owners_len) {
            return false;
        };
        let (owners_ok, max_badge_id) = owners_ready(&authority.users, &authority.owners, 0, owners_len, 0);
        if (!owners_ok) {
            return false;
        };
        authority.next_badge_id >= max_badge_id + 1
    }

    #[view]
    public fun is_initialized(): bool {
        exists<BadgeAuthority>(@lottery)
    }

    #[view]
    public fun admin(): option::Option<address> {
        if (!exists<BadgeAuthority>(@lottery)) {
            option::none<address>()
        } else {
            let authority = borrow_global<BadgeAuthority>(@lottery);
            option::some(authority.admin)
        }
    }

    #[view]
    public fun has_badge(owner: address, badge_id: u64): bool acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return false;
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&authority.users, owner)) {
            false
        } else {
            let collection = table::borrow(&authority.users, owner);
            table::contains(&collection.badges, badge_id)
        }
    }

    #[view]
    public fun badge(owner: address, badge_id: u64): option::Option<WinnerBadgeData>
    acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return option::none<WinnerBadgeData>();
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&authority.users, owner)) {
            option::none<WinnerBadgeData>()
        } else {
            let collection = table::borrow(&authority.users, owner);
            if (!table::contains(&collection.badges, badge_id)) {
                option::none<WinnerBadgeData>()
            } else {
                option::some(*table::borrow(&collection.badges, badge_id))
            }
        }
    }

    #[view]
    public fun owner_badge_ids(owner: address): vector<u64> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return vector::empty<u64>();
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&authority.users, owner)) {
            vector::empty<u64>()
        } else {
            let collection = table::borrow(&authority.users, owner);
            clone_u64_vector(&collection.badge_ids)
        }
    }

    #[view]
    public fun owner_addresses(): vector<address> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return vector::empty<address>();
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        clone_address_vector(&authority.owners)
    }

    #[view]
    public fun owner_snapshot(owner: address): option::Option<BadgeOwnerSnapshot>
    acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            return option::none<BadgeOwnerSnapshot>();
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        if (!table::contains(&authority.users, owner)) {
            option::none<BadgeOwnerSnapshot>()
        } else {
            option::some(build_owner_snapshot(&authority, owner))
        }
    }

    #[view]
    public fun snapshot(): option::Option<NftRewardsSnapshot> acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            option::none<NftRewardsSnapshot>()
        } else {
            let authority = borrow_global<BadgeAuthority>(@lottery);
            option::some(build_snapshot(&authority))
        }
    }

    fun emit_all_snapshots() acquires BadgeAuthority {
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        emit_all_snapshots_internal(authority);
    }

    fun emit_all_snapshots_internal(authority: &mut BadgeAuthority) {
        let len = vector::length(&authority.owners);
        emit_snapshots_recursive(authority, 0, len);
    }

    fun emit_snapshots_recursive(authority: &mut BadgeAuthority, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let owner = *vector::borrow(&authority.owners, index);
        emit_owner_snapshot(authority, owner);
        let next_index = index + 1;
        emit_snapshots_recursive(authority, next_index, len);
    }

    fun emit_owner_snapshot(authority: &mut BadgeAuthority, owner: address) {
        if (!table::contains(&authority.users, owner)) {
            return;
        };
        let snapshot = build_owner_snapshot(authority, owner);
        event::emit_event(
            &mut authority.snapshot_events,
            NftRewardsSnapshotUpdatedEvent {
                admin: authority.admin,
                next_badge_id: authority.next_badge_id,
                snapshot,
            },
        );
    }

    fun build_snapshot(authority: &BadgeAuthority): NftRewardsSnapshot {
        let owners = vector::empty<BadgeOwnerSnapshot>();
        let len = vector::length(&authority.owners);
        collect_owner_snapshots(&authority.users, &authority.owners, 0, len, &mut owners);
        NftRewardsSnapshot {
            admin: authority.admin,
            next_badge_id: authority.next_badge_id,
            owners,
        }
    }

    fun build_snapshot_from_mut(authority: &mut BadgeAuthority): NftRewardsSnapshot {
        build_snapshot(authority)
    }

    fun collect_owner_snapshots(
        users: &table::Table<address, UserBadges>,
        owners: &vector<address>,
        index: u64,
        len: u64,
        target: &mut vector<BadgeOwnerSnapshot>,
    ) {
        if (index >= len) {
            return;
        };
        let owner = *vector::borrow(owners, index);
        if (table::contains(users, owner)) {
            let snapshot = build_owner_snapshot_from_table(users, owner);
            vector::push_back(target, snapshot);
        };
        let next_index = index + 1;
        collect_owner_snapshots(users, owners, next_index, len, target);
    }

    fun build_owner_snapshot(authority: &BadgeAuthority, owner: address): BadgeOwnerSnapshot {
        build_owner_snapshot_from_table(&authority.users, owner)
    }

    fun build_owner_snapshot_from_table(
        users: &table::Table<address, UserBadges>,
        owner: address,
    ): BadgeOwnerSnapshot {
        let collection = table::borrow(users, owner);
        let badges = vector::empty<BadgeSnapshot>();
        let len = vector::length(&collection.badge_ids);
        collect_badge_snapshots(&collection.badges, &collection.badge_ids, 0, len, &mut badges);
        BadgeOwnerSnapshot { owner, badges }
    }

    fun collect_badge_snapshots(
        badges: &table::Table<u64, WinnerBadgeData>,
        badge_ids: &vector<u64>,
        index: u64,
        len: u64,
        target: &mut vector<BadgeSnapshot>,
    ) {
        if (index >= len) {
            return;
        };
        let badge_id = *vector::borrow(badge_ids, index);
        if (table::contains(badges, badge_id)) {
            let badge = table::borrow(badges, badge_id);
            vector::push_back(target, to_badge_snapshot(badge));
        };
        let next_index = index + 1;
        collect_badge_snapshots(badges, badge_ids, next_index, len, target);
    }

    fun to_badge_snapshot(badge: &WinnerBadgeData): BadgeSnapshot {
        BadgeSnapshot {
            badge_id: badge.badge_id,
            lottery_id: badge.lottery_id,
            draw_id: badge.draw_id,
            metadata_uri: clone_bytes(&badge.metadata_uri),
            minted_by: badge.minted_by,
        }
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

    fun remove_badge_internal(
        users: &mut table::Table<address, UserBadges>,
        badge_id: u64,
        owner: address,
    ): option::Option<WinnerBadgeData> {
        if (!table::contains(users, owner)) {
            return option::none<WinnerBadgeData>();
        };
        let collection = table::borrow_mut(users, owner);
        if (!table::contains(&collection.badges, badge_id)) {
            option::none<WinnerBadgeData>()
        } else {
            let data = table::remove(&mut collection.badges, badge_id);
            let len = vector::length(&collection.badge_ids);
            remove_badge_id(&mut collection.badge_ids, badge_id, 0, len);
            option::some(data)
        }
    }

    fun remove_badge_id(ids: &mut vector<u64>, badge_id: u64, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let current = *vector::borrow(ids, index);
        if (current == badge_id) {
            vector::remove(ids, index);
        } else {
            let next_index = index + 1;
            remove_badge_id(ids, badge_id, next_index, len);
        }
    }

    fun apply_legacy_authority(authority: &mut BadgeAuthority, payload: LegacyBadgeAuthority) {
        let LegacyBadgeAuthority { admin, next_badge_id, owners } = payload;
        authority.admin = admin;
        authority.next_badge_id = next_badge_id;
        authority.users = table::new<address, UserBadges>();
        authority.owners = vector::empty<address>();
        restore_owners(authority, owners);
    }

    fun restore_owners(authority: &mut BadgeAuthority, mut owners: vector<LegacyBadgeOwner>) {
        restore_owners_recursive(authority, &mut owners);
    }

    fun restore_owners_recursive(
        authority: &mut BadgeAuthority,
        owners: &mut vector<LegacyBadgeOwner>,
    ) {
        if (vector::is_empty(owners)) {
            return;
        };
        let owner_record = vector::pop_back(owners);
        restore_owners_recursive(authority, owners);
        restore_owner(authority, owner_record);
    }

    fun restore_owner(authority: &mut BadgeAuthority, owner_record: LegacyBadgeOwner) {
        let LegacyBadgeOwner { owner, badges } = owner_record;
        let collection = borrow_or_create_user(&mut authority.users, &mut authority.owners, owner);
        let len = vector::length(&badges);
        restore_badges(&mut collection.badges, &mut collection.badge_ids, badges, 0, len);
    }

    fun restore_badges(
        badges: &mut table::Table<u64, WinnerBadgeData>,
        badge_ids: &mut vector<u64>,
        mut legacy: vector<LegacyBadge>,
    ) {
        if (vector::is_empty(&legacy)) {
            return;
        };
        let badge = vector::pop_back(&mut legacy);
        restore_badges(badges, badge_ids, legacy);
        let LegacyBadge {
            badge_id,
            lottery_id,
            draw_id,
            metadata_uri,
            minted_by,
        } = badge;
        table::add(
            badges,
            badge_id,
            WinnerBadgeData {
                badge_id,
                lottery_id,
                draw_id,
                metadata_uri,
                minted_by,
            },
        );
        vector::push_back(badge_ids, badge_id);
    }

    fun import_authorities_recursive(payloads: &mut vector<LegacyBadgeAuthority>) acquires BadgeAuthority {
        if (vector::is_empty(payloads)) {
            return;
        };
        let payload = vector::pop_back(payloads);
        import_authorities_recursive(payloads);
        let authority = borrow_global_mut<BadgeAuthority>(@lottery);
        apply_legacy_authority(authority, payload);
        emit_all_snapshots_internal(authority);
    }

    fun owners_ready(
        users: &table::Table<address, UserBadges>,
        owners: &vector<address>,
        index: u64,
        len: u64,
        current_max: u64,
    ): (bool, u64) {
        if (index == len) {
            return (true, current_max);
        };
        let owner = *vector::borrow(owners, index);
        if (!table::contains(users, owner)) {
            return (false, current_max);
        };
        let collection = table::borrow(users, owner);
        if (table::length(&collection.badges) != vector::length(&collection.badge_ids)) {
            return (false, current_max);
        };
        let (badges_ok, owner_max) = badges_ready(&collection.badge_ids, &collection.badges, 0, vector::length(&collection.badge_ids), current_max);
        if (!badges_ok) {
            return (false, current_max);
        };
        owners_ready(users, owners, index + 1, len, owner_max)
    }

    fun badges_ready(
        badge_ids: &vector<u64>,
        badges: &table::Table<u64, WinnerBadgeData>,
        index: u64,
        len: u64,
        current_max: u64,
    ): (bool, u64) {
        if (index == len) {
            return (true, current_max);
        };
        let badge_id = *vector::borrow(badge_ids, index);
        if (!table::contains(badges, badge_id)) {
            return (false, current_max);
        };
        if (badge_id_seen_later(badge_ids, badge_id, index + 1, len)) {
            return (false, current_max);
        };
        let next_max = if (badge_id > current_max) { badge_id } else { current_max };
        badges_ready(badge_ids, badges, index + 1, len, next_max)
    }

    fun badge_id_seen_later(ids: &vector<u64>, badge_id: u64, index: u64, len: u64): bool {
        if (index == len) {
            return false;
        };
        let current = *vector::borrow(ids, index);
        if (current == badge_id) {
            true
        } else {
            badge_id_seen_later(ids, badge_id, index + 1, len)
        }
    }

    fun owners_unique(owners: &vector<address>, index: u64, len: u64): bool {
        if (index == len) {
            return true;
        };
        let owner = *vector::borrow(owners, index);
        if (owner_seen_later(owners, owner, index + 1, len)) {
            return false;
        };
        owners_unique(owners, index + 1, len)
    }

    fun owner_seen_later(owners: &vector<address>, owner: address, index: u64, len: u64): bool {
        if (index == len) {
            return false;
        };
        let current = *vector::borrow(owners, index);
        if (current == owner) {
            true
        } else {
            owner_seen_later(owners, owner, index + 1, len)
        }
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        clone_bytes_recursive(data, &mut buffer, 0, len);
        buffer
    }

    fun clone_bytes_recursive(data: &vector<u8>, target: &mut vector<u8>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(data, index);
        vector::push_back(target, byte);
        let next_index = index + 1;
        clone_bytes_recursive(data, target, next_index, len);
    }

    fun clone_address_vector(addresses: &vector<address>): vector<address> {
        let result = vector::empty<address>();
        let len = vector::length(addresses);
        clone_address_vector_recursive(addresses, &mut result, 0, len);
        result
    }

    fun clone_address_vector_recursive(
        addresses: &vector<address>,
        target: &mut vector<address>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let addr = *vector::borrow(addresses, index);
        vector::push_back(target, addr);
        let next_index = index + 1;
        clone_address_vector_recursive(addresses, target, next_index, len);
    }

    fun clone_u64_vector(values: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        let len = vector::length(values);
        clone_u64_vector_recursive(values, &mut result, 0, len);
        result
    }

    fun clone_u64_vector_recursive(values: &vector<u64>, target: &mut vector<u64>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let value = *vector::borrow(values, index);
        vector::push_back(target, value);
        let next_index = index + 1;
        clone_u64_vector_recursive(values, target, next_index, len);
    }

    fun ensure_admin_or_owner(caller: &signer, owner: address) acquires BadgeAuthority {
        if (!exists<BadgeAuthority>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let authority = borrow_global<BadgeAuthority>(@lottery);
        let caller_addr = signer::address_of(caller);
        if (caller_addr != authority.admin && caller_addr != owner) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_admin(caller: &signer) acquires BadgeAuthority {
        ensure_initialized();
        let authority = borrow_global<BadgeAuthority>(@lottery);
        if (signer::address_of(caller) != authority.admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_initialized() {
        if (!exists<BadgeAuthority>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_admin_signer(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }
}
