// sources/errors.move
module lottery_multi::errors {
    /// Общие ошибки тегов
    pub const E_TAG_PRIMARY_TYPE: u64 = 0x1001;
    pub const E_TAG_UNKNOWN_BIT: u64 = 0x1002;
    pub const E_TAG_BUDGET_EXCEEDED: u64 = 0x1003;

    /// Ошибки партнёрских ограничений
    pub const E_PRIMARY_TYPE_NOT_ALLOWED: u64 = 0x1101;
    pub const E_TAG_MASK_NOT_ALLOWED: u64 = 0x1102;

    /// Ошибки реестра и конфигурации
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

    /// Ошибки учёта и распределения
    pub const E_DISTRIBUTION_BPS_INVALID: u64 = 0x1301;
    pub const E_JACKPOT_ALLOWANCE_UNDERFLOW: u64 = 0x1302;

    /// Ошибки feature switch
    pub const E_FEATURE_UNKNOWN: u64 = 0x1401;
    pub const E_FEATURE_MODE_INVALID: u64 = 0x1402;

    /// Ошибки валидации и вьюх
    pub const E_PAGINATION_LIMIT: u64 = 0x1501;
}
