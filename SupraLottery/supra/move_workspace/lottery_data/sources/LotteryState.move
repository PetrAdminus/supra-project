module lottery_data::lottery_state {
    use std::option;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_DUPLICATE_LOTTERY: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;

    struct ClientWhitelistSnapshot has copy, drop, store {
        max_gas_price: u128,
        max_gas_limit: u128,
        min_balance_limit: u128,
    }

    struct ConsumerWhitelistSnapshot has copy, drop, store {
        callback_gas_price: u128,
        callback_gas_limit: u128,
    }

    struct VrfRequestConfig has copy, drop, store {
        rng_count: u8,
        num_confirmations: u64,
        client_seed: u64,
    }

    struct TicketLedger has copy, drop, store {
        participants: vector<address>,
        next_ticket_id: u64,
    }

    struct DrawSettings has copy, drop, store {
        draw_scheduled: bool,
        auto_draw_threshold: u64,
    }

    struct PendingRequest has copy, drop, store {
        request_id: option::Option<u64>,
        last_request_payload_hash: option::Option<vector<u8>>,
        last_requester: option::Option<address>,
    }

    struct GasBudget has copy, drop, store {
        max_fee: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
    }

    struct VrfStats has copy, drop, store {
        request_count: u64,
        response_count: u64,
        next_client_seed: u64,
    }

    struct WhitelistState has copy, drop, store {
        callback_sender: option::Option<address>,
        consumers: vector<address>,
        client_snapshot: option::Option<ClientWhitelistSnapshot>,
        consumer_snapshot: option::Option<ConsumerWhitelistSnapshot>,
    }

    struct LotteryRuntime has copy, drop, store {
        ticket_price: u64,
        jackpot_amount: u64,
        tickets: TicketLedger,
        draw: DrawSettings,
        pending_request: PendingRequest,
        gas: GasBudget,
        vrf_stats: VrfStats,
        whitelist: WhitelistState,
        request_config: option::Option<VrfRequestConfig>,
    }

    #[event]
    struct LotterySnapshotUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        ticket_price: u64,
        jackpot_amount: u64,
        draw_scheduled: bool,
        auto_draw_threshold: u64,
        ticket_count: u64,
        pending_request: bool,
    }

    #[event]
    struct VrfGasBudgetUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        max_fee: u64,
        max_gas_price: u128,
        max_gas_limit: u128,
        callback_gas_price: u128,
        callback_gas_limit: u128,
        verification_gas_value: u128,
    }

    #[event]
    struct VrfWhitelistUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        callback_sender: option::Option<address>,
        consumer_count: u64,
        client_snapshot_recorded: bool,
        consumer_snapshot_recorded: bool,
    }

    #[event]
    struct VrfRequestConfigUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        configured: bool,
        rng_count: u8,
        num_confirmations: u64,
        client_seed: u64,
        next_client_seed: u64,
    }

    struct LotteryState has key {
        admin: address,
        lotteries: table::Table<u64, LotteryRuntime>,
        lottery_ids: vector<u64>,
        snapshot_events: event::EventHandle<LotterySnapshotUpdatedEvent>,
        vrf_gas_events: event::EventHandle<VrfGasBudgetUpdatedEvent>,
        vrf_whitelist_events: event::EventHandle<VrfWhitelistUpdatedEvent>,
        vrf_request_events: event::EventHandle<VrfRequestConfigUpdatedEvent>,
    }

    public entry fun init(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<LotteryState>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            LotteryState {
                admin: caller_address,
                lotteries: table::new<u64, LotteryRuntime>(),
                lottery_ids: vector::empty<u64>(),
                snapshot_events: account::new_event_handle<LotterySnapshotUpdatedEvent>(caller),
                vrf_gas_events: account::new_event_handle<VrfGasBudgetUpdatedEvent>(caller),
                vrf_whitelist_events: account::new_event_handle<VrfWhitelistUpdatedEvent>(caller),
                vrf_request_events: account::new_event_handle<VrfRequestConfigUpdatedEvent>(caller),
            },
        );
    }

    public fun exists_at(addr: address): bool {
        exists<LotteryState>(addr)
    }

    public fun borrow(addr: address): &LotteryState acquires LotteryState {
        assert!(exists<LotteryState>(addr), E_NOT_PUBLISHED);
        borrow_global<LotteryState>(addr)
    }

    public fun borrow_mut(addr: address): &mut LotteryState acquires LotteryState {
        assert!(exists<LotteryState>(addr), E_NOT_PUBLISHED);
        borrow_global_mut<LotteryState>(addr)
    }

    public fun register_lottery(state: &mut LotteryState, lottery_id: u64, runtime: LotteryRuntime) {
        assert!(!table::contains(&state.lotteries, lottery_id), E_DUPLICATE_LOTTERY);
        table::add(&mut state.lotteries, lottery_id, runtime);
        vector::push_back(&mut state.lottery_ids, lottery_id);
    }

    public fun runtime(state: &LotteryState, lottery_id: u64): &LotteryRuntime {
        assert!(table::contains(&state.lotteries, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow(&state.lotteries, lottery_id)
    }

    public fun runtime_mut(state: &mut LotteryState, lottery_id: u64): &mut LotteryRuntime {
        assert!(table::contains(&state.lotteries, lottery_id), E_UNKNOWN_LOTTERY);
        table::borrow_mut(&mut state.lotteries, lottery_id)
    }

    public fun emit_snapshot(state: &mut LotteryState, lottery_id: u64) {
        let runtime_ref = runtime(state, lottery_id);
        let ticket_count = vector::length(&runtime_ref.tickets.participants);
        let has_pending = option::is_some(&runtime_ref.pending_request.request_id);
        event::emit_event(
            &mut state.snapshot_events,
            LotterySnapshotUpdatedEvent {
                lottery_id,
                ticket_price: runtime_ref.ticket_price,
                jackpot_amount: runtime_ref.jackpot_amount,
                draw_scheduled: runtime_ref.draw.draw_scheduled,
                auto_draw_threshold: runtime_ref.draw.auto_draw_threshold,
                ticket_count,
                pending_request: has_pending,
            },
        );
    }

    public fun emit_vrf_gas_budget(state: &mut LotteryState, lottery_id: u64) {
        let runtime_ref = runtime(state, lottery_id);
        let gas = &runtime_ref.gas;
        event::emit_event(
            &mut state.vrf_gas_events,
            VrfGasBudgetUpdatedEvent {
                lottery_id,
                max_fee: gas.max_fee,
                max_gas_price: gas.max_gas_price,
                max_gas_limit: gas.max_gas_limit,
                callback_gas_price: gas.callback_gas_price,
                callback_gas_limit: gas.callback_gas_limit,
                verification_gas_value: gas.verification_gas_value,
            },
        );
    }

    public fun emit_vrf_whitelist(state: &mut LotteryState, lottery_id: u64) {
        let runtime_ref = runtime(state, lottery_id);
        let whitelist = &runtime_ref.whitelist;
        let consumer_count = vector::length(&whitelist.consumers);
        event::emit_event(
            &mut state.vrf_whitelist_events,
            VrfWhitelistUpdatedEvent {
                lottery_id,
                callback_sender: clone_option_address(&whitelist.callback_sender),
                consumer_count,
                client_snapshot_recorded: option::is_some(&whitelist.client_snapshot),
                consumer_snapshot_recorded: option::is_some(&whitelist.consumer_snapshot),
            },
        );
    }

    public fun emit_vrf_request_config(state: &mut LotteryState, lottery_id: u64) {
        let runtime_ref = runtime(state, lottery_id);
        if (option::is_some(&runtime_ref.request_config)) {
            let config = option::borrow(&runtime_ref.request_config);
            let value = *config;
            event::emit_event(
                &mut state.vrf_request_events,
                VrfRequestConfigUpdatedEvent {
                    lottery_id,
                    configured: true,
                    rng_count: value.rng_count,
                    num_confirmations: value.num_confirmations,
                    client_seed: value.client_seed,
                    next_client_seed: runtime_ref.vrf_stats.next_client_seed,
                },
            );
        } else {
            event::emit_event(
                &mut state.vrf_request_events,
                VrfRequestConfigUpdatedEvent {
                    lottery_id,
                    configured: false,
                    rng_count: 0,
                    num_confirmations: 0,
                    client_seed: 0,
                    next_client_seed: runtime_ref.vrf_stats.next_client_seed,
                },
            );
        };
    }

    fun clone_option_address(value: &option::Option<address>): option::Option<address> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<address>()
        }
    }

    public fun empty_runtime(ticket_price: u64, auto_draw_threshold: u64): LotteryRuntime {
        LotteryRuntime {
            ticket_price,
            jackpot_amount: 0,
            tickets: TicketLedger { participants: vector::empty<address>(), next_ticket_id: 0 },
            draw: DrawSettings { draw_scheduled: false, auto_draw_threshold },
            pending_request: PendingRequest {
                request_id: option::none<u64>(),
                last_request_payload_hash: option::none<vector<u8>>(),
                last_requester: option::none<address>(),
            },
            gas: GasBudget {
                max_fee: 0,
                max_gas_price: 0,
                max_gas_limit: 0,
                callback_gas_price: 0,
                callback_gas_limit: 0,
                verification_gas_value: 0,
            },
            vrf_stats: VrfStats { request_count: 0, response_count: 0, next_client_seed: 0 },
            whitelist: WhitelistState {
                callback_sender: option::none<address>(),
                consumers: vector::empty<address>(),
                client_snapshot: option::none<ClientWhitelistSnapshot>(),
                consumer_snapshot: option::none<ConsumerWhitelistSnapshot>(),
            },
            request_config: option::none<VrfRequestConfig>(),
        }
    }
}
