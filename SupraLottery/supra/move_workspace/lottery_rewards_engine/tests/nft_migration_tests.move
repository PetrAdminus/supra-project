#[test_only]
module lottery_rewards_engine::nft_migration_tests {
    use std::option;
    use std::vector;

    use lottery_rewards_engine::nft;

    #[test(lottery_admin = @lottery)]
    fun init_and_mint_keep_ready(lottery_admin: &signer) {
        ensure_initialized(lottery_admin);

        assert!(nft::ready(), 0);

        nft::mint_badge(lottery_admin, @0xA1, 100, 1, b"ipfs://badge/1");
        nft::mint_badge(lottery_admin, @0xB2, 200, 2, b"ipfs://badge/2");

        assert!(nft::ready(), 1);

        let snapshot_opt = nft::snapshot();
        assert!(option::is_some(&snapshot_opt), 2);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 3);
        assert!(snapshot.next_badge_id == 3, 4);

        let first_owner_opt = find_owner_snapshot(&snapshot.owners, @0xA1, 0);
        assert!(option::is_some(&first_owner_opt), 5);
        let first_owner = option::destroy_some(first_owner_opt);
        assert!(vector::length(&first_owner.badges) == 1, 6);
        let badge_a_opt = find_badge_snapshot(&first_owner.badges, 1, 0);
        assert!(option::is_some(&badge_a_opt), 7);
        let badge_a = option::destroy_some(badge_a_opt);
        assert!(badge_a.lottery_id == 100, 8);
        assert!(badge_a.draw_id == 1, 9);

        let second_owner_opt = find_owner_snapshot(&snapshot.owners, @0xB2, 0);
        assert!(option::is_some(&second_owner_opt), 10);
        let second_owner = option::destroy_some(second_owner_opt);
        let badge_b_opt = find_badge_snapshot(&second_owner.badges, 2, 0);
        assert!(option::is_some(&badge_b_opt), 11);
    }

    #[test(lottery_admin = @lottery)]
    fun import_existing_authority_restores_state(lottery_admin: &signer) {
        ensure_initialized(lottery_admin);

        let mut owner_a_badges = vector::empty<nft::LegacyBadge>();
        vector::push_back(
            &mut owner_a_badges,
            nft::LegacyBadge { badge_id: 10, lottery_id: 300, draw_id: 7, metadata_uri: b"ipfs://badge/10", minted_by: @lottery },
        );
        vector::push_back(
            &mut owner_a_badges,
            nft::LegacyBadge { badge_id: 11, lottery_id: 300, draw_id: 8, metadata_uri: b"ipfs://badge/11", minted_by: @lottery },
        );

        let mut owner_b_badges = vector::empty<nft::LegacyBadge>();
        vector::push_back(
            &mut owner_b_badges,
            nft::LegacyBadge { badge_id: 12, lottery_id: 301, draw_id: 1, metadata_uri: b"ipfs://badge/12", minted_by: @lottery },
        );

        let mut owners = vector::empty<nft::LegacyBadgeOwner>();
        vector::push_back(&mut owners, nft::LegacyBadgeOwner { owner: @0xCAFE, badges: owner_a_badges });
        vector::push_back(&mut owners, nft::LegacyBadgeOwner { owner: @0xBEEF, badges: owner_b_badges });

        nft::import_existing_badge_authority(
            lottery_admin,
            nft::LegacyBadgeAuthority { admin: @lottery, next_badge_id: 13, owners },
        );

        assert!(nft::ready(), 0);

        let snapshot_opt = nft::snapshot();
        assert!(option::is_some(&snapshot_opt), 1);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.next_badge_id == 13, 2);
        assert!(vector::length(&snapshot.owners) == 2, 3);

        let owner_a_opt = find_owner_snapshot(&snapshot.owners, @0xCAFE, 0);
        assert!(option::is_some(&owner_a_opt), 4);
        let owner_a = option::destroy_some(owner_a_opt);
        assert!(vector::length(&owner_a.badges) == 2, 5);
        let badge_10_opt = find_badge_snapshot(&owner_a.badges, 10, 0);
        assert!(option::is_some(&badge_10_opt), 6);

        let owner_b_opt = find_owner_snapshot(&snapshot.owners, @0xBEEF, 0);
        assert!(option::is_some(&owner_b_opt), 7);
        let owner_b = option::destroy_some(owner_b_opt);
        let badge_12_opt = find_badge_snapshot(&owner_b.badges, 12, 0);
        assert!(option::is_some(&badge_12_opt), 8);
    }

    fun ensure_initialized(lottery_admin: &signer) {
        if (!nft::is_initialized()) {
            nft::init(lottery_admin);
        };
    }

    fun find_owner_snapshot(
        owners: &vector<nft::BadgeOwnerSnapshot>,
        owner: address,
        index: u64,
    ): option::Option<nft::BadgeOwnerSnapshot> {
        if (index == vector::length(owners)) {
            return option::none<nft::BadgeOwnerSnapshot>();
        };
        let snapshot = *vector::borrow(owners, index);
        if (snapshot.owner == owner) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_owner_snapshot(owners, owner, next_index)
    }

    fun find_badge_snapshot(
        badges: &vector<nft::BadgeSnapshot>,
        badge_id: u64,
        index: u64,
    ): option::Option<nft::BadgeSnapshot> {
        if (index == vector::length(badges)) {
            return option::none<nft::BadgeSnapshot>();
        };
        let snapshot = *vector::borrow(badges, index);
        if (snapshot.badge_id == badge_id) {
            return option::some(snapshot);
        };
        let next_index = index + 1;
        find_badge_snapshot(badges, badge_id, next_index)
    }
}
