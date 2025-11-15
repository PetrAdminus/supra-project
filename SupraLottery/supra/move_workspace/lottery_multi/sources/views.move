// sources/views.move
module lottery_multi::views {
    use std::option;
    use std::string;
    use std::vector;

    use lottery_multi::automation;
    use lottery_multi::draw;
    use lottery_multi::history;
    use lottery_multi::economics;
    use lottery_multi::payouts;
    use lottery_multi::sales;
    use lottery_multi::lottery_registry;
    use lottery_multi::errors;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::vrf_deposit;

    struct BadgeMetadata has drop, store {
        primary_label: string::String,
        is_experimental: bool,
        tags_mask: u64,
    }

    struct LotteryStatusView has drop, store {
        status: u8,
        snapshot_frozen: bool,
        primary_type: u8,
        tags_mask: u64,
    }

    struct VrfDepositStatusView has drop, store {
        total_balance: u64,
        minimum_balance: u64,
        effective_balance: u64,
        required_minimum: u64,
        last_update_ts: u64,
        requests_paused: bool,
        paused_since_ts: u64,
    }

    const REFUND_FIRST_BATCH_SLA_SECS: u64 = 43_200;
    const REFUND_FULL_SLA_SECS: u64 = 86_400;

    struct StatusOverview has drop, store {
        total: u64,
        draft: u64,
        active: u64,
        closing: u64,
        draw_requested: u64,
        drawn: u64,
        payout: u64,
        finalized: u64,
        canceled: u64,
        vrf_requested: u64,
        vrf_fulfilled_pending: u64,
        vrf_retry_blocked: u64,
        winners_pending: u64,
        payout_backlog: u64,
        refund_active: u64,
        refund_batch_pending: u64,
        refund_sla_breach: bool,
    }

    struct AutomationBotView has drop, store {
        operator: address,
        allowed_actions: vector<u64>,
        timelock_secs: u64,
        max_failures: u64,
        failure_count: u64,
        success_streak: u64,
        reputation_score: u64,
        has_pending: bool,
        pending_execute_after: u64,
        pending_action_hash: vector<u8>,
        expires_at: u64,
        cron_spec: vector<u8>,
        last_action_ts: u64,
        last_action_hash: vector<u8>,
    }

    public fun validate_config(id: u64) {
        let primary_type = lottery_registry::primary_type(id);
        let tags_mask = lottery_registry::tags_mask(id);
        let sales_window = lottery_registry::sales_window_view(id);
        let ticket_price = lottery_registry::ticket_price(id);
        let ticket_limits = lottery_registry::ticket_limits(id);
        let distribution = lottery_registry::sales_distribution_view(id);
        let prize_plan = lottery_registry::clone_prize_plan(id);
        let draw_algo = lottery_registry::draw_algo(id);
        tags::validate(primary_type, tags_mask);
        tags::assert_tag_budget(tags_mask);
        types::assert_sales_window(&sales_window);
        types::assert_ticket_price(ticket_price);
        types::assert_ticket_limits(&ticket_limits);
        economics::assert_distribution(&distribution);
        types::assert_prize_plan(&prize_plan);
        types::assert_draw_algo(draw_algo);
    }

    public fun get_lottery(id: u64): lottery_registry::Config {
        lottery_registry::config_view(id)
    }

    public fun list_active(from: u64, limit: u64): vector<u64> {
        list_by_status(types::status_active(), from, limit)
    }

    public fun get_lottery_badges(id: u64): (u8, u64) {
        (lottery_registry::primary_type(id), lottery_registry::tags_mask(id))
    }

    public fun get_badge_metadata(primary_type: u8, tags_mask: u64): BadgeMetadata {
        let label = type_label(primary_type);
        let experimental = (tags_mask & tags::tag_experimental()) != 0;
        BadgeMetadata {
            primary_label: label,
            is_experimental: experimental,
            tags_mask,
        }
    }

    public fun get_lottery_status(id: u64): LotteryStatusView {
        let status = lottery_registry::get_status(id);
        let snapshot_frozen = lottery_registry::is_snapshot_frozen(id);
        let (primary_type, tags_mask) = get_lottery_badges(id);
        LotteryStatusView {
            status,
            snapshot_frozen,
            primary_type,
            tags_mask,
        }
    }

    public fun accounting_snapshot(id: u64): economics::Accounting {
        sales::accounting_snapshot(id)
    }

