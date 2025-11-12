// sources/registry.move
module lottery_multi::registry {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;
    use supra_framework::event;

    use lottery_multi::history;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::roles;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    pub const STATUS_DRAFT: u8 = types::STATUS_DRAFT;
    pub const STATUS_ACTIVE: u8 = types::STATUS_ACTIVE;
    pub const STATUS_CLOSING: u8 = types::STATUS_CLOSING;
    pub const STATUS_DRAW_REQUESTED: u8 = types::STATUS_DRAW_REQUESTED;
    pub const STATUS_DRAWN: u8 = types::STATUS_DRAWN;
    pub const STATUS_PAYOUT: u8 = types::STATUS_PAYOUT;
    pub const STATUS_FINALIZED: u8 = types::STATUS_FINALIZED;
    pub const STATUS_CANCELED: u8 = types::STATUS_CANCELED;

    pub const CANCEL_REASON_VRF_FAILURE: u8 = 1;
    pub const CANCEL_REASON_COMPLIANCE: u8 = 2;
    pub const CANCEL_REASON_OPERATIONS: u8 = 3;

    pub struct Config has copy, drop, store {
        pub event_slug: vector<u8>,
        pub series_code: vector<u8>,
        pub run_id: u64,
        pub config_version: u64,
        pub primary_type: u8,
        pub tags_mask: u64,
        pub sales_window: types::SalesWindow,
        pub ticket_price: u64,
        pub ticket_limits: types::TicketLimits,
        pub sales_distribution: economics::SalesDistribution,
        pub prize_plan: vector<types::PrizeSlot>,
        pub winners_dedup: bool,
        pub draw_algo: u8,
        pub auto_close_policy: types::AutoClosePolicy,
        pub reward_backend: types::RewardBackend,
        pub vrf_retry_policy: types::RetryPolicy,
    }

    struct Lottery has store {
        id: u64,
        config: Config,
        status: u8,
        snapshot_frozen: bool,
        slots_checksum: vector<u8>,
    }

    pub struct CancellationRecord has copy, drop, store {
        pub reason_code: u8,
        pub canceled_ts: u64,
        pub previous_status: u8,
        pub tickets_sold: u64,
        pub proceeds_accum: u64,
    }

    struct Registry has key {
        lotteries: table::Table<u64, Lottery>,
        ordered_ids: vector<u64>,
        created_events: event::EventHandle<history::LotteryCreatedEvent>,
        canceled_events: event::EventHandle<history::LotteryCanceledEvent>,
        cancellations: table::Table<u64, CancellationRecord>,
    }

