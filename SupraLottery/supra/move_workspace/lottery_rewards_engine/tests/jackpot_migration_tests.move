#[test_only]
module lottery_rewards_engine::jackpot_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::jackpot as jackpot_data;
    use lottery_rewards_engine::jackpot;

    #[test(lottery_admin = @lottery)]
    fun import_existing_jackpots_restore_runtime(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 701, @0xAA01);
        register_lottery(lottery_admin, 808, @0xBB02);

        let mut payloads = vector::empty<jackpot::LegacyJackpotRuntime>();
        vector::push_back(
            &mut payloads,
            jackpot::LegacyJackpotRuntime {
                lottery_id: 701,
                tickets: addresses3(@0xCAFE, @0xDEAD, @0x0C0A),
                draw_scheduled: true,
                pending_request_id: option::some(88),
                pending_payload: option::some(b"abc"),
            },
        );
        vector::push_back(
            &mut payloads,
            jackpot::LegacyJackpotRuntime {
                lottery_id: 808,
                tickets: addresses1(@0xFEED),
                draw_scheduled: false,
                pending_request_id: option::none<u64>(),
                pending_payload: option::none<vector<u8>>(),
            },
        );

        jackpot::import_existing_jackpots(lottery_admin, payloads);

        let first_runtime = jackpot::runtime_view(701);
        assert!(option::is_some(&first_runtime), 0);
        let runtime = option::destroy_some(first_runtime);
        assert!(runtime.lottery_id == 701, 1);
        assert!(runtime.draw_scheduled, 2);
        assert!(vector::length(&runtime.tickets) == 3, 3);
        assert!(*vector::borrow(&runtime.tickets, 0) == @0xCAFE, 4);
        assert!(*vector::borrow(&runtime.tickets, 2) == @0x0C0A, 5);
        assert!(option::is_some(&runtime.pending_request_id), 6);
        assert!(*option::borrow(&runtime.pending_request_id) == 88, 7);
        assert!(option::is_some(&runtime.pending_payload), 8);
        let payload = option::borrow(&runtime.pending_payload);
        assert!(vector::length(payload) == 3, 9);
        assert!(*vector::borrow(payload, 0) == 0x61, 10);

        let second_runtime = jackpot::runtime_view(808);
        assert!(option::is_some(&second_runtime), 11);
        let runtime_two = option::destroy_some(second_runtime);
        assert!(vector::length(&runtime_two.tickets) == 1, 12);
        assert!(*vector::borrow(&runtime_two.tickets, 0) == @0xFEED, 13);
        assert!(!runtime_two.draw_scheduled, 14);
        assert!(option::is_none(&runtime_two.pending_request_id), 15);
        assert!(option::is_none(&runtime_two.pending_payload), 16);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_records(lottery_admin: &signer) {
        bootstrap_prerequisites(lottery_admin);
        register_lottery(lottery_admin, 999, @0xCC03);

        jackpot::import_existing_jackpot(
            lottery_admin,
            jackpot::LegacyJackpotRuntime {
                lottery_id: 999,
                tickets: addresses1(@0x01),
                draw_scheduled: false,
                pending_request_id: option::none<u64>(),
                pending_payload: option::none<vector<u8>>(),
            },
        );

        jackpot::import_existing_jackpot(
            lottery_admin,
            jackpot::LegacyJackpotRuntime {
                lottery_id: 999,
                tickets: addresses2(@0x02, @0x03),
                draw_scheduled: true,
                pending_request_id: option::some(501),
                pending_payload: option::some(b"xyz"),
            },
        );

        let runtime_opt = jackpot::runtime_view(999);
        assert!(option::is_some(&runtime_opt), 17);
        let runtime = option::destroy_some(runtime_opt);
        assert!(vector::length(&runtime.tickets) == 2, 18);
        assert!(*vector::borrow(&runtime.tickets, 0) == @0x02, 19);
        assert!(runtime.draw_scheduled, 20);
        assert!(option::is_some(&runtime.pending_request_id), 21);
        assert!(*option::borrow(&runtime.pending_request_id) == 501, 22);
        let payload_view = option::borrow(&runtime.pending_payload);
        assert!(vector::length(payload_view) == 3, 23);
        assert!(*vector::borrow(payload_view, 2) == 0x7A, 24);
    }

    fun bootstrap_prerequisites(lottery_admin: &signer) {
        if (!instances::is_initialized()) {
            instances::init_registry(lottery_admin);
        };
        if (!jackpot_data::is_initialized()) {
            jackpot_data::init_registry(lottery_admin);
        };
    }

    fun register_lottery(lottery_admin: &signer, lottery_id: u64, owner: address) {
        let record = instances::LegacyInstanceRecord {
            lottery_id,
            owner,
            lottery_address: owner,
            ticket_price: 1,
            jackpot_share_bps: 100,
            tickets_sold: 0,
            jackpot_accumulated: 0,
            active: true,
        };
        instances::import_existing_instance(lottery_admin, record);
    }

    fun addresses3(a: address, b: address, c: address): vector<address> {
        let result = vector::empty<address>();
        vector::push_back(&mut result, a);
        vector::push_back(&mut result, b);
        vector::push_back(&mut result, c);
        result
    }

    fun addresses2(a: address, b: address): vector<address> {
        let result = vector::empty<address>();
        vector::push_back(&mut result, a);
        vector::push_back(&mut result, b);
        result
    }

    fun addresses1(a: address): vector<address> {
        let result = vector::empty<address>();
        vector::push_back(&mut result, a);
        result
    }
}
