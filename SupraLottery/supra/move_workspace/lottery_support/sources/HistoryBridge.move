// sources/HistoryBridge.move
module lottery_support::history_bridge {

    use std::option;
    use std::signer;
    use std::table;

    use supra_framework::account;
    use supra_framework::event;

    const E_NOT_AUTHORIZED: u64 = 0x101;

    struct LegacySummary has copy, drop, store {
        summary_bcs: vector<u8>,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    struct LegacySummaryEvent has drop, store {
        lottery_id: u64,
        archive_hash: vector<u8>,
        finalized_at: u64,
    }

    struct LegacyArchive has key {
        summaries: table::Table<u64, LegacySummary>,
        summary_events: event::EventHandle<LegacySummaryEvent>,
    }

    public entry fun init_bridge(admin: &signer) {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<LegacyArchive>(@lottery)) {
            return
        };
        let archive = LegacyArchive {
            summaries: table::new(),
            summary_events: account::new_event_handle<LegacySummaryEvent>(admin),
        };
        move_to(admin, archive);
    }

    public fun record_summary(
        lottery_id: u64,
        summary_bcs: vector<u8>,
        archive_hash: vector<u8>,
        finalized_at: u64,
    ) acquires LegacyArchive {
        if (!exists<LegacyArchive>(@lottery)) {
            return
        };
        let archive = borrow_global_mut<LegacyArchive>(@lottery);
        if (table::contains(&archive.summaries, lottery_id)) {
            let existing = table::borrow_mut(&mut archive.summaries, lottery_id);
            existing.summary_bcs = copy summary_bcs;
            existing.archive_hash = copy archive_hash;
            existing.finalized_at = finalized_at;
        } else {
            let entry = LegacySummary {
                summary_bcs: copy summary_bcs,
                archive_hash: copy archive_hash,
                finalized_at,
            };
            table::add(&mut archive.summaries, lottery_id, entry);
        };
        let event = LegacySummaryEvent {
            lottery_id,
            archive_hash,
            finalized_at,
        };
        event::emit_event(&mut archive.summary_events, event);
    }

    public fun get_summary(lottery_id: u64): option::Option<LegacySummary> acquires LegacyArchive {
        if (!exists<LegacyArchive>(@lottery)) {
            return option::none<LegacySummary>()
        };
        let archive = borrow_global<LegacyArchive>(@lottery);
        if (!table::contains(&archive.summaries, lottery_id)) {
            option::none<LegacySummary>()
        } else {
            let summary = table::borrow(&archive.summaries, lottery_id);
            option::some(*summary)
        }
    }

    public fun legacy_summary_summary_bcs(summary: &LegacySummary): vector<u8> {
        let bytes_ref = &summary.summary_bcs;
        *bytes_ref
    }

    public fun legacy_summary_archive_hash(summary: &LegacySummary): vector<u8> {
        let hash_ref = &summary.archive_hash;
        *hash_ref
    }

    public fun legacy_summary_finalized_at(summary: &LegacySummary): u64 {
        let ts_ref = &summary.finalized_at;
        *ts_ref
    }

    public fun is_initialized(): bool {
        exists<LegacyArchive>(@lottery)
    }
}
