module lottery::treasury_v1 {
    friend lottery::autopurchase;
    friend lottery::main_v2;
    friend lottery::treasury_multi;
    use std::option;
    use std::string;
    use std::event;
    use std::vector;
    use std::signer;
    use std::math64;
    use vrf_hub::table;

    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_STORE_NOT_REGISTERED: u64 = 4;
    const E_TREASURY_STORE_NOT_REGISTERED: u64 = 5;
    const E_INVALID_BASIS_POINTS: u64 = 6;
    const E_RECIPIENT_STORE_NOT_REGISTERED: u64 = 7;
    const E_STORE_FROZEN: u64 = 0x50003;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;
    const DEFAULT_BP_JACKPOT: u64 = 5_000;
    const DEFAULT_BP_PRIZE: u64 = 2_000;
    const DEFAULT_BP_TREASURY: u64 = 1_500;
    const DEFAULT_BP_MARKETING: u64 = 800;
    const DEFAULT_BP_COMMUNITY: u64 = 400;
    const DEFAULT_BP_TEAM: u64 = 200;
    const DEFAULT_BP_PARTNERS: u64 = 100;

    struct VaultConfig has copy, drop, store {
        bp_jackpot: u64,
        bp_prize: u64,
        bp_treasury: u64,
        bp_marketing: u64,
        bp_community: u64,
        bp_team: u64,
        bp_partners: u64,
    }

    struct VaultRecipients has copy, drop, store {
        treasury: address,
        marketing: address,
        community: address,
        team: address,
        partners: address,
    }

    struct Vaults has key {
        config: VaultConfig,
        recipients: VaultRecipients,
    }

    #[event]
    struct ConfigUpdatedEvent has drop, store, copy {
        bp_jackpot: u64,
        bp_prize: u64,
        bp_treasury: u64,
        bp_marketing: u64,
        bp_community: u64,
        bp_team: u64,
        bp_partners: u64,
    }

    #[event]
    struct JackpotDistributedEvent has drop, store, copy {
        winner: address,
        total_amount: u64,
        winner_share: u64,
        jackpot_share: u64,
        prize_share: u64,
        treasury_share: u64,
        marketing_share: u64,
        community_share: u64,
        team_share: u64,
        partners_share: u64,
    }

    fun default_config(): VaultConfig {
        let config = VaultConfig {
            bp_jackpot: DEFAULT_BP_JACKPOT,
            bp_prize: DEFAULT_BP_PRIZE,
            bp_treasury: DEFAULT_BP_TREASURY,
            bp_marketing: DEFAULT_BP_MARKETING,
            bp_community: DEFAULT_BP_COMMUNITY,
            bp_team: DEFAULT_BP_TEAM,
            bp_partners: DEFAULT_BP_PARTNERS,
        };
        validate_basis_points(&config);
        config
    }

    fun default_recipients(): VaultRecipients {
        VaultRecipients {
            treasury: @lottery,
            marketing: @lottery,
            community: @lottery,
            team: @lottery,
            partners: @lottery,
        }
    }

    fun emit_config() acquires Vaults {
        let vaults = borrow_global<Vaults>(@lottery);
        let config = &vaults.config;
        event::emit(ConfigUpdatedEvent {
            bp_jackpot: config.bp_jackpot,
            bp_prize: config.bp_prize,
            bp_treasury: config.bp_treasury,
            bp_marketing: config.bp_marketing,
            bp_community: config.bp_community,
            bp_team: config.bp_team,
            bp_partners: config.bp_partners,
        });
    }

    fun validate_basis_points(config: &VaultConfig) {
        let sum =
            config.bp_jackpot +
            config.bp_prize +
            config.bp_treasury +
            config.bp_marketing +
            config.bp_community +
            config.bp_team +
            config.bp_partners;
        assert!(sum == BASIS_POINT_DENOMINATOR, E_INVALID_BASIS_POINTS);
    }