    public entry fun init_registry(admin: &signer) {
        let registry_addr = signer::address_of(admin);
        assert!(registry_addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(
            !exists<Registry>(registry_addr),
            errors::E_ALREADY_INITIALIZED,
        );
        let created_events = event::new_event_handle<history::LotteryCreatedEvent>(admin);
        let canceled_events = event::new_event_handle<history::LotteryCanceledEvent>(admin);
        let registry = Registry {
            lotteries: table::new(),
            ordered_ids: vector::empty(),
            created_events,
            canceled_events,
            cancellations: table::new(),
        };
        move_to(admin, registry);
    }

    public entry fun create_draft_admin(admin: &signer, id: u64, config: Config) acquires Registry {
        ensure_config_valid(&config);
        let creator = signer::address_of(admin);
        create_lottery_internal(creator, id, config);
    }

    public entry fun create_draft_partner(
        partner: &signer,
        cap: &roles::PartnerCreateCap,
        id: u64,
        config: Config,
    ) acquires Registry {
        ensure_config_valid(&config);
        roles::ensure_primary_type_allowed(cap, config.primary_type);
        roles::ensure_tags_allowed(cap, config.tags_mask);
        let creator = signer::address_of(partner);
        create_lottery_internal(creator, id, config);
    }

    public entry fun set_primary_type(admin: &signer, id: u64, primary_type: u8) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAFT, errors::E_PRIMARY_TYPE_LOCKED);
        if (lottery.config.primary_type != primary_type) {
            tags::validate(primary_type, lottery.config.tags_mask);
            lottery.config.primary_type = primary_type;
        };
    }

    public entry fun set_tags_mask(admin: &signer, id: u64, tags_mask: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAFT || lottery.status == STATUS_ACTIVE, errors::E_TAGS_LOCKED);
        assert!(!lottery.snapshot_frozen, errors::E_TAGS_LOCKED);
        tags::validate(lottery.config.primary_type, tags_mask);
        tags::assert_tag_budget(tags_mask);
        lottery.config.tags_mask = tags_mask;
    }

    public entry fun advance_status(admin: &signer, id: u64, next_status: u8) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(is_transition_allowed(lottery.status, next_status), errors::E_STATUS_TRANSITION_NOT_ALLOWED);
        if (next_status == STATUS_CLOSING) {
            assert!(!lottery.snapshot_frozen, errors::E_SNAPSHOT_FROZEN);
            lottery.snapshot_frozen = true;
        };
        lottery.status = next_status;
    }

    public entry fun cancel_lottery_admin(
        admin: &signer,
        id: u64,
        reason_code: u8,
        now_ts: u64,
    ) acquires Registry, sales::SalesLedger {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(reason_code > 0, errors::E_CANCEL_REASON_INVALID);
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        let previous_status = lottery.status;
        assert!(is_transition_allowed(previous_status, STATUS_CANCELED), errors::E_STATUS_TRANSITION_NOT_ALLOWED);
        lottery.status = STATUS_CANCELED;
        if (!lottery.snapshot_frozen) {
            lottery.snapshot_frozen = true;
        };

        let mut tickets_sold = 0u64;
        let mut proceeds_accum = 0u64;
        if (sales::has_state(id)) {
            let (sold, proceeds, _last_ts) = sales::sales_totals(id);
            tickets_sold = sold;
            proceeds_accum = proceeds;
            sales::begin_refund(id);
        };

        let record = CancellationRecord {
            reason_code,
            canceled_ts: now_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
        };
        table::add(&mut registry.cancellations, id, copy record);

        let event = history::LotteryCanceledEvent {
            event_version: history::EVENT_VERSION_V1,
            event_category: history::EVENT_CATEGORY_REFUND,
            lottery_id: id,
            previous_status,
            reason_code,
            tickets_sold,
            proceeds_accum,
            timestamp: now_ts,
        };
        event::emit_event(&mut registry.canceled_events, event);
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

    public fun get_cancellation_record(
        id: u64,
    ): option::Option<CancellationRecord> acquires Registry {
        let registry = borrow_registry_ref();
        if (!table::contains(&registry.cancellations, id)) {
            option::none()
        } else {
            let record = table::borrow(&registry.cancellations, id);
            option::some(*record)
        }
    }

    fun create_lottery_internal(creator: address, id: u64, config: Config) acquires Registry {
        let registry = borrow_registry_mut();
        assert!(!table::contains(&registry.lotteries, id), errors::E_LOTTERY_EXISTS);
        vector::push_back(&mut registry.ordered_ids, id);
        let slots_checksum = types::prize_plan_checksum(&config.prize_plan);
        let event_slug_for_event = copy config.event_slug;
        let series_code_for_event = copy config.series_code;
        let primary_type_for_event = config.primary_type;
        let tags_mask_for_event = config.tags_mask;
        let run_id = config.run_id;
        let config_version = config.config_version;
        let cfg_bytes = bcs::to_bytes(&config);
        let cfg_hash = hash::sha3_256(cfg_bytes);
        let lottery = Lottery {
            id,
            config,
            status: STATUS_DRAFT,
            snapshot_frozen: false,
            slots_checksum: copy slots_checksum,
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
            slots_checksum,
        };
        event::emit_event(&mut registry.created_events, event);
    }

    public fun get_cancellation_record(id: u64): option::Option<CancellationRecord> acquires Registry {
        let registry = borrow_registry_ref();
        if (!table::contains(&registry.cancellations, id)) {
            return option::none();
        };
        let record = table::borrow(&registry.cancellations, id);
        option::some(copy *record)
    }

    public fun get_cancellation_from_registry(
        registry_ref: &Registry,
        id: u64,
    ): option::Option<CancellationRecord> {
        if (!table::contains(&registry_ref.cancellations, id)) {
            return option::none();
        };
        let record = table::borrow(&registry_ref.cancellations, id);
        option::some(copy *record)
    }

    fun borrow_registry_mut(): &mut Registry acquires Registry {
        let registry_addr = @lottery_multi;
        if (!exists<Registry>(registry_addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global_mut<Registry>(registry_addr)
    }

    fun borrow_registry_ref(): &Registry acquires Registry {
        // The registry is stored at the module address (@lottery_multi).
        let registry_addr = @lottery_multi;
        if (!exists<Registry>(registry_addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global<Registry>(registry_addr)
    }

    public fun borrow_registry_for_view(): &Registry acquires Registry {
        borrow_registry_ref()
    }

    fun ensure_config_valid(config: &Config) {
        tags::validate(config.primary_type, config.tags_mask);
        tags::assert_tag_budget(config.tags_mask);
        types::assert_sales_window(&config.sales_window);
        types::assert_ticket_price(config.ticket_price);
        types::assert_ticket_limits(&config.ticket_limits);
        economics::assert_distribution(&config.sales_distribution);
        types::assert_prize_plan(&config.prize_plan);
        types::assert_draw_algo(config.draw_algo);
        types::assert_retry_policy(&config.vrf_retry_policy);
    }

    public fun ordered_ids_view(registry_ref: &Registry): &vector<u64> {
        &registry_ref.ordered_ids
    }

    public fun borrow_config_from_registry(registry_ref: &Registry, id: u64): &Config {
        let lottery = table::borrow(&registry_ref.lotteries, id);
        &lottery.config
    }

    public fun get_status_from_registry(registry_ref: &Registry, id: u64): u8 {
        let lottery = table::borrow(&registry_ref.lotteries, id);
        lottery.status
    }

    public fun slots_checksum(id: u64): vector<u8> acquires Registry {
        let registry = borrow_registry_ref();
        let lottery = table::borrow(&registry.lotteries, id);
        copy lottery.slots_checksum
    }

    public fun mark_draw_requested(id: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(
            lottery.status == STATUS_CLOSING || lottery.status == STATUS_DRAW_REQUESTED,
            errors::E_DRAW_STATUS_INVALID,
        );
        lottery.status = STATUS_DRAW_REQUESTED;
    }

    public fun mark_drawn(id: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAW_REQUESTED, errors::E_DRAW_STATUS_INVALID);
        lottery.status = STATUS_DRAWN;
    }

    public fun mark_payout(id: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_DRAWN, errors::E_DRAW_STATUS_INVALID);
        lottery.status = STATUS_PAYOUT;
    }

    public fun mark_finalized(id: u64) acquires Registry {
        let registry = borrow_registry_mut();
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == STATUS_PAYOUT, errors::E_DRAW_STATUS_INVALID);
        lottery.status = STATUS_FINALIZED;
    }

    fun is_transition_allowed(current: u8, next: u8): bool {
        if (current == STATUS_DRAFT) {
            return next == STATUS_ACTIVE || next == STATUS_CANCELED;
        };
        if (current == STATUS_ACTIVE) {
            return next == STATUS_CLOSING || next == STATUS_CANCELED;
        };
        if (current == STATUS_CLOSING) {
            return next == STATUS_DRAW_REQUESTED || next == STATUS_FINALIZED || next == STATUS_CANCELED;
        };
        if (current == STATUS_DRAW_REQUESTED) {
            return next == STATUS_DRAWN || next == STATUS_CANCELED;
        };
        if (current == STATUS_DRAWN) {
            return next == STATUS_PAYOUT || next == STATUS_CANCELED;
        };
        if (current == STATUS_PAYOUT) {
            return next == STATUS_FINALIZED || next == STATUS_CANCELED;
        };
        false
    }
}

