# Инвентаризация структур Move

> Последнее обновление: 2025-12-26 (UTC)

Документ автоматически собирает все структуры, ресурсы и события из текущего Move-workspace SupraLottery. Данные используются как исходная точка для планирования миграции в новую архитектуру.

**Как читать документ:** разделы разбиты по пакетам и модулям. Для каждой структуры указаны способности (`has …`) и ключевые поля. Категория помогает быстро отличить ресурсы (`Ресурс`), события (`Событие`) и вспомогательные структуры (`Структура`).

**Как обновлять:** запустите `python docs/architecture/tools/export_move_inventory.py` из корня репозитория. При необходимости можно указать иные пути через аргументы `--workspace-root` и `--output`. Для автоматизированных сверок доступен экспорт в JSON: добавьте `--json-output docs/architecture/move_struct_inventory.json` (структура: пакеты → модули → список структур с категориями, способностями и полями).

## Пакет `SupraVrf`

### Модуль `supra_addr::deposit` (`SupraLottery/supra/move_workspace/SupraVrf/sources/deposit.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `supra_addr::supra_vrf` (`SupraLottery/supra/move_workspace/SupraVrf/sources/supra_vrf.move`)

> В этом модуле структур с `struct ... has ...` не найдено.


## Пакет `lottery_core`

### Модуль `lottery_core::core_main_v2` (`SupraLottery/supra/move_workspace/lottery_core/sources/Lottery.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `ClientWhitelistSnapshot` | copy, drop, store | `max_gas_price`: u128<br>`max_gas_limit`: u128<br>`min_balance_limit`: u128 |
| Структура | `ConsumerWhitelistSnapshot` | copy, drop, store | `callback_gas_price`: u128<br>`callback_gas_limit`: u128 |
| Структура | `VrfRequestConfig` | copy, drop, store | `rng_count`: u8<br>`num_confirmations`: u64<br>`client_seed`: u64 |
| Структура | `WhitelistStatus` | copy, drop | `aggregator`: option::Option<address><br>`consumers`: vector<address> |
| Ресурс | `LotteryData` | key | `tickets`: vector<address><br>`jackpot_amount`: u64<br>`draw_scheduled`: bool<br>`next_ticket_id`: u64<br>`pending_request`: option::Option<u64><br>`max_gas_fee`: u64<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`verification_gas_value`: u128<br>`rng_request_count`: u64<br>`rng_response_count`: u64<br>`last_request_payload_hash`: option::Option<vector<u8>><br>`last_requester`: option::Option<address><br>`next_client_seed`: u64<br>`whitelisted_consumers`: vector<address><br>`whitelisted_callback_sender`: option::Option<address><br>`client_whitelist_snapshot`: option::Option<ClientWhitelistSnapshot><br>`consumer_whitelist_snapshot`: option::Option<ConsumerWhitelistSnapshot><br>`vrf_request_config`: option::Option<VrfRequestConfig><br>`ticket_price`: u64<br>`auto_draw_threshold`: u64 |
| Событие | `TicketBought` | store, copy, drop | `buyer`: address<br>`ticket_id`: u64<br>`amount`: u64 |
| Событие | `WinnerSelected` | store, copy, drop | `winner`: address<br>`prize`: u64 |
| Событие | `LotteryConfigUpdatedEvent` | store, copy, drop | `ticket_price`: u64<br>`auto_draw_threshold`: u64 |
| Событие | `SubscriptionConfiguredEvent` | drop, store, copy | `min_balance`: u64<br>`per_request_fee`: u64<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`verification_gas_value`: u128<br>`initial_deposit`: u64<br>`callback_sender`: option::Option<address><br>`consumer_count`: u64<br>`pending_request`: option::Option<u64> |
| Событие | `SubscriptionContractRemovedEvent` | drop, store, copy | `admin`: address<br>`callback_sender`: option::Option<address><br>`consumer_count`: u64<br>`pending_request`: bool |
| Событие | `MinimumBalanceUpdatedEvent` | drop, store, copy | `min_balance`: u64<br>`per_request_fee`: u64<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`verification_gas_value`: u128<br>`callback_sender`: option::Option<address><br>`consumer_count`: u64<br>`pending_request`: option::Option<u64> |
| Событие | `ClientWhitelistRecordedEvent` | drop, store, copy | `max_gas_price`: u128<br>`max_gas_limit`: u128<br>`min_balance_limit`: u128 |
| Событие | `ConsumerWhitelistSnapshotRecordedEvent` | drop, store, copy | `callback_gas_price`: u128<br>`callback_gas_limit`: u128 |
| Событие | `VrfRequestConfigUpdatedEvent` | drop, store, copy | `rng_count`: u8<br>`num_confirmations`: u64<br>`client_seed`: u64 |
| Событие | `GasConfigUpdatedEvent` | drop, store, copy | `max_gas_price`: u128<br>`max_gas_limit`: u128<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`verification_gas_value`: u128<br>`per_request_fee`: u64<br>`callback_sender`: option::Option<address><br>`consumer_count`: u64<br>`pending_request`: option::Option<u64> |
| Событие | `AggregatorWhitelistedEvent` | drop, store, copy | `aggregator`: address |
| Событие | `AggregatorRevokedEvent` | drop, store, copy | `aggregator`: address |
| Событие | `ConsumerWhitelistedEvent` | drop, store, copy | `consumer`: address |
| Событие | `ConsumerRemovedEvent` | drop, store, copy | `consumer`: address |
| Событие | `WhitelistSnapshotUpdatedEvent` | drop, store | `aggregator`: option::Option<address><br>`consumers`: vector<address> |
| Событие | `DrawRequestedEvent` | drop, store, copy | `nonce`: u64<br>`client_seed`: u64<br>`request_hash`: vector<u8><br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`requester`: address<br>`callback_address`: address<br>`callback_module`: vector<u8><br>`callback_function`: vector<u8><br>`rng_count`: u8<br>`num_confirmations`: u64<br>`callback_sender`: address<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`verification_gas_value`: u128 |
| Событие | `DrawHandledEvent` | drop, store, copy | `nonce`: u64<br>`success`: bool<br>`request_hash`: vector<u8><br>`requester`: address<br>`callback_sender`: address<br>`client_seed`: u64<br>`rng_count`: u8<br>`num_confirmations`: u64<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`verification_gas_value`: u128<br>`randomness`: vector<u256> |
| Событие | `FundsWithdrawnEvent` | drop, store, copy | `admin`: address<br>`amount`: u64 |
| Структура | `LotteryStatus` | copy, drop | `ticket_count`: u64<br>`draw_scheduled`: bool<br>`pending_request`: bool<br>`jackpot_amount`: u64<br>`rng_request_count`: u64<br>`rng_response_count`: u64 |
| Структура | `PendingRequestView` | copy, drop | `nonce`: u64<br>`requester`: address<br>`request_hash`: vector<u8><br>`client_seed`: u64<br>`rng_count`: u8<br>`num_confirmations`: u64<br>`callback_sender`: address<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`verification_gas_value`: u128 |
| Структура | `CallbackRequest` | copy, drop, store | `nonce`: u64<br>`client_seed`: u64<br>`requester`: address<br>`rng_count`: u8<br>`num_confirmations`: u64<br>`callback_address`: address<br>`callback_module`: vector<u8><br>`callback_function`: vector<u8><br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`verification_gas_value`: u128 |
| Структура | `ClientWhitelistSnapshotView` | copy, drop | `max_gas_price`: u128<br>`max_gas_limit`: u128<br>`min_balance_limit`: u128 |
| Структура | `ConsumerWhitelistSnapshotView` | copy, drop | `callback_gas_price`: u128<br>`callback_gas_limit`: u128 |
| Структура | `VrfRequestConfigView` | copy, drop | `rng_count`: u8<br>`num_confirmations`: u64<br>`client_seed`: u64 |

### Модуль `lottery_core::core_instances` (`SupraLottery/supra/move_workspace/lottery_core/sources/LotteryInstances.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `InstancesExportCap` | store | — |
| Ресурс | `CoreControl` | key | `export_cap`: option::Option<InstancesExportCap> |
| Структура | `InstanceStats` | copy, drop, store | `tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Структура | `InstanceState` | store | `info`: registry::LotteryInfo<br>`tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Ресурс | `LotteryCollection` | key | `admin`: address<br>`hub`: address<br>`instances`: table::Table<u64, InstanceState><br>`lottery_ids`: vector<u64><br>`create_events`: event::EventHandle<LotteryInstanceCreatedEvent><br>`blueprint_events`: event::EventHandle<LotteryInstanceBlueprintSyncedEvent><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`hub_events`: event::EventHandle<HubAddressUpdatedEvent><br>`status_events`: event::EventHandle<LotteryInstanceStatusUpdatedEvent><br>`snapshot_events`: event::EventHandle<LotteryInstancesSnapshotUpdatedEvent> |
| Событие | `LotteryInstanceCreatedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Событие | `LotteryInstanceBlueprintSyncedEvent` | drop, store, copy | `lottery_id`: u64<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `HubAddressUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `LotteryInstanceStatusUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`active`: bool |
| Структура | `LotteryInstanceSnapshot` | copy, drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16<br>`tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Структура | `LotteryInstancesSnapshot` | copy, drop, store | `admin`: address<br>`hub`: address<br>`instances`: vector<LotteryInstanceSnapshot> |
| Событие | `LotteryInstancesSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`hub`: address<br>`snapshot`: LotteryInstanceSnapshot |

### Модуль `lottery_core::core_rounds` (`SupraLottery/supra/move_workspace/lottery_core/sources/LotteryRounds.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `HistoryWriterCap` | store | — |
| Структура | `AutopurchaseRoundCap` | store | — |
| Структура | `RoundState` | store | `tickets`: vector<address><br>`draw_scheduled`: bool<br>`next_ticket_id`: u64<br>`pending_request`: option::Option<u64> |
| Ресурс | `RoundCollection` | key | `admin`: address<br>`rounds`: table::Table<u64, RoundState><br>`lottery_ids`: vector<u64><br>`ticket_events`: event::EventHandle<TicketPurchasedEvent><br>`schedule_events`: event::EventHandle<DrawScheduleUpdatedEvent><br>`reset_events`: event::EventHandle<RoundResetEvent><br>`request_events`: event::EventHandle<DrawRequestIssuedEvent><br>`fulfill_events`: event::EventHandle<DrawFulfilledEvent><br>`snapshot_events`: event::EventHandle<RoundSnapshotUpdatedEvent> |
| Событие | `TicketPurchasedEvent` | drop, store, copy | `lottery_id`: u64<br>`ticket_id`: u64<br>`buyer`: address<br>`amount`: u64 |
| Событие | `DrawScheduleUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`draw_scheduled`: bool |
| Событие | `RoundResetEvent` | drop, store, copy | `lottery_id`: u64<br>`tickets_cleared`: u64 |
| Событие | `DrawRequestIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64 |
| Событие | `DrawFulfilledEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`random_bytes`: vector<u8><br>`prize_amount`: u64<br>`payload`: vector<u8> |
| Структура | `RoundSnapshot` | copy, drop, store | `ticket_count`: u64<br>`draw_scheduled`: bool<br>`has_pending_request`: bool<br>`next_ticket_id`: u64<br>`pending_request_id`: option::Option<u64> |
| Событие | `RoundSnapshotUpdatedEvent` | copy, drop, store | `lottery_id`: u64<br>`snapshot`: RoundSnapshot |
| Структура | `PendingHistoryRecord` | drop, store | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8> |
| Ресурс | `HistoryQueue` | key | `pending`: vector<PendingHistoryRecord> |
| Структура | `PendingPurchaseRecord` | drop, store | `lottery_id`: u64<br>`buyer`: address<br>`ticket_count`: u64<br>`paid_amount`: u64 |
| Ресурс | `PurchaseQueue` | key | `pending`: vector<PendingPurchaseRecord> |
| Ресурс | `CoreControl` | key | `admin`: address<br>`history_cap`: option::Option<HistoryWriterCap><br>`autopurchase_cap`: option::Option<AutopurchaseRoundCap> |

### Модуль `lottery_core::core_operators` (`SupraLottery/supra/move_workspace/lottery_core/sources/Operators.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `LotteryOperators` | key | `admin`: address<br>`entries`: table::Table<u64, LotteryOperatorEntry><br>`lottery_ids`: vector<u64><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`owner_events`: event::EventHandle<OwnerUpdatedEvent><br>`grant_events`: event::EventHandle<OperatorGrantedEvent><br>`revoke_events`: event::EventHandle<OperatorRevokedEvent><br>`snapshot_events`: event::EventHandle<OperatorSnapshotUpdatedEvent> |
| Структура | `LotteryOperatorEntry` | store | `owner`: address<br>`operators`: table::Table<address, bool><br>`operator_list`: vector<address> |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `OwnerUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`previous`: option::Option<address><br>`next`: option::Option<address> |
| Событие | `OperatorGrantedEvent` | drop, store, copy | `lottery_id`: u64<br>`operator`: address<br>`granted_by`: address |
| Событие | `OperatorRevokedEvent` | drop, store, copy | `lottery_id`: u64<br>`operator`: address<br>`revoked_by`: address |
| Событие | `OperatorSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: option::Option<address><br>`operators`: vector<address> |
| Структура | `OperatorSnapshot` | copy, drop, store | `owner`: option::Option<address><br>`operators`: vector<address> |