    public fun get_vrf_deposit_status(): VrfDepositStatusView {
        let status = vrf_deposit::get_status();
        VrfDepositStatusView {
            total_balance: vrf_deposit::status_total_balance(&status),
            minimum_balance: vrf_deposit::status_minimum_balance(&status),
            effective_balance: vrf_deposit::status_effective_balance(&status),
            required_minimum: vrf_deposit::status_required_minimum(&status),
            last_update_ts: vrf_deposit::status_last_update_ts(&status),
            requests_paused: vrf_deposit::status_requests_paused(&status),
            paused_since_ts: vrf_deposit::status_paused_since_ts(&status),
        }
    }

    public fun get_lottery_summary(id: u64): history::LotterySummary {
        history::get_summary(id)
    }

    public fun list_finalized_ids(from: u64, limit: u64): vector<u64> {
        history::list_finalized(from, limit)
    }

    public fun get_cancellation(
        id: u64,
    ): option::Option<lottery_registry::CancellationRecord> {
        lottery_registry::get_cancellation_record(id)
    }

    public fun get_refund_progress(id: u64): sales::RefundProgressView {
        sales::refund_progress(id)
    }

    public fun list_automation_bots(): vector<AutomationBotView> {
        let operators = automation::automation_operators();
        let len = vector::length(&operators);
        let idx = 0u64;
        let out = vector::empty<AutomationBotView>();
        while (idx < len) {
            let operator = *vector::borrow(&operators, idx);
            let status = automation::automation_status(operator);
            let view = automation_status_to_view(status);
            vector::push_back(&mut out, view);
            idx = idx + 1;
        };
        out
    }

    public fun get_automation_bot(
        operator: address,
    ): option::Option<AutomationBotView> {
        let status_opt = automation::automation_status_option(operator);
        if (option::is_none(&status_opt)) {
            return option::none<AutomationBotView>()
        };
        let status = option::extract(&mut status_opt);
        option::some(automation_status_to_view(status))
    }

    public fun status_overview(now_ts: u64): StatusOverview {
        let ids = lottery_registry::ordered_ids_snapshot();
        let total = 0u64;
        let draft = 0u64;
        let active = 0u64;
        let closing = 0u64;
        let draw_requested = 0u64;
        let drawn = 0u64;
        let payout = 0u64;
        let finalized = 0u64;
        let canceled = 0u64;
        let vrf_requested = 0u64;
        let vrf_fulfilled_pending = 0u64;
        let vrf_retry_blocked = 0u64;
        let winners_pending = 0u64;
        let payout_backlog = 0u64;
        let refund_active = 0u64;
        let refund_batch_pending = 0u64;
        let refund_sla_breach = false;

        let len = vector::length(&ids);
        let idx = 0u64;
        while (idx < len) {
            let lottery_id = *vector::borrow(&ids, idx);
            let status = lottery_registry::get_status(lottery_id);
            total = total + 1;
            if (status == types::status_draft()) {
                draft = draft + 1;
            } else if (status == types::status_active()) {
                active = active + 1;
            } else if (status == types::status_closing()) {
                closing = closing + 1;
            } else if (status == types::status_draw_requested()) {
                draw_requested = draw_requested + 1;
            } else if (status == types::status_drawn()) {
                drawn = drawn + 1;
            } else if (status == types::status_payout()) {
                payout = payout + 1;
            } else if (status == types::status_finalized()) {
                finalized = finalized + 1;
            } else if (status == types::status_canceled()) {
                canceled = canceled + 1;
            };

        let vrf_view = draw::vrf_state_view(lottery_id);
        if (draw::vrf_view_status(&vrf_view) == types::vrf_status_requested()) {
            vrf_requested = vrf_requested + 1;
            if (!draw::vrf_view_consumed(&vrf_view)) {
                let retry_after = draw::vrf_view_retry_after_ts(&vrf_view);
                if (retry_after > 0 && retry_after > now_ts) {
                    vrf_retry_blocked = vrf_retry_blocked + 1;
                };
            };
        } else if (
            draw::vrf_view_status(&vrf_view) == types::vrf_status_fulfilled()
                && !draw::vrf_view_consumed(&vrf_view)
        ) {
            vrf_fulfilled_pending = vrf_fulfilled_pending + 1;
        };

        let progress = payouts::winner_progress(lottery_id);
        if (
            payouts::winner_progress_initialized(&progress)
                && payouts::winner_progress_total_required(&progress)
                    > payouts::winner_progress_total_assigned(&progress)
        ) {
            winners_pending = winners_pending + 1;
        };
        if (
            payouts::winner_progress_initialized(&progress)
                && payouts::winner_progress_next_batch(&progress)
                    > payouts::winner_progress_payout_round(&progress)
        ) {
            payout_backlog = payout_backlog + 1;
        };

        let refund_progress = sales::refund_progress(lottery_id);
        if (sales::refund_view_active(&refund_progress)) {
            refund_active = refund_active + 1;
            let tickets_refunded = sales::refund_view_tickets_refunded(&refund_progress);
            let tickets_sold = sales::refund_view_tickets_sold(&refund_progress);
            if (tickets_refunded < tickets_sold) {
                let remaining = tickets_sold - tickets_refunded;
                refund_batch_pending = refund_batch_pending + remaining;
            };

            if (!refund_sla_breach) {
                let cancel_opt = lottery_registry::get_cancellation_record(lottery_id);
                if (option::is_some(&cancel_opt)) {
                    let cancel_ref = option::borrow(&cancel_opt);
                    let canceled_ts = lottery_registry::cancellation_record_canceled_ts(cancel_ref);
                    let refund_round = sales::refund_view_refund_round(&refund_progress);
                    if (refund_round == 0) {
                        if (now_ts > canceled_ts + REFUND_FIRST_BATCH_SLA_SECS) {
                            refund_sla_breach = true;
                        };
                    } else if (tickets_refunded < tickets_sold) {
                        if (now_ts > canceled_ts + REFUND_FULL_SLA_SECS) {
                            refund_sla_breach = true;
                        };
                    };
                };
            };
        };

            idx = idx + 1;
        };

        StatusOverview {
            total,
            draft,
            active,
            closing,
            draw_requested,
            drawn,
            payout,
            finalized,
            canceled,
            vrf_requested,
            vrf_fulfilled_pending,
            vrf_retry_blocked,
            winners_pending,
            payout_backlog,
            refund_active,
            refund_batch_pending,
            refund_sla_breach,
        }
    }

