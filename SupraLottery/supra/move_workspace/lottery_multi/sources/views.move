// sources/views.move
module lottery_multi::views {
    use std::string;
    use std::vector;

    use lottery_multi::economics;
    use lottery_multi::sales;
    use lottery_multi::registry;
    use lottery_multi::errors;
    use lottery_multi::tags;
    use lottery_multi::types;

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
            if (!matches(config_ref.primary_type, config_ref.tags_mask, primary_type, tag_mask, mode)) {
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

    fun matches(
        current_primary: u8,
        current_tags: u64,
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

