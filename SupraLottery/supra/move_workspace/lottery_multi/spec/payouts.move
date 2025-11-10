spec module lottery_multi::payouts {
    use std::table;

    use lottery_multi::economics;
    use lottery_multi::payouts::{PayoutLedger, WinnerState};
    use lottery_multi::sales;

    spec struct WinnerState {
        invariant total_assigned <= total_required;
        invariant payout_round >= 0;
        invariant total_required >= 0;
        invariant len(snapshot_hash) == 0 || len(snapshot_hash) == 32;
        invariant len(payload_hash) == 0 || len(payload_hash) == 32;
        invariant len(winners_batch_hash) == 0 || len(winners_batch_hash) == 32;
        invariant next_winner_batch_no >= payout_round;
    }

    spec fun winner_state(addr: address, lottery_id: u64): WinnerState {
        table::borrow(&global<PayoutLedger>(addr).states, lottery_id)
    }

    spec fun accounting(lottery_id: u64): economics::Accounting {
        sales::accounting_snapshot(lottery_id)
    }

    spec record_payout_batch_admin {
        let old_state = old(winner_state(@lottery_multi, lottery_id));
        let new_state = winner_state(@lottery_multi, lottery_id);
        let old_accounting = old(accounting(lottery_id));
        let new_accounting = accounting(lottery_id);
        ensures new_state.payout_round == old_state.payout_round + 1;
        ensures new_state.payout_round > old_state.payout_round;
        ensures new_accounting.total_prize_paid
            == old_accounting.total_prize_paid + prize_paid;
        ensures new_accounting.total_operations_paid
            == old_accounting.total_operations_paid + operations_paid;
        ensures new_accounting.total_allocated == old_accounting.total_allocated;
        ensures new_accounting.total_operations_allocated
            == old_accounting.total_operations_allocated;
        ensures new_accounting.total_prize_paid <= new_accounting.total_allocated;
        ensures new_accounting.total_operations_paid
            <= new_accounting.total_operations_allocated;
    }

    spec record_partner_payout_admin {
        let old_state = old(winner_state(@lottery_multi, lottery_id));
        let new_state = winner_state(@lottery_multi, lottery_id);
        let old_accounting = old(accounting(lottery_id));
        let new_accounting = accounting(lottery_id);
        ensures new_state.payout_round == old_state.payout_round;
        ensures new_accounting.total_operations_paid
            == old_accounting.total_operations_paid + amount;
        ensures new_accounting.total_prize_paid == old_accounting.total_prize_paid;
        ensures new_accounting.total_operations_paid
            <= new_accounting.total_operations_allocated;
    }
}
