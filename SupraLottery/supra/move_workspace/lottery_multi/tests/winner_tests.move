module lottery_multi::winner_tests {
    use std::bcs;
    use std::hash;
    use std::signer;
    use std::table;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::payouts;
    use lottery_multi::registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";
    const MAX_REHASH_ATTEMPTS: u8 = 16;

    #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2, buyer3 = @0x3)]
    fun winners_without_replacement(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        buyer3: &signer,
    ) {
        setup_modules(account);
        let mut config = new_config(true);
        registry::create_draft_admin(account, 1, copy config);
        registry::advance_status(account, 1, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, 1, 1, 20, 1);
        sales::purchase_tickets_public(buyer2, 1, 1, 22, 2);
        sales::purchase_tickets_public(buyer3, 1, 1, 24, 3);
        registry::advance_status(account, 1, registry::STATUS_CLOSING);
        registry::mark_draw_requested(1);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(1);
        let mut numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x0102030405060708u256);
        vector::push_back(&mut numbers, 0x0f0e0d0c0b0a0908u256);
        let payload_hash = hash::sha3_256(b"payload-v1");
        draw::test_seed_vrf_state(
            1,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            123,
            1,
        );
        registry::mark_drawn(1);

        payouts::compute_winners_admin(account, 1, 10);
        let actual = payouts::test_read_winner_indices(1);
        let cfg = registry::borrow_config(1);
        let expected = expected_winners(
            &numbers,
            cfg,
            &snapshot_hash,
            &payload_hash,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            tickets_sold,
            true,
            1,
        );
        assert!(vector::length(&actual) == vector::length(&expected), 0);
        compare_vectors(&actual, &expected);
        assert_no_duplicates(&actual);
    }

    #[test(account = @lottery_multi, buyer1 = @0x1)]
    fun winners_allow_duplicates_when_disabled(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let mut config = new_config(false);
        config.prize_plan = single_slot_two_winners();
        registry::create_draft_admin(account, 7, copy config);
        registry::advance_status(account, 7, registry::STATUS_ACTIVE);
        sales::purchase_tickets_public(buyer1, 7, 1, 20, 1);
        registry::advance_status(account, 7, registry::STATUS_CLOSING);
        registry::mark_draw_requested(7);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(7);
        let mut numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0u256);
        let payload_hash = hash::sha3_256(b"payload-single");
        draw::test_seed_vrf_state(
            7,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            77,
            1,
        );
        registry::mark_drawn(7);

        payouts::compute_winners_admin(account, 7, 10);
        let actual = payouts::test_read_winner_indices(7);
        let cfg = registry::borrow_config(7);
        let expected = expected_winners(
            &numbers,
            cfg,
            &snapshot_hash,
            &payload_hash,
            types::DEFAULT_SCHEMA_VERSION,
            1,
            tickets_sold,
            false,
            7,
        );
        compare_vectors(&actual, &expected);
        assert!(vector::length(&actual) == 2, 0);
        let first = *vector::borrow(&actual, 0);
        let second = *vector::borrow(&actual, 1);
        assert!(first == second, 0);
    }

    fun setup_modules(account: &signer) {
        registry::init_registry(account);
        sales::init_sales(account);
        draw::init_draw(account);
        payouts::init_payouts(account);
    }

    fun new_config(winners_dedup: bool): registry::Config {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(0, 1, types::REWARD_FROM_SALES, b""),
        );
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(1, 1, types::REWARD_FROM_SALES, b""),
        );
        registry::Config {
            event_slug: copy EVENT_BYTES,
            series_code: copy SERIES_BYTES,
            run_id: 0,
            config_version: 1,
            primary_type: tags::TYPE_BASIC,
            tags_mask: 0,
            sales_window: types::new_sales_window(10, 100),
            ticket_price: 100,
            ticket_limits: types::new_ticket_limits(100, 10),
            sales_distribution: economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            winners_dedup,
            draw_algo: types::DRAW_ALGO_WITHOUT_REPLACEMENT,
            auto_close_policy: types::new_auto_close_policy(true, 60),
            reward_backend: types::new_reward_backend(types::BACKEND_NATIVE, b""),
        }
    }

    fun single_slot_two_winners(): vector<types::PrizeSlot> {
        let mut prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(5, 2, types::REWARD_FROM_SALES, b""),
        );
        prize_plan
    }

    fun compare_vectors(actual: &vector<u64>, expected: &vector<u64>) {
        let len = vector::length(actual);
        let mut idx = 0;
        while (idx < len) {
            let a = *vector::borrow(actual, idx);
            let e = *vector::borrow(expected, idx);
            assert!(a == e, 0);
            idx = idx + 1;
        };
    }

    fun assert_no_duplicates(values: &vector<u64>) {
        let mut seen = table::new<u64, bool>();
        let len = vector::length(values);
        let mut idx = 0;
        while (idx < len) {
            let value = *vector::borrow(values, idx);
            assert!(!table::contains(&seen, value), 0);
            table::add(&mut seen, value, true);
            idx = idx + 1;
        };
    }

    fun expected_winners(
        numbers: &vector<u256>,
        config: &registry::Config,
        snapshot_hash: &vector<u8>,
        payload_hash: &vector<u8>,
        schema_version: u16,
        attempt: u8,
        total_tickets: u64,
        dedup: bool,
        lottery_id: u64,
    ): vector<u64> {
        let total = total_winners_local(&config.prize_plan);
        let mut winners = vector::empty<u64>();
        let mut assigned = table::new<u64, bool>();
        let mut ordinal = 0u64;
        while (ordinal < total) {
            let ctx = slot_context_local(&config.prize_plan, ordinal);
            let base = *vector::borrow(numbers, ctx.slot_position);
            let base_bytes = bcs::to_bytes(&base);
            let mut digest = derive_seed_local(
                &base_bytes,
                snapshot_hash,
                payload_hash,
                lottery_id,
                ordinal,
                ctx.local_index,
                schema_version,
                attempt,
            );
            let mut tries = 0u8;
            let ticket = loop {
                let candidate = reduce_digest_local(&digest, total_tickets);
                if (!dedup || !table::contains(&assigned, candidate)) {
                    break candidate;
                };
                tries = tries + 1;
                assert!(tries < MAX_REHASH_ATTEMPTS, 0);
                digest = hash::sha3_256(copy digest);
            };
            if (dedup) {
                table::add(&mut assigned, ticket, true);
            };
            vector::push_back(&mut winners, ticket);
            ordinal = ordinal + 1;
        };
        winners
    }

    struct SlotContextLocal has copy, drop, store {
        slot_id: u64,
        slot_position: u64,
        local_index: u64,
    }

    fun slot_context_local(prize_plan: &vector<types::PrizeSlot>, ordinal: u64): SlotContextLocal {
        let mut accumulated = 0u64;
        let len = vector::length(prize_plan);
        let mut idx = 0u64;
        while (idx < (len as u64)) {
            let slot = vector::borrow(prize_plan, idx);
            let winners_per_slot = slot.winners_per_slot as u64;
            if (ordinal < accumulated + winners_per_slot) {
                return SlotContextLocal {
                    slot_id: slot.slot_id,
                    slot_position: idx,
                    local_index: ordinal - accumulated,
                };
            };
            accumulated = accumulated + winners_per_slot;
            idx = idx + 1;
        };
        abort 0;
    }

    fun total_winners_local(prize_plan: &vector<types::PrizeSlot>): u64 {
        let len = vector::length(prize_plan);
        let mut idx = 0;
        let mut total = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            total = total + (slot.winners_per_slot as u64);
            idx = idx + 1;
        };
        total
    }

    fun derive_seed_local(
        base_seed: &vector<u8>,
        snapshot_hash: &vector<u8>,
        payload_hash: &vector<u8>,
        lottery_id: u64,
        ordinal: u64,
        local_index: u64,
        schema_version: u16,
        attempt: u8,
    ): vector<u8> {
        let mut data = copy *base_seed;
        vector::append(&mut data, copy *snapshot_hash);
        vector::append(&mut data, copy *payload_hash);
        vector::append(&mut data, bcs::to_bytes(&lottery_id));
        vector::append(&mut data, bcs::to_bytes(&ordinal));
        vector::append(&mut data, bcs::to_bytes(&local_index));
        vector::append(&mut data, bcs::to_bytes(&(schema_version as u64)));
        vector::append(&mut data, bcs::to_bytes(&(attempt as u64)));
        hash::sha3_256(data)
    }

    fun reduce_digest_local(digest: &vector<u8>, total_tickets: u64): u64 {
        let mut value = 0u64;
        let mut i = 0u64;
        while (i < 8) {
            let byte = *vector::borrow(digest, i);
            value = value | ((byte as u64) << (i * 8));
            i = i + 1;
        };
        if (total_tickets == 0) {
            0
        } else {
            value % total_tickets
        }
    }
}
