#[test_only]
module lottery::metadata_tests {
    use std::vector;
    use lottery::metadata;
    use lottery::test_utils;
    use supra_framework::event;

    fun vector_equals(lhs: &vector<u8>, rhs: &vector<u8>): bool {
        if (vector::length(lhs) != vector::length(rhs)) {
            return false
        };
        let len = vector::length(lhs);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(lhs, i) != *vector::borrow(rhs, i)) {
                return false
            };
            i = i + 1;
        };
        true
    }

    #[test(lottery_admin = @lottery)]
    fun upsert_updates_metadata(lottery_admin: &signer) {
        metadata::init(lottery_admin);

        let initial = metadata::new_metadata(
            b"Daily Lottery",
            b"First description",
            b"https://img.example/lottery.png",
            b"https://example/lottery",
            b"https://example/lottery/rules",
        );
        metadata::upsert_metadata_struct(lottery_admin, 1, initial);

        let ids = metadata::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 0);
        assert!(*vector::borrow(&ids, 0) == 1, 1);

        let snapshot_events = event::emitted_events<metadata::MetadataSnapshotUpdatedEvent>();
        let snapshot_event_len = vector::length(&snapshot_events);
        assert!(snapshot_event_len >= 2, 8);
        let latest_snapshot_event = vector::borrow(&snapshot_events, snapshot_event_len - 1);
        let (previous_opt, current_snapshot) =
            metadata::metadata_snapshot_event_fields_for_test(latest_snapshot_event);
        let _previous_snapshot = test_utils::unwrap(&mut previous_opt);
        let admin_addr = metadata::metadata_snapshot_admin(&current_snapshot);
        assert!(admin_addr == @lottery, 9);
        let entry_count = metadata::metadata_snapshot_entry_count(&current_snapshot);
        assert!(entry_count == 1, 10);
        let entry = metadata::metadata_snapshot_entry_at(&current_snapshot, 0);
        let (entry_id, entry_metadata) = metadata::metadata_entry_fields_for_test(&entry);
        assert!(entry_id == 1, 11);
        let (title, description, _image_uri, _website_uri, _rules_uri) =
            metadata::metadata_fields_for_test(&entry_metadata);
        assert!(vector_equals(&title, &b"Daily Lottery"), 12);
        assert!(vector_equals(&description, &b"First description"), 13);

        let stored_opt = metadata::get_metadata(1);
        let stored = test_utils::unwrap(&mut stored_opt);
        let (title, description, _image_uri, _website_uri, _rules_uri) =
            metadata::metadata_fields_for_test(&stored);
        assert!(vector_equals(&title, &b"Daily Lottery"), 2);
        assert!(vector_equals(&description, &b"First description"), 3);

        let updated = metadata::new_metadata(
            b"Daily Lottery",
            b"Updated description",
            b"https://img.example/lottery-v2.png",
            b"https://example/lottery",
            b"https://example/lottery/rules",
        );
        metadata::upsert_metadata_struct(lottery_admin, 1, updated);

        let updated_ids = metadata::list_lottery_ids();
        assert!(vector::length(&updated_ids) == 1, 4);
        assert!(*vector::borrow(&updated_ids, 0) == 1, 5);

        let snapshot = metadata::get_metadata_snapshot();
        let snapshot_admin = metadata::metadata_snapshot_admin(&snapshot);
        assert!(snapshot_admin == @lottery, 14);
        let snapshot_entry = metadata::metadata_snapshot_entry_at(&snapshot, 0);
        let (snapshot_id, snapshot_metadata) =
            metadata::metadata_entry_fields_for_test(&snapshot_entry);
        assert!(snapshot_id == 1, 15);
        let (_snapshot_title, snapshot_description, snapshot_image_uri, _website2, _rules2) =
            metadata::metadata_fields_for_test(&snapshot_metadata);
        assert!(vector_equals(&snapshot_description, &b"Updated description"), 16);
        assert!(vector_equals(&snapshot_image_uri, &b"https://img.example/lottery-v2.png"), 17);

        let updated_opt = metadata::get_metadata(1);
        let updated_stored = test_utils::unwrap(&mut updated_opt);
        let (_title2, description2, image_uri2, _website2, _rules2) =
            metadata::metadata_fields_for_test(&updated_stored);
        assert!(vector_equals(&description2, &b"Updated description"), 6);
        assert!(vector_equals(&image_uri2, &b"https://img.example/lottery-v2.png"), 7);

        let snapshot_events_after_update = event::emitted_events<metadata::MetadataSnapshotUpdatedEvent>();
        let event_len_after_update = vector::length(&snapshot_events_after_update);
        let last_event = vector::borrow(&snapshot_events_after_update, event_len_after_update - 1);
        let (previous_snapshot_opt, current_snapshot_after_update) =
            metadata::metadata_snapshot_event_fields_for_test(last_event);
        let previous_snapshot = test_utils::unwrap(&mut previous_snapshot_opt);
        let previous_entry = metadata::metadata_snapshot_entry_at(&previous_snapshot, 0);
        let (_prev_id, previous_metadata) = metadata::metadata_entry_fields_for_test(&previous_entry);
        let (_prev_title, prev_description, _prev_image, _prev_website, _prev_rules) =
            metadata::metadata_fields_for_test(&previous_metadata);
        assert!(vector_equals(&prev_description, &b"First description"), 18);
        let updated_entry = metadata::metadata_snapshot_entry_at(&current_snapshot_after_update, 0);
        let (_updated_id, updated_metadata) =
            metadata::metadata_entry_fields_for_test(&updated_entry);
        let (_updated_title, updated_description, updated_image, _updated_website, _updated_rules) =
            metadata::metadata_fields_for_test(&updated_metadata);
        assert!(vector_equals(&updated_description, &b"Updated description"), 19);
        assert!(vector_equals(&updated_image, &b"https://img.example/lottery-v2.png"), 20);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(
        location = lottery::metadata,
        abort_code = metadata::E_METADATA_MISSING,
    )]
    fun cannot_remove_missing(lottery_admin: &signer) {
        metadata::init(lottery_admin);
        metadata::remove_metadata(lottery_admin, 42);
    }

    #[test(lottery_admin = @lottery, attacker = @player1)]
    #[expected_failure(
        location = lottery::metadata,
        abort_code = metadata::E_NOT_AUTHORIZED,
    )]
    fun non_admin_cannot_upsert(lottery_admin: &signer, attacker: &signer) {
        metadata::init(lottery_admin);
        let payload = metadata::new_metadata(
            b"Weekly Lottery",
            b"Description",
            b"https://img.example/weekly.png",
            b"https://example/weekly",
            b"https://example/weekly/rules",
        );
        metadata::upsert_metadata_struct(attacker, 7, payload);
    }
}
