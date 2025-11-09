spec module lottery_multi::economics {
    use lottery_multi::economics::Accounting;

    spec struct Accounting {
        invariant total_allocated >= total_prize_paid;
        invariant total_allocated >= total_operations_paid;
        invariant jackpot_allowance_token <= total_allocated + total_sales;
    }
}
