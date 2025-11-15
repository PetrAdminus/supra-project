// sources/registry.move
module lottery_multi::lottery_registry {
    use std::bcs;
    use std::hash;
    use std::option;
    use std::signer;
    use std::table;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::history;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::math;
    use lottery_multi::roles;
    use lottery_multi::tags;
    use lottery_multi::types;

    const EVENT_CATEGORY_REGISTRY: u8 = 1;
    const EVENT_CATEGORY_REFUND: u8 = 8;

    const CANCEL_REASON_VRF_FAILURE: u8 = 1;
    const CANCEL_REASON_COMPLIANCE: u8 = 2;
    const CANCEL_REASON_OPERATIONS: u8 = 3;

    struct Config has copy, drop, store {
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        config_version: u64,
        primary_type: u8,
        tags_mask: u64,
        sales_window: types::SalesWindow,
        ticket_price: u64,
        ticket_limits: types::TicketLimits,
        sales_distribution: economics::SalesDistribution,
        prize_plan: vector<types::PrizeSlot>,
        winners_dedup: bool,
        draw_algo: u8,
        auto_close_policy: types::AutoClosePolicy,
        reward_backend: types::RewardBackend,
        vrf_retry_policy: types::RetryPolicy,
    }

    struct Lottery has store {
        id: u64,
        config: Config,
        status: u8,
        snapshot_frozen: bool,
        slots_checksum: vector<u8>,
    }

    struct CancellationRecord has copy, drop, store {
        reason_code: u8,
        canceled_ts: u64,
        previous_status: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
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
        assert!(registry_addr == @lottery_multi, errors::err_registry_missing());
        assert!(
            !exists<Registry>(registry_addr),
            errors::err_already_initialized(),
        );
        let created_events = account::new_event_handle<history::LotteryCreatedEvent>(admin);
        let canceled_events = account::new_event_handle<history::LotteryCanceledEvent>(admin);
        let registry = Registry {
            lotteries: table::new(),
            ordered_ids: vector::empty(),
            created_events,
            canceled_events,
            cancellations: table::new(),
        };
        move_to(admin, registry);
    }

    public entry fun create_draft_admin(
        admin: &signer,
        id: u64,
        config_bytes: vector<u8>,
    ) acquires Registry {
        let config = decode_config(config_bytes);
        create_draft_admin_with_config(admin, id, config);
    }

    public entry fun create_draft_partner(
        partner: &signer,
        cap_bytes: vector<u8>,
        id: u64,
        config_bytes: vector<u8>,
    ) acquires Registry {
        let config = decode_config(config_bytes);
        let cap = decode_partner_cap(cap_bytes);
        create_draft_partner_with_config(partner, &cap, id, config);
    }

    public fun create_draft_admin_with_config(
        admin: &signer,
        id: u64,
        config: Config,
    ) acquires Registry {
        ensure_config_valid(&config);
        let creator = signer::address_of(admin);
        create_lottery_internal(creator, id, config);
    }

    public fun create_draft_partner_with_config(
        partner: &signer,
        cap: &roles::PartnerCreateCap,
        id: u64,
        config: Config,
    ) acquires Registry {
        ensure_config_valid(&config);
        let creator = signer::address_of(partner);
        roles::ensure_primary_type_allowed(cap, config.primary_type);
        roles::ensure_tags_allowed(cap, config.tags_mask);
        create_lottery_internal(creator, id, config);
    }

