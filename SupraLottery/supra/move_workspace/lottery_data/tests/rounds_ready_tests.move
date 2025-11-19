#[test_only]
module lottery_data::rounds_ready_tests {
    use std::option;
    use std::vector;

    use lottery_data::rounds;

    #[test(lottery_admin = @lottery)]
    fun rounds_ready_flow(lottery_admin: &signer) {
        assert!(!rounds::ready(), 0);

        rounds::init_registry(lottery_admin);
        rounds::init_history_queue(lottery_admin);
        rounds::init_purchase_queue(lottery_admin);
        rounds::init_control(lottery_admin);

        assert!(rounds::ready(), 1);

        let legacy_round = rounds::LegacyRoundRecord {
            lottery_id: 1,
            tickets: vector::empty<address>(),
            draw_scheduled: false,
            next_ticket_id: 0,
            pending_request: option::none<u64>(),
        };
        rounds::import_existing_round(lottery_admin, legacy_round);
        assert!(rounds::ready(), 2);

        let registry = rounds::borrow_registry_mut(@lottery);
        let removed_id = vector::pop_back(&mut registry.lottery_ids);
        assert!(!rounds::ready(), 3);
        vector::push_back(&mut registry.lottery_ids, removed_id);
        assert!(rounds::ready(), 4);

        let mut history_records = vector::empty<rounds::PendingHistoryRecord>();
        vector::push_back(
            &mut history_records,
            rounds::PendingHistoryRecord {
                lottery_id: 999,
                request_id: 1,
                winner: @lottery,
                ticket_index: 0,
                prize_amount: 0,
                random_bytes: b"rand",
                payload: b"payload",
            },
        );
        rounds::import_pending_history_records(lottery_admin, history_records);
        assert!(!rounds::ready(), 5);

        let mut valid_history = vector::empty<rounds::PendingHistoryRecord>();
        vector::push_back(
            &mut valid_history,
            rounds::PendingHistoryRecord {
                lottery_id: 1,
                request_id: 10,
                winner: @lottery,
                ticket_index: 0,
                prize_amount: 0,
                random_bytes: b"rand",
                payload: b"payload",
            },
        );
        rounds::import_pending_history_records(lottery_admin, valid_history);
        assert!(rounds::ready(), 6);

        let mut purchase_records = vector::empty<rounds::PendingPurchaseRecord>();
        vector::push_back(
            &mut purchase_records,
            rounds::PendingPurchaseRecord {
                lottery_id: 1,
                buyer: @lottery,
                ticket_count: 0,
                paid_amount: 10,
            },
        );
        rounds::import_pending_purchase_records(lottery_admin, purchase_records);
        assert!(!rounds::ready(), 7);

        let mut bad_purchase_lottery = vector::empty<rounds::PendingPurchaseRecord>();
        vector::push_back(
            &mut bad_purchase_lottery,
            rounds::PendingPurchaseRecord {
                lottery_id: 33,
                buyer: @lottery,
                ticket_count: 1,
                paid_amount: 10,
            },
        );
        rounds::import_pending_purchase_records(lottery_admin, bad_purchase_lottery);
        assert!(!rounds::ready(), 8);

        let mut valid_purchase = vector::empty<rounds::PendingPurchaseRecord>();
        vector::push_back(
            &mut valid_purchase,
            rounds::PendingPurchaseRecord {
                lottery_id: 1,
                buyer: @lottery,
                ticket_count: 1,
                paid_amount: 10,
            },
        );
        rounds::import_pending_purchase_records(lottery_admin, valid_purchase);
        assert!(rounds::ready(), 9);
    }
}
