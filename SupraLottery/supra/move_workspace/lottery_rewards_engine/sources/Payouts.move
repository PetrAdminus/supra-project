module lottery_rewards_engine::payouts {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::payouts;
    use lottery_data::treasury_multi;

    const E_UNAUTHORIZED: u64 = 1;
    const E_RECIPIENT_MISMATCH: u64 = 2;
    const E_AMOUNT_MISMATCH: u64 = 3;
    const E_STATUS_NOT_PENDING: u64 = 4;
    const E_EMPTY_BATCH: u64 = 5;
    const E_AMOUNT_ZERO: u64 = 6;

    #[view]
    public fun is_initialized(): bool {
        payouts::is_initialized()
    }

    public entry fun pay_jackpot_winner(caller: &signer, payout_id: u64)
    acquires instances::InstanceRegistry, payouts::PayoutLedger, treasury_multi::TreasuryState {
        ensure_admin(caller);
        execute_pay_jackpot(payout_id);
    }

    public entry fun pay_jackpot_batch(caller: &signer, payout_ids: vector<u64>)
    acquires instances::InstanceRegistry, payouts::PayoutLedger, treasury_multi::TreasuryState {
        ensure_admin(caller);
        let len = vector::length(&payout_ids);
        assert!(len > 0, E_EMPTY_BATCH);
        pay_jackpot_recursive(&payout_ids, 0, len);
    }

    public entry fun record_prize_payout(
        caller: &signer,
        lottery_id: u64,
        winner: address,
        amount: u64,
    ) acquires instances::InstanceRegistry, treasury_multi::TreasuryState {
        ensure_admin(caller);
        assert!(amount > 0, E_AMOUNT_ZERO);
        ensure_lottery_exists(lottery_id);
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_prize_payout(state, lottery_id, winner, amount);
    }

    public entry fun withdraw_operations_pool(
        caller: &signer,
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) acquires instances::InstanceRegistry, treasury_multi::TreasuryState {
        ensure_admin(caller);
        assert!(amount > 0, E_AMOUNT_ZERO);
        ensure_lottery_exists(lottery_id);
        let state = treasury_multi::borrow_state_mut(@lottery);
        let expected_recipient = treasury_multi::operations_recipient(state);
        assert!(recipient == expected_recipient, E_RECIPIENT_MISMATCH);
        treasury_multi::record_operations_withdrawal(state, lottery_id, recipient, amount);
    }

    public entry fun record_operations_income(
        caller: &signer,
        lottery_id: u64,
        amount: u64,
        source: vector<u8>,
    ) acquires instances::InstanceRegistry, treasury_multi::TreasuryState {
        ensure_admin(caller);
        assert!(amount > 0, E_AMOUNT_ZERO);
        ensure_lottery_exists(lottery_id);
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_operations_income(state, lottery_id, amount, source);
    }

    public entry fun record_operations_bonus(
        caller: &signer,
        lottery_id: u64,
        recipient: address,
        amount: u64,
    ) acquires instances::InstanceRegistry, treasury_multi::TreasuryState {
        ensure_admin(caller);
        assert!(amount > 0, E_AMOUNT_ZERO);
        ensure_lottery_exists(lottery_id);
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_operations_bonus(state, lottery_id, recipient, amount);
    }

    public entry fun record_jackpot_payment(
        caller: &signer,
        recipient: address,
        amount: u64,
    ) acquires instances::InstanceRegistry, treasury_multi::TreasuryState {
        ensure_admin(caller);
        assert!(amount > 0, E_AMOUNT_ZERO);
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::record_jackpot_payment(state, recipient, amount);
    }

    #[view]
    public fun ledger_snapshot(): option::Option<payouts::PayoutLedgerSnapshot>
    acquires payouts::PayoutLedger {
        payouts::ledger_snapshot()
    }

    #[view]
    public fun lottery_snapshot(lottery_id: u64): option::Option<payouts::LotteryPayoutSnapshot>
    acquires payouts::PayoutLedger {
        payouts::lottery_snapshot(lottery_id)
    }

    fun ensure_admin(caller: &signer) acquires instances::InstanceRegistry {
        let caller_address = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        assert!(caller_address == registry.admin, E_UNAUTHORIZED);
    }

    fun ensure_lottery_exists(lottery_id: u64) acquires instances::InstanceRegistry {
        let registry = instances::borrow_registry(@lottery);
        let _record = instances::instance(registry, lottery_id);
    }

    fun execute_pay_jackpot(payout_id: u64)
    acquires payouts::PayoutLedger, treasury_multi::TreasuryState, instances::InstanceRegistry {
        let record = payouts::payout_record(payout_id);
        assert!(record.status == payouts::status_pending(), E_STATUS_NOT_PENDING);
        ensure_lottery_exists(record.lottery_id);
        assert!(record.amount > 0, E_AMOUNT_ZERO);
        let state = treasury_multi::borrow_state_mut(@lottery);
        let jackpot_before = treasury_multi::jackpot_balance(state);
        assert!(jackpot_before >= record.amount, E_AMOUNT_MISMATCH);
        treasury_multi::record_jackpot_payment(state, record.winner, record.amount);
        payouts::mark_paid(payout_id);
    }

    fun pay_jackpot_recursive(
        payout_ids: &vector<u64>,
        index: u64,
        len: u64,
    ) acquires payouts::PayoutLedger, treasury_multi::TreasuryState, instances::InstanceRegistry {
        if (index >= len) {
            return;
        };
        let payout_id = *vector::borrow(payout_ids, index);
        execute_pay_jackpot(payout_id);
        let next_index = index + 1;
        pay_jackpot_recursive(payout_ids, next_index, len);
    }
}
