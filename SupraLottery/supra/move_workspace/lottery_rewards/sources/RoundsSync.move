module lottery_rewards::rewards_rounds_sync {
    use lottery_core::core_rounds as rounds;
    use lottery_core::core_rounds::PendingPurchaseRecord;
    use lottery_rewards::rewards_referrals as referrals;
    use lottery_rewards::rewards_vip as vip;
    use std::signer;
    use std::vector;

    const E_NOT_AUTHORIZED: u64 = 1;

    public entry fun sync_purchases_from_rounds(
        admin: &signer,
        limit: u64,
    ) {
        ensure_lottery_signer(admin);
        let records = rounds::drain_purchase_queue_admin(admin, limit);
        let len = vector::length(&records);
        let idx = 0;
        while (idx < len) {
            let record = vector::borrow(&records, idx);
            process_record(admin, record);
            idx = idx + 1;
        };
    }

    fun process_record(admin: &signer, record: &PendingPurchaseRecord) {
        let (lottery_id, buyer, _ticket_count, paid_amount) =
            rounds::purchase_record_fields(record);
        let bonus_tickets = vip::bonus_tickets_for(lottery_id, buyer);
        if (bonus_tickets > 0) {
            rounds::grant_bonus_tickets_admin(admin, lottery_id, buyer, bonus_tickets);
            vip::record_bonus_usage(lottery_id, buyer, bonus_tickets);
        };
        referrals::record_reward(admin, lottery_id, buyer, paid_amount);
    }

    fun ensure_lottery_signer(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }
}




