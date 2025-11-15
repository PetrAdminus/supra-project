// sources/types.move
module lottery_multi::types {
    use std::bcs;
    use std::hash;
    use std::vector;

    use lottery_multi::errors;
    use lottery_multi::math;

    const STATUS_DRAFT: u8 = 0;
    const STATUS_ACTIVE: u8 = 1;
    const STATUS_CLOSING: u8 = 2;
    const STATUS_DRAW_REQUESTED: u8 = 3;
    const STATUS_DRAWN: u8 = 4;
    const STATUS_PAYOUT: u8 = 5;
    const STATUS_FINALIZED: u8 = 6;
    const STATUS_CANCELED: u8 = 7;

    const DRAW_ALGO_WITHOUT_REPLACEMENT: u8 = 0;
    const DRAW_ALGO_WITH_REPLACEMENT: u8 = 1;
    const DRAW_ALGO_STRIDE: u8 = 2;

    const REWARD_FROM_SALES: u8 = 0;
    const REWARD_FROM_JACKPOT: u8 = 1;
    const REWARD_NFT_ESCROW: u8 = 2;
    const REWARD_CUSTOM_HOOK: u8 = 3;

    const BACKEND_NATIVE: u8 = 0;
    const BACKEND_PARTNER: u8 = 1;

    const RETRY_STRATEGY_FIXED: u8 = 0;
    const RETRY_STRATEGY_EXPONENTIAL: u8 = 1;
    const RETRY_STRATEGY_MANUAL: u8 = 2;

    const DEFAULT_RETRY_DELAY_SECS: u64 = 600;

    const VRF_STATUS_IDLE: u8 = 0;
    const VRF_STATUS_REQUESTED: u8 = 1;
    const VRF_STATUS_FULFILLED: u8 = 2;
    const VRF_STATUS_FAILED: u8 = 3;

    const DEFAULT_SCHEMA_VERSION: u16 = 1;

    struct SalesWindow has copy, drop, store {
        sales_start: u64,
        sales_end: u64,
    }

    struct TicketLimits has copy, drop, store {
        max_tickets_total: u64,
        max_tickets_per_address: u64,
    }

    struct AutoClosePolicy has copy, drop, store {
        enabled: bool,
        grace_period_secs: u64,
    }

    struct PrizeSlot has copy, drop, store {
        slot_id: u64,
        winners_per_slot: u16,
        reward_type: u8,
        reward_payload: vector<u8>,
    }

    struct RewardBackend has copy, drop, store {
        backend_type: u8,
        config_blob: vector<u8>,
    }

    struct VrfStatus has copy, drop, store {
        status: u8,
    }

    const MAX_RNG_COUNT: u64 = 255;

    struct VrfState has copy, drop, store {
        request_id: u64,
        payload_hash: vector<u8>,
        schema_version: u16,
        attempt: u8,
        consumed: bool,
        retry_after_ts: u64,
        retry_strategy: u8,
        closing_block_height: u64,
        chain_id: u8,
        status: u8,
    }

    struct WinnerCursor has copy, drop, store {
        last_processed_index: u64,
        checksum_after_batch: vector<u8>,
    }

    struct RetryPolicy has copy, drop, store {
        strategy: u8,
        base_delay_secs: u64,
        max_delay_secs: u64,
    }

    public fun new_sales_window(sales_start: u64, sales_end: u64): SalesWindow {
        SalesWindow { sales_start, sales_end }
    }

    public fun new_ticket_limits(
        max_tickets_total: u64,
        max_tickets_per_address: u64,
    ): TicketLimits {
        TicketLimits {
            max_tickets_total,
            max_tickets_per_address,
        }
    }

    public fun new_auto_close_policy(enabled: bool, grace_period_secs: u64): AutoClosePolicy {
        AutoClosePolicy { enabled, grace_period_secs }
    }

