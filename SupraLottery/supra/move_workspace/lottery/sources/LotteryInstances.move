module lottery::instances {
    friend lottery::migration;
    friend lottery::rounds;

    use std::option;
    use std::signer;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;
    use std::vector;
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
        snapshot_events: event::EventHandle<LotteryInstancesSnapshotUpdatedEvent>,
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

    struct LotteryInstanceSnapshot has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }

    struct LotteryInstancesSnapshot has copy, drop, store {
        admin: address,
        hub: address,
        instances: vector<LotteryInstanceSnapshot>,
    }

    #[event]
    struct LotteryInstancesSnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        hub: address,
        snapshot: LotteryInstanceSnapshot,
    }


    public entry fun init(caller: &signer, hub: address) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<LotteryCollection>(@lottery)) {
            abort E_ALREADY_INIT
        };
        move_to(
            caller,
            LotteryCollection {
                admin: addr,
                hub,
                instances: table::new(),
                lottery_ids: vector::empty<u64>(),
                create_events: account::new_event_handle<LotteryInstanceCreatedEvent>(caller),
                blueprint_events: account::new_event_handle<LotteryInstanceBlueprintSyncedEvent>(caller),
                admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
                hub_events: account::new_event_handle<HubAddressUpdatedEvent>(caller),
                status_events: account::new_event_handle<LotteryInstanceStatusUpdatedEvent>(caller),
                snapshot_events: account::new_event_handle<LotteryInstancesSnapshotUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        emit_all_snapshots(state);
    }


    #[view]
    public fun is_initialized(): bool {
        exists<LotteryCollection>(@lottery)
    }


    #[view]
    public fun hub_address(): address acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        state.hub
    }


    #[view]
    public fun admin(): address acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        state.admin
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        let previous = state.admin;
        state.admin = new_admin;
        event::emit_event(&mut state.admin_events, AdminUpdatedEvent { previous, next: new_admin });
        emit_all_snapshots(state);
    }


    public entry fun set_hub(caller: &signer, new_hub: address) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        let previous = state.hub;
        state.hub = new_hub;
        event::emit_event(&mut state.hub_events, HubAddressUpdatedEvent { previous, next: new_hub });
        emit_all_snapshots(state);
    }


    public entry fun set_instance_active(caller: &signer, lottery_id: u64, active: bool)
    acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE
        };
        let hub_active = hub::is_lottery_active(lottery_id);
        if (hub_active != active) {
            abort E_STATUS_MISMATCH
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        if (instance.active != active) {
            instance.active = active;
            event::emit_event(&mut state.status_events, LotteryInstanceStatusUpdatedEvent { lottery_id, active });
        };
        emit_instance_snapshot(state, lottery_id);
    }


    public entry fun create_instance(caller: &signer, lottery_id: u64) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (table::contains(&state.instances, lottery_id)) {
            abort E_INSTANCE_EXISTS
        };

        let registration_opt = hub::get_registration(lottery_id);
        if (!option::is_some(&registration_opt)) {
            abort E_REGISTRATION_INACTIVE
        };
        let registration_ref = option::borrow(&registration_opt);
        let reg_owner = hub::registration_owner(registration_ref);
        let reg_lottery = hub::registration_lottery(registration_ref);
        let active = hub::registration_active(registration_ref);
        if (!active) {
            abort E_REGISTRATION_INACTIVE
        };

        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_FACTORY_INFO_MISSING
        };
        let info_ref = option::borrow(&info_opt);
        let owner = registry::lottery_info_owner(info_ref);
        let lottery_addr = registry::lottery_info_lottery(info_ref);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        if (owner != reg_owner || lottery_addr != reg_lottery) {
            abort E_REGISTRATION_MISMATCH
        };
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);

        table::add(
            &mut state.instances,
            lottery_id,
            InstanceState {
                info: registry::make_lottery_info(owner, lottery_addr, blueprint),
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
        emit_instance_snapshot(state, lottery_id);
    }


    public entry fun sync_blueprint(caller: &signer, lottery_id: u64) acquires LotteryCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE
        };

        let info_opt = registry::get_lottery(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_FACTORY_INFO_MISSING
        };
        let info_ref = option::borrow(&info_opt);
        let owner = registry::lottery_info_owner(info_ref);
        let lottery_addr = registry::lottery_info_lottery(info_ref);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);

        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.info = registry::make_lottery_info(owner, lottery_addr, blueprint);

        event::emit_event(
            &mut state.blueprint_events,
            LotteryInstanceBlueprintSyncedEvent { lottery_id, ticket_price, jackpot_share_bps },
        );
        emit_instance_snapshot(state, lottery_id);
    }


    #[view]
    public fun instance_count(): u64 acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        table::length(&state.instances)
    }


    #[view]
    public fun contains_instance(lottery_id: u64): bool acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        table::contains(&state.instances, lottery_id)
    }


    #[view]
    public fun get_lottery_info(lottery_id: u64): option::Option<registry::LotteryInfo> acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            option::none()
        } else {
            let instance = table::borrow(&state.instances, lottery_id);
            option::some(instance.info)
        }
    }


    #[view]
    public fun get_instance_stats(lottery_id: u64): option::Option<InstanceStats> acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            option::none()
        } else {
            let instance = table::borrow(&state.instances, lottery_id);
            option::some(InstanceStats {
                tickets_sold: instance.tickets_sold,
                jackpot_accumulated: instance.jackpot_accumulated,
                active: instance.active,
            })
        }
    }


    #[view]
    public fun list_lottery_ids(): vector<u64> acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
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


    #[view]
    public fun list_active_lottery_ids(): vector<u64> acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
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


    #[view]
    public fun is_instance_active(lottery_id: u64): bool acquires LotteryCollection {
        ensure_initialized();
        let state = borrow_global<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            false
        } else {
            table::borrow(&state.instances, lottery_id).active
        }
    }


    #[view]
    public fun get_instance_snapshot(lottery_id: u64): option::Option<LotteryInstanceSnapshot>
    acquires LotteryCollection {
        if (!exists<LotteryCollection>(@lottery)) {
            return option::none<LotteryInstanceSnapshot>()
        };
        let state = borrow_global<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            return option::none<LotteryInstanceSnapshot>()
        };
        option::some(build_instance_snapshot(state, lottery_id))
    }


    #[view]
    public fun get_instances_snapshot(): option::Option<LotteryInstancesSnapshot>
    acquires LotteryCollection {
        if (!exists<LotteryCollection>(@lottery)) {
            return option::none<LotteryInstancesSnapshot>()
        };
        let state = borrow_global<LotteryCollection>(@lottery);
        option::some(build_instances_snapshot(state))
    }


    public(friend) fun record_ticket_sale(lottery_id: u64, jackpot_contribution: u64) acquires LotteryCollection {
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.tickets_sold = instance.tickets_sold + 1;
        instance.jackpot_accumulated = instance.jackpot_accumulated + jackpot_contribution;
        emit_instance_snapshot(state, lottery_id);
    }


    public(friend) fun migrate_override_stats(
        lottery_id: u64,
        tickets_sold: u64,
        jackpot_accumulated: u64,
    ) acquires LotteryCollection {
        let state = borrow_global_mut<LotteryCollection>(@lottery);
        if (!table::contains(&state.instances, lottery_id)) {
            abort E_UNKNOWN_INSTANCE
        };
        let instance = table::borrow_mut(&mut state.instances, lottery_id);
        instance.tickets_sold = tickets_sold;
        instance.jackpot_accumulated = jackpot_accumulated;
        emit_instance_snapshot(state, lottery_id);
    }

    fun ensure_admin(caller: &signer) acquires LotteryCollection {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<LotteryCollection>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_initialized() {
        if (!exists<LotteryCollection>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    #[test_only]
    public fun instance_stats_for_test(stats: &InstanceStats): (u64, u64, bool) {
        (stats.tickets_sold, stats.jackpot_accumulated, stats.active)
    }

    #[test_only]
    public fun instance_snapshot_fields_for_test(
        snapshot: &LotteryInstanceSnapshot,
    ): (u64, address, address, u64, u16, u64, u64, bool) {
        (
            snapshot.lottery_id,
            snapshot.owner,
            snapshot.lottery,
            snapshot.ticket_price,
            snapshot.jackpot_share_bps,
            snapshot.tickets_sold,
            snapshot.jackpot_accumulated,
            snapshot.active,
        )
    }

    #[test_only]
    public fun instances_snapshot_fields_for_test(
        snapshot: &LotteryInstancesSnapshot,
    ): (address, address, vector<LotteryInstanceSnapshot>) {
        (snapshot.admin, snapshot.hub, copy_instance_snapshots(&snapshot.instances))
    }

    #[test_only]
    public fun snapshot_event_fields_for_test(
        event: &LotteryInstancesSnapshotUpdatedEvent,
    ): (address, address, LotteryInstanceSnapshot) {
        (event.admin, event.hub, event.snapshot)
    }

    fun emit_instance_snapshot(state: &mut LotteryCollection, lottery_id: u64) {
        if (!table::contains(&state.instances, lottery_id)) {
            return
        };
        let snapshot = build_instance_snapshot_from_mut(state, lottery_id);
        event::emit_event(
            &mut state.snapshot_events,
            LotteryInstancesSnapshotUpdatedEvent { admin: state.admin, hub: state.hub, snapshot },
        );
    }

    fun emit_all_snapshots(state: &mut LotteryCollection) {
        let len = vector::length(&state.lottery_ids);
        let i = 0;
        while (i < len) {
            let id = *vector::borrow(&state.lottery_ids, i);
            if (table::contains(&state.instances, id)) {
                emit_instance_snapshot(state, id);
            };
            i = i + 1;
        };
    }

    fun build_instance_snapshot_from_mut(
        state: &mut LotteryCollection,
        lottery_id: u64,
    ): LotteryInstanceSnapshot {
        build_instance_snapshot_from_table(&state.instances, lottery_id)
    }

    fun build_instance_snapshot(state: &LotteryCollection, lottery_id: u64): LotteryInstanceSnapshot {
        build_instance_snapshot_from_table(&state.instances, lottery_id)
    }

    fun build_instance_snapshot_from_table(
        instances: &table::Table<u64, LotteryInstance>,
        lottery_id: u64,
    ): LotteryInstanceSnapshot {
        let instance = table::borrow(instances, lottery_id);
        let info_ref = &instance.info;
        let owner = registry::lottery_info_owner(info_ref);
        let lottery_addr = registry::lottery_info_lottery(info_ref);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);
        LotteryInstanceSnapshot {
            lottery_id,
            owner,
            lottery: lottery_addr,
            ticket_price,
            jackpot_share_bps,
            tickets_sold: instance.tickets_sold,
            jackpot_accumulated: instance.jackpot_accumulated,
            active: instance.active,
        }
    }

    fun build_instances_snapshot(state: &LotteryCollection): LotteryInstancesSnapshot {
        LotteryInstancesSnapshot {
            admin: state.admin,
            hub: state.hub,
            instances: collect_instance_snapshots(state),
        }
    }

    fun collect_instance_snapshots(state: &LotteryCollection): vector<LotteryInstanceSnapshot> {
        let snapshots = vector::empty<LotteryInstanceSnapshot>();
        let len = vector::length(&state.lottery_ids);
        let i = 0;
        while (i < len) {
            let id = *vector::borrow(&state.lottery_ids, i);
            if (table::contains(&state.instances, id)) {
                let snapshot = build_instance_snapshot(state, id);
                vector::push_back(&mut snapshots, snapshot);
            };
            i = i + 1;
        };
        snapshots
    }

    fun copy_instance_snapshots(values: &vector<LotteryInstanceSnapshot>): vector<LotteryInstanceSnapshot> {
        let out = vector::empty<LotteryInstanceSnapshot>();
        let len = vector::length(values);
        let i = 0;
        while (i < len) {
            let snapshot = *vector::borrow(values, i);
            vector::push_back(&mut out, snapshot);
            i = i + 1;
        };
        out
    }
}
