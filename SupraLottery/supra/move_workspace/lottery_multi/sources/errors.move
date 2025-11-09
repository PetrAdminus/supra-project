// sources/errors.move
module lottery_multi::errors {
    /// Common tag errors
    pub const E_TAG_PRIMARY_TYPE: u64 = 0x1001;
    pub const E_TAG_UNKNOWN_BIT: u64 = 0x1002;
    pub const E_TAG_BUDGET_EXCEEDED: u64 = 0x1003;

    /// Partner capability errors
    pub const E_PRIMARY_TYPE_NOT_ALLOWED: u64 = 0x1101;
    pub const E_TAG_MASK_NOT_ALLOWED: u64 = 0x1102;

    /// Registry and configuration errors
    pub const E_ALREADY_INITIALIZED: u64 = 0x1201;
    pub const E_REGISTRY_MISSING: u64 = 0x1202;
    pub const E_LOTTERY_EXISTS: u64 = 0x1203;
    pub const E_STATUS_TRANSITION_NOT_ALLOWED: u64 = 0x1204;
    pub const E_PRIMARY_TYPE_LOCKED: u64 = 0x1205;
    pub const E_TAGS_LOCKED: u64 = 0x1206;
    pub const E_SNAPSHOT_FROZEN: u64 = 0x1207;
    pub const E_SALES_WINDOW_INVALID: u64 = 0x1208;
    pub const E_TICKET_PRICE_ZERO: u64 = 0x1209;
    pub const E_TICKET_LIMIT_INVALID: u64 = 0x120A;
    pub const E_PRIZE_PLAN_EMPTY: u64 = 0x120B;
    pub const E_PRIZE_SLOT_INVALID: u64 = 0x120C;
    pub const E_DRAW_ALGO_UNSUPPORTED: u64 = 0x120D;
    pub const E_SALES_WINDOW_CLOSED: u64 = 0x120E;
    pub const E_LOTTERY_NOT_ACTIVE: u64 = 0x120F;
    pub const E_DRAW_STATUS_INVALID: u64 = 0x1210;

    /// Accounting and allocation errors
    pub const E_DISTRIBUTION_BPS_INVALID: u64 = 0x1301;
    pub const E_JACKPOT_ALLOWANCE_UNDERFLOW: u64 = 0x1302;

    /// Feature switch errors
    pub const E_FEATURE_UNKNOWN: u64 = 0x1401;
    pub const E_FEATURE_MODE_INVALID: u64 = 0x1402;
    pub const E_FEATURE_DISABLED: u64 = 0x1403;

    /// Validation and view errors
    pub const E_PAGINATION_LIMIT: u64 = 0x1501;

    /// Ticket purchase errors
    pub const E_PURCHASE_QTY_ZERO: u64 = 0x1601;
    pub const E_PURCHASE_QTY_LIMIT: u64 = 0x1602;
    pub const E_PURCHASE_TOTAL_LIMIT: u64 = 0x1603;
    pub const E_PURCHASE_ADDRESS_LIMIT: u64 = 0x1604;
    pub const E_AMOUNT_OVERFLOW: u64 = 0x1605;
    pub const E_PREMIUM_CAP_MISMATCH: u64 = 0x1606;
    pub const E_PREMIUM_CAP_EXPIRED: u64 = 0x1607;

    /// VRF / draw errors
    pub const E_VRF_PENDING: u64 = 0x1701;
    pub const E_VRF_NOT_REQUESTED: u64 = 0x1702;
    pub const E_VRF_NONCE_UNKNOWN: u64 = 0x1703;
    pub const E_VRF_PAYLOAD_MISMATCH: u64 = 0x1704;
    pub const E_VRF_ATTEMPT_OUT_OF_ORDER: u64 = 0x1705;
    pub const E_VRF_RNG_COUNT_INVALID: u64 = 0x1706;
    pub const E_VRF_SNAPSHOT_EMPTY: u64 = 0x1707;
    pub const E_VRF_CONSUMED: u64 = 0x1708;
    pub const E_VRF_RETRY_WINDOW: u64 = 0x1709;
    pub const E_VRF_CLIENT_SEED_OVERFLOW: u64 = 0x170A;

    /// Winner computation / payouts
    pub const E_WINNER_VRF_NOT_READY: u64 = 0x1801;
    pub const E_WINNER_ALL_ASSIGNED: u64 = 0x1802;
    pub const E_WINNER_INDEX_OUT_OF_RANGE: u64 = 0x1803;
    pub const E_WINNER_DEDUP_EXHAUSTED: u64 = 0x1804;
    pub const E_PAYOUT_STATE_MISSING: u64 = 0x1805;
    pub const E_PAYOUT_ROUND_NON_MONOTONIC: u64 = 0x1806;
    pub const E_PAYOUT_COOLDOWN: u64 = 0x1807;
}
