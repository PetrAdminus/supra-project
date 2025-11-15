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
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_COUNTER_OVERFLOW: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;
    const E_NOT_INITIALIZED: u64 = 5;

    struct OwnerLotteries has store {
        lottery_ids: vector<u64>,
    }

    struct GatewayLottery has copy, drop, store {
        owner: address,
        active: bool,
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

    public entry fun init(caller: &signer, admin: address)
    acquires GatewayRegistry, instances::InstanceRegistry {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<GatewayRegistry>(caller_address), E_ALREADY_INITIALIZED);

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
    acquires GatewayRegistry, instances::InstanceRegistry {
        let caller_address = signer::address_of(caller);
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        assert!(caller_address == gateway.admin, E_UNAUTHORIZED);
        gateway.admin = new_admin;
        emit_snapshot(gateway);

        let registry = instances::borrow_registry_mut(@lottery);
        instances::set_admin(registry, new_admin);
    }

    public entry fun create_lottery(
        caller: &signer,
        owner: address,
        ticket_price: u64,
        auto_draw_threshold: u64,
        jackpot_share_bps: u16,
    ) acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
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
        emit_snapshot(gateway);
    }

    public entry fun set_owner(caller: &signer, lottery_id: u64, new_owner: address)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        operators::OperatorRegistry
    {
        let previous_owner = current_owner(lottery_id);
        engine_operators::set_owner(caller, lottery_id, new_owner);
        let gateway = borrow_global_mut<GatewayRegistry>(@lottery);
        refresh_owner(gateway, lottery_id, option::some(previous_owner), new_owner);
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
        rounds::RoundRegistry
    {
        lifecycle::pause_lottery(caller, lottery_id);
        sync_status(lottery_id);
    }

    public entry fun resume_lottery(caller: &signer, lottery_id: u64)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        operators::OperatorRegistry,
        rounds::RoundRegistry
    {
        lifecycle::resume_lottery(caller, lottery_id);
        sync_status(lottery_id);
    }

    public entry fun cancel_lottery(
        caller: &signer,
        lottery_id: u64,
        reason_code: u8,
        canceled_ts: u64,
    ) acquires
        GatewayRegistry,
        cancellations::CancellationLedger,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        cancellation::cancel_lottery(caller, lottery_id, reason_code, canceled_ts);
        sync_status(lottery_id);
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        draw::schedule_draw(caller, lottery_id);
    }

    public entry fun request_randomness(caller: &signer, lottery_id: u64, payload: vector<u8>)
    acquires
        GatewayRegistry,
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        draw::request_randomness(caller, lottery_id, payload);
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
}
