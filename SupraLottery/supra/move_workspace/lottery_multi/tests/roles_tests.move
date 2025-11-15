module lottery_multi::roles_tests {
    use std::option;
    use std::vector;
    use lottery_multi::errors;
    use lottery_multi::roles;
    use lottery_multi::tags;

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PAYOUT_BATCH_COOLDOWN)]
    fun payout_batch_cap_enforces_cooldown() {
        let cap = roles::new_payout_batch_cap(@0x42, 32, 1_000, 60, 1);
        roles::consume_payout_batch(&mut cap, 10, 20, 100, 1);
        roles::consume_payout_batch(&mut cap, 5, 10, 120, 2);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PAYOUT_OPERATIONS_BUDGET)]
    fun payout_batch_cap_tracks_operations_budget() {
        let cap = roles::new_payout_batch_cap(@0x42, 0, 25, 0, 1);
        roles::consume_payout_batch(&mut cap, 4, 10, 100, 1);
        roles::consume_payout_batch(&mut cap, 3, 16, 180, 2);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_COOLDOWN)]
    fun partner_cap_respects_cooldown() {
        let cap = roles::new_partner_payout_cap(@0x77, 100, 90, 1, 0);
        roles::consume_partner_payout(&mut cap, 40, 500, 1);
        roles::consume_partner_payout(&mut cap, 10, 560, 2);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_BUDGET_EXCEEDED)]
    fun partner_cap_limits_budget() {
        let cap = roles::new_partner_payout_cap(@0x77, 50, 0, 1, 0);
        roles::consume_partner_payout(&mut cap, 30, 100, 1);
        roles::consume_partner_payout(&mut cap, 25, 200, 2);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_NONCE)]
    fun partner_cap_requires_stride() {
        let _cap = roles::new_partner_payout_cap(@0x77, 10, 0, 0, 0);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PAYOUT_BATCH_NONCE)]
    fun payout_batch_cap_requires_stride() {
        let _cap = roles::new_payout_batch_cap(@0x77, 10, 100, 0, 0);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_TAG_BUDGET_EXCEEDED)]
    fun tag_budget_limits_active_bits() {
        let mask = (1u64 << 17) - 1;
        tags::assert_tag_budget(mask);
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_TAG_UNKNOWN_BIT)]
    fun partner_cap_rejects_unknown_tags() {
        let _cap = roles::new_partner_cap(
            vector::empty<u8>(),
            vector::empty<vector<u8>>(),
            vector::empty<u8>(),
            1u64 << 20,
            1,
            0,
            0,
        );
    }

    // // #[test]
    // // #[expected_failure(abort_code = errors::E_PARTNER_PAYOUT_EXPIRED)]
    fun partner_cap_blocks_after_expiry() {
        let cap = roles::new_partner_payout_cap(@0x77, 10, 0, 1, 50);
        roles::consume_partner_payout(&mut cap, 1, 60, 1);
    }

    // #[test(account = @lottery_multi)]
    fun admin_can_list_and_track_partner_caps(account: &signer) {
        roles::init_roles(account);
        roles::upsert_partner_payout_cap_admin(account, @0x77, 100, 0, 1, 0);
        let (_, _, partner_granted, partner_revoked, _, _) = roles::event_counters();
        assert!(partner_granted == 1, 0);
        assert!(partner_revoked == 0, 1);
        let caps = roles::list_partner_caps();
        assert!(vector::length(&caps) == 1, 2);
        let info = vector::borrow(&caps, 0);
        assert!(roles::partner_cap_info_partner(info) == @0x77, 3);
        assert!(roles::partner_cap_info_max_total(info) == 100, 4);
        roles::revoke_partner_payout_cap_admin(account, @0x77);
        let (_, _, _, partner_revoked_after, _, _) = roles::event_counters();
        assert!(partner_revoked_after == 1, 5);
        let caps_after = roles::list_partner_caps();
        assert!(vector::length(&caps_after) == 0, 6);
    }

    // #[test(account = @lottery_multi)]
    fun cleanup_expired_removes_caps(account: &signer) {
        roles::init_roles(account);
        roles::upsert_partner_payout_cap_admin(account, @0x77, 100, 0, 1, 30);
        roles::grant_premium_access_admin(account, @0x99, 25, false, option::none<address>());
        roles::cleanup_expired_admin(account, 60);
        let partner_caps = roles::list_partner_caps();
        assert!(vector::length(&partner_caps) == 0, 0);
        let premium_caps = roles::list_premium_caps();
        assert!(vector::length(&premium_caps) == 0, 1);
        let (_, _, _, partner_revoked, _, premium_revoked) = roles::event_counters();
        assert!(partner_revoked == 1, 2);
        assert!(premium_revoked == 1, 3);
    }

    // #[test(account = @lottery_multi)]
    fun premium_grant_and_revoke_updates_events(account: &signer) {
        roles::init_roles(account);
        roles::grant_premium_access_admin(account, @0x88, 100, true, option::some(@0x55));
        let premium_caps = roles::list_premium_caps();
        assert!(vector::length(&premium_caps) == 1, 0);
        let info = vector::borrow(&premium_caps, 0);
        assert!(roles::premium_cap_info_holder(info) == @0x88, 1);
        assert!(roles::premium_cap_info_has_referrer(info), 2);
        roles::revoke_premium_access_admin(account, @0x88);
        let premium_caps_after = roles::list_premium_caps();
        assert!(vector::length(&premium_caps_after) == 0, 3);
        let (_, _, _, _, premium_granted, premium_revoked) = roles::event_counters();
        assert!(premium_granted == 1, 4);
        assert!(premium_revoked == 1, 5);
    }
}








