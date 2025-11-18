module lottery_engine::lifecycle {
    use std::option;
    use std::signer;
    use std::vector;

    use lottery_data::instances;
    use lottery_data::lottery_state;
    use lottery_data::rounds;
    use lottery_engine::operators;
    use supra_framework::event;

    const E_PENDING_REQUEST: u64 = 1;

    #[view]
    public fun is_initialized(): bool {
        instances::is_initialized() && lottery_state::is_initialized() && rounds::is_initialized()
    }

    struct LifecycleSnapshot has copy, drop, store {
        lottery_id: u64,
        instance_active: bool,
        runtime_draw_scheduled: bool,
        runtime_pending_request: bool,
        round_draw_scheduled: bool,
        round_pending_request: bool,
    }

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

    #[view]
    public fun lifecycle_snapshot(lottery_id: u64): option::Option<LifecycleSnapshot>
    acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        let instance_snapshot = instances::instance_snapshot(lottery_id);
        if (!option::is_some(&instance_snapshot)) {
            return option::none<LifecycleSnapshot>();
        };

        let runtime_snapshot = lottery_state::runtime_snapshot(lottery_id);
        if (!option::is_some(&runtime_snapshot)) {
            return option::none<LifecycleSnapshot>();
        };

        let round_snapshot = rounds::round_snapshot(lottery_id);
        if (!option::is_some(&round_snapshot)) {
            return option::none<LifecycleSnapshot>();
        };

        let instance_value = option::borrow(&instance_snapshot);
        let runtime_value = option::borrow(&runtime_snapshot);
        let round_value = option::borrow(&round_snapshot);

        option::some(build_lifecycle_snapshot(instance_value, runtime_value, round_value))
    }

    #[view]
    public fun lifecycle_snapshots(): option::Option<vector<LifecycleSnapshot>>
    acquires
        instances::InstanceRegistry,
        lottery_state::LotteryState,
        rounds::RoundRegistry
    {
        let registry_snapshot = instances::registry_snapshot();
        if (!option::is_some(&registry_snapshot)) {
            return option::none<vector<LifecycleSnapshot>>();
        };

        let registry = option::borrow(&registry_snapshot);
        let len = vector::length(&registry.instances);
        let snapshots = collect_lifecycle_snapshots(&registry.instances, 0, len);
        option::some(snapshots)
    }

    fun collect_lifecycle_snapshots(
        instances: &vector<instances::InstanceSnapshot>,
        index: u64,
        len: u64,
    ): vector<LifecycleSnapshot> acquires lottery_state::LotteryState, rounds::RoundRegistry {
        if (index == len) {
            return vector::empty<LifecycleSnapshot>();
        };

        let instance_snapshot = *vector::borrow(instances, index);
        let runtime_snapshot = lottery_state::runtime_snapshot(instance_snapshot.lottery_id);
        let round_snapshot = rounds::round_snapshot(instance_snapshot.lottery_id);

        let mut current = vector::empty<LifecycleSnapshot>();
        if (option::is_some(&runtime_snapshot) && option::is_some(&round_snapshot)) {
            let runtime_value = option::borrow(&runtime_snapshot);
            let round_value = option::borrow(&round_snapshot);
            let snapshot = build_lifecycle_snapshot(&instance_snapshot, runtime_value, round_value);
            vector::push_back(&mut current, snapshot);
        };

        let tail = collect_lifecycle_snapshots(instances, index + 1, len);
        append_lifecycle_snapshots(&mut current, &tail, 0);

        current
    }

    fun build_lifecycle_snapshot(
        instance_snapshot: &instances::InstanceSnapshot,
        runtime_snapshot: &lottery_state::LotteryRuntimeSnapshot,
        round_snapshot: &rounds::RoundRuntimeSnapshot,
    ): LifecycleSnapshot {
        LifecycleSnapshot {
            lottery_id: instance_snapshot.lottery_id,
            instance_active: instance_snapshot.active,
            runtime_draw_scheduled: runtime_snapshot.draw.draw_scheduled,
            runtime_pending_request: option::is_some(&runtime_snapshot.pending_request.request_id),
            round_draw_scheduled: round_snapshot.draw_scheduled,
            round_pending_request: option::is_some(&round_snapshot.pending_request),
        }
    }

    fun append_lifecycle_snapshots(
        dst: &mut vector<LifecycleSnapshot>,
        src: &vector<LifecycleSnapshot>,
        index: u64,
    ) {
        if (index == vector::length(src)) {
            return;
        };

        let value = *vector::borrow(src, index);
        vector::push_back(dst, value);
        append_lifecycle_snapshots(dst, src, index + 1);
    }
}
