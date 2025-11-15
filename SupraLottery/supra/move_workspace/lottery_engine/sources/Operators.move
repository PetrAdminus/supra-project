module lottery_engine::operators {
    use std::option;
    use std::signer;

    use lottery_data::instances;
    use lottery_data::operators;

    const E_NOT_AUTHORIZED: u64 = 1;

    public entry fun set_owner(caller: &signer, lottery_id: u64, new_owner: address)
    acquires instances::InstanceRegistry, operators::OperatorRegistry {
        ensure_admin_signer(caller);

        let registry = instances::borrow_registry_mut(@lottery);
        instances::set_owner(registry, lottery_id, new_owner);
        instances::emit_snapshot(registry, lottery_id);

        let operator_registry = operators::borrow_registry_mut(@lottery);
        operators::ensure_entry(operator_registry, lottery_id);
        operators::set_owner(operator_registry, lottery_id, option::some(new_owner));
        operators::emit_snapshot(operator_registry, lottery_id);
    }

    public entry fun grant_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires instances::InstanceRegistry, operators::OperatorRegistry {
        ensure_can_manage_signer(caller, lottery_id);

        let operator_registry = operators::borrow_registry_mut(@lottery);
        operators::ensure_entry(operator_registry, lottery_id);
        operators::grant_operator(operator_registry, lottery_id, operator, signer::address_of(caller));
        operators::emit_snapshot(operator_registry, lottery_id);
    }

    public entry fun revoke_operator(caller: &signer, lottery_id: u64, operator: address)
    acquires instances::InstanceRegistry, operators::OperatorRegistry {
        ensure_can_manage_signer(caller, lottery_id);

        let operator_registry = operators::borrow_registry_mut(@lottery);
        operators::ensure_entry(operator_registry, lottery_id);
        operators::revoke_operator(operator_registry, lottery_id, operator, signer::address_of(caller));
        operators::emit_snapshot(operator_registry, lottery_id);
    }

    public fun ensure_admin_signer(caller: &signer) acquires instances::InstanceRegistry {
        let caller_addr = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        assert!(caller_addr == registry.admin, E_NOT_AUTHORIZED);
    }

    public fun ensure_can_manage_signer(caller: &signer, lottery_id: u64)
    acquires instances::InstanceRegistry, operators::OperatorRegistry {
        let caller_addr = signer::address_of(caller);
        let registry = instances::borrow_registry(@lottery);
        if (caller_addr == registry.admin) {
            return;
        };

        let record = instances::instance(registry, lottery_id);
        if (record.owner == caller_addr) {
            return;
        };

        let operator_registry = operators::borrow_registry(@lottery);
        if (operators::has_operator(operator_registry, lottery_id, caller_addr)) {
            return;
        };

        abort E_NOT_AUTHORIZED;
    }
}
