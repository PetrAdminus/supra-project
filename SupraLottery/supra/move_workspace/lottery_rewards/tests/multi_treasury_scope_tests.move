#[test_only]
module lottery_rewards::multi_treasury_scope_tests {
    use lottery_core::treasury_multi;
    use lottery_rewards::jackpot;
    use lottery_rewards::referrals;
    use lottery_rewards::store;
    use lottery_rewards::test_utils;
    use lottery_rewards::vip;

    #[test(admin = @lottery, factory = @lottery_factory, vrf = @vrf_hub)]
    fun scopes_are_isolated(admin: &signer, factory: &signer, vrf: &signer) {
        test_utils::bootstrap_multi_treasury(admin, factory, vrf);

        assert!(jackpot::scope_id() == treasury_multi::scope_jackpot(), 0);
        assert!(referrals::scope_id() == treasury_multi::scope_referrals(), 1);
        assert!(store::scope_id() == treasury_multi::scope_store(), 2);
        assert!(vip::scope_id() == treasury_multi::scope_vip(), 3);

        assert!(!jackpot::caps_ready(), 4);
        assert!(!referrals::caps_ready(), 5);
        assert!(!store::caps_ready(), 6);
        assert!(!vip::caps_ready(), 7);

        assert!(treasury_multi::cap_available(jackpot::scope_id()), 8);
        assert!(treasury_multi::cap_available(referrals::scope_id()), 9);
        assert!(treasury_multi::cap_available(store::scope_id()), 10);
        assert!(treasury_multi::cap_available(vip::scope_id()), 11);

        jackpot::ensure_caps_initialized(admin);
        assert!(jackpot::caps_ready(), 12);
        assert!(!treasury_multi::cap_available(jackpot::scope_id()), 13);
        assert!(treasury_multi::cap_available(referrals::scope_id()), 14);

        jackpot::release_caps(admin);
        assert!(!jackpot::caps_ready(), 15);
        assert!(treasury_multi::cap_available(jackpot::scope_id()), 16);

        referrals::ensure_caps_initialized(admin);
        assert!(referrals::caps_ready(), 17);
        assert!(!treasury_multi::cap_available(referrals::scope_id()), 18);
        referrals::release_caps(admin);
        assert!(!referrals::caps_ready(), 19);
        assert!(treasury_multi::cap_available(referrals::scope_id()), 20);

        store::ensure_caps_initialized(admin);
        assert!(store::caps_ready(), 21);
        assert!(!treasury_multi::cap_available(store::scope_id()), 22);
        assert!(treasury_multi::cap_available(vip::scope_id()), 23);

        vip::ensure_caps_initialized(admin);
        assert!(vip::caps_ready(), 24);
        assert!(!treasury_multi::cap_available(vip::scope_id()), 25);

        store::release_caps(admin);
        assert!(!store::caps_ready(), 26);
        assert!(treasury_multi::cap_available(store::scope_id()), 27);
        assert!(!treasury_multi::cap_available(vip::scope_id()), 28);

        vip::release_caps(admin);
        assert!(!vip::caps_ready(), 29);
        assert!(treasury_multi::cap_available(vip::scope_id()), 30);
        let _ = vrf;
    }

    #[test(admin = @lottery, factory = @lottery_factory, vrf = @vrf_hub)]
    #[expected_failure(
        location = lottery_core::treasury_multi,
        abort_code = treasury_multi::E_CORE_CAP_BORROWED,
    )]
    fun cannot_double_borrow_same_scope(admin: &signer, factory: &signer, vrf: &signer) {
        test_utils::bootstrap_multi_treasury(admin, factory, vrf);
        jackpot::ensure_caps_initialized(admin);
        let _ = treasury_multi::borrow_multi_treasury_cap(admin, jackpot::scope_id());
        let _ = vrf;
    }
}
