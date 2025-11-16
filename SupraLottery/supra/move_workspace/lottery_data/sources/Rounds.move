module lottery_data::rounds {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_UNKNOWN_ROUND: u64 = 3;
    const E_ROUND_EXISTS: u64 = 4;
    const E_HISTORY_QUEUE_MISSING: u64 = 5;
    const E_HISTORY_CAP_OCCUPIED: u64 = 6;
    const E_PURCHASE_QUEUE_MISSING: u64 = 7;
    const E_NOT_ADMIN: u64 = 8;

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
                history_cap: option::some(HistoryWriterCap {}),
                autopurchase_cap: option::some(AutopurchaseRoundCap {}),
            },
        );
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

    fun ensure_admin(caller: &signer) acquires RoundRegistry {
        let registry = borrow_registry(@lottery);
        if (signer::address_of(caller) != registry.admin) {
            abort E_NOT_ADMIN;
        };
    }
}
