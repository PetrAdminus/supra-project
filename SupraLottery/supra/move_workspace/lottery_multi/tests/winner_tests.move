module lottery_multi::winner_tests {
    use std::bcs;
    use std::hash;
    use std::vector;

    use lottery_multi::draw;
    use lottery_multi::economics;
    use lottery_multi::errors;
    use lottery_multi::math;
    use lottery_multi::payouts;
    use lottery_multi::lottery_registry as registry;
    use lottery_multi::sales;
    use lottery_multi::tags;
    use lottery_multi::types;

    const EVENT_BYTES: vector<u8> = b"lottery";
    const SERIES_BYTES: vector<u8> = b"daily";
    const MAX_REHASH_ATTEMPTS: u8 = 16;

    // #[test(account = @lottery_multi, buyer1 = @0x1, buyer2 = @0x2, buyer3 = @0x3)]
    fun winners_without_replacement(
        account: &signer,
        buyer1: &signer,
        buyer2: &signer,
        buyer3: &signer,
    ) {
        setup_modules(account);
        let config = new_config(true);
        let config_for_setup = registry::clone_config(&config);
        registry::create_draft_admin_with_config(account, 1, config_for_setup);
        registry::advance_status(account, 1, types::status_active());
        sales::purchase_tickets_public(buyer1, 1, 1, 20, 1);
        sales::purchase_tickets_public(buyer2, 1, 1, 22, 2);
        sales::purchase_tickets_public(buyer3, 1, 1, 24, 3);
        registry::advance_status(account, 1, types::status_closing());
        registry::mark_draw_requested(1);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(1);
        let numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0x0102030405060708u256);
        vector::push_back(&mut numbers, 0x0f0e0d0c0b0a0908u256);
        let payload_hash = hash::sha3_256(b"payload-v1");
        draw::test_seed_vrf_state(
            1,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::vrf_default_schema_version(),
            1,
            123,
            1,
        );
        registry::mark_drawn(1);

        payouts::compute_winners_admin(account, 1, 10);
        let actual = payouts::test_read_winner_indices(1);
        let expected = expected_winners(
            &numbers,
            &config,
            &snapshot_hash,
            &payload_hash,
            types::vrf_default_schema_version(),
            1,
            tickets_sold,
            true,
            1,
        );
        assert!(vector::length(&actual) == vector::length(&expected), 0);
        compare_vectors(&actual, &expected);
        assert_no_duplicates(&actual);
    }

    // #[test(account = @lottery_multi, buyer1 = @0x1)]
    fun winners_allow_duplicates_when_disabled(account: &signer, buyer1: &signer) {
        setup_modules(account);
        let config_base = new_config(false);
        let config_with_plan =
            registry::config_with_prize_plan(&config_base, single_slot_two_winners());
        let config_for_setup = registry::clone_config(&config_with_plan);
        registry::create_draft_admin_with_config(account, 7, config_for_setup);
        registry::advance_status(account, 7, types::status_active());
        sales::purchase_tickets_public(buyer1, 7, 1, 20, 1);
        registry::advance_status(account, 7, types::status_closing());
        registry::mark_draw_requested(7);

        let (snapshot_hash, tickets_sold, _) = sales::snapshot_for_draw(7);
        let numbers = vector::empty<u256>();
        vector::push_back(&mut numbers, 0u256);
        let payload_hash = hash::sha3_256(b"payload-single");
        draw::test_seed_vrf_state(
            7,
            copy numbers,
            copy snapshot_hash,
            copy payload_hash,
            tickets_sold,
            types::vrf_default_schema_version(),
            1,
            77,
            1,
        );
        registry::mark_drawn(7);

        payouts::compute_winners_admin(account, 7, 10);
        let actual = payouts::test_read_winner_indices(7);
        let expected = expected_winners(
            &numbers,
            &config_with_plan,
            &snapshot_hash,
            &payload_hash,
            types::vrf_default_schema_version(),
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
        let prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(
                0,
                1,
                types::reward_from_sales_value(),
                b"",
            ),
        );
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(
                1,
                1,
                types::reward_from_sales_value(),
                b"",
            ),
        );
        registry::new_config_for_tests(
            EVENT_BYTES,
            SERIES_BYTES,
            0,
            1,
            tags::type_basic(),
            0,
            types::new_sales_window(10, 100),
            100,
            types::new_ticket_limits(100, 10),
            economics::new_sales_distribution(7000, 1500, 1000, 500),
            prize_plan,
            winners_dedup,
            types::draw_algo_without_replacement_value(),
            types::new_auto_close_policy(true, 60),
            types::new_reward_backend(types::backend_native_value(), b""),
            types::default_retry_policy(),
        )
    }

    fun single_slot_two_winners(): vector<types::PrizeSlot> {
        let prize_plan = vector::empty<types::PrizeSlot>();
        vector::push_back(
            &mut prize_plan,
            types::new_prize_slot(
                5,
                2,
                types::reward_from_sales_value(),
                b"",
            ),
        );
        prize_plan
    }

    fun compare_vectors(actual: &vector<u64>, expected: &vector<u64>) {
        let len = vector::length(actual);
        let idx = 0;
        while (idx < len) {
            let a = *vector::borrow(actual, idx);
            let e = *vector::borrow(expected, idx);
            assert!(a == e, 0);
            idx = idx + 1;
        };
    }

    fun assert_no_duplicates(values: &vector<u64>) {
        let seen = vector::empty<u64>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            let value = *vector::borrow(values, idx);
            assert!(!vector_contains(&seen, value), 0);
            vector::push_back(&mut seen, value);
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
        let prize_plan = registry::config_prize_plan(config);
        let total = total_winners_local(&prize_plan);
        let winners = vector::empty<u64>();
        let assigned = vector::empty<u64>();
        let ordinal = 0u64;
        while (ordinal < total) {
            let ctx = slot_context_local(&prize_plan, ordinal);
            let base = *vector::borrow(numbers, ctx.slot_position);
            let base_bytes = bcs::to_bytes(&base);
            let digest = derive_seed_local(
                &base_bytes,
                snapshot_hash,
                payload_hash,
                lottery_id,
                ordinal,
                ctx.local_index,
                schema_version,
                attempt,
            );
            let ticket = pick_ticket(&assigned, dedup, total_tickets, digest);
            if (dedup) {
                vector::push_back(&mut assigned, ticket);
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
        let accumulated = 0u64;
        let len = vector::length(prize_plan);
        let idx = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            let winners_per_slot = math::widen_u64_from_u16(types::prize_slot_winners(slot));
            if (ordinal < accumulated + winners_per_slot) {
                return SlotContextLocal {
                    slot_id: types::prize_slot_slot_id(slot),
                    slot_position: idx,
                    local_index: ordinal - accumulated,
                }
            };
            accumulated = accumulated + winners_per_slot;
            idx = idx + 1;
        };
        abort 0
    }

    fun total_winners_local(prize_plan: &vector<types::PrizeSlot>): u64 {
        let len = vector::length(prize_plan);
        let idx = 0u64;
        let total = 0u64;
        while (idx < len) {
            let slot = vector::borrow(prize_plan, idx);
            total = total + math::widen_u64_from_u16(types::prize_slot_winners(slot));
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
        let data = clone_bytes(base_seed);
        vector::append(&mut data, clone_bytes(snapshot_hash));
        vector::append(&mut data, clone_bytes(payload_hash));
        vector::append(&mut data, bcs::to_bytes(&lottery_id));
        vector::append(&mut data, bcs::to_bytes(&ordinal));
        vector::append(&mut data, bcs::to_bytes(&local_index));
        let schema_version_u64 = math::widen_u64_from_u16(schema_version);
        vector::append(&mut data, bcs::to_bytes(&schema_version_u64));
        let attempt_u64 = math::widen_u64_from_u8(attempt);
        vector::append(&mut data, bcs::to_bytes(&attempt_u64));
        hash::sha3_256(data)
    }

    fun reduce_digest_local(digest: &vector<u8>, total_tickets: u64): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            let byte = *vector::borrow(digest, i);
            let shift =
                math::narrow_u8_from_u64(i * 8u64, errors::err_winner_index_out_of_range());
            value = value | (math::widen_u64_from_u8(byte) << shift);
            i = i + 1;
        };
        if (total_tickets == 0) {
            0
        } else {
            value % total_tickets
        }
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let out = vector::empty<u8>();
        let idx = 0;
        let len = vector::length(source);
        while (idx < len) {
            let byte = *vector::borrow(source, idx);
            vector::push_back(&mut out, byte);
            idx = idx + 1;
        };
        out
    }

    fun pick_ticket(
        assigned: &vector<u64>,
        dedup: bool,
        total_tickets: u64,
        digest: vector<u8>,
    ): u64 {
        let tries = 0u8;
        let current = digest;
        while (tries < MAX_REHASH_ATTEMPTS) {
            let candidate = reduce_digest_local(&current, total_tickets);
            if (!dedup || !vector_contains(assigned, candidate)) {
                return candidate
            };
            tries = tries + 1;
            current = hash::sha3_256(copy current);
        };
        abort errors::err_winner_index_out_of_range()
    }

    fun vector_contains(values: &vector<u64>, target: u64): bool {
        let len = vector::length(values);
        let i = 0u64;
        while (i < len) {
            if (*vector::borrow(values, i) == target) {
                return true
            };
            i = i + 1;
        };
        false
    }
}








