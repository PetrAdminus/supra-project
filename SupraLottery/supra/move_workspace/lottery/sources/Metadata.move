module lottery::metadata {
    use std::borrow;
    use std::option;
    use std::signer;
    use vrf_hub::table;
    use std::vector;
    use supra_framework::event;

    const E_ALREADY_INIT: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_METADATA_MISSING: u64 = 4;

    struct LotteryMetadata has copy, drop, store {
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    }

    struct MetadataRegistry has key {
        admin: address,
        entries: table::Table<u64, LotteryMetadata>,
        lottery_ids: vector<u64>,
    }

    #[event]
    struct LotteryMetadataUpsertedEvent has drop, store, copy {
        lottery_id: u64,
        created: bool,
        metadata: LotteryMetadata,
    }

    #[event]
    struct LotteryMetadataRemovedEvent has drop, store, copy {
        lottery_id: u64,
    }

    #[event]
    struct MetadataAdminUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    struct MetadataEntry has copy, drop, store {
        lottery_id: u64,
        metadata: LotteryMetadata,
    }

    struct MetadataSnapshot has copy, drop, store {
        admin: address,
        entries: vector<MetadataEntry>,
    }

    #[event]
    struct MetadataSnapshotUpdatedEvent has drop, store, copy {
        previous: option::Option<MetadataSnapshot>,
        current: MetadataSnapshot,
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<MetadataRegistry>(@lottery)) {
            abort E_ALREADY_INIT
        };
        move_to(
            caller,
            MetadataRegistry {
                admin: addr,
                entries: table::new(),
                lottery_ids: vector::empty<u64>(),
            },
        );
        let state = borrow_global<MetadataRegistry>(@lottery);
        let current = build_snapshot(state);
        event::emit(MetadataSnapshotUpdatedEvent {
            previous: option::none<MetadataSnapshot>(),
            current,
        });
    }

    public fun is_initialized(): bool {
        exists<MetadataRegistry>(@lottery)
    }

    public fun admin(): address acquires MetadataRegistry {
        let state = borrow_global<MetadataRegistry>(@lottery);
        state.admin
    }

    public fun has_metadata(lottery_id: u64): bool acquires MetadataRegistry {
        let state = borrow_global<MetadataRegistry>(@lottery);
        table::contains(&state.entries, lottery_id)
    }

    public fun get_metadata(lottery_id: u64): option::Option<LotteryMetadata> acquires MetadataRegistry {
        let state = borrow_global<MetadataRegistry>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.entries, lottery_id))
        }
    }

    public fun list_lottery_ids(): vector<u64> acquires MetadataRegistry {
        let state = borrow_global<MetadataRegistry>(@lottery);
        let len = vector::length(&state.lottery_ids);
        let result = vector::empty<u64>();
        let i = 0;
        while (i < len) {
            vector::push_back(&mut result, *vector::borrow(&state.lottery_ids, i));
            i = i + 1;
        };
        result
    }

    public fun new_metadata(
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    ): LotteryMetadata {
        LotteryMetadata { title, description, image_uri, website_uri, rules_uri }
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires MetadataRegistry {
        ensure_admin(caller);
        let state = borrow_global_mut<MetadataRegistry>(@lottery);
        let previous_snapshot = option::some<MetadataSnapshot>(build_snapshot(borrow::freeze(state)));
        let previous = state.admin;
        state.admin = new_admin;
        event::emit(MetadataAdminUpdatedEvent { previous, next: new_admin });
        let next_snapshot = build_snapshot(borrow::freeze(state));
        event::emit(MetadataSnapshotUpdatedEvent {
            previous: previous_snapshot,
            current: next_snapshot,
        });
    }

    public entry fun upsert_metadata(
        caller: &signer,
        lottery_id: u64,
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    ) acquires MetadataRegistry {
        let metadata = LotteryMetadata { title, description, image_uri, website_uri, rules_uri };
        upsert_metadata_internal(caller, lottery_id, metadata);
    }

    public fun upsert_metadata_struct(
        caller: &signer,
        lottery_id: u64,
        metadata: LotteryMetadata,
    ) acquires MetadataRegistry {
        upsert_metadata_internal(caller, lottery_id, metadata);
    }

    fun upsert_metadata_internal(
        caller: &signer,
        lottery_id: u64,
        metadata: LotteryMetadata,
    ) acquires MetadataRegistry {
        ensure_admin(caller);
        let metadata_for_event = clone_metadata(&metadata);
        let state = borrow_global_mut<MetadataRegistry>(@lottery);
        let previous_snapshot = option::some<MetadataSnapshot>(build_snapshot(borrow::freeze(state)));
        let created = if (table::contains(&state.entries, lottery_id)) {
            let entry = table::borrow_mut(&mut state.entries, lottery_id);
            *entry = metadata;
            false
        } else {
            table::add(&mut state.entries, lottery_id, metadata);
            vector::push_back(&mut state.lottery_ids, lottery_id);
            true
        };
        event::emit(LotteryMetadataUpsertedEvent { lottery_id, created, metadata: metadata_for_event });
        let next_snapshot = build_snapshot(borrow::freeze(state));
        event::emit(MetadataSnapshotUpdatedEvent {
            previous: previous_snapshot,
            current: next_snapshot,
        });
    }

    public entry fun remove_metadata(caller: &signer, lottery_id: u64) acquires MetadataRegistry {
        ensure_admin(caller);
        let state = borrow_global_mut<MetadataRegistry>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            abort E_METADATA_MISSING
        };
        let previous_snapshot = option::some<MetadataSnapshot>(build_snapshot(borrow::freeze(state)));
        table::remove(&mut state.entries, lottery_id);
        remove_lottery_id(&mut state.lottery_ids, lottery_id);
        event::emit(LotteryMetadataRemovedEvent { lottery_id });
        let next_snapshot = build_snapshot(borrow::freeze(state));
        event::emit(MetadataSnapshotUpdatedEvent {
            previous: previous_snapshot,
            current: next_snapshot,
        });
    }

    fun ensure_admin(caller: &signer) acquires MetadataRegistry {
        let addr = signer::address_of(caller);
        if (!exists<MetadataRegistry>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let state = borrow_global<MetadataRegistry>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        }
    }

    #[view]
    public fun get_metadata_snapshot(): MetadataSnapshot acquires MetadataRegistry {
        let state = borrow_global<MetadataRegistry>(@lottery);
        build_snapshot(state)
    }

    #[test_only]
    public fun metadata_snapshot_event_fields_for_test(
        event: &MetadataSnapshotUpdatedEvent
    ): (option::Option<MetadataSnapshot>, MetadataSnapshot) {
        (event.previous, event.current)
    }

    #[test_only]
    public fun metadata_snapshot_admin(snapshot: &MetadataSnapshot): address {
        snapshot.admin
    }

    #[test_only]
    public fun metadata_snapshot_entry_count(snapshot: &MetadataSnapshot): u64 {
        vector::length(&snapshot.entries)
    }

    #[test_only]
    public fun metadata_snapshot_entry_at(snapshot: &MetadataSnapshot, index: u64): MetadataEntry {
        *vector::borrow(&snapshot.entries, index)
    }

    #[test_only]
    public fun metadata_entry_fields_for_test(
        entry: &MetadataEntry
    ): (u64, LotteryMetadata) {
        (entry.lottery_id, clone_metadata(&entry.metadata))
    }

    #[test_only]
    public fun metadata_fields_for_test(
        metadata: &LotteryMetadata
    ): (vector<u8>, vector<u8>, vector<u8>, vector<u8>, vector<u8>) {
        (
            metadata.title,
            metadata.description,
            metadata.image_uri,
            metadata.website_uri,
            metadata.rules_uri,
        )
    }

    fun clone_metadata(metadata: &LotteryMetadata): LotteryMetadata {
        LotteryMetadata {
            title: clone_bytes(&metadata.title),
            description: clone_bytes(&metadata.description),
            image_uri: clone_bytes(&metadata.image_uri),
            website_uri: clone_bytes(&metadata.website_uri),
            rules_uri: clone_bytes(&metadata.rules_uri),
        }
    }

    fun build_snapshot(state: &MetadataRegistry): MetadataSnapshot {
        let entries = vector::empty<MetadataEntry>();
        let len = vector::length(&state.lottery_ids);
        let i = 0;
        while (i < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, i);
            if (table::contains(&state.entries, lottery_id)) {
                let metadata = clone_metadata(table::borrow(&state.entries, lottery_id));
                vector::push_back(
                    &mut entries,
                    MetadataEntry { lottery_id, metadata },
                );
            };
            i = i + 1;
        };
        MetadataSnapshot { admin: state.admin, entries }
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(source);
        let i = 0;
        while (i < len) {
            vector::push_back(&mut buffer, *vector::borrow(source, i));
            i = i + 1;
        };
        buffer
    }

    fun remove_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(ids, i) == lottery_id) {
                vector::swap_remove(ids, i);
                return
            };
            i = i + 1;
        };
    }
}