### Модуль `lottery_core::core_treasury_v1` (`SupraLottery/supra/move_workspace/lottery_core/sources/Treasury.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `AutopurchaseTreasuryCap` | store | — |
| Структура | `LegacyTreasuryCap` | store | — |
| Структура | `VaultConfig` | copy, drop, store | `bp_jackpot`: u64<br>`bp_prize`: u64<br>`bp_treasury`: u64<br>`bp_marketing`: u64<br>`bp_community`: u64<br>`bp_team`: u64<br>`bp_partners`: u64 |
| Структура | `VaultRecipients` | copy, drop, store | `treasury`: address<br>`marketing`: address<br>`community`: address<br>`team`: address<br>`partners`: address |
| Ресурс | `Vaults` | key | `config`: VaultConfig<br>`recipients`: VaultRecipients |
| Структура | `VaultRecipientStatus` | copy, drop, store | `account`: address<br>`registered`: bool<br>`frozen`: bool<br>`store`: option::Option<address><br>`balance`: u64 |
| Структура | `VaultRecipientsSnapshot` | copy, drop, store | `treasury`: VaultRecipientStatus<br>`marketing`: VaultRecipientStatus<br>`community`: VaultRecipientStatus<br>`team`: VaultRecipientStatus<br>`partners`: VaultRecipientStatus |
| Событие | `ConfigUpdatedEvent` | drop, store, copy | `bp_jackpot`: u64<br>`bp_prize`: u64<br>`bp_treasury`: u64<br>`bp_marketing`: u64<br>`bp_community`: u64<br>`bp_team`: u64<br>`bp_partners`: u64 |
| Событие | `RecipientsUpdatedEvent` | drop, store, copy | `previous`: option::Option<VaultRecipientsSnapshot><br>`next`: VaultRecipientsSnapshot |
| Событие | `JackpotDistributedEvent` | drop, store, copy | `winner`: address<br>`total_amount`: u64<br>`winner_share`: u64<br>`jackpot_share`: u64<br>`prize_share`: u64<br>`treasury_share`: u64<br>`marketing_share`: u64<br>`community_share`: u64<br>`team_share`: u64<br>`partners_share`: u64 |
| Ресурс | `TokenState` | key | `metadata`: object::Object<fungible_asset::Metadata><br>`mint_ref`: fungible_asset::MintRef<br>`burn_ref`: fungible_asset::BurnRef<br>`transfer_ref`: fungible_asset::TransferRef |
| Ресурс | `CoreControl` | key | `admin`: address<br>`autopurchase_cap`: option::Option<AutopurchaseTreasuryCap><br>`legacy_cap`: option::Option<LegacyTreasuryCap> |

### Модуль `lottery_core::core_treasury_multi` (`SupraLottery/supra/move_workspace/lottery_core/sources/TreasuryMulti.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryShareConfig` | copy, drop, store | `prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Структура | `LotteryPool` | copy, drop, store | `prize_balance`: u64<br>`operations_balance`: u64 |
| Ресурс | `TreasuryState` | key | `admin`: address<br>`jackpot_recipient`: address<br>`operations_recipient`: address<br>`jackpot_balance`: u64<br>`configs`: table::Table<u64, LotteryShareConfig><br>`pools`: table::Table<u64, LotteryPool><br>`lottery_ids`: vector<u64><br>`config_events`: event::EventHandle<LotteryConfigUpdatedEvent><br>`allocation_events`: event::EventHandle<AllocationRecordedEvent><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`recipient_events`: event::EventHandle<RecipientsUpdatedEvent><br>`prize_events`: event::EventHandle<PrizePaidEvent><br>`operations_events`: event::EventHandle<OperationsWithdrawnEvent><br>`operations_income_events`: event::EventHandle<OperationsIncomeRecordedEvent><br>`operations_bonus_events`: event::EventHandle<OperationsBonusPaidEvent><br>`jackpot_events`: event::EventHandle<JackpotPaidEvent> |
| Структура | `MultiTreasuryCap` | store | `scope`: u64 |
| Ресурс | `CoreControl` | key | `admin`: address<br>`jackpot_cap`: option::Option<MultiTreasuryCap><br>`referrals_cap`: option::Option<MultiTreasuryCap><br>`store_cap`: option::Option<MultiTreasuryCap><br>`vip_cap`: option::Option<MultiTreasuryCap> |
| Структура | `RecipientStatus` | copy, drop, store | `recipient`: address<br>`registered`: bool<br>`frozen`: bool<br>`store`: option::Option<address><br>`balance`: u64 |
| Событие | `LotteryConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Событие | `AllocationRecordedEvent` | drop, store, copy | `lottery_id`: u64<br>`total_amount`: u64<br>`prize_amount`: u64<br>`jackpot_amount`: u64<br>`operations_amount`: u64 |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `RecipientsUpdatedEvent` | drop, store, copy | `previous_jackpot`: option::Option<RecipientStatus><br>`previous_operations`: option::Option<RecipientStatus><br>`next_jackpot`: RecipientStatus<br>`next_operations`: RecipientStatus |
| Событие | `PrizePaidEvent` | drop, store, copy | `lottery_id`: u64<br>`winner`: address<br>`amount`: u64 |
| Событие | `OperationsWithdrawnEvent` | drop, store, copy | `lottery_id`: u64<br>`recipient`: address<br>`amount`: u64 |
| Событие | `OperationsIncomeRecordedEvent` | drop, store, copy | `lottery_id`: u64<br>`amount`: u64<br>`source`: vector<u8> |
| Событие | `OperationsBonusPaidEvent` | drop, store, copy | `lottery_id`: u64<br>`recipient`: address<br>`amount`: u64 |
| Событие | `JackpotPaidEvent` | drop, store, copy | `recipient`: address<br>`amount`: u64 |
| Структура | `LotterySummary` | copy, drop, store | `config`: LotteryShareConfig<br>`pool`: LotteryPool |


## Пакет `lottery_data`

### Модуль `lottery_data::automation` (`SupraLottery/supra/move_workspace/lottery_data/sources/Automation.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `AutomationState` | store | `allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`pending_action_hash`: vector<u8><br>`pending_execute_after`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |
| Структура | `LegacyAutomationBot` | drop, store | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`pending_action_hash`: vector<u8><br>`pending_execute_after`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |
| Ресурс | `AutomationRegistry` | key | `admin`: address<br>`bots`: table::Table<address, AutomationState><br>`register_events`: event::EventHandle<AutomationBotRegisteredEvent><br>`rotate_events`: event::EventHandle<AutomationBotRotatedEvent><br>`remove_events`: event::EventHandle<AutomationBotRemovedEvent><br>`dry_run_events`: event::EventHandle<AutomationActionPlannedEvent><br>`tick_events`: event::EventHandle<AutomationActionTickEvent><br>`rejected_events`: event::EventHandle<AutomationActionRejectedEvent><br>`error_events`: event::EventHandle<AutomationErrorEvent> |
| Ресурс | `AutomationCap` | key | `operator`: address<br>`cron_spec`: vector<u8> |
| Структура | `AutomationBotStatus` | drop, store | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`pending_action_hash`: vector<u8><br>`pending_execute_after`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |
| Событие | `AutomationBotRegisteredEvent` | drop, store, copy | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8> |
| Событие | `AutomationBotRotatedEvent` | drop, store, copy | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8> |
| Событие | `AutomationBotRemovedEvent` | drop, store, copy | `operator`: address |
| Событие | `AutomationActionPlannedEvent` | drop, store, copy | `operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`executes_after_ts`: u64 |
| Событие | `AutomationActionTickEvent` | drop, store, copy | `operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`timestamp`: u64<br>`success`: bool<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64 |
| Событие | `AutomationActionRejectedEvent` | drop, store, copy | `operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`reason_code`: u64 |
| Событие | `AutomationErrorEvent` | drop, store, copy | `operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`timestamp`: u64<br>`error_code`: u64 |

### Модуль `lottery_data::cancellations` (`SupraLottery/supra/move_workspace/lottery_data/sources/Cancellations.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacyCancellationRecord` | drop, store | `lottery_id`: u64<br>`reason_code`: u8<br>`canceled_ts`: u64<br>`previous_status`: u8<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`jackpot_locked`: u64<br>`pending_tickets_cleared`: u64 |
| Структура | `CancellationRecord` | copy, drop, store | `reason_code`: u8<br>`canceled_ts`: u64<br>`previous_status`: u8<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`jackpot_locked`: u64<br>`pending_tickets_cleared`: u64 |
| Событие | `LotteryCanceledEvent` | drop, store, copy | `lottery_id`: u64<br>`reason_code`: u8<br>`canceled_ts`: u64<br>`previous_status`: u8<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`jackpot_locked`: u64<br>`pending_tickets_cleared`: u64 |
| Ресурс | `CancellationLedger` | key | `admin`: address<br>`records`: table::Table<u64, CancellationRecord><br>`events`: event::EventHandle<LotteryCanceledEvent> |

### Модуль `lottery_data::instances` (`SupraLottery/supra/move_workspace/lottery_data/sources/Instances.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacyInstanceRecord` | drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery_address`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16<br>`tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Структура | `InstanceRecord` | store | `owner`: address<br>`lottery_address`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16<br>`tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Структура | `InstanceSnapshot` | copy, drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery_address`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16<br>`tickets_sold`: u64<br>`jackpot_accumulated`: u64<br>`active`: bool |
| Ресурс | `InstanceControl` | key | `admin`: address<br>`export_cap`: option::Option<InstancesExportCap> |
| Структура | `InstancesExportCap` | store | — |
| Событие | `LotteryInstanceCreatedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address<br>`lottery_address`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Событие | `LotteryInstanceBlueprintSyncedEvent` | drop, store, copy | `lottery_id`: u64<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `HubAddressUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `LotteryInstanceStatusUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`active`: bool |
| Событие | `LotteryInstanceOwnerUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`previous`: option::Option<address><br>`next`: address |
| Событие | `LotteryInstancesSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`hub`: address<br>`snapshot`: InstanceSnapshot |
| Ресурс | `InstanceRegistry` | key | `admin`: address<br>`hub`: address<br>`instances`: table::Table<u64, InstanceRecord><br>`lottery_ids`: vector<u64><br>`create_events`: event::EventHandle<LotteryInstanceCreatedEvent><br>`blueprint_events`: event::EventHandle<LotteryInstanceBlueprintSyncedEvent><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`hub_events`: event::EventHandle<HubAddressUpdatedEvent><br>`status_events`: event::EventHandle<LotteryInstanceStatusUpdatedEvent><br>`owner_events`: event::EventHandle<LotteryInstanceOwnerUpdatedEvent><br>`snapshot_events`: event::EventHandle<LotteryInstancesSnapshotUpdatedEvent> |

### Модуль `lottery_data::jackpot` (`SupraLottery/supra/move_workspace/lottery_data/sources/Jackpot.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `JackpotRuntime` | copy, drop, store | `tickets`: vector<address><br>`draw_scheduled`: bool<br>`pending_request`: option::Option<u64><br>`pending_payload`: option::Option<vector<u8>> |
| Структура | `JackpotSnapshot` | copy, drop, store | `lottery_id`: u64<br>`ticket_count`: u64<br>`draw_scheduled`: bool<br>`has_pending_request`: bool<br>`pending_request_id`: option::Option<u64> |
| Событие | `JackpotTicketGrantedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`ticket_index`: u64 |
| Событие | `JackpotScheduleUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`draw_scheduled`: bool |
| Событие | `JackpotRequestIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64<br>`payload`: vector<u8> |
| Событие | `JackpotFulfilledEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8> |
| Событие | `JackpotSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`snapshot`: JackpotSnapshot |
| Ресурс | `JackpotRegistry` | key | `admin`: address<br>`jackpots`: table::Table<u64, JackpotRuntime><br>`lottery_ids`: vector<u64><br>`ticket_events`: event::EventHandle<JackpotTicketGrantedEvent><br>`schedule_events`: event::EventHandle<JackpotScheduleUpdatedEvent><br>`request_events`: event::EventHandle<JackpotRequestIssuedEvent><br>`fulfill_events`: event::EventHandle<JackpotFulfilledEvent><br>`snapshot_events`: event::EventHandle<JackpotSnapshotUpdatedEvent> |

### Модуль `lottery_data::lottery_state` (`SupraLottery/supra/move_workspace/lottery_data/sources/LotteryState.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `ClientWhitelistSnapshot` | copy, drop, store | `max_gas_price`: u128<br>`max_gas_limit`: u128<br>`min_balance_limit`: u128 |
| Структура | `ConsumerWhitelistSnapshot` | copy, drop, store | `callback_gas_price`: u128<br>`callback_gas_limit`: u128 |
| Структура | `VrfRequestConfig` | copy, drop, store | `rng_count`: u8<br>`num_confirmations`: u64<br>`client_seed`: u64 |
| Структура | `TicketLedger` | copy, drop, store | `participants`: vector<address><br>`next_ticket_id`: u64 |
| Структура | `DrawSettings` | copy, drop, store | `draw_scheduled`: bool<br>`auto_draw_threshold`: u64 |
| Структура | `PendingRequest` | copy, drop, store | `request_id`: option::Option<u64><br>`last_request_payload_hash`: option::Option<vector<u8>><br>`last_requester`: option::Option<address> |
| Структура | `GasBudget` | copy, drop, store | `max_fee`: u64<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`verification_gas_value`: u128 |
| Структура | `VrfStats` | copy, drop, store | `request_count`: u64<br>`response_count`: u64<br>`next_client_seed`: u64 |
| Структура | `WhitelistState` | copy, drop, store | `callback_sender`: option::Option<address><br>`consumers`: vector<address><br>`client_snapshot`: option::Option<ClientWhitelistSnapshot><br>`consumer_snapshot`: option::Option<ConsumerWhitelistSnapshot> |
| Структура | `LotteryRuntime` | copy, drop, store | `ticket_price`: u64<br>`jackpot_amount`: u64<br>`tickets`: TicketLedger<br>`draw`: DrawSettings<br>`pending_request`: PendingRequest<br>`gas`: GasBudget<br>`vrf_stats`: VrfStats<br>`whitelist`: WhitelistState<br>`request_config`: option::Option<VrfRequestConfig> |
| Структура | `LegacyLotteryRuntime` | drop, store | `lottery_id`: u64<br>`ticket_price`: u64<br>`jackpot_amount`: u64<br>`participants`: vector<address><br>`next_ticket_id`: u64<br>`draw_scheduled`: bool<br>`auto_draw_threshold`: u64<br>`pending_request_id`: option::Option<u64><br>`last_request_payload_hash`: option::Option<vector<u8>><br>`last_requester`: option::Option<address><br>`gas`: GasBudget<br>`vrf_stats`: VrfStats<br>`whitelist`: WhitelistState<br>`request_config`: option::Option<VrfRequestConfig> |
| Событие | `LotterySnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`ticket_price`: u64<br>`jackpot_amount`: u64<br>`draw_scheduled`: bool<br>`auto_draw_threshold`: u64<br>`ticket_count`: u64<br>`pending_request`: bool |
| Событие | `VrfGasBudgetUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`max_fee`: u64<br>`max_gas_price`: u128<br>`max_gas_limit`: u128<br>`callback_gas_price`: u128<br>`callback_gas_limit`: u128<br>`verification_gas_value`: u128 |
| Событие | `VrfWhitelistUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`callback_sender`: option::Option<address><br>`consumer_count`: u64<br>`client_snapshot_recorded`: bool<br>`consumer_snapshot_recorded`: bool |
| Событие | `VrfRequestConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`configured`: bool<br>`rng_count`: u8<br>`num_confirmations`: u64<br>`client_seed`: u64<br>`next_client_seed`: u64 |
| Ресурс | `LotteryState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryRuntime><br>`lottery_ids`: vector<u64><br>`snapshot_events`: event::EventHandle<LotterySnapshotUpdatedEvent><br>`vrf_gas_events`: event::EventHandle<VrfGasBudgetUpdatedEvent><br>`vrf_whitelist_events`: event::EventHandle<VrfWhitelistUpdatedEvent><br>`vrf_request_events`: event::EventHandle<VrfRequestConfigUpdatedEvent> |

### Модуль `lottery_data::operators` (`SupraLottery/supra/move_workspace/lottery_data/sources/Operators.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacyOperatorRecord` | drop, store | `lottery_id`: u64<br>`owner`: option::Option<address><br>`operators`: vector<address> |
| Структура | `LotteryOperatorEntry` | store | `owner`: option::Option<address><br>`operators`: table::Table<address, bool><br>`operator_list`: vector<address> |
| Структура | `OperatorSnapshot` | copy, drop, store | `owner`: option::Option<address><br>`operators`: vector<address> |
| Ресурс | `OperatorRegistry` | key | `admin`: address<br>`entries`: table::Table<u64, LotteryOperatorEntry><br>`lottery_ids`: vector<u64><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`owner_events`: event::EventHandle<OwnerUpdatedEvent><br>`grant_events`: event::EventHandle<OperatorGrantedEvent><br>`revoke_events`: event::EventHandle<OperatorRevokedEvent><br>`snapshot_events`: event::EventHandle<OperatorSnapshotUpdatedEvent> |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `OwnerUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`previous`: option::Option<address><br>`next`: option::Option<address> |
| Событие | `OperatorGrantedEvent` | drop, store, copy | `lottery_id`: u64<br>`operator`: address<br>`granted_by`: address |
| Событие | `OperatorRevokedEvent` | drop, store, copy | `lottery_id`: u64<br>`operator`: address<br>`revoked_by`: address |
| Событие | `OperatorSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: option::Option<address><br>`operators`: vector<address> |

### Модуль `lottery_data::payouts` (`SupraLottery/supra/move_workspace/lottery_data/sources/Payouts.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `PayoutRecord` | copy, drop, store | `payout_id`: u64<br>`lottery_id`: u64<br>`round_number`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`amount`: u64<br>`status`: u8<br>`randomness_hash`: vector<u8><br>`payload_hash`: vector<u8> |
| Структура | `LotteryPayoutState` | store | `round_number`: u64<br>`pending_count`: u64<br>`paid_count`: u64<br>`refunded_count`: u64<br>`payouts`: table::Table<u64, PayoutRecord><br>`payout_ids`: vector<u64> |
| Структура | `LegacyPayoutRecord` | drop, store | `payout_id`: u64<br>`lottery_id`: u64<br>`round_number`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`amount`: u64<br>`status`: u8<br>`randomness_hash`: vector<u8><br>`payload_hash`: vector<u8><br>`refund_recipient`: address<br>`refund_amount`: u64 |
| Событие | `WinnerRecordedEvent` | drop, store, copy | `payout_id`: u64<br>`lottery_id`: u64<br>`round_number`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`amount`: u64<br>`randomness_hash`: vector<u8><br>`payload_hash`: vector<u8> |
| Событие | `PayoutStatusUpdatedEvent` | drop, store, copy | `payout_id`: u64<br>`lottery_id`: u64<br>`round_number`: u64<br>`previous_status`: u8<br>`next_status`: u8 |
| Событие | `RefundIssuedEvent` | drop, store, copy | `payout_id`: u64<br>`lottery_id`: u64<br>`round_number`: u64<br>`recipient`: address<br>`amount`: u64 |
| Ресурс | `PayoutLedger` | key | `admin`: address<br>`next_payout_id`: u64<br>`states`: table::Table<u64, LotteryPayoutState><br>`payout_index`: table::Table<u64, u64><br>`winner_events`: event::EventHandle<WinnerRecordedEvent><br>`payout_events`: event::EventHandle<PayoutStatusUpdatedEvent><br>`refund_events`: event::EventHandle<RefundIssuedEvent> |