    public fun new_prize_slot(
        slot_id: u64,
        winners_per_slot: u16,
        reward_type: u8,
        reward_payload: vector<u8>,
    ): PrizeSlot {
        PrizeSlot {
            slot_id,
            winners_per_slot,
            reward_type,
            reward_payload,
        }
    }

    public fun new_reward_backend(backend_type: u8, config_blob: vector<u8>): RewardBackend {
        RewardBackend {
            backend_type,
            config_blob,
        }
    }

    public fun new_retry_policy(strategy: u8, base_delay_secs: u64, max_delay_secs: u64): RetryPolicy {
        RetryPolicy {
            strategy,
            base_delay_secs,
            max_delay_secs,
        }
    }

    public fun default_retry_policy(): RetryPolicy {
        RetryPolicy {
            strategy: RETRY_STRATEGY_FIXED,
            base_delay_secs: DEFAULT_RETRY_DELAY_SECS,
            max_delay_secs: DEFAULT_RETRY_DELAY_SECS,
        }
    }

    public fun new_vrf_state(): VrfState {
        VrfState {
            request_id: 0,
            payload_hash: b"",
            schema_version: DEFAULT_SCHEMA_VERSION,
            attempt: 0,
            consumed: false,
            retry_after_ts: 0,
            retry_strategy: RETRY_STRATEGY_FIXED,
            closing_block_height: 0,
            chain_id: 0,
            status: VRF_STATUS_IDLE,
        }
    }

    public fun assert_sales_window(window: &SalesWindow) {
        let start = window.sales_start;
        let end = window.sales_end;
        assert!(start < end, errors::err_sales_window_invalid());
    }

    public fun assert_ticket_price(ticket_price: u64) {
        assert!(ticket_price > 0, errors::err_ticket_price_zero());
    }

    public fun assert_ticket_limits(limits: &TicketLimits) {
        assert!(limits.max_tickets_total > 0, errors::err_ticket_limit_invalid());
        if (limits.max_tickets_per_address > 0) {
            assert!(
                limits.max_tickets_per_address <= limits.max_tickets_total,
                errors::err_ticket_limit_invalid(),
            );
        };
    }

    public fun assert_retry_policy(policy: &RetryPolicy) {
        let strategy = policy.strategy;
        let valid_strategy = strategy == RETRY_STRATEGY_FIXED
            || strategy == RETRY_STRATEGY_EXPONENTIAL
            || strategy == RETRY_STRATEGY_MANUAL;
        assert!(valid_strategy, errors::err_vrf_retry_policy_invalid());

        if (strategy == RETRY_STRATEGY_MANUAL) {
            return
        };

        assert!(policy.base_delay_secs > 0, errors::err_vrf_retry_policy_invalid());
        assert!(policy.max_delay_secs >= policy.base_delay_secs, errors::err_vrf_retry_policy_invalid());
    }

    public fun assert_draw_algo(draw_algo: u8) {
        let supported = draw_algo == DRAW_ALGO_WITHOUT_REPLACEMENT
            || draw_algo == DRAW_ALGO_WITH_REPLACEMENT
            || draw_algo == DRAW_ALGO_STRIDE;
        assert!(supported, errors::err_draw_algo_unsupported());
    }

