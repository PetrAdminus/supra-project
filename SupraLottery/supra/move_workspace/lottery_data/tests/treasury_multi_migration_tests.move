#[test_only]
module lottery_data::treasury_multi_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::treasury_multi;

    #[test(lottery_admin = @lottery)]
    fun import_state_and_lotteries_restore_snapshot(lottery_admin: &signer) {
        treasury_multi::init_state(lottery_admin, @0xAAA, @0xBBB);

        treasury_multi::import_existing_state(
            lottery_admin,
            treasury_multi::LegacyMultiTreasuryState {
                jackpot_recipient: @0xC0FFEE,
                operations_recipient: @0xABCD,
                jackpot_balance: 77_777,
            },
        );

        let mut records = vector::empty<treasury_multi::LegacyMultiTreasuryLottery>();
        vector::push_back(
            &mut records,
            treasury_multi::LegacyMultiTreasuryLottery {
                lottery_id: 1,
                prize_bps: 7_500,
                jackpot_bps: 1_000,
                operations_bps: 1_500,
                prize_balance: 222_222,
                operations_balance: 10_000,
            },
        );
        vector::push_back(
            &mut records,
            treasury_multi::LegacyMultiTreasuryLottery {
                lottery_id: 9,
                prize_bps: 8_000,
                jackpot_bps: 500,
                operations_bps: 1_500,
                prize_balance: 555_555,
                operations_balance: 12_345,
            },
        );

        treasury_multi::import_existing_lotteries(lottery_admin, records);

        let snapshot_opt = treasury_multi::state_snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 1);
        assert!(snapshot.jackpot_recipient.recipient == @0xC0FFEE, 2);
        assert!(snapshot.operations_recipient.recipient == @0xABCD, 3);
        assert!(snapshot.jackpot_balance == 77_777, 4);
        assert!(vector::length(&snapshot.lotteries) == 2, 5);

        let first = *vector::borrow(&snapshot.lotteries, 0);
        assert!(first.lottery_id == 1, 6);
        assert!(first.prize_bps == 7_500, 7);
        assert!(first.operations_balance == 10_000, 8);

        let second = *vector::borrow(&snapshot.lotteries, 1);
        assert!(second.lottery_id == 9, 9);
        assert!(second.jackpot_bps == 500, 10);
        assert!(second.prize_balance == 555_555, 11);
    }

    #[test(lottery_admin = @lottery)]
    fun reimport_existing_lottery_updates_balances(lottery_admin: &signer) {
        treasury_multi::init_state(lottery_admin, @0x111, @0x222);

        treasury_multi::import_existing_lottery(
            lottery_admin,
            treasury_multi::LegacyMultiTreasuryLottery {
                lottery_id: 77,
                prize_bps: 7_000,
                jackpot_bps: 2_000,
                operations_bps: 1_000,
                prize_balance: 90_000,
                operations_balance: 5_000,
            },
        );

        treasury_multi::import_existing_lottery(
            lottery_admin,
            treasury_multi::LegacyMultiTreasuryLottery {
                lottery_id: 77,
                prize_bps: 6_500,
                jackpot_bps: 2_500,
                operations_bps: 1_000,
                prize_balance: 123_456,
                operations_balance: 8_765,
            },
        );

        let snapshot_opt = treasury_multi::state_snapshot();
        assert!(option::is_some(&snapshot_opt), 12);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(vector::length(&snapshot.lotteries) == 1, 13);
        let record = *vector::borrow(&snapshot.lotteries, 0);
        assert!(record.lottery_id == 77, 14);
        assert!(record.prize_bps == 6_500, 15);
        assert!(record.jackpot_bps == 2_500, 16);
        assert!(record.prize_balance == 123_456, 17);
        assert!(record.operations_balance == 8_765, 18);
    }
}
