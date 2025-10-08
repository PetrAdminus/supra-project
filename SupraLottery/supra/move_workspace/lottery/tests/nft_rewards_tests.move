module lottery::nft_rewards_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::nft_rewards;

    #[test(admin = @lottery, owner = @0x123)]
    fun mint_flow(admin: &signer, owner: &signer) {
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
        let info = option::extract(info_opt);
        assert!(info.lottery_id == 1, 4);
        assert!(info.draw_id == 7, 5);
        assert!(info.minted_by == signer::address_of(admin), 6);
    }

    #[test(admin = @lottery, owner = @0x456)]
    #[expected_failure(abort_code = 1)]
    fun non_admin_cannot_mint(admin: &signer, owner: &signer) {
        nft_rewards::init(admin);
        let owner_addr = signer::address_of(owner);
        nft_rewards::mint_badge(owner, owner_addr, 1, 1, vector::empty<u8>());
    }

    #[test(admin = @lottery, owner = @0x789)]
    fun burn_by_owner(admin: &signer, owner: &signer) {
        nft_rewards::init(admin);
        let owner_addr = signer::address_of(owner);
        nft_rewards::mint_badge(admin, owner_addr, 2, 10, vector::empty<u8>());
        nft_rewards::burn_badge(owner, owner_addr, 1);
        assert!(!nft_rewards::has_badge(owner_addr, 1), 0);
    }
}
