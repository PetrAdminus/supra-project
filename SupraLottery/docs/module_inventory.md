# Инвентаризация Move-модулей SupraLottery

Документ фиксирует состав пакетов Move в рабочей области `SupraLottery/supra/move_workspace` и ключевые публичные entry-функции, ресурсы и события.

## Пакет `lottery`

### `Lottery.move`
- **Публичные entry-функции**: `init`, `buy_ticket`, `create_subscription`, `whitelist_callback_sender`, `revoke_callback_sender`, `whitelist_consumer`, `remove_consumer`, `set_minimum_balance`, `configure_vrf_gas`, `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request`, `withdraw_funds`, `remove_subscription`, `manual_draw`, `simple_draw`, `on_random_received`.
- **Ресурсы (`has key`)**: `LotteryData`.
- **События**: `TicketBought`, `WinnerSelected`, `SubscriptionConfiguredEvent`, `MinimumBalanceUpdatedEvent`, `ClientWhitelistRecordedEvent`, `ConsumerWhitelistSnapshotRecordedEvent`, `WhitelistSnapshotUpdatedEvent`, `VrfRequestConfigUpdatedEvent`, `GasConfigUpdatedEvent`, `AggregatorWhitelistedEvent`, `AggregatorRevokedEvent`, `ConsumerWhitelistedEvent`, `ConsumerRemovedEvent`, `DrawRequestedEvent`, `DrawHandledEvent`, `FundsWithdrawnEvent`, `SubscriptionContractRemovedEvent`.
- **Особенности dVRF**: `DrawRequestedEvent` публикует SHA3-хеш `CallbackRequest`, whitelisted `callback_sender` (агрегатора Supra) и полный набор параметров Supra (адрес/модуль/функция колбэка, `rng_count`, `num_confirmations`, конфигурации газа), что соответствует гайду dVRF 3.0. `DrawHandledEvent` зеркалирует те же поля и добавляет BCS-вектор `randomness`, что позволяет сопоставлять fulfilled события с исходной заявкой и VRF Hub.
- **Конфигурация VRF**: `VrfRequestConfigUpdatedEvent` логирует текущие `rng_count`, `num_confirmations`, `client_seed`, а view-функции возвращают те же поля для мониторинга.
- **Мониторинг заявок**: view-функция `get_pending_request_view` возвращает структуру `PendingRequestView` (nonce, whitelisted requester, `callback_sender`, `request_hash`, `rng_count`, `num_confirmations`, `client_seed`, значения `maxGasPrice/maxGasLimit`, `callbackGasPrice/callbackGasLimit`, `verificationGasValue`), что облегчает сверку с событиями и Supra dVRF CLI.
- **Whitelisting агрегатора и потребителей**: `WhitelistSnapshotUpdatedEvent` публикуется при каждой операции `whitelist_callback_sender`/`revoke_callback_sender`/`whitelist_consumer`/`remove_consumer`/`init` и содержит whitelisted агрегатор и полный список потребителей; `get_whitelist_status` возвращает такой же снимок для мониторинга Supra без разбора журнала.

### `LotteryRounds.move`
- **Публичные entry-функции**: `init`, `set_admin`, `buy_ticket`, `schedule_draw`, `reset_round`, `request_randomness`, `fulfill_draw`.
- **Ресурсы**: `RoundCollection`.
- **События**: `TicketPurchasedEvent`, `DrawScheduleUpdatedEvent`, `RoundResetEvent`, `DrawRequestIssuedEvent`, `DrawFulfilledEvent`, `RoundSnapshotUpdatedEvent` (публикует агрегированный `RoundSnapshot` с числом билетов, статусом расписания, `pending_request_id` и `next_ticket_id`).
- **View-функции**: `get_round_snapshot` (возвращает ту же структуру `RoundSnapshot`, что и событие снапшота) и `pending_request_id` (сохраняет совместимость с прежним API, выдавая `option<u64>` идентификатора активной заявки).

