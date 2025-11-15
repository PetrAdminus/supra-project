module lottery_engine::lifecycle {
    use std::option;
    use std::signer;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_engine::operators;
    use supra_framework::event;

    const E_PENDING_REQUEST: u64 = 1;

    public entry fun pause_lottery(caller: &signer, lottery_id: u64)
    acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        operators::OperatorRegistry,
        rounds::RoundRegistry
    {
        operators::ensure_can_manage_signer(caller, lottery_id);

        {
            let registry = instances::borrow_registry_mut(@lottery);
            let changed = instances::set_active(registry, lottery_id, false);
            if (changed) {
                instances::emit_snapshot(registry, lottery_id);
            };
        };

        {
            let state = lottery_state::borrow_mut(@lottery);
            let runtime = lottery_state::runtime_mut(state, lottery_id);
            assert!(!option::is_some(&runtime.pending_request.request_id), E_PENDING_REQUEST);
            if (runtime.draw.draw_scheduled) {
                runtime.draw.draw_scheduled = false;
            };
            lottery_state::emit_snapshot(state, lottery_id);
        };

        {
            let rounds_registry = rounds::borrow_registry_mut(@lottery);
            let round = rounds::round_mut(rounds_registry, lottery_id);
            assert!(!option::is_some(&round.pending_request), E_PENDING_REQUEST);
            if (round.draw_scheduled) {
                round.draw_scheduled = false;
                event::emit_event(
                    &mut rounds_registry.schedule_events,
                    rounds::DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
                );
            };
            rounds::emit_snapshot(rounds_registry, lottery_id);
        };
    }

    public entry fun resume_lottery(caller: &signer, lottery_id: u64)
    acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        operators::OperatorRegistry,
        rounds::RoundRegistry
    {
        operators::ensure_can_manage_signer(caller, lottery_id);

        {
            let registry = instances::borrow_registry_mut(@lottery);
            let changed = instances::set_active(registry, lottery_id, true);
            if (changed) {
                instances::emit_snapshot(registry, lottery_id);
            };
        };

        {
            let state = lottery_state::borrow_mut(@lottery);
            lottery_state::emit_snapshot(state, lottery_id);
        };

        {
            let rounds_registry = rounds::borrow_registry_mut(@lottery);
            rounds::emit_snapshot(rounds_registry, lottery_id);
        };
    }
}