    struct StoreInfo has store {
        balance: u64,
        frozen: bool,
    }

    struct TokenState has key {
        name: string::String,
        symbol: string::String,
        decimals: u8,
        icon_uri: string::String,
        project_uri: string::String,
        total_supply: u128,
        stores: table::Table<address, StoreInfo>,
    }

    const METADATA_ADDRESS: address = @lottery;

    fun borrow_state(): &TokenState {
        borrow_global<TokenState>(@lottery)
    }

    fun borrow_state_mut(): &mut TokenState {
        borrow_global_mut<TokenState>(@lottery)
    }

    fun ensure_store_entry(state: &mut TokenState, account: address): &mut StoreInfo {
        if (!table::contains(&state.stores, account)) {
            table::add(&mut state.stores, account, StoreInfo { balance: 0, frozen: false });
        };
        table::borrow_mut(&mut state.stores, account)
    }

    fun ensure_store_exists(state: &TokenState, account: address) {
        assert!(table::contains(&state.stores, account), E_STORE_NOT_REGISTERED);
    }

    fun store_registered_internal(state: &TokenState, account: address): bool {
        table::contains(&state.stores, account)
    }

    fun to_u128(value: u64): u128 {
        let remaining = value;
        let result: u128 = 0;
        let place: u128 = 1;
        while (remaining > 0) {
            if (remaining % 2 == 1) {
                result = result + place;
            };
            remaining = remaining / 2;
            if (remaining > 0) {
                place = place * 2u128;
            };
        };
        result
    }

    public entry fun init_token(
        admin: &signer,
        seed: vector<u8>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        icon_uri: vector<u8>,
        project_uri: vector<u8>
    ) acquires Vaults {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lottery, E_NOT_OWNER);
        assert!(!exists<TokenState>(admin_addr), E_ALREADY_INITIALIZED);
        assert!(!exists<Vaults>(admin_addr), E_ALREADY_INITIALIZED);

        let _ = seed;
        let name_string = string::utf8(name);
        let symbol_string = string::utf8(symbol);
        let icon_uri_string = string::utf8(icon_uri);
        let project_uri_string = string::utf8(project_uri);
        let stores = table::new<address, StoreInfo>();
        table::add(&mut stores, admin_addr, StoreInfo { balance: 0, frozen: false });