### `LotteryInstances.move`
- **Публичные entry-функции**: `init`, `set_admin`, `set_hub`, `set_instance_active`, `create_instance`, `sync_blueprint`.
- **Ресурсы**: `LotteryCollection`.
- **События**: `LotteryInstanceCreatedEvent`, `LotteryInstanceBlueprintSyncedEvent`, `AdminUpdatedEvent`, `HubAddressUpdatedEvent`, `LotteryInstanceStatusUpdatedEvent`, `LotteryInstancesSnapshotUpdatedEvent` (агрегированный снимок администратора, адреса VRF-хаба и параметров конкретного экземпляра).
- **View-функции**: `hub_address`, `admin`, `instance_count`, `contains_instance`, `get_lottery_info`, `get_instance_stats`, `list_lottery_ids`, `list_active_lottery_ids`, `is_instance_active`, `get_instance_snapshot`, `get_instances_snapshot`.
- **View-структуры**: `LotteryInstanceSnapshot` (владелец, адрес контракта, цена билета, доля джекпота, накопленные продажи/взносы и статус), `LotteryInstancesSnapshot` (администратор, адрес VRF-хаба и список снимков по всем экземплярам).

### `Treasury.move`
- **Публичные entry-функции**: `init_token`, `register_store`, `register_store_for`, `register_stores_for`, `mint_to`, `burn_from`, `transfer_between`, `set_store_frozen`, `set_recipients`, `set_config`.
- **Ресурсы**: `Vaults` (basis points и адреса получателей), `TokenState` (обёртка над `supra_framework::fungible_asset` с `metadata`, `MintRef`, `BurnRef`, `TransferRef`).
- **События**: `ConfigUpdatedEvent`, `RecipientsUpdatedEvent`, `JackpotDistributedEvent`.
- **View/тестовые хелперы**: `get_recipients`, `get_recipient_statuses`, `recipient_status_fields_for_test`, `metadata_summary`, `account_status`, `account_extended_status`.
- **Особенности**: операции депозита/выплат используют primary store через `supra_framework::primary_fungible_store`, проверяют freeze-флаг `fungible_asset::is_frozen`; `set_recipients` требует зарегистрированных и незамороженных store, `RecipientsUpdatedEvent` публикует парные снапшоты `VaultRecipientsSnapshot` (предыдущие и текущие статусы направлений) при инициализации и каждом обновлении, а `get_recipient_statuses` возвращает адрес, регистрацию, freeze и баланс для мониторинга Supra.

### `TreasuryMulti.move`
- **Публичные entry-функции**: `init`, `set_admin`, `set_recipients`, `upsert_lottery_config`, `record_allocation`, `distribute_prize`, `withdraw_operations`, `distribute_jackpot`.
- **Ресурсы**: `TreasuryState`.
- **События**: `LotteryConfigUpdatedEvent`, `AllocationRecordedEvent`, `AdminUpdatedEvent`, `RecipientsUpdatedEvent`, `PrizePaidEvent`, `OperationsWithdrawnEvent`, `OperationsIncomeRecordedEvent`, `OperationsBonusPaidEvent`, `JackpotPaidEvent`.
- **View-функции**: `list_lottery_ids`, `get_lottery_summary`, `get_config`, `get_pool`, `get_recipients`, `get_recipient_statuses`, `jackpot_balance`.
- **Особенности**: `init` и `set_recipients` проверяют готовность `treasury_v1`, регистрацию и отсутствие freeze у адресов пулов (`E_TREASURY_NOT_READY`, `E_JACKPOT_RECIPIENT_UNREGISTERED`, `E_OPERATIONS_RECIPIENT_UNREGISTERED`, `E_JACKPOT_RECIPIENT_FROZEN`, `E_OPERATIONS_RECIPIENT_FROZEN`); `RecipientsUpdatedEvent` публикует снимки `RecipientStatus` для предыдущих и новых адресов при инициализации и каждой смене получателей; `withdraw_operations`, `pay_operations_bonus_internal` и `distribute_jackpot` валидируют получателей и победителей перед выплатой (`E_OPERATIONS_RECIPIENT_FROZEN`, `E_BONUS_RECIPIENT_UNREGISTERED`, `E_BONUS_RECIPIENT_FROZEN`, `E_JACKPOT_WINNER_UNREGISTERED`, `E_JACKPOT_WINNER_FROZEN`); `get_recipient_statuses` возвращает структуру `RecipientStatus` с признаками регистрации, фризом и балансом Supra FA для каждого пула.

