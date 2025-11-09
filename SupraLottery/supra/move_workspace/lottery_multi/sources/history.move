// sources/history.move
module lottery_multi::history {

    pub const EVENT_VERSION_V1: u16 = 1;
    pub const EVENT_CATEGORY_REGISTRY: u8 = 1;
    pub const EVENT_CATEGORY_ARCHIVE: u8 = 2;
    pub const EVENT_CATEGORY_SALES: u8 = 3;
    pub const EVENT_CATEGORY_DRAW: u8 = 4;

    pub struct LotteryCreatedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub id: u64,
        pub cfg_hash: vector<u8>,
        pub config_version: u64,
        pub creator: address,
        pub event_slug: vector<u8>,
        pub series_code: vector<u8>,
        pub run_id: u64,
        pub primary_type: u8,
        pub tags_mask: u64,
        pub slots_checksum: vector<u8>,
    }

    pub struct LotteryFinalizedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub id: u64,
        pub archive_slot_hash: vector<u8>,
        pub primary_type: u8,
        pub tags_mask: u64,
    }

    pub struct VrfRequestedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub request_id: u64,
        pub attempt: u8,
        pub rng_count: u8,
        pub client_seed: u64,
        pub payload_hash: vector<u8>,
        pub snapshot_hash: vector<u8>,
        pub tickets_sold: u64,
        pub closing_block_height: u64,
        pub chain_id: u8,
        pub request_ts: u64,
    }

    pub struct VrfFulfilledEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub request_id: u64,
        pub attempt: u8,
        pub payload_hash: vector<u8>,
        pub message_hash: vector<u8>,
        pub rng_count: u8,
        pub client_seed: u64,
        pub verified_seed_hash: vector<u8>,
        pub closing_block_height: u64,
        pub chain_id: u8,
        pub fulfilled_ts: u64,
    }

    pub struct LotterySummary has drop, store {
        pub id: u64,
        pub status: u8,
        pub event_slug: vector<u8>,
        pub series_code: vector<u8>,
        pub run_id: u64,
        pub tickets_sold: u64,
        pub proceeds_accum: u64,
        pub vrf_status: u8,
        pub primary_type: u8,
        pub tags_mask: u64,
        pub snapshot_hash: vector<u8>,
        pub slots_checksum: vector<u8>,
        pub winners_batch_hash: vector<u8>,
        pub checksum_after_batch: vector<u8>,
        pub payout_round: u64,
        pub created_at: u64,
        pub closed_at: u64,
        pub finalized_at: u64,
    }
}

