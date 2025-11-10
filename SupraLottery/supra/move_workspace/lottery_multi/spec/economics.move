spec module lottery_multi::economics {
    use lottery_multi::economics::Accounting;

    spec struct Accounting {
        invariant total_allocated >= total_prize_paid;
        invariant total_operations_allocated >= total_operations_paid;
        invariant total_allocated >= total_prize_paid;
        invariant total_allocated >= total_prize_paid + total_operations_paid;
        invariant jackpot_allowance_token <= total_allocated + total_sales;
        invariant jackpot_allowance_token <= total_sales + total_allocated - total_prize_paid;
    }
}
