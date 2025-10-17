#[test_only]
module lottery::nft_rewards_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::nft_rewards;
    use lottery::test_utils;

    #[test(admin = @lottery, owner = @0x123)]
    fun mint_flow(admin: &signer, owner: &signer) {
        test_utils::ensure_core_accounts();
        nft_rewards::init(admin);
        let owner_addr = signer::address_of(owner);
        let metadata = b"ipfs://badge-1";
        nft_rewards::mint_badge(admin, owner_addr, 1, 7, metadata);
        assert!(nft_rewards::has_badge(owner_addr, 1), 0);
        let badges = nft_rewards::list_badges(owner_addr);
        assert!(vector::length(&badges) == 1, 1);
        assert!(*vector::borrow(&badges, 0) == 1, 2);
        let info_opt = nft_rewards::get_badge(owner_addr, 1);
        assert!(option::is_some(&info_opt), 3);
        let info = test_utils::unwrap(&mut info_opt);
        let (lottery_id, draw_id, _metadata, minted_by) =
            nft_rewards::badge_fields_for_test(&info);
        assert!(lottery_id == 1, 4);
        assert!(draw_id == 7, 5);
        assert!(minted_by == signer::address_of(admin), 6);
    }

    #[test(admin = @lottery, owner = @0x456)]
    #[expected_failure(
        location = lottery::nft_rewards,
        abort_code = nft_rewards::E_NOT_AUTHORIZED,
    )]
    fun non_admin_cannot_mint(admin: &signer, owner: &signer) {
        test_utils::ensure_core_accounts();
        nft_rewards::init(admin);
        let owner_addr = signer::address_of(owner);
        nft_rewards::mint_badge(owner, owner_addr, 1, 1, vector::empty<u8>());
    }

    #[test(admin = @lottery, owner = @0x789)]
    fun burn_by_owner(admin: &signer, owner: &signer) {
        test_utils::ensure_core_accounts();
        nft_rewards::init(admin);
        let owner_addr = signer::address_of(owner);
        nft_rewards::mint_badge(admin, owner_addr, 2, 10, vector::empty<u8>());
        nft_rewards::burn_badge(owner, owner_addr, 1);
        assert!(!nft_rewards::has_badge(owner_addr, 1), 0);
    }

    #[test(admin = @lottery, owner1 = @0xa11ce, owner2 = @0xb0b0)]
    fun snapshot_and_events(admin: &signer, owner1: &signer, owner2: &signer) {
        let snapshot_baseline =
            test_utils::event_count<nft_rewards::NftRewardsSnapshotUpdatedEvent>();
        test_utils::ensure_core_accounts();
        nft_rewards::init(admin);
        let owner1_addr = signer::address_of(owner1);
        let owner2_addr = signer::address_of(owner2);
        let metadata1 = b"badge-one";
        let metadata2 = b"badge-two";

        nft_rewards::mint_badge(admin, owner1_addr, 42, 7, metadata1);
        nft_rewards::mint_badge(admin, owner2_addr, 99, 3, metadata2);

        let owners = nft_rewards::list_owner_addresses();
        assert!(vector::length(&owners) == 2, 0);
        assert!(*vector::borrow(&owners, 0) == owner1_addr, 1);
        assert!(*vector::borrow(&owners, 1) == owner2_addr, 2);

        let snapshot_opt = nft_rewards::get_snapshot();
        assert!(option::is_some(&snapshot_opt), 3);
        let snapshot = test_utils::unwrap(&mut snapshot_opt);
        let (snapshot_admin, next_badge_id, owner_snapshots) =
            nft_rewards::rewards_snapshot_fields_for_test(&snapshot);
        assert!(snapshot_admin == signer::address_of(admin), 4);
        assert!(next_badge_id == 3, 5);
        assert!(vector::length(&owner_snapshots) == 2, 6);

        let first_snapshot = vector::borrow(&owner_snapshots, 0);
        let (first_owner, first_badges) =
            nft_rewards::owner_snapshot_fields_for_test(first_snapshot);
        assert!(first_owner == owner1_addr, 7);
        assert!(vector::length(&first_badges) == 1, 8);
        let first_badge = vector::borrow(&first_badges, 0);
        let (first_badge_id, first_lottery, first_draw, first_metadata, first_minter) =
            nft_rewards::badge_snapshot_fields_for_test(first_badge);
        assert!(first_badge_id == 1, 9);
        assert!(first_lottery == 42, 10);
        assert!(first_draw == 7, 11);
        assert!(first_minter == signer::address_of(admin), 12);
        assert!(vector::length(&first_metadata) == vector::length(&metadata1), 13);
        assert!(vector::length(&metadata1) > 0, 14);
        assert!(*vector::borrow(&first_metadata, 0) == *vector::borrow(&metadata1, 0), 15);

        let second_snapshot = vector::borrow(&owner_snapshots, 1);
        let (second_owner, second_badges) =
            nft_rewards::owner_snapshot_fields_for_test(second_snapshot);
        assert!(second_owner == owner2_addr, 16);
        assert!(vector::length(&second_badges) == 1, 17);
        let second_badge = vector::borrow(&second_badges, 0);
        let (second_badge_id, second_lottery, second_draw, second_metadata, second_minter) =
            nft_rewards::badge_snapshot_fields_for_test(second_badge);
        assert!(second_badge_id == 2, 18);
        assert!(second_lottery == 99, 19);
        assert!(second_draw == 3, 20);
        assert!(second_minter == signer::address_of(admin), 21);
        assert!(vector::length(&second_metadata) == vector::length(&metadata2), 22);

        let owner2_snapshot_opt = nft_rewards::get_owner_snapshot(owner2_addr);
        assert!(option::is_some(&owner2_snapshot_opt), 23);
        let owner2_snapshot = test_utils::unwrap(&mut owner2_snapshot_opt);
        let (owner2_from_view, owner2_badges) =
            nft_rewards::owner_snapshot_fields_for_test(&owner2_snapshot);
        assert!(owner2_from_view == owner2_addr, 24);
        assert!(vector::length(&owner2_badges) == 1, 25);
        let badge_from_view = vector::borrow(&owner2_badges, 0);
        let (view_badge_id, _, _, _, _) =
            nft_rewards::badge_snapshot_fields_for_test(badge_from_view);
        assert!(view_badge_id == 2, 26);

        let snapshot_events_len =
            test_utils::event_count<nft_rewards::NftRewardsSnapshotUpdatedEvent>();
        assert!(snapshot_events_len >= snapshot_baseline + 2, 27);
        let last_event = test_utils::borrow_event<nft_rewards::NftRewardsSnapshotUpdatedEvent>(
            snapshot_events_len - 1,
        );
        let (event_admin, event_next_id, event_snapshot) =
            nft_rewards::snapshot_event_fields_for_test(last_event);
        assert!(event_admin == signer::address_of(admin), 28);
        assert!(event_next_id == 3, 29);
        let (event_owner, event_badges) =
            nft_rewards::owner_snapshot_fields_for_test(&event_snapshot);
        assert!(event_owner == owner2_addr, 30);
        assert!(vector::length(&event_badges) == 1, 31);

        nft_rewards::burn_badge(admin, owner1_addr, 1);

        let events_after_burn_len =
            test_utils::event_count<nft_rewards::NftRewardsSnapshotUpdatedEvent>();
        assert!(events_after_burn_len >= snapshot_baseline + 3, 32);
        let burn_event = test_utils::borrow_event<nft_rewards::NftRewardsSnapshotUpdatedEvent>(
            events_after_burn_len - 1,
        );
        let (_, burn_next_id, burn_snapshot) =
            nft_rewards::snapshot_event_fields_for_test(burn_event);
        assert!(burn_next_id == 3, 33);
        let (burn_owner, burn_badges) =
            nft_rewards::owner_snapshot_fields_for_test(&burn_snapshot);
        assert!(burn_owner == owner1_addr, 34);
        assert!(vector::length(&burn_badges) == 0, 35);

        let owner1_snapshot_opt = nft_rewards::get_owner_snapshot(owner1_addr);
        assert!(option::is_some(&owner1_snapshot_opt), 36);
        let owner1_snapshot = test_utils::unwrap(&mut owner1_snapshot_opt);
        let (_, owner1_badges_after) =
            nft_rewards::owner_snapshot_fields_for_test(&owner1_snapshot);
        assert!(vector::length(&owner1_badges_after) == 0, 37);
    }
}
