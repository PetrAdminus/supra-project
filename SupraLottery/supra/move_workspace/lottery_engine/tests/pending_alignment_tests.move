#[test_only]
module lottery_engine::pending_alignment_tests {
    use std::hash;
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_engine::draw;
    use lottery_vrf_gateway::hub;

    #[test(admin = @lottery, hub_admin = @lottery_vrf_gateway)]
    fun alignment_reports_pending_state(admin: &signer, hub_admin: &signer) {
        hub::init(hub_admin);
        hub::register_lottery(hub_admin, @lottery, @lottery, b"meta");

        instances::init_registry(admin, @lottery_vrf_gateway);
        rounds::init_registry(admin);
        lottery_state::init(admin);

        let instance = instances::LegacyInstanceRecord {
            lottery_id: 0,
            owner: @lottery,
            lottery_address: @lottery,
            ticket_price: 10,
            jackpot_share_bps: 100,
            tickets_sold: 1,
            jackpot_accumulated: 5,
            active: true,
        };
        instances::import_existing_instance(admin, instance);

        let mut tickets = vector::empty<address>();
        vector::push_back(&mut tickets, @player1);
        let payload = b"payload";
        let request_id = hub::request_randomness(0, vector::copy(payload));
        let payload_hash = hash::sha3_256(payload);

        let round_record = rounds::LegacyRoundRecord {
            lottery_id: 0,
            tickets: clone_addresses(&tickets),
            draw_scheduled: true,
            next_ticket_id: 1,
            pending_request: option::some(request_id),
        };
        rounds::import_existing_round(admin, round_record);

        let runtime = lottery_state::LegacyLotteryRuntime {
            lottery_id: 0,
            ticket_price: 10,
            jackpot_amount: 5,
            participants: tickets,
            next_ticket_id: 1,
            draw_scheduled: true,
            auto_draw_threshold: 0,
            pending_request_id: option::some(request_id),
            last_request_payload_hash: option::some(payload_hash),
            last_requester: option::some(@lottery),
            gas: lottery_state::GasBudget {
                max_fee: 0,
                max_gas_price: 0,
                max_gas_limit: 0,
                callback_gas_price: 0,
                callback_gas_limit: 0,
                verification_gas_value: 0,
            },
            vrf_stats: lottery_state::VrfStats { request_count: 1, response_count: 0, next_client_seed: 0 },
            whitelist: lottery_state::WhitelistState {
                callback_sender: option::none<address>(),
                consumers: vector::empty<address>(),
                client_snapshot: option::none<lottery_state::ClientWhitelistSnapshot>(),
                consumer_snapshot: option::none<lottery_state::ConsumerWhitelistSnapshot>(),
            },
            request_config: option::none<lottery_state::VrfRequestConfig>(),
        };
        lottery_state::import_existing_lottery(admin, runtime);

        let alignment = draw::pending_request_alignment(0);
        assert!(option::is_some(&alignment), 0);
        let report = option::destroy_some(alignment);

        assert!(option::is_some(&report.round_pending_request_id), 1);
        assert!(option::borrow(&report.round_pending_request_id) == &request_id, 2);
        assert!(report.pending_ids_match, 3);
        assert!(report.hub_pending, 4);
        assert!(report.payload_hash_match, 5);
        assert!(option::is_some(&report.hub_request_id), 6);
    }

    fun clone_addresses(addresses: &vector<address>): vector<address> {
        let len = vector::length(addresses);
        let mut out = vector::empty<address>();
        let mut i = 0;
        while (i < len) {
            vector::push_back(&mut out, *vector::borrow(addresses, i));
            i = i + 1;
        };
        out
    }
}
