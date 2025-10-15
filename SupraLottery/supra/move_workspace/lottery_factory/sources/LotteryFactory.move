module lottery_factory::registry {
    use std::option;
    use std::signer;
    use std::vector;
    use supra_framework::event;
    use vrf_hub::hub;
    use vrf_hub::table;

    const E_ALREADY_INIT: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_UNKNOWN_LOTTERY: u64 = 4;

    struct LotteryBlueprint has copy, drop, store {
        ticket_price: u64,
        jackpot_share_bps: u16,
    }

    struct LotteryInfo has copy, drop, store {
        owner: address,
        lottery: address,
        blueprint: LotteryBlueprint,
    }

    struct LotteryRegistryEntry has copy, drop, store {
        lottery_id: u64,
        owner: address,
        lottery: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
    }

    struct LotteryRegistrySnapshot has copy, drop, store {
        admin: address,
        lotteries: vector<LotteryRegistryEntry>,
    }

    struct FactoryState has key {
        admin: address,
        lotteries: table::Table<u64, LotteryInfo>,
        lottery_ids: vector<u64>,
    }

    #[event]
    struct LotteryPlannedEvent has drop, store, copy {
        lottery_id: u64,
        owner: address,
    }

    #[event]
    struct LotteryActivatedEvent has drop, store, copy {
        lottery_id: u64,
        lottery: address,
    }

    #[event]
    struct LotteryRegistrySnapshotUpdatedEvent has drop, store, copy {
        admin: address,
        lotteries: vector<LotteryRegistryEntry>,
    }

    public entry fun init(caller: &signer) acquires FactoryState {
        let addr = signer::address_of(caller);
        if (addr != @lottery_factory) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<FactoryState>(@lottery_factory)) {
            abort E_ALREADY_INIT
        };
        let state = FactoryState {
            admin: addr,
            lotteries: table::new(),
            lottery_ids: vector::empty<u64>(),
        };
        move_to(caller, state);
        let state_ref = borrow_global_mut<FactoryState>(@lottery_factory);
        emit_registry_snapshot(state_ref);
    }

    #[view]
    public fun is_initialized(): bool {
        exists<FactoryState>(@lottery_factory)
    }

    #[view]
    public fun new_blueprint(ticket_price: u64, jackpot_share_bps: u16): LotteryBlueprint {
        LotteryBlueprint { ticket_price, jackpot_share_bps }
    }

    public entry fun create_lottery(
        caller: &signer,
        owner: address,
        lottery: address,
        blueprint: LotteryBlueprint,
        metadata: vector<u8>,
    ): u64 acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        let lottery_id = hub::register_lottery(caller, owner, lottery, metadata);
        table::add(
            &mut state.lotteries,
            lottery_id,
            LotteryInfo { owner, lottery, blueprint },
        );
        record_lottery_id(&mut state.lottery_ids, lottery_id);
        event::emit(LotteryPlannedEvent { lottery_id, owner });
        event::emit(LotteryActivatedEvent { lottery_id, lottery });
        emit_registry_snapshot(state);
        lottery_id
    }

    public entry fun update_blueprint(
        caller: &signer,
        lottery_id: u64,
        blueprint: LotteryBlueprint,
    ) acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        if (!table::contains(&state.lotteries, lottery_id)) {
            abort E_UNKNOWN_LOTTERY
        };
        let info = table::borrow_mut(&mut state.lotteries, lottery_id);
        info.blueprint = blueprint;
        emit_registry_snapshot(state);
    }

    public entry fun set_admin(caller: &signer, new_admin: address) acquires FactoryState {
        ensure_admin(caller);
        let state = borrow_global_mut<FactoryState>(@lottery_factory);
        state.admin = new_admin;
        emit_registry_snapshot(state);
    }

    public fun make_lottery_info(
        owner: address,
        lottery: address,
        blueprint: LotteryBlueprint,
    ): LotteryInfo {
        LotteryInfo { owner, lottery, blueprint }
    }

    public fun copy_lottery_info(info: &LotteryInfo): LotteryInfo {
        *info
    }

    public fun lottery_info_owner(info: &LotteryInfo): address {
        info.owner
    }

    public fun lottery_info_lottery(info: &LotteryInfo): address {
        info.lottery
    }

    public fun lottery_info_blueprint(info: &LotteryInfo): LotteryBlueprint {
        info.blueprint
    }

    public fun blueprint_ticket_price(blueprint: &LotteryBlueprint): u64 {
        blueprint.ticket_price
    }

    public fun blueprint_jackpot_share_bps(blueprint: &LotteryBlueprint): u16 {
        blueprint.jackpot_share_bps
    }

    public fun copy_blueprint(blueprint: &LotteryBlueprint): LotteryBlueprint {
        *blueprint
    }

    #[test_only]
    public fun lottery_info_fields_for_test(info: &LotteryInfo): (address, address, u64, u16) {
        let blueprint = info.blueprint;
        (
            info.owner,
            info.lottery,
            blueprint.ticket_price,
            blueprint.jackpot_share_bps,
        )
    }

    #[view]
    public fun get_lottery(lottery_id: u64): option::Option<LotteryInfo> acquires FactoryState {
        ensure_initialized();
        let state = borrow_global<FactoryState>(@lottery_factory);
        if (!table::contains(&state.lotteries, lottery_id)) {
            option::none()
        } else {
            option::some(*table::borrow(&state.lotteries, lottery_id))
        }
    }

    #[view]
    public fun lottery_count(): u64 acquires FactoryState {
        ensure_initialized();
        let state = borrow_global<FactoryState>(@lottery_factory);
        table::length(&state.lotteries)
    }

    #[view]
    public fun list_lottery_ids(): vector<u64> acquires FactoryState {
        if (!exists<FactoryState>(@lottery_factory)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<FactoryState>(@lottery_factory);
        copy_u64_vector(&state.lottery_ids)
    }

    #[view]
    public fun get_registry_snapshot(): LotteryRegistrySnapshot acquires FactoryState {
        if (!exists<FactoryState>(@lottery_factory)) {
            return LotteryRegistrySnapshot {
                admin: @lottery_factory,
                lotteries: vector::empty<LotteryRegistryEntry>(),
            }
        };
        let state = borrow_global<FactoryState>(@lottery_factory);
        build_registry_snapshot(state)
    }

    #[test_only]
    public fun registry_snapshot_fields_for_test(
        snapshot: &LotteryRegistrySnapshot
    ): (address, vector<LotteryRegistryEntry>) {
        (
            snapshot.admin,
            copy_registry_entries(&snapshot.lotteries),
        )
    }

    #[test_only]
    public fun registry_snapshot_event_fields_for_test(
        event: &LotteryRegistrySnapshotUpdatedEvent
    ): (address, vector<LotteryRegistryEntry>) {
        (
            event.admin,
            copy_registry_entries(&event.lotteries),
        )
    }

    #[test_only]
    public fun registry_entry_fields_for_test(
        entry: &LotteryRegistryEntry
    ): (u64, address, address, u64, u16) {
        (
            entry.lottery_id,
            entry.owner,
            entry.lottery,
            entry.ticket_price,
            entry.jackpot_share_bps,
        )
    }

    fun ensure_admin(caller: &signer) acquires FactoryState {
        ensure_initialized();
        let addr = signer::address_of(caller);
        let state = borrow_global<FactoryState>(@lottery_factory);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun emit_registry_snapshot(state: &mut FactoryState) {
        let snapshot = build_registry_snapshot(state);
        let LotteryRegistrySnapshot { admin, lotteries } = snapshot;
        event::emit(LotteryRegistrySnapshotUpdatedEvent { admin, lotteries });
    }

    fun build_registry_snapshot(state: &FactoryState): LotteryRegistrySnapshot {
        LotteryRegistrySnapshot {
            admin: state.admin,
            lotteries: collect_registry_entries(&state.lotteries, &state.lottery_ids),
        }
    }

    fun collect_registry_entries(
        lotteries: &table::Table<u64, LotteryInfo>,
        ids: &vector<u64>,
    ): vector<LotteryRegistryEntry> {
        let entries = vector::empty<LotteryRegistryEntry>();
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(ids, idx);
            if (table::contains(lotteries, lottery_id)) {
                let info = table::borrow(lotteries, lottery_id);
                vector::push_back(&mut entries, make_registry_entry(lottery_id, info));
            };
            idx = idx + 1;
        };
        entries
    }

    fun make_registry_entry(lottery_id: u64, info: &LotteryInfo): LotteryRegistryEntry {
        let blueprint = &info.blueprint;
        LotteryRegistryEntry {
            lottery_id,
            owner: info.owner,
            lottery: info.lottery,
            ticket_price: blueprint.ticket_price,
            jackpot_share_bps: blueprint.jackpot_share_bps,
        }
    }

    fun copy_registry_entries(
        entries: &vector<LotteryRegistryEntry>
    ): vector<LotteryRegistryEntry> {
        let out = vector::empty<LotteryRegistryEntry>();
        let len = vector::length(entries);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(entries, idx));
            idx = idx + 1;
        };
        out
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(ids, lottery_id);
    }

    fun copy_u64_vector(values: &vector<u64>): vector<u64> {
        let out = vector::empty<u64>();
        let len = vector::length(values);
        let idx = 0;
        while (idx < len) {
            vector::push_back(&mut out, *vector::borrow(values, idx));
            idx = idx + 1;
        };
        out
    }

    fun ensure_initialized() {
        if (!exists<FactoryState>(@lottery_factory)) {
            abort E_NOT_INITIALIZED
        };
    }
}
