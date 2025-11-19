#[test_only]
module lottery_data::access_migration_tests {
    use std::option;
    use std::vector;

    use lottery_data::access;

    #[test(lottery_admin = @lottery)]
    fun import_existing_role_store_restores_caps(lottery_admin: &signer) {
        access::init_store(lottery_admin);

        let payout_cap = access::LegacyPayoutBatchCap {
            holder: @0xF00D,
            max_batch_size: 50,
            operations_budget_total: 1_000,
            operations_budget_used: 125,
            cooldown_secs: 3600,
            last_batch_at: 111,
            last_nonce: 900,
            nonce_stride: 5,
        };

        let mut partner_caps = vector::empty<access::LegacyPartnerPayoutCap>();
        vector::push_back(
            &mut partner_caps,
            access::LegacyPartnerPayoutCap {
                partner: @0x111,
                max_total_payout: 10_000,
                remaining_payout: 7_000,
                payout_cooldown_secs: 120,
                last_payout_at: 80,
                next_nonce: 3,
                nonce_stride: 7,
                expires_at: 123_456,
            },
        );
        vector::push_back(
            &mut partner_caps,
            access::LegacyPartnerPayoutCap {
                partner: @0x222,
                max_total_payout: 5_000,
                remaining_payout: 1_000,
                payout_cooldown_secs: 60,
                last_payout_at: 42,
                next_nonce: 9,
                nonce_stride: 2,
                expires_at: 654_321,
            },
        );

        let mut premium_caps = vector::empty<access::LegacyPremiumAccessCap>();
        vector::push_back(
            &mut premium_caps,
            access::LegacyPremiumAccessCap {
                holder: @0xAAA,
                expires_at: 555,
                auto_renew: true,
                referrer: option::some(@0x123),
            },
        );
        vector::push_back(
            &mut premium_caps,
            access::LegacyPremiumAccessCap {
                holder: @0xBBB,
                expires_at: 777,
                auto_renew: false,
                referrer: option::none<address>(),
            },
        );

        let state = access::LegacyRoleStore {
            admin: @lottery,
            payout_batch: option::some(payout_cap),
            partner_caps,
            premium_caps,
        };

        access::import_existing_role_store(lottery_admin, state);

        let snapshot_opt = access::snapshot();
        assert!(option::is_some(&snapshot_opt), 0);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(snapshot.admin == @lottery, 1);

        let payout_opt = snapshot.payout_batch;
        assert!(option::is_some(&payout_opt), 2);
        let payout = option::destroy_some(payout_opt);
        assert!(payout.holder == @0xF00D, 3);
        assert!(payout.max_batch_size == 50, 4);
        assert!(payout.operations_budget_used == 125, 5);

        let partners = snapshot.partner_caps;
        assert!(vector::length(&partners) == 2, 6);
        let first_partner = *vector::borrow(&partners, 0);
        assert!(first_partner.partner == @0x222, 7);
        let second_partner = *vector::borrow(&partners, 1);
        assert!(second_partner.partner == @0x111, 8);

        let premium = snapshot.premium_caps;
        assert!(vector::length(&premium) == 2, 9);
        let first_premium = *vector::borrow(&premium, 0);
        assert!(first_premium.holder == @0xBBB, 10);
        let second_premium = *vector::borrow(&premium, 1);
        assert!(second_premium.holder == @0xAAA, 11);
    }

    #[test(lottery_admin = @lottery)]
    fun incremental_imports_keep_indexes_deduplicated(lottery_admin: &signer) {
        access::init_store(lottery_admin);

        let mut initial_partner = vector::empty<access::LegacyPartnerPayoutCap>();
        vector::push_back(
            &mut initial_partner,
            access::LegacyPartnerPayoutCap {
                partner: @0x10,
                max_total_payout: 100,
                remaining_payout: 75,
                payout_cooldown_secs: 10,
                last_payout_at: 1,
                next_nonce: 2,
                nonce_stride: 1,
                expires_at: 20,
            },
        );
        access::import_partner_caps(lottery_admin, initial_partner);

        let mut extra_partner = vector::empty<access::LegacyPartnerPayoutCap>();
        vector::push_back(
            &mut extra_partner,
            access::LegacyPartnerPayoutCap {
                partner: @0x20,
                max_total_payout: 500,
                remaining_payout: 400,
                payout_cooldown_secs: 25,
                last_payout_at: 2,
                next_nonce: 3,
                nonce_stride: 4,
                expires_at: 30,
            },
        );
        access::import_partner_caps(lottery_admin, extra_partner);

        access::remove_partner_cap(lottery_admin, @0x10);
        access::import_partner_cap(
            lottery_admin,
            access::LegacyPartnerPayoutCap {
                partner: @0x10,
                max_total_payout: 200,
                remaining_payout: 150,
                payout_cooldown_secs: 45,
                last_payout_at: 4,
                next_nonce: 5,
                nonce_stride: 6,
                expires_at: 60,
            },
        );

        let mut premium_caps = vector::empty<access::LegacyPremiumAccessCap>();
        vector::push_back(
            &mut premium_caps,
            access::LegacyPremiumAccessCap {
                holder: @0xE1,
                expires_at: 111,
                auto_renew: false,
                referrer: option::none<address>(),
            },
        );
        vector::push_back(
            &mut premium_caps,
            access::LegacyPremiumAccessCap {
                holder: @0xE2,
                expires_at: 222,
                auto_renew: true,
                referrer: option::some(@0xCAFE),
            },
        );
        access::import_premium_caps(lottery_admin, premium_caps);
        access::remove_premium_cap(lottery_admin, @0xE2);
        access::import_premium_cap(
            lottery_admin,
            access::LegacyPremiumAccessCap {
                holder: @0xE2,
                expires_at: 333,
                auto_renew: true,
                referrer: option::some(@0xBEEF),
            },
        );

        let partner_caps = access::partner_caps();
        assert!(vector::length(&partner_caps) == 2, 12);
        let partner_first = *vector::borrow(&partner_caps, 0);
        assert!(partner_first.partner == @0x20, 13);
        let partner_second = *vector::borrow(&partner_caps, 1);
        assert!(partner_second.partner == @0x10, 14);
        assert!(partner_second.remaining_payout == 150, 15);

        let premium = access::premium_caps();
        assert!(vector::length(&premium) == 2, 16);
        let premium_second = *vector::borrow(&premium, 1);
        assert!(premium_second.holder == @0xE1, 17);
        let premium_first = *vector::borrow(&premium, 0);
        assert!(premium_first.holder == @0xE2, 18);
        assert!(premium_first.expires_at == 333, 19);
    }
}