    fun automation_status_to_view(status: automation::AutomationBotStatus): AutomationBotView {
        let status_ref = &status;
        let operator = automation::bot_status_operator(status_ref);
        let allowed_actions = automation::bot_status_allowed_actions(status_ref);
        let timelock_secs = automation::bot_status_timelock_secs(status_ref);
        let max_failures = automation::bot_status_max_failures(status_ref);
        let failure_count = automation::bot_status_failure_count(status_ref);
        let success_streak = automation::bot_status_success_streak(status_ref);
        let reputation_score = automation::bot_status_reputation_score(status_ref);
        let pending_action_hash = automation::bot_status_pending_action_hash(status_ref);
        let pending_execute_after = automation::bot_status_pending_execute_after(status_ref);
        let expires_at = automation::bot_status_expires_at(status_ref);
        let cron_spec = automation::bot_status_cron_spec(status_ref);
        let last_action_ts = automation::bot_status_last_action_ts(status_ref);
        let last_action_hash = automation::bot_status_last_action_hash(status_ref);
        let has_pending = automation::bot_status_has_pending(status_ref);
        let _ = status;
        AutomationBotView {
            operator,
            allowed_actions,
            timelock_secs,
            max_failures,
            failure_count,
            success_streak,
            reputation_score,
            has_pending,
            pending_execute_after,
            pending_action_hash,
            expires_at,
            cron_spec,
            last_action_ts,
            last_action_hash,
        }
    }

    public fun list_by_primary_type(primary_type: u8, from: u64, limit: u64): vector<u64> {
        collect_ids(primary_type, 0, MODE_PRIMARY, from, limit)
    }

    public fun list_by_tag_mask(tag_mask: u64, from: u64, limit: u64): vector<u64> {
        collect_ids(0, tag_mask, MODE_TAG_ANY, from, limit)
    }

    public fun list_by_all_tags(tag_mask: u64, from: u64, limit: u64): vector<u64> {
        collect_ids(0, tag_mask, MODE_TAG_ALL, from, limit)
    }

    const MODE_PRIMARY: u8 = 0;
    const MODE_TAG_ANY: u8 = 1;
    const MODE_TAG_ALL: u8 = 2;
    const MODE_STATUS: u8 = 3;