### `Referrals.move`
- **Публичные entry-функции**: `init`, `set_admin`, `set_lottery_config`, `register_referrer`, `admin_set_referrer`, `admin_clear_referrer`.
- **Ресурсы**: `ReferralState` (администратор, таблица конфигураций по `lottery_id`, статистика выплат и связи игрок → реферер).
- **События**: `ReferralConfigUpdatedEvent`, `ReferralRegisteredEvent`, `ReferralClearedEvent`, `ReferralRewardPaidEvent`, `ReferralSnapshotUpdatedEvent` (агрегированный снимок с админом, общим счётчиком регистраций и данными по каждой настроенной лотерее).
- **View-функции**: `is_initialized`, `admin`, `total_registered`, `get_referrer`, `get_lottery_config`, `get_lottery_stats`, `list_lottery_ids`, `get_referral_snapshot`.
- **Особенности**: `set_lottery_config` валидирует доли с учётом операционного пула `treasury_multi`; `record_purchase` вызывается из `rounds::complete_purchase`, рассчитывает бонусы, списывает их через `treasury_multi::pay_operations_bonus_internal` и обновляет статистику, после чего `ReferralSnapshotUpdatedEvent` и view `get_referral_snapshot` фиксируют актуальные коэффициенты и суммы реферальных выплат Supra.

### `Jackpot.move`
- **Публичные entry-функции**: `init`, `set_admin`, `grant_ticket`, `grant_tickets_batch`, `schedule_draw`, `reset`, `request_randomness`, `fulfill_draw`.
- **Ресурсы**: `JackpotState`.
- **События**: `JackpotTicketGrantedEvent`, `JackpotScheduleUpdatedEvent`, `JackpotRequestIssuedEvent`, `JackpotFulfilledEvent`, `JackpotSnapshotUpdatedEvent` (агрегированный снимок с администратором, `lottery_id`, количеством билетов и `pending_request_id`).
- **View-функции**: `is_initialized`, `admin`, `lottery_id`, `get_snapshot`, `pending_request`.
- **View-структуры**: `JackpotSnapshot` (адрес администратора, `lottery_id`, количество билетов, статус расписания и `pending_request_id`).

### `History.move`
- **Публичные entry-функции**: `init`, `set_admin`, `clear_history`.
- **View-функции**: `has_history`, `list_lottery_ids`, `get_history`, `latest_record`, `get_lottery_snapshot`, `get_history_snapshot`.
- **Ресурсы**: `HistoryCollection`.
- **События**: `DrawRecordedEvent`, `HistorySnapshotUpdatedEvent` (агрегированный снимок администратора, списка лотерей и последних `DrawRecord`).
- **View-структуры**: `LotteryHistorySnapshot`, `HistorySnapshot`.

### `Metadata.move`
- **Публичные entry-функции**: `init`, `set_admin`, `upsert_metadata`, `remove_metadata`.
- **View-функции**: `list_lottery_ids`, `has_metadata`, `get_metadata`, `get_metadata_snapshot`.
- **Ресурсы**: `MetadataRegistry`.
- **События**: `LotteryMetadataUpsertedEvent`, `LotteryMetadataRemovedEvent`, `MetadataAdminUpdatedEvent`, `MetadataSnapshotUpdatedEvent`.
- **View-структуры**: `MetadataSnapshot` (адрес администратора и список `MetadataEntry` с метаданными по каждому `lottery_id`).

