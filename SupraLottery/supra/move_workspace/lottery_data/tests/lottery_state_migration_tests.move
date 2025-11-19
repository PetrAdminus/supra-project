#[test_only]
module lottery_data::lottery_state_migration_tests {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::lottery_state;

    #[test(
        lottery_admin = @lottery,
        first_player = @first_player,
        second_player = @second_player,
        third_player = @third_player
    )]
    fun import_and_update_lotteries(
        lottery_admin: &signer,
        first_player: &signer,
        second_player: &signer,
        third_player: &signer,
    ) {
        lottery_state::init(lottery_admin);

        let mut participants = vector::empty<address>();
        vector::push_back(&mut participants, signer::address_of(first_player));
        vector::push_back(&mut participants, signer::address_of(second_player));

        let mut lotteries = vector::empty<lottery_state::LegacyLotteryRuntime>();
        vector::push_back(
            &mut lotteries,
            lottery_state::LegacyLotteryRuntime {
                lottery_id: 1,
                ticket_price: 5,
                jackpot_amount: 250,
                participants,
                next_ticket_id: 3,
                draw_scheduled: true,
                auto_draw_threshold: 3,
                pending_request_id: option::some(99),
                last_request_payload_hash: option::some(b"payload_hash"),
                last_requester: option::some(signer::address_of(first_player)),
                gas: lottery_state::GasBudget {
                    max_fee: 1_000,
                    max_gas_price: 2,
                    max_gas_limit: 3,
                    callback_gas_price: 4,
                    callback_gas_limit: 5,
                    verification_gas_value: 6,
                },
                vrf_stats: lottery_state::VrfStats {
                    request_count: 10,
                    response_count: 7,
                    next_client_seed: 11,
                },
                whitelist: lottery_state::WhitelistState {
                    callback_sender: option::some(signer::address_of(second_player)),
                    consumers: vector::empty<address>(),
                    client_snapshot: option::some(lottery_state::ClientWhitelistSnapshot {
                        max_gas_price: 100,
                        max_gas_limit: 200,
                        min_balance_limit: 300,
                    }),
                    consumer_snapshot: option::some(lottery_state::ConsumerWhitelistSnapshot {
                        callback_gas_price: 8,
                        callback_gas_limit: 9,
                    }),
                },
                request_config: option::some(lottery_state::VrfRequestConfig {
                    rng_count: 4,
                    num_confirmations: 55,
                    client_seed: 77,
                }),
            },
        );

        let mut second_participants = vector::empty<address>();
        vector::push_back(&mut second_participants, signer::address_of(third_player));
        vector::push_back(&mut second_participants, signer::address_of(first_player));
        vector::push_back(&mut lotteries, lottery_state::LegacyLotteryRuntime {
            lottery_id: 2,
            ticket_price: 10,
            jackpot_amount: 500,
            participants: second_participants,
            next_ticket_id: 4,
            draw_scheduled: false,
            auto_draw_threshold: 0,
            pending_request_id: option::none<u64>(),
            last_request_payload_hash: option::none<vector<u8>>(),
            last_requester: option::none<address>(),
            gas: lottery_state::GasBudget {
                max_fee: 5_000,
                max_gas_price: 6,
                max_gas_limit: 7,
                callback_gas_price: 8,
                callback_gas_limit: 9,
                verification_gas_value: 10,
            },
            vrf_stats: lottery_state::VrfStats {
                request_count: 0,
                response_count: 0,
                next_client_seed: 12,
            },
            whitelist: lottery_state::WhitelistState {
                callback_sender: option::none<address>(),
                consumers: vector::empty<address>(),
                client_snapshot: option::none<lottery_state::ClientWhitelistSnapshot>(),
                consumer_snapshot: option::none<lottery_state::ConsumerWhitelistSnapshot>(),
            },
            request_config: option::none<lottery_state::VrfRequestConfig>(),
        });

        lottery_state::import_existing_lotteries(lottery_admin, lotteries);

        let state = lottery_state::borrow(@lottery);
        let first_runtime = lottery_state::runtime(state, 1);
        assert!(first_runtime.ticket_price == 5, 0);
        assert!(first_runtime.jackpot_amount == 250, 1);
        assert!(vector::length(&first_runtime.tickets.participants) == 2, 2);
        assert!(first_runtime.tickets.next_ticket_id == 3, 3);
        assert!(first_runtime.draw.draw_scheduled, 4);
        assert!(first_runtime.draw.auto_draw_threshold == 3, 5);
        assert!(option::is_some(&first_runtime.pending_request.request_id), 6);
        assert!(option::is_some(&first_runtime.pending_request.last_request_payload_hash), 7);
        assert!(option::is_some(&first_runtime.pending_request.last_requester), 8);
        assert!(first_runtime.gas.max_fee == 1_000, 9);
        assert!(first_runtime.vrf_stats.request_count == 10, 10);
        assert!(option::is_some(&first_runtime.request_config), 11);
        assert!(option::is_some(&first_runtime.whitelist.client_snapshot), 12);
        assert!(option::is_some(&first_runtime.whitelist.consumer_snapshot), 13);

        let second_runtime = lottery_state::runtime(state, 2);
        assert!(second_runtime.ticket_price == 10, 14);
        assert!(second_runtime.jackpot_amount == 500, 15);
        assert!(vector::length(&second_runtime.tickets.participants) == 2, 16);
        assert!(second_runtime.tickets.next_ticket_id == 4, 17);
        assert!(!second_runtime.draw.draw_scheduled, 18);
        assert!(second_runtime.draw.auto_draw_threshold == 0, 19);
        assert!(!option::is_some(&second_runtime.pending_request.request_id), 20);
        assert!(!option::is_some(&second_runtime.request_config), 21);

        let mut updated_participants = vector::empty<address>();
        vector::push_back(&mut updated_participants, signer::address_of(third_player));
        vector::push_back(&mut updated_participants, signer::address_of(second_player));
        lottery_state::import_existing_lottery(
            lottery_admin,
            lottery_state::LegacyLotteryRuntime {
                lottery_id: 1,
                ticket_price: 7,
                jackpot_amount: 300,
                participants: updated_participants,
                next_ticket_id: 5,
                draw_scheduled: false,
                auto_draw_threshold: 1,
                pending_request_id: option::none<u64>(),
                last_request_payload_hash: option::none<vector<u8>>(),
                last_requester: option::none<address>(),
                gas: lottery_state::GasBudget {
                    max_fee: 2_000,
                    max_gas_price: 20,
                    max_gas_limit: 30,
                    callback_gas_price: 40,
                    callback_gas_limit: 50,
                    verification_gas_value: 60,
                },
                vrf_stats: lottery_state::VrfStats {
                    request_count: 11,
                    response_count: 8,
                    next_client_seed: 44,
                },
                whitelist: lottery_state::WhitelistState {
                    callback_sender: option::some(signer::address_of(third_player)),
                    consumers: vector::empty<address>(),
                    client_snapshot: option::none<lottery_state::ClientWhitelistSnapshot>(),
                    consumer_snapshot: option::none<lottery_state::ConsumerWhitelistSnapshot>(),
                },
                request_config: option::some(lottery_state::VrfRequestConfig {
                    rng_count: 3,
                    num_confirmations: 66,
                    client_seed: 88,
                }),
            },
        );

        let updated_state = lottery_state::borrow(@lottery);
        let migrated_runtime = lottery_state::runtime(updated_state, 1);
        assert!(migrated_runtime.ticket_price == 7, 22);
        assert!(migrated_runtime.jackpot_amount == 300, 23);
        assert!(vector::length(&migrated_runtime.tickets.participants) == 2, 24);
        assert!(migrated_runtime.tickets.next_ticket_id == 5, 25);
        assert!(!migrated_runtime.draw.draw_scheduled, 26);
        assert!(migrated_runtime.draw.auto_draw_threshold == 1, 27);
        assert!(!option::is_some(&migrated_runtime.pending_request.request_id), 28);
        assert!(!option::is_some(&migrated_runtime.pending_request.last_request_payload_hash), 29);
        assert!(!option::is_some(&migrated_runtime.pending_request.last_requester), 30);
        assert!(migrated_runtime.gas.max_fee == 2_000, 31);
        assert!(migrated_runtime.vrf_stats.request_count == 11, 32);
        assert!(option::is_some(&migrated_runtime.request_config), 33);
        assert!(!option::is_some(&migrated_runtime.whitelist.client_snapshot), 34);
        assert!(!option::is_some(&migrated_runtime.whitelist.consumer_snapshot), 35);
    }
}

