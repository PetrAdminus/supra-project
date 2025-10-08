module lottery::metadata {
    use std::option;
    use std::signer;
    use aptos_std::table;
    use aptos_std::vector;
    use std::event;

    const E_ALREADY_INIT: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_METADATA_MISSING: u64 = 4;

    public struct LotteryMetadata has copy, drop, store {
        title: vector<u8>,
        description: vector<u8>,
        image_uri: vector<u8>,
        website_uri: vector<u8>,
        rules_uri: vector<u8>,
    }

    struct MetadataRegistry has key {
        admin: address,
        entries: table::Table<u64, LotteryMetadata>,
        lottery_ids: vector::Vector<u64>,
        upsert_events: event::EventHandle<LotteryMetadataUpsertedEvent>,
        remove_events: event::EventHandle<LotteryMetadataRemovedEvent>,
        admin_events: event::EventHandle<MetadataAdminUpdatedEvent>,
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

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<MetadataRegistry>(@lottery)) {
            abort E_ALREADY_INIT;
        };
        move_to(
            caller,
            MetadataRegistry {
                admin: addr,
                entries: table::new(),
                lottery_ids: vector::empty<u64>(),
                upsert_events: event::new_event_handle<LotteryMetadataUpsertedEvent>(caller),
                remove_events: event::new_event_handle<LotteryMetadataRemovedEvent>(caller),
                admin_events: event::new_event_handle<MetadataAdminUpdatedEvent>(caller),
            },
        );
    }

    public fun is_initialized(): bool {
        exists<MetadataRegistry>(@lottery)
    }

    public fun admin(): address acquires MetadataRegistry {
        borrow_state().admin
    }

    public fun has_metadata(lottery_id: u64): bool acquires MetadataRegistry {
        let state = borrow_state();
        table::contains(&state.entries, lottery_id)
    }

    public fun get_metadata(lottery_id: u64): option::Option<LotteryMetadata> acquires MetadataRegistry {
        let state = borrow_state();
        if (!table::contains(&state.entries, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.entries, lottery_id))
        };
    }

    public fun list_lottery_ids(): vector::Vector<u64> acquires MetadataRegistry {
        let state = borrow_state();
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
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, MetadataAdminUpdatedEvent { previous, next: new_admin });
    }

    public entry fun upsert_metadata(
        caller: &signer,
        lottery_id: u64,
        metadata: LotteryMetadata,
    ) acquires MetadataRegistry {
        ensure_admin(caller);
        let metadata_for_event = clone_metadata(&metadata);
        let state = borrow_global_mut<MetadataRegistry>(@lottery);
        let created = if (table::contains(&state.entries, lottery_id)) {
            let entry = table::borrow_mut(&mut state.entries, lottery_id);
            *entry = metadata;
            false
        } else {
            table::add(&mut state.entries, lottery_id, metadata);
            vector::push_back(&mut state.lottery_ids, lottery_id);
            true
        };
        event::emit_event(
            &mut state.upsert_events,
            LotteryMetadataUpsertedEvent { lottery_id, created, metadata: metadata_for_event },
        );
    }

    public entry fun remove_metadata(caller: &signer, lottery_id: u64) acquires MetadataRegistry {
        ensure_admin(caller);
        let state = borrow_global_mut<MetadataRegistry>(@lottery);
        if (!table::contains(&state.entries, lottery_id)) {
            abort E_METADATA_MISSING;
        };
        table::remove(&mut state.entries, lottery_id);
        remove_lottery_id(&mut state.lottery_ids, lottery_id);
        event::emit_event(&mut state.remove_events, LotteryMetadataRemovedEvent { lottery_id });
    }

    fun borrow_state(): &MetadataRegistry acquires MetadataRegistry {
        if (!exists<MetadataRegistry>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<MetadataRegistry>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires MetadataRegistry {
        let addr = signer::address_of(caller);
        if (addr != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun clone_metadata(metadata: &LotteryMetadata): LotteryMetadata {
        LotteryMetadata {
            title: clone_bytes(&metadata.title),
            description: clone_bytes(&metadata.description),
            image_uri: clone_bytes(&metadata.image_uri),
            website_uri: clone_bytes(&metadata.website_uri),
            rules_uri: clone_bytes(&metadata.rules_uri),
        };
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

    fun remove_lottery_id(ids: &mut vector::Vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(ids, i) == lottery_id) {
                vector::swap_remove(ids, i);
                return;
            };
            i = i + 1;
        };
    }
}
