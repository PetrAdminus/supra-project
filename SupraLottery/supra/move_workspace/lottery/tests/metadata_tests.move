module lottery::metadata_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::metadata;
    use lottery::test_utils;

    fun vector_equals(lhs: &vector<u8>, rhs: &vector<u8>): bool {
        if (vector::length(lhs) != vector::length(rhs)) {
            return false;
        };
        let len = vector::length(lhs);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(lhs, i) != *vector::borrow(rhs, i)) {
                return false;
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
        metadata::upsert_metadata(lottery_admin, 1, initial);

        let ids = metadata::list_lottery_ids();
        assert!(vector::length(&ids) == 1, 0);
        assert!(*vector::borrow(&ids, 0) == 1, 1);

        let stored_opt = metadata::get_metadata_view(1);
        let (title, description, _, _, _) = test_utils::unwrap(stored_opt);
        assert!(vector_equals(&title, &b"Daily Lottery"), 2);
        assert!(vector_equals(&description, &b"First description"), 3);

        let updated = metadata::new_metadata(
            b"Daily Lottery",
            b"Updated description",
            b"https://img.example/lottery-v2.png",
            b"https://example/lottery",
            b"https://example/lottery/rules",
        );
        metadata::upsert_metadata(lottery_admin, 1, updated);

        let updated_ids = metadata::list_lottery_ids();
        assert!(vector::length(&updated_ids) == 1, 4);
        assert!(*vector::borrow(&updated_ids, 0) == 1, 5);

        let updated_opt = metadata::get_metadata_view(1);
        let (_, updated_description, updated_image_uri, _, _) = test_utils::unwrap(updated_opt);
        assert!(vector_equals(&updated_description, &b"Updated description"), 6);
        assert!(vector_equals(&updated_image_uri, &b"https://img.example/lottery-v2.png"), 7);
    }

    #[test(lottery_admin = @lottery)]
    #[expected_failure(abort_code = 4)]
    fun cannot_remove_missing(lottery_admin: &signer) {
        metadata::init(lottery_admin);
        metadata::remove_metadata(lottery_admin, 42);
    }

    #[test(lottery_admin = @lottery, attacker = @player1)]
    #[expected_failure(abort_code = 3)]
    fun non_admin_cannot_upsert(lottery_admin: &signer, attacker: &signer) {
        metadata::init(lottery_admin);
        let payload = metadata::new_metadata(
            b"Weekly Lottery",
            b"Description",
            b"https://img.example/weekly.png",
            b"https://example/weekly",
            b"https://example/weekly/rules",
        );
        metadata::upsert_metadata(attacker, 7, payload);
    }
}
