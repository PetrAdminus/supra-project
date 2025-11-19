module lottery_data::rounds {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_core::core_rounds;
    use lottery_vrf_gateway::table;
    use supra_framework::account;
    use supra_framework::event;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_UNKNOWN_ROUND: u64 = 3;
    const E_ROUND_EXISTS: u64 = 4;
    const E_HISTORY_QUEUE_MISSING: u64 = 5;
    const E_HISTORY_CAP_OCCUPIED: u64 = 6;
    const E_PURCHASE_QUEUE_MISSING: u64 = 7;
    const E_NOT_ADMIN: u64 = 8;
    const E_AUTOPURCHASE_CAP_OCCUPIED: u64 = 9;
    const E_INVALID_HISTORY_RECORD: u64 = 10;
    const E_INVALID_PURCHASE_RECORD: u64 = 11;

    struct RoundRuntime has copy, drop, store {
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    }

    struct RoundSnapshot has copy, drop, store {
        lottery_id: u64,
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
        next_ticket_id: u64,
        pending_request_id: option::Option<u64>,
    }

    struct RoundRuntimeSnapshot has copy, drop, store {
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request_id: option::Option<u64>,
    }

    struct RoundRegistrySnapshot has copy, drop, store {
        admin: address,
        rounds: vector<RoundRuntimeSnapshot>,
    }

    #[event]
    struct TicketPurchasedEvent has drop, store, copy {
        lottery_id: u64,
        ticket_id: u64,
        buyer: address,
        amount: u64,
    }

    #[event]
    struct DrawScheduleUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        draw_scheduled: bool,
    }

    #[event]
    struct RoundResetEvent has drop, store, copy {
        lottery_id: u64,
        tickets_cleared: u64,
    }

    #[event]
    struct DrawRequestIssuedEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
    }

    #[event]
    struct DrawFulfilledEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        random_bytes: vector<u8>,
        prize_amount: u64,
        payload: vector<u8>,
    }

    #[event]
    struct RoundSnapshotUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        snapshot: RoundSnapshot,
    }

    struct RoundRegistry has key {
        admin: address,
        rounds: table::Table<u64, RoundRuntime>,
        lottery_ids: vector<u64>,
        ticket_events: event::EventHandle<TicketPurchasedEvent>,
        schedule_events: event::EventHandle<DrawScheduleUpdatedEvent>,
        reset_events: event::EventHandle<RoundResetEvent>,
        request_events: event::EventHandle<DrawRequestIssuedEvent>,
        fulfill_events: event::EventHandle<DrawFulfilledEvent>,
        snapshot_events: event::EventHandle<RoundSnapshotUpdatedEvent>,
    }

    struct HistoryWriterCap has store {}

    struct AutopurchaseRoundCap has store {}

    struct RoundControl has key {
        admin: address,
        history_cap: option::Option<HistoryWriterCap>,
        autopurchase_cap: option::Option<AutopurchaseRoundCap>,
    }

    struct RoundControlSnapshot has copy, drop, store {
        admin: address,
        history_cap_present: bool,
        autopurchase_cap_present: bool,
    }

    struct PendingHistoryRecord has drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    }

    struct PendingPurchaseRecord has drop, store {
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        paid_amount: u64,
    }

    struct PendingHistoryQueue has key {
        pending: vector<PendingHistoryRecord>,
    }

    struct PendingPurchaseQueue has key {
        pending: vector<PendingPurchaseRecord>,
    }

    struct PendingHistorySnapshot has drop, store {
        records: vector<PendingHistoryRecord>,
    }

    struct PendingPurchaseSnapshot has drop, store {
        records: vector<PendingPurchaseRecord>,
    }

    public struct LegacyRoundRecord has drop, store {
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    }

    public entry fun init_registry(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<RoundRegistry>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            RoundRegistry {
                admin: caller_address,
                rounds: table::new<u64, RoundRuntime>(),
                lottery_ids: vector::empty<u64>(),
                ticket_events: account::new_event_handle<TicketPurchasedEvent>(caller),
                schedule_events: account::new_event_handle<DrawScheduleUpdatedEvent>(caller),
                reset_events: account::new_event_handle<RoundResetEvent>(caller),
                request_events: account::new_event_handle<DrawRequestIssuedEvent>(caller),
                fulfill_events: account::new_event_handle<DrawFulfilledEvent>(caller),
                snapshot_events: account::new_event_handle<RoundSnapshotUpdatedEvent>(caller),
            },
        );
    }

    public entry fun init_control(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<RoundControl>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            RoundControl {
                admin: caller_address,
                history_cap: option::none<HistoryWriterCap>(),
                autopurchase_cap: option::none<AutopurchaseRoundCap>(),
            },
        );
    }

    public entry fun claim_round_control_caps(
        caller: &signer,
        _legacy_history_cap: core_rounds::HistoryWriterCap,
        _legacy_autopurchase_cap: core_rounds::AutopurchaseRoundCap,
    ) acquires RoundControl {
        let control = borrow_control_mut(@lottery);
        ensure_control_admin(control, caller);
        if (option::is_some(&control.history_cap)) {
            abort E_HISTORY_CAP_OCCUPIED;
        };
        if (option::is_some(&control.autopurchase_cap)) {
            abort E_AUTOPURCHASE_CAP_OCCUPIED;
        };

        option::fill(&mut control.history_cap, HistoryWriterCap {});
        option::fill(&mut control.autopurchase_cap, AutopurchaseRoundCap {});
    }

    public entry fun init_history_queue(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<PendingHistoryQueue>(caller_address), E_ALREADY_INITIALIZED);
        move_to(caller, PendingHistoryQueue { pending: vector::empty<PendingHistoryRecord>() });
    }

    public entry fun init_purchase_queue(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<PendingPurchaseQueue>(caller_address), E_ALREADY_INITIALIZED);
        move_to(caller, PendingPurchaseQueue { pending: vector::empty<PendingPurchaseRecord>() });
    }

    public fun borrow_registry(addr: address): &RoundRegistry acquires RoundRegistry {
        assert!(exists<RoundRegistry>(addr), E_NOT_PUBLISHED);
        borrow_global<RoundRegistry>(addr)
    }

    public fun borrow_registry_mut(addr: address): &mut RoundRegistry acquires RoundRegistry {
        assert!(exists<RoundRegistry>(addr), E_NOT_PUBLISHED);
        borrow_global_mut<RoundRegistry>(addr)
    }

    public fun borrow_control(addr: address): &RoundControl acquires RoundControl {
        assert!(exists<RoundControl>(addr), E_NOT_PUBLISHED);
        borrow_global<RoundControl>(addr)
    }

    public fun borrow_control_mut(addr: address): &mut RoundControl acquires RoundControl {
        assert!(exists<RoundControl>(addr), E_NOT_PUBLISHED);
        borrow_global_mut<RoundControl>(addr)
    }

    public fun history_cap_available(control: &RoundControl): bool {
        option::is_some(&control.history_cap)
    }

    public fun extract_history_cap(
        control: &mut RoundControl,
    ): option::Option<HistoryWriterCap> {
        if (!option::is_some(&control.history_cap)) {
            return option::none<HistoryWriterCap>();
        };
        let cap = option::extract(&mut control.history_cap);
        option::some(cap)
    }

    public fun restore_history_cap(control: &mut RoundControl, cap: HistoryWriterCap) {
        if (option::is_some(&control.history_cap)) {
            abort E_HISTORY_CAP_OCCUPIED;
        };
        option::fill(&mut control.history_cap, cap);
    }

    public fun autopurchase_cap_available(control: &RoundControl): bool {
        option::is_some(&control.autopurchase_cap)
    }

    #[view]
    public fun caps_ready(): bool acquires RoundControl {
        if (!exists<RoundControl>(@lottery)) {
            return false;
        };
        let control = borrow_global<RoundControl>(@lottery);
        history_cap_available(&control) && autopurchase_cap_available(&control)
    }

    #[view]
    public fun control_snapshot(): option::Option<RoundControlSnapshot> acquires RoundControl {
        if (!exists<RoundControl>(@lottery)) {
            return option::none<RoundControlSnapshot>();
        };
        let control = borrow_global<RoundControl>(@lottery);
        option::some(build_control_snapshot(&control))
    }

    fun build_control_snapshot(control: &RoundControl): RoundControlSnapshot {
        RoundControlSnapshot {
            admin: control.admin,
            history_cap_present: history_cap_available(control),
            autopurchase_cap_present: autopurchase_cap_available(control),
        }
    }

    public fun extract_autopurchase_cap(
        control: &mut RoundControl,
    ): option::Option<AutopurchaseRoundCap> {
        if (!option::is_some(&control.autopurchase_cap)) {
            return option::none<AutopurchaseRoundCap>();
        };
        let cap = option::extract(&mut control.autopurchase_cap);
        option::some(cap)
    }

    public fun restore_autopurchase_cap(
        control: &mut RoundControl,
        cap: AutopurchaseRoundCap,
    ) {
        if (option::is_some(&control.autopurchase_cap)) {
            abort E_ALREADY_INITIALIZED;
        };
        option::fill(&mut control.autopurchase_cap, cap);
    }

    public fun borrow_history_queue(addr: address): &PendingHistoryQueue acquires PendingHistoryQueue {
        borrow_global<PendingHistoryQueue>(addr)
    }

    public fun borrow_history_queue_mut(addr: address): &mut PendingHistoryQueue acquires PendingHistoryQueue {
        borrow_global_mut<PendingHistoryQueue>(addr)
    }

    #[view]
    public fun history_queue_length(): u64 acquires PendingHistoryQueue {
        if (!exists<PendingHistoryQueue>(@lottery)) {
            return 0;
        };
        let queue = borrow_global<PendingHistoryQueue>(@lottery);
        vector::length(&queue.pending)
    }

    #[view]
    public fun history_queue_initialized(): bool {
        exists<PendingHistoryQueue>(@lottery)
    }

    public fun enqueue_history_record(
        queue: &mut PendingHistoryQueue,
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) {
        vector::push_back(
            &mut queue.pending,
            PendingHistoryRecord {
                lottery_id,
                request_id,
                winner,
                ticket_index,
                prize_amount,
                random_bytes,
                payload,
            },
        );
    }

    public fun drain_history_queue(
        _cap: &HistoryWriterCap,
        limit: u64,
    ): vector<PendingHistoryRecord> acquires PendingHistoryQueue {
        assert!(exists<PendingHistoryQueue>(@lottery), E_HISTORY_QUEUE_MISSING);
        let queue = borrow_global_mut<PendingHistoryQueue>(@lottery);
        let available = vector::length(&queue.pending);
        let to_take = history_drain_limit(limit, available);
        let drained = vector::empty<PendingHistoryRecord>();
        drain_history_records(&mut queue.pending, drained, to_take)
    }

    public fun destroy_pending_history_record(
        record: PendingHistoryRecord,
    ): (
        u64,
        u64,
        address,
        u64,
        u64,
        vector<u8>,
        vector<u8>,
    ) {
        let PendingHistoryRecord {
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        } = record;
        (
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            random_bytes,
            payload,
        )
    }

    public fun borrow_purchase_queue(addr: address): &PendingPurchaseQueue acquires PendingPurchaseQueue {
        borrow_global<PendingPurchaseQueue>(addr)
    }

    public fun borrow_purchase_queue_mut(addr: address): &mut PendingPurchaseQueue acquires PendingPurchaseQueue {
        borrow_global_mut<PendingPurchaseQueue>(addr)
    }

    #[view]
    public fun purchase_queue_length(): u64 acquires PendingPurchaseQueue {
        if (!exists<PendingPurchaseQueue>(@lottery)) {
            return 0;
        };
        let queue = borrow_global<PendingPurchaseQueue>(@lottery);
        vector::length(&queue.pending)
    }

    #[view]
    public fun purchase_queue_initialized(): bool {
        exists<PendingPurchaseQueue>(@lottery)
    }

    #[view]
    public fun queues_initialized(): bool {
        history_queue_initialized() && purchase_queue_initialized()
    }

    #[view]
    public fun ready()
    acquires RoundRegistry, RoundControl, PendingHistoryQueue, PendingPurchaseQueue: bool {
        if (!exists<RoundRegistry>(@lottery)) {
            return false;
        };
        if (!exists<RoundControl>(@lottery)) {
            return false;
        };
        if (!history_queue_initialized() || !purchase_queue_initialized()) {
            return false;
        };

        let registry = borrow_global<RoundRegistry>(@lottery);
        if (!registry_consistent(&registry)) {
            return false;
        };

        let history_queue = borrow_global<PendingHistoryQueue>(@lottery);
        if (!history_records_consistent(&history_queue, &registry)) {
            return false;
        };

        let purchase_queue = borrow_global<PendingPurchaseQueue>(@lottery);
        if (!purchase_records_consistent(&purchase_queue, &registry)) {
            return false;
        };

        caps_ready()
    }

    #[view]
    public fun pending_history_snapshot(): option::Option<PendingHistorySnapshot>
    acquires PendingHistoryQueue {
        if (!exists<PendingHistoryQueue>(@lottery)) {
            option::none<PendingHistorySnapshot>()
        } else {
            let queue = borrow_global<PendingHistoryQueue>(@lottery);
            option::some(build_history_snapshot(&queue.pending))
        }
    }

    #[view]
    public fun is_initialized(): bool {
        exists<RoundRegistry>(@lottery)
    }

    #[view]
    public fun registry_snapshot(): option::Option<RoundRegistrySnapshot>
    acquires RoundRegistry {
        if (!exists<RoundRegistry>(@lottery)) {
            return option::none<RoundRegistrySnapshot>();
        };

        let registry = borrow_global<RoundRegistry>(@lottery);
        let rounds = collect_round_snapshots(&registry, 0, vector::length(&registry.lottery_ids));
        let snapshot = RoundRegistrySnapshot { admin: registry.admin, rounds };

        option::some(snapshot)
    }

    #[view]
    public fun round_snapshot(lottery_id: u64): option::Option<RoundRuntimeSnapshot>
    acquires RoundRegistry {
        if (!exists<RoundRegistry>(@lottery)) {
            return option::none<RoundRuntimeSnapshot>();
        };

        let registry = borrow_global<RoundRegistry>(@lottery);
        if (!table::contains(&registry.rounds, lottery_id)) {
            return option::none<RoundRuntimeSnapshot>();
        };

        let snapshot = build_round_snapshot(&registry, lottery_id);
        option::some(snapshot)
    }

    #[view]
    public fun pending_purchase_snapshot(): option::Option<PendingPurchaseSnapshot>
    acquires PendingPurchaseQueue {
        if (!exists<PendingPurchaseQueue>(@lottery)) {
            option::none<PendingPurchaseSnapshot>()
        } else {
            let queue = borrow_global<PendingPurchaseQueue>(@lottery);
            option::some(build_purchase_snapshot(&queue.pending))
        }
    }

    public fun enqueue_purchase_record(
        queue: &mut PendingPurchaseQueue,
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        paid_amount: u64,
    ) {
        vector::push_back(
            &mut queue.pending,
            PendingPurchaseRecord { lottery_id, buyer, ticket_count, paid_amount },
        );
    }

    public fun drain_purchase_queue(
        _cap: &AutopurchaseRoundCap,
        limit: u64,
    ): vector<PendingPurchaseRecord> acquires PendingPurchaseQueue {
        assert!(exists<PendingPurchaseQueue>(@lottery), E_PURCHASE_QUEUE_MISSING);
        let queue = borrow_global_mut<PendingPurchaseQueue>(@lottery);
        let available = vector::length(&queue.pending);
        let to_take = history_drain_limit(limit, available);
        let drained = vector::empty<PendingPurchaseRecord>();
        drain_purchase_records(&mut queue.pending, drained, to_take)
    }

    public fun destroy_pending_purchase_record(
        record: PendingPurchaseRecord,
    ): (u64, address, u64, u64) {
        let PendingPurchaseRecord { lottery_id, buyer, ticket_count, paid_amount } = record;
        (lottery_id, buyer, ticket_count, paid_amount)
    }

    public entry fun import_existing_round(
        caller: &signer,
        record: LegacyRoundRecord,
    ) acquires RoundRegistry {
        import_existing_rounds(caller, vector::singleton(record))
    }

    public entry fun import_existing_rounds(
        caller: &signer,
        mut records: vector<LegacyRoundRecord>,
    ) acquires RoundRegistry {
        ensure_admin(caller);
        import_existing_rounds_recursive(&mut records);
    }

    public entry fun import_pending_history_records(
        caller: &signer,
        mut records: vector<PendingHistoryRecord>,
    ) acquires PendingHistoryQueue, RoundRegistry {
        ensure_admin(caller);
        assert!(exists<PendingHistoryQueue>(@lottery), E_HISTORY_QUEUE_MISSING);
        let registry = borrow_registry(@lottery);
        ensure_history_records_valid(&records, registry);
        let queue = borrow_global_mut<PendingHistoryQueue>(@lottery);
        queue.pending = vector::empty<PendingHistoryRecord>();
        append_history_records(&mut queue.pending, &mut records);
    }

    public entry fun import_pending_purchase_records(
        caller: &signer,
        mut records: vector<PendingPurchaseRecord>,
    ) acquires PendingPurchaseQueue, RoundRegistry {
        ensure_admin(caller);
        assert!(exists<PendingPurchaseQueue>(@lottery), E_PURCHASE_QUEUE_MISSING);
        let registry = borrow_registry(@lottery);
        ensure_purchase_records_valid(&records, registry);
        let queue = borrow_global_mut<PendingPurchaseQueue>(@lottery);
        queue.pending = vector::empty<PendingPurchaseRecord>();
        append_purchase_records(&mut queue.pending, &mut records);
    }

    public fun register_round(registry: &mut RoundRegistry, lottery_id: u64, runtime: RoundRuntime) {
        assert!(!table::contains(&registry.rounds, lottery_id), E_ROUND_EXISTS);
        table::add(&mut registry.rounds, lottery_id, runtime);
        vector::push_back(&mut registry.lottery_ids, lottery_id);
    }

    public fun round(registry: &RoundRegistry, lottery_id: u64): &RoundRuntime {
        assert!(table::contains(&registry.rounds, lottery_id), E_UNKNOWN_ROUND);
        table::borrow(&registry.rounds, lottery_id)
    }

    public fun round_mut(registry: &mut RoundRegistry, lottery_id: u64): &mut RoundRuntime {
        assert!(table::contains(&registry.rounds, lottery_id), E_UNKNOWN_ROUND);
        table::borrow_mut(&mut registry.rounds, lottery_id)
    }

    public fun emit_snapshot(registry: &mut RoundRegistry, lottery_id: u64) {
        let runtime_ref = round(registry, lottery_id);
        let snapshot = RoundSnapshot {
            lottery_id,
            ticket_count: vector::length(&runtime_ref.tickets),
            draw_scheduled: runtime_ref.draw_scheduled,
            has_pending_request: option::is_some(&runtime_ref.pending_request),
            next_ticket_id: runtime_ref.next_ticket_id,
            pending_request_id: runtime_ref.pending_request,
        };
        event::emit_event(&mut registry.snapshot_events, RoundSnapshotUpdatedEvent { lottery_id, snapshot });
    }

    public fun empty_round(): RoundRuntime {
        RoundRuntime {
            tickets: vector::empty<address>(),
            draw_scheduled: false,
            next_ticket_id: 0,
            pending_request: option::none<u64>(),
        }
    }

    fun build_round_snapshot(registry: &RoundRegistry, lottery_id: u64): RoundRuntimeSnapshot {
        let runtime = table::borrow(&registry.rounds, lottery_id);
        let tickets = clone_addresses(&runtime.tickets, 0, vector::length(&runtime.tickets));
        let pending_request_id = clone_option_u64(&runtime.pending_request);

        RoundRuntimeSnapshot {
            lottery_id,
            tickets,
            draw_scheduled: runtime.draw_scheduled,
            next_ticket_id: runtime.next_ticket_id,
            pending_request_id,
        }
    }

    fun collect_round_snapshots(
        registry: &RoundRegistry,
        index: u64,
        len: u64,
    ): vector<RoundRuntimeSnapshot> {
        if (index >= len) {
            return vector::empty<RoundRuntimeSnapshot>();
        };

        let mut current = vector::empty<RoundRuntimeSnapshot>();
        let lottery_id = *vector::borrow(&registry.lottery_ids, index);
        vector::push_back(&mut current, build_round_snapshot(registry, lottery_id));

        let tail = collect_round_snapshots(registry, index + 1, len);
        append_round_snapshots(&mut current, &tail, 0);
        current
    }

    fun append_round_snapshots(
        dst: &mut vector<RoundRuntimeSnapshot>,
        src: &vector<RoundRuntimeSnapshot>,
        index: u64,
    ) {
        if (index >= vector::length(src)) {
            return;
        };

        vector::push_back(dst, *vector::borrow(src, index));
        append_round_snapshots(dst, src, index + 1);
    }

    fun clone_addresses(addresses: &vector<address>, index: u64, len: u64): vector<address> {
        if (index >= len) {
            return vector::empty<address>();
        };

        let mut current = vector::empty<address>();
        vector::push_back(&mut current, *vector::borrow(addresses, index));

        let tail = clone_addresses(addresses, index + 1, len);
        append_addresses(&mut current, &tail, 0);
        current
    }

    fun append_addresses(dst: &mut vector<address>, src: &vector<address>, index: u64) {
        if (index >= vector::length(src)) {
            return;
        };

        vector::push_back(dst, *vector::borrow(src, index));
        append_addresses(dst, src, index + 1);
    }

    fun clone_option_u64(value: &option::Option<u64>): option::Option<u64> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<u64>()
        }
    }

    fun history_drain_limit(limit: u64, available: u64): u64 {
        if (limit == 0 || limit >= available) {
            available
        } else {
            limit
        }
    }

    fun drain_history_records(
        source: &mut vector<PendingHistoryRecord>,
        drained: vector<PendingHistoryRecord>,
        remaining: u64,
    ): vector<PendingHistoryRecord> {
        if (remaining == 0 || vector::is_empty(source)) {
            drained
        } else {
            let record = vector::remove(source, 0);
            let mut next = drained;
            vector::push_back(&mut next, record);
            let next_remaining = remaining - 1;
            drain_history_records(source, next, next_remaining)
        }
    }

    fun import_existing_rounds_recursive(records: &mut vector<LegacyRoundRecord>) acquires RoundRegistry {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        import_existing_rounds_recursive(records);
        apply_legacy_round(record);
    }

    fun apply_legacy_round(record: LegacyRoundRecord) acquires RoundRegistry {
        let LegacyRoundRecord {
            lottery_id,
            tickets,
            draw_scheduled,
            next_ticket_id,
            pending_request,
        } = record;
        let registry = borrow_registry_mut(@lottery);
        if (!table::contains(&registry.rounds, lottery_id)) {
            register_round(
                registry,
                lottery_id,
                RoundRuntime {
                    tickets,
                    draw_scheduled,
                    next_ticket_id,
                    pending_request,
                },
            );
        } else {
            let runtime = round_mut(registry, lottery_id);
            runtime.tickets = tickets;
            runtime.draw_scheduled = draw_scheduled;
            runtime.next_ticket_id = next_ticket_id;
            runtime.pending_request = pending_request;
        };
        emit_snapshot(registry, lottery_id);
    }

    fun append_history_records(
        target: &mut vector<PendingHistoryRecord>,
        records: &mut vector<PendingHistoryRecord>,
    ) {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        append_history_records(target, records);
        vector::push_back(target, record);
    }

    fun append_purchase_records(
        target: &mut vector<PendingPurchaseRecord>,
        records: &mut vector<PendingPurchaseRecord>,
    ) {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        append_purchase_records(target, records);
        vector::push_back(target, record);
    }

    fun drain_purchase_records(
        source: &mut vector<PendingPurchaseRecord>,
        drained: vector<PendingPurchaseRecord>,
        remaining: u64,
    ): vector<PendingPurchaseRecord> {
        if (remaining == 0 || vector::is_empty(source)) {
            drained
        } else {
            let record = vector::remove(source, 0);
            let mut next = drained;
            vector::push_back(&mut next, record);
            let next_remaining = remaining - 1;
            drain_purchase_records(source, next, next_remaining)
        }
    }

    fun build_history_snapshot(pending: &vector<PendingHistoryRecord>): PendingHistorySnapshot {
        PendingHistorySnapshot {
            records: clone_history_records(pending),
        }
    }

    fun build_purchase_snapshot(pending: &vector<PendingPurchaseRecord>): PendingPurchaseSnapshot {
        PendingPurchaseSnapshot {
            records: clone_purchase_records(pending),
        }
    }

    fun clone_history_records(records: &vector<PendingHistoryRecord>): vector<PendingHistoryRecord> {
        let buffer = vector::empty<PendingHistoryRecord>();
        let len = vector::length(records);
        append_history_records_clone(records, &mut buffer, 0, len);
        buffer
    }

    fun clone_purchase_records(records: &vector<PendingPurchaseRecord>): vector<PendingPurchaseRecord> {
        let buffer = vector::empty<PendingPurchaseRecord>();
        let len = vector::length(records);
        append_purchase_records_clone(records, &mut buffer, 0, len);
        buffer
    }

    fun append_history_records_clone(
        source: &vector<PendingHistoryRecord>,
        dest: &mut vector<PendingHistoryRecord>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let record_ref = vector::borrow(source, index);
        vector::push_back(
            dest,
            PendingHistoryRecord {
                lottery_id: record_ref.lottery_id,
                request_id: record_ref.request_id,
                winner: record_ref.winner,
                ticket_index: record_ref.ticket_index,
                prize_amount: record_ref.prize_amount,
                random_bytes: clone_bytes(&record_ref.random_bytes),
                payload: clone_bytes(&record_ref.payload),
            },
        );
        append_history_records_clone(source, dest, index + 1, len);
    }

    fun append_purchase_records_clone(
        source: &vector<PendingPurchaseRecord>,
        dest: &mut vector<PendingPurchaseRecord>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        let record_ref = vector::borrow(source, index);
        vector::push_back(
            dest,
            PendingPurchaseRecord {
                lottery_id: record_ref.lottery_id,
                buyer: record_ref.buyer,
                ticket_count: record_ref.ticket_count,
                paid_amount: record_ref.paid_amount,
            },
        );
        append_purchase_records_clone(source, dest, index + 1, len);
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(source);
        append_bytes(source, &mut buffer, 0, len);
        buffer
    }

    fun append_bytes(source: &vector<u8>, dest: &mut vector<u8>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        vector::push_back(dest, *vector::borrow(source, index));
        append_bytes(source, dest, index + 1, len);
    }

    fun registry_consistent(registry: &RoundRegistry): bool {
        let len = vector::length(&registry.lottery_ids);
        registry_consistent_recursive(registry, 0, len)
    }

    fun registry_consistent_recursive(
        registry: &RoundRegistry,
        index: u64,
        len: u64,
    ): bool {
        if (index >= len) {
            return true;
        };

        let lottery_id = *vector::borrow(&registry.lottery_ids, index);
        if (!table::contains(&registry.rounds, lottery_id)) {
            return false;
        };

        registry_consistent_recursive(registry, index + 1, len)
    }

    fun history_records_consistent(
        queue: &PendingHistoryQueue,
        registry: &RoundRegistry,
    ): bool {
        history_records_consistent_recursive(&queue.pending, registry, 0)
    }

    fun ensure_history_records_valid(records: &vector<PendingHistoryRecord>, registry: &RoundRegistry) {
        if (!history_records_valid(records, registry)) {
            abort E_INVALID_HISTORY_RECORD;
        };
    }

    fun history_records_consistent_recursive(
        records: &vector<PendingHistoryRecord>,
        registry: &RoundRegistry,
        index: u64,
    ): bool {
        if (index >= vector::length(records)) {
            return true;
        };

        let record = vector::borrow(records, index);
        if (!table::contains(&registry.rounds, record.lottery_id)) {
            return false;
        };

        history_records_consistent_recursive(records, registry, index + 1)
    }

    fun purchase_records_consistent(
        queue: &PendingPurchaseQueue,
        registry: &RoundRegistry,
    ): bool {
        purchase_records_consistent_recursive(&queue.pending, registry, 0)
    }

    fun ensure_purchase_records_valid(records: &vector<PendingPurchaseRecord>, registry: &RoundRegistry) {
        if (!purchase_records_valid(records, registry)) {
            abort E_INVALID_PURCHASE_RECORD;
        };
    }

    fun purchase_records_consistent_recursive(
        records: &vector<PendingPurchaseRecord>,
        registry: &RoundRegistry,
        index: u64,
    ): bool {
        if (index >= vector::length(records)) {
            return true;
        };

        let record = vector::borrow(records, index);
        if (!table::contains(&registry.rounds, record.lottery_id)) {
            return false;
        };
        if (record.ticket_count == 0 || record.paid_amount == 0) {
            return false;
        };

        purchase_records_consistent_recursive(records, registry, index + 1)
    }

    fun history_records_valid(
        records: &vector<PendingHistoryRecord>,
        registry: &RoundRegistry,
    ): bool {
        history_records_valid_recursive(records, registry, 0)
    }

    fun history_records_valid_recursive(
        records: &vector<PendingHistoryRecord>,
        registry: &RoundRegistry,
        index: u64,
    ): bool {
        if (index >= vector::length(records)) {
            return true;
        };

        let record = vector::borrow(records, index);
        if (!table::contains(&registry.rounds, record.lottery_id)) {
            return false;
        };

        let runtime = table::borrow(&registry.rounds, record.lottery_id);
        if (!option::is_some(&runtime.pending_request)) {
            return false;
        };
        if (*option::borrow(&runtime.pending_request) != record.request_id) {
            return false;
        };
        if (record.ticket_index >= vector::length(&runtime.tickets)) {
            return false;
        };

        history_records_valid_recursive(records, registry, index + 1)
    }

    fun purchase_records_valid(
        records: &vector<PendingPurchaseRecord>,
        registry: &RoundRegistry,
    ): bool {
        purchase_records_valid_recursive(records, registry, 0)
    }

    fun purchase_records_valid_recursive(
        records: &vector<PendingPurchaseRecord>,
        registry: &RoundRegistry,
        index: u64,
    ): bool {
        if (index >= vector::length(records)) {
            return true;
        };

        let record = vector::borrow(records, index);
        if (!table::contains(&registry.rounds, record.lottery_id)) {
            return false;
        };
        if (record.ticket_count == 0 || record.paid_amount == 0) {
            return false;
        };

        purchase_records_valid_recursive(records, registry, index + 1)
    }

    fun ensure_admin(caller: &signer) acquires RoundRegistry {
        let registry = borrow_registry(@lottery);
        if (signer::address_of(caller) != registry.admin) {
            abort E_NOT_ADMIN;
        };
    }

    fun ensure_control_admin(control: &RoundControl, caller: &signer) {
        if (signer::address_of(caller) != control.admin) {
            abort E_NOT_ADMIN;
        };
    }
}
