// sources/draw.move
module lottery_multi::draw {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::string;
    use std::table;
    use std::vector;

    use supra_addr::supra_vrf;
    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::cancellation;
    use lottery_multi::errors;
    use lottery_multi::feature_switch;
    use lottery_multi::history;
    use lottery_multi::lottery_registry;
    use lottery_multi::sales;
    use lottery_multi::types;
    use lottery_multi::vrf_deposit;

    const EVENT_CATEGORY_DRAW: u8 = 4;
    const CALLBACK_MODULE_BYTES: vector<u8> = b"draw";
    const CALLBACK_FUNCTION_BYTES: vector<u8> = b"vrf_callback";
    const VRF_EVENT_VERSION_V1: u16 = 1;
    const MAX_VRF_ATTEMPTS: u8 = 5;
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

    struct FinalizationSnapshot has copy, drop, store {
        snapshot_hash: vector<u8>,
        payload_hash: vector<u8>,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
        schema_version: u16,
        attempt: u8,
        closing_block_height: u64,
        chain_id: u8,
        request_ts: u64,
        vrf_status: u8,
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
        verified_numbers: vector<u256>,
        payload: vector<u8>,
        next_client_seed: u64,
    }

    struct VrfStateView has copy, drop, store {
        status: u8,
        attempt: u8,
        consumed: bool,
        retry_after_ts: u64,
        retry_strategy: u8,
        last_request_ts: u64,
        request_id: u64,
    }

    struct DrawLedger has key {
        states: table::Table<u64, DrawState>,
        nonce_to_lottery: table::Table<u64, u64>,
        requested_events: event::EventHandle<history::VrfRequestedEvent>,
        fulfilled_events: event::EventHandle<history::VrfFulfilledEvent>,
    }