    public entry fun set_primary_type(admin: &signer, id: u64, primary_type: u8) acquires Registry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::err_registry_missing());
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == types::status_draft(), errors::err_primary_type_locked());
        if (lottery.config.primary_type != primary_type) {
            tags::validate(primary_type, lottery.config.tags_mask);
            lottery.config.primary_type = primary_type;
        };
    }

    public entry fun set_tags_mask(admin: &signer, id: u64, tags_mask: u64) acquires Registry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::err_registry_missing());
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == types::status_draft() || lottery.status == types::status_active(), errors::err_tags_locked());
        assert!(!lottery.snapshot_frozen, errors::err_tags_locked());
        tags::validate(lottery.config.primary_type, tags_mask);
        tags::assert_tag_budget(tags_mask);
        lottery.config.tags_mask = tags_mask;
    }

    public entry fun advance_status(admin: &signer, id: u64, next_status: u8) acquires Registry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::err_registry_missing());
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(is_transition_allowed(lottery.status, next_status), errors::err_status_transition_not_allowed());
        if (next_status == types::status_closing()) {
            assert!(!lottery.snapshot_frozen, errors::err_snapshot_frozen());
            lottery.snapshot_frozen = true;
        };
        lottery.status = next_status;
    }

    public fun apply_cancellation(
        admin: &signer,
        id: u64,
        reason_code: u8,
        now_ts: u64,
        tickets_sold: u64,
        proceeds_accum: u64,
    ) acquires Registry {
        let caller = signer::address_of(admin);
        assert!(caller == @lottery_multi, errors::err_registry_missing());
        assert!(reason_code > 0, errors::err_cancel_reason_invalid());
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        let previous_status = lottery.status;
        assert!(is_transition_allowed(previous_status, types::status_canceled()), errors::err_status_transition_not_allowed());
        lottery.status = types::status_canceled();
        if (!lottery.snapshot_frozen) {
            lottery.snapshot_frozen = true;
        };

        let record = CancellationRecord {
            reason_code,
            canceled_ts: now_ts,
            previous_status,
            tickets_sold,
            proceeds_accum,
        };
        table::add(&mut registry.cancellations, id, copy record);

        let event = history::new_lottery_canceled_event(
            id,
            previous_status,
            reason_code,
            tickets_sold,
            proceeds_accum,
            now_ts,
        );
        event::emit_event(&mut registry.canceled_events, event);
    }

    public fun get_status(id: u64): u8 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let lottery = table::borrow(&registry.lotteries, id);
        lottery.status
    }

    public fun is_snapshot_frozen(id: u64): bool acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let lottery = table::borrow(&registry.lotteries, id);
        lottery.snapshot_frozen
    }

    public fun get_cancellation_record(
        id: u64,
    ): option::Option<CancellationRecord> acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        if (!table::contains(&registry.cancellations, id)) {
            option::none()
        } else {
            let record = table::borrow(&registry.cancellations, id);
            option::some(clone_cancellation(record))
        }
    }

    fun create_lottery_internal(creator: address, id: u64, config: Config) acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        assert!(!table::contains(&registry.lotteries, id), errors::err_lottery_exists());
        vector::push_back(&mut registry.ordered_ids, id);
        let slots_checksum = types::prize_plan_checksum(&config.prize_plan);
        let event_slug_for_event = clone_bytes(&config.event_slug);
        let series_code_for_event = clone_bytes(&config.series_code);
        let primary_type_for_event = config.primary_type;
        let tags_mask_for_event = config.tags_mask;
        let run_id = config.run_id;
        let config_version = config.config_version;
        let cfg_bytes = bcs::to_bytes(&config);
        let cfg_hash = hash::sha3_256(cfg_bytes);
        let lottery = Lottery {
            id,
            config,
            status: types::status_draft(),
            snapshot_frozen: false,
            slots_checksum: copy slots_checksum,
        };
        table::add(&mut registry.lotteries, id, lottery);
        let event = history::new_lottery_created_event(
            id,
            cfg_hash,
            config_version,
            creator,
            event_slug_for_event,
            series_code_for_event,
            run_id,
            primary_type_for_event,
            tags_mask_for_event,
            slots_checksum,
        );
        event::emit_event(&mut registry.created_events, event);
    }

    public fun get_cancellation_from_registry(
        registry_ref: &Registry,
        id: u64,
    ): option::Option<CancellationRecord> {
        if (!table::contains(&registry_ref.cancellations, id)) {
            return option::none()
        };
        let record = table::borrow(&registry_ref.cancellations, id);
        option::some(clone_cancellation(record))
    }

    //
    // Test helpers (Move v1 compatibility)
    //

    public fun new_config_for_tests(
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        config_version: u64,
        primary_type: u8,
        tags_mask: u64,
        sales_window: types::SalesWindow,
        ticket_price: u64,
        ticket_limits: types::TicketLimits,
        sales_distribution: economics::SalesDistribution,
        prize_plan: vector<types::PrizeSlot>,
        winners_dedup: bool,
        draw_algo: u8,
        auto_close_policy: types::AutoClosePolicy,
        reward_backend: types::RewardBackend,
        vrf_retry_policy: types::RetryPolicy,
    ): Config {
        Config {
            event_slug,
            series_code,
            run_id,
            config_version,
            primary_type,
            tags_mask,
            sales_window,
            ticket_price,
            ticket_limits,
            sales_distribution,
            prize_plan,
            winners_dedup,
            draw_algo,
            auto_close_policy,
            reward_backend,
            vrf_retry_policy,
        }
    }

    public fun clone_config(config: &Config): Config {
        let prize_plan = types::clone_prize_plan(&config.prize_plan);
        new_config_for_tests(
            clone_bytes(&config.event_slug),
            clone_bytes(&config.series_code),
            config.run_id,
            config.config_version,
            config.primary_type,
            config.tags_mask,
            config.sales_window,
            config.ticket_price,
            config.ticket_limits,
            economics::clone_sales_distribution(&config.sales_distribution),
            prize_plan,
            config.winners_dedup,
            config.draw_algo,
            config.auto_close_policy,
            types::clone_reward_backend(&config.reward_backend),
            types::clone_retry_policy(&config.vrf_retry_policy),
        )
    }

    public fun config_with_run_id(config: &Config, run_id: u64): Config {
        rebuild_config_with(
            config,
            run_id,
            config.sales_window,
            types::clone_prize_plan(&config.prize_plan),
        )
    }

    public fun config_with_sales_window(
        config: &Config,
        sales_window: types::SalesWindow,
    ): Config {
        rebuild_config_with(
            config,
            config.run_id,
            sales_window,
            types::clone_prize_plan(&config.prize_plan),
        )
    }

    public fun config_with_prize_plan(
        config: &Config,
        prize_plan: vector<types::PrizeSlot>,
    ): Config {
        rebuild_config_with(
            config,
            config.run_id,
            config.sales_window,
            prize_plan,
        )
    }

    public fun config_run_id(config: &Config): u64 {
        config.run_id
    }

    public fun config_prize_plan(config: &Config): vector<types::PrizeSlot> {
        types::clone_prize_plan(&config.prize_plan)
    }

    fun rebuild_config_with(
        config: &Config,
        run_id: u64,
        sales_window: types::SalesWindow,
        prize_plan: vector<types::PrizeSlot>,
    ): Config {
        new_config_for_tests(
            clone_bytes(&config.event_slug),
            clone_bytes(&config.series_code),
            run_id,
            config.config_version,
            config.primary_type,
            config.tags_mask,
            sales_window,
            config.ticket_price,
            config.ticket_limits,
            economics::clone_sales_distribution(&config.sales_distribution),
            prize_plan,
            config.winners_dedup,
            config.draw_algo,
            config.auto_close_policy,
            types::clone_reward_backend(&config.reward_backend),
            types::clone_retry_policy(&config.vrf_retry_policy),
        )
    }

    fun registry_addr_or_abort(): address {
        let registry_addr = @lottery_multi;
        if (!exists<Registry>(registry_addr)) {
            abort errors::err_registry_missing()
        };
        registry_addr
    }

    fun decode_config(data: vector<u8>): Config {
        let cursor = 0u64;
        let event_slug = read_bytes(&data, &mut cursor);
        let series_code = read_bytes(&data, &mut cursor);
        let run_id = read_u64(&data, &mut cursor);
        let config_version = read_u64(&data, &mut cursor);
        let primary_type = read_u8(&data, &mut cursor);
        let tags_mask = read_u64(&data, &mut cursor);
        let sales_window = decode_sales_window(&data, &mut cursor);
        let ticket_price = read_u64(&data, &mut cursor);
        let ticket_limits = decode_ticket_limits(&data, &mut cursor);
        let sales_distribution = decode_sales_distribution(&data, &mut cursor);
        let prize_plan = decode_prize_plan(&data, &mut cursor);
        let winners_dedup = read_bool(&data, &mut cursor);
        let draw_algo = read_u8(&data, &mut cursor);
        let auto_close_policy = decode_auto_close_policy(&data, &mut cursor);
        let reward_backend = decode_reward_backend(&data, &mut cursor);
        let vrf_retry_policy = decode_retry_policy(&data, &mut cursor);
        ensure_fully_consumed(&data, cursor);
        Config {
            event_slug,
            series_code,
            run_id,
            config_version,
            primary_type,
            tags_mask,
            sales_window,
            ticket_price,
            ticket_limits,
            sales_distribution,
            prize_plan,
            winners_dedup,
            draw_algo,
            auto_close_policy,
            reward_backend,
            vrf_retry_policy,
        }
    }

    fun decode_partner_cap(data: vector<u8>): roles::PartnerCreateCap {
        let cursor = 0u64;
        let allowed_event_slug = read_bytes(&data, &mut cursor);
        let allowed_series_codes = read_series_codes(&data, &mut cursor);
        let allowed_primary_types = read_bytes(&data, &mut cursor);
        let allowed_tags_mask = read_u64(&data, &mut cursor);
        let max_parallel = read_u64(&data, &mut cursor);
        let expires_at = read_u64(&data, &mut cursor);
        let payout_cooldown_secs = read_u64(&data, &mut cursor);
        ensure_fully_consumed(&data, cursor);
        roles::new_partner_cap(
            allowed_event_slug,
            allowed_series_codes,
            allowed_primary_types,
            allowed_tags_mask,
            max_parallel,
            expires_at,
            payout_cooldown_secs,
        )
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

    public fun ordered_ids_snapshot(): vector<u64> acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        clone_u64_vector(&registry.ordered_ids)
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
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let lottery = table::borrow(&registry.lotteries, id);
        clone_bytes(&lottery.slots_checksum)
    }

    public fun mark_draw_requested(id: u64) acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(
            lottery.status == types::status_closing() || lottery.status == types::status_draw_requested(),
            errors::err_draw_status_invalid(),
        );
        lottery.status = types::status_draw_requested();
    }

    public fun mark_drawn(id: u64) acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == types::status_draw_requested(), errors::err_draw_status_invalid());
        lottery.status = types::status_drawn();
    }

    public fun mark_payout(id: u64) acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == types::status_drawn(), errors::err_draw_status_invalid());
        lottery.status = types::status_payout();
    }

    public fun mark_finalized(id: u64) acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global_mut<Registry>(registry_addr);
        let lottery = table::borrow_mut(&mut registry.lotteries, id);
        assert!(lottery.status == types::status_payout(), errors::err_draw_status_invalid());
        lottery.status = types::status_finalized();
    }

    //
    // Config accessors (Move v1 compatibility)
    //

    public fun clone_prize_plan(id: u64): vector<types::PrizeSlot> acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        types::clone_prize_plan(&config.prize_plan)
    }

    public fun winners_dedup_enabled(id: u64): bool acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.winners_dedup
    }

    public fun config_view(id: u64): Config acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let lottery = table::borrow(&registry.lotteries, id);
        lottery.config
    }

    public fun cancel_reason_vrf_failure(): u8 {
        CANCEL_REASON_VRF_FAILURE
    }

    public fun cancel_reason_compliance(): u8 {
        CANCEL_REASON_COMPLIANCE
    }

    public fun cancel_reason_operations(): u8 {
        CANCEL_REASON_OPERATIONS
    }

    public fun event_slug(id: u64): vector<u8> acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        clone_bytes(&config.event_slug)
    }

    public fun series_code(id: u64): vector<u8> acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        clone_bytes(&config.series_code)
    }

    public fun run_id(id: u64): u64 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.run_id
    }

    public fun primary_type(id: u64): u8 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.primary_type
    }

    public fun tags_mask(id: u64): u64 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.tags_mask
    }

    public fun sales_start(id: u64): u64 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        types::sales_window_start(&config.sales_window)
    }

    public fun sales_window_view(id: u64): types::SalesWindow acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.sales_window
    }

    public fun config_version(id: u64): u64 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.config_version
    }

    public fun vrf_retry_policy(id: u64): types::RetryPolicy acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        types::clone_retry_policy(&config.vrf_retry_policy)
    }

    public fun ticket_price(id: u64): u64 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.ticket_price
    }

    public fun ticket_limits(id: u64): types::TicketLimits acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.ticket_limits
    }

    public fun sales_distribution_view(id: u64): economics::SalesDistribution acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.sales_distribution
    }

    public fun draw_algo(id: u64): u8 acquires Registry {
        let registry_addr = registry_addr_or_abort();
        let registry = borrow_global<Registry>(registry_addr);
        let config = borrow_config_from_registry(registry, id);
        config.draw_algo
    }

    public fun cancellation_record_canceled_ts(record: &CancellationRecord): u64 {
        record.canceled_ts
    }

    public fun cancellation_record_reason_code(record: &CancellationRecord): u8 {
        record.reason_code
    }

    public fun cancellation_record_previous_status(record: &CancellationRecord): u8 {
        record.previous_status
    }

    public fun cancellation_record_tickets_sold(record: &CancellationRecord): u64 {
        record.tickets_sold
    }

    public fun cancellation_record_proceeds_accum(record: &CancellationRecord): u64 {
        record.proceeds_accum
    }

    public fun primary_type_from_registry(registry_ref: &Registry, id: u64): u8 {
        let lottery = table::borrow(&registry_ref.lotteries, id);
        lottery.config.primary_type
    }

    public fun tags_mask_from_registry(registry_ref: &Registry, id: u64): u64 {
        let lottery = table::borrow(&registry_ref.lotteries, id);
        lottery.config.tags_mask
    }

    fun is_transition_allowed(current: u8, next: u8): bool {
        if (current == types::status_draft()) {
            return next == types::status_active() || next == types::status_canceled()
        };
        if (current == types::status_active()) {
            return next == types::status_closing() || next == types::status_canceled()
        };
        if (current == types::status_closing()) {
            return next == types::status_draw_requested() || next == types::status_finalized() || next == types::status_canceled()
        };
        if (current == types::status_draw_requested()) {
            return next == types::status_drawn() || next == types::status_canceled()
        };
        if (current == types::status_drawn()) {
            return next == types::status_payout() || next == types::status_canceled()
        };
        if (current == types::status_payout()) {
            return next == types::status_finalized() || next == types::status_canceled()
        };
        false
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let result = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(source, i);
            vector::push_back(&mut result, byte);
            i = i + 1;
        };
        result
    }

    fun clone_u64_vector(source: &vector<u64>): vector<u64> {
        let len = vector::length(source);
        let result = vector::empty<u64>();
        let i = 0u64;
        while (i < len) {
            let value = *vector::borrow(source, i);
            vector::push_back(&mut result, value);
            i = i + 1;
        };
        result
    }

    fun clone_cancellation(record: &CancellationRecord): CancellationRecord {
        CancellationRecord {
            reason_code: record.reason_code,
            canceled_ts: record.canceled_ts,
            previous_status: record.previous_status,
            tickets_sold: record.tickets_sold,
            proceeds_accum: record.proceeds_accum,
        }
    }

    //
    // BCS decoding helpers (Move v1 compatibility)
    //

    fun decode_sales_window(data: &vector<u8>, cursor: &mut u64): types::SalesWindow {
        let sales_start = read_u64(data, cursor);
        let sales_end = read_u64(data, cursor);
        types::new_sales_window(sales_start, sales_end)
    }

    fun decode_ticket_limits(data: &vector<u8>, cursor: &mut u64): types::TicketLimits {
        let max_total = read_u64(data, cursor);
        let max_per_address = read_u64(data, cursor);
        types::new_ticket_limits(max_total, max_per_address)
    }

    fun decode_sales_distribution(data: &vector<u8>, cursor: &mut u64): economics::SalesDistribution {
        let prize_bps = read_u16(data, cursor);
        let jackpot_bps = read_u16(data, cursor);
        let operations_bps = read_u16(data, cursor);
        let reserve_bps = read_u16(data, cursor);
        economics::new_sales_distribution(prize_bps, jackpot_bps, operations_bps, reserve_bps)
    }

    fun decode_prize_plan(data: &vector<u8>, cursor: &mut u64): vector<types::PrizeSlot> {
        let count = read_len(data, cursor);
        let plan = vector::empty<types::PrizeSlot>();
        let i = 0u64;
        while (i < count) {
            vector::push_back(&mut plan, decode_prize_slot(data, cursor));
            i = i + 1;
        };
        plan
    }

    fun decode_prize_slot(data: &vector<u8>, cursor: &mut u64): types::PrizeSlot {
        let slot_id = read_u64(data, cursor);
        let winners_per_slot = read_u16(data, cursor);
        let reward_type = read_u8(data, cursor);
        let reward_payload = read_bytes(data, cursor);
        types::new_prize_slot(slot_id, winners_per_slot, reward_type, reward_payload)
    }

    fun decode_auto_close_policy(data: &vector<u8>, cursor: &mut u64): types::AutoClosePolicy {
        let enabled = read_bool(data, cursor);
        let grace_period_secs = read_u64(data, cursor);
        types::new_auto_close_policy(enabled, grace_period_secs)
    }

    fun decode_reward_backend(data: &vector<u8>, cursor: &mut u64): types::RewardBackend {
        let backend_type = read_u8(data, cursor);
        let config_blob = read_bytes(data, cursor);
        types::new_reward_backend(backend_type, config_blob)
    }

    fun decode_retry_policy(data: &vector<u8>, cursor: &mut u64): types::RetryPolicy {
        let strategy = read_u8(data, cursor);
        let base_delay = read_u64(data, cursor);
        let max_delay = read_u64(data, cursor);
        types::new_retry_policy(strategy, base_delay, max_delay)
    }

    fun read_series_codes(data: &vector<u8>, cursor: &mut u64): vector<vector<u8>> {
        let count = read_len(data, cursor);
        let codes = vector::empty<vector<u8>>();
        let i = 0u64;
        while (i < count) {
            vector::push_back(&mut codes, read_bytes(data, cursor));
            i = i + 1;
        };
        codes
    }

    fun read_bytes(data: &vector<u8>, cursor: &mut u64): vector<u8> {
        let len = read_len(data, cursor);
        ensure_available(data, *cursor, len);
        let out = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(data, *cursor);
            vector::push_back(&mut out, byte);
            *cursor = *cursor + 1;
            i = i + 1;
        };
        out
    }

    fun read_bool(data: &vector<u8>, cursor: &mut u64): bool {
        let value = read_u8(data, cursor);
        if (value == 0) {
            return false
        };
        if (value == 1) {
            return true
        };
        abort errors::err_bcs_decode()
    }

    fun read_u8(data: &vector<u8>, cursor: &mut u64): u8 {
        ensure_available(data, *cursor, 1);
        let value = *vector::borrow(data, *cursor);
        *cursor = *cursor + 1;
        value
    }

    fun read_u16(data: &vector<u8>, cursor: &mut u64): u16 {
        let byte0 = math::widen_u16_from_u8(read_u8(data, cursor));
        let byte1 = math::widen_u16_from_u8(read_u8(data, cursor));
        byte0 | (byte1 << 8u8)
    }

    fun read_u64(data: &vector<u8>, cursor: &mut u64): u64 {
        let result = 0u64;
        let i = 0u64;
        while (i < 8) {
            let byte = read_u8(data, cursor);
            let shift =
                math::narrow_u8_from_u64(i * 8u64, errors::err_bcs_decode());
            result = result | (math::widen_u64_from_u8(byte) << shift);
            i = i + 1;
        };
        result
    }

    fun read_len(data: &vector<u8>, cursor: &mut u64): u64 {
        read_uleb128(data, cursor)
    }

    fun read_uleb128(data: &vector<u8>, cursor: &mut u64): u64 {
        let result = 0u64;
        let shift = 0u8;
        while (true) {
            let byte = read_u8(data, cursor);
            let lower = byte & 0x7fu8;
            let value = math::widen_u64_from_u8(lower) << shift;
            result = result | value;
            if ((byte & 0x80u8) == 0u8) {
                break
            };
            shift = shift + 7u8;
            if (shift > 63u8) {
                abort errors::err_bcs_decode()
            };
        };
        result
    }

    fun ensure_available(data: &vector<u8>, cursor: u64, needed: u64) {
        let len = vector::length(data);
        if (cursor + needed > len) {
            abort errors::err_bcs_decode()
        };
    }

    fun ensure_fully_consumed(data: &vector<u8>, cursor: u64) {
        let len = vector::length(data);
        assert!(cursor == len, errors::err_bcs_decode());
    }
}

