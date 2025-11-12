// sources/draw.move
module lottery_multi::draw {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::string;
    use std::table;
    use std::vector;

    use supra_addr::supra_vrf;
    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::feature_switch;
    use lottery_multi::history;
    use lottery_multi::registry;
    use lottery_multi::sales;
    use lottery_multi::types;
    use lottery_multi::vrf_deposit;

    const CALLBACK_MODULE_BYTES: vector<u8> = b"draw";
    const CALLBACK_FUNCTION_BYTES: vector<u8> = b"vrf_callback";
    const VRF_EVENT_VERSION_V1: u16 = 1;
    const RETRY_DELAY_SECS: u64 = 600;
    const MAX_CLIENT_SEED: u64 = 0xffffffffffffffff;

    struct PayloadV1 has drop, store {
        lottery_id: u64,
        config_version: u64,
        snapshot_hash: vector<u8>,
        slots_checksum: vector<u8>,
        rng_count: u8,
        client_seed: u64,
        attempt: u8,
        closing_block_height: u64,
        chain_id: u8,
    }

    pub struct FinalizationSnapshot has copy, drop, store {
        pub snapshot_hash: vector<u8>,
        pub payload_hash: vector<u8>,
        pub winners_batch_hash: vector<u8>,
        pub checksum_after_batch: vector<u8>,
        pub schema_version: u16,
        pub attempt: u8,
        pub closing_block_height: u64,
        pub chain_id: u8,
        pub request_ts: u64,
        pub vrf_status: u8,
    }

    struct DrawState has store {
        vrf_state: types::VrfState,
        rng_count: u8,
        client_seed: u64,
        last_request_ts: u64,
        snapshot_hash: vector<u8>,
        total_tickets: u64,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
        verified_payload: vector<u8>,
        payload: vector<u8>,
        next_client_seed: u64,
    }

    pub struct VrfStateView has copy, drop, store {
        pub status: u8,
        pub attempt: u8,
        pub consumed: bool,
        pub retry_after_ts: u64,
        pub retry_strategy: u8,
        pub last_request_ts: u64,
        pub request_id: u64,
    }

    struct DrawLedger has key {
        states: table::Table<u64, DrawState>,
        nonce_to_lottery: table::Table<u64, u64>,
        requested_events: event::EventHandle<history::VrfRequestedEvent>,
        fulfilled_events: event::EventHandle<history::VrfFulfilledEvent>,
    }

