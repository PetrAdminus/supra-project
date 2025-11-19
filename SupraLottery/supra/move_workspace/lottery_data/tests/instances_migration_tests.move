#[test_only]
module lottery_data::instances_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::instances;

    #[test(lottery_admin = @lottery)]
    fun import_existing_instances_restore_registry(lottery_admin: &signer) {
        instances::init_registry(lottery_admin, @0xC0FFEE);

        let mut records = vector::empty<instances::LegacyInstanceRecord>();
        vector::push_back(
            &mut records,
            instances::LegacyInstanceRecord {
                lottery_id: 11,
                owner: @0x111,
                lottery_address: @0xA11,
                ticket_price: 1_000,
                jackpot_share_bps: 2_000,
                tickets_sold: 5_000,
                jackpot_accumulated: 25_000,
                active: true,
            },
        );
        vector::push_back(
            &mut records,
            instances::LegacyInstanceRecord {
                lottery_id: 7,
                owner: @0x222,
                lottery_address: @0xB22,
                ticket_price: 2_500,
                jackpot_share_bps: 3_500,
                tickets_sold: 12_345,
                jackpot_accumulated: 77_777,
                active: false,
            },
        );

        instances::import_existing_instances(lottery_admin, records);

        let registry_opt = instances::registry_snapshot();
        assert!(option::is_some(&registry_opt), 0);
        let registry = option::destroy_some(registry_opt);
        assert!(registry.admin == @lottery, 1);
        assert!(registry.hub == @0xC0FFEE, 2);
        assert!(vector::length(&registry.instances) == 2, 3);

        let first_snapshot_opt = instances::instance_snapshot(11);
        assert!(option::is_some(&first_snapshot_opt), 4);
        let first_snapshot = option::destroy_some(first_snapshot_opt);
        assert!(first_snapshot.owner == @0x111, 5);
        assert!(first_snapshot.ticket_price == 1_000, 6);
        assert!(first_snapshot.tickets_sold == 5_000, 7);
        assert!(first_snapshot.active, 8);

        let second_snapshot_opt = instances::instance_snapshot(7);
        assert!(option::is_some(&second_snapshot_opt), 9);
        let second_snapshot = option::destroy_some(second_snapshot_opt);
        assert!(second_snapshot.lottery_address == @0xB22, 10);
        assert!(second_snapshot.jackpot_share_bps == 3_500, 11);
        assert!(second_snapshot.jackpot_accumulated == 77_777, 12);
        assert!(!second_snapshot.active, 13);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_updates_existing_instance(lottery_admin: &signer) {
        instances::init_registry(lottery_admin, @0xDEADBEEF);

        instances::import_existing_instance(
            lottery_admin,
            instances::LegacyInstanceRecord {
                lottery_id: 33,
                owner: @0xAAA,
                lottery_address: @0xC33,
                ticket_price: 750,
                jackpot_share_bps: 1_500,
                tickets_sold: 50,
                jackpot_accumulated: 9_999,
                active: true,
            },
        );

        instances::import_existing_instance(
            lottery_admin,
            instances::LegacyInstanceRecord {
                lottery_id: 33,
                owner: @0xBBB,
                lottery_address: @0xD44,
                ticket_price: 1_250,
                jackpot_share_bps: 4_000,
                tickets_sold: 80,
                jackpot_accumulated: 12_345,
                active: false,
            },
        );

        let snapshot_opt = instances::instance_snapshot(33);
        assert!(option::is_some(&snapshot_opt), 14);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.owner == @0xBBB, 15);
        assert!(snapshot.lottery_address == @0xD44, 16);
        assert!(snapshot.ticket_price == 1_250, 17);
        assert!(snapshot.jackpot_share_bps == 4_000, 18);
        assert!(snapshot.tickets_sold == 80, 19);
        assert!(snapshot.jackpot_accumulated == 12_345, 20);
        assert!(!snapshot.active, 21);

        let registry_opt = instances::registry_snapshot();
        let registry = option::destroy_some(registry_opt);
        assert!(vector::length(&registry.instances) == 1, 22);
        let stored = *vector::borrow(&registry.instances, 0);
        assert!(stored.lottery_id == 33, 23);
        assert!(stored.ticket_price == 1_250, 24);
    }
}
