spec module lottery_multi::economics {
    use lottery_multi::economics::{Accounting, SalesDistribution, BASIS_POINTS_MAX};

    spec struct SalesDistribution {
        invariant prize_bps + jackpot_bps + operations_bps + reserve_bps == BASIS_POINTS_MAX;
    }

    spec struct Accounting {
        invariant total_sales >= 0;
        invariant total_allocated >= total_prize_paid;
        invariant total_operations_allocated >= total_operations_paid;
        invariant total_allocated >= total_prize_paid + total_operations_paid;
        invariant jackpot_allowance_token <= total_sales + total_allocated - total_prize_paid;
    }

    spec apply_sale {
        let old_acc = old(accounting);
        ensures accounting.total_sales == old_acc.total_sales + amount;
        ensures accounting.total_allocated == old_acc.total_allocated + result_1 + result_4;
        ensures accounting.total_operations_allocated
            == old_acc.total_operations_allocated + result_3;
        ensures accounting.total_prize_paid == old_acc.total_prize_paid;
        ensures accounting.total_operations_paid == old_acc.total_operations_paid;
        ensures result_1 + result_2 + result_3 + result_4 == amount;
    }

    spec record_prize_payout {
        let old_acc = old(accounting);
        ensures accounting.total_prize_paid == old_acc.total_prize_paid + amount;
        ensures accounting.total_prize_paid <= accounting.total_allocated;
        ensures accounting.total_operations_paid == old_acc.total_operations_paid;
    }

    spec record_operations_payout {
        let old_acc = old(accounting);
        ensures accounting.total_operations_paid == old_acc.total_operations_paid + amount;
        ensures accounting.total_operations_paid <= accounting.total_operations_allocated;
        ensures accounting.total_prize_paid == old_acc.total_prize_paid;
    }

    spec set_initial_jackpot_allowance {
        let old_acc = old(accounting);
        ensures old_acc.jackpot_allowance_token == 0
            ==> accounting.jackpot_allowance_token == allowance;
        ensures old_acc.jackpot_allowance_token > 0
            ==> accounting.jackpot_allowance_token <= old_acc.jackpot_allowance_token;
    }

    spec consume_jackpot_allowance {
        let old_acc = old(accounting);
        ensures accounting.jackpot_allowance_token
            == old_acc.jackpot_allowance_token - amount;
        ensures accounting.jackpot_allowance_token >= 0;
    }
}
