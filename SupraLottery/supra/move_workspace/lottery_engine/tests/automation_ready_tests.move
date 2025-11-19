#[test_only]
module lottery_engine::automation_ready_tests {
    use std::signer;
    use std::vector;

    use lottery_data::automation;
    use lottery_engine::automation as engine_automation;

    #[test(lottery_admin = @lottery, operator = @operator)]
    fun automation_caps_ready_flow(lottery_admin: &signer, operator: &signer) {
        assert!(!automation::caps_ready(), 0);

        automation::init_registry(lottery_admin);
        assert!(automation::caps_ready(), 1);

        let allowed_actions = vector::empty<u64>();
        vector::push_back(&mut allowed_actions, 1);
        engine_automation::register_bot(
            lottery_admin,
            operator,
            b"@daily",
            allowed_actions,
            60,
            1,
            10,
        );

        assert!(automation::caps_ready(), 2);

        let operator_addr = signer::address_of(operator);
        automation::remove_cap(operator_addr);
        let missing = automation::caps_snapshot();
        assert!(vector::length(&missing.missing_caps) == 1, 3);
        assert!(*vector::borrow(&missing.missing_caps, 0) == operator_addr, 4);
        assert!(!automation::caps_ready(), 5);

        automation::publish_cap(operator, b"@daily");
        let fixed = automation::caps_snapshot();
        assert!(vector::length(&fixed.missing_caps) == 0, 6);
        assert!(automation::caps_ready(), 7);
    }
}
