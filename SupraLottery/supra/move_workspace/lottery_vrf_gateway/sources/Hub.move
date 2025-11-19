module lottery_vrf_gateway::hub {
    #[test_only]
    friend lottery_vrf_gateway::hub_tests;
    use std::hash;
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_vrf_gateway::table;
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

    public struct LegacyLotteryRegistration has drop, store {
        lottery_id: u64,
        owner: address,
        lottery: address,
        metadata: vector<u8>,
        active: bool,
    }

    public struct LegacyRequestRecord has drop, store {
        request_id: u64,
        lottery_id: u64,
        payload: vector<u8>,
        payload_hash: vector<u8>,
    }

    public struct LegacyHubState has drop, store {
        admin: address,
        next_lottery_id: u64,
        next_request_id: u64,
        lotteries: vector<LegacyLotteryRegistration>,
        requests: vector<LegacyRequestRecord>,
        lottery_ids: vector<u64>,
        pending_request_ids: vector<u64>,
        callback_sender: option::Option<address>,
    }

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

    public entry fun import_existing_state(caller: &signer, payload: LegacyHubState)
    acquires HubState {
        import_state_internal(caller, payload);
    }

    public entry fun migrate_lottery_vrf_gateway_state(caller: &signer, payload: LegacyHubState)
    acquires HubState {
        import_state_internal(caller, payload);
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

    struct HubSnapshot has copy, drop, store {
        admin: address,
        next_lottery_id: u64,
        next_request_id: u64,
        lotteries: vector<LotteryRegistration>,
        requests: vector<RequestRecord>,
        lottery_ids: vector<u64>,
        pending_request_ids: vector<u64>,
        callback_sender: option::Option<address>,
    }

    struct LotteryRegistrationSnapshot has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery: address,
        metadata: vector<u8>,
        active: bool,
    }

    struct RequestSnapshot has copy, drop, store {
        request_id: u64,
        lottery_id: u64,
        payload: vector<u8>,
        payload_hash: vector<u8>,
        pending: bool,
    }

    #[view]
    public fun is_initialized(): bool {
        exists<HubState>(@lottery_vrf_gateway)
    }

    #[view]
    public fun hub_snapshot(): HubSnapshot acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let HubState {
            admin,
            next_lottery_id,
            next_request_id,
            lotteries,
            requests,
            lottery_ids,
            pending_request_ids,
            callback_sender,
            register_events: _,
            status_events: _,
            metadata_events: _,
            request_events: _,
            fulfill_events: _,
            callback_sender_events: _,
        } = borrow_global<HubState>(@lottery_vrf_gateway);
        HubSnapshot {
            admin,
            next_lottery_id,
            next_request_id,
            lotteries: clone_lotteries(lotteries),
            requests: clone_requests(requests),
            lottery_ids: clone_u64_vector(lottery_ids),
            pending_request_ids: clone_u64_vector(pending_request_ids),
            callback_sender: option::copy(callback_sender),
        }
    }

    #[view]
    public fun lottery_snapshot(lottery_id: u64): option::Option<LotteryRegistrationSnapshot>
    acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let state = borrow_global<HubState>(@lottery_vrf_gateway);
        if (!table::contains(&state.lotteries, lottery_id)) {
            option::none<LotteryRegistrationSnapshot>()
        } else {
            let registration = table::borrow(&state.lotteries, lottery_id);
            option::some(LotteryRegistrationSnapshot {
                lottery_id,
                owner: registration.owner,
                lottery: registration.lottery,
                metadata: clone_bytes(&registration.metadata),
                active: registration.active,
            })
        }
    }

    #[view]
    public fun request_snapshot(request_id: u64): option::Option<RequestSnapshot> acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let state = borrow_global<HubState>(@lottery_vrf_gateway);
        if (!table::contains(&state.requests, request_id)) {
            option::none<RequestSnapshot>()
        } else {
            let record = table::borrow(&state.requests, request_id);
            let (pending, _) = find_pending_request_index(&state.pending_request_ids, request_id);
            option::some(RequestSnapshot {
                request_id,
                lottery_id: record.lottery_id,
                payload: clone_bytes(&record.payload),
                payload_hash: clone_bytes(&record.payload_hash),
                pending,
            })
        }
    }

    #[view]
    public fun callback_sender_status(): CallbackSenderStatus acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let HubState { callback_sender, .. } = borrow_global<HubState>(@lottery_vrf_gateway);
        CallbackSenderStatus { sender: option::copy(callback_sender) }
    }

    public fun ensure_callback_sender(caller: &signer) acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let state = borrow_global<HubState>(@lottery_vrf_gateway);
        assert!(option::is_some(&state.callback_sender), E_CALLBACK_NOT_CONFIGURED);
        let allowed = *option::borrow(&state.callback_sender);
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == allowed, E_CALLBACK_NOT_ALLOWED);
    }

    public fun request_randomness(lottery_id: u64, payload: vector<u8>): u64 acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(table::contains(&state.lotteries, lottery_id), E_UNKNOWN_LOTTERY);
        let registration = table::borrow(&state.lotteries, lottery_id);
        assert!(registration.active, E_INACTIVE_LOTTERY);

        let request_id = state.next_request_id;
        state.next_request_id = request_id + 1;
        let payload_hash = hash::sha3_256(&payload);
        let payload_for_store = clone_bytes(&payload);
        table::add(
            &mut state.requests,
            request_id,
            RequestRecord { lottery_id, payload: payload_for_store, payload_hash: clone_bytes(&payload_hash) },
        );
        vector::push_back(&mut state.pending_request_ids, request_id);
        event::emit_event(
            &mut state.request_events,
            RandomnessRequestedEvent { request_id, lottery_id, payload: clone_bytes(&payload), payload_hash },
        );
        request_id
    }

    public fun consume_request(request_id: u64): RequestRecord acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(table::contains(&state.requests, request_id), E_UNKNOWN_REQUEST);
        let record = table::remove(&mut state.requests, request_id);
        remove_pending_request_id(&mut state.pending_request_ids, request_id);
        record
    }

    #[view]
    public fun get_request(request_id: u64): option::Option<RequestRecord> acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let state = borrow_global<HubState>(@lottery_vrf_gateway);
        if (!table::contains(&state.requests, request_id)) {
            option::none<RequestRecord>()
        } else {
            option::some(*table::borrow(&state.requests, request_id))
        }
    }

    #[view]
    public fun list_pending_request_ids(): vector<u64> acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        let state = borrow_global<HubState>(@lottery_vrf_gateway);
        clone_u64_vector(&state.pending_request_ids)
    }

    public fun record_fulfillment(
        request_id: u64,
        lottery_id: u64,
        randomness: vector<u8>,
    ) acquires HubState {
        let state = borrow_hub_state_mut();
        event::emit_event(
            &mut state.fulfill_events,
            RandomnessFulfilledEvent { request_id, lottery_id, randomness: clone_bytes(&randomness) },
        );
    }

    public fun request_record_lottery_id(record: &RequestRecord): u64 {
        record.lottery_id
    }

    public fun request_record_payload(record: &RequestRecord): vector<u8> {
        clone_bytes(&record.payload)
    }

    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        assert!(addr == @lottery_vrf_gateway, E_NOT_AUTHORIZED);
        assert!(!exists<HubState>(@lottery_vrf_gateway), E_ALREADY_INIT);
        move_to(
            caller,
            HubState {
                admin: addr,
                next_lottery_id: 0,
                next_request_id: 0,
                lotteries: table::new<u64, LotteryRegistration>(),
                requests: table::new<u64, RequestRecord>(),
                lottery_ids: vector::empty<u64>(),
                pending_request_ids: vector::empty<u64>(),
                callback_sender: option::none<address>(),
                register_events: account::new_event_handle<LotteryRegisteredEvent>(caller),
                status_events: account::new_event_handle<LotteryStatusChangedEvent>(caller),
                metadata_events: account::new_event_handle<LotteryMetadataUpdatedEvent>(caller),
                request_events: account::new_event_handle<RandomnessRequestedEvent>(caller),
                fulfill_events: account::new_event_handle<RandomnessFulfilledEvent>(caller),
                callback_sender_events: account::new_event_handle<CallbackSenderUpdatedEvent>(caller),
            },
        );
    }

    public entry fun register_lottery(caller: &signer, owner: address, lottery: address, metadata: vector<u8>)
    acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        let id = state.next_lottery_id;
        state.next_lottery_id = id + 1;
        table::add(&mut state.lotteries, id, LotteryRegistration { owner, lottery, metadata, active: true });
        vector::push_back(&mut state.lottery_ids, id);
        event::emit_event(
            &mut state.register_events,
            LotteryRegisteredEvent { lottery_id: id, owner, lottery },
        );
    }

    public entry fun change_status(caller: &signer, id: u64, active: bool) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        let registration = table::borrow_mut(&mut state.lotteries, id);
        registration.active = active;
        event::emit_event(
            &mut state.status_events,
            LotteryStatusChangedEvent { lottery_id: id, active },
        );
    }

    public entry fun update_metadata(caller: &signer, id: u64, metadata: vector<u8>) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        assert!(table::contains(&state.lotteries, id), E_UNKNOWN_LOTTERY);
        let registration = table::borrow_mut(&mut state.lotteries, id);
        registration.metadata = metadata;
        event::emit_event(
            &mut state.metadata_events,
            LotteryMetadataUpdatedEvent { lottery_id: id, metadata: clone_bytes(&registration.metadata) },
        );
    }

    public entry fun set_callback_sender(caller: &signer, sender: option::Option<address>) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        apply_callback_sender(state, sender);
    }

    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
        payload_hash: vector<u8>,
    ) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        assert!(table::contains(&state.lotteries, lottery_id), E_UNKNOWN_LOTTERY);
        let registration = table::borrow(&state.lotteries, lottery_id);
        assert!(registration.active, E_INACTIVE_LOTTERY);
        let id = state.next_request_id;
        state.next_request_id = id + 1;
        table::add(
            &mut state.requests,
            id,
            RequestRecord { lottery_id, payload: clone_bytes(&payload), payload_hash: clone_bytes(&payload_hash) },
        );
        vector::push_back(&mut state.pending_request_ids, id);
        event::emit_event(
            &mut state.request_events,
            RandomnessRequestedEvent { request_id: id, lottery_id, payload: clone_bytes(&payload), payload_hash },
        );
    }

    public entry fun fulfill_randomness(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        assert!(option::is_some(&state.callback_sender), E_CALLBACK_NOT_CONFIGURED);
        assert!(table::contains(&state.requests, request_id), E_UNKNOWN_REQUEST);
        let request = table::borrow(&state.requests, request_id);
        assert!(table::contains(&state.lotteries, request.lottery_id), E_UNKNOWN_LOTTERY);
        let registration = table::borrow(&state.lotteries, request.lottery_id);
        assert!(registration.active, E_INACTIVE_LOTTERY);
        event::emit_event(
            &mut state.fulfill_events,
            RandomnessFulfilledEvent { request_id, lottery_id: request.lottery_id, randomness: clone_bytes(&randomness) },
        );
        let (found, index) = find_pending_request_index(&state.pending_request_ids, request_id);
        if (found) {
            vector::swap_remove(&mut state.pending_request_ids, index);
        };
    }

    public entry fun fulfill_randomness_with_callback(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
        payload: vector<u8>,
    ) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        assert!(option::is_some(&state.callback_sender), E_CALLBACK_NOT_CONFIGURED);
        let sender_opt = option::borrow(&state.callback_sender);
        assert!(option::is_some(sender_opt), E_CALLBACK_NOT_CONFIGURED);
        let sender = option::destroy_some(sender_opt);
        let caller_addr = signer::address_of(caller);
        assert!(sender == caller_addr, E_CALLBACK_NOT_ALLOWED);
        assert!(table::contains(&state.requests, request_id), E_UNKNOWN_REQUEST);
        let request = table::borrow(&state.requests, request_id);
        assert!(table::contains(&state.lotteries, request.lottery_id), E_UNKNOWN_LOTTERY);
        let registration = table::borrow(&state.lotteries, request.lottery_id);
        assert!(registration.active, E_INACTIVE_LOTTERY);
        let payload_hash = hash::sha3_256(&payload);
        assert!(payload_hash == request.payload_hash, E_CALLBACK_NOT_ALLOWED);
        event::emit_event(
            &mut state.fulfill_events,
            RandomnessFulfilledEvent { request_id, lottery_id: request.lottery_id, randomness: clone_bytes(&randomness) },
        );
        let (found, index) = find_pending_request_index(&state.pending_request_ids, request_id);
        if (found) {
            vector::swap_remove(&mut state.pending_request_ids, index);
        };
    }

    public entry fun remove_request(caller: &signer, request_id: u64) acquires HubState {
        let state = borrow_hub_state_mut();
        assert!(is_admin(state, caller), E_NOT_AUTHORIZED);
        assert!(table::contains(&state.requests, request_id), E_UNKNOWN_REQUEST);
        table::remove(&mut state.requests, request_id);
        let (found, index) = find_pending_request_index(&state.pending_request_ids, request_id);
        if (found) {
            vector::swap_remove(&mut state.pending_request_ids, index);
        };
    }

    fun import_state_internal(caller: &signer, payload: LegacyHubState) acquires HubState {
        ensure_migration_signer(caller);
        let LegacyHubState {
            admin,
            next_lottery_id,
            next_request_id,
            lotteries,
            requests,
            lottery_ids,
            pending_request_ids,
            callback_sender,
        } = payload;
        reset_state(caller);
        move_to(
            caller,
            HubState {
                admin,
                next_lottery_id,
                next_request_id,
                lotteries: table::new(),
                requests: table::new(),
                lottery_ids: clone_u64_vector(&lottery_ids),
                pending_request_ids: clone_u64_vector(&pending_request_ids),
                callback_sender,
                register_events: account::new_event_handle<LotteryRegisteredEvent>(caller),
                status_events: account::new_event_handle<LotteryStatusChangedEvent>(caller),
                metadata_events: account::new_event_handle<LotteryMetadataUpdatedEvent>(caller),
                request_events: account::new_event_handle<RandomnessRequestedEvent>(caller),
                fulfill_events: account::new_event_handle<RandomnessFulfilledEvent>(caller),
                callback_sender_events: account::new_event_handle<CallbackSenderUpdatedEvent>(caller),
            },
        );
        let state = borrow_global_mut<HubState>(@lottery_vrf_gateway);
        apply_callback_sender(state, option::none<address>());
        import_registrations(state, &lotteries);
        import_requests(state, &requests);
    }

    fun apply_callback_sender(state: &mut HubState, sender: option::Option<address>) {
        let previous = option::copy(&state.callback_sender);
        state.callback_sender = sender;
        event::emit_event(&mut state.callback_sender_events, CallbackSenderUpdatedEvent { previous, current: option::copy(&state.callback_sender) });
    }

    fun import_registrations(state: &mut HubState, registrations: &vector<LegacyLotteryRegistration>) {
        let len = vector::length(registrations);
        let i = 0;
        while (i < len) {
            let reg_ref = vector::borrow(registrations, i);
            let reg = copy *reg_ref;
            table::add(
                &mut state.lotteries,
                reg.lottery_id,
                LotteryRegistration { owner: reg.owner, lottery: reg.lottery, metadata: clone_bytes(&reg.metadata), active: reg.active },
            );
            i = i + 1;
        };
    }

    fun import_requests(state: &mut HubState, requests: &vector<LegacyRequestRecord>) {
        let len = vector::length(requests);
        let i = 0;
        while (i < len) {
            let req_ref = vector::borrow(requests, i);
            let req = copy *req_ref;
            table::add(
                &mut state.requests,
                req.request_id,
                RequestRecord { lottery_id: req.lottery_id, payload: clone_bytes(&req.payload), payload_hash: clone_bytes(&req.payload_hash) },
            );
            i = i + 1;
        };
    }

    fun ensure_migration_signer(caller: &signer) {
        let addr = signer::address_of(caller);
        assert!(addr == @lottery_vrf_gateway || addr == @lottery, E_NOT_AUTHORIZED);
    }

    fun borrow_hub_state_mut(): &mut HubState acquires HubState {
        assert!(exists<HubState>(@lottery_vrf_gateway), E_NOT_INITIALIZED);
        borrow_global_mut<HubState>(@lottery_vrf_gateway)
    }

    fun is_admin(state: &HubState, caller: &signer): bool {
        let caller_addr = signer::address_of(caller);
        caller_addr == state.admin
    }

    fun find_pending_request_index(requests: &vector<u64>, request_id: u64): (bool, u64) {
        let len = vector::length(requests);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(requests, i) == request_id) {
                return (true, i)
            };
            i = i + 1;
        };
        (false, 0)
    }

    fun remove_pending_request_id(requests: &mut vector<u64>, request_id: u64) {
        let (found, index) = find_pending_request_index(requests, request_id);
        if (found) {
            vector::swap_remove(requests, index);
        };
    }

    fun reset_state(caller: &signer) acquires HubState {
        if (!exists<HubState>(@lottery_vrf_gateway)) {
            return
        };
        let HubState {
            admin: _,
            next_lottery_id: _,
            next_request_id: _,
            lotteries: _,
            requests: _,
            lottery_ids: _,
            pending_request_ids: _,
            callback_sender: _,
            register_events: _,
            status_events: _,
            metadata_events: _,
            request_events: _,
            fulfill_events: _,
            callback_sender_events: _,
        } = move_from<HubState>(@lottery_vrf_gateway);
        account::remove_event_handle<LotteryRegisteredEvent>(caller);
        account::remove_event_handle<LotteryStatusChangedEvent>(caller);
        account::remove_event_handle<LotteryMetadataUpdatedEvent>(caller);
        account::remove_event_handle<RandomnessRequestedEvent>(caller);
        account::remove_event_handle<RandomnessFulfilledEvent>(caller);
        account::remove_event_handle<CallbackSenderUpdatedEvent>(caller);
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let out = vector::empty<u8>();
        let i = 0;
        while (i < len) {
            let value_ref = vector::borrow(source, i);
            vector::push_back(&mut out, *value_ref);
            i = i + 1;
        };
        out
    }

    fun clone_u64_vector(source: &vector<u64>): vector<u64> {
        let len = vector::length(source);
        let out = vector::empty<u64>();
        let i = 0;
        while (i < len) {
            let value_ref = vector::borrow(source, i);
            vector::push_back(&mut out, *value_ref);
            i = i + 1;
        };
        out
    }

    fun clone_lotteries(source: &table::Table<u64, LotteryRegistration>): vector<LotteryRegistration> {
        let keys = table::keys(source);
        let len = vector::length(&keys);
        let lotteries = vector::empty<LotteryRegistration>();
        let i = 0;
        while (i < len) {
            let key_ref = vector::borrow(&keys, i);
            let lottery = table::borrow(source, *key_ref);
            vector::push_back(&mut lotteries, LotteryRegistration {
                owner: lottery.owner,
                lottery: lottery.lottery,
                metadata: clone_bytes(&lottery.metadata),
                active: lottery.active,
            });
            i = i + 1;
        };
        lotteries
    }

    fun clone_requests(source: &table::Table<u64, RequestRecord>): vector<RequestRecord> {
        let keys = table::keys(source);
        let len = vector::length(&keys);
        let requests = vector::empty<RequestRecord>();
        let i = 0;
        while (i < len) {
            let key_ref = vector::borrow(&keys, i);
            let request = table::borrow(source, *key_ref);
            vector::push_back(
                &mut requests,
                RequestRecord {
                    lottery_id: request.lottery_id,
                    payload: clone_bytes(&request.payload),
                    payload_hash: clone_bytes(&request.payload_hash),
                },
            );
            i = i + 1;
        };
        requests
    }
}