    public entry fun init_draw(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
        assert!(!exists<DrawLedger>(addr), errors::err_already_initialized());
        let ledger = DrawLedger {
            states: table::new(),
            nonce_to_lottery: table::new(),
            requested_events: account::new_event_handle<history::VrfRequestedEvent>(admin),
            fulfilled_events: account::new_event_handle<history::VrfFulfilledEvent>(admin),
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
    ) acquires DrawLedger {
        ensure_feature_enabled(false);
        vrf_deposit::ensure_requests_allowed();
        let status = lottery_registry::get_status(lottery_id);
        assert!(
            status == types::status_closing() || status == types::status_draw_requested(),
            errors::err_draw_status_invalid(),
        );

        let prize_plan = lottery_registry::clone_prize_plan(lottery_id);
        let prize_slots_len = vector::length(&prize_plan);
        types::assert_rng_count(prize_slots_len);
        let rng_count = types::as_u8(prize_slots_len);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(lottery_id);
        assert!(tickets_sold > 0, errors::err_vrf_snapshot_empty());

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        let state = borrow_or_create_state(&mut ledger.states, lottery_id);
        let current_attempt = types::vrf_state_attempt(&state.vrf_state);
        if (current_attempt >= MAX_VRF_ATTEMPTS) {
            types::vrf_state_set_status(&mut state.vrf_state, types::vrf_status_failed());
            types::vrf_state_set_consumed(&mut state.vrf_state, true);
            types::vrf_state_set_retry_after_ts(&mut state.vrf_state, 0);
            types::vrf_state_set_request_id(&mut state.vrf_state, 0);
            types::vrf_state_clear_payload_hash(&mut state.vrf_state);
            state.verified_numbers = vector::empty();
            state.payload = b"";
            state.winners_batch_hash = b"";
            state.checksum_after_batch = b"";
            cancellation::cancel_lottery_admin(
                admin,
                lottery_id,
                lottery_registry::cancel_reason_vrf_failure(),
                now_ts,
            );
            return
        };
        assert!(
            types::vrf_state_status(&state.vrf_state) != types::vrf_status_requested(),
            errors::err_vrf_pending(),
        );
        if (current_attempt > 0
            && types::vrf_state_retry_strategy(&state.vrf_state) == types::retry_strategy_manual())
        {
            assert!(
                types::vrf_state_retry_after_ts(&state.vrf_state) > 0,
                errors::err_vrf_manual_schedule_required(),
            );
        };
        if (types::vrf_state_status(&state.vrf_state) == types::vrf_status_fulfilled()) {
            assert!(types::vrf_state_consumed(&state.vrf_state), errors::err_vrf_pending());
        };
        let retry_after_ts = types::vrf_state_retry_after_ts(&state.vrf_state);
        if (retry_after_ts > 0 && now_ts < retry_after_ts) {
            abort errors::err_vrf_retry_window()
        };

        let attempt = increment_attempt(&mut state.vrf_state);
        state.rng_count = rng_count;
        let client_seed = next_client_seed(state);
        let slots_checksum = lottery_registry::slots_checksum(lottery_id);
        let payload = encode_payload_v1(
            lottery_id,
            lottery_registry::config_version(lottery_id),
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

        types::vrf_state_set_request_id(&mut state.vrf_state, nonce);
        types::vrf_state_set_payload_hash(&mut state.vrf_state, &payload_hash);
        types::vrf_state_set_schema_version(
            &mut state.vrf_state,
            types::vrf_default_schema_version(),
        );
        types::vrf_state_set_status(&mut state.vrf_state, types::vrf_status_requested());
        types::vrf_state_set_consumed(&mut state.vrf_state, false);
        let retry_policy = lottery_registry::vrf_retry_policy(lottery_id);
        let policy = &retry_policy;
        let (retry_after_ts, retry_strategy) = compute_retry_schedule(policy, now_ts, attempt);
        types::vrf_state_set_retry_after_ts(&mut state.vrf_state, retry_after_ts);
        types::vrf_state_set_retry_strategy(&mut state.vrf_state, retry_strategy);
        types::vrf_state_set_closing_block_height(&mut state.vrf_state, closing_block_height);
        types::vrf_state_set_chain_id(&mut state.vrf_state, chain_id);
        state.client_seed = client_seed;
        state.last_request_ts = now_ts;
        state.snapshot_hash = copy snapshot_hash;
        state.total_tickets = tickets_sold;
        state.payload = copy payload;
        state.verified_numbers = vector::empty();
        state.winners_batch_hash = b"";
        state.checksum_after_batch = b"";

        if (table::contains(&ledger.nonce_to_lottery, nonce)) {
            abort errors::err_vrf_nonce_unknown()
        };
        table::add(&mut ledger.nonce_to_lottery, nonce, lottery_id);

        let requested = history::new_vrf_requested_event(
            lottery_id,
            nonce,
            attempt,
            rng_count,
            client_seed,
            copy payload_hash,
            copy snapshot_hash,
            tickets_sold,
            closing_block_height,
            chain_id,
            now_ts,
        );
        event::emit_event(&mut ledger.requested_events, requested);

        lottery_registry::mark_draw_requested(lottery_id);
    }

    public entry fun schedule_manual_retry_admin(
        admin: &signer,
        lottery_id: u64,
        now_ts: u64,
        retry_after_ts: u64,
    ) acquires DrawLedger {
        assert_admin(admin);
        ensure_feature_enabled(false);
        let status = lottery_registry::get_status(lottery_id);
        assert!(
            status == types::status_closing() || status == types::status_draw_requested(),
            errors::err_draw_status_invalid(),
        );

        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        assert!(table::contains(&ledger.states, lottery_id), errors::err_vrf_not_requested());
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(
            types::vrf_state_retry_strategy(&state.vrf_state) == types::retry_strategy_manual(),
            errors::err_vrf_retry_policy_invalid(),
        );
        assert!(retry_after_ts > 0, errors::err_vrf_manual_deadline());
        assert!(retry_after_ts >= now_ts, errors::err_vrf_manual_deadline());
        types::vrf_state_set_retry_after_ts(&mut state.vrf_state, retry_after_ts);
    }

    public fun max_vrf_attempts(): u8 {
        MAX_VRF_ATTEMPTS
    }

    public entry fun vrf_callback(
        nonce: u64,
        message: vector<u8>,
        signature: vector<u8>,
        caller_address: address,
        rng_count: u8,
        client_seed: u64,
    ) acquires DrawLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        if (!table::contains(&ledger.nonce_to_lottery, nonce)) {
            abort errors::err_vrf_nonce_unknown()
        };
        let lottery_id = table::remove(&mut ledger.nonce_to_lottery, nonce);
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(types::vrf_state_request_id(&state.vrf_state) == nonce, errors::err_vrf_nonce_unknown());
        assert!(
            types::vrf_state_status(&state.vrf_state) == types::vrf_status_requested(),
            errors::err_vrf_not_requested(),
        );
        assert!(!types::vrf_state_consumed(&state.vrf_state), errors::err_vrf_consumed());
        assert!(state.rng_count == rng_count, errors::err_vrf_rng_count_invalid());
        assert!(state.client_seed == client_seed, errors::err_vrf_payload_mismatch());

        let message_hash = hash::sha3_256(copy message);
        assert!(
            message_hash == *types::vrf_state_payload_hash_ref(&state.vrf_state),
            errors::err_vrf_payload_mismatch(),
        );

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

        state.verified_numbers = clone_numbers(&verified_nums);
        types::vrf_state_set_status(&mut state.vrf_state, types::vrf_status_fulfilled());
        types::vrf_state_set_consumed(&mut state.vrf_state, false);
        types::vrf_state_set_retry_after_ts(&mut state.vrf_state, 0);

        let fulfilled = history::new_vrf_fulfilled_event(
            lottery_id,
            nonce,
            types::vrf_state_attempt(&state.vrf_state),
            clone_bytes(types::vrf_state_payload_hash_ref(&state.vrf_state)),
            message_hash,
            rng_count,
            client_seed,
            verified_seed_hash,
            types::vrf_state_closing_block_height(&state.vrf_state),
            types::vrf_state_chain_id(&state.vrf_state),
            state.last_request_ts,
        );
        event::emit_event(&mut ledger.fulfilled_events, fulfilled);

        lottery_registry::mark_drawn(lottery_id);
    }

    fun ensure_feature_enabled(has_premium: bool) {
        if (feature_switch::is_initialized()) {
            let enabled = feature_switch::is_enabled(feature_switch::feature_draw_id(), has_premium);
            assert!(enabled, errors::err_feature_disabled());
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
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        assert!(
            types::vrf_state_status(&state.vrf_state) == types::vrf_status_fulfilled(),
            errors::err_winner_vrf_not_ready(),
        );
        assert!(!types::vrf_state_consumed(&state.vrf_state), errors::err_vrf_consumed());
        let numbers = clone_numbers(&state.verified_numbers);
        types::vrf_state_set_consumed(&mut state.vrf_state, true);
        (
            numbers,
            clone_bytes(&state.snapshot_hash),
            clone_bytes(types::vrf_state_payload_hash_ref(&state.vrf_state)),
            state.total_tickets,
            types::vrf_state_schema_version(&state.vrf_state),
            types::vrf_state_attempt(&state.vrf_state),
        )
    }

    public fun record_winner_hashes(
        lottery_id: u64,
        winners_batch_hash: &vector<u8>,
        checksum_after_batch: &vector<u8>,
    ) acquires DrawLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        state.winners_batch_hash = clone_bytes(winners_batch_hash);
        state.checksum_after_batch = clone_bytes(checksum_after_batch);
    }

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
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        let state = borrow_or_create_state(&mut ledger.states, lottery_id);
        let rng_len = vector::length(&numbers);
        let rng_count = types::as_u8(rng_len);
        state.rng_count = rng_count;
        state.total_tickets = total_tickets;
        state.snapshot_hash = copy snapshot_hash;
        types::vrf_state_set_status(&mut state.vrf_state, types::vrf_status_fulfilled());
        types::vrf_state_set_consumed(&mut state.vrf_state, false);
        types::vrf_state_set_schema_version(&mut state.vrf_state, schema_version);
        types::vrf_state_set_attempt(&mut state.vrf_state, attempt);
        types::vrf_state_set_retry_after_ts(&mut state.vrf_state, 0);
        types::vrf_state_set_retry_strategy(&mut state.vrf_state, types::retry_strategy_fixed());
        types::vrf_state_set_closing_block_height(&mut state.vrf_state, closing_block_height);
        types::vrf_state_set_chain_id(&mut state.vrf_state, chain_id);
        types::vrf_state_set_payload_hash(&mut state.vrf_state, &payload_hash);
        types::vrf_state_set_request_id(&mut state.vrf_state, 0);
        state.client_seed = 0;
        state.last_request_ts = 0;
        state.payload = bcs::to_bytes(&numbers);
        state.verified_numbers = clone_numbers(&numbers);
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
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<DrawLedger>(ledger_addr);
        let state = table::borrow_mut(&mut ledger.states, lottery_id);
        types::vrf_state_set_status(&mut state.vrf_state, status);
        types::vrf_state_set_consumed(&mut state.vrf_state, consumed);
        types::vrf_state_set_retry_after_ts(&mut state.vrf_state, retry_after_ts);
        types::vrf_state_set_attempt(&mut state.vrf_state, attempt);
    }