### Модуль `lottery_data::rounds` (`SupraLottery/supra/move_workspace/lottery_data/sources/Rounds.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `RoundRuntime` | copy, drop, store | `tickets`: vector<address><br>`draw_scheduled`: bool<br>`next_ticket_id`: u64<br>`pending_request`: option::Option<u64> |
| Структура | `LegacyRoundRecord` | drop, store | `lottery_id`: u64<br>`tickets`: vector<address><br>`draw_scheduled`: bool<br>`next_ticket_id`: u64<br>`pending_request`: option::Option<u64> |
| Структура | `RoundSnapshot` | copy, drop, store | `lottery_id`: u64<br>`ticket_count`: u64<br>`draw_scheduled`: bool<br>`has_pending_request`: bool<br>`next_ticket_id`: u64<br>`pending_request_id`: option::Option<u64> |
| Событие | `TicketPurchasedEvent` | drop, store, copy | `lottery_id`: u64<br>`ticket_id`: u64<br>`buyer`: address<br>`amount`: u64 |
| Событие | `DrawScheduleUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`draw_scheduled`: bool |
| Событие | `RoundResetEvent` | drop, store, copy | `lottery_id`: u64<br>`tickets_cleared`: u64 |
| Событие | `DrawRequestIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64 |
| Событие | `DrawFulfilledEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`random_bytes`: vector<u8><br>`prize_amount`: u64<br>`payload`: vector<u8> |
| Событие | `RoundSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`snapshot`: RoundSnapshot |
| Ресурс | `RoundRegistry` | key | `admin`: address<br>`rounds`: table::Table<u64, RoundRuntime><br>`lottery_ids`: vector<u64><br>`ticket_events`: event::EventHandle<TicketPurchasedEvent><br>`schedule_events`: event::EventHandle<DrawScheduleUpdatedEvent><br>`reset_events`: event::EventHandle<RoundResetEvent><br>`request_events`: event::EventHandle<DrawRequestIssuedEvent><br>`fulfill_events`: event::EventHandle<DrawFulfilledEvent><br>`snapshot_events`: event::EventHandle<RoundSnapshotUpdatedEvent> |
| Структура | `HistoryWriterCap` | store | — |
| Структура | `AutopurchaseRoundCap` | store | — |
| Ресурс | `RoundControl` | key | `admin`: address<br>`history_cap`: option::Option<HistoryWriterCap><br>`autopurchase_cap`: option::Option<AutopurchaseRoundCap> |
| Структура | `PendingHistoryRecord` | drop, store | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8> |
| Структура | `PendingPurchaseRecord` | drop, store | `lottery_id`: u64<br>`buyer`: address<br>`ticket_count`: u64<br>`paid_amount`: u64 |
| Ресурс | `PendingHistoryQueue` | key | `pending`: vector<PendingHistoryRecord> |
| Ресурс | `PendingPurchaseQueue` | key | `pending`: vector<PendingPurchaseRecord> |

### Модуль `lottery_data::treasury_multi` (`SupraLottery/supra/move_workspace/lottery_data/sources/TreasuryMulti.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryShareConfig` | copy, drop, store | `prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Структура | `LotteryPool` | copy, drop, store | `prize_balance`: u64<br>`operations_balance`: u64 |
| Структура | `RecipientStatus` | copy, drop, store | `recipient`: address<br>`registered`: bool<br>`frozen`: bool<br>`store`: option::Option<address><br>`balance`: u64 |
| Структура | `LegacyMultiTreasuryState` | drop, store | `jackpot_recipient`: address<br>`operations_recipient`: address<br>`jackpot_balance`: u64 |
| Структура | `LegacyMultiTreasuryLottery` | drop, store | `lottery_id`: u64<br>`prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64<br>`prize_balance`: u64<br>`operations_balance`: u64 |
| Событие | `LotteryConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Событие | `AllocationRecordedEvent` | drop, store, copy | `lottery_id`: u64<br>`total_amount`: u64<br>`prize_amount`: u64<br>`jackpot_amount`: u64<br>`operations_amount`: u64 |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `RecipientsUpdatedEvent` | drop, store, copy | `previous_jackpot`: option::Option<RecipientStatus><br>`previous_operations`: option::Option<RecipientStatus><br>`next_jackpot`: RecipientStatus<br>`next_operations`: RecipientStatus |
| Событие | `PrizePaidEvent` | drop, store, copy | `lottery_id`: u64<br>`winner`: address<br>`amount`: u64 |
| Событие | `OperationsWithdrawnEvent` | drop, store, copy | `lottery_id`: u64<br>`recipient`: address<br>`amount`: u64 |
| Событие | `OperationsIncomeRecordedEvent` | drop, store, copy | `lottery_id`: u64<br>`amount`: u64<br>`source`: vector<u8> |
| Событие | `OperationsBonusPaidEvent` | drop, store, copy | `lottery_id`: u64<br>`recipient`: address<br>`amount`: u64 |
| Событие | `JackpotPaidEvent` | drop, store, copy | `recipient`: address<br>`amount`: u64 |
| Ресурс | `TreasuryState` | key | `admin`: address<br>`jackpot_recipient`: address<br>`operations_recipient`: address<br>`jackpot_balance`: u64<br>`configs`: table::Table<u64, LotteryShareConfig><br>`pools`: table::Table<u64, LotteryPool><br>`lottery_ids`: vector<u64><br>`config_events`: event::EventHandle<LotteryConfigUpdatedEvent><br>`allocation_events`: event::EventHandle<AllocationRecordedEvent><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`recipient_events`: event::EventHandle<RecipientsUpdatedEvent><br>`prize_events`: event::EventHandle<PrizePaidEvent><br>`operations_events`: event::EventHandle<OperationsWithdrawnEvent><br>`operations_income_events`: event::EventHandle<OperationsIncomeRecordedEvent><br>`operations_bonus_events`: event::EventHandle<OperationsBonusPaidEvent><br>`jackpot_events`: event::EventHandle<JackpotPaidEvent> |
| Структура | `MultiTreasuryCap` | store | `scope`: u64 |
| Ресурс | `TreasuryMultiControl` | key | `admin`: address<br>`jackpot_cap`: option::Option<MultiTreasuryCap><br>`referrals_cap`: option::Option<MultiTreasuryCap><br>`store_cap`: option::Option<MultiTreasuryCap><br>`vip_cap`: option::Option<MultiTreasuryCap> |

### Модуль `lottery_data::treasury` (`SupraLottery/supra/move_workspace/lottery_data/sources/Treasury.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `VaultConfig` | copy, drop, store | `bp_jackpot`: u64<br>`bp_prize`: u64<br>`bp_treasury`: u64<br>`bp_marketing`: u64<br>`bp_community`: u64<br>`bp_team`: u64<br>`bp_partners`: u64 |
| Структура | `LegacyVaultConfig` | copy, drop, store | `bp_jackpot`: u64<br>`bp_prize`: u64<br>`bp_treasury`: u64<br>`bp_marketing`: u64<br>`bp_community`: u64<br>`bp_team`: u64<br>`bp_partners`: u64 |
| Структура | `VaultRecipients` | copy, drop, store | `treasury`: address<br>`marketing`: address<br>`community`: address<br>`team`: address<br>`partners`: address |
| Структура | `LegacyVaultRecipients` | copy, drop, store | `treasury`: address<br>`marketing`: address<br>`community`: address<br>`team`: address<br>`partners`: address |
| Структура | `VaultRecipientStatus` | copy, drop, store | `account`: address<br>`registered`: bool<br>`frozen`: bool<br>`store`: option::Option<address><br>`balance`: u64 |
| Структура | `VaultRecipientsSnapshot` | copy, drop, store | `treasury`: VaultRecipientStatus<br>`marketing`: VaultRecipientStatus<br>`community`: VaultRecipientStatus<br>`team`: VaultRecipientStatus<br>`partners`: VaultRecipientStatus |
| Структура | `LegacyVaultState` | drop, store | `config`: LegacyVaultConfig<br>`recipients`: LegacyVaultRecipients |
| Событие | `ConfigUpdatedEvent` | drop, store, copy | `bp_jackpot`: u64<br>`bp_prize`: u64<br>`bp_treasury`: u64<br>`bp_marketing`: u64<br>`bp_community`: u64<br>`bp_team`: u64<br>`bp_partners`: u64 |
| Событие | `RecipientsUpdatedEvent` | drop, store, copy | `previous`: option::Option<VaultRecipientsSnapshot><br>`next`: VaultRecipientsSnapshot |
| Событие | `JackpotDistributedEvent` | drop, store, copy | `winner`: address<br>`total_amount`: u64<br>`winner_share`: u64<br>`jackpot_share`: u64<br>`prize_share`: u64<br>`treasury_share`: u64<br>`marketing_share`: u64<br>`community_share`: u64<br>`team_share`: u64<br>`partners_share`: u64 |
| Ресурс | `Vaults` | key | `config`: VaultConfig<br>`recipients`: VaultRecipients<br>`config_events`: event::EventHandle<ConfigUpdatedEvent><br>`recipient_events`: event::EventHandle<RecipientsUpdatedEvent><br>`jackpot_events`: event::EventHandle<JackpotDistributedEvent> |
| Ресурс | `TokenState` | key | `metadata`: object::Object<fungible_asset::Metadata><br>`mint_ref`: fungible_asset::MintRef<br>`burn_ref`: fungible_asset::BurnRef<br>`transfer_ref`: fungible_asset::TransferRef |
| Структура | `AutopurchaseTreasuryCap` | store | — |
| Структура | `LegacyTreasuryCap` | store | — |
| Ресурс | `TreasuryV1Control` | key | `admin`: address<br>`autopurchase_cap`: option::Option<AutopurchaseTreasuryCap><br>`legacy_cap`: option::Option<LegacyTreasuryCap> |

