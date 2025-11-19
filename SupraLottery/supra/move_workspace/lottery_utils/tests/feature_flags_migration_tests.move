module lottery_utils::feature_flags_migration_tests {
    use std::vector;

    use lottery_utils::feature_flags;

    #[test(creator = @lottery)]
    public fun import_registry_overwrites_state(lottery: &signer) {
        feature_flags::init(lottery, false);
        feature_flags::set_mode(lottery, feature_flags::feature_purchase_id(), 1);

        let payload = feature_flags::LegacyFeatureRegistry {
            admin: @lottery,
            force_enable_devnet: true,
            features: vector[
                feature_flags::LegacyFeatureRecord { feature_id: 99, mode: 2 },
                feature_flags::LegacyFeatureRecord { feature_id: 5, mode: 1 },
            ],
        };
        feature_flags::import_existing_registry(lottery, payload);

        assert!(feature_flags::mode(99) == 2, 0);
        assert!(feature_flags::mode(5) == 1, 1);
        assert!(feature_flags::has_feature(99), 2);
        assert!(feature_flags::is_enabled(1234, false), 3);
    }

    #[test(creator = @lottery)]
    public fun batch_and_single_imports_share_indexes(lottery: &signer) {
        let features = vector[
            feature_flags::LegacyFeatureRecord { feature_id: 7, mode: 1 },
            feature_flags::LegacyFeatureRecord { feature_id: 8, mode: 2 },
        ];
        feature_flags::import_existing_features(lottery, features);

        assert!(feature_flags::mode(7) == 1, 10);
        assert!(feature_flags::mode(8) == 2, 11);

        feature_flags::import_existing_feature(
            lottery,
            feature_flags::LegacyFeatureRecord { feature_id: 8, mode: 1 },
        );
        assert!(feature_flags::mode(8) == 1, 12);

        feature_flags::import_existing_feature(
            lottery,
            feature_flags::LegacyFeatureRecord { feature_id: 9, mode: 2 },
        );
        assert!(feature_flags::mode(9) == 2, 13);
    }
}
