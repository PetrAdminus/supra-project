module lottery_utils::metadata {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;
    const E_METADATA_MISSING: u64 = 4;

    struct LotteryMetadata has copy, drop, store {
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    }

    struct LegacyMetadataImport has copy, drop, store {
        lottery_id: u64,
        metadata: LotteryMetadata,
    }

    struct MetadataRegistry has key {
        admin: address,
        entries: table::Table<u64, LotteryMetadata>,
        lottery_ids: vector<u64>,
        upsert_events: event::EventHandle<LotteryMetadataUpsertedEvent>,
        remove_events: event::EventHandle<LotteryMetadataRemovedEvent>,
        admin_events: event::EventHandle<MetadataAdminUpdatedEvent>,
        snapshot_events: event::EventHandle<MetadataSnapshotUpdatedEvent>,
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

    public entry fun init(caller: &signer) acquires MetadataRegistry {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<MetadataRegistry>(@lottery), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            MetadataRegistry {
                admin: caller_address,
                entries: table::new<u64, LotteryMetadata>(),
                lottery_ids: vector::empty<u64>(),
                upsert_events: account::new_event_handle<LotteryMetadataUpsertedEvent>(caller),
                remove_events: account::new_event_handle<LotteryMetadataRemovedEvent>(caller),
                admin_events: account::new_event_handle<MetadataAdminUpdatedEvent>(caller),
                snapshot_events: account::new_event_handle<MetadataSnapshotUpdatedEvent>(caller),
            },
        );

        emit_initial_snapshot();
    }

    public fun is_initialized(): bool {
        exists<MetadataRegistry>(@lottery)
    }

    public fun admin(): address acquires MetadataRegistry {
        let registry = borrow_global<MetadataRegistry>(@lottery);
        registry.admin
    }

    public fun has_metadata(lottery_id: u64): bool acquires MetadataRegistry {
        let registry = borrow_global<MetadataRegistry>(@lottery);
        table::contains(&registry.entries, lottery_id)
    }

    public fun get_metadata(lottery_id: u64): option::Option<LotteryMetadata>
    acquires MetadataRegistry {
        let registry = borrow_global<MetadataRegistry>(@lottery);
        if (!table::contains(&registry.entries, lottery_id)) {
            option::none<LotteryMetadata>()
        } else {
            option::some(*table::borrow(&registry.entries, lottery_id))
        }
    }

    public fun list_lottery_ids(): vector<u64> acquires MetadataRegistry {
        let registry = borrow_global<MetadataRegistry>(@lottery);
        clone_u64_vector(&registry.lottery_ids)
    }

    public fun new_metadata(
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    ): LotteryMetadata {
        LotteryMetadata {
            title,
            description,
            image_uri,
            website_uri,
            rules_uri,
        }
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires MetadataRegistry {
        ensure_admin(caller);
        let registry = borrow_global_mut<MetadataRegistry>(@lottery);
        let previous_snapshot = option::some(build_snapshot_from_mut(registry));
        let previous = registry.admin;
        registry.admin = new_admin;
        event::emit_event(
            &mut registry.admin_events,
            MetadataAdminUpdatedEvent {
                previous,
                next: new_admin,
            },
        );
        emit_snapshot_with_previous(registry, previous_snapshot);
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
        let metadata = LotteryMetadata {
            title,
            description,
            image_uri,
            website_uri,
            rules_uri,
        };
        upsert_metadata_struct(caller, lottery_id, metadata);
    }

    public entry fun upsert_metadata_struct(
        caller: &signer,
        lottery_id: u64,
        metadata: LotteryMetadata,
    ) acquires MetadataRegistry {
        ensure_admin(caller);
        let registry = borrow_global_mut<MetadataRegistry>(@lottery);
        let previous_snapshot = option::some(build_snapshot_from_mut(registry));
        let metadata_for_event = clone_metadata(&metadata);
        let created = if (table::contains(&registry.entries, lottery_id)) {
            let entry = table::borrow_mut(&mut registry.entries, lottery_id);
            *entry = metadata;
            false
        } else {
            table::add(&mut registry.entries, lottery_id, metadata);
            vector::push_back(&mut registry.lottery_ids, lottery_id);
            true
        };
        event::emit_event(
            &mut registry.upsert_events,
            LotteryMetadataUpsertedEvent {
                lottery_id,
                created,
                metadata: metadata_for_event,
            },
        );
        emit_snapshot_with_previous(registry, previous_snapshot);
    }

    public entry fun import_existing_metadata(
        caller: &signer,
        entry: LegacyMetadataImport,
    ) acquires MetadataRegistry {
        ensure_admin(caller);
        upsert_metadata_struct(caller, entry.lottery_id, entry.metadata);
    }

    public entry fun import_existing_metadata_batch(
        caller: &signer,
        entries: vector<LegacyMetadataImport>,
    ) acquires MetadataRegistry {
        ensure_admin(caller);
        import_existing_batch_recursive(caller, &entries, vector::length(&entries));
    }

    fun import_existing_batch_recursive(
        caller: &signer,
        entries: &vector<LegacyMetadataImport>,
        remaining: u64,
    ) acquires MetadataRegistry {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        import_existing_batch_recursive(caller, entries, next_remaining);
        let entry = *vector::borrow(entries, next_remaining);
        upsert_metadata_struct(caller, entry.lottery_id, entry.metadata);
    }

    public entry fun remove_metadata(caller: &signer, lottery_id: u64) acquires MetadataRegistry {
        ensure_admin(caller);
        let registry = borrow_global_mut<MetadataRegistry>(@lottery);
        if (!table::contains(&registry.entries, lottery_id)) {
            abort E_METADATA_MISSING;
        };
        let previous_snapshot = option::some(build_snapshot_from_mut(registry));
        table::remove(&mut registry.entries, lottery_id);
        remove_lottery_id(&mut registry.lottery_ids, lottery_id);
        event::emit_event(
            &mut registry.remove_events,
            LotteryMetadataRemovedEvent { lottery_id },
        );
        emit_snapshot_with_previous(registry, previous_snapshot);
    }

    #[view]
    public fun get_metadata_snapshot(): MetadataSnapshot acquires MetadataRegistry {
        let registry = borrow_global<MetadataRegistry>(@lottery);
        build_snapshot(registry)
    }

    #[test_only]
    public fun metadata_snapshot_event_fields_for_test(
        event: &MetadataSnapshotUpdatedEvent,
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
        entry: &MetadataEntry,
    ): (u64, LotteryMetadata) {
        (entry.lottery_id, clone_metadata(&entry.metadata))
    }

    #[test_only]
    public fun metadata_fields_for_test(
        metadata: &LotteryMetadata,
    ): (vector<u8>, vector<u8>, vector<u8>, vector<u8>, vector<u8>) {
        (
            metadata.title,
            metadata.description,
            metadata.image_uri,
            metadata.website_uri,
            metadata.rules_uri,
        )
    }

    fun ensure_admin(caller: &signer) acquires MetadataRegistry {
        if (!exists<MetadataRegistry>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        let registry = borrow_global<MetadataRegistry>(@lottery);
        let addr = signer::address_of(caller);
        if (addr != registry.admin) {
            abort E_UNAUTHORIZED;
        };
    }

    fun emit_initial_snapshot() acquires MetadataRegistry {
        let registry = borrow_global_mut<MetadataRegistry>(@lottery);
        let snapshot = build_snapshot_from_mut(registry);
        event::emit_event(
            &mut registry.snapshot_events,
            MetadataSnapshotUpdatedEvent {
                previous: option::none<MetadataSnapshot>(),
                current: snapshot,
            },
        );
    }

    fun emit_snapshot_with_previous(
        registry: &mut MetadataRegistry,
        previous: option::Option<MetadataSnapshot>,
    ) {
        let snapshot = build_snapshot_from_mut(registry);
        event::emit_event(
            &mut registry.snapshot_events,
            MetadataSnapshotUpdatedEvent {
                previous,
                current: snapshot,
            },
        );
    }

    fun build_snapshot_from_mut(registry: &mut MetadataRegistry): MetadataSnapshot {
        build_snapshot_internal(registry.admin, &registry.lottery_ids, &registry.entries)
    }

    fun build_snapshot(registry: &MetadataRegistry): MetadataSnapshot {
        build_snapshot_internal(registry.admin, &registry.lottery_ids, &registry.entries)
    }

    fun build_snapshot_internal(
        admin: address,
        lottery_ids: &vector<u64>,
        entries_table: &table::Table<u64, LotteryMetadata>,
    ): MetadataSnapshot {
        let entries = vector::empty<MetadataEntry>();
        let len = vector::length(lottery_ids);
        append_metadata_entries(&mut entries, lottery_ids, entries_table, 0, len);
        MetadataSnapshot { admin, entries }
    }

    fun append_metadata_entries(
        entries: &mut vector<MetadataEntry>,
        lottery_ids: &vector<u64>,
        entries_table: &table::Table<u64, LotteryMetadata>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let lottery_id = *vector::borrow(lottery_ids, index);
        if (table::contains(entries_table, lottery_id)) {
            let metadata = clone_metadata(table::borrow(entries_table, lottery_id));
            vector::push_back(
                entries,
                MetadataEntry { lottery_id, metadata },
            );
        };
        append_metadata_entries(entries, lottery_ids, entries_table, index + 1, len);
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

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(source);
        append_bytes(source, &mut buffer, 0, len);
        buffer
    }

    fun append_bytes(
        source: &vector<u8>,
        dest: &mut vector<u8>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        vector::push_back(dest, *vector::borrow(source, index));
        append_bytes(source, dest, index + 1, len);
    }

    fun clone_u64_vector(source: &vector<u64>): vector<u64> {
        let buffer = vector::empty<u64>();
        let len = vector::length(source);
        append_u64(source, &mut buffer, 0, len);
        buffer
    }

    fun append_u64(
        source: &vector<u64>,
        dest: &mut vector<u64>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        vector::push_back(dest, *vector::borrow(source, index));
        append_u64(source, dest, index + 1, len);
    }

    fun remove_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        remove_lottery_id_internal(ids, lottery_id, 0, len);
    }

    fun remove_lottery_id_internal(
        ids: &mut vector<u64>,
        lottery_id: u64,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            vector::swap_remove(ids, index);
            return;
        };
        remove_lottery_id_internal(ids, lottery_id, index + 1, len);
    }
}
