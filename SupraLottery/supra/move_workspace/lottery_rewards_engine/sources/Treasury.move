module lottery_rewards_engine::treasury {
    use std::signer;

    use lottery_data::instances;
    use lottery_data::treasury_multi;

    const E_UNAUTHORIZED: u64 = 1;
    const E_INVALID_SHARES: u64 = 2;
    const E_JACKPOT_MISMATCH: u64 = 3;
    const E_SHARE_OVERFLOW: u64 = 4;

    const BPS_DENOMINATOR: u64 = 10_000;

    public entry fun set_admin(caller: &signer, new_admin: address)
    acquires treasury_multi::TreasuryState {
        let caller_address = signer::address_of(caller);
        let state = treasury_multi::borrow_state_mut(@lottery);
        assert!(caller_address == treasury_multi::admin(state), E_UNAUTHORIZED);
        treasury_multi::set_admin(state, new_admin);
    }

    public entry fun set_recipients(
        caller: &signer,
        jackpot_recipient: address,
        operations_recipient: address,
    ) acquires treasury_multi::TreasuryState {
        let caller_address = signer::address_of(caller);
        let state = treasury_multi::borrow_state_mut(@lottery);
        assert!(caller_address == treasury_multi::admin(state), E_UNAUTHORIZED);
        treasury_multi::set_recipients(state, jackpot_recipient, operations_recipient);
    }

    public entry fun configure_lottery_shares(
        caller: &signer,
        lottery_id: u64,
        prize_bps: u64,
        jackpot_bps: u64,
        operations_bps: u64,
    ) acquires treasury_multi::TreasuryState, instances::InstanceRegistry {
        ensure_valid_shares(prize_bps, jackpot_bps, operations_bps);
        let caller_address = signer::address_of(caller);
        let state = treasury_multi::borrow_state_mut(@lottery);
        assert!(caller_address == treasury_multi::admin(state), E_UNAUTHORIZED);

        treasury_multi::update_config(state, lottery_id, prize_bps, jackpot_bps, operations_bps);

        let registry = instances::borrow_registry_mut(@lottery);
        let jackpot_share = as_u16(jackpot_bps);
        instances::update_jackpot_share(registry, lottery_id, jackpot_share);
    }

    public fun record_sale_allocation(lottery_id: u64, total_amount: u64, jackpot_amount: u64)
    acquires treasury_multi::TreasuryState {
        let state = treasury_multi::borrow_state_mut(@lottery);
        treasury_multi::ensure_lottery(state, lottery_id);
        let (prize_bps, jackpot_bps, operations_bps) = treasury_multi::share_config(state, lottery_id);

        let expected_jackpot = multiply_bps(total_amount, jackpot_bps);
        assert!(expected_jackpot == jackpot_amount, E_JACKPOT_MISMATCH);

        let prize_amount = multiply_bps(total_amount, prize_bps);
        let operations_amount = multiply_bps(total_amount, operations_bps);
        let remainder = compute_remainder(total_amount, prize_amount, jackpot_amount, operations_amount);
        let final_prize = add_with_check(prize_amount, remainder, E_SHARE_OVERFLOW);

        treasury_multi::record_allocation(
            state,
            lottery_id,
            total_amount,
            final_prize,
            jackpot_amount,
            operations_amount,
        );
    }

    fun ensure_valid_shares(prize_bps: u64, jackpot_bps: u64, operations_bps: u64) {
        assert!(prize_bps <= BPS_DENOMINATOR, E_INVALID_SHARES);
        assert!(jackpot_bps <= BPS_DENOMINATOR, E_INVALID_SHARES);
        assert!(operations_bps <= BPS_DENOMINATOR, E_INVALID_SHARES);
        let total = prize_bps + jackpot_bps + operations_bps;
        assert!(total == BPS_DENOMINATOR, E_INVALID_SHARES);
    }

    fun multiply_bps(amount: u64, bps: u64): u64 {
        let product = (amount as u128) * (bps as u128);
        let result = product / (BPS_DENOMINATOR as u128);
        assert!(result <= 18446744073709551615, E_SHARE_OVERFLOW);
        result as u64
    }

    fun compute_remainder(
        total_amount: u64,
        prize_amount: u64,
        jackpot_amount: u64,
        operations_amount: u64,
    ): u64 {
        let total = total_amount as u128;
        let allocated = (prize_amount as u128) + (jackpot_amount as u128) + (operations_amount as u128);
        if (allocated >= total) {
            0
        } else {
            let remainder = total - allocated;
            assert!(remainder <= 18446744073709551615, E_SHARE_OVERFLOW);
            remainder as u64
        }
    }

    fun add_with_check(current: u64, increment: u64, err: u64): u64 {
        let sum = (current as u128) + (increment as u128);
        assert!(sum <= 18446744073709551615, err);
        sum as u64
    }

    fun as_u16(value: u64): u16 {
        assert!(value <= 65535, E_INVALID_SHARES);
        value as u16
    }
}
