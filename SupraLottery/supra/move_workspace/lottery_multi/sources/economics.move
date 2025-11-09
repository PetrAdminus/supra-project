// sources/economics.move
module lottery_multi::economics {
    use lottery_multi::errors;

    pub const BASIS_POINTS_MAX: u64 = 10_000;

    pub struct SalesDistribution has copy, drop, store {
        pub prize_bps: u16,
        pub jackpot_bps: u16,
        pub operations_bps: u16,
        pub reserve_bps: u16,
    }

    pub struct Accounting has copy, drop, store {
        pub total_sales: u64,
        pub total_allocated: u64,
        pub total_prize_paid: u64,
        pub total_operations_paid: u64,
        pub jackpot_allowance_token: u64,
    }

    pub fun new_sales_distribution(
        prize_bps: u16,
        jackpot_bps: u16,
        operations_bps: u16,
        reserve_bps: u16,
    ): SalesDistribution {
        let distribution = SalesDistribution {
            prize_bps,
            jackpot_bps,
            operations_bps,
            reserve_bps,
        };
        assert_distribution(&distribution);
        distribution
    }

    pub fun assert_distribution(distribution: &SalesDistribution) {
        let sum = (distribution.prize_bps as u64)
            + (distribution.jackpot_bps as u64)
            + (distribution.operations_bps as u64)
            + (distribution.reserve_bps as u64);
        assert!(sum == BASIS_POINTS_MAX, errors::E_DISTRIBUTION_BPS_INVALID);
    }

    pub fun new_accounting(): Accounting {
        Accounting {
            total_sales: 0,
            total_allocated: 0,
            total_prize_paid: 0,
            total_operations_paid: 0,
            jackpot_allowance_token: 0,
        }
    }

    pub fun apply_sale(
        accounting: &mut Accounting,
        amount: u64,
        distribution: &SalesDistribution,
    ): (u64, u64, u64, u64) {
        assert_distribution(distribution);
        let (prize, jackpot, operations, reserve) = split_amount(amount, distribution);
        accounting.total_sales = accounting.total_sales + amount;
        accounting.total_allocated = accounting.total_allocated + prize + reserve;
        (prize, jackpot, operations, reserve)
    }

    pub fun record_prize_payout(accounting: &mut Accounting, amount: u64) {
        accounting.total_prize_paid = accounting.total_prize_paid + amount;
    }

    pub fun record_operations_payout(accounting: &mut Accounting, amount: u64) {
        accounting.total_operations_paid = accounting.total_operations_paid + amount;
    }

    pub fun set_initial_jackpot_allowance(accounting: &mut Accounting, allowance: u64) {
        accounting.jackpot_allowance_token = allowance;
    }

    pub fun consume_jackpot_allowance(accounting: &mut Accounting, amount: u64) {
        assert!(
            accounting.jackpot_allowance_token >= amount,
            errors::E_JACKPOT_ALLOWANCE_UNDERFLOW,
        );
        accounting.jackpot_allowance_token = accounting.jackpot_allowance_token - amount;
    }

    pub fun split_amount(
        amount: u64,
        distribution: &SalesDistribution,
    ): (u64, u64, u64, u64) {
        let amount_u128 = (amount as u128);
        let divisor = (BASIS_POINTS_MAX as u128);
        let prize_u128 = amount_u128 * (distribution.prize_bps as u128) / divisor;
        let jackpot_u128 = amount_u128 * (distribution.jackpot_bps as u128) / divisor;
        let operations_u128 = amount_u128 * (distribution.operations_bps as u128) / divisor;
        let reserve_u128 = amount_u128 * (distribution.reserve_bps as u128) / divisor;
        let computed = prize_u128 + jackpot_u128 + operations_u128 + reserve_u128;
        let remainder = amount_u128 - computed;
        let adjusted_prize = prize_u128 + remainder;
        (
            adjusted_prize as u64,
            jackpot_u128 as u64,
            operations_u128 as u64,
            reserve_u128 as u64,
        )
    }
}
