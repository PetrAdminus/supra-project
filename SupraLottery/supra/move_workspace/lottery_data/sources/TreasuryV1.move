module lottery_data::treasury_v1 {
    use std::option;
    use std::signer;

    use supra_framework::account;
    use supra_framework::event;
    use supra_framework::fungible_asset;
    use supra_framework::object;
    use supra_framework::primary_fungible_store;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_STORE_NOT_REGISTERED: u64 = 4;
    const E_TREASURY_STORE_NOT_REGISTERED: u64 = 5;
    const E_STORE_FROZEN: u64 = 6;
    const E_AUTOPURCHASE_CAP_OCCUPIED: u64 = 7;
    const E_LEGACY_CAP_OCCUPIED: u64 = 8;

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

    struct Vaults has key {
        config: VaultConfig,
        recipients: VaultRecipients,
        config_events: event::EventHandle<ConfigUpdatedEvent>,
        recipient_events: event::EventHandle<RecipientsUpdatedEvent>,
        jackpot_events: event::EventHandle<JackpotDistributedEvent>,
    }

    struct TokenState has key {
        metadata: object::Object<fungible_asset::Metadata>,
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef,
    }

    struct AutopurchaseTreasuryCap has store {}

    struct LegacyTreasuryCap has store {}

    struct TreasuryV1Control has key {
        admin: address,
        autopurchase_cap: option::Option<AutopurchaseTreasuryCap>,
        legacy_cap: option::Option<LegacyTreasuryCap>,
    }

    public entry fun init_vaults(caller: &signer, config: VaultConfig, recipients: VaultRecipients) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<Vaults>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            Vaults {
                config,
                recipients,
                config_events: account::new_event_handle<ConfigUpdatedEvent>(caller),
                recipient_events: account::new_event_handle<RecipientsUpdatedEvent>(caller),
                jackpot_events: account::new_event_handle<JackpotDistributedEvent>(caller),
            },
        );
    }

    public entry fun init_control(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<TreasuryV1Control>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            TreasuryV1Control {
                admin: caller_address,
                autopurchase_cap: option::some(AutopurchaseTreasuryCap {}),
                legacy_cap: option::some(LegacyTreasuryCap {}),
            },
        );
    }

    public entry fun init_token_state(
        caller: &signer,
        metadata: object::Object<fungible_asset::Metadata>,
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef,
    ) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_UNAUTHORIZED);
        assert!(!exists<TokenState>(caller_address), E_ALREADY_INITIALIZED);
        move_to(
            caller,
            TokenState { metadata, mint_ref, burn_ref, transfer_ref },
        );
    }

    public fun borrow_vaults(addr: address): &Vaults acquires Vaults {
        borrow_global<Vaults>(addr)
    }

    public fun borrow_vaults_mut(addr: address): &mut Vaults acquires Vaults {
        borrow_global_mut<Vaults>(addr)
    }

    public fun borrow_control(addr: address): &TreasuryV1Control acquires TreasuryV1Control {
        borrow_global<TreasuryV1Control>(addr)
    }

    public fun borrow_control_mut(addr: address): &mut TreasuryV1Control acquires TreasuryV1Control {
        borrow_global_mut<TreasuryV1Control>(addr)
    }

    public fun autopurchase_cap_available(control: &TreasuryV1Control): bool {
        option::is_some(&control.autopurchase_cap)
    }

    public fun legacy_cap_available(control: &TreasuryV1Control): bool {
        option::is_some(&control.legacy_cap)
    }

    public fun extract_autopurchase_cap(
        control: &mut TreasuryV1Control,
    ): option::Option<AutopurchaseTreasuryCap> {
        if (!option::is_some(&control.autopurchase_cap)) {
            return option::none<AutopurchaseTreasuryCap>();
        };
        let cap = option::extract(&mut control.autopurchase_cap);
        option::some(cap)
    }

    public fun restore_autopurchase_cap(
        control: &mut TreasuryV1Control,
        cap: AutopurchaseTreasuryCap,
    ) {
        if (option::is_some(&control.autopurchase_cap)) {
            abort E_AUTOPURCHASE_CAP_OCCUPIED;
        };
        option::fill(&mut control.autopurchase_cap, cap);
    }

    public fun extract_legacy_cap(control: &mut TreasuryV1Control): option::Option<LegacyTreasuryCap> {
        if (!option::is_some(&control.legacy_cap)) {
            return option::none<LegacyTreasuryCap>();
        };
        let cap = option::extract(&mut control.legacy_cap);
        option::some(cap)
    }

    public fun restore_legacy_cap(control: &mut TreasuryV1Control, cap: LegacyTreasuryCap) {
        if (option::is_some(&control.legacy_cap)) {
            abort E_LEGACY_CAP_OCCUPIED;
        };
        option::fill(&mut control.legacy_cap, cap);
    }

    public fun deposit_from_user(user: &signer, amount: u64) acquires TokenState {
        ensure_token_initialized();
        let state = borrow_global<TokenState>(@lottery);
        let user_addr = signer::address_of(user);
        let user_store = ensure_store_exists(&state, user_addr, E_STORE_NOT_REGISTERED);
        let treasury_store = ensure_store_exists(&state, @lottery, E_TREASURY_STORE_NOT_REGISTERED);
        ensure_not_frozen(user_store);
        ensure_not_frozen(treasury_store);
        fungible_asset::transfer_with_ref(&state.transfer_ref, user_store, treasury_store, amount);
    }

    public fun payout_with_autopurchase_cap(
        _cap: &AutopurchaseTreasuryCap,
        recipient: address,
        amount: u64,
    ) acquires TokenState {
        payout_from_treasury(recipient, amount);
    }

    fun payout_from_treasury(recipient: address, amount: u64) acquires TokenState {
        ensure_token_initialized();
        let state = borrow_global<TokenState>(@lottery);
        let treasury_store = ensure_store_exists(&state, @lottery, E_TREASURY_STORE_NOT_REGISTERED);
        let recipient_store = ensure_store_exists(&state, recipient, E_STORE_NOT_REGISTERED);
        ensure_not_frozen(treasury_store);
        ensure_not_frozen(recipient_store);
        fungible_asset::transfer_with_ref(&state.transfer_ref, treasury_store, recipient_store, amount);
    }

    fun ensure_token_initialized() {
        if (!exists<TokenState>(@lottery)) {
            abort E_NOT_INITIALIZED;
        };
    }

    fun ensure_store_exists(
        state: &TokenState,
        account: address,
        error_code: u64,
    ): object::Object<fungible_asset::FungibleStore> {
        let metadata = state.metadata;
        if (!primary_fungible_store::primary_store_exists(account, metadata)) {
            abort error_code;
        };
        primary_fungible_store::primary_store(account, metadata)
    }

    fun ensure_not_frozen(store: object::Object<fungible_asset::FungibleStore>) {
        if (fungible_asset::is_frozen(store)) {
            abort E_STORE_FROZEN;
        };
    }
    public fun borrow_token_state(addr: address): &TokenState acquires TokenState {
        borrow_global<TokenState>(addr)
    }

    public fun borrow_token_state_mut(addr: address): &mut TokenState acquires TokenState {
        borrow_global_mut<TokenState>(addr)
    }

    public fun emit_config(vaults: &mut Vaults) {
        let config = &vaults.config;
        event::emit_event(
            &mut vaults.config_events,
            ConfigUpdatedEvent {
                bp_jackpot: config.bp_jackpot,
                bp_prize: config.bp_prize,
                bp_treasury: config.bp_treasury,
                bp_marketing: config.bp_marketing,
                bp_community: config.bp_community,
                bp_team: config.bp_team,
                bp_partners: config.bp_partners,
            },
        );
    }

    public fun emit_recipients(vaults: &mut Vaults, previous: option::Option<VaultRecipientsSnapshot>) {
        let snapshot = VaultRecipientsSnapshot {
            treasury: VaultRecipientStatus {
                account: vaults.recipients.treasury,
                registered: true,
                frozen: false,
                store: option::none<address>(),
                balance: 0,
            },
            marketing: VaultRecipientStatus {
                account: vaults.recipients.marketing,
                registered: true,
                frozen: false,
                store: option::none<address>(),
                balance: 0,
            },
            community: VaultRecipientStatus {
                account: vaults.recipients.community,
                registered: true,
                frozen: false,
                store: option::none<address>(),
                balance: 0,
            },
            team: VaultRecipientStatus {
                account: vaults.recipients.team,
                registered: true,
                frozen: false,
                store: option::none<address>(),
                balance: 0,
            },
            partners: VaultRecipientStatus {
                account: vaults.recipients.partners,
                registered: true,
                frozen: false,
                store: option::none<address>(),
                balance: 0,
            },
        };
        event::emit_event(&mut vaults.recipient_events, RecipientsUpdatedEvent { previous, next: snapshot });
    }
}