### Модуль `lottery_data::vrf_deposit` (`SupraLottery/supra/move_workspace/lottery_data/sources/VrfDeposit.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `VrfDepositConfig` | copy, drop, store | `min_balance_multiplier_bps`: u64<br>`effective_floor`: u64 |
| Структура | `VrfDepositStatus` | copy, drop, store | `total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`last_update_ts`: u64<br>`requests_paused`: bool<br>`paused_since_ts`: u64 |
| Событие | `VrfDepositSnapshotEvent` | drop, store, copy | `total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`effective_floor`: u64<br>`timestamp`: u64 |
| Событие | `VrfDepositAlertEvent` | drop, store, copy | `total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`effective_floor`: u64<br>`timestamp`: u64 |
| Событие | `VrfRequestsPausedEvent` | drop, store, copy | `timestamp`: u64 |
| Событие | `VrfRequestsResumedEvent` | drop, store, copy | `timestamp`: u64 |
| Ресурс | `VrfDepositLedger` | key | `admin`: address<br>`config`: VrfDepositConfig<br>`status`: VrfDepositStatus<br>`snapshot_events`: event::EventHandle<VrfDepositSnapshotEvent><br>`alert_events`: event::EventHandle<VrfDepositAlertEvent><br>`paused_events`: event::EventHandle<VrfRequestsPausedEvent><br>`resumed_events`: event::EventHandle<VrfRequestsResumedEvent> |
| Структура | `LegacyVrfDepositLedger` | drop, store | `admin`: address<br>`config`: VrfDepositConfig<br>`status`: VrfDepositStatus<br>`snapshot_timestamp`: u64 |


## Пакет `lottery_engine`

### Модуль `lottery_engine::automation` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Automation.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::cancellation` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Cancellation.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::draw` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Draw.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::lifecycle` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Lifecycle.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::operators` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Operators.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::payouts` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Payouts.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::sales` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Sales.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::ticketing` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Ticketing.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::vrf` (`SupraLottery/supra/move_workspace/lottery_engine/sources/Vrf.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_engine::vrf_config` (`SupraLottery/supra/move_workspace/lottery_engine/sources/VrfConfig.move`)

> В этом модуле структур с `struct ... has ...` не найдено.


## Пакет `lottery_factory`

### Модуль `lottery_factory::registry` (`SupraLottery/supra/move_workspace/lottery_factory/sources/LotteryFactory.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryBlueprint` | copy, drop, store | `ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Структура | `LotteryInfo` | copy, drop, store | `owner`: address<br>`lottery`: address<br>`blueprint`: LotteryBlueprint |
| Структура | `LotteryRegistryEntry` | copy, drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16 |
| Структура | `LotteryRegistrySnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<LotteryRegistryEntry> |
| Ресурс | `FactoryState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryInfo><br>`lottery_ids`: vector<u64><br>`planned_events`: event::EventHandle<LotteryPlannedEvent><br>`activated_events`: event::EventHandle<LotteryActivatedEvent><br>`snapshot_events`: event::EventHandle<LotteryRegistrySnapshotUpdatedEvent> |
| Событие | `LotteryPlannedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address |
| Событие | `LotteryActivatedEvent` | drop, store, copy | `lottery_id`: u64<br>`lottery`: address |
| Событие | `LotteryRegistrySnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`lotteries`: vector<LotteryRegistryEntry> |


## Пакет `lottery_gateway`

### Модуль `lottery_gateway::gateway` (`SupraLottery/supra/move_workspace/lottery_gateway/sources/Gateway.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `OwnerLotteries` | store | `lottery_ids`: vector<u64> |
| Структура | `GatewayLottery` | copy, drop, store | `owner`: address<br>`active`: bool |
| Событие | `LotteryCreatedEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address<br>`ticket_price`: u64<br>`auto_draw_threshold`: u64<br>`jackpot_share_bps`: u16 |
| Событие | `LotteryOwnerUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`previous`: option::Option<address><br>`next`: address |
| Событие | `LotteryStatusUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`active`: bool |
| Событие | `GatewaySnapshotEvent` | drop, store, copy | `admin`: address<br>`next_lottery_id`: u64<br>`total_lotteries`: u64 |
| Ресурс | `GatewayRegistry` | key | `admin`: address<br>`next_lottery_id`: u64<br>`lotteries`: table::Table<u64, GatewayLottery><br>`owner_index`: table::Table<address, OwnerLotteries><br>`lottery_ids`: vector<u64><br>`creation_events`: event::EventHandle<LotteryCreatedEvent><br>`owner_events`: event::EventHandle<LotteryOwnerUpdatedEvent><br>`status_events`: event::EventHandle<LotteryStatusUpdatedEvent><br>`snapshot_events`: event::EventHandle<GatewaySnapshotEvent> |

### Модуль `lottery_gateway::registry` (`SupraLottery/supra/move_workspace/lottery_gateway/sources/Registry.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryCancellationSummary` | copy, drop, store | `reason_code`: u8<br>`canceled_ts`: u64 |
| Структура | `LegacyCancellationImport` | copy, drop, store | `lottery_id`: u64<br>`reason_code`: u8<br>`canceled_ts`: u64 |
| Структура | `LotteryRegistryEntry` | copy, drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery_address`: address<br>`ticket_price`: u64<br>`jackpot_share_bps`: u16<br>`active`: bool<br>`cancellation`: option::Option<LotteryCancellationSummary> |
| Структура | `LotteryRegistrySnapshot` | copy, drop, store | `admin`: address<br>`total_lotteries`: u64<br>`entries`: vector<LotteryRegistryEntry> |
| Событие | `LotteryRegistrySnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<LotteryRegistrySnapshot><br>`current`: LotteryRegistrySnapshot |
| Ресурс | `LotteryRegistry` | key | `admin`: address<br>`entries`: table::Table<u64, LotteryRegistryEntry><br>`lottery_ids`: vector<u64><br>`snapshot_events`: event::EventHandle<LotteryRegistrySnapshotUpdatedEvent> |


## Пакет `lottery_hub`

### Модуль `lottery_hub::registry` (`SupraLottery/supra/move_workspace/lottery_hub/sources/registry.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `Lottery` | copy, drop, store | `id`: u64<br>`ticket_price`: u64<br>`min_players`: u64<br>`max_players`: u64<br>`sales_start_ts`: u64<br>`sales_end_ts`: u64 |
| Ресурс | `Registry` | key | `admin`: address<br>`next_id`: u64<br>`lotteries`: vector<Lottery> |

### Модуль `lottery_hub::registry_tests` (`SupraLottery/supra/move_workspace/lottery_hub/sources/registry_tests.move`)

> В этом модуле структур с `struct ... has ...` не найдено.


## Пакет `lottery_multi`

### Модуль `lottery_multi::automation` (`SupraLottery/supra/move_workspace/lottery_multi/sources/automation.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `AutomationCap` | key, store | `operator`: address<br>`cron_spec`: vector<u8> |
| Структура | `AutomationState` | store | `allowed_actions`: vector<u64><br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`timelock_secs`: u64<br>`pending_action_hash`: vector<u8><br>`pending_execute_after`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |
| Ресурс | `AutomationRegistry` | key | `bots`: table::Table<address, AutomationState><br>`dry_run_events`: event::EventHandle<history::AutomationDryRunPlannedEvent><br>`call_rejected_events`: event::EventHandle<history::AutomationCallRejectedEvent><br>`key_rotated_events`: event::EventHandle<history::AutomationKeyRotatedEvent><br>`tick_events`: event::EventHandle<history::AutomationTickEvent><br>`error_events`: event::EventHandle<history::AutomationErrorEvent> |
| Структура | `AutomationBotStatus` | drop, store | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`pending_action_hash`: vector<u8><br>`pending_execute_after`: u64<br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |

### Модуль `lottery_multi::cancellation` (`SupraLottery/supra/move_workspace/lottery_multi/sources/cancellation.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_multi::draw` (`SupraLottery/supra/move_workspace/lottery_multi/sources/draw.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `PayloadV1` | drop, store | `lottery_id`: u64<br>`config_version`: u64<br>`snapshot_hash`: vector<u8><br>`slots_checksum`: vector<u8><br>`rng_count`: u8<br>`client_seed`: u64<br>`attempt`: u8<br>`closing_block_height`: u64<br>`chain_id`: u8 |
| Структура | `FinalizationSnapshot` | copy, drop, store | `snapshot_hash`: vector<u8><br>`payload_hash`: vector<u8><br>`winners_batch_hash`: vector<u8><br>`checksum_after_batch`: vector<u8><br>`schema_version`: u16<br>`attempt`: u8<br>`closing_block_height`: u64<br>`chain_id`: u8<br>`request_ts`: u64<br>`vrf_status`: u8 |
| Структура | `DrawState` | store | `vrf_state`: types::VrfState<br>`rng_count`: u8<br>`client_seed`: u64<br>`last_request_ts`: u64<br>`snapshot_hash`: vector<u8><br>`total_tickets`: u64<br>`winners_batch_hash`: vector<u8><br>`checksum_after_batch`: vector<u8><br>`verified_numbers`: vector<u256><br>`payload`: vector<u8><br>`next_client_seed`: u64 |
| Структура | `VrfStateView` | copy, drop, store | `status`: u8<br>`attempt`: u8<br>`consumed`: bool<br>`retry_after_ts`: u64<br>`retry_strategy`: u8<br>`last_request_ts`: u64<br>`request_id`: u64 |
| Ресурс | `DrawLedger` | key | `states`: table::Table<u64, DrawState><br>`nonce_to_lottery`: table::Table<u64, u64><br>`requested_events`: event::EventHandle<history::VrfRequestedEvent><br>`fulfilled_events`: event::EventHandle<history::VrfFulfilledEvent> |

### Модуль `lottery_multi::economics` (`SupraLottery/supra/move_workspace/lottery_multi/sources/economics.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `SalesDistribution` | copy, drop, store | `prize_bps`: u16<br>`jackpot_bps`: u16<br>`operations_bps`: u16<br>`reserve_bps`: u16 |
| Структура | `Accounting` | copy, drop, store | `total_sales`: u64<br>`total_allocated`: u64<br>`total_prize_paid`: u64<br>`total_operations_paid`: u64<br>`total_operations_allocated`: u64<br>`jackpot_allowance_token`: u64 |

### Модуль `lottery_multi::errors` (`SupraLottery/supra/move_workspace/lottery_multi/sources/errors.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_multi::feature_switch` (`SupraLottery/supra/move_workspace/lottery_multi/sources/feature_switch.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `FeatureSwitchAdminCap` | key | — |
| Структура | `FeatureRecord` | store | `mode`: u8 |
| Ресурс | `FeatureSwitchRegistry` | key | `force_enable_devnet`: bool<br>`entries`: table::Table<u64, FeatureRecord> |

### Модуль `lottery_multi::history` (`SupraLottery/supra/move_workspace/lottery_multi/sources/history.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryCreatedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`id`: u64<br>`cfg_hash`: vector<u8><br>`config_version`: u64<br>`creator`: address<br>`event_slug`: vector<u8><br>`series_code`: vector<u8><br>`run_id`: u64<br>`primary_type`: u8<br>`tags_mask`: u64<br>`slots_checksum`: vector<u8> |
| Структура | `LotteryCanceledEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`previous_status`: u8<br>`reason_code`: u8<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`timestamp`: u64 |
| Структура | `LotteryFinalizedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`id`: u64<br>`archive_slot_hash`: vector<u8><br>`primary_type`: u8<br>`tags_mask`: u64 |
| Структура | `LegacySummaryImportedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`archive_hash`: vector<u8><br>`finalized_at`: u64<br>`primary_type`: u8<br>`tags_mask`: u64 |
| Структура | `LegacySummaryRolledBackEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`archive_hash`: vector<u8><br>`finalized_at`: u64<br>`primary_type`: u8<br>`tags_mask`: u64 |
| Структура | `LegacySummaryClassificationUpdatedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`archive_hash`: vector<u8><br>`primary_type`: u8<br>`tags_mask`: u64 |
| Структура | `VrfRequestedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`request_id`: u64<br>`attempt`: u8<br>`rng_count`: u8<br>`client_seed`: u64<br>`payload_hash`: vector<u8><br>`snapshot_hash`: vector<u8><br>`tickets_sold`: u64<br>`closing_block_height`: u64<br>`chain_id`: u8<br>`request_ts`: u64 |
| Структура | `VrfFulfilledEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`request_id`: u64<br>`attempt`: u8<br>`payload_hash`: vector<u8><br>`message_hash`: vector<u8><br>`rng_count`: u8<br>`client_seed`: u64<br>`verified_seed_hash`: vector<u8><br>`closing_block_height`: u64<br>`chain_id`: u8<br>`fulfilled_ts`: u64 |
| Структура | `LotterySummary` | copy, drop, store | `id`: u64<br>`status`: u8<br>`event_slug`: vector<u8><br>`series_code`: vector<u8><br>`run_id`: u64<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`total_allocated`: u64<br>`total_prize_paid`: u64<br>`total_operations_paid`: u64<br>`vrf_status`: u8<br>`primary_type`: u8<br>`tags_mask`: u64<br>`snapshot_hash`: vector<u8><br>`slots_checksum`: vector<u8><br>`winners_batch_hash`: vector<u8><br>`checksum_after_batch`: vector<u8><br>`payout_round`: u64<br>`created_at`: u64<br>`closed_at`: u64<br>`finalized_at`: u64 |
| Структура | `WinnersComputedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`batch_no`: u64<br>`assigned_in_batch`: u64<br>`total_assigned`: u64<br>`winners_batch_hash`: vector<u8><br>`checksum_after_batch`: vector<u8> |
| Структура | `PayoutBatchEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`payout_round`: u64<br>`winners_paid`: u64<br>`prize_paid`: u64<br>`operations_paid`: u64<br>`timestamp`: u64 |
| Структура | `PartnerPayoutEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`partner`: address<br>`amount`: u64<br>`payout_round`: u64<br>`timestamp`: u64 |
| Структура | `RefundBatchEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`refund_round`: u64<br>`tickets_refunded`: u64<br>`prize_refunded`: u64<br>`operations_refunded`: u64<br>`total_tickets_refunded`: u64<br>`total_amount_refunded`: u64<br>`timestamp`: u64 |
| Структура | `PurchaseRateLimitHitEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`buyer`: address<br>`timestamp`: u64<br>`current_block`: u64<br>`reason_code`: u8 |
| Структура | `AutomationDryRunPlannedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`executes_after_ts`: u64 |
| Структура | `AutomationCallRejectedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`reason_code`: u64 |
| Структура | `AutomationKeyRotatedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`operator`: address<br>`schedule_hash`: vector<u8><br>`expires_at`: u64 |
| Структура | `AutomationTickEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`executed_ts`: u64<br>`success`: bool<br>`reputation_score`: u64<br>`success_streak`: u64<br>`failure_count`: u64 |
| Структура | `AutomationErrorEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`operator`: address<br>`action_id`: u64<br>`action_hash`: vector<u8><br>`error_code`: u64<br>`timestamp`: u64 |
| Структура | `VrfDepositSnapshotEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`effective_floor`: u64<br>`timestamp`: u64 |
| Структура | `VrfDepositAlertEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`effective_floor`: u64<br>`timestamp`: u64 |
| Структура | `VrfRequestsPausedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`paused_since_ts`: u64 |
| Структура | `VrfRequestsResumedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`resumed_ts`: u64 |
| Ресурс | `ArchiveLedger` | key | `summaries`: table::Table<u64, LotterySummary><br>`imported_flags`: table::Table<u64, bool><br>`ordered_ids`: vector<u64><br>`finalized_events`: event::EventHandle<LotteryFinalizedEvent><br>`import_events`: event::EventHandle<LegacySummaryImportedEvent><br>`rollback_events`: event::EventHandle<LegacySummaryRolledBackEvent><br>`classification_events`: event::EventHandle<LegacySummaryClassificationUpdatedEvent> |

### Модуль `lottery_multi::legacy_bridge` (`SupraLottery/supra/move_workspace/lottery_multi/sources/legacy_bridge.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `ArchiveDualWriteStartedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`expected_hash`: vector<u8> |
| Структура | `ArchiveDualWriteCompletedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`archive_hash`: vector<u8><br>`finalized_at`: u64 |
| Структура | `DualWriteStatus` | copy, drop, store | `enabled`: bool<br>`abort_on_mismatch`: bool<br>`abort_on_missing`: bool<br>`expected_hash`: option::Option<vector<u8>> |
| Ресурс | `DualWriteControl` | key | `enabled`: bool<br>`abort_on_mismatch`: bool<br>`abort_on_missing`: bool<br>`expected_hashes`: table::Table<u64, vector<u8>><br>`started_events`: event::EventHandle<ArchiveDualWriteStartedEvent><br>`completed_events`: event::EventHandle<ArchiveDualWriteCompletedEvent> |
| Ресурс | `MirrorConfig` | key, drop | — |