### `Store.move`
- **Публичные entry-функции**: `init`, `set_admin`, `upsert_item`, `set_availability`, `purchase`.
- **View-функции**: `is_initialized`, `admin`, `get_item`, `get_item_with_stats`, `list_lottery_ids`, `list_item_ids`, `get_lottery_summary`, `get_lottery_snapshot`, `get_store_snapshot`.
- **Ресурсы**: `StoreState`.
- **События**: `AdminUpdatedEvent`, `ItemConfiguredEvent`, `ItemPurchasedEvent`, `StoreSnapshotUpdatedEvent` (агрегированный снимок администратора и ассортимента по лотерее).
- **View-структуры**: `StoreItemSnapshot`, `StoreLotterySnapshot`, `StoreSnapshot`.

### `Operators.move`
- **Публичные entry-функции**: `init`, `set_admin`, `set_owner`, `grant_operator`, `revoke_operator`.
- **View-функции**: `is_initialized`, `get_owner`, `can_manage`, `list_lottery_ids`, `list_operators`, `get_operator_snapshot`.
- **Ресурсы**: `LotteryOperators`.
- **События**: `AdminUpdatedEvent`, `OwnerUpdatedEvent`, `OperatorGrantedEvent`, `OperatorRevokedEvent`, `OperatorSnapshotUpdatedEvent`.
- **View-структуры**: `OperatorSnapshot` (владелец и список операторов).

### `Autopurchase.move`
- **Публичные entry-функции**: `init`, `set_admin`, `configure_plan`, `deposit`, `execute`, `refund`.
- **Ресурсы**: `AutopurchaseState`, `AutopurchaseLotterySnapshot`, `AutopurchasePlayerSnapshot`, `AutopurchaseSnapshot`.
- **События**: `AutopurchaseDepositEvent`, `AutopurchaseConfigUpdatedEvent`, `AutopurchaseExecutedEvent`, `AutopurchaseRefundedEvent`, `AutopurchaseSnapshotUpdatedEvent` (публикует администратора и полный список планов по лотерее).
- **View-функции**: `get_plan`, `get_lottery_summary`, `list_lottery_ids`, `list_players`, `get_lottery_snapshot`, `get_autopurchase_snapshot`.

### `Referrals.move`
- **Публичные entry-функции**: `init`, `set_admin`, `set_lottery_config`, `register_referrer`, `admin_set_referrer`, `admin_clear_referrer`.
- **Ресурсы**: `ReferralState`.
- **События**: `ReferralConfigUpdatedEvent`, `ReferralRegisteredEvent`, `ReferralClearedEvent`, `ReferralRewardPaidEvent`.

### `Vip.move`
- **Публичные entry-функции**: `init`, `set_admin`, `upsert_config`, `subscribe`, `subscribe_for`, `cancel`, `cancel_for`.
- **Ресурсы**: `VipState` (хранит таблицу лотерей и event handle снапшота).
- **События**: `VipConfigUpdatedEvent`, `VipSubscribedEvent`, `VipCancelledEvent`, `VipBonusIssuedEvent`, `VipSnapshotUpdatedEvent` (публикует агрегированный `VipSnapshot` с администраторами, конфигурациями и статистикой участников по всем лотереям).
- **View-функции**: `list_lottery_ids`, `list_players`, `get_subscription`, `get_lottery_summary`, `get_lottery_snapshot`, `get_vip_snapshot`.
- **View-структуры**: `VipSubscriptionView`, `VipLotterySummary`, `VipLotterySnapshot`, `VipSnapshot`.

### `Migration.move`
- **Публичные entry-функции**: `migrate_from_legacy`.
- **Ресурсы**: `MigrationLedger` (хранит таблицу снапшотов и event handle).
- **События**: `MigrationSnapshotUpdatedEvent` (публикует агрегированный `MigrationSnapshot` после каждой миграции).
- **View-функции**: `list_migrated_lottery_ids`, `get_migration_snapshot` (возвращает `option<MigrationSnapshot>` для Supra CLI).

