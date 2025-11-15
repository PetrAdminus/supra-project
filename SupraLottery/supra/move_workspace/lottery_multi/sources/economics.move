// sources/economics.move
module lottery_multi::economics {
    use lottery_multi::errors;
    use lottery_multi::math;

    const BASIS_POINTS_MAX: u16 = 10_000;

    struct SalesDistribution has copy, drop, store {
        prize_bps: u16,
        jackpot_bps: u16,
        operations_bps: u16,
        reserve_bps: u16,
    }

    struct Accounting has copy, drop, store {
        total_sales: u64,
        total_allocated: u64,
        total_prize_paid: u64,
        total_operations_paid: u64,
        total_operations_allocated: u64,
        jackpot_allowance_token: u64,
    }

    public fun new_sales_distribution(
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

    public fun assert_distribution(distribution: &SalesDistribution) {
        let sum = math::widen_u64_from_u16(distribution.prize_bps)
            + math::widen_u64_from_u16(distribution.jackpot_bps)
            + math::widen_u64_from_u16(distribution.operations_bps)
            + math::widen_u64_from_u16(distribution.reserve_bps);
        assert!(
            sum == math::widen_u64_from_u16(BASIS_POINTS_MAX),
            errors::err_distribution_bps_invalid(),
        );
    }

    public fun new_accounting(): Accounting {
        Accounting {
            total_sales: 0,
            total_allocated: 0,
            total_prize_paid: 0,
            total_operations_paid: 0,
            total_operations_allocated: 0,
            jackpot_allowance_token: 0,
        }
    }

    public fun apply_sale(
        accounting: &mut Accounting,
        amount: u64,
        distribution: &SalesDistribution,
    ): (u64, u64, u64, u64) {
        assert_distribution(distribution);
        let (prize, jackpot, operations, reserve) = split_amount(amount, distribution);
        accounting.total_sales = accounting.total_sales + amount;
        accounting.total_allocated = accounting.total_allocated + prize + reserve;
        accounting.total_operations_allocated = accounting.total_operations_allocated + operations;
        (prize, jackpot, operations, reserve)
    }

    public fun record_prize_payout(accounting: &mut Accounting, amount: u64) {
        assert!(
            accounting.total_prize_paid + amount <= accounting.total_allocated,
            errors::err_payout_alloc_exceeded(),
        );
        accounting.total_prize_paid = accounting.total_prize_paid + amount;
    }

    public fun record_operations_payout(accounting: &mut Accounting, amount: u64) {
        assert!(
            accounting.total_operations_paid + amount <= accounting.total_operations_allocated,
            errors::err_operations_alloc_exceeded(),
        );
        accounting.total_operations_paid = accounting.total_operations_paid + amount;
    }

    public fun set_initial_jackpot_allowance(accounting: &mut Accounting, allowance: u64) {
        if (accounting.jackpot_allowance_token == 0) {
            accounting.jackpot_allowance_token = allowance;
            return
        };
        assert!(
            allowance <= accounting.jackpot_allowance_token,
            errors::err_jackpot_allowance_increase(),
        );
        accounting.jackpot_allowance_token = allowance;
    }

    public fun consume_jackpot_allowance(accounting: &mut Accounting, amount: u64) {
        assert!(
            accounting.jackpot_allowance_token >= amount,
            errors::err_jackpot_allowance_underflow(),
        );
        accounting.jackpot_allowance_token = accounting.jackpot_allowance_token - amount;
    }

    public fun split_amount(
        amount: u64,
        distribution: &SalesDistribution,
    ): (u64, u64, u64, u64) {
        let amount_u128 = math::widen_u128_from_u64(amount);
        let divisor = math::widen_u128_from_u16(BASIS_POINTS_MAX);
        let prize_u128 =
            amount_u128 * math::widen_u128_from_u16(distribution.prize_bps) / divisor;
        let jackpot_u128 =
            amount_u128 * math::widen_u128_from_u16(distribution.jackpot_bps) / divisor;
        let operations_u128 =
            amount_u128 * math::widen_u128_from_u16(distribution.operations_bps) / divisor;
        let reserve_u128 =
            amount_u128 * math::widen_u128_from_u16(distribution.reserve_bps) / divisor;
        let computed = prize_u128 + jackpot_u128 + operations_u128 + reserve_u128;
        let remainder = amount_u128 - computed;
        let adjusted_prize =
            math::checked_u64_from_u128(prize_u128 + remainder, errors::err_amount_overflow());
        let jackpot = math::checked_u64_from_u128(jackpot_u128, errors::err_amount_overflow());
        let operations =
            math::checked_u64_from_u128(operations_u128, errors::err_amount_overflow());
        let reserve = math::checked_u64_from_u128(reserve_u128, errors::err_amount_overflow());
        (adjusted_prize, jackpot, operations, reserve)
    }

    public fun clone_sales_distribution(distribution: &SalesDistribution): SalesDistribution {
        SalesDistribution {
            prize_bps: distribution.prize_bps,
            jackpot_bps: distribution.jackpot_bps,
            operations_bps: distribution.operations_bps,
            reserve_bps: distribution.reserve_bps,
        }
    }

    public fun clone_accounting(accounting: &Accounting): Accounting {
        Accounting {
            total_sales: accounting.total_sales,
            total_allocated: accounting.total_allocated,
            total_prize_paid: accounting.total_prize_paid,
            total_operations_paid: accounting.total_operations_paid,
            total_operations_allocated: accounting.total_operations_allocated,
            jackpot_allowance_token: accounting.jackpot_allowance_token,
        }
    }

    //
    // Accounting helpers (Move v1 compatibility)
    //

    public fun accounting_total_sales(accounting: &Accounting): u64 {
        accounting.total_sales
    }

    public fun accounting_total_allocated(accounting: &Accounting): u64 {
        accounting.total_allocated
    }

    public fun accounting_total_prize_paid(accounting: &Accounting): u64 {
        accounting.total_prize_paid
    }

    public fun accounting_total_operations_paid(accounting: &Accounting): u64 {
        accounting.total_operations_paid
    }

    public fun accounting_total_operations_allocated(accounting: &Accounting): u64 {
        accounting.total_operations_allocated
    }

    public fun accounting_jackpot_allowance(accounting: &Accounting): u64 {
        accounting.jackpot_allowance_token
    }
}
