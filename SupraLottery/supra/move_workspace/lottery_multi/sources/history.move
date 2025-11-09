// sources/history.move
module lottery_multi::history {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::event;

    use lottery_multi::errors;

    pub const EVENT_VERSION_V1: u16 = 1;
    pub const EVENT_CATEGORY_REGISTRY: u8 = 1;
    pub const EVENT_CATEGORY_ARCHIVE: u8 = 2;
    pub const EVENT_CATEGORY_SALES: u8 = 3;
    pub const EVENT_CATEGORY_DRAW: u8 = 4;
    pub const EVENT_CATEGORY_PAYOUT: u8 = 5;
    pub const EVENT_CATEGORY_AUTOMATION: u8 = 6;

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

    pub struct LotterySummary has copy, drop, store {
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

    pub struct WinnersComputedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub batch_no: u64,
        pub assigned_in_batch: u64,
        pub total_assigned: u64,
        pub winners_batch_hash: vector<u8>,
        pub checksum_after_batch: vector<u8>,
    }

    pub struct PayoutBatchEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub payout_round: u64,
        pub winners_paid: u64,
        pub prize_paid: u64,
        pub operations_paid: u64,
        pub timestamp: u64,
    }

    pub struct AutomationDryRunPlannedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub operator: address,
        pub action_id: u64,
        pub action_hash: vector<u8>,
        pub executes_after_ts: u64,
    }

    pub struct AutomationCallRejectedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub operator: address,
        pub action_id: u64,
        pub action_hash: vector<u8>,
        pub reason_code: u64,
    }

    pub struct AutomationKeyRotatedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub operator: address,
        pub schedule_hash: vector<u8>,
        pub expires_at: u64,
    }

    pub struct AutomationTickEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub operator: address,
        pub action_id: u64,
        pub action_hash: vector<u8>,
        pub executed_ts: u64,
        pub success: bool,
        pub reputation_score: u64,
        pub success_streak: u64,
        pub failure_count: u64,
    }

    pub struct AutomationErrorEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub operator: address,
        pub action_id: u64,
        pub action_hash: vector<u8>,
        pub error_code: u64,
        pub timestamp: u64,
    }

    struct ArchiveLedger has key {
        summaries: table::Table<u64, LotterySummary>,
        ordered_ids: vector<u64>,
        finalized_events: event::EventHandle<LotteryFinalizedEvent>,
    }

    pub entry fun init_history(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_MISSING);
        assert!(!exists<ArchiveLedger>(addr), errors::E_ALREADY_INITIALIZED);
        let ledger = ArchiveLedger {
            summaries: table::new(),
            ordered_ids: vector::empty(),
            finalized_events: event::new_event_handle<LotteryFinalizedEvent>(admin),
        };
        move_to(admin, ledger);
    }

    pub fun record_summary(lottery_id: u64, summary: LotterySummary) acquires ArchiveLedger {
        let ledger = borrow_ledger_mut();
        let summary_bytes = bcs::to_bytes(&summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        let primary_type = summary.primary_type;
        let tags_mask = summary.tags_mask;
        if (table::contains(&ledger.summaries, lottery_id)) {
            let existing = table::borrow_mut(&mut ledger.summaries, lottery_id);
            let existing_bytes = bcs::to_bytes(&*existing);
            let existing_hash = hash::sha3_256(existing_bytes);
            assert!(existing_hash == archive_hash, errors::E_HISTORY_MISMATCH);
            *existing = summary;
        } else {
            table::add(&mut ledger.summaries, lottery_id, summary);
            vector::push_back(&mut ledger.ordered_ids, lottery_id);
        };
        let event = LotteryFinalizedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            id: lottery_id,
            archive_slot_hash: archive_hash,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.finalized_events, event);
    }

    pub fun get_summary(id: u64): LotterySummary acquires ArchiveLedger {
        let ledger = borrow_ledger_ref();
        let summary = table::borrow(&ledger.summaries, id);
        copy *summary
    }

    pub fun list_finalized(from: u64, limit: u64): vector<u64> acquires ArchiveLedger {
        assert!(limit <= 1000, errors::E_PAGINATION_LIMIT);
        let ledger = borrow_ledger_ref();
        let ids = &ledger.ordered_ids;
        let mut result = vector::empty<u64>();
        let mut skipped = 0u64;
        let mut taken = 0u64;
        let mut index = vector::length(ids);
        while (index > 0) {
            index = index - 1;
            let lottery_id = *vector::borrow(ids, index);
            if (skipped < from) {
                skipped = skipped + 1;
                continue;
            };
            if (taken >= limit) {
                break;
            };
            vector::push_back(&mut result, lottery_id);
            taken = taken + 1;
        };
        result
    }

    fun borrow_ledger_mut(): &mut ArchiveLedger acquires ArchiveLedger {
        let addr = @lottery_multi;
        if (!exists<ArchiveLedger>(addr)) {
            abort errors::E_HISTORY_MISSING;
        };
        borrow_global_mut<ArchiveLedger>(addr)
    }

    fun borrow_ledger_ref(): &ArchiveLedger acquires ArchiveLedger {
        let addr = @lottery_multi;
        if (!exists<ArchiveLedger>(addr)) {
            abort errors::E_HISTORY_MISSING;
        };
        borrow_global<ArchiveLedger>(addr)
    }
}
