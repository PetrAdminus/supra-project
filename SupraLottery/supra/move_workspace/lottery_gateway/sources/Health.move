module lottery_gateway::health {
    use lottery_data::access;
    use lottery_data::automation;
    use lottery_data::cancellations;
    use lottery_data::instances;
    use lottery_data::jackpot;
    use lottery_data::lottery_state;
    use lottery_data::payouts;
    use lottery_data::rounds;
    use lottery_data::treasury;
    use lottery_data::treasury_multi;
    use lottery_data::vrf_deposit;
    use lottery_engine::automation as engine_automation;
    use lottery_engine::cancellation as engine_cancellation;
    use lottery_engine::lifecycle;
    use lottery_engine::payouts as engine_payouts;
    use lottery_engine::sales;
    use lottery_engine::ticketing;
    use lottery_engine::vrf;
    use lottery_gateway::gateway;
    use lottery_gateway::registry;
    use lottery_vrf_gateway::hub;
    use lottery_rewards_engine::autopurchase;
    use lottery_rewards_engine::jackpot as rewards_jackpot;
    use lottery_rewards_engine::payouts as rewards_payouts;
    use lottery_rewards_engine::referrals;
    use lottery_rewards_engine::store;
    use lottery_rewards_engine::vip;
    use lottery_utils::feature_flags;
    use lottery_utils::history;
    use lottery_utils::metadata;
    use lottery_utils::migration;

    struct HealthSnapshot has copy, drop, store {
        storage_ready: bool,
        queues_ready: bool,
        treasury_ready: bool,
        rewards_ready: bool,
        autopurchase_ready: bool,
        utils_ready: bool,
        history_ready: bool,
        gateway_ready: bool,
        access_ready: bool,
        cancellations_ready: bool,
        automation_ready: bool,
        vrf_ready: bool,
        engine_ready: bool,
    }

    #[view]
    public fun storage_ready(): bool {
        instances::is_initialized()
            && lottery_state::is_initialized()
            && rounds::is_initialized()
    }

    #[view]
    public fun queues_ready(): bool {
        rounds::ready()
    }

    #[view]
    public fun treasury_ready(): bool {
        treasury::is_initialized() && treasury_multi::is_initialized()
    }

    #[view]
    public fun rewards_ready(): bool {
        payouts::ready()
            && jackpot::ready()
            && rewards_payouts::is_initialized()
            && rewards_jackpot::is_initialized()
            && store::is_initialized()
            && vip::is_initialized()
            && referrals::is_initialized()
    }

    #[view]
    public fun autopurchase_ready(): bool {
        autopurchase::ready()
    }

    #[view]
    public fun utils_ready(): bool {
        feature_flags::is_initialized()
            && metadata::is_initialized()
            && migration::is_initialized()
            && history::ready()
    }

    #[view]
    public fun history_ready(): bool {
        history::ready()
    }

    #[view]
    public fun gateway_ready(): bool {
        gateway::is_initialized() && registry::ready()
    }

    #[view]
    public fun access_ready(): bool {
        access::is_initialized()
    }

    #[view]
    public fun cancellations_ready(): bool {
        cancellations::ready()
    }

    #[view]
    public fun automation_ready(): bool {
        automation::caps_ready() && engine_automation::is_initialized()
    }

    #[view]
    public fun vrf_ready(): bool {
        vrf_deposit::is_initialized() && vrf::is_initialized() && hub::is_initialized()
    }

    #[view]
    public fun engine_ready(): bool {
        ticketing::is_initialized()
            && lifecycle::is_initialized()
            && sales::is_initialized()
            && engine_cancellation::is_initialized()
            && engine_payouts::is_initialized()
    }

    #[view]
    public fun snapshot(): HealthSnapshot {
        HealthSnapshot {
            storage_ready: storage_ready(),
            queues_ready: queues_ready(),
            treasury_ready: treasury_ready(),
            rewards_ready: rewards_ready(),
            autopurchase_ready: autopurchase_ready(),
            utils_ready: utils_ready(),
            history_ready: history_ready(),
            gateway_ready: gateway_ready(),
            access_ready: access_ready(),
            cancellations_ready: cancellations_ready(),
            automation_ready: automation_ready(),
            vrf_ready: vrf_ready(),
            engine_ready: engine_ready(),
        }
    }
}
