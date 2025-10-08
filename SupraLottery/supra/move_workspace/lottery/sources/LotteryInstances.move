module lottery::instances {
    friend lottery::migration;
    friend lottery::rounds;
    use std::option;
    use std::signer;
    use vrf_hub::table;
    use std::event;
    use std::math64;
    use lottery_factory::registry;
    use vrf_hub::hub;


    const E_ALREADY_INIT: u64 = 1;

    const E_NOT_INITIALIZED: u64 = 2;

    const E_NOT_AUTHORIZED: u64 = 3;

    const E_INSTANCE_EXISTS: u64 = 4;

    const E_UNKNOWN_INSTANCE: u64 = 5;

    const E_FACTORY_INFO_MISSING: u64 = 6;

    const E_REGISTRATION_INACTIVE: u64 = 7;

    const E_REGISTRATION_MISMATCH: u64 = 8;

    const E_STATUS_MISMATCH: u64 = 9;


    struct InstanceStats has copy, drop, store {
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }


    struct InstanceState has store {
        info: registry::LotteryInfo,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }


    struct LotteryCollection has key {
        admin: address,
        hub: address,
        instances: table::Table<u64, InstanceState>,
        lottery_ids: vector<u64>,
        create_events: event::EventHandle<LotteryInstanceCreatedEvent>,
        blueprint_events: event::EventHandle<LotteryInstanceBlueprintSyncedEvent>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        hub_events: event::EventHandle<HubAddressUpdatedEvent>,
        status_events: event::EventHandle<LotteryInstanceStatusUpdatedEvent>,
    }

    #[event]
    struct LotteryInstanceCreatedEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
        lottery: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
    }

    #[event]
    struct LotteryInstanceBlueprintSyncedEvent has drop, store, copy {
        lottery_id: u64,
        ticket_price: u64,
        jackpot_share_bps: u16,
    }

    #[event]
    struct AdminUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    #[event]
    struct HubAddressUpdatedEvent has drop, store, copy {
        previous: address,
        next: address,
    }

    #[event]
    struct LotteryInstanceStatusUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        active: bool,
    }


    public entry fun init(caller: &signer, hub: address) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
        if (exists<LotteryCollection>(@lottery)) {
            abort E_ALREADY_INIT;
        };
        move_to(
            caller,
            LotteryCollection {
                admin: addr,
                hub,
                instances: table::new(),
                lottery_ids: vector::empty<u64>(),
                create_events: event::new_event_handle<LotteryInstanceCreatedEvent>(caller),
                blueprint_events: event::new_event_handle<LotteryInstanceBlueprintSyncedEvent>(caller),
                admin_events: event::new_event_handle<AdminUpdatedEvent>(caller),
                hub_events: event::new_event_handle<HubAddressUpdatedEvent>(caller),
                status_events: event::new_event_handle<LotteryInstanceStatusUpdatedEvent>(caller),
            },
        );
    }


    public fun is_initialized(): bool {
        exists<LotteryCollection>(@lottery)
    }


    public fun hub_address(): address acquires LotteryCollection {
        borrow_state().hub
    }


    public fun admin(): address acquires LotteryCollection {
        borrow_state().admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
    }


    public entry fun set_hub(caller: &signer, new_hub: address) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        let previous = state.hub;
        state.hub = new_hub;
        event::emit_event(&mut state.hub_events, HubAddressUpdatedEvent { previous, next: new_hub });
    }


    public entry fun set_instance_active(caller: &signer, lottery_id: u64, active: bool)
    acquires LotteryCollection, hub::HubState {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE;
        };
        let hub_active = hub::is_lottery_active(lottery_id);
        if (hub_active != active) {
            abort E_STATUS_MISMATCH;
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        if (instance.active != active) {
            instance.active = active;
            event::emit_event(&mut state.status_events, LotteryInstanceStatusUpdatedEvent { lottery_id, active });
        };
    }


    public entry fun create_instance(caller: &signer, lottery_id: u64) acquires LotteryCollection, hub::HubState, registry::FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (table::contains(&state.instances, lottery_id)) {
            abort E_INSTANCE_EXISTS;
        };

        let registration_opt = hub::get_registration(lottery_id);
        if (!option::is_some(&registration_opt)) {
            abort E_REGISTRATION_INACTIVE;
        };
        let registration = option::extract(registration_opt);
        let reg_owner = registration.owner;
        let reg_lottery = registration.lottery;
        let active = registration.active;
        if (!active) {
            abort E_REGISTRATION_INACTIVE;
        };

        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_FACTORY_INFO_MISSING;
        };
        let info = option::extract(info_opt);
        let owner = info.owner;
        let lottery_addr = info.lottery;
        let blueprint = info.blueprint;
        if (owner != reg_owner || lottery_addr != reg_lottery) {
            abort E_REGISTRATION_MISMATCH;
        };
        let ticket_price = blueprint.ticket_price;
        let jackpot_share_bps = blueprint.jackpot_share_bps;

        table::add(
            &mut state.instances,
            lottery_id,
            InstanceState {
                info: registry::LotteryInfo {
                    owner,
                    lottery: lottery_addr,
                    blueprint: registry::LotteryBlueprint { ticket_price, jackpot_share_bps },
                },
                tickets_sold: 0,
                jackpot_accumulated: 0,
                active: true,
            },
        );
        vector::push_back(&mut state.lottery_ids, lottery_id);

        event::emit_event(
            &mut state.create_events,
            LotteryInstanceCreatedEvent { lottery_id, owner, lottery: lottery_addr, ticket_price, jackpot_share_bps },
        );
        event::emit_event(&mut state.status_events, LotteryInstanceStatusUpdatedEvent { lottery_id, active: true });
    }


    public entry fun sync_blueprint(caller: &signer, lottery_id: u64) acquires LotteryCollection, registry::FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE;
        };

        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_FACTORY_INFO_MISSING;
        };
        let info_sync = option::extract(info_opt);
        let owner = info_sync.owner;
        let lottery_addr = info_sync.lottery;
        let blueprint = info_sync.blueprint;
        let ticket_price = blueprint.ticket_price;
        let jackpot_share_bps = blueprint.jackpot_share_bps;

        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.info = registry::LotteryInfo {
            owner,
            lottery: lottery_addr,
            blueprint: registry::LotteryBlueprint { ticket_price, jackpot_share_bps },
        };

        event::emit_event(
            &mut state.blueprint_events,
            LotteryInstanceBlueprintSyncedEvent { lottery_id, ticket_price, jackpot_share_bps },
        );
    }


    public fun instance_count(): u64 acquires LotteryCollection {
        table::length(&borrow_state().instances)
    }


    public fun contains_instance(lottery_id: u64): bool acquires LotteryCollection {
        table::contains(&borrow_state().instances, lottery_id)
    }


    public fun get_lottery_info(lottery_id: u64): option::Option<registry::LotteryInfo> acquires LotteryCollection {
        let state = borrow_state();
        if (!table::contains(&state.instances, lottery_id)) {
            option::none()
        } else {
            let instance = table::borrow(&state.instances, lottery_id);
            option::some(instance.info)
        };
    }


    public fun get_instance_stats(lottery_id: u64): option::Option<InstanceStats> acquires LotteryCollection {
        let state = borrow_state();
        if (!table::contains(&state.instances, lottery_id)) {
            option::none()
        } else {
            let instance = table::borrow(&state.instances, lottery_id);
            option::some(InstanceStats {
                tickets_sold: instance.tickets_sold,
                jackpot_accumulated: instance.jackpot_accumulated,
                active: instance.active,
            })
        };
    }


    public fun list_lottery_ids(): vector<u64> acquires LotteryCollection {
        let state = borrow_state();
        let len = vector::length(&state.lottery_ids);
        let result = vector::empty<u64>();
        let i = 0;
        while (i < len) {
            let id = *vector::borrow(&state.lottery_ids, i);
            vector::push_back(&mut result, id);
            i = i + 1;
        };
        result
    }


    public fun list_active_lottery_ids(): vector<u64> acquires LotteryCollection {
        let state = borrow_state();
        let len = vector::length(&state.lottery_ids);
        let result = vector::empty<u64>();
        let i = 0;
        while (i < len) {
            let id = *vector::borrow(&state.lottery_ids, i);
            if (table::contains(&state.instances, id)) {
                let instance = table::borrow(&state.instances, id);
                if (instance.active) {
                    vector::push_back(&mut result, id);
                };
            };
            i = i + 1;
        };
        result
    }


    public fun is_instance_active(lottery_id: u64): bool acquires LotteryCollection {
        let state = borrow_state();
        if (!table::contains(&state.instances, lottery_id)) {
            false
        } else {
            table::borrow(&state.instances, lottery_id).active
        };
    }


    public(friend) fun record_ticket_sale(lottery_id: u64, jackpot_contribution: u64) acquires LotteryCollection {
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE;
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.tickets_sold = math64::checked_add(instance.tickets_sold, 1);
        instance.jackpot_accumulated = math64::checked_add(instance.jackpot_accumulated, jackpot_contribution);
    }


    public(friend) fun migrate_override_stats(
        lottery_id: u64,
        tickets_sold: u64,
        jackpot_accumulated: u64,
    ) acquires LotteryCollection {
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE;
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.tickets_sold = tickets_sold;
        instance.jackpot_accumulated = jackpot_accumulated;
    }

    fun borrow_state(): &LotteryCollection acquires LotteryCollection {
        if (!exists<LotteryCollection>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
        borrow_global<LotteryCollection>(@lottery)
    }

    fun ensure_admin(caller: &signer) acquires LotteryCollection {
        let addr = signer::address_of(caller);
        if (addr != borrow_state().admin) {
            abort E_NOT_AUTHORIZED;
        };
    }
}
