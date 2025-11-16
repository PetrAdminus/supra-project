module lottery_data::instances {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_INSTANCE_EXISTS: u64 = 3;
    const E_UNKNOWN_INSTANCE: u64 = 4;
    const E_EXPORT_CAP_OCCUPIED: u64 = 5;

    public struct LegacyInstanceRecord has drop, store {
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }

    struct InstanceRecord has store {
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }

    struct InstanceSnapshot has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery_address: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        tickets_sold: u64,
        jackpot_accumulated: u64,
        active: bool,
    }

    struct InstanceControl has key {
        admin: address,
        export_cap: option::Option<InstancesExportCap>,
    }

    struct InstancesExportCap has store {}

    #[event]
    struct LotteryInstanceCreatedEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
        lottery_address: address,
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

    #[event]
    struct LotteryInstanceOwnerUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        previous: option::Option<address>,
        next: address,
    }

    #[event]
    struct LotteryInstancesSnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        hub: address,
        snapshot: InstanceSnapshot,
    }

    struct InstanceRegistry has key {
        admin: address,
        hub: address,
        instances: table::Table<u64, InstanceRecord>,
        lottery_ids: vector<u64>,
        create_events: event::EventHandle<LotteryInstanceCreatedEvent>,
        blueprint_events: event::EventHandle<LotteryInstanceBlueprintSyncedEvent>,
        admin_events: event::EventHandle<AdminUpdatedEvent>,
        hub_events: event::EventHandle<HubAddressUpdatedEvent>,
        status_events: event::EventHandle<LotteryInstanceStatusUpdatedEvent>,
        owner_events: event::EventHandle<LotteryInstanceOwnerUpdatedEvent>,
        snapshot_events: event::EventHandle<LotteryInstancesSnapshotUpdatedEvent>,
    }

    public entry fun import_existing_instance(caller: &signer, record: LegacyInstanceRecord)
    acquires InstanceRegistry {
        ensure_admin(caller);
        upsert_legacy_instance(record);
    }

    public entry fun import_existing_instances(caller: &signer, mut records: vector<LegacyInstanceRecord>)
    acquires InstanceRegistry {
        ensure_admin(caller);
        import_existing_instances_recursive(&mut records);
    }

    public entry fun init_registry(caller: &signer, hub: address) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<InstanceRegistry>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            InstanceRegistry {
                admin: caller_address,
                hub,
                instances: table::new<u64, InstanceRecord>(),
                lottery_ids: vector::empty<u64>(),
                create_events: account::new_event_handle<LotteryInstanceCreatedEvent>(caller),
                blueprint_events: account::new_event_handle<LotteryInstanceBlueprintSyncedEvent>(caller),
                admin_events: account::new_event_handle<AdminUpdatedEvent>(caller),
                hub_events: account::new_event_handle<HubAddressUpdatedEvent>(caller),
                status_events: account::new_event_handle<LotteryInstanceStatusUpdatedEvent>(caller),
                owner_events: account::new_event_handle<LotteryInstanceOwnerUpdatedEvent>(caller),
                snapshot_events: account::new_event_handle<LotteryInstancesSnapshotUpdatedEvent>(caller),
            },
        );
    }

    public entry fun init_control(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<InstanceControl>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            InstanceControl {
                admin: caller_address,
                export_cap: option::some(InstancesExportCap {}),
            },
        );
    }

    public fun borrow_registry(addr: address): &InstanceRegistry acquires InstanceRegistry {
        borrow_global<InstanceRegistry>(addr)
    }

    public fun borrow_registry_mut(addr: address): &mut InstanceRegistry acquires InstanceRegistry {
        borrow_global_mut<InstanceRegistry>(addr)
    }

    public fun borrow_control(addr: address): &InstanceControl acquires InstanceControl {
        borrow_global<InstanceControl>(addr)
    }

    public fun borrow_control_mut(addr: address): &mut InstanceControl acquires InstanceControl {
        borrow_global_mut<InstanceControl>(addr)
    }

    public fun export_cap_available(control: &InstanceControl): bool {
        option::is_some(&control.export_cap)
    }

    public fun extract_export_cap(control: &mut InstanceControl): option::Option<InstancesExportCap> {
        if (!option::is_some(&control.export_cap)) {
            return option::none<InstancesExportCap>();
        };
        let cap = option::extract(&mut control.export_cap);
        option::some(cap)
    }

    public fun restore_export_cap(control: &mut InstanceControl, cap: InstancesExportCap) {
        if (option::is_some(&control.export_cap)) {
            abort E_EXPORT_CAP_OCCUPIED;
        };
        option::fill(&mut control.export_cap, cap);
    }

    public fun migrate_override_stats(
        _cap: &InstancesExportCap,
        registry: &mut InstanceRegistry,
        lottery_id: u64,
        tickets_sold: u64,
        jackpot_accumulated: u64,
    ) {
        let record = instance_mut(registry, lottery_id);
        record.tickets_sold = tickets_sold;
        record.jackpot_accumulated = jackpot_accumulated;
        emit_snapshot(registry, lottery_id);
    }

    public fun register_instance(registry: &mut InstanceRegistry, lottery_id: u64, record: InstanceRecord) {
        assert!(!table::contains(&registry.instances, lottery_id), E_INSTANCE_EXISTS);
        table::add(&mut registry.instances, lottery_id, record);
        vector::push_back(&mut registry.lottery_ids, lottery_id);
    }

    public fun instance(registry: &InstanceRegistry, lottery_id: u64): &InstanceRecord {
        assert!(table::contains(&registry.instances, lottery_id), E_UNKNOWN_INSTANCE);
        table::borrow(&registry.instances, lottery_id)
    }

    public fun contains(registry: &InstanceRegistry, lottery_id: u64): bool {
        table::contains(&registry.instances, lottery_id)
    }

    public fun instance_mut(registry: &mut InstanceRegistry, lottery_id: u64): &mut InstanceRecord {
        assert!(table::contains(&registry.instances, lottery_id), E_UNKNOWN_INSTANCE);
        table::borrow_mut(&mut registry.instances, lottery_id)
    }

    public fun is_active(registry: &InstanceRegistry, lottery_id: u64): bool {
        let record = instance(registry, lottery_id);
        record.active
    }

    public fun set_active(
        registry: &mut InstanceRegistry,
        lottery_id: u64,
        active: bool,
    ): bool {
        let record = instance_mut(registry, lottery_id);
        if (record.active == active) {
            return false;
        };
        record.active = active;
        emit_status(registry, lottery_id, active);
        true
    }

    public fun set_admin(registry: &mut InstanceRegistry, new_admin: address) {
        let previous = registry.admin;
        registry.admin = new_admin;
        event::emit_event(&mut registry.admin_events, AdminUpdatedEvent { previous, next: new_admin });
    }

    public fun set_hub(registry: &mut InstanceRegistry, new_hub: address) {
        let previous = registry.hub;
        registry.hub = new_hub;
        event::emit_event(&mut registry.hub_events, HubAddressUpdatedEvent { previous, next: new_hub });
    }

    public fun emit_status(registry: &mut InstanceRegistry, lottery_id: u64, active: bool) {
        event::emit_event(
            &mut registry.status_events,
            LotteryInstanceStatusUpdatedEvent { lottery_id, active },
        );
    }

    public fun emit_creation(registry: &mut InstanceRegistry, lottery_id: u64, record: &InstanceRecord) {
        event::emit_event(
            &mut registry.create_events,
            LotteryInstanceCreatedEvent {
                lottery_id,
                owner: record.owner,
                lottery_address: record.lottery_address,
                ticket_price: record.ticket_price,
                jackpot_share_bps: record.jackpot_share_bps,
            },
        );
    }

    public fun emit_blueprint(registry: &mut InstanceRegistry, lottery_id: u64, ticket_price: u64, jackpot_share_bps: u16) {
        event::emit_event(
            &mut registry.blueprint_events,
            LotteryInstanceBlueprintSyncedEvent { lottery_id, ticket_price, jackpot_share_bps },
        );
    }

    public fun emit_owner_record(
        registry: &mut InstanceRegistry,
        lottery_id: u64,
        previous: option::Option<address>,
        next: address,
    ) {
        event::emit_event(
            &mut registry.owner_events,
            LotteryInstanceOwnerUpdatedEvent { lottery_id, previous, next },
        );
    }

    public fun update_jackpot_share(registry: &mut InstanceRegistry, lottery_id: u64, jackpot_share_bps: u16) {
        let record = instance_mut(registry, lottery_id);
        if (record.jackpot_share_bps == jackpot_share_bps) {
            return;
        };
        record.jackpot_share_bps = jackpot_share_bps;
        emit_blueprint(registry, lottery_id, record.ticket_price, jackpot_share_bps);
    }

    public fun set_owner(registry: &mut InstanceRegistry, lottery_id: u64, new_owner: address): address {
        let record = instance_mut(registry, lottery_id);
        let previous = record.owner;
        record.owner = new_owner;
        emit_owner_record(registry, lottery_id, option::some(previous), new_owner);
        previous
    }

    public fun emit_snapshot(registry: &mut InstanceRegistry, lottery_id: u64) {
        let record = instance(registry, lottery_id);
        event::emit_event(
            &mut registry.snapshot_events,
            LotteryInstancesSnapshotUpdatedEvent {
                admin: registry.admin,
                hub: registry.hub,
                snapshot: InstanceSnapshot {
                    lottery_id,
                    owner: record.owner,
                    lottery_address: record.lottery_address,
                    ticket_price: record.ticket_price,
                    jackpot_share_bps: record.jackpot_share_bps,
                    tickets_sold: record.tickets_sold,
                    jackpot_accumulated: record.jackpot_accumulated,
                    active: record.active,
                },
            },
        );
    }

    fun import_existing_instances_recursive(records: &mut vector<LegacyInstanceRecord>)
    acquires InstanceRegistry {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        import_existing_instances_recursive(records);
        upsert_legacy_instance(record);
    }

    fun upsert_legacy_instance(record: LegacyInstanceRecord) acquires InstanceRegistry {
        let LegacyInstanceRecord {
            lottery_id,
            owner,
            lottery_address,
            ticket_price,
            jackpot_share_bps,
            tickets_sold,
            jackpot_accumulated,
            active,
        } = record;
        let registry = borrow_registry_mut(@lottery);
        if (table::contains(&registry.instances, lottery_id)) {
            let existing = table::borrow_mut(&mut registry.instances, lottery_id);
            existing.owner = owner;
            existing.lottery_address = lottery_address;
            existing.ticket_price = ticket_price;
            existing.jackpot_share_bps = jackpot_share_bps;
            existing.tickets_sold = tickets_sold;
            existing.jackpot_accumulated = jackpot_accumulated;
            existing.active = active;
        } else {
            let new_record = InstanceRecord {
                owner,
                lottery_address,
                ticket_price,
                jackpot_share_bps,
                tickets_sold,
                jackpot_accumulated,
                active,
            };
            register_instance(registry, lottery_id, new_record);
            let stored = instance(registry, lottery_id);
            emit_creation(registry, lottery_id, stored);
        };
        ensure_lottery_id_recorded(&mut registry.lottery_ids, lottery_id, 0);
        emit_blueprint(registry, lottery_id, ticket_price, jackpot_share_bps);
        emit_status(registry, lottery_id, active);
        emit_snapshot(registry, lottery_id);
    }

    fun ensure_lottery_id_recorded(ids: &mut vector<u64>, lottery_id: u64, index: u64) {
        if (contains_lottery_id(ids, lottery_id, index)) {
            return;
        };
        vector::push_back(ids, lottery_id);
    }

    fun contains_lottery_id(ids: &vector<u64>, lottery_id: u64, index: u64): bool {
        let len = vector::length(ids);
        if (index == len) {
            return false;
        };
        if (*vector::borrow(ids, index) == lottery_id) {
            return true;
        };
        contains_lottery_id(ids, lottery_id, index + 1)
    }

    fun ensure_admin(caller: &signer) acquires InstanceRegistry {
        let registry = borrow_registry(@lottery);
        if (signer::address_of(caller) != registry.admin) {
            abort E_UNAUTHORIZED;
        };
    }
}
