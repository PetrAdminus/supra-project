#[test_only]
module lottery_data::rounds_migration_tests {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::rounds;

    #[test(
        lottery_admin = @lottery,
        first_buyer = @first_buyer,
        second_buyer = @second_buyer,
        third_buyer = @third_buyer
    )]
    fun import_rounds_and_queues(
        lottery_admin: &signer,
        first_buyer: &signer,
        second_buyer: &signer,
        third_buyer: &signer,
    ) {
        rounds::init_registry(lottery_admin);
        rounds::init_history_queue(lottery_admin);
        rounds::init_purchase_queue(lottery_admin);

        let mut records = vector::empty<rounds::LegacyRoundRecord>();
        let mut first_round_tickets = vector::empty<address>();
        vector::push_back(&mut first_round_tickets, signer::address_of(first_buyer));
        vector::push_back(&mut first_round_tickets, signer::address_of(second_buyer));
        vector::push_back(
            &mut records,
            rounds::LegacyRoundRecord {
                lottery_id: 1,
                tickets: first_round_tickets,
                draw_scheduled: true,
                next_ticket_id: 3,
                pending_request: option::some(99),
            },
        );

        let mut second_round_tickets = vector::empty<address>();
        vector::push_back(&mut second_round_tickets, signer::address_of(third_buyer));
        vector::push_back(
            &mut records,
            rounds::LegacyRoundRecord {
                lottery_id: 2,
                tickets: second_round_tickets,
                draw_scheduled: false,
                next_ticket_id: 2,
                pending_request: option::none<u64>(),
            },
        );

        rounds::import_existing_rounds(lottery_admin, records);

        let registry = rounds::borrow_registry(@lottery);
        let round_one = rounds::round(registry, 1);
        assert!(vector::length(&round_one.tickets) == 2, 0);
        assert!(round_one.draw_scheduled, 1);
        assert!(option::is_some(&round_one.pending_request), 2);
        assert!(*option::borrow(&round_one.pending_request) == 99, 3);
        assert!(round_one.next_ticket_id == 3, 4);

        let round_two = rounds::round(registry, 2);
        assert!(vector::length(&round_two.tickets) == 1, 5);
        assert!(!round_two.draw_scheduled, 6);
        assert!(!option::is_some(&round_two.pending_request), 7);

        let mut updated_tickets = vector::empty<address>();
        vector::push_back(&mut updated_tickets, signer::address_of(second_buyer));
        vector::push_back(&mut updated_tickets, signer::address_of(third_buyer));
        rounds::import_existing_round(
            lottery_admin,
            rounds::LegacyRoundRecord {
                lottery_id: 1,
                tickets: updated_tickets,
                draw_scheduled: false,
                next_ticket_id: 5,
                pending_request: option::none<u64>(),
            },
        );

        let registry_after_update = rounds::borrow_registry(@lottery);
        let updated_round_one = rounds::round(registry_after_update, 1);
        assert!(vector::length(&updated_round_one.tickets) == 2, 8);
        assert!(!updated_round_one.draw_scheduled, 9);
        assert!(!option::is_some(&updated_round_one.pending_request), 10);
        assert!(updated_round_one.next_ticket_id == 5, 11);

        let mut history_records = vector::empty<rounds::PendingHistoryRecord>();
        vector::push_back(
            &mut history_records,
            rounds::PendingHistoryRecord {
                lottery_id: 1,
                request_id: 7,
                winner: signer::address_of(second_buyer),
                ticket_index: 1,
                prize_amount: 500,
                random_bytes: b"random_bytes",
                payload: b"history_payload",
            },
        );
        rounds::import_pending_history_records(lottery_admin, history_records);
        assert!(rounds::history_queue_length() == 1, 12);
        let history_snapshot = rounds::pending_history_snapshot();
        assert!(option::is_some(&history_snapshot), 13);

        let mut replacement_history = vector::empty<rounds::PendingHistoryRecord>();
        vector::push_back(
            &mut replacement_history,
            rounds::PendingHistoryRecord {
                lottery_id: 1,
                request_id: 8,
                winner: signer::address_of(first_buyer),
                ticket_index: 0,
                prize_amount: 250,
                random_bytes: b"rand2",
                payload: b"payload2",
            },
        );
        vector::push_back(
            &mut replacement_history,
            rounds::PendingHistoryRecord {
                lottery_id: 2,
                request_id: 9,
                winner: signer::address_of(third_buyer),
                ticket_index: 0,
                prize_amount: 100,
                random_bytes: b"rand3",
                payload: b"payload3",
            },
        );
        rounds::import_pending_history_records(lottery_admin, replacement_history);
        assert!(rounds::history_queue_length() == 2, 14);

        let mut purchase_records = vector::empty<rounds::PendingPurchaseRecord>();
        vector::push_back(
            &mut purchase_records,
            rounds::PendingPurchaseRecord {
                lottery_id: 1,
                buyer: signer::address_of(first_buyer),
                ticket_count: 3,
                paid_amount: 1500,
            },
        );
        rounds::import_pending_purchase_records(lottery_admin, purchase_records);
        assert!(rounds::purchase_queue_length() == 1, 15);
        let purchase_snapshot = rounds::pending_purchase_snapshot();
        assert!(option::is_some(&purchase_snapshot), 16);

        let mut replacement_purchases = vector::empty<rounds::PendingPurchaseRecord>();
        vector::push_back(
            &mut replacement_purchases,
            rounds::PendingPurchaseRecord {
                lottery_id: 1,
                buyer: signer::address_of(second_buyer),
                ticket_count: 1,
                paid_amount: 500,
            },
        );
        vector::push_back(
            &mut replacement_purchases,
            rounds::PendingPurchaseRecord {
                lottery_id: 2,
                buyer: signer::address_of(third_buyer),
                ticket_count: 2,
                paid_amount: 1000,
            },
        );
        rounds::import_pending_purchase_records(lottery_admin, replacement_purchases);
        assert!(rounds::purchase_queue_length() == 2, 17);
    }
}
