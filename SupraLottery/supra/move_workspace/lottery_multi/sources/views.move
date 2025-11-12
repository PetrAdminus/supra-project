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
    use lottery_multi::registry;
    use lottery_multi::errors;
    use lottery_multi::tags;
    use lottery_multi::types;
    use lottery_multi::vrf_deposit;

    pub struct BadgeMetadata has drop, store {
        pub primary_label: string::String,
        pub is_experimental: bool,
        pub tags_mask: u64,
    }

    pub struct LotteryStatusView has drop, store {
        pub status: u8,
        pub snapshot_frozen: bool,
        pub primary_type: u8,
        pub tags_mask: u64,
    }

    pub struct VrfDepositStatusView has drop, store {
        pub total_balance: u64,
        pub minimum_balance: u64,
        pub effective_balance: u64,
        pub required_minimum: u64,
        pub last_update_ts: u64,
        pub requests_paused: bool,
        pub paused_since_ts: u64,
    }

    pub struct StatusOverview has drop, store {
        pub total: u64,
        pub draft: u64,
        pub active: u64,
        pub closing: u64,
        pub draw_requested: u64,
        pub drawn: u64,
        pub payout: u64,
        pub finalized: u64,
        pub canceled: u64,
        pub vrf_requested: u64,
        pub vrf_fulfilled_pending: u64,
        pub vrf_retry_blocked: u64,
        pub winners_pending: u64,
        pub payout_backlog: u64,
    }

    pub struct AutomationBotView has drop, store {
        pub operator: address,
        pub allowed_actions: vector<u64>,
        pub timelock_secs: u64,
        pub max_failures: u64,
        pub failure_count: u64,
        pub success_streak: u64,
        pub reputation_score: u64,
        pub has_pending: bool,
        pub pending_execute_after: u64,
        pub pending_action_hash: vector<u8>,
        pub expires_at: u64,
        pub cron_spec: vector<u8>,
        pub last_action_ts: u64,
        pub last_action_hash: vector<u8>,
    }

    public fun validate_config(config: &registry::Config) {
        tags::validate(config.primary_type, config.tags_mask);
        tags::assert_tag_budget(config.tags_mask);
        types::assert_sales_window(&config.sales_window);
        types::assert_ticket_price(config.ticket_price);
        types::assert_ticket_limits(&config.ticket_limits);
        economics::assert_distribution(&config.sales_distribution);
        types::assert_prize_plan(&config.prize_plan);
        types::assert_draw_algo(config.draw_algo);
    }

    public fun get_lottery(id: u64): registry::Config acquires registry::Registry {
        *registry::borrow_config(id)
    }

    public fun list_active(from: u64, limit: u64): vector<u64> acquires registry::Registry {
        list_by_status(registry::STATUS_ACTIVE, from, limit)
    }

    public fun get_lottery_badges(id: u64): (u8, u64) acquires registry::Registry {
        let config = registry::borrow_config(id);
        (config.primary_type, config.tags_mask)
    }

    public fun get_badge_metadata(primary_type: u8, tags_mask: u64): BadgeMetadata {
        let label = type_label(primary_type);
        let experimental = (tags_mask & tags::TAG_EXPERIMENTAL) != 0;
        BadgeMetadata {
            primary_label: label,
            is_experimental: experimental,
            tags_mask,
        }
    }

    public fun get_lottery_status(id: u64): LotteryStatusView acquires registry::Registry {
        let status = registry::get_status(id);
        let snapshot_frozen = registry::is_snapshot_frozen(id);
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
            total_balance: status.total_balance,
            minimum_balance: status.minimum_balance,
            effective_balance: status.effective_balance,
            required_minimum: status.required_minimum,
            last_update_ts: status.last_update_ts,
            requests_paused: status.requests_paused,
            paused_since_ts: status.paused_since_ts,
        }
    }

    public fun get_lottery_summary(id: u64): history::LotterySummary acquires history::ArchiveLedger {
        history::get_summary(id)
    }

    public fun list_finalized_ids(from: u64, limit: u64): vector<u64> acquires history::ArchiveLedger {
        history::list_finalized(from, limit)
    }

    public fun get_cancellation(
        id: u64,
    ): option::Option<registry::CancellationRecord> acquires registry::Registry {
        registry::get_cancellation_record(id)
    }

    public fun get_refund_progress(id: u64): sales::RefundProgressView {
        sales::refund_progress(id)
    }

    public fun list_automation_bots(): vector<AutomationBotView> acquires automation::AutomationRegistry {
        let operators = automation::automation_operators();
        let len = vector::length(&operators);
        let mut idx = 0u64;
        let mut out = vector::empty<AutomationBotView>();
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
    ): option::Option<AutomationBotView> acquires automation::AutomationRegistry {
        let mut status_opt = automation::automation_status_option(operator);
        if (option::is_none(&status_opt)) {
            return option::none<AutomationBotView>();
        };
        let status = option::extract(&mut status_opt);
        option::some(automation_status_to_view(status))
    }

    public fun status_overview(now_ts: u64): StatusOverview acquires registry::Registry, draw::DrawLedger, payouts::PayoutLedger {
        let registry_ref = registry::borrow_registry_for_view();
        let ids = registry::ordered_ids_view(registry_ref);
        let mut total = 0u64;
        let mut draft = 0u64;
        let mut active = 0u64;
        let mut closing = 0u64;
        let mut draw_requested = 0u64;
        let mut drawn = 0u64;
        let mut payout = 0u64;
        let mut finalized = 0u64;
        let mut canceled = 0u64;
        let mut vrf_requested = 0u64;
        let mut vrf_fulfilled_pending = 0u64;
        let mut vrf_retry_blocked = 0u64;
        let mut winners_pending = 0u64;
        let mut payout_backlog = 0u64;

        let len = vector::length(ids);
        let mut idx = 0u64;
        while (idx < len) {
            let lottery_id = *vector::borrow(ids, idx);
            let status = registry::get_status_from_registry(registry_ref, lottery_id);
            total = total + 1;
            if (status == registry::STATUS_DRAFT) {
                draft = draft + 1;
            } else if (status == registry::STATUS_ACTIVE) {
                active = active + 1;
            } else if (status == registry::STATUS_CLOSING) {
                closing = closing + 1;
            } else if (status == registry::STATUS_DRAW_REQUESTED) {
                draw_requested = draw_requested + 1;
            } else if (status == registry::STATUS_DRAWN) {
                drawn = drawn + 1;
            } else if (status == registry::STATUS_PAYOUT) {
                payout = payout + 1;
            } else if (status == registry::STATUS_FINALIZED) {
                finalized = finalized + 1;
            } else if (status == registry::STATUS_CANCELED) {
                canceled = canceled + 1;
            };

            let vrf_view = draw::vrf_state_view(lottery_id);
            if (vrf_view.status == types::VRF_STATUS_REQUESTED) {
                vrf_requested = vrf_requested + 1;
                if (!vrf_view.consumed) {
                    if (vrf_view.retry_after_ts > 0 && vrf_view.retry_after_ts > now_ts) {
                        vrf_retry_blocked = vrf_retry_blocked + 1;
                    };
                };
            } else if (vrf_view.status == types::VRF_STATUS_FULFILLED && !vrf_view.consumed) {
                vrf_fulfilled_pending = vrf_fulfilled_pending + 1;
            };

            let progress = payouts::winner_progress(lottery_id);
            if (progress.initialized && progress.total_required > progress.total_assigned) {
                winners_pending = winners_pending + 1;
            };
            if (progress.initialized && progress.next_winner_batch_no > progress.payout_round) {
                payout_backlog = payout_backlog + 1;
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
        }
    }

    fun automation_status_to_view(status: automation::AutomationBotStatus): AutomationBotView {
        let automation::AutomationBotStatus {
            operator,
            allowed_actions,
            timelock_secs,
            max_failures,
            failure_count,
            success_streak,
            reputation_score,
            pending_action_hash,
            pending_execute_after,
            expires_at,
            cron_spec,
            last_action_ts,
            last_action_hash,
        } = status;
        let has_pending = vector::length(&pending_action_hash) > 0;
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

    public fun list_by_primary_type(primary_type: u8, from: u64, limit: u64): vector<u64> acquires registry::Registry {
        collect_ids(primary_type, 0, MODE_PRIMARY, from, limit)
    }

    public fun list_by_tag_mask(tag_mask: u64, from: u64, limit: u64): vector<u64> acquires registry::Registry {
        collect_ids(0, tag_mask, MODE_TAG_ANY, from, limit)
    }

    public fun list_by_all_tags(tag_mask: u64, from: u64, limit: u64): vector<u64> acquires registry::Registry {
        collect_ids(0, tag_mask, MODE_TAG_ALL, from, limit)
    }

    const MODE_PRIMARY: u8 = 0;
    const MODE_TAG_ANY: u8 = 1;
    const MODE_TAG_ALL: u8 = 2;
    const MODE_STATUS: u8 = 3;

    fun collect_ids(primary_type: u8, tag_mask: u64, mode: u8, from: u64, limit: u64): vector<u64> acquires registry::Registry {
        assert!(limit <= 1000, errors::E_PAGINATION_LIMIT);
        let registry_ref = registry::borrow_registry_for_view();
        let ids = registry::ordered_ids_view(registry_ref);
        let mut result = vector::empty<u64>();
        let mut taken = 0u64;
        let mut skipped = 0u64;
        let len = vector::length(ids);
        let mut index = len;
        while (index > 0) {
            index = index - 1;
            let lottery_id = *vector::borrow(ids, index);
            let config_ref = registry::borrow_config_from_registry(registry_ref, lottery_id);
            if (!matches(
                config_ref.primary_type,
                config_ref.tags_mask,
                registry::get_status(lottery_id),
                primary_type,
                tag_mask,
                mode,
            )) {
                continue;
            };
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

    fun list_by_status(status: u8, from: u64, limit: u64): vector<u64> acquires registry::Registry {
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
            return current_primary == expected_primary;
        };
        if (mode == MODE_TAG_ANY) {
            return (current_tags & expected_tags) != 0;
        };
        if (mode == MODE_TAG_ALL) {
            return (current_tags & expected_tags) == expected_tags;
        };
        if (mode == MODE_STATUS) {
            return current_status == expected_primary;
        };
        false
    }

    fun type_label(primary_type: u8): string::String {
        if (primary_type == tags::TYPE_BASIC) {
            return string::utf8(b"basic");
        };
        if (primary_type == tags::TYPE_PARTNER) {
            return string::utf8(b"partner");
        };
        if (primary_type == tags::TYPE_JACKPOT) {
            return string::utf8(b"jackpot");
        };
        if (primary_type == tags::TYPE_VIP) {
            return string::utf8(b"vip");
        };
        string::utf8(b"unknown")
    }
}

