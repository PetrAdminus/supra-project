module vrf_hub::hub {
    #[test_only]
    friend vrf_hub::hub_tests;
    use std::option;
    use std::signer;
    use std::vector;
    use std::hash;
    use vrf_hub::table;
    use supra_framework::account;
    use supra_framework::event;


    const E_NOT_AUTHORIZED: u64 = 1;

    const E_ALREADY_INIT: u64 = 2;

    const E_UNKNOWN_LOTTERY: u64 = 3;

    const E_UNKNOWN_REQUEST: u64 = 4;

    const E_CALLBACK_NOT_CONFIGURED: u64 = 5;

    const E_CALLBACK_NOT_ALLOWED: u64 = 6;

    const E_INACTIVE_LOTTERY: u64 = 7;
    const E_NOT_INITIALIZED: u64 = 8;


    struct LotteryRegistration has copy, drop, store {
        owner: address,
        lottery: address,
        metadata: vector<u8>,
        active: bool,
    }


    struct RequestRecord has copy, drop, store {
        lottery_id: u64,
        payload: vector<u8>,
        payload_hash: vector<u8>,
    }


    struct HubState has key {
        admin: address,
        next_lottery_id: u64,
        next_request_id: u64,
        lotteries: table::Table<u64, LotteryRegistration>,
        requests: table::Table<u64, RequestRecord>,
        lottery_ids: vector<u64>,
        pending_request_ids: vector<u64>,
        callback_sender: option::Option<address>,
        register_events: event::EventHandle<LotteryRegisteredEvent>,
        status_events: event::EventHandle<LotteryStatusChangedEvent>,
        metadata_events: event::EventHandle<LotteryMetadataUpdatedEvent>,
        request_events: event::EventHandle<RandomnessRequestedEvent>,
        fulfill_events: event::EventHandle<RandomnessFulfilledEvent>,
        callback_sender_events: event::EventHandle<CallbackSenderUpdatedEvent>,
    }

    #[event]
    struct LotteryRegisteredEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
        lottery: address,
    }

    #[event]
    struct LotteryStatusChangedEvent has drop, store, copy {
        lottery_id: u64,
        active: bool,
    }

    #[event]
    struct LotteryMetadataUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        metadata: vector<u8>,
    }

    #[event]
    struct RandomnessRequestedEvent has drop, store, copy {
        request_id: u64,
        lottery_id: u64,
        payload: vector<u8>,
        payload_hash: vector<u8>,
    }

    #[event]
    struct RandomnessFulfilledEvent has drop, store, copy {
        request_id: u64,
        lottery_id: u64,
        randomness: vector<u8>,
    }

    #[event]
    struct CallbackSenderUpdatedEvent has drop, store, copy {
        previous: option::Option<address>,
        current: option::Option<address>,
    }

    struct CallbackSenderStatus has copy, drop {
        sender: option::Option<address>,
    }


    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @vrf_hub) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<HubState>(@vrf_hub)) {
            abort E_ALREADY_INIT
        };
        move_to(caller, HubState {
            admin: addr,
            next_lottery_id: 1,
            next_request_id: 1,
            lotteries: table::new(),
            requests: table::new(),
            lottery_ids: vector::empty<u64>(),
            pending_request_ids: vector::empty<u64>(),
            callback_sender: option::none(),
            register_events: account::new_event_handle<LotteryRegisteredEvent>(caller),
            status_events: account::new_event_handle<LotteryStatusChangedEvent>(caller),
            metadata_events: account::new_event_handle<LotteryMetadataUpdatedEvent>(caller),
            request_events: account::new_event_handle<RandomnessRequestedEvent>(caller),
            fulfill_events: account::new_event_handle<RandomnessFulfilledEvent>(caller),
            callback_sender_events: account::new_event_handle<CallbackSenderUpdatedEvent>(caller),
        });
    }


    #[view]
    public fun is_initialized(): bool {
        exists<HubState>(@vrf_hub)
    }


    #[view]
    public fun admin(): address acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        state.admin
    }


    #[view]
    public fun peek_next_lottery_id(): u64 acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        state.next_lottery_id
    }


    public entry fun register_lottery(
        caller: &signer,
        owner: address,
        lottery: address,
        metadata: vector<u8>,
    ): u64 acquires HubState {
        ensure_admin(caller);
        let metadata_event = clone_bytes(&metadata);
        let state = borrow_global_mut<HubState>(@vrf_hub);
        let id = state.next_lottery_id;
        state.next_lottery_id = id + 1;
        table::add(
            &mut state.lotteries,
            id,
            LotteryRegistration { owner, lottery, metadata, active: true },
        );
        vector::push_back(&mut state.lottery_ids, id);
        event::emit_event(&mut state.register_events, LotteryRegisteredEvent { lottery_id: id, owner, lottery });
        event::emit_event(
            &mut state.metadata_events,
            LotteryMetadataUpdatedEvent { lottery_id: id, metadata: metadata_event },
        );
        id
    }


    public entry fun update_metadata(
        caller: &signer,
        lottery_id: u64,
        metadata: vector<u8>,
    ) acquires HubState {
        ensure_admin(caller);
        let metadata_event = clone_bytes(&metadata);
        let state = borrow_global_mut<HubState>(@vrf_hub);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let registration = table::borrow_mut(&mut state.lotteries, lottery_id);
        registration.metadata = metadata;
        event::emit_event(
            &mut state.metadata_events,
            LotteryMetadataUpdatedEvent { lottery_id, metadata: metadata_event },
        );
    }


    public entry fun set_lottery_active(
        caller: &signer,
        lottery_id: u64,
        active: bool,
    ) acquires HubState {
        ensure_admin(caller);
        let state = borrow_global_mut<HubState>(@vrf_hub);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let registration = table::borrow_mut(&mut state.lotteries, lottery_id);
        if (registration.active != active) {
            registration.active = active;
            event::emit_event(
                &mut state.status_events,
                LotteryStatusChangedEvent { lottery_id, active },
            );
        };
    }


    public entry fun set_admin(caller: &signer, new_admin: address) acquires HubState {
        ensure_admin(caller);
        let state = borrow_global_mut<HubState>(@vrf_hub);
        state.admin = new_admin;
    }


    #[view]
    public fun is_lottery_active(lottery_id: u64): bool acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        if (!table::contains(&state.lotteries, lottery_id)) {
            return false
        };
        table::borrow(&state.lotteries, lottery_id).active
    }


    #[view]
    public fun get_registration(lottery_id: u64): option::Option<LotteryRegistration> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        if (!table::contains(&state.lotteries, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.lotteries, lottery_id))
        }
    }


    #[view]
    public fun lottery_count(): u64 acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        table::length(&state.lotteries)
    }


    #[view]
    public fun list_lottery_ids(): vector<u64> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        clone_ids(&state.lottery_ids)
    }


    #[view]
    public fun list_active_lottery_ids(): vector<u64> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(&state.lottery_ids);
        while (i < len) {
            let id = *vector::borrow(&state.lottery_ids, i);
            if (table::contains(&state.lotteries, id)) {
                let registration = table::borrow(&state.lotteries, id);
                if (registration.active) {
                    vector::push_back(&mut result, id);
                };
            };
            i = i + 1;
        };
        result
    }


    public entry fun set_callback_sender(caller: &signer, sender: address) acquires HubState {
        ensure_admin(caller);
        let state = borrow_global_mut<HubState>(@vrf_hub);
        let previous = copy_option_address(&state.callback_sender);
        state.callback_sender = option::some(sender);
        event::emit_event(
            &mut state.callback_sender_events,
            CallbackSenderUpdatedEvent { previous, current: option::some(sender) },
        );
    }


    #[view]
    public fun callback_sender(): option::Option<address> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        state.callback_sender
    }

    #[view]
    public fun get_callback_sender_status(): CallbackSenderStatus acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        CallbackSenderStatus { sender: copy_option_address(&state.callback_sender) }
    }


    public fun request_randomness(lottery_id: u64, payload: vector<u8>): u64 acquires HubState {
        let state = borrow_global_mut<HubState>(@vrf_hub);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let registration = table::borrow(&state.lotteries, lottery_id);
        if (!registration.active) {
            abort E_INACTIVE_LOTTERY
        };

        let request_id = state.next_request_id;
        state.next_request_id = request_id + 1;
        let payload_for_event = clone_bytes(&payload);
        let payload_hash = compute_payload_hash(&payload);
        let hash_for_event = clone_bytes(&payload_hash);
        table::add(
            &mut state.requests,
            request_id,
            RequestRecord { lottery_id, payload, payload_hash },
        );
        vector::push_back(&mut state.pending_request_ids, request_id);
        event::emit_event(
            &mut state.request_events,
            RandomnessRequestedEvent {
                request_id,
                lottery_id,
                payload: payload_for_event,
                payload_hash: hash_for_event,
            },
        );
        request_id
    }


    public fun consume_request(request_id: u64): RequestRecord acquires HubState {
        let state = borrow_global_mut<HubState>(@vrf_hub);
        if (!table::contains(&state.requests, request_id)) {
            abort E_UNKNOWN_REQUEST
        };
        let record = table::remove(&mut state.requests, request_id);
        remove_pending_request_id(&mut state.pending_request_ids, request_id);
        record
    }


    #[view]
    public fun get_request(request_id: u64): option::Option<RequestRecord> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        if (!table::contains(&state.requests, request_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.requests, request_id))
        }
    }


    #[view]
    public fun list_pending_request_ids(): vector<u64> acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        clone_ids(&state.pending_request_ids)
    }


    public fun record_fulfillment(
        request_id: u64,
        lottery_id: u64,
        randomness: vector<u8>,
    ) acquires HubState {
        let state = borrow_global_mut<HubState>(@vrf_hub);
        let randomness_for_event = clone_bytes(&randomness);
        event::emit_event(
            &mut state.fulfill_events,
            RandomnessFulfilledEvent { request_id, lottery_id, randomness: randomness_for_event },
        );
    }

    public fun request_record_lottery_id(record: &RequestRecord): u64 {
        record.lottery_id
    }

    public fun request_record_payload(record: &RequestRecord): vector<u8> {
        clone_bytes(&record.payload)
    }

    public fun request_record_payload_hash(record: &RequestRecord): vector<u8> {
        clone_bytes(&record.payload_hash)
    }

    public fun registration_owner(registration: &LotteryRegistration): address {
        registration.owner
    }

    public fun registration_lottery(registration: &LotteryRegistration): address {
        registration.lottery
    }

    public fun registration_active(registration: &LotteryRegistration): bool {
        registration.active
    }

    #[test_only]
    public fun registration_fields_for_test(
        registration: &LotteryRegistration
    ): (address, address, vector<u8>, bool) {
        (
            registration.owner,
            registration.lottery,
            clone_bytes(&registration.metadata),
            registration.active,
        )
    }

    #[test_only]
    public fun request_record_fields_for_test(
        record: &RequestRecord
    ): (u64, vector<u8>, vector<u8>) {
        (
            record.lottery_id,
            clone_bytes(&record.payload),
            clone_bytes(&record.payload_hash),
        )
    }


    public fun ensure_callback_sender(caller: &signer) acquires HubState {
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        if (!option::is_some(&state.callback_sender)) {
            abort E_CALLBACK_NOT_CONFIGURED
        };
        let allowed = *option::borrow(&state.callback_sender);
        let addr = signer::address_of(caller);
        if (addr != allowed) {
            abort E_CALLBACK_NOT_ALLOWED
        };
    }

    fun copy_option_address(value: &option::Option<address>): option::Option<address> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none()
        }
    }

    #[test_only]
    public fun callback_sender_status_sender(status: &CallbackSenderStatus): option::Option<address> {
        status.sender
    }

    #[test_only]
    public fun callback_sender_event_fields_for_test(
        event: &CallbackSenderUpdatedEvent
    ): (option::Option<address>, option::Option<address>) {
        (event.previous, event.current)
    }

    fun ensure_admin(caller: &signer) acquires HubState {
        let addr = signer::address_of(caller);
        ensure_initialized();
        let state = borrow_global<HubState>(@vrf_hub);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_initialized() {
        if (!exists<HubState>(@vrf_hub)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let length = vector::length(data);
        let i = 0;
        let buffer = vector::empty<u8>();
        while (i < length) {
            let byte = *vector::borrow(data, i);
            vector::push_back(&mut buffer, byte);
            i = i + 1;
        };
        buffer
    }

    fun clone_ids(ids: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(ids);
        while (i < len) {
            let value = *vector::borrow(ids, i);
            vector::push_back(&mut result, value);
            i = i + 1;
        };
        result
    }

    fun compute_payload_hash(payload: &vector<u8>): vector<u8> {
        hash::sha3_256(clone_bytes(payload))
    }

    fun remove_pending_request_id(ids: &mut vector<u64>, request_id: u64) {
        let i = 0;
        let len = vector::length(ids);
        while (i < len) {
            let current = *vector::borrow(ids, i);
            if (current == request_id) {
                let last = vector::pop_back(ids);
                len = len - 1;
                if (i < len) {
                    let slot = vector::borrow_mut(ids, i);
                    *slot = last;
                };
                return
            };
            i = i + 1;
        };
    }
}