    public entry fun init_draw(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_REGISTRY_MISSING);
        assert!(!exists<DrawLedger>(addr), errors::E_ALREADY_INITIALIZED);
        let ledger = DrawLedger {
            states: table::new(),
            nonce_to_lottery: table::new(),
            requested_events: event::new_event_handle<history::VrfRequestedEvent>(admin),
            fulfilled_events: event::new_event_handle<history::VrfFulfilledEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public entry fun request_draw_admin(
        admin: &signer,
        lottery_id: u64,
        now_ts: u64,
        closing_block_height: u64,
        chain_id: u8,
        num_confirmations: u64,
    ) acquires DrawLedger, registry::Registry, sales::SalesLedger {
        ensure_feature_enabled(false);
        vrf_deposit::ensure_requests_allowed();
        let status = registry::get_status(lottery_id);
        assert!(
            status == registry::STATUS_CLOSING || status == registry::STATUS_DRAW_REQUESTED,
            errors::E_DRAW_STATUS_INVALID,
        );

        let config = registry::borrow_config(lottery_id);
        let prize_slots_len = vector::length(&config.prize_plan);
        types::assert_rng_count(prize_slots_len);
        let rng_count = types::as_u8(prize_slots_len);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(lottery_id);
        assert!(tickets_sold > 0, errors::E_VRF_SNAPSHOT_EMPTY);

        let ledger = borrow_ledger_mut();
        let state = borrow_or_create_state(&mut ledger.states, lottery_id);
        assert!(state.vrf_state.status != types::VRF_STATUS_REQUESTED, errors::E_VRF_PENDING);
        if (state.vrf_state.status == types::VRF_STATUS_FULFILLED) {
            assert!(state.vrf_state.consumed, errors::E_VRF_PENDING);
        };
        if (state.vrf_state.retry_after_ts > 0 && now_ts < state.vrf_state.retry_after_ts) {
            abort errors::E_VRF_RETRY_WINDOW;
        };

        let attempt = increment_attempt(&mut state.vrf_state);
        state.rng_count = rng_count;
        let client_seed = next_client_seed(state);
        let slots_checksum = registry::slots_checksum(lottery_id);
        let payload = encode_payload_v1(
            lottery_id,
            config.config_version,
            &snapshot_hash,
            &slots_checksum,
            rng_count,
            client_seed,
            attempt,
            closing_block_height,
            chain_id,
        );
        let payload_hash = hash::sha3_256(copy payload);

        let module_name = string::utf8(callback_module_bytes());
        let function_name = string::utf8(callback_function_bytes());
        let callback_address = @lottery_multi;
        let nonce = supra_vrf::rng_request(
            admin,
            callback_address,
            module_name,
            function_name,
            rng_count,
            client_seed,
            num_confirmations,
        );

        state.vrf_state.request_id = nonce;
        state.vrf_state.payload_hash = copy payload_hash;
        state.vrf_state.schema_version = types::DEFAULT_SCHEMA_VERSION;
        state.vrf_state.status = types::VRF_STATUS_REQUESTED;
        state.vrf_state.consumed = false;
        state.vrf_state.retry_after_ts = now_ts + RETRY_DELAY_SECS;
        state.vrf_state.retry_strategy = types::RETRY_STRATEGY_FIXED;
        state.vrf_state.closing_block_height = closing_block_height;
        state.vrf_state.chain_id = chain_id;
        state.client_seed = client_seed;
        state.last_request_ts = now_ts;
        state.snapshot_hash = copy snapshot_hash;
        state.total_tickets = tickets_sold;
        state.payload = copy payload;
        state.verified_payload = b"";
        state.winners_batch_hash = b"";
        state.checksum_after_batch = b"";

        if (table::contains(&ledger.nonce_to_lottery, nonce)) {
            abort errors::E_VRF_NONCE_UNKNOWN;
        };
        table::add(&mut ledger.nonce_to_lottery, nonce, lottery_id);

        let requested = history::VrfRequestedEvent {
            event_version: VRF_EVENT_VERSION_V1,
            event_category: history::EVENT_CATEGORY_DRAW,
            lottery_id,
            request_id: nonce,
            attempt,
            rng_count,
            client_seed,
            payload_hash: copy payload_hash,
            snapshot_hash: copy snapshot_hash,
            tickets_sold,
            closing_block_height,
            chain_id,
            request_ts: now_ts,
        };
        event::emit_event(&mut ledger.requested_events, requested);

        registry::mark_draw_requested(lottery_id);
    }

    public entry fun vrf_callback(
        nonce: u64,
        message: vector<u8>,
        signature: vector<u8>,
        caller_address: address,
        rng_count: u8,
        client_seed: u64,
    ) acquires DrawLedger, registry::Registry {
        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.nonce_to_lottery, nonce)) {
            abort errors::E_VRF_NONCE_UNKNOWN;
        };
        let lottery_id = table::remove(&mut ledger.nonce_to_lottery, nonce);
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(state.vrf_state.request_id == nonce, errors::E_VRF_NONCE_UNKNOWN);
        assert!(state.vrf_state.status == types::VRF_STATUS_REQUESTED, errors::E_VRF_NOT_REQUESTED);
        assert!(!state.vrf_state.consumed, errors::E_VRF_CONSUMED);
        assert!(state.rng_count == rng_count, errors::E_VRF_RNG_COUNT_INVALID);
        assert!(state.client_seed == client_seed, errors::E_VRF_PAYLOAD_MISMATCH);

        let message_hash = hash::sha3_256(copy message);
        assert!(message_hash == state.vrf_state.payload_hash, errors::E_VRF_PAYLOAD_MISMATCH);

        let verified_nums: vector<u256> = supra_vrf::verify_callback(
            nonce,
            copy message,
            signature,
            caller_address,
            rng_count,
            client_seed,
        );
        let verified_bytes = bcs::to_bytes(&verified_nums);
        let verified_seed_hash = hash::sha3_256(copy verified_bytes);

        state.verified_payload = verified_bytes;
        state.vrf_state.status = types::VRF_STATUS_FULFILLED;
        state.vrf_state.consumed = false;
        state.vrf_state.retry_after_ts = 0;