### Модуль `lottery_multi::lottery_registry` (`SupraLottery/supra/move_workspace/lottery_multi/sources/lottery_registry.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `Config` | copy, drop, store | `event_slug`: vector<u8><br>`series_code`: vector<u8><br>`run_id`: u64<br>`config_version`: u64<br>`primary_type`: u8<br>`tags_mask`: u64<br>`sales_window`: types::SalesWindow<br>`ticket_price`: u64<br>`ticket_limits`: types::TicketLimits<br>`sales_distribution`: economics::SalesDistribution<br>`prize_plan`: vector<types::PrizeSlot><br>`winners_dedup`: bool<br>`draw_algo`: u8<br>`auto_close_policy`: types::AutoClosePolicy<br>`reward_backend`: types::RewardBackend<br>`vrf_retry_policy`: types::RetryPolicy |
| Структура | `Lottery` | store | `id`: u64<br>`config`: Config<br>`status`: u8<br>`snapshot_frozen`: bool<br>`slots_checksum`: vector<u8> |
| Структура | `CancellationRecord` | copy, drop, store | `reason_code`: u8<br>`canceled_ts`: u64<br>`previous_status`: u8<br>`tickets_sold`: u64<br>`proceeds_accum`: u64 |
| Ресурс | `Registry` | key | `lotteries`: table::Table<u64, Lottery><br>`ordered_ids`: vector<u64><br>`created_events`: event::EventHandle<history::LotteryCreatedEvent><br>`canceled_events`: event::EventHandle<history::LotteryCanceledEvent><br>`cancellations`: table::Table<u64, CancellationRecord> |

### Модуль `lottery_multi::math` (`SupraLottery/supra/move_workspace/lottery_multi/sources/math.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_multi::payouts` (`SupraLottery/supra/move_workspace/lottery_multi/sources/payouts.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `WinnerRecord` | copy, drop, store | `slot_id`: u64<br>`ticket_index`: u64<br>`winner`: address<br>`winner_hash`: vector<u8> |
| Структура | `WinnerChunk` | store | `lottery_id`: u64<br>`chunk_seq`: u64<br>`start_ordinal`: u64<br>`records`: vector<WinnerRecord> |
| Структура | `WinnerState` | store | `initialized`: bool<br>`total_required`: u64<br>`total_assigned`: u64<br>`total_tickets`: u64<br>`snapshot_hash`: vector<u8><br>`payload_hash`: vector<u8><br>`schema_version`: u16<br>`attempt`: u8<br>`random_numbers`: vector<u256><br>`winners_batch_hash`: vector<u8><br>`cursor`: types::WinnerCursor<br>`next_chunk_seq`: u64<br>`winner_chunks`: table::Table<u64, WinnerChunk><br>`assigned_indices`: table::Table<u64, bool><br>`payout_round`: u64<br>`last_payout_ts`: u64<br>`next_winner_batch_no`: u64 |
| Структура | `WinnerProgressView` | copy, drop, store | `initialized`: bool<br>`total_required`: u64<br>`total_assigned`: u64<br>`payout_round`: u64<br>`next_winner_batch_no`: u64<br>`last_payout_ts`: u64 |
| Ресурс | `PayoutLedger` | key | `states`: table::Table<u64, WinnerState><br>`winner_events`: event::EventHandle<history::WinnersComputedEvent><br>`payout_events`: event::EventHandle<history::PayoutBatchEvent><br>`partner_events`: event::EventHandle<history::PartnerPayoutEvent><br>`refund_events`: event::EventHandle<history::RefundBatchEvent> |
| Структура | `SlotContext` | copy, drop, store | `slot_id`: u64<br>`slot_position`: u64<br>`local_index`: u64 |

### Модуль `lottery_multi::price_feed` (`SupraLottery/supra/move_workspace/lottery_multi/sources/price_feed.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `PriceFeedRecord` | store | `asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`last_updated_ts`: u64<br>`staleness_window`: u64<br>`clamp_threshold_bps`: u64<br>`fallback_active`: bool<br>`fallback_reason`: u8<br>`clamp_active`: bool |
| Структура | `PriceFeedUpdatedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`updated_ts`: u64 |
| Структура | `PriceFeedFallbackEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`fallback_active`: bool<br>`reason`: u8 |
| Структура | `PriceFeedClampEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`old_price`: u64<br>`new_price`: u64<br>`threshold_bps`: u64 |
| Структура | `PriceFeedClampClearedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`cleared_ts`: u64 |
| Структура | `PriceFeedView` | drop, store | `asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`last_updated_ts`: u64<br>`staleness_window`: u64<br>`clamp_threshold_bps`: u64<br>`fallback_active`: bool<br>`fallback_reason`: u8<br>`clamp_active`: bool |
| Ресурс | `PriceFeedRegistry` | key | `version`: u16<br>`feeds`: table::Table<u64, PriceFeedRecord><br>`updates`: event::EventHandle<PriceFeedUpdatedEvent><br>`fallbacks`: event::EventHandle<PriceFeedFallbackEvent><br>`clamps`: event::EventHandle<PriceFeedClampEvent><br>`clamp_clears`: event::EventHandle<PriceFeedClampClearedEvent> |

### Модуль `lottery_multi::roles` (`SupraLottery/supra/move_workspace/lottery_multi/sources/roles.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `PartnerCreateCap` | drop, store | `allowed_event_slug`: vector<u8><br>`allowed_series_codes`: vector<vector<u8>><br>`allowed_primary_types`: vector<u8><br>`allowed_tags_mask`: u64<br>`max_parallel`: u64<br>`expires_at`: u64<br>`payout_cooldown_secs`: u64 |
| Структура | `PremiumAccessCap` | store, drop | `holder`: address<br>`expires_at`: u64<br>`auto_renew`: bool<br>`referrer`: option::Option<address> |
| Структура | `PayoutBatchCap` | store, drop | `holder`: address<br>`max_batch_size`: u64<br>`operations_budget_total`: u64<br>`operations_budget_used`: u64<br>`cooldown_secs`: u64<br>`last_batch_at`: u64<br>`last_nonce`: u64<br>`nonce_stride`: u64 |
| Структура | `PartnerPayoutCap` | store, drop | `partner`: address<br>`max_total_payout`: u64<br>`remaining_payout`: u64<br>`payout_cooldown_secs`: u64<br>`last_payout_at`: u64<br>`next_nonce`: u64<br>`nonce_stride`: u64<br>`expires_at`: u64 |
| Структура | `PartnerCapInfo` | copy, drop, store | `partner`: address<br>`max_total_payout`: u64<br>`remaining_payout`: u64<br>`payout_cooldown_secs`: u64<br>`last_payout_at`: u64<br>`next_nonce`: u64<br>`nonce_stride`: u64<br>`expires_at`: u64 |
| Структура | `PremiumCapInfo` | copy, drop, store | `holder`: address<br>`expires_at`: u64<br>`auto_renew`: bool<br>`referrer`: option::Option<address> |
| Структура | `RoleEvents` | store | `payout_granted`: event::EventHandle<PayoutBatchCapGrantedEvent><br>`payout_revoked`: event::EventHandle<PayoutBatchCapRevokedEvent><br>`partner_granted`: event::EventHandle<PartnerPayoutCapGrantedEvent><br>`partner_revoked`: event::EventHandle<PartnerPayoutCapRevokedEvent><br>`premium_granted`: event::EventHandle<PremiumAccessGrantedEvent><br>`premium_revoked`: event::EventHandle<PremiumAccessRevokedEvent> |
| Структура | `PayoutBatchCapGrantedEvent` | copy, drop, store | `holder`: address<br>`max_batch_size`: u64<br>`operations_budget_total`: u64<br>`cooldown_secs`: u64<br>`nonce_stride`: u64 |
| Структура | `PayoutBatchCapRevokedEvent` | copy, drop, store | `holder`: address |
| Структура | `PartnerPayoutCapGrantedEvent` | copy, drop, store | `partner`: address<br>`max_total_payout`: u64<br>`payout_cooldown_secs`: u64<br>`nonce_stride`: u64<br>`expires_at`: u64 |
| Структура | `PartnerPayoutCapRevokedEvent` | copy, drop, store | `partner`: address |
| Структура | `PremiumAccessGrantedEvent` | copy, drop, store | `holder`: address<br>`expires_at`: u64<br>`auto_renew`: bool |
| Структура | `PremiumAccessRevokedEvent` | copy, drop, store | `holder`: address |
| Ресурс | `RoleStore` | key | `payout_batch`: option::Option<PayoutBatchCap><br>`partner_caps`: table::Table<address, PartnerPayoutCap><br>`partner_index`: vector<address><br>`premium_caps`: table::Table<address, PremiumAccessCap><br>`premium_index`: vector<address><br>`events`: RoleEvents |

### Модуль `lottery_multi::sales` (`SupraLottery/supra/move_workspace/lottery_multi/sources/sales.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `TicketChunk` | store | `lottery_id`: u64<br>`chunk_seq`: u64<br>`start_index`: u64<br>`buyers`: vector<address> |
| Структура | `ChunkSnapshot` | copy, drop, store | `chunk_seq`: u64<br>`start_index`: u64<br>`buyers`: vector<address> |
| Структура | `TicketPurchaseEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`lottery_id`: u64<br>`buyer`: address<br>`quantity`: u64<br>`sale_amount`: u64<br>`prize_allocation`: u64<br>`jackpot_allocation`: u64<br>`operations_allocation`: u64<br>`reserve_allocation`: u64<br>`tickets_sold`: u64<br>`proceeds_accum`: u64 |
| Структура | `RefundProgressView` | copy, drop, store | `active`: bool<br>`refund_round`: u64<br>`tickets_refunded`: u64<br>`prize_refunded`: u64<br>`operations_refunded`: u64<br>`last_refund_ts`: u64<br>`tickets_sold`: u64<br>`proceeds_accum`: u64 |
| Структура | `RateTrack` | store | `window_start`: u64<br>`purchase_count`: u64 |
| Структура | `SalesState` | store | `ticket_price`: u64<br>`tickets_sold`: u64<br>`proceeds_accum`: u64<br>`last_purchase_ts`: u64<br>`last_purchase_block`: u64<br>`block_purchase_count`: u64<br>`next_chunk_seq`: u64<br>`tickets_per_address`: table::Table<address, u64><br>`ticket_chunks`: table::Table<u64, TicketChunk><br>`rate_track`: table::Table<address, RateTrack><br>`distribution`: economics::SalesDistribution<br>`accounting`: economics::Accounting<br>`refund_active`: bool<br>`refund_round`: u64<br>`refund_tickets_processed`: u64<br>`refund_prize_total`: u64<br>`refund_operations_total`: u64<br>`last_refund_ts`: u64 |
| Ресурс | `SalesLedger` | key | `states`: table::Table<u64, SalesState><br>`purchase_events`: event::EventHandle<TicketPurchaseEvent><br>`rate_limit_events`: event::EventHandle<history::PurchaseRateLimitHitEvent> |

### Модуль `lottery_multi::tags` (`SupraLottery/supra/move_workspace/lottery_multi/sources/tags.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_multi::types` (`SupraLottery/supra/move_workspace/lottery_multi/sources/types.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `SalesWindow` | copy, drop, store | `sales_start`: u64<br>`sales_end`: u64 |
| Структура | `TicketLimits` | copy, drop, store | `max_tickets_total`: u64<br>`max_tickets_per_address`: u64 |
| Структура | `AutoClosePolicy` | copy, drop, store | `enabled`: bool<br>`grace_period_secs`: u64 |
| Структура | `PrizeSlot` | copy, drop, store | `slot_id`: u64<br>`winners_per_slot`: u16<br>`reward_type`: u8<br>`reward_payload`: vector<u8> |
| Структура | `RewardBackend` | copy, drop, store | `backend_type`: u8<br>`config_blob`: vector<u8> |
| Структура | `VrfStatus` | copy, drop, store | `status`: u8 |
| Структура | `VrfState` | copy, drop, store | `request_id`: u64<br>`payload_hash`: vector<u8><br>`schema_version`: u16<br>`attempt`: u8<br>`consumed`: bool<br>`retry_after_ts`: u64<br>`retry_strategy`: u8<br>`closing_block_height`: u64<br>`chain_id`: u8<br>`status`: u8 |
| Структура | `WinnerCursor` | copy, drop, store | `last_processed_index`: u64<br>`checksum_after_batch`: vector<u8> |
| Структура | `RetryPolicy` | copy, drop, store | `strategy`: u8<br>`base_delay_secs`: u64<br>`max_delay_secs`: u64 |

