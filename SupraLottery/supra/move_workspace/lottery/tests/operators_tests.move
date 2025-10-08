module lottery::operators_tests {
    use std::option;
    use std::vector;
    use std::signer;
    use lottery::operators;

    #[test(lottery_admin = @lottery, owner = @player1, operator = @player2)]
    fun admin_assigns_and_grants(
        lottery_admin: &signer,
        owner: &signer,
        operator: &signer,
    ) {
        operators::init(lottery_admin);
        operators::set_owner(lottery_admin, 0, signer::address_of(owner));

        let owner_opt = operators::get_owner(0);
        let owner_addr = option::extract(owner_opt);
        assert!(owner_addr == signer::address_of(owner), 0);

        operators::grant_operator(lottery_admin, 0, signer::address_of(operator));
        assert!(operators::is_operator(0, signer::address_of(operator)), 1);

        let operators_list = option::extract(operators::list_operators(0));
        assert!(vector::length(&operators_list) == 1, 2);
        assert!(*vector::borrow(&operators_list, 0) == signer::address_of(operator), 3);

        let lotteries = operators::list_lottery_ids();
        assert!(vector::length(&lotteries) == 1, 4);
        assert!(*vector::borrow(&lotteries, 0) == 0, 5);
    }

    #[test(lottery_admin = @lottery, owner = @player1, operator = @player2)]
    fun owner_can_manage(
        lottery_admin: &signer,
        owner: &signer,
        operator: &signer,
    ) {
        operators::init(lottery_admin);
        operators::set_owner(lottery_admin, 7, signer::address_of(owner));

        operators::grant_operator(owner, 7, signer::address_of(operator));
        assert!(operators::is_operator(7, signer::address_of(operator)), 10);

        operators::revoke_operator(owner, 7, signer::address_of(operator));
        assert!(!operators::is_operator(7, signer::address_of(operator)), 11);

        let operators_after = option::extract(operators::list_operators(7));
        assert!(vector::length(&operators_after) == 0, 12);
    }

    #[test(lottery_admin = @lottery, owner = @player1, intruder = @player2, operator = @player3)]
    #[expected_failure(abort_code = 3)]
    fun unauthorized_cannot_grant(
        lottery_admin: &signer,
        owner: &signer,
        intruder: &signer,
        operator: &signer,
    ) {
        operators::init(lottery_admin);
        operators::set_owner(lottery_admin, 42, signer::address_of(owner));

        operators::grant_operator(intruder, 42, signer::address_of(operator));
    }
}
