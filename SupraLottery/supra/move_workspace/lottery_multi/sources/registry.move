// sources/registry.move
module lottery_multi::registry {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;
    use supra_framework::event;

    use lottery_multi::history;
    use lottery_multi::roles;
    use lottery_multi::tags;

    const E_ALREADY_INITIALIZED: u64 = 0x1201;
    const E_REGISTRY_MISSING: u64 = 0x1202;
    const E_LOTTERY_EXISTS: u64 = 0x1203;
    const E_STATUS_TRANSITION_NOT_ALLOWED: u64 = 0x1205;
    const E_PRIMARY_TYPE_LOCKED: u64 = 0x1206;
    const E_TAGS_LOCKED: u64 = 0x1207;
    const E_SNAPSHOT_FROZEN: u64 = 0x1208;

    pub const STATUS_DRAFT: u8 = 0;
    pub const STATUS_ACTIVE: u8 = 1;
    pub const STATUS_CLOSING: u8 = 2;
    pub const STATUS_FINALIZED: u8 = 3;

    pub struct Config has copy, drop, store {
        pub event_slug: vector<u8>,
        pub series_code: vector<u8>,
        pub run_id: u64,
        pub config_version: u64,
        pub primary_type: u8,
        pub tags_mask: u64,
    }

    struct Lottery has store {
        id: u64,
        config: Config,
        status: u8,
        snapshot_frozen: bool,
    }

    struct Registry has key {
        lotteries: table::Table<u64, Lottery>,
        ordered_ids: vector<u64>,
        created_events: event::EventHandle<history::LotteryCreatedEvent>,
    }

    public entry fun init_registry(admin: &signer) {
        let registry_addr = signer::address_of(admin);
        assert!(registry_addr == @lottery_multi, E_REGISTRY_MISSING);
        assert!(
            !exists<Registry>(registry_addr),
            E_ALREADY_INITIALIZED,
        );
        let created_events = event::new_event_handle<history::LotteryCreatedEvent>(admin);
        let registry = Registry {
            lotteries: table::new(),
            ordered_ids: vector::empty(),
            created_events,
        };
        move_to(admin, registry);
    }

    public entry fun create_draft_admin(admin: &signer, id: u64, config: Config) acquires Registry {
        tags::validate(config.primary_type, config.tags_mask);
        tags::assert_tag_budget(config.tags_mask);
        let creator = signer::address_of(admin);
        create_lottery_internal(creator, id, config);
    }

    public entry fun create_draft_partner(
        partner: &signer,
        cap: &roles::PartnerCreateCap,
        id: u64,
        config: Config,
    ) acquires Registry {
        tags::validate(config.primary_type, config.tags_mask);
        tags::assert_tag_budget(config.tags_mask);
        roles::ensure_primary_type_allowed(cap, config.primary_type);
        roles::ensure_tags_allowed(cap, config.tags_mask);
        let creator = signer::address_of(partner);
        create_lottery_internal(creator, id, config);
    }

    public entry fun set_primary_type(admin: &signer, id: u64, primary_type: u8) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAFT, E_PRIMARY_TYPE_LOCKED);
        if (lottery.config.primary_type != primary_type) {
            tags::validate(primary_type, lottery.config.tags_mask);
            lottery.config.primary_type = primary_type;
        };
    }

    public entry fun set_tags_mask(admin: &signer, id: u64, tags_mask: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAFT || lottery.status == STATUS_ACTIVE, E_TAGS_LOCKED);
        assert!(!lottery.snapshot_frozen, E_TAGS_LOCKED);
        tags::validate(lottery.config.primary_type, tags_mask);
        tags::assert_tag_budget(tags_mask);
        lottery.config.tags_mask = tags_mask;
    }

    public entry fun advance_status(admin: &signer, id: u64, next_status: u8) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(is_transition_allowed(lottery.status, next_status), E_STATUS_TRANSITION_NOT_ALLOWED);
        if (next_status == STATUS_CLOSING) {
            lottery.snapshot_frozen = true;
        };
        lottery.status = next_status;
    }

    public fun borrow_config(id: u64): &Config acquires Registry {
        let registry = borrow_registry_ref();
        let lottery = table::borrow(&registry.lotteries, id);
        &lottery.config
    }

    public fun get_status(id: u64): u8 acquires Registry {
        let registry = borrow_registry_ref();
        let lottery = table::borrow(&registry.lotteries, id);
        lottery.status
    }

    public fun is_snapshot_frozen(id: u64): bool acquires Registry {
        let registry = borrow_registry_ref();
        let lottery = table::borrow(&registry.lotteries, id);
        lottery.snapshot_frozen
    }

    fun create_lottery_internal(creator: address, id: u64, config: Config) acquires Registry {
        let registry = borrow_registry_mut();
        assert!(!table::contains(&registry.lotteries, id), E_LOTTERY_EXISTS);
        vector::push_back(&mut registry.ordered_ids, id);
        let Config {
            event_slug,
            series_code,
            run_id,
            config_version,
            primary_type,
            tags_mask,
        } = config;
        let event_slug_for_event = event_slug;
        let series_code_for_event = series_code;
        let primary_type_for_event = primary_type;
        let tags_mask_for_event = tags_mask;
        let cfg_for_store = Config {
            event_slug,
            series_code,
            run_id,
            config_version,
            primary_type,
            tags_mask,
        };
        let cfg_bytes = bcs::to_bytes(&cfg_for_store);
        let cfg_hash = hash::sha3_256(cfg_bytes);
        let lottery = Lottery {
            id,
            config: cfg_for_store,
            status: STATUS_DRAFT,
            snapshot_frozen: false,
        };
        table::add(&mut registry.lotteries, id, lottery);
        let event = history::LotteryCreatedEvent {
            event_version: history::EVENT_VERSION_V1,
            event_category: history::EVENT_CATEGORY_REGISTRY,
            id,
            cfg_hash,
            config_version,
            creator,
            event_slug: event_slug_for_event,
            series_code: series_code_for_event,
            run_id,
            primary_type: primary_type_for_event,
            tags_mask: tags_mask_for_event,
        };
        event::emit_event(&mut registry.created_events, event);
    }

    fun borrow_registry_mut(): &mut Registry acquires Registry {
        let registry_addr = @lottery_multi;
        if (!exists<Registry>(registry_addr)) {
            abort E_REGISTRY_MISSING;
        };
        borrow_global_mut<Registry>(registry_addr)
    }

    fun borrow_registry_ref(): &Registry acquires Registry {
        // Registry хранится по адресу владельца (тот же, что и модуль lottery_multi).
        let registry_addr = @lottery_multi;
        if (!exists<Registry>(registry_addr)) {
            abort E_REGISTRY_MISSING;
        };
        borrow_global<Registry>(registry_addr)
    }

    public fun borrow_registry_for_view(): &Registry acquires Registry {
        borrow_registry_ref()
    }

    public fun ordered_ids_view(registry_ref: &Registry): &vector<u64> {
        &registry_ref.ordered_ids
    }

    public fun borrow_config_from_registry(registry_ref: &Registry, id: u64): &Config {
        let lottery = table::borrow(&registry_ref.lotteries, id);
        &lottery.config
    }

    fun is_transition_allowed(current: u8, next: u8): bool {
        if (current == STATUS_DRAFT && next == STATUS_ACTIVE) {
            return true;
        };
        if (current == STATUS_ACTIVE && next == STATUS_CLOSING) {
            return true;
        };
        if (current == STATUS_CLOSING && next == STATUS_FINALIZED) {
            return true;
        };
        false
    }
}

