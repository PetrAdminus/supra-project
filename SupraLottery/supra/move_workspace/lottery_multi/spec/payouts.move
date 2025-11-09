spec module lottery_multi::payouts {
    use lottery_multi::payouts::WinnerState;

    spec struct WinnerState {
        invariant total_assigned <= total_required;
        invariant payout_round >= 0;
        invariant total_required >= 0;
        invariant len(snapshot_hash) == 0 || len(snapshot_hash) == 32;
        invariant len(payload_hash) == 0 || len(payload_hash) == 32;
        invariant len(winners_batch_hash) == 0 || len(winners_batch_hash) == 32;
        invariant next_winner_batch_no >= payout_round;
    }
}
