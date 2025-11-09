// sources/types.move
module lottery_multi::types {
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

    pub const RETRY_STRATEGY_FIXED: u8 = 0;
    pub const RETRY_STRATEGY_EXPONENTIAL: u8 = 1;

    pub const DEFAULT_SCHEMA_VERSION: u16 = 1;

    pub struct SalesWindow has copy, drop, store {
        pub sales_start: u64,
        pub sales_end: u64,
    }

    pub struct TicketLimits has copy, drop, store {
        pub max_tickets_total: u64,
        pub max_tickets_per_address: u64,
    }

    pub struct VrfState has copy, drop, store {
        pub request_id: vector<u8>,
        pub payload_hash: vector<u8>,
        pub schema_version: u16,
        pub attempt: u8,
        pub consumed: bool,
        pub retry_after_ts: u64,
        pub retry_strategy: u8,
        pub closing_block_height: u64,
        pub chain_id: u8,
    }

    pub struct WinnerCursor has copy, drop, store {
        pub last_processed_index: u64,
        pub checksum_after_batch: vector<u8>,
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

    pub fun new_vrf_state(): VrfState {
        VrfState {
            request_id: b"",
            payload_hash: b"",
            schema_version: DEFAULT_SCHEMA_VERSION,
            attempt: 0,
            consumed: false,
            retry_after_ts: 0,
            retry_strategy: RETRY_STRATEGY_FIXED,
            closing_block_height: 0,
            chain_id: 0,
        }
    }
}