        move_to(
            admin,
            TokenState {
                name: name_string,
                symbol: symbol_string,
                decimals,
                icon_uri: icon_uri_string,
                project_uri: project_uri_string,
                total_supply: 0,
                stores,
            },
        );
        move_to(admin, Vaults { config: default_config(), recipients: default_recipients() });
        emit_config();
    }

    public entry fun register_store(account: &signer) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        let _ = ensure_store_entry(state, signer::address_of(account));
    }

    public entry fun register_store_for(admin: &signer, account: address) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        let _ = ensure_store_entry(state, account);
    }

    fun register_stores_for_internal(
        state: &mut TokenState,
        accounts: &vector<address>,
        idx: u64
    ) {
        let len = vector::length(accounts);
        if (idx >= len) {
            return
        };

        let addr = *vector::borrow(accounts, idx);
        let _ = ensure_store_entry(state, addr);
        register_stores_for_internal(state, accounts, idx + 1);
    }

    public entry fun register_stores_for(admin: &signer, accounts: vector<address>) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        register_stores_for_internal(state, &accounts, 0);
    }

    public entry fun mint_to(admin: &signer, recipient: address, amount: u64) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        let store = ensure_store_entry(state, recipient);
        assert!(!store.frozen, E_STORE_FROZEN);
        store.balance = store.balance + amount;
        state.total_supply = state.total_supply + to_u128(amount);
    }

    public entry fun burn_from(admin: &signer, owner: address, amount: u64) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        ensure_store_exists(state, owner);
        {
            let store = table::borrow_mut(&mut state.stores, owner);
            assert!(!store.frozen, E_STORE_FROZEN);
            store.balance = store.balance - amount;
        };
        state.total_supply = state.total_supply - to_u128(amount);
    }

    public entry fun transfer_between(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        ensure_store_exists(state, from);
        ensure_store_exists(state, to);
        {
            let from_store = table::borrow_mut(&mut state.stores, from);
            assert!(!from_store.frozen, E_STORE_FROZEN);
            from_store.balance = from_store.balance - amount;
        };
        {
            let to_store = table::borrow_mut(&mut state.stores, to);
            assert!(!to_store.frozen, E_STORE_FROZEN);
            to_store.balance = to_store.balance + amount;
        };
    }

    public entry fun set_store_frozen(
        admin: &signer,
        account: address,
        frozen: bool
    ) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        ensure_store_exists(state, account);
        let store = table::borrow_mut(&mut state.stores, account);
        store.frozen = frozen;
    }

    public fun deposit_from_user(user: &signer, amount: u64) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        let user_addr = signer::address_of(user);
        assert!(store_registered_internal(state, user_addr), E_STORE_NOT_REGISTERED);
        assert!(store_registered_internal(state, @lottery), E_TREASURY_STORE_NOT_REGISTERED);
        {
            let store = table::borrow_mut(&mut state.stores, user_addr);
            assert!(!store.frozen, E_STORE_FROZEN);
            store.balance = store.balance - amount;
        };
        {
            let treasury_store = table::borrow_mut(&mut state.stores, @lottery);
            treasury_store.balance = treasury_store.balance + amount;
        };
    }

    public(friend) fun payout_from_treasury(recipient: address, amount: u64) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state_mut();
        assert!(store_registered_internal(state, @lottery), E_TREASURY_STORE_NOT_REGISTERED);
        assert!(store_registered_internal(state, recipient), E_STORE_NOT_REGISTERED);
        {
            let treasury_store = table::borrow_mut(&mut state.stores, @lottery);
            treasury_store.balance = treasury_store.balance - amount;
        };
        {
            let recipient_store = table::borrow_mut(&mut state.stores, recipient);
            assert!(!recipient_store.frozen, E_STORE_FROZEN);
            recipient_store.balance = recipient_store.balance + amount;
        };
    }

    public entry fun set_recipients(
        admin: &signer,
        treasury: address,
        marketing: address,
        community: address,
        team: address,
        partners: address,
    ) acquires TokenState, Vaults {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<Vaults>(@lottery), E_NOT_INITIALIZED);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);

        let state = borrow_state();
        ensure_recipient_store_registered(state, treasury);
        ensure_recipient_store_registered(state, marketing);
        ensure_recipient_store_registered(state, community);
        ensure_recipient_store_registered(state, team);
        ensure_recipient_store_registered(state, partners);

        let vaults = borrow_global_mut<Vaults>(@lottery);
        vaults.recipients = VaultRecipients { treasury, marketing, community, team, partners };
    }

    #[view]
    public fun treasury_balance(): u64 acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state();
        if (!store_registered_internal(state, @lottery)) {
            0
        } else {
            let store = table::borrow(&state.stores, @lottery);
            store.balance
        }
    }

    #[view]
    public fun balance_of(account: address): u64 acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state();
        if (!store_registered_internal(state, account)) {
            0
        } else {
            let store = table::borrow(&state.stores, account);
            store.balance
        }
    }

    #[view]
    public fun store_registered(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = borrow_state();
        store_registered_internal(state, account)
    }

    #[view]
    public fun store_frozen(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = borrow_state();
        if (!store_registered_internal(state, account)) {
            false
        } else {
            let store = table::borrow(&state.stores, account);
            store.frozen
        }
    }

    #[view]
    public fun primary_store_address(account: address): address acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state();
        assert!(store_registered_internal(state, account), E_STORE_NOT_REGISTERED);
        account
    }

    #[view]
    public fun total_supply(): u128 acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        borrow_state().total_supply
    }

    #[view]
    public fun metadata_address(): address {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        METADATA_ADDRESS
    }

    #[view]
    public fun metadata_summary(): (string::String, string::String, u8, string::String, string::String) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_state();
        (
            state.name,
            state.symbol,
            state.decimals,
            state.icon_uri,
            state.project_uri
        )
    }

    #[view]
    public fun account_status(account: address): (bool, option::Option<address>, u64) acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return (false, option::none(), 0)
        };

        let state = borrow_state();
        let registered = store_registered_internal(state, account);
        if (!registered) {
            return (false, option::none(), 0)
        };

        let store = table::borrow(&state.stores, account);
        (true, option::some(account), store.balance)
    }

    #[view]
    public fun account_extended_status(account: address): (bool, bool, option::Option<address>, u64) acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return (false, false, option::none(), 0)
        };

        let state = borrow_state();
        let registered = store_registered_internal(state, account);
        if (!registered) {
            return (false, false, option::none(), 0)
        };

        let store = table::borrow(&state.stores, account);
        (true, store.frozen, option::some(account), store.balance)
    }

    #[view]
    public fun is_initialized(): bool {
        exists<TokenState>(@lottery) && exists<Vaults>(@lottery)
    }

    #[view]
    public fun get_config(): (u64, u64, u64, u64, u64, u64, u64) acquires Vaults {
        if (!exists<Vaults>(@lottery)) {
            return (
                DEFAULT_BP_JACKPOT,
                DEFAULT_BP_PRIZE,
                DEFAULT_BP_TREASURY,
                DEFAULT_BP_MARKETING,
                DEFAULT_BP_COMMUNITY,
                DEFAULT_BP_TEAM,
                DEFAULT_BP_PARTNERS,
            )
        };

        let vaults = borrow_global<Vaults>(@lottery);
        let config = &vaults.config;
        (
            config.bp_jackpot,
            config.bp_prize,
            config.bp_treasury,
            config.bp_marketing,
            config.bp_community,
            config.bp_team,
            config.bp_partners,
        )
    }

    #[view]
    public fun get_recipients(): (address, address, address, address, address) acquires Vaults {
        if (!exists<Vaults>(@lottery)) {
            return (@lottery, @lottery, @lottery, @lottery, @lottery)
        };

        let vaults = borrow_global<Vaults>(@lottery);
        let recipients = &vaults.recipients;
        (
            recipients.treasury,
            recipients.marketing,
            recipients.community,
            recipients.team,
            recipients.partners,
        )
    }

    fun calculate_share(total: u64, basis_points: u64): u64 {
        if (basis_points == 0) {
            return 0
        };

        math64::mul_div(total, basis_points, BASIS_POINT_DENOMINATOR)
    }

    fun share_for_recipient(total: u64, basis_points: u64, recipient: address): u64 {
        if (recipient == @lottery) {
            return 0
        };

        calculate_share(total, basis_points)
    }

    fun transfer_share_if_needed(
        state: &mut TokenState,
        target: address,
        amount: u64
    ) {
        if (amount == 0 || target == @lottery) {
            return
        };

        assert!(
            store_registered_internal(state, target),
            E_RECIPIENT_STORE_NOT_REGISTERED
        );
        {
            let treasury_store = table::borrow_mut(&mut state.stores, @lottery);
            treasury_store.balance = treasury_store.balance - amount;
        };
        {
            let target_store = table::borrow_mut(&mut state.stores, target);
            assert!(!target_store.frozen, E_STORE_FROZEN);
            target_store.balance = target_store.balance + amount;
        };
    }

    fun ensure_recipient_store_registered(state: &TokenState, account: address) {
        if (account == @lottery) {
            return
        };

        assert!(
            store_registered_internal(state, account),
            E_RECIPIENT_STORE_NOT_REGISTERED
        );
    }

    public(friend) fun distribute_payout(winner: address, total_amount: u64): u64 acquires TokenState, Vaults {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        if (total_amount == 0) {
            return 0
        };

        let state = borrow_state_mut();
        assert!(store_registered_internal(state, winner), E_STORE_NOT_REGISTERED);

        assert!(exists<Vaults>(@lottery), E_NOT_INITIALIZED);
        let vaults = borrow_global<Vaults>(@lottery);
        let config = &vaults.config;
        let recipients = &vaults.recipients;

        let jackpot_share = calculate_share(total_amount, config.bp_jackpot);
        let prize_share = calculate_share(total_amount, config.bp_prize);
        let treasury_share = share_for_recipient(total_amount, config.bp_treasury, recipients.treasury);
        let marketing_share = share_for_recipient(total_amount, config.bp_marketing, recipients.marketing);
        let community_share = share_for_recipient(total_amount, config.bp_community, recipients.community);
        let team_share = share_for_recipient(total_amount, config.bp_team, recipients.team);
        let partners_share = share_for_recipient(total_amount, config.bp_partners, recipients.partners);

        let distributed =
            jackpot_share +
            prize_share +
            treasury_share +
            marketing_share +
            community_share +
            team_share +
            partners_share;

        let remainder = total_amount - distributed;
        let winner_share = jackpot_share + prize_share + remainder;

        let winner_amount = winner_share;
        {
            let treasury_store = table::borrow_mut(&mut state.stores, @lottery);
            treasury_store.balance = treasury_store.balance - winner_amount;
        };
        {
            let winner_store = table::borrow_mut(&mut state.stores, winner);
            assert!(!winner_store.frozen, E_STORE_FROZEN);
            winner_store.balance = winner_store.balance + winner_amount;
        };

        transfer_share_if_needed(state, recipients.treasury, treasury_share);
        transfer_share_if_needed(state, recipients.marketing, marketing_share);
        transfer_share_if_needed(state, recipients.community, community_share);
        transfer_share_if_needed(state, recipients.team, team_share);
        transfer_share_if_needed(state, recipients.partners, partners_share);

        event::emit(JackpotDistributedEvent {
            winner,
            total_amount,
            winner_share: winner_amount,
            jackpot_share,
            prize_share,
            treasury_share,
            marketing_share,
            community_share,
            team_share,
            partners_share,
        });

        winner_amount
    }

    public entry fun set_config(
        admin: &signer,
        bp_jackpot: u64,
        bp_prize: u64,
        bp_treasury: u64,
        bp_marketing: u64,
        bp_community: u64,
        bp_team: u64,
        bp_partners: u64,
    ) acquires Vaults {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<Vaults>(@lottery), E_NOT_INITIALIZED);

        let config = VaultConfig {
            bp_jackpot,
            bp_prize,
            bp_treasury,
            bp_marketing,
            bp_community,
            bp_team,
            bp_partners,
        };
        validate_basis_points(&config);

        let vaults = borrow_global_mut<Vaults>(@lottery);
        vaults.config = config;
        emit_config();
    }

    public fun config_event_fields(
        event: &ConfigUpdatedEvent
    ): (u64, u64, u64, u64, u64, u64, u64) {
        (
            event.bp_jackpot,
            event.bp_prize,
            event.bp_treasury,
            event.bp_marketing,
            event.bp_community,
            event.bp_team,
            event.bp_partners,
        )
    }

    #[test_only]
    public fun jackpot_distribution_fields(
        event: &JackpotDistributedEvent
    ): (address, u64, u64, u64, u64, u64, u64, u64, u64, u64) {
        (
            event.winner,
            event.total_amount,
            event.winner_share,
            event.jackpot_share,
            event.prize_share,
            event.treasury_share,
            event.marketing_share,
            event.community_share,
            event.team_share,
            event.partners_share,
        )
    }
}