### Модуль `lottery_multi::views` (`SupraLottery/supra/move_workspace/lottery_multi/sources/views.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `BadgeMetadata` | drop, store | `primary_label`: string::String<br>`is_experimental`: bool<br>`tags_mask`: u64 |
| Структура | `LotteryStatusView` | drop, store | `status`: u8<br>`snapshot_frozen`: bool<br>`primary_type`: u8<br>`tags_mask`: u64 |
| Структура | `VrfDepositStatusView` | drop, store | `total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`last_update_ts`: u64<br>`requests_paused`: bool<br>`paused_since_ts`: u64 |
| Структура | `StatusOverview` | drop, store | `total`: u64<br>`draft`: u64<br>`active`: u64<br>`closing`: u64<br>`draw_requested`: u64<br>`drawn`: u64<br>`payout`: u64<br>`finalized`: u64<br>`canceled`: u64<br>`vrf_requested`: u64<br>`vrf_fulfilled_pending`: u64<br>`vrf_retry_blocked`: u64<br>`winners_pending`: u64<br>`payout_backlog`: u64<br>`refund_active`: u64<br>`refund_batch_pending`: u64<br>`refund_sla_breach`: bool |
| Структура | `AutomationBotView` | drop, store | `operator`: address<br>`allowed_actions`: vector<u64><br>`timelock_secs`: u64<br>`max_failures`: u64<br>`failure_count`: u64<br>`success_streak`: u64<br>`reputation_score`: u64<br>`has_pending`: bool<br>`pending_execute_after`: u64<br>`pending_action_hash`: vector<u8><br>`expires_at`: u64<br>`cron_spec`: vector<u8><br>`last_action_ts`: u64<br>`last_action_hash`: vector<u8> |

### Модуль `lottery_multi::vrf_deposit` (`SupraLottery/supra/move_workspace/lottery_multi/sources/vrf_deposit.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `VrfDepositConfig` | store | `min_balance_multiplier_bps`: u64<br>`effective_floor`: u64 |
| Структура | `VrfDepositStatus` | copy, drop, store | `total_balance`: u64<br>`minimum_balance`: u64<br>`effective_balance`: u64<br>`required_minimum`: u64<br>`last_update_ts`: u64<br>`requests_paused`: bool<br>`paused_since_ts`: u64 |
| Ресурс | `VrfDepositLedger` | key | `config`: VrfDepositConfig<br>`status`: VrfDepositStatus<br>`snapshots`: event::EventHandle<history::VrfDepositSnapshotEvent><br>`alerts`: event::EventHandle<history::VrfDepositAlertEvent><br>`paused_events`: event::EventHandle<history::VrfRequestsPausedEvent><br>`resumed_events`: event::EventHandle<history::VrfRequestsResumedEvent> |


## Пакет `lottery_rewards`

### Модуль `lottery_rewards::rewards_autopurchase` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/Autopurchase.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `AutopurchasePlan` | copy, drop, store | `balance`: u64<br>`tickets_per_draw`: u64<br>`active`: bool |
| Структура | `LegacyAutopurchasePlan` | drop, store | `lottery_id`: u64<br>`player`: address<br>`balance`: u64<br>`tickets_per_draw`: u64<br>`active`: bool |
| Структура | `LotteryPlans` | store | `plans`: table::Table<address, AutopurchasePlan><br>`players`: vector<address><br>`total_balance`: u64 |
| Ресурс | `AutopurchaseState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryPlans><br>`lottery_ids`: vector<u64><br>`deposit_events`: event::EventHandle<AutopurchaseDepositEvent><br>`config_events`: event::EventHandle<AutopurchaseConfigUpdatedEvent><br>`executed_events`: event::EventHandle<AutopurchaseExecutedEvent><br>`refund_events`: event::EventHandle<AutopurchaseRefundedEvent><br>`snapshot_events`: event::EventHandle<AutopurchaseSnapshotUpdatedEvent> |
| Ресурс | `AutopurchaseAccess` | key | `rounds`: AutopurchaseRoundCap<br>`treasury`: AutopurchaseTreasuryCap |
| Структура | `AutopurchaseLotterySummary` | copy, drop, store | `total_balance`: u64<br>`total_players`: u64<br>`active_players`: u64 |
| Структура | `AutopurchasePlayerSnapshot` | copy, drop, store | `player`: address<br>`balance`: u64<br>`tickets_per_draw`: u64<br>`active`: bool |
| Структура | `AutopurchaseLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`total_balance`: u64<br>`total_players`: u64<br>`active_players`: u64<br>`players`: vector<AutopurchasePlayerSnapshot> |
| Структура | `AutopurchaseSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<AutopurchaseLotterySnapshot> |
| Событие | `AutopurchaseDepositEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`amount`: u64<br>`new_balance`: u64 |
| Событие | `AutopurchaseConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`tickets_per_draw`: u64<br>`active`: bool |
| Событие | `AutopurchaseExecutedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`tickets_bought`: u64<br>`spent_amount`: u64<br>`remaining_balance`: u64 |
| Событие | `AutopurchaseRefundedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`amount`: u64<br>`remaining_balance`: u64 |
| Событие | `AutopurchaseSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`snapshot`: AutopurchaseLotterySnapshot |

### Модуль `lottery_rewards::rewards_jackpot` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/Jackpot.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `JackpotState` | key | `admin`: address<br>`lottery_id`: u64<br>`tickets`: vector<address><br>`draw_scheduled`: bool<br>`pending_request`: option::Option<u64><br>`ticket_events`: event::EventHandle<JackpotTicketGrantedEvent><br>`schedule_events`: event::EventHandle<JackpotScheduleUpdatedEvent><br>`request_events`: event::EventHandle<JackpotRequestIssuedEvent><br>`fulfill_events`: event::EventHandle<JackpotFulfilledEvent><br>`snapshot_events`: event::EventHandle<JackpotSnapshotUpdatedEvent> |
| Ресурс | `JackpotAccess` | key | `cap`: MultiTreasuryCap |
| Событие | `JackpotTicketGrantedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`ticket_index`: u64 |
| Событие | `JackpotScheduleUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`draw_scheduled`: bool |
| Событие | `JackpotRequestIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64 |
| Событие | `JackpotFulfilledEvent` | drop, store, copy | `request_id`: u64<br>`lottery_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`random_bytes`: vector<u8><br>`prize_amount`: u64<br>`payload`: vector<u8> |
| Структура | `JackpotSnapshot` | copy, drop, store | `admin`: address<br>`lottery_id`: u64<br>`ticket_count`: u64<br>`draw_scheduled`: bool<br>`has_pending_request`: bool<br>`pending_request_id`: option::Option<u64> |
| Событие | `JackpotSnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<JackpotSnapshot><br>`current`: JackpotSnapshot |

### Модуль `lottery_rewards::rewards_nft` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/NftRewards.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `WinnerBadgeData` | copy, drop, store | `badge_id`: u64<br>`lottery_id`: u64<br>`draw_id`: u64<br>`metadata_uri`: vector<u8><br>`minted_by`: address |
| Структура | `UserBadges` | store | `badges`: table::Table<u64, WinnerBadgeData><br>`badge_ids`: vector<u64> |
| Ресурс | `BadgeAuthority` | key | `admin`: address<br>`next_badge_id`: u64<br>`users`: table::Table<address, UserBadges><br>`owners`: vector<address><br>`mint_events`: event::EventHandle<BadgeMintedEvent><br>`burn_events`: event::EventHandle<BadgeBurnedEvent><br>`snapshot_events`: event::EventHandle<NftRewardsSnapshotUpdatedEvent> |
| Событие | `BadgeMintedEvent` | drop, store, copy | `badge_id`: u64<br>`owner`: address<br>`lottery_id`: u64<br>`draw_id`: u64<br>`metadata_uri`: vector<u8> |
| Событие | `BadgeBurnedEvent` | drop, store, copy | `badge_id`: u64<br>`owner`: address |
| Структура | `BadgeSnapshot` | copy, drop, store | `badge_id`: u64<br>`lottery_id`: u64<br>`draw_id`: u64<br>`metadata_uri`: vector<u8><br>`minted_by`: address |
| Структура | `BadgeOwnerSnapshot` | copy, drop, store | `owner`: address<br>`badges`: vector<BadgeSnapshot> |
| Структура | `NftRewardsSnapshot` | copy, drop, store | `admin`: address<br>`next_badge_id`: u64<br>`owners`: vector<BadgeOwnerSnapshot> |
| Событие | `NftRewardsSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`next_badge_id`: u64<br>`snapshot`: BadgeOwnerSnapshot |

### Модуль `lottery_rewards::rewards_referrals` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/Referrals.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `ReferralConfig` | copy, drop, store | `referrer_bps`: u64<br>`referee_bps`: u64 |
| Структура | `ReferralStats` | copy, drop, store | `rewarded_purchases`: u64<br>`total_referrer_rewards`: u64<br>`total_referee_rewards`: u64 |
| Ресурс | `ReferralState` | key | `admin`: address<br>`configs`: table::Table<u64, ReferralConfig><br>`stats`: table::Table<u64, ReferralStats><br>`referrers`: table::Table<address, address><br>`lottery_ids`: vector<u64><br>`total_registered`: u64<br>`config_events`: event::EventHandle<ReferralConfigUpdatedEvent><br>`register_events`: event::EventHandle<ReferralRegisteredEvent><br>`cleared_events`: event::EventHandle<ReferralClearedEvent><br>`reward_events`: event::EventHandle<ReferralRewardPaidEvent><br>`snapshot_events`: event::EventHandle<ReferralSnapshotUpdatedEvent> |
| Структура | `LotteryReferralSnapshot` | copy, drop, store | `lottery_id`: u64<br>`referrer_bps`: u64<br>`referee_bps`: u64<br>`rewarded_purchases`: u64<br>`total_referrer_rewards`: u64<br>`total_referee_rewards`: u64 |
| Структура | `ReferralSnapshot` | copy, drop, store | `admin`: address<br>`total_registered`: u64<br>`lotteries`: vector<LotteryReferralSnapshot> |
| Ресурс | `ReferralsControl` | key | `treasury_cap`: MultiTreasuryCap |
| Событие | `ReferralSnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<ReferralSnapshot><br>`current`: ReferralSnapshot |
| Событие | `ReferralConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`referrer_bps`: u64<br>`referee_bps`: u64 |
| Событие | `ReferralRegisteredEvent` | drop, store, copy | `player`: address<br>`referrer`: address<br>`by_admin`: bool |
| Событие | `ReferralClearedEvent` | drop, store, copy | `player`: address<br>`by_admin`: bool |
| Событие | `ReferralRewardPaidEvent` | drop, store, copy | `lottery_id`: u64<br>`buyer`: address<br>`referrer`: address<br>`referrer_amount`: u64<br>`referee_amount`: u64<br>`total_amount`: u64 |

### Модуль `lottery_rewards::rewards_rounds_sync` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/RoundsSync.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_rewards::rewards_store` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/Store.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `StoreItem` | copy, drop, store | `price`: u64<br>`metadata`: vector<u8><br>`available`: bool<br>`stock`: option::Option<u64> |
| Структура | `StoreRecord` | store | `item`: StoreItem<br>`sold`: u64 |
| Структура | `LotteryStore` | store | `items`: table::Table<u64, StoreRecord><br>`item_ids`: vector<u64> |
| Ресурс | `StoreState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryStore><br>`lottery_ids`: vector<u64><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`item_events`: event::EventHandle<ItemConfiguredEvent><br>`purchase_events`: event::EventHandle<ItemPurchasedEvent><br>`snapshot_events`: event::EventHandle<StoreSnapshotUpdatedEvent> |
| Ресурс | `StoreAccess` | key | `cap`: MultiTreasuryCap |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `ItemConfiguredEvent` | drop, store, copy | `lottery_id`: u64<br>`item_id`: u64<br>`price`: u64<br>`available`: bool<br>`stock`: option::Option<u64><br>`metadata`: vector<u8> |
| Событие | `ItemPurchasedEvent` | drop, store, copy | `lottery_id`: u64<br>`item_id`: u64<br>`buyer`: address<br>`quantity`: u64<br>`total_price`: u64 |
| Структура | `StoreItemSnapshot` | copy, drop, store | `item_id`: u64<br>`price`: u64<br>`available`: bool<br>`stock`: option::Option<u64><br>`sold`: u64<br>`metadata`: vector<u8> |
| Структура | `StoreLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`items`: vector<StoreItemSnapshot> |
| Структура | `StoreSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<StoreLotterySnapshot> |
| Событие | `StoreSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`snapshot`: StoreLotterySnapshot |
| Структура | `ItemWithStats` | copy, drop, store | `item`: StoreItem<br>`sold`: u64 |
| Структура | `LegacyStoreItem` | drop, store | `lottery_id`: u64<br>`item_id`: u64<br>`price`: u64<br>`metadata`: vector<u8><br>`available`: bool<br>`stock`: option::Option<u64><br>`sold`: u64 |