    public fun assert_prize_plan(prize_plan: &vector<PrizeSlot>) {
        let len = vector::length(prize_plan);
        assert!(len > 0, errors::err_prize_plan_empty());
        let idx = 0;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            assert!(slot.winners_per_slot > 0, errors::err_prize_slot_invalid());
            assert!(slot.reward_type <= REWARD_CUSTOM_HOOK, errors::err_prize_slot_invalid());
            idx = idx + 1;
        };
    }

    public fun prize_plan_checksum(prize_plan: &vector<PrizeSlot>): vector<u8> {
        let bytes = bcs::to_bytes(prize_plan);
        hash::sha3_256(bytes)
    }

    //
    // Struct helpers (Move v1 compatibility)
    //

    public fun clone_bytes(source: &vector<u8>): vector<u8> {
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

    public fun prize_slot_slot_id(slot: &PrizeSlot): u64 {
        slot.slot_id
    }

    public fun prize_slot_winners(slot: &PrizeSlot): u16 {
        slot.winners_per_slot
    }

    public fun sales_window_start(window: &SalesWindow): u64 {
        window.sales_start
    }

    public fun sales_window_end(window: &SalesWindow): u64 {
        window.sales_end
    }

    public fun ticket_limits_total(limits: &TicketLimits): u64 {
        limits.max_tickets_total
    }

    public fun ticket_limits_per_address(limits: &TicketLimits): u64 {
        limits.max_tickets_per_address
    }

    public fun retry_policy_strategy(policy: &RetryPolicy): u8 {
        policy.strategy
    }

    public fun retry_policy_base_delay(policy: &RetryPolicy): u64 {
        policy.base_delay_secs
    }

    public fun retry_policy_max_delay(policy: &RetryPolicy): u64 {
        policy.max_delay_secs
    }

    public fun clone_prize_slot(slot: &PrizeSlot): PrizeSlot {
        PrizeSlot {
            slot_id: slot.slot_id,
            winners_per_slot: slot.winners_per_slot,
            reward_type: slot.reward_type,
            reward_payload: clone_bytes(&slot.reward_payload),
        }
    }

    public fun clone_prize_plan(plan: &vector<PrizeSlot>): vector<PrizeSlot> {
        let len = vector::length(plan);
        let result = vector::empty<PrizeSlot>();
        let i = 0;
        while (i < len) {
            let slot = vector::borrow(plan, i);
            let cloned = clone_prize_slot(slot);
            vector::push_back(&mut result, cloned);
            i = i + 1;
        };
        result
    }

    public fun clone_retry_policy(policy: &RetryPolicy): RetryPolicy {
        RetryPolicy {
            strategy: policy.strategy,
            base_delay_secs: policy.base_delay_secs,
            max_delay_secs: policy.max_delay_secs,
        }
    }

    public fun clone_reward_backend(backend: &RewardBackend): RewardBackend {
        RewardBackend {
            backend_type: backend.backend_type,
            config_blob: clone_bytes(&backend.config_blob),
        }
    }

    public fun winner_cursor_new(): WinnerCursor {
        WinnerCursor {
            last_processed_index: 0,
            checksum_after_batch: b"",
        }
    }

    public fun winner_cursor_last_index(cursor: &WinnerCursor): u64 {
        cursor.last_processed_index
    }

    public fun winner_cursor_set_last_index(cursor: &mut WinnerCursor, value: u64) {
        cursor.last_processed_index = value;
    }

    public fun winner_cursor_checksum(cursor: &WinnerCursor): vector<u8> {
        clone_bytes(&cursor.checksum_after_batch)
    }

    public fun winner_cursor_set_checksum(cursor: &mut WinnerCursor, checksum: &vector<u8>) {
        cursor.checksum_after_batch = clone_bytes(checksum);
    }

    public fun assert_rng_count(count: u64) {
        assert!(count > 0 && count <= MAX_RNG_COUNT, errors::err_vrf_rng_count_invalid());
    }

    public fun as_u8(value: u64): u8 {
        assert!(value <= MAX_RNG_COUNT, errors::err_vrf_rng_count_invalid());
        let narrowed = math::narrow_u8_from_u64(value, errors::err_vrf_rng_count_invalid());
        narrowed
    }

    //
    // Status helpers (Move v1 compatibility)
    //

    public fun status_draft(): u8 {
        STATUS_DRAFT
    }

    public fun status_active(): u8 {
        STATUS_ACTIVE
    }

    public fun status_closing(): u8 {
        STATUS_CLOSING
    }

    public fun status_draw_requested(): u8 {
        STATUS_DRAW_REQUESTED
    }

    public fun status_drawn(): u8 {
        STATUS_DRAWN
    }

    public fun status_payout(): u8 {
        STATUS_PAYOUT
    }

    public fun status_finalized(): u8 {
        STATUS_FINALIZED
    }

    public fun status_canceled(): u8 {
        STATUS_CANCELED
    }

    //
    // VRF helpers (Move v1 compatibility)
    //

    public fun vrf_status_idle(): u8 {
        VRF_STATUS_IDLE
    }

    public fun vrf_status_requested(): u8 {
        VRF_STATUS_REQUESTED
    }

    public fun vrf_status_fulfilled(): u8 {
        VRF_STATUS_FULFILLED
    }

    public fun vrf_status_failed(): u8 {
        VRF_STATUS_FAILED
    }

    public fun retry_strategy_fixed(): u8 {
        RETRY_STRATEGY_FIXED
    }

    public fun retry_strategy_exponential(): u8 {
        RETRY_STRATEGY_EXPONENTIAL
    }

    public fun retry_strategy_manual(): u8 {
        RETRY_STRATEGY_MANUAL
    }

    public fun vrf_default_schema_version(): u16 {
        DEFAULT_SCHEMA_VERSION
    }

    public fun vrf_state_attempt(state: &VrfState): u8 {
        state.attempt
    }

    public fun vrf_state_set_attempt(state: &mut VrfState, value: u8) {
        state.attempt = value;
    }

    public fun vrf_state_status(state: &VrfState): u8 {
        state.status
    }

    public fun vrf_state_set_status(state: &mut VrfState, status: u8) {
        state.status = status;
    }

    public fun vrf_state_consumed(state: &VrfState): bool {
        state.consumed
    }

    public fun vrf_state_set_consumed(state: &mut VrfState, consumed: bool) {
        state.consumed = consumed;
    }

    public fun vrf_state_retry_after_ts(state: &VrfState): u64 {
        state.retry_after_ts
    }

    public fun vrf_state_set_retry_after_ts(state: &mut VrfState, value: u64) {
        state.retry_after_ts = value;
    }

    public fun vrf_state_retry_strategy(state: &VrfState): u8 {
        state.retry_strategy
    }

    public fun vrf_state_set_retry_strategy(state: &mut VrfState, strategy: u8) {
        state.retry_strategy = strategy;
    }

    public fun vrf_state_request_id(state: &VrfState): u64 {
        state.request_id
    }

    public fun vrf_state_set_request_id(state: &mut VrfState, request_id: u64) {
        state.request_id = request_id;
    }

    public fun vrf_state_payload_hash_ref(state: &VrfState): &vector<u8> {
        &state.payload_hash
    }

    public fun vrf_state_set_payload_hash(state: &mut VrfState, payload_hash: &vector<u8>) {
        state.payload_hash = clone_bytes(payload_hash);
    }

    public fun vrf_state_clear_payload_hash(state: &mut VrfState) {
        state.payload_hash = b"";
    }

    public fun vrf_state_schema_version(state: &VrfState): u16 {
        state.schema_version
    }

    public fun vrf_state_set_schema_version(state: &mut VrfState, version: u16) {
        state.schema_version = version;
    }

    public fun vrf_state_closing_block_height(state: &VrfState): u64 {
        state.closing_block_height
    }

    public fun vrf_state_set_closing_block_height(state: &mut VrfState, value: u64) {
        state.closing_block_height = value;
    }

    public fun vrf_state_chain_id(state: &VrfState): u8 {
        state.chain_id
    }

    public fun vrf_state_set_chain_id(state: &mut VrfState, value: u8) {
        state.chain_id = value;
    }

    public fun draw_algo_without_replacement_value(): u8 {
        DRAW_ALGO_WITHOUT_REPLACEMENT
    }

    public fun reward_from_sales_value(): u8 {
        REWARD_FROM_SALES
    }

    public fun backend_native_value(): u8 {
        BACKEND_NATIVE
    }

}
