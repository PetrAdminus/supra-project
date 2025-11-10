module lottery_multi::economics_tests {
    use lottery_multi::economics;
    use lottery_multi::errors;

    #[test]
    fun payout_respects_allocation() {
        let distribution = economics::new_sales_distribution(7000, 1500, 1000, 500);
        let mut accounting = economics::new_accounting();
        let (prize, _jackpot, operations, _reserve) = economics::apply_sale(&mut accounting, 1_000_000, &distribution);
        economics::record_prize_payout(&mut accounting, prize);
        economics::record_operations_payout(&mut accounting, operations);
    }

    #[test]
    #[expected_failure(abort_code = errors::E_PAYOUT_ALLOC_EXCEEDED)]
    fun prize_allocation_guard() {
        let distribution = economics::new_sales_distribution(7000, 1500, 1000, 500);
        let mut accounting = economics::new_accounting();
        let (prize, _jackpot, _operations, _reserve) = economics::apply_sale(&mut accounting, 1_000_000, &distribution);
        economics::record_prize_payout(&mut accounting, prize + 1);
    }

    #[test]
    #[expected_failure(abort_code = errors::E_OPERATIONS_ALLOC_EXCEEDED)]
    fun operations_allocation_guard() {
        let distribution = economics::new_sales_distribution(7000, 1500, 1000, 500);
        let mut accounting = economics::new_accounting();
        let (_prize, _jackpot, operations, _reserve) = economics::apply_sale(&mut accounting, 1_000_000, &distribution);
        economics::record_operations_payout(&mut accounting, operations + 1);
    }
}