### Модуль `lottery_rewards::rewards_vip` (`SupraLottery/supra/move_workspace/lottery_rewards/sources/Vip.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `VipConfig` | copy, drop, store | `price`: u64<br>`duration_secs`: u64<br>`bonus_tickets`: u64 |
| Структура | `VipSubscription` | copy, drop, store | `expiry_ts`: u64<br>`bonus_tickets`: u64 |
| Структура | `VipLottery` | store | `config`: VipConfig<br>`subscriptions`: table::Table<address, VipSubscription><br>`members`: vector<address><br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |
| Структура | `LegacyVipSubscription` | drop, store | `player`: address<br>`expiry_ts`: u64<br>`bonus_tickets`: u64 |
| Структура | `LegacyVipLottery` | drop, store | `lottery_id`: u64<br>`config`: VipConfig<br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64<br>`members`: vector<address><br>`subscriptions`: vector<LegacyVipSubscription> |
| Ресурс | `VipState` | key | `admin`: address<br>`lotteries`: table::Table<u64, VipLottery><br>`lottery_ids`: vector<u64><br>`config_events`: event::EventHandle<VipConfigUpdatedEvent><br>`subscribed_events`: event::EventHandle<VipSubscribedEvent><br>`cancelled_events`: event::EventHandle<VipCancelledEvent><br>`bonus_events`: event::EventHandle<VipBonusIssuedEvent><br>`snapshot_events`: event::EventHandle<VipSnapshotUpdatedEvent> |
| Ресурс | `VipAccess` | key | `cap`: MultiTreasuryCap |
| Событие | `VipConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`price`: u64<br>`duration_secs`: u64<br>`bonus_tickets`: u64 |
| Событие | `VipSubscribedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`expiry_ts`: u64<br>`bonus_tickets`: u64<br>`amount_paid`: u64<br>`renewed`: bool |
| Событие | `VipCancelledEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address |
| Событие | `VipBonusIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`bonus_tickets`: u64 |
| Структура | `VipLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`config`: VipConfig<br>`total_members`: u64<br>`active_members`: u64<br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |
| Структура | `VipSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<VipLotterySnapshot> |
| Событие | `VipSnapshotUpdatedEvent` | drop, store, copy | `snapshot`: VipSnapshot |
| Структура | `VipSubscriptionView` | copy, drop, store | `expiry_ts`: u64<br>`is_active`: bool<br>`bonus_tickets`: u64 |
| Структура | `VipLotterySummary` | copy, drop, store | `config`: VipConfig<br>`total_members`: u64<br>`active_members`: u64<br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |


## Пакет `lottery_rewards_engine`

### Модуль `lottery_rewards_engine::autopurchase` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Autopurchase.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `AutopurchasePlan` | copy, drop, store | `balance`: u64<br>`tickets_per_draw`: u64<br>`active`: bool |
| Структура | `LotteryPlans` | store | `plans`: table::Table<address, AutopurchasePlan><br>`players`: vector<address><br>`total_balance`: u64 |
| Ресурс | `AutopurchaseState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryPlans><br>`lottery_ids`: vector<u64><br>`deposit_events`: event::EventHandle<AutopurchaseDepositEvent><br>`config_events`: event::EventHandle<AutopurchaseConfigUpdatedEvent><br>`executed_events`: event::EventHandle<AutopurchaseExecutedEvent><br>`refund_events`: event::EventHandle<AutopurchaseRefundedEvent><br>`snapshot_events`: event::EventHandle<AutopurchaseSnapshotUpdatedEvent> |
| Ресурс | `AutopurchaseAccess` | key | `rounds`: rounds::AutopurchaseRoundCap<br>`treasury`: treasury::AutopurchaseTreasuryCap |
| Структура | `AutopurchaseLotterySummary` | copy, drop, store | `total_balance`: u64<br>`total_players`: u64<br>`active_players`: u64 |
| Структура | `AutopurchasePlayerSnapshot` | copy, drop, store | `player`: address<br>`balance`: u64<br>`tickets_per_draw`: u64<br>`active`: bool |
| Структура | `AutopurchaseLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`total_balance`: u64<br>`total_players`: u64<br>`active_players`: u64<br>`players`: vector<AutopurchasePlayerSnapshot> |
| Структура | `AutopurchaseSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<AutopurchaseLotterySnapshot> |
| Событие | `AutopurchaseDepositEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`amount`: u64<br>`new_balance`: u64 |
| Событие | `AutopurchaseConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`tickets_per_draw`: u64<br>`active`: bool |
| Событие | `AutopurchaseExecutedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`tickets_bought`: u64<br>`spent_amount`: u64<br>`remaining_balance`: u64 |
| Событие | `AutopurchaseRefundedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`amount`: u64<br>`remaining_balance`: u64 |
| Событие | `AutopurchaseSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`snapshot`: AutopurchaseLotterySnapshot |

### Модуль `lottery_rewards_engine::referrals` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Referrals.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `ReferralConfig` | copy, drop, store | `referrer_bps`: u64<br>`referee_bps`: u64 |
| Структура | `ReferralStats` | copy, drop, store | `rewarded_purchases`: u64<br>`total_referrer_rewards`: u64<br>`total_referee_rewards`: u64 |
| Ресурс | `ReferralState` | key | `admin`: address<br>`configs`: table::Table<u64, ReferralConfig><br>`stats`: table::Table<u64, ReferralStats><br>`referrers`: table::Table<address, address><br>`lottery_ids`: vector<u64><br>`total_registered`: u64<br>`config_events`: event::EventHandle<ReferralConfigUpdatedEvent><br>`register_events`: event::EventHandle<ReferralRegisteredEvent><br>`cleared_events`: event::EventHandle<ReferralClearedEvent><br>`reward_events`: event::EventHandle<ReferralRewardPaidEvent><br>`snapshot_events`: event::EventHandle<ReferralSnapshotUpdatedEvent> |
| Ресурс | `ReferralsControl` | key | `treasury_cap`: treasury_multi::MultiTreasuryCap |
| Структура | `LotteryReferralSnapshot` | copy, drop, store | `lottery_id`: u64<br>`referrer_bps`: u64<br>`referee_bps`: u64<br>`rewarded_purchases`: u64<br>`total_referrer_rewards`: u64<br>`total_referee_rewards`: u64 |
| Структура | `ReferralSnapshot` | copy, drop, store | `admin`: address<br>`total_registered`: u64<br>`lotteries`: vector<LotteryReferralSnapshot> |
| Структура | `LegacyReferralLottery` | drop, store | `lottery_id`: u64<br>`referrer_bps`: u64<br>`referee_bps`: u64<br>`rewarded_purchases`: u64<br>`total_referrer_rewards`: u64<br>`total_referee_rewards`: u64 |
| Структура | `LegacyReferralRegistration` | drop, store | `player`: address<br>`referrer`: address |
| Событие | `ReferralSnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<ReferralSnapshot><br>`current`: ReferralSnapshot |
| Событие | `ReferralConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`referrer_bps`: u64<br>`referee_bps`: u64 |
| Событие | `ReferralRegisteredEvent` | drop, store, copy | `player`: address<br>`referrer`: address<br>`by_admin`: bool |
| Событие | `ReferralClearedEvent` | drop, store, copy | `player`: address<br>`by_admin`: bool |
| Событие | `ReferralRewardPaidEvent` | drop, store, copy | `lottery_id`: u64<br>`buyer`: address<br>`referrer`: address<br>`referrer_amount`: u64<br>`referee_amount`: u64<br>`total_amount`: u64 |

### Модуль `lottery_rewards_engine::jackpot` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Jackpot.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacyJackpotRuntime` | drop, store | `lottery_id`: u64<br>`tickets`: vector<address><br>`draw_scheduled`: bool<br>`pending_request_id`: option::Option<u64><br>`pending_payload`: option::Option<vector<u8>> |

