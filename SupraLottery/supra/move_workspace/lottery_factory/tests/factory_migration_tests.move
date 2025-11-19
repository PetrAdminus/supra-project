#[test_only]
module lottery_factory::factory_migration_tests {
    use std::account;
    use std::vector;

    use lottery_factory::registry;

    const FACTORY: address = @lottery_factory;

    #[test]
    fun import_registry_restores_entries_and_next_lottery_id() {
        let factory_signer = account::create_signer_for_test(FACTORY);

        let mut entries = vector::empty<registry::LegacyFactoryEntry>();
        vector::push_back(
            &mut entries,
            registry::LegacyFactoryEntry {
                lottery_id: 3,
                owner: @0x111,
                lottery: @0x222,
                ticket_price: 7,
                jackpot_share_bps: 250,
            },
        );
        vector::push_back(
            &mut entries,
            registry::LegacyFactoryEntry {
                lottery_id: 1,
                owner: @0x333,
                lottery: @0x444,
                ticket_price: 5,
                jackpot_share_bps: 150,
            },
        );

        let payload = registry::LegacyFactoryState {
            admin: @0x555,
            next_lottery_id: 10,
            lottery_ids: vector::from([1, 3]),
            lotteries: entries,
        };

        registry::import_existing_registry(&factory_signer, payload);

        let snapshot = registry::get_registry_snapshot();
        let (admin, next_lottery_id, total_lotteries, snapshot_entries) =
            registry::registry_snapshot_fields_for_test(&snapshot);
        assert!(admin == @0x555, 0);
        assert!(next_lottery_id == 10, 1);
        assert!(total_lotteries == 2, 2);
        assert!(vector::length(&snapshot_entries) == 2, 3);

        let first = vector::borrow(&snapshot_entries, 0);
        let (
            first_id,
            first_owner,
            first_lottery,
            first_price,
            first_share,
        ) = registry::registry_entry_fields_for_test(first);
        assert!(first_id == 1, 4);
        assert!(first_owner == @0x333, 5);
        assert!(first_lottery == @0x444, 6);
        assert!(first_price == 5, 7);
        assert!(first_share == 150, 8);

        let second = vector::borrow(&snapshot_entries, 1);
        let (
            second_id,
            second_owner,
            second_lottery,
            second_price,
            second_share,
        ) = registry::registry_entry_fields_for_test(second);
        assert!(second_id == 3, 9);
        assert!(second_owner == @0x111, 10);
        assert!(second_lottery == @0x222, 11);
        assert!(second_price == 7, 12);
        assert!(second_share == 250, 13);
    }

    #[test]
    fun import_registry_normalizes_next_id_from_lottery_ids() {
        let factory_signer = account::create_signer_for_test(FACTORY);

        let mut entries = vector::empty<registry::LegacyFactoryEntry>();
        vector::push_back(
            &mut entries,
            registry::LegacyFactoryEntry {
                lottery_id: 4,
                owner: @0xAAA,
                lottery: @0xBBB,
                ticket_price: 30,
                jackpot_share_bps: 900,
            },
        );

        let payload = registry::LegacyFactoryState {
            admin: FACTORY,
            next_lottery_id: 2,
            lottery_ids: vector::from([4]),
            lotteries: entries,
        };

        registry::import_existing_registry(&factory_signer, payload);

        let snapshot = registry::get_registry_snapshot();
        let (_admin, next_lottery_id, total_lotteries, entries_after) =
            registry::registry_snapshot_fields_for_test(&snapshot);
        assert!(next_lottery_id == 5, 20);
        assert!(total_lotteries == 1, 21);
        assert!(vector::length(&entries_after) == 1, 22);
    }

    #[test(admin = @lottery_factory, outsider = @0x666)]
    #[expected_failure(abort_code = 3, location = lottery_factory::registry)]
    fun import_registry_rejects_non_admin(admin: &signer, outsider: &signer) {
        let mut entries = vector::empty<registry::LegacyFactoryEntry>();
        vector::push_back(
            &mut entries,
            registry::LegacyFactoryEntry {
                lottery_id: 1,
                owner: @0x777,
                lottery: @0x888,
                ticket_price: 12,
                jackpot_share_bps: 300,
            },
        );
        let payload = registry::LegacyFactoryState {
            admin: @lottery_factory,
            next_lottery_id: 2,
            lottery_ids: vector::from([1]),
            lotteries: entries,
        };

        registry::import_existing_registry(admin, payload);

        let invalid_payload = registry::LegacyFactoryState {
            admin: @lottery_factory,
            next_lottery_id: 3,
            lottery_ids: vector::from([1]),
            lotteries: vector::empty<registry::LegacyFactoryEntry>(),
        };
        registry::import_existing_registry(outsider, invalid_payload);
    }
}
