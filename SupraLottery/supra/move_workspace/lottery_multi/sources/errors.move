// sources/errors.move
module lottery_multi::errors {
    /// Common tag errors
    pub const E_TAG_PRIMARY_TYPE: u64 = 0x1001;
    pub const E_TAG_UNKNOWN_BIT: u64 = 0x1002;
    pub const E_TAG_BUDGET_EXCEEDED: u64 = 0x1003;

    /// Partner capability errors
    pub const E_PRIMARY_TYPE_NOT_ALLOWED: u64 = 0x1101;
    pub const E_TAG_MASK_NOT_ALLOWED: u64 = 0x1102;
    pub const E_ROLES_NOT_INITIALIZED: u64 = 0x1103;
    pub const E_PAYOUT_BATCH_CAP_MISSING: u64 = 0x1104;
    pub const E_PARTNER_PAYOUT_CAP_MISSING: u64 = 0x1105;
    pub const E_PREMIUM_CAP_MISSING: u64 = 0x1106;
    pub const E_PREMIUM_CAP_EXPIRED: u64 = 0x1107;

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
    pub const E_CANCEL_REASON_INVALID: u64 = 0x1211;
    pub const E_CANCELLATION_RECORD_MISSING: u64 = 0x1212;

    /// Accounting and allocation errors
    pub const E_DISTRIBUTION_BPS_INVALID: u64 = 0x1301;
    pub const E_JACKPOT_ALLOWANCE_UNDERFLOW: u64 = 0x1302;
    pub const E_JACKPOT_ALLOWANCE_INCREASE: u64 = 0x1303;
    pub const E_PAYOUT_ALLOC_EXCEEDED: u64 = 0x1304;
    pub const E_OPERATIONS_ALLOC_EXCEEDED: u64 = 0x1305;

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
    pub const E_PURCHASE_RATE_LIMIT_BLOCK: u64 = 0x1608;
    pub const E_PURCHASE_RATE_LIMIT_WINDOW: u64 = 0x1609;
    pub const E_PURCHASE_GRACE_RESTRICTED: u64 = 0x160A;

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
    pub const E_VRF_DEPOSIT_NOT_INITIALIZED: u64 = 0x170B;
    pub const E_VRF_DEPOSIT_CONFIG: u64 = 0x170C;
    pub const E_VRF_REQUESTS_PAUSED: u64 = 0x170D;

    /// Winner computation / payouts
    pub const E_WINNER_VRF_NOT_READY: u64 = 0x1801;
    pub const E_WINNER_ALL_ASSIGNED: u64 = 0x1802;
    pub const E_WINNER_INDEX_OUT_OF_RANGE: u64 = 0x1803;
    pub const E_WINNER_DEDUP_EXHAUSTED: u64 = 0x1804;
    pub const E_PAYOUT_STATE_MISSING: u64 = 0x1805;
    pub const E_PAYOUT_ROUND_NON_MONOTONIC: u64 = 0x1806;
    pub const E_PAYOUT_COOLDOWN: u64 = 0x1807;
    pub const E_PAYOUT_BATCH_TOO_LARGE: u64 = 0x1808;
    pub const E_PAYOUT_BATCH_COOLDOWN: u64 = 0x1809;
    pub const E_PAYOUT_BATCH_NONCE: u64 = 0x180A;
    pub const E_PAYOUT_OPERATIONS_BUDGET: u64 = 0x180B;
    pub const E_PARTNER_PAYOUT_BUDGET_EXCEEDED: u64 = 0x180C;
    pub const E_PARTNER_PAYOUT_COOLDOWN: u64 = 0x180D;
    pub const E_PARTNER_PAYOUT_NONCE: u64 = 0x180E;
    pub const E_PARTNER_PAYOUT_HOLDER_MISMATCH: u64 = 0x180F;
    pub const E_PARTNER_PAYOUT_EXPIRED: u64 = 0x1810;
    pub const E_REFUND_NOT_ACTIVE: u64 = 0x1811;
    pub const E_REFUND_ROUND_NON_MONOTONIC: u64 = 0x1812;
    pub const E_REFUND_LIMIT_TICKETS: u64 = 0x1813;
    pub const E_REFUND_LIMIT_FUNDS: u64 = 0x1814;
    pub const E_REFUND_STATUS_INVALID: u64 = 0x1815;
    pub const E_REFUND_BATCH_EMPTY: u64 = 0x1816;
    pub const E_REFUND_TIMESTAMP: u64 = 0x1817;
    pub const E_REFUND_PROGRESS_INCOMPLETE: u64 = 0x1818;
    pub const E_REFUND_PROGRESS_FUNDS: u64 = 0x1819;

    /// Price feed errors
    pub const E_PRICE_FEED_EXISTS: u64 = 0x1901;
    pub const E_PRICE_FEED_NOT_FOUND: u64 = 0x1902;
    pub const E_PRICE_DECIMALS_INVALID: u64 = 0x1903;
    pub const E_PRICE_STALE: u64 = 0x1904;
    pub const E_PRICE_FALLBACK_ACTIVE: u64 = 0x1905;
    pub const E_PRICE_CLAMP_TRIGGERED: u64 = 0x1906;
    pub const E_PRICE_CLAMP_ACTIVE: u64 = 0x1907;
    pub const E_PRICE_CLAMP_NOT_ACTIVE: u64 = 0x1908;

    /// Automation / automation bot errors
    pub const E_AUTOBOT_REGISTRY_MISSING: u64 = 0x1A01;
    pub const E_AUTOBOT_ALREADY_REGISTERED: u64 = 0x1A02;
    pub const E_AUTOBOT_NOT_REGISTERED: u64 = 0x1A03;
    pub const E_AUTOBOT_EXPIRED: u64 = 0x1A04;
    pub const E_AUTOBOT_FORBIDDEN_TARGET: u64 = 0x1A05;
    pub const E_AUTOBOT_FAILURE_LIMIT: u64 = 0x1A06;
    pub const E_AUTOBOT_TIMELOCK: u64 = 0x1A07;
    pub const E_AUTOBOT_PENDING_EXISTS: u64 = 0x1A08;
    pub const E_AUTOBOT_PENDING_MISMATCH: u64 = 0x1A09;
    pub const E_AUTOBOT_PENDING_REQUIRED: u64 = 0x1A0A;
    pub const E_AUTOBOT_ACTION_HASH_EMPTY: u64 = 0x1A0B;
    pub const E_AUTOBOT_CALLER_MISMATCH: u64 = 0x1A0C;

    /// История и финализация
    pub const E_HISTORY_MISSING: u64 = 0x1B01;
    pub const E_HISTORY_MISMATCH: u64 = 0x1B02;
    pub const E_FINALIZATION_INCOMPLETE: u64 = 0x1B03;
    pub const E_HISTORY_NOT_AUTHORIZED: u64 = 0x1B04;
    pub const E_HISTORY_EXPECTED_MISSING: u64 = 0x1B05;
    pub const E_HISTORY_CONTROL_MISSING: u64 = 0x1B06;
    pub const E_HISTORY_IMPORT_HASH: u64 = 0x1B07;
    pub const E_HISTORY_ID_MISMATCH: u64 = 0x1B08;
    pub const E_HISTORY_NOT_LEGACY: u64 = 0x1B09;
    pub const E_HISTORY_SUMMARY_MISSING: u64 = 0x1B0A;
}
