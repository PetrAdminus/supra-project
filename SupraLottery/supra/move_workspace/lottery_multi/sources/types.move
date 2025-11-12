// sources/types.move
module lottery_multi::types {
    use std::bcs;
    use std::hash;
    use std::vector;

    use lottery_multi::errors;

    pub const STATUS_DRAFT: u8 = 0;
    pub const STATUS_ACTIVE: u8 = 1;
    pub const STATUS_CLOSING: u8 = 2;
    pub const STATUS_DRAW_REQUESTED: u8 = 3;
    pub const STATUS_DRAWN: u8 = 4;
    pub const STATUS_PAYOUT: u8 = 5;
    pub const STATUS_FINALIZED: u8 = 6;
    pub const STATUS_CANCELED: u8 = 7;

    pub const DRAW_ALGO_WITHOUT_REPLACEMENT: u8 = 0;
    pub const DRAW_ALGO_WITH_REPLACEMENT: u8 = 1;
    pub const DRAW_ALGO_STRIDE: u8 = 2;

    pub const REWARD_FROM_SALES: u8 = 0;
    pub const REWARD_FROM_JACKPOT: u8 = 1;
    pub const REWARD_NFT_ESCROW: u8 = 2;
    pub const REWARD_CUSTOM_HOOK: u8 = 3;

    pub const BACKEND_NATIVE: u8 = 0;
    pub const BACKEND_PARTNER: u8 = 1;

    pub const RETRY_STRATEGY_FIXED: u8 = 0;
    pub const RETRY_STRATEGY_EXPONENTIAL: u8 = 1;
    pub const RETRY_STRATEGY_MANUAL: u8 = 2;

    pub const DEFAULT_RETRY_DELAY_SECS: u64 = 600;

    pub const VRF_STATUS_IDLE: u8 = 0;
    pub const VRF_STATUS_REQUESTED: u8 = 1;
    pub const VRF_STATUS_FULFILLED: u8 = 2;
    pub const VRF_STATUS_FAILED: u8 = 3;

    pub const DEFAULT_SCHEMA_VERSION: u16 = 1;

    pub struct SalesWindow has copy, drop, store {
        pub sales_start: u64,
        pub sales_end: u64,
    }

    pub struct TicketLimits has copy, drop, store {
        pub max_tickets_total: u64,
        pub max_tickets_per_address: u64,
    }

    pub struct AutoClosePolicy has copy, drop, store {
        pub enabled: bool,
        pub grace_period_secs: u64,
    }

    pub struct PrizeSlot has copy, drop, store {
        pub slot_id: u64,
        pub winners_per_slot: u16,
        pub reward_type: u8,
        pub reward_payload: vector<u8>,
    }

    pub struct RewardBackend has copy, drop, store {
        pub backend_type: u8,
        pub config_blob: vector<u8>,
    }

    pub struct VrfStatus has copy, drop, store {
        pub status: u8,
    }

    pub const MAX_RNG_COUNT: u64 = 255;

    pub struct VrfState has copy, drop, store {
        pub request_id: u64,
        pub payload_hash: vector<u8>,
        pub schema_version: u16,
        pub attempt: u8,
        pub consumed: bool,
        pub retry_after_ts: u64,
        pub retry_strategy: u8,
        pub closing_block_height: u64,
        pub chain_id: u8,
        pub status: u8,
    }

    pub struct WinnerCursor has copy, drop, store {
        pub last_processed_index: u64,
        pub checksum_after_batch: vector<u8>,
    }

    pub struct RetryPolicy has copy, drop, store {
        pub strategy: u8,
        pub base_delay_secs: u64,
        pub max_delay_secs: u64,
    }

    pub fun new_sales_window(sales_start: u64, sales_end: u64): SalesWindow {
        SalesWindow { sales_start, sales_end }
    }

    pub fun new_ticket_limits(
        max_tickets_total: u64,
        max_tickets_per_address: u64,
    ): TicketLimits {
        TicketLimits {
            max_tickets_total,
            max_tickets_per_address,
        }
    }

    pub fun new_auto_close_policy(enabled: bool, grace_period_secs: u64): AutoClosePolicy {
        AutoClosePolicy { enabled, grace_period_secs }
    }

    pub fun new_prize_slot(
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

    pub fun new_reward_backend(backend_type: u8, config_blob: vector<u8>): RewardBackend {
        RewardBackend {
            backend_type,
            config_blob,
        }
    }

    pub fun new_retry_policy(strategy: u8, base_delay_secs: u64, max_delay_secs: u64): RetryPolicy {
        RetryPolicy {
            strategy,
            base_delay_secs,
            max_delay_secs,
        }
    }

    pub fun default_retry_policy(): RetryPolicy {
        RetryPolicy {
            strategy: RETRY_STRATEGY_FIXED,
            base_delay_secs: DEFAULT_RETRY_DELAY_SECS,
            max_delay_secs: DEFAULT_RETRY_DELAY_SECS,
        }
    }

    pub fun new_vrf_state(): VrfState {
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

    pub fun assert_sales_window(window: &SalesWindow) {
        let start = window.sales_start;
        let end = window.sales_end;
        assert!(start < end, errors::E_SALES_WINDOW_INVALID);
    }

    pub fun assert_ticket_price(ticket_price: u64) {
        assert!(ticket_price > 0, errors::E_TICKET_PRICE_ZERO);
    }

    pub fun assert_ticket_limits(limits: &TicketLimits) {
        assert!(limits.max_tickets_total > 0, errors::E_TICKET_LIMIT_INVALID);
        if (limits.max_tickets_per_address > 0) {
            assert!(
                limits.max_tickets_per_address <= limits.max_tickets_total,
                errors::E_TICKET_LIMIT_INVALID,
            );
        };
    }

    pub fun assert_retry_policy(policy: &RetryPolicy) {
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

    pub fun assert_draw_algo(draw_algo: u8) {
        let supported = draw_algo == DRAW_ALGO_WITHOUT_REPLACEMENT
            || draw_algo == DRAW_ALGO_WITH_REPLACEMENT
            || draw_algo == DRAW_ALGO_STRIDE;
        assert!(supported, errors::E_DRAW_ALGO_UNSUPPORTED);
    }

    pub fun assert_prize_plan(prize_plan: &vector<PrizeSlot>) {
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

    pub fun prize_plan_checksum(prize_plan: &vector<PrizeSlot>): vector<u8> {
        let bytes = bcs::to_bytes(prize_plan);
        hash::sha3_256(bytes)
    }

    pub fun assert_rng_count(count: u64) {
        assert!(count > 0 && count <= MAX_RNG_COUNT, errors::E_VRF_RNG_COUNT_INVALID);
    }

    pub fun as_u8(value: u64): u8 {
        assert!(value <= MAX_RNG_COUNT, errors::E_VRF_RNG_COUNT_INVALID);
        value as u8
    }
}