    public fun finalization_snapshot(lottery_id: u64): FinalizationSnapshot acquires DrawLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global<DrawLedger>(ledger_addr);
        let state = table::borrow(&ledger.states, lottery_id);
        FinalizationSnapshot {
            snapshot_hash: clone_bytes(&state.snapshot_hash),
            payload_hash: clone_bytes(types::vrf_state_payload_hash_ref(&state.vrf_state)),
            winners_batch_hash: clone_bytes(&state.winners_batch_hash),
            checksum_after_batch: clone_bytes(&state.checksum_after_batch),
            schema_version: types::vrf_state_schema_version(&state.vrf_state),
            attempt: types::vrf_state_attempt(&state.vrf_state),
            closing_block_height: types::vrf_state_closing_block_height(&state.vrf_state),
            chain_id: types::vrf_state_chain_id(&state.vrf_state),
            request_ts: state.last_request_ts,
            vrf_status: types::vrf_state_status(&state.vrf_state),
        }
    }

    public fun has_state(lottery_id: u64): bool acquires DrawLedger {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            return false
        };
        let ledger = borrow_global<DrawLedger>(addr);
        table::contains(&ledger.states, lottery_id)
    }

    public fun vrf_state_view(lottery_id: u64): VrfStateView acquires DrawLedger {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            return VrfStateView {
                status: types::vrf_status_idle(),
                attempt: 0,
                consumed: true,
                retry_after_ts: 0,
                retry_strategy: types::retry_strategy_fixed(),
                last_request_ts: 0,
                request_id: 0,
            }
        };
        let ledger = borrow_global<DrawLedger>(addr);
        if (!table::contains(&ledger.states, lottery_id)) {
            return VrfStateView {
                status: types::vrf_status_idle(),
                attempt: 0,
                consumed: true,
                retry_after_ts: 0,
                retry_strategy: types::retry_strategy_fixed(),
                last_request_ts: 0,
                request_id: 0,
            }
        };
        let state = table::borrow(&ledger.states, lottery_id);
        VrfStateView {
            status: types::vrf_state_status(&state.vrf_state),
            attempt: types::vrf_state_attempt(&state.vrf_state),
            consumed: types::vrf_state_consumed(&state.vrf_state),
            retry_after_ts: types::vrf_state_retry_after_ts(&state.vrf_state),
            retry_strategy: types::vrf_state_retry_strategy(&state.vrf_state),
            last_request_ts: state.last_request_ts,
            request_id: types::vrf_state_request_id(&state.vrf_state),
        }
    }

    fun ledger_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<DrawLedger>(addr)) {
            abort errors::err_registry_missing()
        };
        addr
    }

    //
    // View helpers (Move v1 compatibility)
    //

    public fun finalization_snapshot_snapshot_hash(snapshot: &FinalizationSnapshot): vector<u8> {

        clone_bytes(&snapshot.snapshot_hash)

    }



    public fun finalization_snapshot_winners_batch_hash(snapshot: &FinalizationSnapshot): vector<u8> {

        clone_bytes(&snapshot.winners_batch_hash)

    }



    public fun finalization_snapshot_checksum_after_batch(snapshot: &FinalizationSnapshot): vector<u8> {

        clone_bytes(&snapshot.checksum_after_batch)

    }



    public fun finalization_snapshot_closing_block(snapshot: &FinalizationSnapshot): u64 {

        snapshot.closing_block_height

    }



    public fun finalization_snapshot_chain_id(snapshot: &FinalizationSnapshot): u8 {

        snapshot.chain_id

    }



    public fun finalization_snapshot_attempt(snapshot: &FinalizationSnapshot): u8 {

        snapshot.attempt

    }



    public fun finalization_snapshot_vrf_status(snapshot: &FinalizationSnapshot): u8 {

        snapshot.vrf_status

    }



    public fun finalization_snapshot_request_ts(snapshot: &FinalizationSnapshot): u64 {

        snapshot.request_ts

    }



    public fun vrf_state_view_attempt(view: &VrfStateView): u8 {
        view.attempt
    }

    public fun vrf_state_view_retry_strategy(view: &VrfStateView): u8 {
        view.retry_strategy
    }

    public fun vrf_state_view_retry_after_ts(view: &VrfStateView): u64 {
        view.retry_after_ts
    }

    public fun vrf_state_view_status(view: &VrfStateView): u8 {
        view.status
    }


    fun assert_admin(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_registry_missing());
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
                verified_numbers: vector::empty(),
                payload: b"",
                next_client_seed: 0,
            };
            table::add(states, id, state);
        };
        table::borrow_mut(states, id)
    }

    fun next_client_seed(state: &mut DrawState): u64 {
        let current = state.next_client_seed;
        assert!(current < MAX_CLIENT_SEED, errors::err_vrf_client_seed_overflow());
        state.next_client_seed = current + 1;
        current
    }

    fun increment_attempt(vrf_state: &mut types::VrfState): u8 {
        let current = types::vrf_state_attempt(vrf_state);
        assert!(current < 255, errors::err_vrf_attempt_out_of_order());
        let next = current + 1;
        types::vrf_state_set_attempt(vrf_state, next);
        next
    }

    fun compute_retry_schedule(
        policy: &types::RetryPolicy,
        now_ts: u64,
        attempt: u8,
    ): (u64, u8) {
        let strategy = types::retry_policy_strategy(policy);
        if (strategy == types::retry_strategy_manual()) {
            (0, strategy)
        } else {
            let delay = compute_retry_delay(policy, attempt);
            let deadline = now_ts + delay;
            (deadline, strategy)
        }
    }

    fun compute_retry_delay(policy: &types::RetryPolicy, attempt: u8): u64 {
        let base = types::retry_policy_base_delay(policy);
        let strategy = types::retry_policy_strategy(policy);
        if (strategy == types::retry_strategy_fixed() || attempt <= 1) {
            base
        } else {
            let idx = 1u8;
            let delay = base;
            let max_delay = types::retry_policy_max_delay(policy);
            while (idx < attempt) {
                delay = saturating_double(delay, max_delay);
                idx = idx + 1;
            };
            delay
        }
    }

    fun saturating_double(value: u64, max_value: u64): u64 {
        if (value >= max_value) {
            return max_value
        };
        if (value > max_value / 2) {
            return max_value
        };
        let doubled = value * 2;
        if (doubled > max_value) {
            max_value
        } else {
            doubled
        }
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
            snapshot_hash: clone_bytes(snapshot_hash),
            slots_checksum: clone_bytes(slots_checksum),
            rng_count,
            client_seed,
            attempt,
            closing_block_height,
            chain_id,
        };
        bcs::to_bytes(&payload)
    }

    fun callback_module_bytes(): vector<u8> {
        CALLBACK_MODULE_BYTES
    }

    fun callback_function_bytes(): vector<u8> {
        CALLBACK_FUNCTION_BYTES
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let len = vector::length(source);
        let result = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(source, i);
            vector::push_back(&mut result, byte);
            i = i + 1;
        };
        result
    }

    fun clone_numbers(source: &vector<u256>): vector<u256> {
        let len = vector::length(source);
        let result = vector::empty<u256>();
        let i = 0u64;
        while (i < len) {
            let value = *vector::borrow(source, i);
            vector::push_back(&mut result, value);
            i = i + 1;
        };
        result
    }

    public fun finalization_snapshot_placeholder(
        snapshot_hash: vector<u8>,
        request_ts: u64,
    ): FinalizationSnapshot {
        FinalizationSnapshot {
            snapshot_hash,
            payload_hash: b"",
            winners_batch_hash: b"",
            checksum_after_batch: b"",
            schema_version: types::vrf_default_schema_version(),
            attempt: 0,
            closing_block_height: 0,
            chain_id: 0,
            request_ts,
            vrf_status: types::vrf_status_idle(),
        }
    }

  

    //

    // VRF state view helpers (Move v1 compatibility)

    //



    public fun vrf_view_status(view: &VrfStateView): u8 {
        view.status
    }

    public fun vrf_view_consumed(view: &VrfStateView): bool {
        view.consumed
    }

    public fun vrf_view_retry_after_ts(view: &VrfStateView): u64 {
        view.retry_after_ts
    }
}
