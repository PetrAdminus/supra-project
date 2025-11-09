spec module lottery_multi::payouts {
    use lottery_multi::payouts::WinnerState;

    spec struct WinnerState {
        invariant total_assigned <= total_required;
        invariant payout_round >= 0;
        invariant total_required >= 0;
    }
}
