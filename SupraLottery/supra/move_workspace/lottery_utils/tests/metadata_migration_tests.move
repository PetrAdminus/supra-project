#[test_only]
module lottery_utils::metadata_migration_tests {
    use std::option;
    use std::vector;

    use lottery_utils::metadata;

    #[test(lottery_admin = @lottery)]
    fun import_existing_metadata_batch_populates_snapshot(lottery_admin: &signer) {
        metadata::init(lottery_admin);

        let entries = vector[
            metadata::LegacyMetadataImport {
                lottery_id: 1,
                metadata: metadata::new_metadata(
                    b"Alpha",
                    b"Alpha description",
                    b"https://alpha.example/image.png",
                    b"https://alpha.example",
                    b"https://alpha.example/rules",
                ),
            },
            metadata::LegacyMetadataImport {
                lottery_id: 7,
                metadata: metadata::new_metadata(
                    b"Bravo",
                    b"Bravo description",
                    b"https://bravo.example/image.png",
                    b"https://bravo.example",
                    b"https://bravo.example/rules",
                ),
            },
        ];
        metadata::import_existing_metadata_batch(lottery_admin, entries);

        assert!(metadata::has_metadata(1), 0);
        assert!(metadata::has_metadata(7), 1);

        let snapshot_opt = metadata::registry_snapshot();
        assert!(option::is_some(&snapshot_opt), 2);
        let snapshot = option::destroy_some(snapshot_opt);
        assert!(metadata::metadata_snapshot_admin(&snapshot) == @lottery, 3);
        assert!(metadata::metadata_snapshot_entry_count(&snapshot) == 2, 4);

        let entry_a = metadata::metadata_snapshot_entry_at(&snapshot, 0);
        let (lottery_a, metadata_a) = metadata::metadata_entry_fields_for_test(&entry_a);
        assert!(lottery_a == 1, 5);
        let (title_a, _, _, _, _) = metadata::metadata_fields_for_test(&metadata_a);
        assert_has_prefix(&title_a, b"Alpha", 6);

        let entry_b = metadata::metadata_snapshot_entry_at(&snapshot, 1);
        let (lottery_b, metadata_b) = metadata::metadata_entry_fields_for_test(&entry_b);
        assert!(lottery_b == 7, 7);
        let (title_b, _, _, _, _) = metadata::metadata_fields_for_test(&metadata_b);
        assert_has_prefix(&title_b, b"Bravo", 8);
    }

    #[test(lottery_admin = @lottery)]
    fun import_existing_metadata_updates_entries(lottery_admin: &signer) {
        metadata::init(lottery_admin);
        let initial = metadata::LegacyMetadataImport {
            lottery_id: 99,
            metadata: metadata::new_metadata(
                b"First",
                b"First description",
                b"https://first.example/image.png",
                b"https://first.example",
                b"https://first.example/rules",
            ),
        };
        metadata::import_existing_metadata(lottery_admin, initial);
        assert!(vector::length(&metadata::list_lottery_ids()) == 1, 10);

        let updated = metadata::LegacyMetadataImport {
            lottery_id: 99,
            metadata: metadata::new_metadata(
                b"Second",
                b"Second description",
                b"https://second.example/image.png",
                b"https://second.example",
                b"https://second.example/rules",
            ),
        };
        metadata::import_existing_metadata(lottery_admin, updated);

        let metadata_opt = metadata::get_metadata(99);
        assert!(option::is_some(&metadata_opt), 11);
        let latest = option::destroy_some(metadata_opt);
        let (title, _, _, _, _) = metadata::metadata_fields_for_test(&latest);
        assert_has_prefix(&title, b"Second", 12);
    }

    fun assert_has_prefix(value: &vector<u8>, prefix: &vector<u8>, code: u64) {
        let prefix_len = vector::length(prefix);
        assert!(vector::length(value) >= prefix_len, code);
        assert_has_prefix_internal(value, prefix, 0, prefix_len, code);
    }

    fun assert_has_prefix_internal(
        value: &vector<u8>,
        prefix: &vector<u8>,
        index: u64,
        len: u64,
        code: u64,
    ) {
        if (index >= len) {
            return;
        };
        let actual = *vector::borrow(value, index);
        let expected = *vector::borrow(prefix, index);
        assert!(actual == expected, code);
        assert_has_prefix_internal(value, prefix, index + 1, len, code);
    }
}