### Модуль `lottery_rewards_engine::payouts` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Payouts.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_rewards_engine::store` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Store.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `StoreItem` | copy, drop, store | `price`: u64<br>`metadata`: vector<u8><br>`available`: bool<br>`stock`: option::Option<u64> |
| Структура | `StoreRecord` | store | `item`: StoreItem<br>`sold`: u64 |
| Структура | `LotteryStore` | store | `items`: table::Table<u64, StoreRecord><br>`item_ids`: vector<u64> |
| Ресурс | `StoreState` | key | `admin`: address<br>`lotteries`: table::Table<u64, LotteryStore><br>`lottery_ids`: vector<u64><br>`admin_events`: event::EventHandle<AdminUpdatedEvent><br>`item_events`: event::EventHandle<ItemConfiguredEvent><br>`purchase_events`: event::EventHandle<ItemPurchasedEvent><br>`snapshot_events`: event::EventHandle<StoreSnapshotUpdatedEvent> |
| Ресурс | `StoreAccess` | key | `cap`: treasury_multi::MultiTreasuryCap |
| Событие | `AdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Событие | `ItemConfiguredEvent` | drop, store, copy | `lottery_id`: u64<br>`item_id`: u64<br>`price`: u64<br>`available`: bool<br>`stock`: option::Option<u64><br>`metadata`: vector<u8> |
| Событие | `ItemPurchasedEvent` | drop, store, copy | `lottery_id`: u64<br>`item_id`: u64<br>`buyer`: address<br>`quantity`: u64<br>`total_price`: u64 |
| Структура | `StoreItemSnapshot` | copy, drop, store | `item_id`: u64<br>`price`: u64<br>`available`: bool<br>`stock`: option::Option<u64><br>`sold`: u64<br>`metadata`: vector<u8> |
| Структура | `StoreLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`items`: vector<StoreItemSnapshot> |
| Структура | `StoreSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<StoreLotterySnapshot> |
| Событие | `StoreSnapshotUpdatedEvent` | drop, store, copy | `admin`: address<br>`snapshot`: StoreLotterySnapshot |
| Структура | `ItemWithStats` | copy, drop, store | `item`: StoreItem<br>`sold`: u64 |
| Структура | `LegacyStoreItem` | drop, store | `lottery_id`: u64<br>`item_id`: u64<br>`price`: u64<br>`metadata`: vector<u8><br>`available`: bool<br>`stock`: option::Option<u64><br>`sold`: u64 |

### Модуль `lottery_rewards_engine::treasury` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Treasury.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_rewards_engine::vip` (`SupraLottery/supra/move_workspace/lottery_rewards_engine/sources/Vip.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `VipConfig` | copy, drop, store | `price`: u64<br>`duration_secs`: u64<br>`bonus_tickets`: u64 |
| Структура | `VipSubscription` | copy, drop, store | `expiry_ts`: u64<br>`bonus_tickets`: u64 |
| Структура | `VipLottery` | store | `config`: VipConfig<br>`subscriptions`: table::Table<address, VipSubscription><br>`members`: vector<address><br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |
| Ресурс | `VipState` | key | `admin`: address<br>`lotteries`: table::Table<u64, VipLottery><br>`lottery_ids`: vector<u64><br>`config_events`: event::EventHandle<VipConfigUpdatedEvent><br>`subscribed_events`: event::EventHandle<VipSubscribedEvent><br>`cancelled_events`: event::EventHandle<VipCancelledEvent><br>`bonus_events`: event::EventHandle<VipBonusIssuedEvent><br>`snapshot_events`: event::EventHandle<VipSnapshotUpdatedEvent> |
| Ресурс | `VipAccess` | key | `cap`: treasury_multi::MultiTreasuryCap |
| Событие | `VipConfigUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`price`: u64<br>`duration_secs`: u64<br>`bonus_tickets`: u64 |
| Событие | `VipSubscribedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`expiry_ts`: u64<br>`bonus_tickets`: u64<br>`amount_paid`: u64<br>`renewed`: bool |
| Событие | `VipCancelledEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address |
| Событие | `VipBonusIssuedEvent` | drop, store, copy | `lottery_id`: u64<br>`player`: address<br>`bonus_tickets`: u64 |
| Структура | `VipLotterySnapshot` | copy, drop, store | `lottery_id`: u64<br>`config`: VipConfig<br>`total_members`: u64<br>`active_members`: u64<br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |
| Структура | `VipSnapshot` | copy, drop, store | `admin`: address<br>`lotteries`: vector<VipLotterySnapshot> |
| Событие | `VipSnapshotUpdatedEvent` | drop, store, copy | `snapshot`: VipSnapshot |
| Структура | `VipSubscriptionView` | copy, drop, store | `expiry_ts`: u64<br>`is_active`: bool<br>`bonus_tickets`: u64 |
| Структура | `VipLotterySummary` | copy, drop, store | `config`: VipConfig<br>`total_members`: u64<br>`active_members`: u64<br>`total_revenue`: u64<br>`bonus_tickets_issued`: u64 |


## Пакет `lottery_support`

### Модуль `lottery_support::support_history` (`SupraLottery/supra/move_workspace/lottery_support/sources/History.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryHistory` | store | `records`: vector<DrawRecord> |
| Ресурс | `HistoryCollection` | key | `admin`: address<br>`histories`: table::Table<u64, LotteryHistory><br>`lottery_ids`: vector<u64><br>`record_events`: event::EventHandle<DrawRecordedEvent><br>`snapshot_events`: event::EventHandle<HistorySnapshotUpdatedEvent> |
| Ресурс | `HistoryWarden` | key | `writer`: HistoryWriterCap |
| Структура | `DrawRecord` | copy, drop, store | `request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8><br>`timestamp_seconds`: u64 |
| Структура | `LotteryHistorySnapshot` | copy, drop, store | `lottery_id`: u64<br>`records`: vector<DrawRecord> |
| Структура | `HistorySnapshot` | copy, drop, store | `admin`: address<br>`lottery_ids`: vector<u64><br>`histories`: vector<LotteryHistorySnapshot> |
| Событие | `DrawRecordedEvent` | copy, drop, store | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`timestamp_seconds`: u64 |
| Событие | `HistorySnapshotUpdatedEvent` | copy, drop, store | `previous`: option::Option<HistorySnapshot><br>`current`: HistorySnapshot |

### Модуль `lottery_support::history_bridge` (`SupraLottery/supra/move_workspace/lottery_support/sources/HistoryBridge.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacySummary` | copy, drop, store | `summary_bcs`: vector<u8><br>`archive_hash`: vector<u8><br>`finalized_at`: u64 |
| Структура | `LegacySummaryEvent` | drop, store | `lottery_id`: u64<br>`archive_hash`: vector<u8><br>`finalized_at`: u64 |
| Ресурс | `LegacyArchive` | key | `summaries`: table::Table<u64, LegacySummary><br>`summary_events`: event::EventHandle<LegacySummaryEvent> |

### Модуль `lottery_support::support_metadata` (`SupraLottery/supra/move_workspace/lottery_support/sources/Metadata.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryMetadata` | copy, drop, store | `title`: vector<u8><br>`description`: vector<u8><br>`image_uri`: vector<u8><br>`website_uri`: vector<u8><br>`rules_uri`: vector<u8> |
| Ресурс | `MetadataRegistry` | key | `admin`: address<br>`entries`: table::Table<u64, LotteryMetadata><br>`lottery_ids`: vector<u64> |
| Событие | `LotteryMetadataUpsertedEvent` | drop, store, copy | `lottery_id`: u64<br>`created`: bool<br>`metadata`: LotteryMetadata |
| Событие | `LotteryMetadataRemovedEvent` | drop, store, copy | `lottery_id`: u64 |
| Событие | `MetadataAdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Структура | `MetadataEntry` | copy, drop, store | `lottery_id`: u64<br>`metadata`: LotteryMetadata |
| Структура | `MetadataSnapshot` | copy, drop, store | `admin`: address<br>`entries`: vector<MetadataEntry> |
| Событие | `MetadataSnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<MetadataSnapshot><br>`current`: MetadataSnapshot |

### Модуль `lottery_support::support_migration` (`SupraLottery/supra/move_workspace/lottery_support/sources/Migration.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `MigrationLedger` | key | `snapshots`: table::Table<u64, MigrationSnapshot><br>`lottery_ids`: vector<u64><br>`snapshot_events`: event::EventHandle<MigrationSnapshotUpdatedEvent> |
| Структура | `MigrationSnapshot` | copy, drop, store | `lottery_id`: u64<br>`ticket_count`: u64<br>`legacy_next_ticket_id`: u64<br>`migrated_next_ticket_id`: u64<br>`legacy_draw_scheduled`: bool<br>`migrated_draw_scheduled`: bool<br>`legacy_pending_request`: bool<br>`jackpot_amount_migrated`: u64<br>`prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Событие | `MigrationSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`snapshot`: MigrationSnapshot |
| Ресурс | `MigrationSession` | key | `instances_cap`: option::Option<instances::InstancesExportCap><br>`legacy_cap`: option::Option<treasury::LegacyTreasuryCap> |


## Пакет `lottery_utils`

### Модуль `lottery_utils::feature_flags` (`SupraLottery/supra/move_workspace/lottery_utils/sources/FeatureFlags.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `FeatureRecord` | store | `mode`: u8 |
| Ресурс | `FeatureRegistry` | key | `admin`: address<br>`force_enable_devnet`: bool<br>`entries`: table::Table<u64, FeatureRecord><br>`updates`: event::EventHandle<FeatureUpdatedEvent> |
| Структура | `FeatureUpdatedEvent` | drop, store | `feature_id`: u64<br>`previous_mode`: option::Option<u8><br>`new_mode`: u8 |

### Модуль `lottery_utils::history` (`SupraLottery/supra/move_workspace/lottery_utils/sources/History.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryHistory` | store | `records`: vector<DrawRecord> |
| Ресурс | `HistoryCollection` | key | `admin`: address<br>`histories`: table::Table<u64, LotteryHistory><br>`lottery_ids`: vector<u64><br>`record_events`: event::EventHandle<DrawRecordedEvent><br>`snapshot_events`: event::EventHandle<HistorySnapshotUpdatedEvent> |
| Ресурс | `HistoryWarden` | key | `writer`: rounds::HistoryWriterCap |
| Структура | `DrawRecord` | copy, drop, store | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8><br>`timestamp_seconds`: u64 |
| Структура | `LegacyHistoryRecord` | drop, store | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`random_bytes`: vector<u8><br>`payload`: vector<u8><br>`timestamp_seconds`: u64 |
| Структура | `LotteryHistorySnapshot` | copy, drop, store | `lottery_id`: u64<br>`records`: vector<DrawRecord> |
| Структура | `HistorySnapshot` | copy, drop, store | `admin`: address<br>`lottery_ids`: vector<u64><br>`histories`: vector<LotteryHistorySnapshot> |
| Событие | `DrawRecordedEvent` | drop, store, copy | `lottery_id`: u64<br>`request_id`: u64<br>`winner`: address<br>`ticket_index`: u64<br>`prize_amount`: u64<br>`timestamp_seconds`: u64 |
| Событие | `HistorySnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<HistorySnapshot><br>`current`: HistorySnapshot |

### Модуль `lottery_utils::math` (`SupraLottery/supra/move_workspace/lottery_utils/sources/Math.move`)

> В этом модуле структур с `struct ... has ...` не найдено.

### Модуль `lottery_utils::metadata` (`SupraLottery/supra/move_workspace/lottery_utils/sources/Metadata.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryMetadata` | copy, drop, store | `title`: vector<u8><br>`description`: vector<u8><br>`image_uri`: vector<u8><br>`website_uri`: vector<u8><br>`rules_uri`: vector<u8> |
| Структура | `LegacyMetadataImport` | copy, drop, store | `lottery_id`: u64<br>`metadata`: LotteryMetadata |
| Ресурс | `MetadataRegistry` | key | `admin`: address<br>`entries`: table::Table<u64, LotteryMetadata><br>`lottery_ids`: vector<u64><br>`upsert_events`: event::EventHandle<LotteryMetadataUpsertedEvent><br>`remove_events`: event::EventHandle<LotteryMetadataRemovedEvent><br>`admin_events`: event::EventHandle<MetadataAdminUpdatedEvent><br>`snapshot_events`: event::EventHandle<MetadataSnapshotUpdatedEvent> |
| Событие | `LotteryMetadataUpsertedEvent` | drop, store, copy | `lottery_id`: u64<br>`created`: bool<br>`metadata`: LotteryMetadata |
| Событие | `LotteryMetadataRemovedEvent` | drop, store, copy | `lottery_id`: u64 |
| Событие | `MetadataAdminUpdatedEvent` | drop, store, copy | `previous`: address<br>`next`: address |
| Структура | `MetadataEntry` | copy, drop, store | `lottery_id`: u64<br>`metadata`: LotteryMetadata |
| Структура | `MetadataSnapshot` | copy, drop, store | `admin`: address<br>`entries`: vector<MetadataEntry> |
| Событие | `MetadataSnapshotUpdatedEvent` | drop, store, copy | `previous`: option::Option<MetadataSnapshot><br>`current`: MetadataSnapshot |

### Модуль `lottery_utils::migration` (`SupraLottery/supra/move_workspace/lottery_utils/sources/Migration.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Ресурс | `MigrationLedger` | key | `snapshots`: table::Table<u64, MigrationSnapshot><br>`lottery_ids`: vector<u64><br>`snapshot_events`: event::EventHandle<MigrationSnapshotUpdatedEvent> |
| Структура | `MigrationSnapshot` | copy, drop, store | `lottery_id`: u64<br>`ticket_count`: u64<br>`legacy_next_ticket_id`: u64<br>`migrated_next_ticket_id`: u64<br>`legacy_draw_scheduled`: bool<br>`migrated_draw_scheduled`: bool<br>`legacy_pending_request`: bool<br>`jackpot_amount_migrated`: u64<br>`prize_bps`: u64<br>`jackpot_bps`: u64<br>`operations_bps`: u64 |
| Событие | `MigrationSnapshotUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`snapshot`: MigrationSnapshot |
| Ресурс | `MigrationSession` | key | `instances_cap`: option::Option<instances::InstancesExportCap><br>`legacy_cap`: option::Option<treasury::LegacyTreasuryCap> |

### Модуль `lottery_utils::price_feed` (`SupraLottery/supra/move_workspace/lottery_utils/sources/PriceFeed.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `PriceFeedRecord` | store | `asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`last_updated_ts`: u64<br>`staleness_window`: u64<br>`clamp_threshold_bps`: u64<br>`fallback_active`: bool<br>`fallback_reason`: u8<br>`clamp_active`: bool |
| Структура | `PriceFeedUpdatedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`updated_ts`: u64 |
| Структура | `PriceFeedFallbackEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`fallback_active`: bool<br>`reason`: u8 |
| Структура | `PriceFeedClampEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`old_price`: u64<br>`new_price`: u64<br>`threshold_bps`: u64 |
| Структура | `PriceFeedClampClearedEvent` | drop, store | `event_version`: u16<br>`event_category`: u8<br>`asset_id`: u64<br>`cleared_ts`: u64 |
| Структура | `PriceFeedView` | drop, store | `asset_id`: u64<br>`price`: u64<br>`decimals`: u8<br>`last_updated_ts`: u64<br>`staleness_window`: u64<br>`clamp_threshold_bps`: u64<br>`fallback_active`: bool<br>`fallback_reason`: u8<br>`clamp_active`: bool |
| Ресурс | `PriceFeedRegistry` | key | `admin`: address<br>`version`: u16<br>`feeds`: table::Table<u64, PriceFeedRecord><br>`updates`: event::EventHandle<PriceFeedUpdatedEvent><br>`fallbacks`: event::EventHandle<PriceFeedFallbackEvent><br>`clamps`: event::EventHandle<PriceFeedClampEvent><br>`clamp_clears`: event::EventHandle<PriceFeedClampClearedEvent> |


## Пакет `lottery_vrf_gateway`

### Модуль `lottery_vrf_gateway::table` (`SupraLottery/supra/move_workspace/lottery_vrf_gateway/sources/Table.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `Table<K: copy + drop, V: store>` | store | `keys`: vector<K><br>`values`: vector<V> |

### Модуль `lottery_vrf_gateway::hub` (`SupraLottery/supra/move_workspace/lottery_vrf_gateway/sources/Hub.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LegacyLotteryRegistration` | drop, store | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address<br>`metadata`: vector<u8><br>`active`: bool |
| Структура | `LegacyRequestRecord` | drop, store | `request_id`: u64<br>`lottery_id`: u64<br>`payload`: vector<u8><br>`payload_hash`: vector<u8> |
| Структура | `LegacyHubState` | drop, store | `admin`: address<br>`next_lottery_id`: u64<br>`next_request_id`: u64<br>`lotteries`: vector<LegacyLotteryRegistration><br>`requests`: vector<LegacyRequestRecord><br>`lottery_ids`: vector<u64><br>`pending_request_ids`: vector<u64><br>`callback_sender`: option::Option<address> |
| Структура | `LotteryRegistration` | copy, drop, store | `owner`: address<br>`lottery`: address<br>`metadata`: vector<u8><br>`active`: bool |
| Структура | `RequestRecord` | copy, drop, store | `lottery_id`: u64<br>`payload`: vector<u8><br>`payload_hash`: vector<u8> |
| Ресурс | `HubState` | key | `admin`: address<br>`next_lottery_id`: u64<br>`next_request_id`: u64<br>`lotteries`: table::Table<u64, LotteryRegistration><br>`requests`: table::Table<u64, RequestRecord><br>`lottery_ids`: vector<u64><br>`pending_request_ids`: vector<u64><br>`callback_sender`: option::Option<address><br>`register_events`: event::EventHandle<LotteryRegisteredEvent><br>`status_events`: event::EventHandle<LotteryStatusChangedEvent><br>`metadata_events`: event::EventHandle<LotteryMetadataUpdatedEvent><br>`request_events`: event::EventHandle<RandomnessRequestedEvent><br>`fulfill_events`: event::EventHandle<RandomnessFulfilledEvent><br>`callback_sender_events`: event::EventHandle<CallbackSenderUpdatedEvent> |
| Событие | `LotteryRegisteredEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address |
| Событие | `LotteryStatusChangedEvent` | drop, store, copy | `lottery_id`: u64<br>`active`: bool |
| Событие | `LotteryMetadataUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`metadata`: vector<u8> |
| Событие | `RandomnessRequestedEvent` | drop, store, copy | `request_id`: u64<br>`lottery_id`: u64<br>`payload`: vector<u8><br>`payload_hash`: vector<u8> |
| Событие | `RandomnessFulfilledEvent` | drop, store, copy | `request_id`: u64<br>`lottery_id`: u64<br>`randomness`: vector<u8> |
| Событие | `CallbackSenderUpdatedEvent` | drop, store, copy | `previous`: option::Option<address><br>`current`: option::Option<address> |
| Структура | `CallbackSenderStatus` | copy, drop | `sender`: option::Option<address> |
| Структура | `HubSnapshot` | copy, drop, store | `admin`: address<br>`next_lottery_id`: u64<br>`next_request_id`: u64<br>`lotteries`: vector<LotteryRegistration><br>`requests`: vector<RequestRecord><br>`lottery_ids`: vector<u64><br>`pending_request_ids`: vector<u64><br>`callback_sender`: option::Option<address> |


## Пакет `vrf_hub`

### Модуль `vrf_hub::table` (`SupraLottery/supra/move_workspace/vrf_hub/sources/Table.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `Table<K: copy + drop, V: store>` | store | `keys`: vector<K><br>`values`: vector<V> |

### Модуль `vrf_hub::hub` (`SupraLottery/supra/move_workspace/vrf_hub/sources/VRFHub.move`)

| Категория | Структура | Способности | Поля |
| --- | --- | --- | --- |
| Структура | `LotteryRegistration` | copy, drop, store | `owner`: address<br>`lottery`: address<br>`metadata`: vector<u8><br>`active`: bool |
| Структура | `RequestRecord` | copy, drop, store | `lottery_id`: u64<br>`payload`: vector<u8><br>`payload_hash`: vector<u8> |
| Ресурс | `HubState` | key | `admin`: address<br>`next_lottery_id`: u64<br>`next_request_id`: u64<br>`lotteries`: table::Table<u64, LotteryRegistration><br>`requests`: table::Table<u64, RequestRecord><br>`lottery_ids`: vector<u64><br>`pending_request_ids`: vector<u64><br>`callback_sender`: option::Option<address><br>`register_events`: event::EventHandle<LotteryRegisteredEvent><br>`status_events`: event::EventHandle<LotteryStatusChangedEvent><br>`metadata_events`: event::EventHandle<LotteryMetadataUpdatedEvent><br>`request_events`: event::EventHandle<RandomnessRequestedEvent><br>`fulfill_events`: event::EventHandle<RandomnessFulfilledEvent><br>`callback_sender_events`: event::EventHandle<CallbackSenderUpdatedEvent> |
| Событие | `LotteryRegisteredEvent` | drop, store, copy | `lottery_id`: u64<br>`owner`: address<br>`lottery`: address |
| Событие | `LotteryStatusChangedEvent` | drop, store, copy | `lottery_id`: u64<br>`active`: bool |
| Событие | `LotteryMetadataUpdatedEvent` | drop, store, copy | `lottery_id`: u64<br>`metadata`: vector<u8> |
| Событие | `RandomnessRequestedEvent` | drop, store, copy | `request_id`: u64<br>`lottery_id`: u64<br>`payload`: vector<u8><br>`payload_hash`: vector<u8> |
| Событие | `RandomnessFulfilledEvent` | drop, store, copy | `request_id`: u64<br>`lottery_id`: u64<br>`randomness`: vector<u8> |
| Событие | `CallbackSenderUpdatedEvent` | drop, store, copy | `previous`: option::Option<address><br>`current`: option::Option<address> |
| Структура | `CallbackSenderStatus` | copy, drop | `sender`: option::Option<address> |


