module lottery_rewards_engine::rounds_sync {
    use std::signer;
    use std::vector;

    use lottery_data::rounds;
    use lottery_engine::sales;
    use lottery_rewards_engine::autopurchase;
    use lottery_rewards_engine::referrals;
    use lottery_rewards_engine::vip;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_CAPS_NOT_READY: u64 = 2;

    public entry fun sync_purchases_from_rounds(caller: &signer, limit: u64)
    acquires autopurchase::AutopurchaseAccess, rounds::PendingPurchaseQueue {
        ensure_admin(caller);
        ensure_round_caps_ready();
        let access = borrow_global<autopurchase::AutopurchaseAccess>(@lottery);
        let cap_ref = &access.rounds;
        let mut pending = rounds::drain_purchase_queue(cap_ref, limit);
        process_records(caller, &mut pending);
    }

    fun process_records(caller: &signer, records: &mut vector<rounds::PendingPurchaseRecord>) {
        if (vector::is_empty(records)) {
            return;
        };
        let record = vector::pop_back(records);
        handle_record(caller, record);
        process_records(caller, records);
    }

    fun handle_record(caller: &signer, record: rounds::PendingPurchaseRecord) {
        let (lottery_id, buyer, _ticket_count, paid_amount) =
            rounds::destroy_pending_purchase_record(record);
        let bonus_tickets = vip::bonus_tickets_for(lottery_id, buyer);
        if (bonus_tickets > 0) {
            sales::grant_bonus_tickets_admin(caller, lottery_id, buyer, bonus_tickets);
            vip::record_bonus_usage(lottery_id, buyer, bonus_tickets);
        };
        if (paid_amount > 0) {
            referrals::record_reward(caller, lottery_id, buyer, paid_amount);
        };
    }

    fun ensure_admin(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED;
        };
    }

    fun ensure_round_caps_ready() {
        if (!autopurchase::caps_ready()) {
            abort E_CAPS_NOT_READY;
        };
    }
}
