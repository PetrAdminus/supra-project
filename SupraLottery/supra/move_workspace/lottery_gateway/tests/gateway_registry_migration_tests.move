#[test_only]
module lottery_gateway::gateway_registry_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;
    use lottery_gateway::gateway;
    use lottery_gateway::registry;

    #[test(lottery_admin = @lottery)]
    fun migrate_lottery_registry_keeps_gateway_and_facade_in_sync(lottery_admin: &signer) {
        instances::init_registry(lottery_admin, @lottery);
        gateway::init(lottery_admin, @lottery);

        let mut gateway_entries = vector::empty<gateway::LegacyGatewayLottery>();
        vector::push_back(
            &mut gateway_entries,
            gateway::LegacyGatewayLottery {
                lottery_id: 7,
                owner: @0x1,
                active: true,
                ticket_price: 5,
                auto_draw_threshold: 11,
                jackpot_share_bps: 450,
            },
        );
        vector::push_back(
            &mut gateway_entries,
            gateway::LegacyGatewayLottery {
                lottery_id: 8,
                owner: @0x2,
                active: false,
                ticket_price: 10,
                auto_draw_threshold: 0,
                jackpot_share_bps: 550,
            },
        );
        let gateway_payload = gateway::LegacyGatewayRegistry {
            admin: @lottery,
            next_lottery_id: 9,
            lotteries: gateway_entries,
        };

        let mut registry_entries = vector::empty<registry::LegacyLotteryRegistryEntry>();
        vector::push_back(
            &mut registry_entries,
            registry::LegacyLotteryRegistryEntry {
                lottery_id: 7,
                owner: @0x1,
                lottery_address: @0xAAA,
                ticket_price: 5,
                jackpot_share_bps: 450,
                active: true,
                cancellation: option::none<registry::LotteryCancellationSummary>(),
            },
        );
        vector::push_back(
            &mut registry_entries,
            registry::LegacyLotteryRegistryEntry {
                lottery_id: 8,
                owner: @0x2,
                lottery_address: @0xBBB,
                ticket_price: 10,
                jackpot_share_bps: 550,
                active: false,
                cancellation: option::none<registry::LotteryCancellationSummary>(),
            },
        );
        let registry_payload = registry::LegacyLotteryRegistry {
            admin: @lottery,
            next_lottery_id: 9,
            entries: registry_entries,
        };

        gateway::migrate_lottery_registry(lottery_admin, gateway_payload, registry_payload);

        let ids = gateway::list_lottery_ids();
        assert!(vector::length(&ids) == 2, 0);
        assert!(*vector::borrow(&ids, 0) == 7, 1);
        assert!(*vector::borrow(&ids, 1) == 8, 2);

        let gateway_entry_opt = gateway::lottery(8);
        assert!(option::is_some(&gateway_entry_opt), 3);
        let gateway_entry = option::destroy_some(gateway_entry_opt);
        assert!(!gateway_entry.active, 4);
        assert!(gateway_entry.owner == @0x2, 5);

        let registry_entry_opt = registry::lottery_entry(8);
        assert!(option::is_some(&registry_entry_opt), 6);
        let registry_entry = option::destroy_some(registry_entry_opt);
        assert!(option::is_none(&registry_entry.cancellation), 7);
        assert!(registry_entry.lottery_address == @0xBBB, 8);
        assert!(!registry_entry.active, 9);

        let snapshot_opt = registry::registry_snapshot();
        assert!(option::is_some(&snapshot_opt), 10);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.total_lotteries == 2, 11);
        assert!(snapshot.next_lottery_id == 9, 12);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 8)]
    fun migrate_lottery_registry_rejects_mismatched_lengths(lottery_admin: &signer) {
        instances::init_registry(lottery_admin, @lottery);
        gateway::init(lottery_admin, @lottery);

        let mut gateway_entries = vector::empty<gateway::LegacyGatewayLottery>();
        vector::push_back(
            &mut gateway_entries,
            gateway::LegacyGatewayLottery {
                lottery_id: 1,
                owner: @lottery,
                active: true,
                ticket_price: 1,
                auto_draw_threshold: 0,
                jackpot_share_bps: 500,
            },
        );
        let gateway_payload = gateway::LegacyGatewayRegistry {
            admin: @lottery,
            next_lottery_id: 2,
            lotteries: gateway_entries,
        };

        let mut registry_entries = vector::empty<registry::LegacyLotteryRegistryEntry>();
        vector::push_back(
            &mut registry_entries,
            registry::LegacyLotteryRegistryEntry {
                lottery_id: 1,
                owner: @lottery,
                lottery_address: @lottery,
                ticket_price: 1,
                jackpot_share_bps: 500,
                active: true,
                cancellation: option::none<registry::LotteryCancellationSummary>(),
            },
        );
        vector::push_back(
            &mut registry_entries,
            registry::LegacyLotteryRegistryEntry {
                lottery_id: 2,
                owner: @lottery,
                lottery_address: @lottery,
                ticket_price: 1,
                jackpot_share_bps: 500,
                active: true,
                cancellation: option::none<registry::LotteryCancellationSummary>(),
            },
        );
        let registry_payload = registry::LegacyLotteryRegistry {
            admin: @lottery,
            next_lottery_id: 2,
            entries: registry_entries,
        };

        gateway::migrate_lottery_registry(lottery_admin, gateway_payload, registry_payload);
    }
}
