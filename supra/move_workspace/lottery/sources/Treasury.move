module lottery::treasury_v1 {
    use std::option;
    use std::string;
    use supra_framework::event;
    use std::vector;
    use supra_framework::object;
    use supra_framework::fungible_asset;
    use supra_framework::primary_fungible_store;
    use std::signer;
    use std::math64;

    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_STORE_NOT_REGISTERED: u64 = 4;
    const E_TREASURY_STORE_NOT_REGISTERED: u64 = 5;
    const E_INVALID_BASIS_POINTS: u64 = 6;
    const E_RECIPIENT_STORE_NOT_REGISTERED: u64 = 7;

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

    struct TokenState has key {
        metadata: object::Object<fungible_asset::Metadata>,
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef,
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

        let constructor_ref = object::create_named_object(admin, seed);
        let name_string = string::utf8(name);
        let symbol_string = string::utf8(symbol);
        let icon_uri_string = string::utf8(icon_uri);
        let project_uri_string = string::utf8(project_uri);
        let max_supply = option::none<u128>();

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            max_supply,
            name_string,
            symbol_string,
            decimals,
            icon_uri_string,
            project_uri_string,
        );

        let metadata = object::object_from_constructor_ref<fungible_asset::Metadata>(&constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);

        primary_fungible_store::ensure_primary_store_exists(admin_addr, metadata);

        move_to(admin, TokenState { metadata, mint_ref, burn_ref, transfer_ref });
        move_to(admin, Vaults { config: default_config(), recipients: default_recipients() });
        emit_config();
    }

    public entry fun register_store(account: &signer) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::ensure_primary_store_exists(signer::address_of(account), state.metadata);
    }

    public entry fun register_store_for(admin: &signer, account: address) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::ensure_primary_store_exists(account, state.metadata);
    }

    fun register_stores_for_internal(
        state: &TokenState,
        accounts: &vector<address>,
        idx: u64
    ) {
        let len = vector::length(accounts);
        if (idx >= len) {
            return
        };

        let addr = *vector::borrow(accounts, idx);
        primary_fungible_store::ensure_primary_store_exists(addr, state.metadata);
        register_stores_for_internal(state, accounts, idx + 1);
    }

    public entry fun register_stores_for(admin: &signer, accounts: vector<address>) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        register_stores_for_internal(state, &accounts, 0);
    }

    public entry fun mint_to(admin: &signer, recipient: address, amount: u64) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(recipient, state.metadata), E_STORE_NOT_REGISTERED);
        let store = primary_fungible_store::ensure_primary_store_exists(recipient, state.metadata);
        fungible_asset::mint_to(&state.mint_ref, store, amount);
    }

    public entry fun burn_from(admin: &signer, owner: address, amount: u64) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(owner, state.metadata), E_STORE_NOT_REGISTERED);
        let store = primary_fungible_store::ensure_primary_store_exists(owner, state.metadata);
        fungible_asset::burn_from(&state.burn_ref, store, amount);
    }

    public entry fun transfer_between(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(from, state.metadata), E_STORE_NOT_REGISTERED);
        assert!(primary_fungible_store::primary_store_exists(to, state.metadata), E_STORE_NOT_REGISTERED);
        let from_store = primary_fungible_store::ensure_primary_store_exists(from, state.metadata);
        let to_store = primary_fungible_store::ensure_primary_store_exists(to, state.metadata);
        fungible_asset::transfer_with_ref(&state.transfer_ref, from_store, to_store, amount);
    }

    public entry fun set_store_frozen(
        admin: &signer,
        account: address,
        frozen: bool
    ) acquires TokenState {
        assert!(signer::address_of(admin) == @lottery, E_NOT_OWNER);
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(account, state.metadata), E_STORE_NOT_REGISTERED);
        primary_fungible_store::set_frozen_flag(&state.transfer_ref, account, frozen);
    }

    public fun deposit_from_user(user: &signer, amount: u64) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(signer::address_of(user), state.metadata), E_STORE_NOT_REGISTERED);
        assert!(primary_fungible_store::primary_store_exists(@lottery, state.metadata), E_TREASURY_STORE_NOT_REGISTERED);
        let asset = primary_fungible_store::withdraw(user, state.metadata, amount);
        primary_fungible_store::deposit(@lottery, asset);
    }

    public(package) fun payout_from_treasury(recipient: address, amount: u64) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(@lottery, state.metadata), E_TREASURY_STORE_NOT_REGISTERED);
        assert!(primary_fungible_store::primary_store_exists(recipient, state.metadata), E_STORE_NOT_REGISTERED);
        let treasury_store = primary_fungible_store::ensure_primary_store_exists(@lottery, state.metadata);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient, state.metadata);
        fungible_asset::transfer_with_ref(&state.transfer_ref, treasury_store, recipient_store, amount);
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

        let state = borrow_global<TokenState>(@lottery);
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
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::balance(@lottery, state.metadata)
    }

    #[view]
    public fun balance_of(account: address): u64 acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::balance(account, state.metadata)
    }

    #[view]
    public fun store_registered(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::primary_store_exists(account, state.metadata)
    }

    #[view]
    public fun store_frozen(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::is_frozen(account, state.metadata)
    }

    #[view]
    public fun primary_store_address(account: address): address acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        primary_fungible_store::primary_store_address(account, state.metadata)
    }

    #[view]
    public fun total_supply(): u128 acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        let supply_opt = fungible_asset::supply(state.metadata);
        if (option::is_some(&supply_opt)) {
            let supply_ref = option::borrow(&supply_opt);
            *supply_ref
        } else {
            0
        }
    }

    #[view]
    public fun metadata_address(): address acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        object::object_address(&state.metadata)
    }

    #[view]
    public fun metadata_summary(): (string::String, string::String, u8, string::String, string::String) acquires TokenState {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        let state = borrow_global<TokenState>(@lottery);
        let name = fungible_asset::name(state.metadata);
        let symbol = fungible_asset::symbol(state.metadata);
        let icon_uri = fungible_asset::icon_uri(state.metadata);
        let project_uri = fungible_asset::project_uri(state.metadata);

        (
            name,
            symbol,
            fungible_asset::decimals(state.metadata),
            icon_uri,
            project_uri
        )
    }

    #[view]
    public fun account_status(account: address): (bool, option::Option<address>, u64) acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return (false, option::none(), 0)
        };

        let state = borrow_global<TokenState>(@lottery);
        let registered = primary_fungible_store::primary_store_exists(account, state.metadata);
        if (!registered) {
            return (false, option::none(), 0)
        };

        let store_address = primary_fungible_store::primary_store_address(account, state.metadata);
        let balance = primary_fungible_store::balance(account, state.metadata);
        (true, option::some(store_address), balance)
    }

    #[view]
    public fun account_extended_status(account: address): (bool, bool, option::Option<address>, u64) acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return (false, false, option::none(), 0)
        };

        let state = borrow_global<TokenState>(@lottery);
        let registered = primary_fungible_store::primary_store_exists(account, state.metadata);
        if (!registered) {
            return (false, false, option::none(), 0)
        };

        let frozen = primary_fungible_store::is_frozen(account, state.metadata);
        let store_address = primary_fungible_store::primary_store_address(account, state.metadata);
        let balance = primary_fungible_store::balance(account, state.metadata);
        (true, frozen, option::some(store_address), balance)
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
        state: &TokenState,
        target: address,
        amount: u64
    ) {
        if (amount == 0 || target == @lottery) {
            return
        };

        assert!(
            primary_fungible_store::primary_store_exists(target, state.metadata),
            E_RECIPIENT_STORE_NOT_REGISTERED
        );
        let treasury_store = primary_fungible_store::ensure_primary_store_exists(@lottery, state.metadata);
        let target_store = primary_fungible_store::ensure_primary_store_exists(target, state.metadata);
        fungible_asset::transfer_with_ref(&state.transfer_ref, treasury_store, target_store, amount);
    }

    fun ensure_recipient_store_registered(state: &TokenState, account: address) {
        if (account == @lottery) {
            return
        };

        assert!(
            primary_fungible_store::primary_store_exists(account, state.metadata),
            E_RECIPIENT_STORE_NOT_REGISTERED
        );
    }

    public(package) fun distribute_payout(winner: address, total_amount: u64): u64 acquires TokenState, Vaults {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
        if (total_amount == 0) {
            return 0
        };

        let state = borrow_global<TokenState>(@lottery);
        assert!(primary_fungible_store::primary_store_exists(winner, state.metadata), E_STORE_NOT_REGISTERED);

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

        let treasury_store = primary_fungible_store::ensure_primary_store_exists(@lottery, state.metadata);
        let winner_store = primary_fungible_store::ensure_primary_store_exists(winner, state.metadata);
        let winner_amount = winner_share;
        fungible_asset::transfer_with_ref(&state.transfer_ref, treasury_store, winner_store, winner_amount);

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
