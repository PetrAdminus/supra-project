module lottery::treasury_v1 {
    use std::math64;
    use std::option;
    use std::signer;
    use std::string;
    use std::vector;
    use supra_framework::event;
    use supra_framework::fungible_asset;
    use supra_framework::object;
    use supra_framework::primary_fungible_store;

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

    struct VaultRecipientStatus has copy, drop, store {
        account: address,
        registered: bool,
        frozen: bool,
        store: option::Option<address>,
        balance: u64,
    }

    struct VaultRecipientsSnapshot has copy, drop, store {
        treasury: VaultRecipientStatus,
        marketing: VaultRecipientStatus,
        community: VaultRecipientStatus,
        team: VaultRecipientStatus,
        partners: VaultRecipientStatus,
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
    struct RecipientsUpdatedEvent has drop, store, copy {
        previous: option::Option<VaultRecipientsSnapshot>,
        next: VaultRecipientsSnapshot,
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

    struct TokenState has key {
        metadata: object::Object<fungible_asset::Metadata>,
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef,
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

    fun ensure_token_initialized() {
        assert!(exists<TokenState>(@lottery), E_NOT_INITIALIZED);
    }

    fun ensure_vaults_initialized() {
        assert!(exists<Vaults>(@lottery), E_NOT_INITIALIZED);
    }

    fun ensure_owner(caller: &signer) {
        assert!(signer::address_of(caller) == @lottery, E_NOT_OWNER);
    }

    fun state_ref(): &TokenState acquires TokenState {
        borrow_global<TokenState>(@lottery)
    }

    fun metadata_address_internal(state: &TokenState): address {
        object::object_address(&state.metadata)
    }

    fun ensure_store_exists(
        state: &TokenState,
        account: address,
        error_code: u64,
    ): object::Object<fungible_asset::FungibleStore> {
        let metadata = state.metadata;
        assert!(
            primary_fungible_store::primary_store_exists(account, metadata),
            error_code,
        );
        primary_fungible_store::primary_store(account, metadata)
    }

    fun ensure_not_frozen(store: object::Object<fungible_asset::FungibleStore>) {
        assert!(!fungible_asset::is_frozen(store), E_STORE_FROZEN);
    }

    fun ensure_recipient_store_ready(state: &TokenState, account: address) {
        let error_code = if (account == @lottery) {
            E_TREASURY_STORE_NOT_REGISTERED
        } else {
            E_RECIPIENT_STORE_NOT_REGISTERED
        };
        let store = ensure_store_exists(state, account, error_code);
        ensure_not_frozen(store);
    }

    fun transfer_share_if_needed(
        state: &TokenState,
        treasury_store: object::Object<fungible_asset::FungibleStore>,
        target: address,
        amount: u64,
    ) {
        if (amount == 0 || target == @lottery) {
            return
        };

        let target_store = ensure_store_exists(state, target, E_RECIPIENT_STORE_NOT_REGISTERED);
        ensure_not_frozen(target_store);
        fungible_asset::transfer_with_ref(
            &state.transfer_ref,
            treasury_store,
            target_store,
            amount,
        );
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

    public entry fun init_token(
        admin: &signer,
        seed: vector<u8>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        icon_uri: vector<u8>,
        project_uri: vector<u8>
    ) acquires TokenState, Vaults {
        ensure_owner(admin);
        let admin_addr = signer::address_of(admin);
        assert!(!exists<TokenState>(admin_addr), E_ALREADY_INITIALIZED);
        assert!(!exists<Vaults>(admin_addr), E_ALREADY_INITIALIZED);

        let constructor_ref = object::create_named_object(admin, seed);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            string::utf8(icon_uri),
            string::utf8(project_uri),
        );

        let metadata = object::object_from_constructor_ref<fungible_asset::Metadata>(&constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);

        primary_fungible_store::ensure_primary_store_exists(admin_addr, metadata);

        move_to(
            admin,
            TokenState {
                metadata,
                mint_ref,
                burn_ref,
                transfer_ref,
            },
        );
        move_to(admin, Vaults { config: default_config(), recipients: default_recipients() });
        emit_config();
        emit_recipients_event(option::none());
    }

    public entry fun register_store(account: &signer) acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        let account_addr = signer::address_of(account);
        primary_fungible_store::ensure_primary_store_exists(account_addr, state.metadata);
    }

    public entry fun register_store_for(admin: &signer, account: address) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        primary_fungible_store::ensure_primary_store_exists(account, state.metadata);
    }

    public entry fun register_stores_for(admin: &signer, accounts: vector<address>) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        let i = 0;
        let len = vector::length(&accounts);
        while (i < len) {
            let addr = *vector::borrow(&accounts, i);
            primary_fungible_store::ensure_primary_store_exists(addr, state.metadata);
            i = i + 1;
        };
    }

    public entry fun mint_to(admin: &signer, recipient: address, amount: u64) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        let store = ensure_store_exists(state, recipient, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(store);
        fungible_asset::mint_to(&state.mint_ref, store, amount);
    }

    public entry fun burn_from(admin: &signer, owner: address, amount: u64) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        let store = ensure_store_exists(state, owner, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(store);
        fungible_asset::burn_from(&state.burn_ref, store, amount);
    }

    public entry fun transfer_between(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        let from_store = ensure_store_exists(state, from, E_STORE_NOT_REGISTERED);
        let to_store = ensure_store_exists(state, to, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(from_store);
        ensure_not_frozen(to_store);
        fungible_asset::transfer_with_ref(&state.transfer_ref, from_store, to_store, amount);
    }

    public entry fun set_store_frozen(
        admin: &signer,
        account: address,
        frozen: bool
    ) acquires TokenState {
        ensure_owner(admin);
        ensure_token_initialized();
        let state = state_ref();
        let store = ensure_store_exists(state, account, E_STORE_NOT_REGISTERED);
        fungible_asset::set_frozen_flag(&state.transfer_ref, store, frozen);
    }

    public fun deposit_from_user(user: &signer, amount: u64) acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        let user_addr = signer::address_of(user);
        let user_store = ensure_store_exists(state, user_addr, E_STORE_NOT_REGISTERED);
        let treasury_store = ensure_store_exists(state, @lottery, E_TREASURY_STORE_NOT_REGISTERED);
        ensure_not_frozen(user_store);
        ensure_not_frozen(treasury_store);
        fungible_asset::transfer_with_ref(&state.transfer_ref, user_store, treasury_store, amount);
    }

    public(package) fun payout_from_treasury(recipient: address, amount: u64) acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        let treasury_store = ensure_store_exists(state, @lottery, E_TREASURY_STORE_NOT_REGISTERED);
        let recipient_store = ensure_store_exists(state, recipient, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(treasury_store);
        ensure_not_frozen(recipient_store);
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
        ensure_owner(admin);
        ensure_vaults_initialized();
        ensure_token_initialized();

        let state = state_ref();
        ensure_recipient_store_ready(state, treasury);
        ensure_recipient_store_ready(state, marketing);
        ensure_recipient_store_ready(state, community);
        ensure_recipient_store_ready(state, team);
        ensure_recipient_store_ready(state, partners);

        {
            let vaults = borrow_global_mut<Vaults>(@lottery);
            let previous_snapshot = build_recipients_snapshot(&vaults.recipients);
            vaults.recipients = VaultRecipients { treasury, marketing, community, team, partners };
            emit_recipients_event(option::some(previous_snapshot));
        };
    }

    #[view]
    public fun treasury_balance(): u64 acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        if (!primary_fungible_store::primary_store_exists(@lottery, state.metadata)) {
            0
        } else {
            primary_fungible_store::balance(@lottery, state.metadata)
        }
    }

    #[view]
    public fun balance_of(account: address): u64 acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        if (!primary_fungible_store::primary_store_exists(account, state.metadata)) {
            0
        } else {
            primary_fungible_store::balance(account, state.metadata)
        }
    }

    #[view]
    public fun store_registered(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = state_ref();
        primary_fungible_store::primary_store_exists(account, state.metadata)
    }

    #[view]
    public fun store_frozen(account: address): bool acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return false
        };
        let state = state_ref();
        if (!primary_fungible_store::primary_store_exists(account, state.metadata)) {
            false
        } else {
            let store = primary_fungible_store::primary_store(account, state.metadata);
            fungible_asset::is_frozen(store)
        }
    }

    #[view]
    public fun primary_store_address(account: address): address acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        let store = ensure_store_exists(state, account, E_STORE_NOT_REGISTERED);
        object::object_address(&store)
    }

    #[view]
    public fun total_supply(): u128 acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        let supply_opt = fungible_asset::supply(state.metadata);
        if (option::is_some(&supply_opt)) {
            *option::borrow(&supply_opt)
        } else {
            0
        }
    }

    #[view]
    public fun metadata_address(): address acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        metadata_address_internal(state)
    }

    #[view]
    public fun metadata_summary(): (string::String, string::String, u8, string::String, string::String) acquires TokenState {
        ensure_token_initialized();
        let state = state_ref();
        (
            fungible_asset::name(state.metadata),
            fungible_asset::symbol(state.metadata),
            fungible_asset::decimals(state.metadata),
            fungible_asset::icon_uri(state.metadata),
            fungible_asset::project_uri(state.metadata),
        )
    }

    #[view]
    public fun account_status(account: address): (bool, option::Option<address>, u64) acquires TokenState {
        if (!exists<TokenState>(@lottery)) {
            return (false, option::none(), 0)
        };

        let state = state_ref();
        if (!primary_fungible_store::primary_store_exists(account, state.metadata)) {
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

        let state = state_ref();
        if (!primary_fungible_store::primary_store_exists(account, state.metadata)) {
            return (false, false, option::none(), 0)
        };

        let store_address = primary_fungible_store::primary_store_address(account, state.metadata);
        let frozen = fungible_asset::is_frozen(primary_fungible_store::primary_store(account, state.metadata));
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

    #[view]
    public fun get_recipient_statuses(): (
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
    ) acquires Vaults {
        let recipients = if (exists<Vaults>(@lottery)) {
            let vaults = borrow_global<Vaults>(@lottery);
            vaults.recipients
        } else {
            default_recipients()
        };

        (
            build_recipient_status(recipients.treasury),
            build_recipient_status(recipients.marketing),
            build_recipient_status(recipients.community),
            build_recipient_status(recipients.team),
            build_recipient_status(recipients.partners),
        )
    }

    public(package) fun distribute_payout(winner: address, total_amount: u64): u64 acquires TokenState, Vaults {
        ensure_token_initialized();
        if (total_amount == 0) {
            return 0
        };

        let state = state_ref();
        let winner_store = ensure_store_exists(state, winner, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(winner_store);

        ensure_vaults_initialized();
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

        let treasury_store = ensure_store_exists(state, @lottery, E_TREASURY_STORE_NOT_REGISTERED);
        ensure_not_frozen(treasury_store);

        fungible_asset::transfer_with_ref(
            &state.transfer_ref,
            treasury_store,
            winner_store,
            winner_share,
        );

        transfer_share_if_needed(state, treasury_store, recipients.treasury, treasury_share);
        transfer_share_if_needed(state, treasury_store, recipients.marketing, marketing_share);
        transfer_share_if_needed(state, treasury_store, recipients.community, community_share);
        transfer_share_if_needed(state, treasury_store, recipients.team, team_share);
        transfer_share_if_needed(state, treasury_store, recipients.partners, partners_share);

        event::emit(JackpotDistributedEvent {
            winner,
            total_amount,
            winner_share,
            jackpot_share,
            prize_share,
            treasury_share,
            marketing_share,
            community_share,
            team_share,
            partners_share,
        });

        winner_share
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
        ensure_owner(admin);
        ensure_vaults_initialized();

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

    #[test_only]
    public fun recipient_status_fields_for_test(
        status: &VaultRecipientStatus
    ): (address, bool, bool, option::Option<address>, u64) {
        (
            status.account,
            status.registered,
            status.frozen,
            status.store,
            status.balance,
        )
    }

    #[test_only]
    public fun recipients_snapshot_fields_for_test(
        snapshot: &VaultRecipientsSnapshot
    ): (
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
        VaultRecipientStatus,
    ) {
        (
            snapshot.treasury,
            snapshot.marketing,
            snapshot.community,
            snapshot.team,
            snapshot.partners,
        )
    }

    #[test_only]
    public fun recipients_event_fields_for_test(
        event: &RecipientsUpdatedEvent
    ): (option::Option<VaultRecipientsSnapshot>, VaultRecipientsSnapshot) {
        (event.previous, event.next)
    }

    fun emit_recipients_event(
        previous: option::Option<VaultRecipientsSnapshot>
    ) acquires TokenState, Vaults {
        let vaults = borrow_global<Vaults>(@lottery);
        let next_snapshot = build_recipients_snapshot(&vaults.recipients);
        event::emit(RecipientsUpdatedEvent { previous, next: next_snapshot });
    }

    fun build_recipient_status(account: address): VaultRecipientStatus {
        let (registered, frozen, store_opt, balance) = account_extended_status(account);
        VaultRecipientStatus { account, registered, frozen, store: store_opt, balance }
    }

    fun build_recipients_snapshot(
        recipients: &VaultRecipients
    ): VaultRecipientsSnapshot {
        VaultRecipientsSnapshot {
            treasury: build_recipient_status(recipients.treasury),
            marketing: build_recipient_status(recipients.marketing),
            community: build_recipient_status(recipients.community),
            team: build_recipient_status(recipients.team),
            partners: build_recipient_status(recipients.partners),
        }
    }
}
