// sources/types.move
module lottery_multi::types {
    use std::bcs;
    use std::hash;
    use std::vector;

    use lottery_multi::errors;

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

    public struct SalesWindow has copy, drop, store {
        sales_start: u64,
        sales_end: u64,
    }

    public struct TicketLimits has copy, drop, store {
        max_tickets_total: u64,
        max_tickets_per_address: u64,
    }

    public struct AutoClosePolicy has copy, drop, store {
        enabled: bool,
        grace_period_secs: u64,
    }

    public struct PrizeSlot has copy, drop, store {
        slot_id: u64,
        winners_per_slot: u16,
        reward_type: u8,
        reward_payload: vector<u8>,
    }

    public struct RewardBackend has copy, drop, store {
        backend_type: u8,
        config_blob: vector<u8>,
    }

    public struct VrfStatus has copy, drop, store {
        status: u8,
    }

    const MAX_RNG_COUNT: u64 = 255;

    public struct VrfState has copy, drop, store {
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

    public struct WinnerCursor has copy, drop, store {
        last_processed_index: u64,
        checksum_after_batch: vector<u8>,
    }

    public struct RetryPolicy has copy, drop, store {
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
        assert!(start < end, errors::E_SALES_WINDOW_INVALID);
    }

    public fun assert_ticket_price(ticket_price: u64) {
        assert!(ticket_price > 0, errors::E_TICKET_PRICE_ZERO);
    }

    public fun assert_ticket_limits(limits: &TicketLimits) {
        assert!(limits.max_tickets_total > 0, errors::E_TICKET_LIMIT_INVALID);
        if (limits.max_tickets_per_address > 0) {
            assert!(
                limits.max_tickets_per_address <= limits.max_tickets_total,
                errors::E_TICKET_LIMIT_INVALID,
            );
        };
    }

    public fun assert_retry_policy(policy: &RetryPolicy) {
        let strategy = policy.strategy;
        let valid_strategy = strategy == RETRY_STRATEGY_FIXED
            || strategy == RETRY_STRATEGY_EXPONENTIAL
            || strategy == RETRY_STRATEGY_MANUAL;
        assert!(valid_strategy, errors::E_VRF_RETRY_POLICY_INVALID);

        if (strategy == RETRY_STRATEGY_MANUAL) {
            return;
        };

        assert!(policy.base_delay_secs > 0, errors::E_VRF_RETRY_POLICY_INVALID);
        assert!(policy.max_delay_secs >= policy.base_delay_secs, errors::E_VRF_RETRY_POLICY_INVALID);
    }

    public fun assert_draw_algo(draw_algo: u8) {
        let supported = draw_algo == DRAW_ALGO_WITHOUT_REPLACEMENT
            || draw_algo == DRAW_ALGO_WITH_REPLACEMENT
            || draw_algo == DRAW_ALGO_STRIDE;
        assert!(supported, errors::E_DRAW_ALGO_UNSUPPORTED);
    }

    public fun assert_prize_plan(prize_plan: &vector<PrizeSlot>) {
        let len = vector::length(prize_plan);
        assert!(len > 0, errors::E_PRIZE_PLAN_EMPTY);
        let mut idx = 0;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            assert!(slot.winners_per_slot > 0, errors::E_PRIZE_SLOT_INVALID);
            assert!(slot.reward_type <= REWARD_CUSTOM_HOOK, errors::E_PRIZE_SLOT_INVALID);
            idx = idx + 1;
        };
    }

    public fun prize_plan_checksum(prize_plan: &vector<PrizeSlot>): vector<u8> {
        let bytes = bcs::to_bytes(prize_plan);
        hash::sha3_256(bytes)
    }

    public fun assert_rng_count(count: u64) {
        assert!(count > 0 && count <= MAX_RNG_COUNT, errors::E_VRF_RNG_COUNT_INVALID);
    }

    public fun as_u8(value: u64): u8 {
        assert!(value <= MAX_RNG_COUNT, errors::E_VRF_RNG_COUNT_INVALID);
        value as u8
    }
}
