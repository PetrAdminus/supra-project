// sources/history.move
module lottery_multi::history {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::legacy_bridge;

    pub const EVENT_VERSION_V1: u16 = 1;
    pub const EVENT_CATEGORY_REGISTRY: u8 = 1;
    pub const EVENT_CATEGORY_ARCHIVE: u8 = 2;
    pub const EVENT_CATEGORY_SALES: u8 = 3;
    pub const EVENT_CATEGORY_DRAW: u8 = 4;
    pub const EVENT_CATEGORY_PAYOUT: u8 = 5;
    pub const EVENT_CATEGORY_AUTOMATION: u8 = 6;
    pub const EVENT_CATEGORY_INFRA: u8 = 7;

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

    pub struct LegacySummaryImportedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub archive_hash: vector<u8>,
        pub finalized_at: u64,
        pub primary_type: u8,
        pub tags_mask: u64,
    }

    pub struct LegacySummaryRolledBackEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub archive_hash: vector<u8>,
        pub finalized_at: u64,
        pub primary_type: u8,
        pub tags_mask: u64,
    }

    pub struct LegacySummaryClassificationUpdatedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub archive_hash: vector<u8>,
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
        pub total_allocated: u64,
        pub total_prize_paid: u64,
        pub total_operations_paid: u64,
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

    pub struct PartnerPayoutEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub partner: address,
        pub amount: u64,
        pub payout_round: u64,
        pub timestamp: u64,
    }

    pub struct PurchaseRateLimitHitEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub lottery_id: u64,
        pub buyer: address,
        pub timestamp: u64,
        pub current_block: u64,
        pub reason_code: u8,
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

    pub struct VrfDepositSnapshotEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub total_balance: u64,
        pub minimum_balance: u64,
        pub effective_balance: u64,
        pub required_minimum: u64,
        pub effective_floor: u64,
        pub timestamp: u64,
    }

    pub struct VrfDepositAlertEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub total_balance: u64,
        pub minimum_balance: u64,
        pub effective_balance: u64,
        pub required_minimum: u64,
        pub effective_floor: u64,
        pub timestamp: u64,
    }

    pub struct VrfRequestsPausedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub paused_since_ts: u64,
    }

    pub struct VrfRequestsResumedEvent has drop, store {
        pub event_version: u16,
        pub event_category: u8,
        pub resumed_ts: u64,
    }

    struct ArchiveLedger has key {
        summaries: table::Table<u64, LotterySummary>,
        imported_flags: table::Table<u64, bool>,
        ordered_ids: vector<u64>,
        finalized_events: event::EventHandle<LotteryFinalizedEvent>,
        import_events: event::EventHandle<LegacySummaryImportedEvent>,
        rollback_events: event::EventHandle<LegacySummaryRolledBackEvent>,
        classification_events: event::EventHandle<LegacySummaryClassificationUpdatedEvent>,
    }

    pub entry fun init_history(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_MISSING);
        assert!(!exists<ArchiveLedger>(addr), errors::E_ALREADY_INITIALIZED);
        let ledger = ArchiveLedger {
            summaries: table::new(),
            imported_flags: table::new(),
            ordered_ids: vector::empty(),
            finalized_events: event::new_event_handle<LotteryFinalizedEvent>(admin),
            import_events: event::new_event_handle<LegacySummaryImportedEvent>(admin),
            rollback_events: event::new_event_handle<LegacySummaryRolledBackEvent>(admin),
            classification_events: event::new_event_handle<LegacySummaryClassificationUpdatedEvent>(admin),
        };
        move_to(admin, ledger);
    }

    pub fun record_summary(lottery_id: u64, summary: LotterySummary) acquires ArchiveLedger {
        let summary_bytes = bcs::to_bytes(&summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        let finalized_at = summary.finalized_at;
        legacy_bridge::mirror_summary_to_legacy(lottery_id, &summary_bytes, &archive_hash, finalized_at);
        legacy_bridge::notify_summary_written(lottery_id, &archive_hash, finalized_at);
        store_summary(lottery_id, summary, archive_hash, false);
    }

    public entry fun import_legacy_summary_admin(
        admin: &signer,
        lottery_id: u64,
        summary_bytes: vector<u8>,
        expected_hash: vector<u8>,
    ) acquires ArchiveLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let mut summary: LotterySummary = bcs::from_bytes(&summary_bytes);
        assert!(summary.id == lottery_id, errors::E_HISTORY_ID_MISMATCH);
        let primary_type = summary.primary_type;
        let tags_mask = summary.tags_mask;
        let finalized_at = summary.finalized_at;
        let computed_hash = hash::sha3_256(copy summary_bytes);
        assert!(computed_hash == expected_hash, errors::E_HISTORY_IMPORT_HASH);
        legacy_bridge::mirror_summary_to_legacy(lottery_id, &summary_bytes, &computed_hash, finalized_at);
        let hash_for_store = copy computed_hash;
        store_summary(lottery_id, summary, hash_for_store, true);
        let ledger = borrow_ledger_mut();
        let event = LegacySummaryImportedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash: computed_hash,
            finalized_at,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.import_events, event);
    }

    public entry fun rollback_legacy_summary_admin(admin: &signer, lottery_id: u64)
    acquires ArchiveLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.summaries, lottery_id)) {
            abort errors::E_HISTORY_SUMMARY_MISSING;
        };
        let is_legacy = *table::borrow(&ledger.imported_flags, lottery_id);
        assert!(is_legacy, errors::E_HISTORY_NOT_LEGACY);
        let stored_copy = copy *table::borrow(&ledger.summaries, lottery_id);
        let archive_hash = hash::sha3_256(bcs::to_bytes(&stored_copy));
        let finalized_at = stored_copy.finalized_at;
        let primary_type = stored_copy.primary_type;
        let tags_mask = stored_copy.tags_mask;
        table::remove(&mut ledger.summaries, lottery_id);
        table::remove(&mut ledger.imported_flags, lottery_id);
        remove_ordered_id(&mut ledger.ordered_ids, lottery_id);
        let event = LegacySummaryRolledBackEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash,
            finalized_at,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.rollback_events, event);
    }

    public entry fun update_legacy_classification_admin(
        admin: &signer,
        lottery_id: u64,
        primary_type: u8,
        tags_mask: u64,
    ) acquires ArchiveLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::E_HISTORY_NOT_AUTHORIZED);
        let ledger = borrow_ledger_mut();
        if (!table::contains(&ledger.summaries, lottery_id)) {
            abort errors::E_HISTORY_SUMMARY_MISSING;
        };
        let is_legacy = *table::borrow(&ledger.imported_flags, lottery_id);
        assert!(is_legacy, errors::E_HISTORY_NOT_LEGACY);
        let summary = table::borrow_mut(&mut ledger.summaries, lottery_id);
        summary.primary_type = primary_type;
        summary.tags_mask = tags_mask;
        let summary_bytes = bcs::to_bytes(&*summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        legacy_bridge::mirror_summary_to_legacy(lottery_id, &summary_bytes, &archive_hash, summary.finalized_at);
        let event = LegacySummaryClassificationUpdatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_ARCHIVE,
            lottery_id,
            archive_hash,
            primary_type,
            tags_mask,
        };
        event::emit_event(&mut ledger.classification_events, event);
    }

    #[view]
    public fun is_legacy_summary(lottery_id: u64): bool acquires ArchiveLedger {
        let ledger = borrow_ledger_ref();
        if (!table::contains(&ledger.imported_flags, lottery_id)) {
            return false;
        };
        let flag = table::borrow(&ledger.imported_flags, lottery_id);
        *flag
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

    fun store_summary(
        lottery_id: u64,
        summary: LotterySummary,
        archive_hash: vector<u8>,
        is_legacy: bool,
    ) acquires ArchiveLedger {
        let primary_type = summary.primary_type;
        let tags_mask = summary.tags_mask;
        let ledger = borrow_ledger_mut();
        if (table::contains(&ledger.summaries, lottery_id)) {
            let existing_summary = copy *table::borrow(&ledger.summaries, lottery_id);
            let existing_hash = hash::sha3_256(bcs::to_bytes(&existing_summary));
            let imported_flag = *table::borrow(&ledger.imported_flags, lottery_id);
            if (imported_flag) {
                assert!(is_legacy, errors::E_HISTORY_NOT_LEGACY);
            } else {
                assert!(!is_legacy, errors::E_HISTORY_NOT_LEGACY);
                assert!(existing_hash == archive_hash, errors::E_HISTORY_MISMATCH);
            };
            let slot = table::borrow_mut(&mut ledger.summaries, lottery_id);
            *slot = summary;
        } else {
            table::add(&mut ledger.summaries, lottery_id, summary);
            table::add(&mut ledger.imported_flags, lottery_id, is_legacy);
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

    fun remove_ordered_id(ids: &mut vector<u64>, lottery_id: u64) {
        let mut index = 0u64;
        let len = vector::length(ids);
        while (index < len) {
            if (*vector::borrow(ids, index) == lottery_id) {
                vector::remove(ids, index);
                break;
            };
            index = index + 1;
        };
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
