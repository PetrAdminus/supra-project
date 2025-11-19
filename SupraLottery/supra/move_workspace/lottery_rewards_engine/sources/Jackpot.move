module lottery_rewards_engine::jackpot {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::jackpot;
    use lottery_data::treasury_multi;
    use lottery_data::vrf_deposit;
    use lottery_rewards::rewards_jackpot;
    use lottery_vrf_gateway::hub;

    const E_UNAUTHORIZED: u64 = 1;
    const E_DRAW_ALREADY_SCHEDULED: u64 = 2;
    const E_PENDING_REQUEST: u64 = 3;
    const E_NO_TICKETS: u64 = 4;
    const E_DRAW_NOT_SCHEDULED: u64 = 5;
    const E_PENDING_REQUEST_MISMATCH: u64 = 6;
    const E_RANDOMNESS_TOO_SHORT: u64 = 7;
    const E_RANDOMNESS_OVERFLOW: u64 = 8;
    const E_EMPTY_JACKPOT: u64 = 9;
    const E_REQUESTS_PAUSED: u64 = 10;
    const E_CAPS_NOT_INITIALIZED: u64 = 11;
    const E_CAPS_UNAVAILABLE: u64 = 12;
    const E_ACCESS_ALREADY_INITIALIZED: u64 = 13;
    const E_CAP_SLOT_OCCUPIED: u64 = 14;

    const RANDOMNESS_WINDOW: u64 = 8;

    struct JackpotAccess has key {
        cap: treasury_multi::MultiTreasuryCap,
    }

    public struct LegacyJackpotRuntime has drop, store {
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        pending_request_id: option::Option<u64>,
        pending_payload: option::Option<vector<u8>>,
    }

    public entry fun register_lottery(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::register_jackpot(registry, lottery_id);
    }

    public entry fun grant_ticket(caller: &signer, lottery_id: u64, player: address)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        ensure_can_grant(lottery_id);
        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::record_ticket(registry, lottery_id, player);
    }

    public entry fun grant_tickets_batch(
        caller: &signer,
        lottery_id: u64,
        players: vector<address>,
    ) acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        ensure_can_grant(lottery_id);
        let len = vector::length(&players);
        grant_batch_recursive(lottery_id, &players, 0, len);
    }

    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        ensure_can_schedule(lottery_id);
        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::schedule_draw(registry, lottery_id);
    }

    public entry fun reset_lottery(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::reset_draw(registry, lottery_id);
    }

    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
    ) acquires instances::InstanceRegistry, jackpot::JackpotRegistry, vrf_deposit::VrfDepositLedger {
        ensure_admin(caller);
        ensure_lottery_exists(lottery_id);
        ensure_can_request(lottery_id);
        ensure_requests_allowed();
        ensure_jackpot_positive();

        let payload_record = clone_bytes(&payload);
        let request_id = hub::request_randomness(lottery_id, payload);
        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::record_request(registry, lottery_id, request_id, &payload_record);
    }

    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires JackpotAccess, jackpot::JackpotRegistry, treasury_multi::TreasuryState, vrf_deposit::VrfDepositLedger {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let lottery_id = hub::request_record_lottery_id(&record);
        let payload = hub::request_record_payload(&record);

        let (winner, ticket_index) = determine_winner(lottery_id, request_id, &randomness);
        let prize_amount = drain_jackpot_balance(winner);

        let registry = jackpot::borrow_registry_mut(@lottery);
        jackpot::record_fulfillment(
            registry,
            lottery_id,
            request_id,
            winner,
            ticket_index,
            prize_amount,
            &randomness,
            &payload,
        );

        hub::record_fulfillment(request_id, lottery_id, randomness);
    }

    public entry fun import_existing_jackpot(caller: &signer, payload: LegacyJackpotRuntime)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        upsert_legacy_jackpot(payload);
    }

    public entry fun import_existing_jackpots(
        caller: &signer,
        mut payloads: vector<LegacyJackpotRuntime>,
    ) acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        ensure_admin(caller);
        import_existing_jackpots_recursive(&mut payloads);
    }

    public entry fun init_access(caller: &signer)
    acquires JackpotAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(caller);
        if (exists<JackpotAccess>(@lottery)) {
            abort E_ACCESS_ALREADY_INITIALIZED;
        };
        let control = treasury_multi::borrow_control_mut(@lottery);
        let cap_opt = treasury_multi::extract_jackpot_cap(control);
        if (!option::is_some(&cap_opt)) {
            abort E_CAPS_UNAVAILABLE;
        };
        let cap = option::destroy_some(cap_opt);
        move_to(caller, JackpotAccess { cap });
    }

    public entry fun claim_jackpot_access(
        caller: &signer,
        _legacy_access: rewards_jackpot::JackpotAccess,
    ) acquires JackpotAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(caller);
        if (exists<JackpotAccess>(@lottery)) {
            abort E_ACCESS_ALREADY_INITIALIZED;
        };
        let control = treasury_multi::borrow_control_mut(@lottery);
        if (option::is_some(&control.jackpot_cap)) {
            abort E_CAP_SLOT_OCCUPIED;
        };
        option::fill(
            &mut control.jackpot_cap,
            treasury_multi::MultiTreasuryCap { scope: treasury_multi::scope_jackpot() },
        );
        let cap = option::extract(&mut control.jackpot_cap);
        move_to(caller, JackpotAccess { cap });
    }

    public entry fun release_access(caller: &signer)
    acquires JackpotAccess, treasury_multi::TreasuryMultiControl {
        ensure_caps_admin(caller);
        if (!exists<JackpotAccess>(@lottery)) {
            abort E_CAPS_NOT_INITIALIZED;
        };
        let JackpotAccess { cap } = move_from<JackpotAccess>(@lottery);
        let control = treasury_multi::borrow_control_mut(@lottery);
        treasury_multi::restore_jackpot_cap(control, cap);
    }

    #[view]
    public fun is_initialized(): bool {
        jackpot::is_initialized()
    }

    #[view]
    public fun ready(): bool {
        jackpot::ready()
    }

    #[view]
    public fun caps_ready(): bool {
        exists<JackpotAccess>(@lottery)
    }

    #[view]
    public fun registry_snapshot(): option::Option<jackpot::JackpotRegistrySnapshot>
    acquires jackpot::JackpotRegistry {
        jackpot::registry_snapshot()
    }

    #[view]
    public fun lottery_snapshot(lottery_id: u64): option::Option<jackpot::JackpotSnapshot>
    acquires jackpot::JackpotRegistry {
        jackpot::lottery_snapshot(lottery_id)
    }

    #[view]
    public fun runtime_view(lottery_id: u64): option::Option<jackpot::JackpotRuntimeView>
    acquires jackpot::JackpotRegistry {
        jackpot::runtime_view(lottery_id)
    }

    #[view]
    public fun runtime_views(): option::Option<vector<jackpot::JackpotRuntimeView>>
    acquires jackpot::JackpotRegistry {
        jackpot::runtime_views()
    }

    fun ensure_admin(caller: &signer) acquires instances::InstanceRegistry {
        let caller_addr = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        assert!(caller_addr == registry.admin, E_UNAUTHORIZED);
    }

    fun ensure_lottery_exists(lottery_id: u64) acquires instances::InstanceRegistry {
        let registry = instances::borrow_registry(@lottery);
        let _record = instances::instance(registry, lottery_id);
    }

    fun ensure_can_grant(lottery_id: u64) acquires jackpot::JackpotRegistry {
        let registry = jackpot::borrow_registry(@lottery);
        let runtime = jackpot::jackpot(registry, lottery_id);
        assert!(!runtime.draw_scheduled, E_DRAW_ALREADY_SCHEDULED);
        assert!(!option::is_some(&runtime.pending_request), E_PENDING_REQUEST);
    }

    fun ensure_can_schedule(lottery_id: u64) acquires jackpot::JackpotRegistry {
        let registry = jackpot::borrow_registry(@lottery);
        let runtime = jackpot::jackpot(registry, lottery_id);
        assert!(!runtime.draw_scheduled, E_DRAW_ALREADY_SCHEDULED);
        assert!(!option::is_some(&runtime.pending_request), E_PENDING_REQUEST);
        let ticket_count = vector::length(&runtime.tickets);
        assert!(ticket_count > 0, E_NO_TICKETS);
    }

    fun ensure_can_request(lottery_id: u64) acquires jackpot::JackpotRegistry {
        let registry = jackpot::borrow_registry(@lottery);
        let runtime = jackpot::jackpot(registry, lottery_id);
        assert!(runtime.draw_scheduled, E_DRAW_NOT_SCHEDULED);
        assert!(!option::is_some(&runtime.pending_request), E_PENDING_REQUEST);
        let ticket_count = vector::length(&runtime.tickets);
        assert!(ticket_count > 0, E_NO_TICKETS);
    }

    fun ensure_requests_allowed() acquires vrf_deposit::VrfDepositLedger {
        if (!exists<vrf_deposit::VrfDepositLedger>(@lottery)) {
            return;
        };
        let ledger = vrf_deposit::ledger(@lottery);
        assert!(!ledger.status.requests_paused, E_REQUESTS_PAUSED);
    }

    fun ensure_jackpot_positive() acquires treasury_multi::TreasuryState {
        let state = treasury_multi::borrow_state(@lottery);
        let balance = treasury_multi::jackpot_balance(state);
        assert!(balance > 0, E_EMPTY_JACKPOT);
    }

    fun determine_winner(
        lottery_id: u64,
        request_id: u64,
        randomness: &vector<u8>,
    ): (address, u64) acquires jackpot::JackpotRegistry {
        let registry = jackpot::borrow_registry(@lottery);
        let runtime = jackpot::jackpot(registry, lottery_id);
        assert!(option::is_some(&runtime.pending_request), E_PENDING_REQUEST);
        let expected_id = *option::borrow(&runtime.pending_request);
        assert!(expected_id == request_id, E_PENDING_REQUEST_MISMATCH);
        let ticket_count = vector::length(&runtime.tickets);
        assert!(ticket_count > 0, E_NO_TICKETS);
        let winner_index = randomness_to_index(randomness, ticket_count);
        let winner = *vector::borrow(&runtime.tickets, winner_index);
        (winner, winner_index)
    }

    fun drain_jackpot_balance(winner: address): u64
    acquires JackpotAccess, treasury_multi::TreasuryState {
        ensure_caps_ready();
        let access = borrow_global<JackpotAccess>(@lottery);
        treasury_multi::ensure_scope(&access.cap, treasury_multi::scope_jackpot());
        let state = treasury_multi::borrow_state_mut(@lottery);
        let amount = treasury_multi::jackpot_balance(state);
        assert!(amount > 0, E_EMPTY_JACKPOT);
        treasury_multi::record_jackpot_payment(state, winner, amount);
        amount
    }

    fun grant_batch_recursive(
        lottery_id: u64,
        players: &vector<address>,
        index: u64,
        len: u64,
    ) acquires jackpot::JackpotRegistry {
        if (index >= len) {
            return;
        };
        let player = *vector::borrow(players, index);
        {
            let registry = jackpot::borrow_registry_mut(@lottery);
            jackpot::record_ticket(registry, lottery_id, player);
        };
        let next_index = index + 1;
        grant_batch_recursive(lottery_id, players, next_index, len);
    }

    fun randomness_to_index(randomness: &vector<u8>, ticket_count: u64): u64 {
        let random_value = randomness_to_u64(randomness);
        random_value % ticket_count
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        let length = vector::length(randomness);
        assert!(length >= RANDOMNESS_WINDOW, E_RANDOMNESS_TOO_SHORT);
        accumulate_randomness(randomness, 0, 0)
    }

    fun accumulate_randomness(randomness: &vector<u8>, index: u64, acc: u64): u64 {
        if (index >= RANDOMNESS_WINDOW) {
            acc
        } else {
            let byte = *vector::borrow(randomness, index);
            let scaled = safe_mul_u64(acc, 256, E_RANDOMNESS_OVERFLOW);
            let next_acc = safe_add_u64(scaled, u8_to_u64(byte), E_RANDOMNESS_OVERFLOW);
            let next_index = index + 1;
            accumulate_randomness(randomness, next_index, next_acc)
        }
    }

    fun safe_mul_u64(value: u64, multiplier: u64, err: u64): u64 {
        let product = (value as u128) * (multiplier as u128);
        assert!(product <= 18446744073709551615, err);
        product as u64
    }

    fun safe_add_u64(value: u64, increment: u64, err: u64): u64 {
        let sum = (value as u128) + (increment as u128);
        assert!(sum <= 18446744073709551615, err);
        sum as u64
    }

    fun u8_to_u64(value: u8): u64 {
        value as u64
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        clone_into(&mut buffer, data, 0, len);
        buffer
    }

    fun clone_into(buffer: &mut vector<u8>, data: &vector<u8>, index: u64, len: u64) {
        if (index >= len) {
            return;
        };
        let byte = *vector::borrow(data, index);
        vector::push_back(buffer, byte);
        let next_index = index + 1;
        clone_into(buffer, data, next_index, len);
    }

    fun import_existing_jackpots_recursive(payloads: &mut vector<LegacyJackpotRuntime>)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        if (vector::is_empty(payloads)) {
            return;
        };
        let payload = vector::pop_back(payloads);
        import_existing_jackpots_recursive(payloads);
        upsert_legacy_jackpot(payload);
    }

    fun upsert_legacy_jackpot(payload: LegacyJackpotRuntime)
    acquires instances::InstanceRegistry, jackpot::JackpotRegistry {
        let LegacyJackpotRuntime {
            lottery_id,
            tickets,
            draw_scheduled,
            pending_request_id,
            pending_payload,
        } = payload;
        ensure_lottery_exists(lottery_id);
        let registry = jackpot::borrow_registry_mut(@lottery);
        if (!jackpot::is_registered(registry, lottery_id)) {
            jackpot::register_jackpot(registry, lottery_id);
        };
        jackpot::restore_runtime(
            registry,
            lottery_id,
            tickets,
            draw_scheduled,
            pending_request_id,
            pending_payload,
        );
    }

    fun ensure_caps_admin(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_UNAUTHORIZED;
        };
    }

    fun ensure_caps_ready() {
        if (!exists<JackpotAccess>(@lottery)) {
            abort E_CAPS_NOT_INITIALIZED;
        };
    }
}
