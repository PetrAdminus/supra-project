module lottery_gateway::gateway {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::cancellations;
    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::operators;
    use lottery_data::rounds;
    use lottery_engine::cancellation;
    use lottery_engine::draw;
    use lottery_engine::lifecycle;
    use lottery_engine::operators as engine_operators;
    use lottery_engine::sales;
    use lottery_engine::ticketing;
    use lottery_gateway::history;
    use lottery_gateway::registry;
    use supra_framework::account;
    use supra_framework::event;
    use lottery_vrf_gateway::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_COUNTER_OVERFLOW: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;
    const E_NOT_INITIALIZED: u64 = 5;
    const E_INVALID_COUNTER_TARGET: u64 = 6;
    const E_LOTTERY_ALREADY_REGISTERED: u64 = 7;

    struct OwnerLotteries has store {
        lottery_ids: vector<u64>,
    }

    struct GatewayLottery has copy, drop, store {
        owner: address,
        active: bool,
    }

    struct LegacyGatewayLottery has copy, drop, store {
        lottery_id: u64,
        owner: address,
        active: bool,
        ticket_price: u64,
        auto_draw_threshold: u64,
        jackpot_share_bps: u16,
    }

    struct LegacyGatewayRegistry has copy, drop, store {
        admin: address,
        next_lottery_id: u64,
        lotteries: vector<LegacyGatewayLottery>,
    }

    #[event]
    struct LotteryCreatedEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
        ticket_price: u64,
        auto_draw_threshold: u64,
        jackpot_share_bps: u16,
    }

    #[event]
    struct LotteryOwnerUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        previous: option::Option<address>,
        next: address,
    }

    #[event]
    struct LotteryStatusUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        active: bool,
    }

    #[event]
    struct GatewaySnapshotEvent has drop, store, copy {
        admin: address,
        next_lottery_id: u64,
        total_lotteries: u64,
    }

    struct GatewayRegistry has key {
        admin: address,
        next_lottery_id: u64,
        lotteries: table::Table<u64, GatewayLottery>,
        owner_index: table::Table<address, OwnerLotteries>,
        lottery_ids: vector<u64>,
        creation_events: event::EventHandle<LotteryCreatedEvent>,
        owner_events: event::EventHandle<LotteryOwnerUpdatedEvent>,
        status_events: event::EventHandle<LotteryStatusUpdatedEvent>,
        snapshot_events: event::EventHandle<GatewaySnapshotEvent>,
    }

    #[view]
    public fun is_initialized(): bool {
        exists<GatewayRegistry>(@lottery)
    }

    #[view]
    public fun admin(): option::Option<address> acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            return option::none<address>();
        };
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        option::some(gateway.admin)
    }

    #[view]
    public fun gateway_snapshot(): option::Option<GatewaySnapshotEvent>
    acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            return option::none<GatewaySnapshotEvent>();
        };
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        let total = vector::length(&gateway.lottery_ids);
        option::some(GatewaySnapshotEvent {
            admin: gateway.admin,
            next_lottery_id: gateway.next_lottery_id,
            total_lotteries: total,
        })
    }

    #[view]
    public fun lottery(lottery_id: u64): option::Option<GatewayLottery>
    acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            return option::none<GatewayLottery>();
        };
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        if (!table::contains(&gateway.lotteries, lottery_id)) {
            option::none<GatewayLottery>()
        } else {
            option::some(*table::borrow(&gateway.lotteries, lottery_id))
        }
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            return vector::empty<u64>();
        };
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        clone_u64_vector(&gateway.lottery_ids)
    }

    #[view]
    public fun lotteries_for_owner(owner: address): vector<u64>
    acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            return vector::empty<u64>();
        };
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        if (!table::contains(&gateway.owner_index, owner)) {
            vector::empty<u64>()
        } else {
            let record = table::borrow(&gateway.owner_index, owner);
            clone_u64_vector(&record.lottery_ids)
        }
    }

    public entry fun init(caller: &signer, admin: address)
    acquires GatewayRegistry, history::LotteryHistory, instances::InstanceRegistry, registry::LotteryRegistry {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<GatewayRegistry>(caller_address), E_ALREADY_INITIALIZED);

        registry::init(caller, admin);
        history::init(caller, admin);

        move_to(
            caller,
            GatewayRegistry {
                admin,
                next_lottery_id: 1,
                lotteries: table::new<u64, GatewayLottery>(),
                owner_index: table::new<address, OwnerLotteries>(),
                lottery_ids: vector::empty<u64>(),
                creation_events: account::new_event_handle<LotteryCreatedEvent>(caller),
                owner_events: account::new_event_handle<LotteryOwnerUpdatedEvent>(caller),
                status_events: account::new_event_handle<LotteryStatusUpdatedEvent>(caller),
                snapshot_events: account::new_event_handle<GatewaySnapshotEvent>(caller),
            },
        );

        let registry = instances::borrow_registry_mut(@lottery);
        instances::set_admin(registry, admin);
        instances::set_hub(registry, caller_address);
    }

    public entry fun set_admin(caller: &signer, new_admin: address)
    acquires GatewayRegistry, instances::InstanceRegistry, registry::LotteryRegistry {
        let caller_address = signer::address_of(caller);
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        assert!(caller_address == gateway.admin, E_UNAUTHORIZED);
        gateway.admin = new_admin;
        emit_snapshot(gateway);

        let registry = instances::borrow_registry_mut(@lottery);
        instances::set_admin(registry, new_admin);
        registry::set_admin(new_admin);
    }

    public entry fun create_lottery(
        caller: &signer,
        owner: address,
        ticket_price: u64,
        auto_draw_threshold: u64,
        jackpot_share_bps: u16,
    ) acquires
        GatewayRegistry,
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        let lottery_id = reserve_lottery_id(gateway);

        ticketing::create_lottery(
            caller,
            lottery_id,
            owner,
            ticket_price,
            auto_draw_threshold,
            jackpot_share_bps,
        );

        let (record_owner, _) = record_creation(gateway, lottery_id);
        registry::record_creation_from_instances(lottery_id);
        event::emit_event(
            &mut gateway.creation_events,
            LotteryCreatedEvent {
                lottery_id,
                owner: record_owner,
                ticket_price,
                auto_draw_threshold,
                jackpot_share_bps,
            },
        );
        history::record_created(caller, lottery_id);
        emit_snapshot(gateway);
    }

    public entry fun register_existing_lottery(caller: &signer, lottery_id: u64)
    acquires GatewayRegistry, instances::InstanceRegistry, registry::LotteryRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        register_imported_lottery(gateway, lottery_id);
        registry::record_creation_from_instances(lottery_id);
        emit_snapshot(gateway);
    }

    public entry fun register_existing_lotteries(caller: &signer, lottery_ids: vector<u64>)
    acquires GatewayRegistry, instances::InstanceRegistry, registry::LotteryRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        register_import_batch(gateway, &lottery_ids);
        normalize_next_lottery_id(gateway);
        emit_snapshot(gateway);
    }

    public entry fun align_next_lottery_id(caller: &signer, next_lottery_id: u64)
    acquires GatewayRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        align_counter(gateway, next_lottery_id);
        emit_snapshot(gateway);
    }

    public entry fun import_existing_lottery(caller: &signer, entry: LegacyGatewayLottery)
    acquires GatewayRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        upsert_imported_lottery(gateway, entry);
        normalize_next_lottery_id(gateway);
        emit_snapshot(gateway);
    }

    public entry fun import_existing_lotteries(caller: &signer, entries: vector<LegacyGatewayLottery>)
    acquires GatewayRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        import_lotteries_batch(gateway, &entries, vector::length(&entries));
        normalize_next_lottery_id(gateway);
        emit_snapshot(gateway);
    }

    public entry fun import_existing_gateway_registry(caller: &signer, payload: LegacyGatewayRegistry)
    acquires GatewayRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        reset_gateway_registry(gateway);
        gateway.admin = payload.admin;
        gateway.next_lottery_id = payload.next_lottery_id;
        import_lotteries_batch(gateway, &payload.lotteries, vector::length(&payload.lotteries));
        normalize_next_lottery_id(gateway);
        emit_snapshot(gateway);
    }

    public entry fun set_owner(caller: &signer, lottery_id: u64, new_owner: address)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        operators::OperatorRegistry,
        registry::LotteryRegistry
    {
        let previous_owner = current_owner(lottery_id);
        engine_operators::set_owner(caller, lottery_id, new_owner);
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        refresh_owner(gateway, lottery_id, option::some(previous_owner), new_owner);
        registry::sync_entry_from_instances(lottery_id);
        emit_snapshot(gateway);
    }

    public entry fun grant_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires GatewayRegistry, instances::InstanceRegistry, operators::OperatorRegistry {
        ensure_gateway_initialized();
        engine_operators::grant_operator(caller, lottery_id, operator);
    }

    public entry fun revoke_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires GatewayRegistry, instances::InstanceRegistry, operators::OperatorRegistry {
        ensure_gateway_initialized();
        engine_operators::revoke_operator(caller, lottery_id, operator);
    }

    public entry fun pause_lottery(caller: &signer, lottery_id: u64)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        operators::OperatorRegistry,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        lifecycle::pause_lottery(caller, lottery_id);
        sync_status(lottery_id);
        registry::sync_entry_from_instances(lottery_id);
    }

    public entry fun resume_lottery(caller: &signer, lottery_id: u64)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        operators::OperatorRegistry,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        lifecycle::resume_lottery(caller, lottery_id);
        sync_status(lottery_id);
        registry::sync_entry_from_instances(lottery_id);
    }

    public entry fun cancel_lottery(
        caller: &signer,
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
    ) acquires
        GatewayRegistry,
        cancellations::CancellationLedger,
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        cancellation::cancel_lottery(caller, lottery_id, reason_code, canceled_ts);
        sync_status(lottery_id);
        registry::record_cancellation(lottery_id, reason_code, canceled_ts);
        history::record_canceled(caller, lottery_id, reason_code);
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        emit_snapshot(gateway);
    }

    public entry fun record_existing_cancellation(
        caller: &signer,
        update: registry::LegacyCancellationImport,
    ) acquires
        GatewayRegistry,
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        apply_existing_cancellation(gateway, caller, update);
        emit_snapshot(gateway);
    }

    public entry fun record_existing_cancellations(
        caller: &signer,
        updates: vector<registry::LegacyCancellationImport>,
    ) acquires
        GatewayRegistry,
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        ensure_admin_signer(gateway, caller);
        record_existing_cancellation_batch(gateway, caller, &updates, vector::length(&updates));
        emit_snapshot(gateway);
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        draw::schedule_draw(caller, lottery_id);
        registry::sync_entry_from_instances(lottery_id);
    }

    public entry fun request_randomness(caller: &signer, lottery_id: u64, payload: vector<u8>)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        draw::request_randomness(caller, lottery_id, payload);
        registry::sync_entry_from_instances(lottery_id);
    }

    public entry fun enter_paid_round(
        caller: &signer,
        lottery_id: u64,
        ticket_count: u64,
        payment_amount: u64,
    ) acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        sales::enter_paid_round(caller, lottery_id, ticket_count, payment_amount);
    }

    fun ensure_admin_signer(gateway: &GatewayRegistry, caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == gateway.admin, E_UNAUTHORIZED);
    }

    fun apply_existing_cancellation(
        gateway: &mut GatewayRegistry,
        caller: &signer,
        update: registry::LegacyCancellationImport,
    ) acquires
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        registry::record_existing_cancellation(caller, update);
        sync_status(update.lottery_id);
        history::record_canceled(caller, update.lottery_id, update.reason_code);
    }

    fun record_existing_cancellation_batch(
        gateway: &mut GatewayRegistry,
        caller: &signer,
        updates: &vector<registry::LegacyCancellationImport>,
        remaining: u64,
    ) acquires
        history::LotteryHistory,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        registry::LotteryRegistry,
        rounds::RoundRegistry
    {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        record_existing_cancellation_batch(gateway, caller, updates, next_remaining);
        let update = *vector::borrow(updates, next_remaining);
        apply_existing_cancellation(gateway, caller, update);
    }

    fun reserve_lottery_id(gateway: &mut GatewayRegistry): u64 {
        let current = gateway.next_lottery_id;
        let next = current + 1;
        assert!(next > current, E_COUNTER_OVERFLOW);
        gateway.next_lottery_id = next;
        current
    }

    fun record_creation(gateway: &mut GatewayRegistry, lottery_id: u64): (address, bool)
    acquires instances::InstanceRegistry {
        let registry_view = instances::borrow_registry(@lottery);
        let record = instances::instance(registry_view, lottery_id);
        table::add(
            &mut gateway.lotteries,
            lottery_id,
            GatewayLottery { owner: record.owner, active: record.active },
        );
        vector::push_back(&mut gateway.lottery_ids, lottery_id);
        bump_next_lottery_id(gateway, lottery_id);
        ensure_owner_entry(gateway, record.owner);
        let owner_record = table::borrow_mut(&mut gateway.owner_index, record.owner);
        vector::push_back(&mut owner_record.lottery_ids, lottery_id);
        event::emit_event(
            &mut gateway.status_events,
            LotteryStatusUpdatedEvent { lottery_id, active: record.active },
        );
        (record.owner, record.active)
    }

    fun ensure_owner_entry(gateway: &mut GatewayRegistry, owner: address) {
        if (!table::contains(&gateway.owner_index, owner)) {
            table::add(
                &mut gateway.owner_index,
                owner,
                OwnerLotteries { lottery_ids: vector::empty<u64>() },
            );
        };
    }

    fun current_owner(lottery_id: u64): address
    acquires GatewayRegistry, instances::InstanceRegistry {
        let gateway = borrow_global<GatewayRegistry>(@lottery);
        assert!(table::contains(&gateway.lotteries, lottery_id), E_UNKNOWN_LOTTERY);
        let registry = instances::borrow_registry(@lottery);
        let record = instances::instance(registry, lottery_id);
        record.owner
    }

    fun refresh_owner(
        gateway: &mut GatewayRegistry,
        lottery_id: u64,
        previous: option::Option<address>,
        next: address,
    ) {
        if (!table::contains(&gateway.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };

        if (option::is_some(&previous)) {
            let prev_addr = *option::borrow(&previous);
            if (prev_addr == next) {
                let summary = table::borrow_mut(&mut gateway.lotteries, lottery_id);
                summary.owner = next;
                event::emit_event(
                    &mut gateway.owner_events,
                    LotteryOwnerUpdatedEvent { lottery_id, previous, next },
                );
                return;
            };
            if (table::contains(&gateway.owner_index, prev_addr)) {
                let record = table::borrow_mut(&mut gateway.owner_index, prev_addr);
                remove_lottery_id(&mut record.lottery_ids, lottery_id);
            };
        };

        ensure_owner_entry(gateway, next);
        let next_record = table::borrow_mut(&mut gateway.owner_index, next);
        vector::push_back(&mut next_record.lottery_ids, lottery_id);

        let summary = table::borrow_mut(&mut gateway.lotteries, lottery_id);
        summary.owner = next;
        event::emit_event(
            &mut gateway.owner_events,
            LotteryOwnerUpdatedEvent { lottery_id, previous, next },
        );
    }

    fun sync_status(lottery_id: u64)
    acquires GatewayRegistry, instances::InstanceRegistry {
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        if (!table::contains(&gateway.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY;
        };

        let registry = instances::borrow_registry(@lottery);
        let record = instances::instance(registry, lottery_id);
        let summary = table::borrow_mut(&mut gateway.lotteries, lottery_id);
        if (summary.active != record.active) {
            summary.active = record.active;
            event::emit_event(
                &mut gateway.status_events,
                LotteryStatusUpdatedEvent { lottery_id, active: record.active },
            );
        };
    }

    fun register_import_batch(gateway: &mut GatewayRegistry, source: &vector<u64>)
    acquires instances::InstanceRegistry, registry::LotteryRegistry {
        let len = vector::length(source);
        register_import_batch_inner(gateway, source, len);
    }

    fun register_import_batch_inner(
        gateway: &mut GatewayRegistry,
        source: &vector<u64>,
        remaining: u64,
    ) acquires instances::InstanceRegistry, registry::LotteryRegistry {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        register_import_batch_inner(gateway, source, next_remaining);
        let lottery_id = *vector::borrow(source, next_remaining);
        register_imported_lottery(gateway, lottery_id);
        registry::record_creation_from_instances(lottery_id);
    }

    fun register_imported_lottery(gateway: &mut GatewayRegistry, lottery_id: u64)
    acquires instances::InstanceRegistry {
        if (table::contains(&gateway.lotteries, lottery_id)) {
            abort E_LOTTERY_ALREADY_REGISTERED;
        };
        record_creation(gateway, lottery_id);
    }

    fun upsert_imported_lottery(gateway: &mut GatewayRegistry, entry: LegacyGatewayLottery) {
        let lottery_id = entry.lottery_id;
        if (table::contains(&gateway.lotteries, lottery_id)) {
            let summary = table::borrow_mut(&mut gateway.lotteries, lottery_id);
            let previous_owner = summary.owner;
            let previous_active = summary.active;
            add_lottery_id_if_missing(&mut gateway.lottery_ids, lottery_id);
            if (previous_owner != entry.owner) {
                if (table::contains(&gateway.owner_index, previous_owner)) {
                    let record = table::borrow_mut(&mut gateway.owner_index, previous_owner);
                    remove_lottery_id(&mut record.lottery_ids, lottery_id);
                };
                ensure_owner_entry(gateway, entry.owner);
                let next_record = table::borrow_mut(&mut gateway.owner_index, entry.owner);
                if (!contains_lottery_id(&next_record.lottery_ids, lottery_id, vector::length(&next_record.lottery_ids))) {
                    vector::push_back(&mut next_record.lottery_ids, lottery_id);
                };
                summary.owner = entry.owner;
                event::emit_event(
                    &mut gateway.owner_events,
                    LotteryOwnerUpdatedEvent {
                        lottery_id,
                        previous: option::some(previous_owner),
                        next: entry.owner,
                    },
                );
            };
            ensure_owner_entry(gateway, entry.owner);
            let current_record = table::borrow_mut(&mut gateway.owner_index, entry.owner);
            if (!contains_lottery_id(&current_record.lottery_ids, lottery_id, vector::length(&current_record.lottery_ids))) {
                vector::push_back(&mut current_record.lottery_ids, lottery_id);
            };
            if (previous_active != entry.active) {
                summary.active = entry.active;
                event::emit_event(
                    &mut gateway.status_events,
                    LotteryStatusUpdatedEvent { lottery_id, active: entry.active },
                );
            };
            bump_next_lottery_id(gateway, lottery_id);
            return;
        };

        table::add(
            &mut gateway.lotteries,
            lottery_id,
            GatewayLottery { owner: entry.owner, active: entry.active },
        );
        add_lottery_id_if_missing(&mut gateway.lottery_ids, lottery_id);
        bump_next_lottery_id(gateway, lottery_id);
        ensure_owner_entry(gateway, entry.owner);
        let owner_record = table::borrow_mut(&mut gateway.owner_index, entry.owner);
        if (!contains_lottery_id(&owner_record.lottery_ids, lottery_id, vector::length(&owner_record.lottery_ids))) {
            vector::push_back(&mut owner_record.lottery_ids, lottery_id);
        };
        event::emit_event(
            &mut gateway.owner_events,
            LotteryOwnerUpdatedEvent { lottery_id, previous: option::none<address>(), next: entry.owner },
        );
        event::emit_event(
            &mut gateway.status_events,
            LotteryStatusUpdatedEvent { lottery_id, active: entry.active },
        );
        event::emit_event(
            &mut gateway.creation_events,
            LotteryCreatedEvent {
                lottery_id,
                owner: entry.owner,
                ticket_price: entry.ticket_price,
                auto_draw_threshold: entry.auto_draw_threshold,
                jackpot_share_bps: entry.jackpot_share_bps,
            },
        );
    }

    fun import_lotteries_batch(
        gateway: &mut GatewayRegistry,
        entries: &vector<LegacyGatewayLottery>,
        remaining: u64,
    ) {
        if (remaining == 0) {
            return;
        };
        let next_remaining = remaining - 1;
        import_lotteries_batch(gateway, entries, next_remaining);
        let entry = *vector::borrow(entries, next_remaining);
        upsert_imported_lottery(gateway, entry);
    }

    fun reset_gateway_registry(gateway: &mut GatewayRegistry) {
        gateway.lotteries = table::new<u64, GatewayLottery>();
        gateway.owner_index = table::new<address, OwnerLotteries>();
        gateway.lottery_ids = vector::empty<u64>();
        gateway.next_lottery_id = 1;
    }

    fun align_counter(gateway: &mut GatewayRegistry, next_lottery_id: u64) {
        let current_next = gateway.next_lottery_id;
        if (next_lottery_id <= current_next) {
            abort E_INVALID_COUNTER_TARGET;
        };
        let highest = max_lottery_id(&gateway.lottery_ids);
        if (highest >= next_lottery_id) {
            abort E_INVALID_COUNTER_TARGET;
        };
        gateway.next_lottery_id = next_lottery_id;
    }

    fun normalize_next_lottery_id(gateway: &mut GatewayRegistry) {
        let highest = max_lottery_id(&gateway.lottery_ids);
        let required_next = highest + 1;
        if (gateway.next_lottery_id < required_next) {
            gateway.next_lottery_id = required_next;
        };
    }

    fun bump_next_lottery_id(gateway: &mut GatewayRegistry, lottery_id: u64) {
        let required_next = lottery_id + 1;
        if (gateway.next_lottery_id < required_next) {
            gateway.next_lottery_id = required_next;
        };
    }

    fun remove_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        remove_lottery_id_inner(ids, lottery_id, vector::length(ids));
    }

    fun remove_lottery_id_inner(ids: &mut vector<u64>, lottery_id: u64, remaining: u64) {
        if (remaining == 0) {
            return;
        };
        let index = remaining - 1;
        if (*vector::borrow(ids, index) == lottery_id) {
            vector::swap_remove(ids, index);
            return;
        };
        remove_lottery_id_inner(ids, lottery_id, index);
    }

    fun emit_snapshot(gateway: &mut GatewayRegistry) {
        let total = vector::length(&gateway.lottery_ids);
        event::emit_event(
            &mut gateway.snapshot_events,
            GatewaySnapshotEvent {
                admin: gateway.admin,
                next_lottery_id: gateway.next_lottery_id,
                total_lotteries: total,
            },
        );
    }

    fun ensure_gateway_initialized() acquires GatewayRegistry {
        if (!exists<GatewayRegistry>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun clone_u64_vector(source: &vector<u64>): vector<u64> {
        let len = vector::length(source);
        clone_u64_vector_inner(source, len)
    }

    fun clone_u64_vector_inner(source: &vector<u64>, remaining: u64): vector<u64> {
        if (remaining == 0) {
            return vector::empty<u64>();
        };
        let next_remaining = remaining - 1;
        let result = clone_u64_vector_inner(source, next_remaining);
        let value = *vector::borrow(source, next_remaining);
        vector::push_back(&mut result, value);
        result
    }

    fun add_lottery_id_if_missing(ids: &mut vector<u64>, lottery_id: u64) {
        if (!contains_lottery_id(ids, lottery_id, vector::length(ids))) {
            vector::push_back(ids, lottery_id);
        };
    }

    fun contains_lottery_id(ids: &vector<u64>, lottery_id: u64, remaining: u64): bool {
        if (remaining == 0) {
            return false;
        };
        let next_remaining = remaining - 1;
        let value = *vector::borrow(ids, next_remaining);
        if (value == lottery_id) {
            true
        } else {
            contains_lottery_id(ids, lottery_id, next_remaining)
        }
    }

    fun max_lottery_id(ids: &vector<u64>): u64 {
        let len = vector::length(ids);
        max_lottery_id_inner(ids, len)
    }

    fun max_lottery_id_inner(ids: &vector<u64>, remaining: u64): u64 {
        if (remaining == 0) {
            return 0;
        };
        let next_remaining = remaining - 1;
        let best = max_lottery_id_inner(ids, next_remaining);
        let value = *vector::borrow(ids, next_remaining);
        if (value > best) {
            value
        } else {
            best
        }
    }
}