        let fulfilled = history::VrfFulfilledEvent {
            event_version: VRF_EVENT_VERSION_V1,
            event_category: history::EVENT_CATEGORY_DRAW,
            lottery_id,
            request_id: nonce,
            attempt: state.vrf_state.attempt,
            payload_hash: copy state.vrf_state.payload_hash,
            message_hash,
            rng_count,
            client_seed,
            verified_seed_hash,
            closing_block_height: state.vrf_state.closing_block_height,
            chain_id: state.vrf_state.chain_id,
            fulfilled_ts: state.last_request_ts,
        };
        event::emit_event(&mut ledger.fulfilled_events, fulfilled);

        registry::mark_drawn(lottery_id);
    }

    fun ensure_feature_enabled(has_premium: bool) {
        if (feature_switch::is_initialized()) {
            let enabled = feature_switch::is_enabled(feature_switch::FEATURE_DRAW, has_premium);
            assert!(enabled, errors::E_FEATURE_DISABLED);
        };
    }

    public fun prepare_for_winner_computation(
        lottery_id: u64,
    ): (
        vector<u256>,
        vector<u8>,
        vector<u8>,
        u64,
        u16,
        u8,
    ) acquires DrawLedger {
        let ledger = borrow_ledger_mut();
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(
            state.vrf_state.status == types::VRF_STATUS_FULFILLED,
            errors::E_WINNER_VRF_NOT_READY,
        );
        assert!(!state.vrf_state.consumed, errors::E_VRF_CONSUMED);
        let numbers: vector<u256> = bcs::from_bytes(&state.verified_payload);
        state.vrf_state.consumed = true;
        (
            numbers,
            copy state.snapshot_hash,
            copy state.vrf_state.payload_hash,
            state.total_tickets,
            state.vrf_state.schema_version,
            state.vrf_state.attempt,
        )
    }

    public fun record_winner_hashes(
        lottery_id: u64,
        winners_batch_hash: &vector<u8>,
        checksum_after_batch: &vector<u8>,
    ) acquires DrawLedger {
        let ledger = borrow_ledger_mut();
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        state.winners_batch_hash = copy *winners_batch_hash;
        state.checksum_after_batch = copy *checksum_after_batch;
    }

    #[test_only]
    public fun test_seed_vrf_state(
        lottery_id: u64,
        numbers: vector<u256>,
        snapshot_hash: vector<u8>,
        payload_hash: vector<u8>,
        total_tickets: u64,
        schema_version: u16,
        attempt: u8,
        closing_block_height: u64,
        chain_id: u8,
    ) acquires DrawLedger {
        let ledger = borrow_ledger_mut();
        let state = borrow_or_create_state(&mut ledger.states, lottery_id);
        let rng_len = vector::length(&numbers);
        let rng_count = types::as_u8(rng_len);
        state.rng_count = rng_count;
        state.total_tickets = total_tickets;
        state.snapshot_hash = copy snapshot_hash;
        state.vrf_state.status = types::VRF_STATUS_FULFILLED;
        state.vrf_state.consumed = false;
        state.vrf_state.schema_version = schema_version;
        state.vrf_state.attempt = attempt;
        state.vrf_state.retry_after_ts = 0;
        state.vrf_state.retry_strategy = types::RETRY_STRATEGY_FIXED;
        state.vrf_state.closing_block_height = closing_block_height;
        state.vrf_state.chain_id = chain_id;
        state.vrf_state.payload_hash = copy payload_hash;
        state.vrf_state.request_id = 0;
        state.client_seed = 0;
        state.last_request_ts = 0;
        state.payload = b"";
        let verified = bcs::to_bytes(&numbers);
        state.verified_payload = verified;
        state.winners_batch_hash = b"";
        state.checksum_after_batch = b"";
    }

    #[test_only]
    public fun test_override_vrf_state(
        lottery_id: u64,
        status: u8,
        consumed: bool,
        retry_after_ts: u64,
        attempt: u8,
    ) acquires DrawLedger {
        let ledger = borrow_ledger_mut();
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        state.vrf_state.status = status;
        state.vrf_state.consumed = consumed;
        state.vrf_state.retry_after_ts = retry_after_ts;
        state.vrf_state.attempt = attempt;
    }

    pub fun finalization_snapshot(lottery_id: u64): FinalizationSnapshot acquires DrawLedger {
        let ledger = borrow_ledger_ref();
        let state = table::borrow(&ledger.states, lottery_id);
        FinalizationSnapshot {
            snapshot_hash: copy state.snapshot_hash,
            payload_hash: copy state.vrf_state.payload_hash,
            winners_batch_hash: copy state.winners_batch_hash,
            checksum_after_batch: copy state.checksum_after_batch,
            schema_version: state.vrf_state.schema_version,
            attempt: state.vrf_state.attempt,
            closing_block_height: state.vrf_state.closing_block_height,
            chain_id: state.vrf_state.chain_id,
            request_ts: state.last_request_ts,
            vrf_status: state.vrf_state.status,
        }
    }

    pub fun vrf_state_view(lottery_id: u64): VrfStateView acquires DrawLedger {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            return VrfStateView {
                status: types::VRF_STATUS_IDLE,
                attempt: 0,
                consumed: true,
                retry_after_ts: 0,
                retry_strategy: types::RETRY_STRATEGY_FIXED,
                last_request_ts: 0,
                request_id: 0,
            };
        };
        let ledger = borrow_ledger_ref();
        if (!table::contains(&ledger.states, lottery_id)) {
            return VrfStateView {
                status: types::VRF_STATUS_IDLE,
                attempt: 0,
                consumed: true,
                retry_after_ts: 0,
                retry_strategy: types::RETRY_STRATEGY_FIXED,
                last_request_ts: 0,
                request_id: 0,
            };
        };
        let state = table::borrow(&ledger.states, lottery_id);
        VrfStateView {
            status: state.vrf_state.status,
            attempt: state.vrf_state.attempt,
            consumed: state.vrf_state.consumed,
            retry_after_ts: state.vrf_state.retry_after_ts,
            retry_strategy: state.vrf_state.retry_strategy,
            last_request_ts: state.last_request_ts,
            request_id: state.vrf_state.request_id,
        }
    }

    fun borrow_ledger_mut(): &mut DrawLedger acquires DrawLedger {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global_mut<DrawLedger>(addr)
    }

    fun borrow_ledger_ref(): &DrawLedger acquires DrawLedger {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            abort errors::E_REGISTRY_MISSING;
        };
        borrow_global<DrawLedger>(addr)
    }

    fun borrow_or_create_state(states: &mut table::Table<u64, DrawState>, id: u64): &mut DrawState {
        if (!table::contains(states, id)) {
            let state = DrawState {
                vrf_state: types::new_vrf_state(),
                rng_count: 0,
                client_seed: 0,
                last_request_ts: 0,
                snapshot_hash: b"",
                total_tickets: 0,
                winners_batch_hash: b"",
                checksum_after_batch: b"",
                verified_payload: b"",
                payload: b"",
                next_client_seed: 0,
            };
            table::add(states, id, state);
        };
        table::borrow_mut(states, id)
    }

    fun next_client_seed(state: &mut DrawState): u64 {
        let current = state.next_client_seed;
        assert!(current < MAX_CLIENT_SEED, errors::E_VRF_CLIENT_SEED_OVERFLOW);
        state.next_client_seed = current + 1;
        current
    }

    fun increment_attempt(vrf_state: &mut types::VrfState): u8 {
        let current = vrf_state.attempt;
        assert!(current < 255, errors::E_VRF_ATTEMPT_OUT_OF_ORDER);
        let next = current + 1;
        vrf_state.attempt = next;
        next
    }

    fun encode_payload_v1(
        lottery_id: u64,
        config_version: u64,
        snapshot_hash: &vector<u8>,
        slots_checksum: &vector<u8>,
        rng_count: u8,
        client_seed: u64,
        attempt: u8,
        closing_block_height: u64,
        chain_id: u8,
    ): vector<u8> {
        let payload = PayloadV1 {
            lottery_id,
            config_version,
            snapshot_hash: copy *snapshot_hash,
            slots_checksum: copy *slots_checksum,
            rng_count,
            client_seed,
            attempt,
            closing_block_height,
            chain_id,
        };
        bcs::to_bytes(&payload)
    }

    fun callback_module_bytes(): vector<u8> {
        copy CALLBACK_MODULE_BYTES
    }

    fun callback_function_bytes(): vector<u8> {
        copy CALLBACK_FUNCTION_BYTES
    }
}