    fun collect_ids(primary_type: u8, tag_mask: u64, mode: u8, from: u64, limit: u64): vector<u64> {
        assert!(limit <= 1000, errors::err_pagination_limit());
        let ids = lottery_registry::ordered_ids_snapshot();
        let result = vector::empty<u64>();
        let taken = 0u64;
        let skipped = 0u64;
        let len = vector::length(&ids);
        let index = len;
        while (index > 0) {
            index = index - 1;
            let lottery_id = *vector::borrow(&ids, index);
            let current_primary = lottery_registry::primary_type(lottery_id);
            let current_tags = lottery_registry::tags_mask(lottery_id);
            let current_status = lottery_registry::get_status(lottery_id);
            if (!matches(
                current_primary,
                current_tags,
                current_status,
                primary_type,
                tag_mask,
                mode,
            )) {
                continue
            };
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

    fun list_by_status(status: u8, from: u64, limit: u64): vector<u64> {
        collect_ids(status, 0, MODE_STATUS, from, limit)
    }

    fun matches(
        current_primary: u8,
        current_tags: u64,
        current_status: u8,
        expected_primary: u8,
        expected_tags: u64,
        mode: u8,
    ): bool {
        if (mode == MODE_PRIMARY) {
            return current_primary == expected_primary
        };
        if (mode == MODE_TAG_ANY) {
            return (current_tags & expected_tags) != 0
        };
        if (mode == MODE_TAG_ALL) {
            return (current_tags & expected_tags) == expected_tags
        };
        if (mode == MODE_STATUS) {
            return current_status == expected_primary
        };
        false
    }

    fun type_label(primary_type: u8): string::String {
        if (primary_type == tags::type_basic()) {
            return string::utf8(b"basic")
        };
        if (primary_type == tags::type_partner()) {
            return string::utf8(b"partner")
        };
        if (primary_type == tags::type_jackpot()) {
            return string::utf8(b"jackpot")
        };
        if (primary_type == tags::type_vip()) {
            return string::utf8(b"vip")
        };
        string::utf8(b"unknown")
    }

    //
    // View getters (Move v1 compatibility)
    //

    public fun lottery_status_status(view: &LotteryStatusView): u8 {
        view.status
    }

    public fun lottery_status_snapshot_frozen(view: &LotteryStatusView): bool {
        view.snapshot_frozen
    }

    public fun automation_bot_operator(view: &AutomationBotView): address {
        view.operator
    }

    public fun automation_bot_allowed_actions(view: &AutomationBotView): vector<u64> {
        clone_u64_vector(&view.allowed_actions)
    }

    public fun automation_bot_timelock_secs(view: &AutomationBotView): u64 {
        view.timelock_secs
    }

    public fun automation_bot_max_failures(view: &AutomationBotView): u64 {
        view.max_failures
    }

    public fun automation_bot_has_pending(view: &AutomationBotView): bool {
        view.has_pending
    }

    public fun automation_bot_pending_execute_after(view: &AutomationBotView): u64 {
        view.pending_execute_after
    }

    public fun status_overview_total(view: &StatusOverview): u64 {
        view.total
    }

    public fun status_overview_draft(view: &StatusOverview): u64 {
        view.draft
    }

    public fun status_overview_active(view: &StatusOverview): u64 {
        view.active
    }

    public fun status_overview_draw_requested(view: &StatusOverview): u64 {
        view.draw_requested
    }

    public fun status_overview_vrf_requested(view: &StatusOverview): u64 {
        view.vrf_requested
    }

    public fun status_overview_vrf_retry_blocked(view: &StatusOverview): u64 {
        view.vrf_retry_blocked
    }

    public fun status_overview_vrf_fulfilled_pending(view: &StatusOverview): u64 {
        view.vrf_fulfilled_pending
    }

    public fun status_overview_refund_active(view: &StatusOverview): u64 {
        view.refund_active
    }

    public fun status_overview_refund_batch_pending(view: &StatusOverview): u64 {
        view.refund_batch_pending
    }

    public fun status_overview_refund_sla_breach(view: &StatusOverview): bool {
        view.refund_sla_breach
    }

    public fun status_overview_winners_pending(view: &StatusOverview): u64 {
        view.winners_pending
    }

    public fun status_overview_payout_backlog(view: &StatusOverview): u64 {
        view.payout_backlog
    }

    public fun badge_metadata_primary_label(view: &BadgeMetadata): vector<u8> {
        clone_bytes(string::bytes(&view.primary_label))
    }

    public fun badge_metadata_is_experimental(view: &BadgeMetadata): bool {
        view.is_experimental
    }

    public fun badge_metadata_tags_mask(view: &BadgeMetadata): u64 {
        view.tags_mask
    }

    public fun refund_first_batch_sla_secs(): u64 {
        REFUND_FIRST_BATCH_SLA_SECS
    }

    public fun refund_full_sla_secs(): u64 {
        REFUND_FULL_SLA_SECS
    }

    fun clone_u64_vector(source: &vector<u64>): vector<u64> {
        let result = vector::empty<u64>();
        let len = vector::length(source);
        let i = 0u64;
        while (i < len) {
            let value = *vector::borrow(source, i);
            vector::push_back(&mut result, value);
            i = i + 1;
        };
        result
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let result = vector::empty<u8>();
        let len = vector::length(source);
        let i = 0u64;
        while (i < len) {
            let byte = *vector::borrow(source, i);
            vector::push_back(&mut result, byte);
            i = i + 1;
        };
        result
    }
}