### `NftRewards.move`
- **Публичные entry-функции**: `init`, `set_admin`, `mint_badge`, `burn_badge`.
- **Ресурсы**: `BadgeAuthority`.
- **События**: `BadgeMintedEvent`, `BadgeBurnedEvent`, `NftRewardsSnapshotUpdatedEvent` (публикует `BadgeOwnerSnapshot` с текущим администратором и `next_badge_id` после `init`, минта и бёрна).
- **View-функции**: `has_badge`, `list_badges`, `get_badge`, `list_owner_addresses`, `get_owner_snapshot`, `get_snapshot`.
- **View-структуры**: `BadgeSnapshot`, `BadgeOwnerSnapshot`, `NftRewardsSnapshot`.

## Пакет `lottery_factory`

### `LotteryFactory.move`
- **Публичные entry-функции**: `init`, `create_lottery`, `update_blueprint`, `set_admin`.
- **Ресурсы**: `FactoryState` (хранит `lottery_ids` и event handle для снапшотов), `LotteryRegistrySnapshot`.
- **События**: `LotteryPlannedEvent`, `LotteryActivatedEvent`, `LotteryRegistrySnapshotUpdatedEvent` (публикует администратора фабрики и полный список зарегистрированных лотерей вместе с параметрами плана).
- **View-функции**: `is_initialized`, `new_blueprint`, `get_lottery`, `lottery_count`, `list_lottery_ids`, `get_registry_snapshot`.

## Пакет `vrf_hub`

### `VRFHub.move`
- **Публичные entry-функции**: `init`, `register_lottery`, `update_metadata`, `set_lottery_active`, `set_admin`, `set_callback_sender`.
- **Ресурсы**: `HubState`.
- **События**: `LotteryRegisteredEvent`, `LotteryStatusChangedEvent`, `LotteryMetadataUpdatedEvent`, `RandomnessRequestedEvent`, `RandomnessFulfilledEvent`, `CallbackSenderUpdatedEvent`.
  - `RandomnessRequestedEvent` теперь публикует не только BCS-пейлоад, но и `payload_hash` (SHA3-256 от конверта), что позволяет оффчейн-сервисам верифицировать соответствие данным `CallbackRequest` Supra dVRF.
  - `CallbackSenderUpdatedEvent` транслирует предыдущий и текущий whitelisted агрегатор Supra при каждом вызове `set_callback_sender`, предоставляя наблюдаемость верхнего уровня для VRF hub.
- **View-функции**: `callback_sender`, `get_callback_sender_status` (возвращает агрегатора в виде `CallbackSenderStatus` с `option<address>`), `lottery_count`, `list_lottery_ids`, `list_active_lottery_ids`, `get_registration`, `get_request`, `list_pending_request_ids`, `peek_next_lottery_id` и др.

### `Table.move`
- Содержит утилитарные структуры и функции для хранения `vector` данных лотерей (публичных entry-функций нет).

## Пакет `SupraVrf`

### `supra_vrf.move`
- **Публичные функции (native)**: `rng_request`, `verify_callback`. Обе вызываются лотереей для запроса случайности и проверки колбэка. Публичных entry-функций нет.
- **Структуры/типы**: не объявлены; модуль служит обёрткой над нативным API Supra.
- **Сопоставление**: сигнатуры совпадают с шаблоном `Supra dVRF Template` и публичным пакетом [`Entropy-Foundation/vrf-interface@testnet`](https://github.com/Entropy-Foundation/vrf-interface/tree/testnet/supra/testnet), расхождений по API не обнаружено.

### `deposit.move`
- **Публичные entry-функции (native)**: `client_setting_minimum_balance`, `add_contract_to_whitelist`, `remove_contract_from_whitelist`, `deposit_fund`, `withdraw_fund`.
- **Сопоставление**: идентичны открытой реализации `Entropy-Foundation/vrf-interface@testnet`; новые camelCase-алиасы Supra CLI отражают те же native-функции.
- Дополнительные публичные функции отсутствуют.

## Дополнительно
- Во всех перечисленных модулях присутствуют вспомогательные структуры и функции (`public fun`), которые требуют отдельной сверки с эталонными контрактами Supra-Labs.
- Пакет `move-stdlib` больше не хранится локально: workspace подтягивает его из `Entropy-Foundation/aptos-core` (`aptos-move/framework/move-stdlib`, `rev = "dev"`).

