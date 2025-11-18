module lottery_engine::payouts {
    use std::signer;

    use std::option;

    use lottery_data::instances;
    use lottery_data::payouts;

    const E_UNAUTHORIZED_ADMIN: u64 = 1;
    const E_REFUND_AMOUNT_ZERO: u64 = 2;
    const E_REFUND_AMOUNT_EXCEEDS: u64 = 3;

    #[view]
    public fun is_initialized(): bool {
        payouts::is_initialized()
    }

    #[view]
    public fun ledger_snapshot(): option::Option<payouts::PayoutLedgerSnapshot> acquires payouts::PayoutLedger {
        payouts::ledger_snapshot()
    }

    #[view]
    public fun lottery_snapshot(lottery_id: u64): option::Option<payouts::LotteryPayoutSnapshot>
    acquires payouts::PayoutLedger {
        payouts::lottery_snapshot(lottery_id)
    }

    public entry fun mark_payout_distributed(caller: &signer, payout_id: u64)
    acquires instances::InstanceRegistry, payouts::PayoutLedger {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);

        payouts::mark_paid(payout_id);
    }

    public entry fun record_refund(
        caller: &signer,
        payout_id: u64,
        recipient: address,
        amount: u64,
    ) acquires instances::InstanceRegistry, payouts::PayoutLedger {
        let admin = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        assert!(admin == registry.admin, E_UNAUTHORIZED_ADMIN);

        assert!(amount > 0, E_REFUND_AMOUNT_ZERO);
        let record = payouts::payout_record(payout_id);
        assert!(amount <= record.amount, E_REFUND_AMOUNT_EXCEEDS);

        payouts::mark_refunded(payout_id, recipient, amount);
    }
}
