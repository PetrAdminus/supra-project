// sources/history.move
module lottery_multi::history {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;

    use lottery_multi::errors;
    use lottery_multi::math;
    use lottery_multi::legacy_bridge;

    const EVENT_VERSION_V1: u16 = 1;
    const EVENT_CATEGORY_REGISTRY: u8 = 1;
    const EVENT_CATEGORY_ARCHIVE: u8 = 2;
    const EVENT_CATEGORY_SALES: u8 = 3;
    const EVENT_CATEGORY_DRAW: u8 = 4;
    const EVENT_CATEGORY_PAYOUT: u8 = 5;
    const EVENT_CATEGORY_AUTOMATION: u8 = 6;
    const EVENT_CATEGORY_INFRA: u8 = 7;
    const EVENT_CATEGORY_REFUND: u8 = 8;

    struct LotteryCreatedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        id: u64,
        cfg_hash: vector<u8>,
        config_version: u64,
        creator: address,
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        primary_type: u8,
        tags_mask: u64,
        slots_checksum: vector<u8>,
    }

    struct LotteryCanceledEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        previous_status: u8,
        reason_code: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        timestamp: u64,
    }

    struct LotteryFinalizedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        id: u64,
        archive_slot_hash: vector<u8>,
        primary_type: u8,
        tags_mask: u64,
    }

    struct LegacySummaryImportedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
    }

    struct LegacySummaryRolledBackEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
        primary_type: u8,
        tags_mask: u64,
    }

    struct LegacySummaryClassificationUpdatedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        archive_hash: vector<u8>,
        primary_type: u8,
        tags_mask: u64,
    }

    struct VrfRequestedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        request_id: u64,
        attempt: u8,
        rng_count: u8,
        client_seed: u64,
        payload_hash: vector<u8>,
        snapshot_hash: vector<u8>,
        tickets_sold: u64,
        closing_block_height: u64,
        chain_id: u8,
        request_ts: u64,
    }

    struct VrfFulfilledEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        request_id: u64,
        attempt: u8,
        payload_hash: vector<u8>,
        message_hash: vector<u8>,
        rng_count: u8,
        client_seed: u64,
        verified_seed_hash: vector<u8>,
        closing_block_height: u64,
        chain_id: u8,
        fulfilled_ts: u64,
    }

    struct LotterySummary has copy, drop, store {
        id: u64,
        status: u8,
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        tickets_sold: u64,
        proceeds_accum: u64,
        total_allocated: u64,
        total_prize_paid: u64,
        total_operations_paid: u64,
        vrf_status: u8,
        primary_type: u8,
        tags_mask: u64,
        snapshot_hash: vector<u8>,
        slots_checksum: vector<u8>,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
        payout_round: u64,
        created_at: u64,
        closed_at: u64,
        finalized_at: u64,
    }

    public fun new_summary(
        id: u64,
        status: u8,
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        tickets_sold: u64,
        proceeds_accum: u64,
        total_allocated: u64,
        total_prize_paid: u64,
        total_operations_paid: u64,
        vrf_status: u8,
        primary_type: u8,
        tags_mask: u64,
        snapshot_hash: vector<u8>,
        slots_checksum: vector<u8>,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
        payout_round: u64,
        created_at: u64,
        closed_at: u64,
        finalized_at: u64,
    ): LotterySummary {
        LotterySummary {
            id,
            status,
            event_slug,
            series_code,
            run_id,
            tickets_sold,
            proceeds_accum,
            total_allocated,
            total_prize_paid,
            total_operations_paid,
            vrf_status,
            primary_type,
            tags_mask,
            snapshot_hash,
            slots_checksum,
            winners_batch_hash,
            checksum_after_batch,
            payout_round,
            created_at,
            closed_at,
            finalized_at,
        }
    }

    struct WinnersComputedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        batch_no: u64,
        assigned_in_batch: u64,
        total_assigned: u64,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
    }

    struct PayoutBatchEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        payout_round: u64,
        winners_paid: u64,
        prize_paid: u64,
        operations_paid: u64,
        timestamp: u64,
    }

    struct PartnerPayoutEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        partner: address,
        amount: u64,
        payout_round: u64,
        timestamp: u64,
    }

    struct RefundBatchEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        refund_round: u64,
        tickets_refunded: u64,
        prize_refunded: u64,
        operations_refunded: u64,
        total_tickets_refunded: u64,
        total_amount_refunded: u64,
        timestamp: u64,
    }

    struct PurchaseRateLimitHitEvent has drop, store {
        event_version: u16,
        event_category: u8,
        lottery_id: u64,
        buyer: address,
        timestamp: u64,
        current_block: u64,
        reason_code: u8,
    }

    struct AutomationDryRunPlannedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        executes_after_ts: u64,
    }

    struct AutomationCallRejectedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    }

    struct AutomationKeyRotatedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        operator: address,
        schedule_hash: vector<u8>,
        expires_at: u64,
    }

    struct AutomationTickEvent has drop, store {
        event_version: u16,
        event_category: u8,
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        executed_ts: u64,
        success: bool,
        reputation_score: u64,
        success_streak: u64,
        failure_count: u64,
    }

    struct AutomationErrorEvent has drop, store {
        event_version: u16,
        event_category: u8,
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        error_code: u64,
        timestamp: u64,
    }

    struct VrfDepositSnapshotEvent has drop, store {
        event_version: u16,
        event_category: u8,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    }

    struct VrfDepositAlertEvent has drop, store {
        event_version: u16,
        event_category: u8,
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    }

    struct VrfRequestsPausedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        paused_since_ts: u64,
    }

    struct VrfRequestsResumedEvent has drop, store {
        event_version: u16,
        event_category: u8,
        resumed_ts: u64,
    }

    //
    // Event constructors (Move v1 compatibility)
    //

    public fun new_lottery_created_event(
        id: u64,
        cfg_hash: vector<u8>,
        config_version: u64,
        creator: address,
        event_slug: vector<u8>,
        series_code: vector<u8>,
        run_id: u64,
        primary_type: u8,
        tags_mask: u64,
        slots_checksum: vector<u8>,
    ): LotteryCreatedEvent {
        LotteryCreatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_REGISTRY,
            id,
            cfg_hash,
            config_version,
            creator,
            event_slug,
            series_code,
            run_id,
            primary_type,
            tags_mask,
            slots_checksum,
        }
    }

    public fun new_lottery_canceled_event(
        lottery_id: u64,
        previous_status: u8,
        reason_code: u8,
        tickets_sold: u64,
        proceeds_accum: u64,
        timestamp: u64,
    ): LotteryCanceledEvent {
        LotteryCanceledEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_REGISTRY,
            lottery_id,
            previous_status,
            reason_code,
            tickets_sold,
            proceeds_accum,
            timestamp,
        }
    }

    public fun new_vrf_requested_event(
        lottery_id: u64,
        request_id: u64,
        attempt: u8,
        rng_count: u8,
        client_seed: u64,
        payload_hash: vector<u8>,
        snapshot_hash: vector<u8>,
        tickets_sold: u64,
        closing_block_height: u64,
        chain_id: u8,
        request_ts: u64,
    ): VrfRequestedEvent {
        VrfRequestedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_DRAW,
            lottery_id,
            request_id,
            attempt,
            rng_count,
            client_seed,
            payload_hash,
            snapshot_hash,
            tickets_sold,
            closing_block_height,
            chain_id,
            request_ts,
        }
    }

    public fun new_vrf_fulfilled_event(
        lottery_id: u64,
        request_id: u64,
        attempt: u8,
        payload_hash: vector<u8>,
        message_hash: vector<u8>,
        rng_count: u8,
        client_seed: u64,
        verified_seed_hash: vector<u8>,
        closing_block_height: u64,
        chain_id: u8,
        fulfilled_ts: u64,
    ): VrfFulfilledEvent {
        VrfFulfilledEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_DRAW,
            lottery_id,
            request_id,
            attempt,
            payload_hash,
            message_hash,
            rng_count,
            client_seed,
            verified_seed_hash,
            closing_block_height,
            chain_id,
            fulfilled_ts,
        }
    }

    public fun new_winners_computed_event(
        lottery_id: u64,
        batch_no: u64,
        assigned_in_batch: u64,
        total_assigned: u64,
        winners_batch_hash: vector<u8>,
        checksum_after_batch: vector<u8>,
    ): WinnersComputedEvent {
        WinnersComputedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            batch_no,
            assigned_in_batch,
            total_assigned,
            winners_batch_hash,
            checksum_after_batch,
        }
    }

    public fun new_payout_batch_event(
        lottery_id: u64,
        payout_round: u64,
        winners_paid: u64,
        prize_paid: u64,
        operations_paid: u64,
        timestamp: u64,
    ): PayoutBatchEvent {
        PayoutBatchEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            payout_round,
            winners_paid,
            prize_paid,
            operations_paid,
            timestamp,
        }
    }

    public fun new_partner_payout_event(
        lottery_id: u64,
        partner: address,
        amount: u64,
        payout_round: u64,
        timestamp: u64,
    ): PartnerPayoutEvent {
        PartnerPayoutEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_PAYOUT,
            lottery_id,
            partner,
            amount,
            payout_round,
            timestamp,
        }
    }

    public fun new_refund_batch_event(
        lottery_id: u64,
        refund_round: u64,
        tickets_refunded: u64,
        prize_refunded: u64,
        operations_refunded: u64,
        total_tickets_refunded: u64,
        total_amount_refunded: u64,
        timestamp: u64,
    ): RefundBatchEvent {
        RefundBatchEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_REFUND,
            lottery_id,
            refund_round,
            tickets_refunded,
            prize_refunded,
            operations_refunded,
            total_tickets_refunded,
            total_amount_refunded,
            timestamp,
        }
    }

    public fun new_purchase_rate_limit_hit_event(
        lottery_id: u64,
        buyer: address,
        timestamp: u64,
        current_block: u64,
        reason_code: u8,
    ): PurchaseRateLimitHitEvent {
        PurchaseRateLimitHitEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_SALES,
            lottery_id,
            buyer,
            timestamp,
            current_block,
            reason_code,
        }
    }

    public fun new_automation_dry_run_planned_event(
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        executes_after_ts: u64,
    ): AutomationDryRunPlannedEvent {
        AutomationDryRunPlannedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash,
            executes_after_ts,
        }
    }

    public fun new_automation_call_rejected_event(
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        reason_code: u64,
    ): AutomationCallRejectedEvent {
        AutomationCallRejectedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash,
            reason_code,
        }
    }

    public fun new_automation_tick_event(
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        executed_ts: u64,
        success: bool,
        reputation_score: u64,
        success_streak: u64,
        failure_count: u64,
    ): AutomationTickEvent {
        AutomationTickEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash,
            executed_ts,
            success,
            reputation_score,
            success_streak,
            failure_count,
        }
    }

    public fun new_automation_error_event(
        operator: address,
        action_id: u64,
        action_hash: vector<u8>,
        error_code: u64,
        timestamp: u64,
    ): AutomationErrorEvent {
        AutomationErrorEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            action_id,
            action_hash,
            error_code,
            timestamp,
        }
    }

    public fun new_automation_key_rotated_event(
        operator: address,
        schedule_hash: vector<u8>,
        expires_at: u64,
    ): AutomationKeyRotatedEvent {
        AutomationKeyRotatedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_AUTOMATION,
            operator,
            schedule_hash,
            expires_at,
        }
    }

    public fun new_vrf_deposit_snapshot_event(
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ): VrfDepositSnapshotEvent {
        VrfDepositSnapshotEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        }
    }

    public fun new_vrf_deposit_alert_event(
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        effective_floor: u64,
        timestamp: u64,
    ): VrfDepositAlertEvent {
        VrfDepositAlertEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            total_balance,
            minimum_balance,
            effective_balance,
            required_minimum,
            effective_floor,
            timestamp,
        }
    }

    public fun new_vrf_requests_paused_event(paused_since_ts: u64): VrfRequestsPausedEvent {
        VrfRequestsPausedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            paused_since_ts,
        }
    }

    public fun new_vrf_requests_resumed_event(resumed_ts: u64): VrfRequestsResumedEvent {
        VrfRequestsResumedEvent {
            event_version: EVENT_VERSION_V1,
            event_category: EVENT_CATEGORY_INFRA,
            resumed_ts,
        }
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

    public entry fun init_history(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_missing());
        assert!(!exists<ArchiveLedger>(addr), errors::err_already_initialized());
        let ledger = ArchiveLedger {
            summaries: table::new(),
            imported_flags: table::new(),
            ordered_ids: vector::empty(),
            finalized_events: account::new_event_handle<LotteryFinalizedEvent>(admin),
            import_events: account::new_event_handle<LegacySummaryImportedEvent>(admin),
            rollback_events: account::new_event_handle<LegacySummaryRolledBackEvent>(admin),
            classification_events: account::new_event_handle<LegacySummaryClassificationUpdatedEvent>(admin),
        };
        move_to(admin, ledger);
    }

    public fun record_summary(lottery_id: u64, summary: LotterySummary) acquires ArchiveLedger {
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
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let summary = decode_summary(&summary_bytes);
        assert!(summary.id == lottery_id, errors::err_history_id_mismatch());
        let primary_type = summary.primary_type;
        let tags_mask = summary.tags_mask;
        let finalized_at = summary.finalized_at;
        let computed_hash = hash::sha3_256(copy summary_bytes);
        assert!(computed_hash == expected_hash, errors::err_history_import_hash());
        legacy_bridge::mirror_summary_to_legacy(lottery_id, &summary_bytes, &computed_hash, finalized_at);
        legacy_bridge::notify_summary_written(lottery_id, &computed_hash, finalized_at);
        let hash_for_store = copy computed_hash;
        store_summary(lottery_id, summary, hash_for_store, true);
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<ArchiveLedger>(ledger_addr);
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

    public entry fun mirror_summary_admin(
        admin: &signer,
        lottery_id: u64,
    ) acquires ArchiveLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        if (!legacy_bridge::is_mirror_enabled()) {
            return
        };
        let summary = get_summary(lottery_id);
        let summary_bytes = bcs::to_bytes(&summary);
        let archive_hash = hash::sha3_256(copy summary_bytes);
        legacy_bridge::mirror_summary_to_legacy(lottery_id, &summary_bytes, &archive_hash, summary.finalized_at);
        legacy_bridge::notify_summary_written(lottery_id, &archive_hash, summary.finalized_at);
    }

    public entry fun rollback_legacy_summary_admin(admin: &signer, lottery_id: u64)
    acquires ArchiveLedger {
        let addr = signer::address_of(admin);
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<ArchiveLedger>(ledger_addr);
        if (!table::contains(&ledger.summaries, lottery_id)) {
            abort errors::err_history_summary_missing()
        };
        let is_legacy = *table::borrow(&ledger.imported_flags, lottery_id);
        assert!(is_legacy, errors::err_history_not_legacy());
        let stored_ref = table::borrow(&ledger.summaries, lottery_id);
        let stored_copy = clone_summary(stored_ref);
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
        assert!(addr == @lottery_multi, errors::err_history_not_authorized());
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<ArchiveLedger>(ledger_addr);
        if (!table::contains(&ledger.summaries, lottery_id)) {
            abort errors::err_history_summary_missing()
        };
        let is_legacy = *table::borrow(&ledger.imported_flags, lottery_id);
        assert!(is_legacy, errors::err_history_not_legacy());
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
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global<ArchiveLedger>(ledger_addr);
        if (!table::contains(&ledger.imported_flags, lottery_id)) {
            return false
        };
        let flag = table::borrow(&ledger.imported_flags, lottery_id);
        *flag
    }

    public fun get_summary(id: u64): LotterySummary acquires ArchiveLedger {
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global<ArchiveLedger>(ledger_addr);
        let summary = table::borrow(&ledger.summaries, id);
        clone_summary(summary)
    }

    public fun list_finalized(from: u64, limit: u64): vector<u64> acquires ArchiveLedger {
        assert!(limit <= 1000, errors::err_pagination_limit());
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global<ArchiveLedger>(ledger_addr);
        let ids = &ledger.ordered_ids;
        let result = vector::empty<u64>();
        let skipped = 0u64;
        let taken = 0u64;
        let index = vector::length(ids);
        while (index > 0) {
            index = index - 1;
            let lottery_id = *vector::borrow(ids, index);
            if (skipped < from) {
                skipped = skipped + 1;
                continue
            };
            if (taken >= limit) {
                break
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
        let ledger_addr = ledger_addr_or_abort();
        let ledger = borrow_global_mut<ArchiveLedger>(ledger_addr);
        if (table::contains(&ledger.summaries, lottery_id)) {
            let existing_summary = clone_summary(table::borrow(&ledger.summaries, lottery_id));
            let existing_hash = hash::sha3_256(bcs::to_bytes(&existing_summary));
            let imported_flag = *table::borrow(&ledger.imported_flags, lottery_id);
            if (imported_flag) {
                assert!(is_legacy, errors::err_history_not_legacy());
            } else {
                assert!(!is_legacy, errors::err_history_not_legacy());
                assert!(existing_hash == archive_hash, errors::err_history_mismatch());
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
        let index = 0u64;
        let len = vector::length(ids);
        while (index < len) {
            if (*vector::borrow(ids, index) == lottery_id) {
                vector::remove(ids, index);
                break
            };
            index = index + 1;
        };
    }

    fun ledger_addr_or_abort(): address {
        let addr = @lottery_multi;
        if (!exists<ArchiveLedger>(addr)) {
            abort errors::err_history_missing()
        };
        addr
    }

    fun clone_summary(summary: &LotterySummary): LotterySummary {
        LotterySummary {
            id: summary.id,
            status: summary.status,
            event_slug: clone_bytes(&summary.event_slug),
            series_code: clone_bytes(&summary.series_code),
            run_id: summary.run_id,
            tickets_sold: summary.tickets_sold,
            proceeds_accum: summary.proceeds_accum,
            total_allocated: summary.total_allocated,
            total_prize_paid: summary.total_prize_paid,
            total_operations_paid: summary.total_operations_paid,
            vrf_status: summary.vrf_status,
            primary_type: summary.primary_type,
            tags_mask: summary.tags_mask,
            snapshot_hash: clone_bytes(&summary.snapshot_hash),
            slots_checksum: clone_bytes(&summary.slots_checksum),
            winners_batch_hash: clone_bytes(&summary.winners_batch_hash),
            checksum_after_batch: clone_bytes(&summary.checksum_after_batch),
            payout_round: summary.payout_round,
            created_at: summary.created_at,
            closed_at: summary.closed_at,
            finalized_at: summary.finalized_at,
        }
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
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

    fun decode_summary(bytes: &vector<u8>): LotterySummary {
        let offset = 0u64;
        decode_summary_at(bytes, &mut offset)
    }

    fun decode_summary_at(bytes: &vector<u8>, cursor: &mut u64): LotterySummary {
        let summary = LotterySummary {
            id: read_u64_le(bytes, cursor),
            status: read_u8(bytes, cursor),
            event_slug: read_bytes(bytes, cursor),
            series_code: read_bytes(bytes, cursor),
            run_id: read_u64_le(bytes, cursor),
            tickets_sold: read_u64_le(bytes, cursor),
            proceeds_accum: read_u64_le(bytes, cursor),
            total_allocated: read_u64_le(bytes, cursor),
            total_prize_paid: read_u64_le(bytes, cursor),
            total_operations_paid: read_u64_le(bytes, cursor),
            vrf_status: read_u8(bytes, cursor),
            primary_type: read_u8(bytes, cursor),
            tags_mask: read_u64_le(bytes, cursor),
            snapshot_hash: read_bytes(bytes, cursor),
            slots_checksum: read_bytes(bytes, cursor),
            winners_batch_hash: read_bytes(bytes, cursor),
            checksum_after_batch: read_bytes(bytes, cursor),
            payout_round: read_u64_le(bytes, cursor),
            created_at: read_u64_le(bytes, cursor),
            closed_at: read_u64_le(bytes, cursor),
            finalized_at: read_u64_le(bytes, cursor),
        };
        assert!(*cursor == vector::length(bytes), errors::err_history_decode());
        summary
    }

    fun read_u8(data: &vector<u8>, cursor: &mut u64): u8 {
        if (*cursor >= vector::length(data)) {
            abort errors::err_history_decode()
        };
        let value = *vector::borrow(data, *cursor);
        *cursor = *cursor + 1;
        value
    }

    fun read_u64_le(data: &vector<u8>, cursor: &mut u64): u64 {
        let result = 0u64;
        let shift = 0u8;
        while (shift < 64u8) {
            let byte = read_u8(data, cursor);
            result = result | (math::widen_u64_from_u8(byte) << shift);
            shift = shift + 8u8;
        };
        result
    }

    fun read_bytes(data: &vector<u8>, cursor: &mut u64): vector<u8> {
        let len = read_uleb128(data, cursor);
        let total_len = vector::length(data);
        let remaining = total_len - *cursor;
        assert!(len <= remaining, errors::err_history_decode());
        let result = vector::empty<u8>();
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(data, *cursor);
            vector::push_back(&mut result, byte);
            *cursor = *cursor + 1;
            i = i + 1;
        };
        result
    }

    fun read_uleb128(data: &vector<u8>, cursor: &mut u64): u64 {
        let result = 0u64;
        let shift = 0u8;
        loop {
            let byte = read_u8(data, cursor);
            let value = math::widen_u64_from_u8(byte) & 0x7Fu64;
            result = result | (value << shift);
            if ((byte & 0x80u8) == 0u8) {
                break
            };
            shift = shift + 7u8;
            assert!(shift < 64u8, errors::err_history_decode());
        };
        result
    }

    #[test_only]
    public fun decode_summary_for_test(bytes: vector<u8>): LotterySummary {
        let cursor = 0u64;
        decode_summary_at(&bytes, &mut cursor)
    }

    //
    // Summary getters for tests
    //

    public fun lottery_summary_id(summary: &LotterySummary): u64 {
        summary.id
    }

    public fun lottery_summary_primary_type(summary: &LotterySummary): u8 {
        summary.primary_type
    }

    public fun lottery_summary_tags_mask(summary: &LotterySummary): u64 {
        summary.tags_mask
    }

    public fun lottery_summary_finalized_at(summary: &LotterySummary): u64 {
        summary.finalized_at
    }

    public fun lottery_summary_status(summary: &LotterySummary): u8 {
        summary.status
    }

    public fun lottery_summary_tickets_sold(summary: &LotterySummary): u64 {
        summary.tickets_sold
    }

    public fun lottery_summary_proceeds_accum(summary: &LotterySummary): u64 {
        summary.proceeds_accum
    }

    public fun lottery_summary_total_allocated(summary: &LotterySummary): u64 {
        summary.total_allocated
    }

    public fun lottery_summary_total_prize_paid(summary: &LotterySummary): u64 {
        summary.total_prize_paid
    }

    public fun lottery_summary_total_operations_paid(summary: &LotterySummary): u64 {
        summary.total_operations_paid
    }

    public fun lottery_summary_payout_round(summary: &LotterySummary): u64 {
        summary.payout_round
    }

    public fun lottery_summary_closed_at(summary: &LotterySummary): u64 {
        summary.closed_at
    }

    public fun lottery_summary_vrf_status(summary: &LotterySummary): u8 {
        summary.vrf_status
    }
}
