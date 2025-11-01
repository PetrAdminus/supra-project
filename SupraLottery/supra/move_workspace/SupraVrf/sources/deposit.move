module supra_addr::deposit {

    /// Registers an existing VRF 2.0 client in the upgraded dVRF 3.0 deposit contract
    /// and stores the chosen max gas parameters. The call is payable on-chain; in Move
    /// it expects the signer to attach the desired deposit separately via `depositFundClient`.
    native public entry fun migrateClient(sender: &signer, max_gas_price: u128, max_gas_limit: u128);

    /// Self-whitelists a client after migration. Supra expects camelCase identifiers.
    native public entry fun addClientToWhitelist(sender: &signer, max_gas_price: u128, max_gas_limit: u128);

    /// Updates the minimum balance threshold tracked by Supra for the client account.
    native public entry fun clientSettingMinimumBalance(sender: &signer, min_balance_limit_client: u128);

    /// Adds a consumer contract to the whitelist with dedicated callback gas configuration.
    native public entry fun addContractToWhitelist(
        sender: &signer,
        contract_address: address,
        callback_gas_price: u128,
        callback_gas_limit: u128,
    );

    /// Removes a consumer contract from the whitelist. Supra currently exposes a simple removal API.
    native public entry fun removeContractFromWhitelist(sender: &signer, contract_address: address);

    /// Deposits Supra coins into the client's balance (amount is provided in on-chain units).
    native public entry fun depositFundClient(sender: &signer, deposit_amount: u64);

    /// Withdraws Supra coins from the client's balance. Fails when pending VRF requests exist.
    native public entry fun withdrawFundClient(sender: &signer, withdraw_amount: u64);

    /// Adjusts the client's max gas price after onboarding.
    native public entry fun updateMaxGasPrice(sender: &signer, max_gas_price: u128);

    /// Adjusts the client's max gas limit after onboarding.
    native public entry fun updateMaxGasLimit(sender: &signer, max_gas_limit: u128);

    /// Adjusts callback gas price for a specific consumer contract.
    native public entry fun updateCallbackGasPrice(
        sender: &signer,
        contract_address: address,
        callback_gas_price: u128,
    );

    /// Adjusts callback gas limit for a specific consumer contract.
    native public entry fun updateCallbackGasLimit(
        sender: &signer,
        contract_address: address,
        callback_gas_limit: u128,
    );

    /// Computes the minimum balance requirement for given gas settings.
    native public fun getMinBalanceLimit(max_gas_price: u128, max_gas_limit: u128): u128;

    /// Returns the stored minimum balance limit for a client account.
    native public fun checkMinBalanceClient(client: address): u128;

    /// Returns the stored max gas price for a client account.
    native public fun checkMaxGasPriceClient(client: address): u128;

    /// Returns the stored max gas limit for a client account.
    native public fun checkMaxGasLimitClient(client: address): u128;

    /// Returns callback gas configuration for a whitelisted consumer contract.
    native public fun getContractDetails(contract_address: address): (u128, u128);

    /// Returns the current deposit balance for a client account.
    native public fun checkClientFund(client: address): u64;

    /// Indicates whether the client balance dropped below the minimum limit.
    native public fun isMinimumBalanceReached(client: address): bool;

    /// Counts the number of consumer contracts whitelisted by a client.
    native public fun countTotalWhitelistedContractByClient(client: address): u64;

    /// Lists all consumer contracts whitelisted by a client.
    native public fun listAllWhitelistedContractByClient(client: address): vector<address>;

    /// Returns subscription metadata stored by Supra. Exact layout is defined on-chain.
    native public fun getSubscriptionInfoByClient(client: address): vector<u8>;
}
