# План декомпозиции контракта SupraLottery

## Цель

Перестроить монолитный пакета `lottery` на набор независимых Move‑пакетов, чтобы:

1. Уложиться в лимиты размера публикации (≤ 60 KB).
2. Упростить дальнейшее развитие (новые модули/фичи подключаются независимо).
3. Сохранить возможность быстро восстановиться на монолитной версии (`backup/lottery_monolith`).

## Исходная точка

- Бэкап текущего состояния: ветка `backup/lottery_monolith`.
- Основная работа ведётся в ветке `main` (или рабочей ветке, указанной командой).
- Набор пакетов до изменений:
  - `SupraVrf`, `vrf_hub`, `lottery_factory`, `lottery`.
- Ограничение: публикация `lottery` ~83 KB даже без артефактов → сеть отклоняет транзакцию.

## Общая архитектура после разбиения

| Пакет              | Назначение                                                               | Пример содержимого                                     |
|--------------------|--------------------------------------------------------------------------|--------------------------------------------------------|
| `lottery_core`     | Минимальный функционал: покупка билетов, розыгрыш, казначейство          | `Lottery.move`, `LotteryRounds.move`, `Treasury*.move` |
| `lottery_rewards`  | Дополнительные механики для игроков                                      | `Vip.move`, `Referrals.move`, `Autopurchase.move`, `NftRewards.move` |
| `lottery_support`  | Админские и вспомогательные функции                                      | `History.move`, `Metadata.move`, `Migration.move`      |
| `lottery_tests` (опционально) | Интеграционные сценарии и вспомогательные тестовые утилиты | Тесты, которые тянут весь стек                         |

Каждый пакет получает свой `Move.toml`, тесты, команды публикации в runbook.

## Шаги по реализации

### 1. Анализ зависимостей

**Статус:** ✅ Завершено (2025-10-20).

- Для каждого модуля зафиксировать:
  - `use` зависимости и friend‑отношения.
  - Какие ресурсы/функции предоставляются другим модулям.
- Результат оформить в таблицу (можно добавить в этот документ или `docs/architecture/modules.md`).

#### Таблица зависимостей модулей SupraLottery

| Модуль | Friend | Ключевые зависимости | Ресурсы (has key) | Основные события | Ключевые публичные функции |
|---|---|---|---|---|---|
| `lottery::autopurchase` | — | lottery::instances<br>lottery::rounds<br>lottery::treasury_v1<br>lottery_factory::registry<br>std<br>supra_framework<br>vrf_hub | AutopurchaseState | AutopurchaseDepositEvent<br>AutopurchaseConfigUpdatedEvent<br>AutopurchaseExecutedEvent<br>AutopurchaseRefundedEvent<br>AutopurchaseSnapshotUpdatedEvent | configure_plan<br>deposit<br>execute<br>get_autopurchase_snapshot<br>get_lottery_snapshot<br>get_lottery_summary |
| `lottery::history` | lottery::rounds | std<br>supra_framework<br>vrf_hub | HistoryCollection | DrawRecordedEvent<br>HistorySnapshotUpdatedEvent | clear_history<br>get_history<br>get_history_snapshot<br>get_lottery_snapshot<br>has_history<br>init |
| `lottery::instances` | lottery::migration<br>lottery::rounds | lottery_factory::registry<br>std<br>supra_framework<br>vrf_hub | LotteryCollection | LotteryInstanceCreatedEvent<br>LotteryInstanceBlueprintSyncedEvent<br>AdminUpdatedEvent<br>HubAddressUpdatedEvent<br>LotteryInstanceStatusUpdatedEvent<br>LotteryInstancesSnapshotUpdatedEvent | contains_instance<br>create_instance<br>get_instance_snapshot<br>get_instance_stats<br>get_instances_snapshot<br>get_lottery_info |
| `lottery::jackpot` | — | lottery::treasury_multi<br>lottery::treasury_v1<br>std<br>supra_framework<br>vrf_hub | JackpotState | JackpotTicketGrantedEvent<br>JackpotScheduleUpdatedEvent<br>JackpotRequestIssuedEvent<br>JackpotFulfilledEvent<br>JackpotSnapshotUpdatedEvent | fulfill_draw<br>get_snapshot<br>grant_ticket<br>grant_tickets_batch<br>init<br>is_initialized |
| `lottery::main_v2` | lottery::migration | lottery::treasury_v1<br>std<br>supra_addr<br>supra_framework | LotteryData | TicketBought<br>WinnerSelected<br>SubscriptionConfiguredEvent<br>SubscriptionContractRemovedEvent<br>MinimumBalanceUpdatedEvent<br>ClientWhitelistRecordedEvent<br>ConsumerWhitelistSnapshotRecordedEvent<br>VrfRequestConfigUpdatedEvent<br>GasConfigUpdatedEvent<br>AggregatorWhitelistedEvent<br>AggregatorRevokedEvent<br>ConsumerWhitelistedEvent<br>ConsumerRemovedEvent<br>WhitelistSnapshotUpdatedEvent<br>DrawRequestedEvent<br>DrawHandledEvent<br>FundsWithdrawnEvent | buy_ticket<br>client_whitelist_snapshot_view<br>configure_vrf_gas<br>configure_vrf_request<br>consumer_whitelist_snapshot_view<br>create_subscription |
| `lottery::metadata` | — | std<br>supra_framework<br>vrf_hub | MetadataRegistry | LotteryMetadataUpsertedEvent<br>LotteryMetadataRemovedEvent<br>MetadataAdminUpdatedEvent<br>MetadataSnapshotUpdatedEvent | get_metadata<br>get_metadata_snapshot<br>has_metadata<br>init<br>is_initialized<br>list_lottery_ids |
| `lottery::migration` | — | lottery::instances<br>lottery::main_v2<br>lottery::rounds<br>lottery::treasury_multi<br>lottery_factory::registry<br>std<br>supra_framework<br>vrf_hub | MigrationLedger | MigrationSnapshotUpdatedEvent | get_migration_snapshot<br>list_migrated_lottery_ids<br>migrate_from_legacy |
| `lottery_rewards::nft_rewards` (ранее `lottery::nft_rewards`) | — | std<br>supra_framework<br>vrf_hub | BadgeAuthority | BadgeMintedEvent<br>BadgeBurnedEvent<br>NftRewardsSnapshotUpdatedEvent | burn_badge<br>get_badge<br>get_owner_snapshot<br>get_snapshot<br>has_badge<br>init |
| `lottery::operators` | — | std<br>supra_framework<br>vrf_hub | LotteryOperators | AdminUpdatedEvent<br>OwnerUpdatedEvent<br>OperatorGrantedEvent<br>OperatorRevokedEvent<br>OperatorSnapshotUpdatedEvent | can_manage<br>ensure_authorized<br>get_operator_snapshot<br>get_owner<br>grant_operator<br>init |
| `lottery::referrals` | lottery::rounds | lottery::treasury_multi<br>std<br>supra_framework<br>vrf_hub | ReferralState | ReferralSnapshotUpdatedEvent<br>ReferralConfigUpdatedEvent<br>ReferralRegisteredEvent<br>ReferralClearedEvent<br>ReferralRewardPaidEvent | admin_clear_referrer<br>admin_set_referrer<br>get_lottery_config<br>get_lottery_stats<br>get_referral_snapshot<br>get_referrer |
| `lottery::rounds` | lottery::autopurchase<br>lottery::migration | lottery::history<br>lottery::instances<br>lottery::referrals<br>lottery::treasury_multi<br>lottery::treasury_v1<br>lottery::vip<br>lottery_factory::registry<br>std<br>supra_framework<br>vrf_hub | RoundCollection | TicketPurchasedEvent<br>DrawScheduleUpdatedEvent<br>RoundResetEvent<br>DrawRequestIssuedEvent<br>DrawFulfilledEvent<br>RoundSnapshotUpdatedEvent | buy_ticket<br>fulfill_draw<br>get_round_snapshot<br>init<br>is_initialized<br>pending_request_id |
| `lottery::store` | — | lottery::instances<br>lottery::treasury_multi<br>lottery::treasury_v1<br>std<br>supra_framework<br>vrf_hub | StoreState | AdminUpdatedEvent<br>ItemConfiguredEvent<br>ItemPurchasedEvent<br>StoreSnapshotUpdatedEvent | get_item<br>get_item_with_stats<br>get_lottery_snapshot<br>get_lottery_summary<br>get_store_snapshot<br>init |
| `lottery::treasury_multi` | lottery::jackpot<br>lottery::migration<br>lottery::referrals<br>lottery::rounds<br>lottery::store<br>lottery::vip | lottery::treasury_v1<br>std<br>supra_framework<br>vrf_hub | TreasuryState | LotteryConfigUpdatedEvent<br>AllocationRecordedEvent<br>AdminUpdatedEvent<br>RecipientsUpdatedEvent<br>PrizePaidEvent<br>OperationsWithdrawnEvent<br>OperationsIncomeRecordedEvent<br>OperationsBonusPaidEvent<br>JackpotPaidEvent | distribute_jackpot<br>distribute_prize<br>get_config<br>get_lottery_summary<br>get_pool<br>get_recipient_statuses |
| `lottery::treasury_v1` | lottery::autopurchase<br>lottery::main_v2<br>lottery::treasury_multi | std<br>supra_framework | Vaults<br>TokenState | ConfigUpdatedEvent<br>RecipientsUpdatedEvent<br>JackpotDistributedEvent | account_extended_status<br>account_status<br>balance_of<br>burn_from<br>deposit_from_user<br>get_config |
| `lottery::vip` | lottery::rounds | lottery::instances<br>lottery::treasury_multi<br>lottery::treasury_v1<br>std<br>supra_framework<br>vrf_hub | VipState | VipConfigUpdatedEvent<br>VipSubscribedEvent<br>VipCancelledEvent<br>VipBonusIssuedEvent<br>VipSnapshotUpdatedEvent | cancel<br>cancel_for<br>get_lottery_snapshot<br>get_lottery_summary<br>get_subscription<br>get_vip_snapshot |

### 2. Определение границ пакетов

**Статус:** ✅ Завершено (2025-10-21).

#### Черновое распределение модулей

- **Ядро (`lottery_core`)** — обеспечивает минимальную работу розыгрыша и управление фондами:
  - `Lottery.move`, `LotteryRounds.move`, `LotteryInstances.move`.
  - `Treasury.move`, `TreasuryMulti.move`, `Operators.move`.
- **Расширения (`lottery_rewards`)** — дополнительные механики для игроков и операторов:
  - `Autopurchase.move`, `Jackpot.move`, `Referrals.move`, `Store.move`, `Vip.move`, `NftRewards.move`.
- **Поддержка (`lottery_support`)** — инфраструктурные и миграционные компоненты:
  - `History.move`, `Metadata.move`, `Migration.move`.

#### Критичные пересечения `friend`

- `History` ↔ `LotteryRounds` — потребуется capability для записи результатов в историю.
- `Lottery`/`LotteryInstances` ↔ `Migration` — capability для экспорта состояния и записи миграции.
- `LotteryRounds` ↔ `Autopurchase` — нужно вынести pre-paid закупку билетов на capability.
- `Treasury` ↔ `Autopurchase` — capability на пополнение/списание депозитов автопокупок.
- `TreasuryMulti` ↔ `Jackpot`/`Referrals`/`Store`/`Vip` — единый capability на доступ к мульти-казначейству.
- `TreasuryMulti` ↔ `LotteryRounds` — оставить внутри ядра (совместное размещение).

#### Проверка на циклы

- `lottery_core` ← `lottery_support`: требуется capability вместо friend для миграции.
- `lottery_core` ← `lottery_rewards`: все зависимости идут от расширений к ядру; критичные friend следует заменить на capability.
- После замены friend (см. шаг 3) ожидается направленный граф: `support` и `rewards` зависят от `core`, но не наоборот.

#### Матрица модулей → пакеты

| Модуль | Пакет | Статус подготовки | Комментарий |
|---|---|---|---|
| `lottery::main_v2` | `lottery_core` | 🟢 Подтверждено | Базовая логика розыгрыша; остаётся в ядре, требуются capability для выдачи привилегий миграции. |
| `lottery::rounds` | `lottery_core` | 🟡 Требует доработки | Нужен capability для записи истории и доступа к автопокупкам (см. шаг 3). |
| `lottery::instances` | `lottery_core` | 🟢 Подтверждено | Остаётся в ядре; friend только с `migration`, который переедет в support. |
| `lottery::treasury_v1` | `lottery_core` | 🟡 Требует доработки | Нужно ограничить доступ расширений к депозитам через capability. |
| `lottery::treasury_multi` | `lottery_core` | 🟡 Требует доработки | Понадобится capability для `jackpot`/`referrals`/`store`/`vip`. |
| `lottery::operators` | `lottery_core` | 🟢 Подтверждено | Используется ядром и поддержкой; дополнительных ограничений не выявлено. |
| `lottery::history` | `lottery_support` | 🟡 Требует доработки | Переезд возможен после capability от `rounds` для записи результатов. |
| `lottery::migration` | `lottery_support` | 🟡 Требует доработки | Нужен контролируемый экспорт состояния `instances`/`main_v2`. |
| `lottery::metadata` | `lottery_support` | 🟢 Подтверждено | Нет friend; остаётся инфраструктурным модулем. |
| `lottery::autopurchase` | `lottery_rewards` | 🟡 Требует доработки | Доступ к казначейству и раундам переводим на capability. |
| `lottery::jackpot` | `lottery_rewards` | 🟡 Требует доработки | Зависит от `treasury_multi`; после capability ограничений не останется. |
| `lottery::referrals` | `lottery_rewards` | 🟡 Требует доработки | Требуется capability к `treasury_multi` и доступ к `rounds`. |
| `lottery::store` | `lottery_rewards` | 🟡 Требует доработки | Потребуется capability к `treasury_multi`; проверить события для тестов. |
| `lottery::vip` | `lottery_rewards` | 🟡 Требует доработки | Аналогично `referrals`, подтверждаем границы после capability. |
| `lottery_rewards::nft_rewards` | `lottery_rewards` | 🟢 Перенесено | Использует только публичный API, код уже живёт в пакете наград. |

#### Итоги шага 2

- [x] Зафиксировать черновое распределение модулей по пакетам.
- [x] Оценить потребность в capability для каждого модуля.
- [x] Описать правила экспорта/инициализации ресурсов ядра, которые потребуются `support` и `rewards`.
- [x] Подготовить драфт структуры каталогов (`supra/move_workspace/<package>`) и `Move.toml` с зависимостями.
- [x] Согласовать порядок миграции модулей, чтобы минимизировать разрыв между публикациями.
- [x] Подтвердить отсутствие циклических зависимостей после переезда модулей.
- [x] Зафиксировать критерии готовности для публикации каждого пакета.

##### Правила экспорта и инициализации ресурсов ядра

- Инициализацию `lottery_core` проводим единоразово, создавая cap‑ресурсы внутри `lottery::main_v2`, `lottery::rounds`, `lottery::treasury_v1` и `lottery::treasury_multi`. Каждая capability хранится в приватном ресурсе `CoreControl`.
- Экспорт состояний в `lottery_support` допускается только через view-функции:
  - `instances::get_instances_snapshot` → используется `migration`/`history`.
  - `rounds::get_round_snapshot` и `rounds::get_lottery_summary` → используются `history` и `autopurchase`.
  - `treasury_multi::get_pool`/`get_config` → используются `jackpot`, `referrals`, `store`, `vip`.
- Для операций записи внедряем защищённые методы, возвращающие capability:
  - `rounds::borrow_history_cap()` → выдаёт capability для `history` (ограничение по адресу модуля).
  - `treasury_multi::borrow_distribution_cap()` → выдаёт capability для `jackpot`/`referrals`/`store`/`vip`.
  - `treasury_v1::borrow_legacy_cap()` → остаётся доступным только `migration`.
- Расширения и поддержка должны выполнять ленивую инициализацию: при первом обращении запрашивают capability и кешируют локально под `key`‑ресурсом, чтобы избежать лишних зависимостей на момент публикации.

##### Драфт структуры каталогов и `Move.toml`

```
supra/
└─ move_workspace/
   ├─ lottery_core/
   │  ├─ Move.toml
   │  └─ sources/
   │     ├─ Lottery.move
   │     ├─ LotteryRounds.move
   │     ├─ Treasury.move
   │     └─ …
   ├─ lottery_support/
   │  ├─ Move.toml
   │  └─ sources/
   │     ├─ History.move
   │     ├─ Metadata.move
   │     └─ Migration.move
   └─ lottery_rewards/
      ├─ Move.toml
      └─ sources/
         ├─ Autopurchase.move
         ├─ Jackpot.move
         ├─ Referrals.move
         └─ …
```

Шаблон `Move.toml` для `lottery_support`/`lottery_rewards`:

```toml
[package]
name = "lottery_support"
version = "0.1.0"

[addresses]
lottery = "_"
supra_framework = "_"
vrf_hub = "_"

[dependencies]
MoveStdlib = { git = "https://github.com/move-language/move", subdir = "language/move-stdlib", rev = "<pin>" }
SupraFramework = { local = "../../SupraLottery/supra_framework" }
lottery_core = { local = "../lottery_core" }
```

Для `lottery_core` зависимость от `lottery_core` в блоке `[dependencies]` опускается, а список адресов дублирует существующий `lottery/Move.toml`.

##### Последовательность миграции модулей

1. **Публикация `lottery_core`**: переносим `Lottery`, `LotteryRounds`, `Treasury*`, `Operators`. Проверяем, что cap‑инициализация происходит в `init` и что публичные view функции покрывают сценарии поддержки.
2. **Публикация `lottery_support`**: переносим `Metadata`, затем `History`, затем `Migration`. Для `History` перед публикацией убеждаемся, что capability из ядра доступен через guarded API.
3. **Публикация `lottery_rewards`**: начинаем с `NftRewards` (нет зависимостей), затем `Vip`/`Referrals`/`Store`, после чего `Autopurchase` и `Jackpot`, где требуется финальная проверка capability к казначейству.
4. После каждой публикации обновляем runbook и фиксируем контрольный тег, чтобы при сбое можно откатиться на предыдущий пакет.

### 3. Замена `friend` на capability (где необходимо)

**Статус:** ✅ Завершено (2025-10-22).

#### Соответствие `friend` → capability

| Пара модулей | Тип capability | Хранение | Guarded API | Дальнейшие действия |
|---|---|---|---|---|
| `lottery::rounds` → `lottery::history` | `struct HistoryWriterCap has store { target: address }` | Внутри `rounds::CoreControl` под `key` ресурсом | `public(friend) fun borrow_history_writer(addr: &signer): HistoryWriterCap` → проверка адреса пакета истории | Обновить `history` на использование capability и удалить friend. |
| `lottery::rounds` → `lottery::autopurchase` | `struct AutopurchaseRoundCap has store {}` | Внутри `rounds::CoreControl` | `public fun borrow_autopurchase_cap(): AutopurchaseRoundCap` (возвращает `copy` только зарегистрированному модулю через адрес) | Переписать вызовы записи автопокупок на передачу cap. |
| `lottery::treasury_v1` → `lottery::autopurchase` | `struct AutopurchaseTreasuryCap has store {}` | Внутри `treasury_v1::CoreControl` | `public fun borrow_autopurchase_cap(): AutopurchaseTreasuryCap` с проверкой адреса | Заменить direct вызовы `friend` у `autopurchase`. |
| `lottery::treasury_v1` → `lottery::migration` | `struct LegacyTreasuryCap has store {}` | `treasury_v1::CoreControl` | `public(friend) fun borrow_legacy_cap(addr: address): LegacyTreasuryCap` | Использовать в миграции, снять friend. |
| `lottery::treasury_multi` → `lottery::jackpot`/`referrals`/`store`/`vip` | `struct MultiTreasuryCap has store { scope: u64 }` | Внутри `treasury_multi::CoreControl`, scope соответствует типу расширения | `public fun borrow_multi_treasury_cap(scope: u64): MultiTreasuryCap` | Обновить каждое расширение, убрать friend. |
| `lottery::instances` → `lottery::migration` | `struct InstancesExportCap has store {}` | `instances::CoreControl` | `public(friend) fun borrow_instances_export_cap(addr: address): InstancesExportCap` | Миграция использует capability вместо friend. |

Примечания:

- Для capability, выдаваемых нескольким пакетам (`treasury_multi`), сохраняем аудит области (`scope`), чтобы расширения не могли выполнять чужие операции.
- Все capability отмечаем как `drop` запрещённый (не объявляем ability `drop`), чтобы модуль обязан был возвращать ресурс.
- Guarded API предоставляется через `public(friend)` для пакетов, которые разворачиваются вместе с ядром, либо `public entry` с проверкой адреса вызывающего модуля (через `@0x...`), если пакет вынесен отдельно.

#### Структура хранения capability в ядре

```move
module lottery::core_control {
    use std::option;

    struct CoreControl has key { 
        history_cap: option::Option<HistoryWriterCap>,
        autopurchase_caps: option::Option<AutopurchaseRoundCap>,
        treasury_caps: option::Option<MultiTreasuryCap>,
        legacy_cap: option::Option<LegacyTreasuryCap>,
    }
}
```

- Инициализация происходит в `init` целевого модуля (`rounds`, `treasury_v1`, `treasury_multi`).
- Доступ к ресурсу `CoreControl` закрыт внутри модуля через приватные функции `borrow_control()`/`borrow_control_mut()`.
- Capability выдаётся один раз на пакет и регистрируется как выданный (флаг в `CoreControl`), чтобы исключить дублирование.

#### Обновлённые сигнатуры и точки входа расширений

| Модуль | Функции/методы | Изменение | Хранение capability |
|---|---|---|---|
| `autopurchase` | `configure_plan`, `deposit`, `execute`, `refund_expired`, `on_draw_fulfilled` | Добавлен параметр `AutopurchaseRoundCap` (для работы с `rounds`) и/или `AutopurchaseTreasuryCap` (для операций с казначейством). | Новый ресурс `AutopurchaseAccess has key { rounds: AutopurchaseRoundCap, treasury: AutopurchaseTreasuryCap }` c lazy‑инициализацией при первой настройке. |
| `jackpot` | `grant_ticket`, `grant_tickets_batch`, `fulfill_draw`, `configure_schedule` | Требуют `MultiTreasuryCap` c `scope = SCOPE_JACKPOT`. | `JackpotControl has key { cap: option::Option<MultiTreasuryCap> }`. |
| `referrals` | `admin_set_referrer`, `admin_clear_referrer`, `record_reward`, `on_round_closed` | Используют `MultiTreasuryCap` (`scope = SCOPE_REFERRALS`) и доступ к `rounds` только через view‑функции. | `ReferralsControl has key { treasury_cap: MultiTreasuryCap }`. |
| `store` | `configure_item`, `purchase_item`, `grant_bonus`, `withdraw_income` | Берут `MultiTreasuryCap` (`scope = SCOPE_STORE`). | `StoreControl has key { treasury_cap: MultiTreasuryCap }`. |
| `vip` | `subscribe`, `subscribe_for`, `cancel`, `issue_bonus` | Принимают `MultiTreasuryCap` (`scope = SCOPE_VIP`) и запрашивают snapshots через публичные функции `rounds`. | `VipControl has key { treasury_cap: MultiTreasuryCap }`. |
| `history` | `record_draw`, `clear_history`, `rebuild_from_snapshot` | Переведены на `HistoryWriterCap`, выдаваемый ядром, вместо friend‑методов. | `HistoryWarden has key { writer: HistoryWriterCap }`. |
| `migration` | `migrate_from_legacy`, `sync_blueprint`, `force_reset` | Требуют `InstancesExportCap` и `LegacyTreasuryCap`, которые передаются отдельными параметрами и хранятся до завершения миграции. | `MigrationSession has key { instances: InstancesExportCap, treasury: LegacyTreasuryCap }` c проверкой, что cap освобождён в `drop`. |

Ключевые правила:

- Новые параметры capability добавляются в сигнатуры как `&mut` ссылки на структуры или значения ресурсов, чтобы Move запретил копирование.
- Все публичные API, используемые внешними клиентами (например, просмотр истории), сохраняют прежние сигнатуры; изменения касаются только внутренних entry‑точек между пакетами.
- Для ленивой инициализации каждый модуль имеет `ensure_capabilities_initialized(s: &signer)` с проверкой кэша и вызовом guarded API ядра.

#### Требования к миграции state и обращению с capability

- `migration` обязан освобождать `InstancesExportCap` и `LegacyTreasuryCap` после завершения операции (`drop` реализован вручную через внутреннюю функцию `return_capabilities`).
- При обновлении/переинициализации пакета расширения необходимо вызвать `release_capabilities()` — entry‑функцию, которая возвращает cap обратно в ядро, прежде чем модуль будет удалён или переопубликован.
- Все capability хранятся под `key`‑ресурсами, чтобы они автоматически очищались при удалении аккаунта разработчика.
- Контроль за повторной выдачей: ядро ведёт счётчик версий в `CoreControl`, и при повторной публикации расширения оно должно запросить capability заново и обновить локальный кэш.
- Для сценариев отката документируется порядок: сначала отзывает capability (через `release_capabilities`), затем выполняется публикация старой версии.

#### Сценарии тестирования выдачи и отзыва capability (шаг 7)

1. **Получение и кэширование**: тест `test_autopurchase_acquire_caps` проверяет, что при первом вызове `configure_plan` модуль получает оба capability и сохраняет их в `AutopurchaseAccess`.
2. **Ограничение областей**: `test_multi_treasury_scope_isolated` убеждается, что `jackpot` с `scope = SCOPE_JACKPOT` не может использовать cap для операций `referrals`.
3. **Отзыв**: `test_release_capabilities_returns_to_core` моделирует переиздание пакета: вызывает `release_capabilities`, затем повторную инициализацию и проверяет, что ядро выдаёт cap заново.
4. **Миграция**: `test_migration_session_lifecycle` создаёт сессию миграции, выполняет перенос и проверяет, что после завершения capability не остаются в аккаунте.

#### Чеклист по шагу 3

- [x] Составить таблицу соответствия `friend` → capability и зафиксировать guarded API.
- [x] Определить структуру хранения capability в ядре и правила выдачи.
- [x] Описать обновлённые сигнатуры функций в расширениях (`autopurchase`, `jackpot`, `referrals`, `store`, `vip`).
- [x] Задокументировать требования к миграции state (в том числе освобождение capability при удалении пакета).
- [x] Добавить сценарии тестирования выдачи/отзыва capability в шаг 7.

#### Итоги шага 3

- Все проблемные `friend`-связки переведены в модель capability; для каждого взаимодействия определены guard-функции и правила хранения.
- Расширения задокументированы с новыми сигнатурами entry-функций и lazy-инициализацией capability.
- Миграционные сценарии и тестовые кейсы фиксируют возврат прав и предотвращают утечки ресурсов.
- Готовы к началу шага 4: зависимости между пакетами теперь контролируются через API, а не через прямой friend-доступ.

### 4. Создание новых пакетов

**Статус:** 🚧 В работе (обновлено 2025-10-24).

#### Общий прогресс

| Направление | Действия | Статус | Комментарии |
|---|---|---|---|
| Каталоги рабочего пространства | Подтверждена корневая структура `supra/move_workspace/<package>` | ✅ Выполнено | Совпадает с драфтом шага 2; требуются рефы в runbook. |
| Шаблоны `Move.toml` | Уточнены адреса и зависимости для всех пакетов | ✅ Выполнено | Повторно использован шаблон из шага 2, добавлены версии и policy тестов. |
| Каркас исходников | Определён список файлов и целевых путей для переноса | ✅ Выполнено | Заглушки модулей созданы во всех трёх пакетах; `lottery_support` уже содержит полноценные `metadata` и `history`. |
| Workspace members | Добавлены новые пакеты в `SupraLottery/supra/move_workspace/Move.toml` | ✅ Выполнено | `lottery_core`, `lottery_support`, `lottery_rewards` участвуют в общем `workspace` и готовы к сборке. |
| Сборочные скрипты | Черновые команды публикации и тестов | 🟢 Готово | Добавлен утилитный скрипт `supra/scripts/build_lottery_packages.sh` для запуска `sandbox build` по пакетам. |
| Автоматизация каркасов | Скрипт генерации директорий и заглушек | 🟢 Готово | `supra/scripts/setup_lottery_packages.sh` разворачивает структуру пакетов и синхронизирует членов `workspace`. |
| Синхронизация адресов | Монолитные адреса автоматически подтягиваются в новые `Move.toml` | 🟢 Готово | `setup_lottery_packages.sh` переписывает секцию `[addresses]` по данным из `lottery/Move.toml`, исключая расхождения при повторных запусках. |
| Проверочные сборки | Локальная компиляция каждого пакета | 🟡 Заблокировано | Ожидает доступа к `supra move tool`; скрипт сборки готов. |

#### Контрольный список шага 4

- [x] Зафиксировать структуру директорий для `lottery_core`, `lottery_support`, `lottery_rewards`.
- [x] Подготовить единый шаблон `Move.toml` (с адресами и зависимостями) и уточнить различия для ядра.
- [x] Создать каталоги и пустые `Move.toml` с заголовками пакетов.
- [x] Добавить заглушки `sources/*.move` для ключевых модулей (по списку ниже).
- [x] Настроить базовые команды сборки/тестов (см. `supra/scripts/build_lottery_packages.sh`).
- [x] Подключить новые пакеты к корневому `workspace` (`SupraLottery/supra/move_workspace/Move.toml`).
- [ ] Прогнать первичную сборку каждого пакета и зафиксировать результаты.
- [ ] Обновить документацию runbook после успешной сборки.

#### Карта переноса модулей по пакетам

| Пакет | Исходные файлы (монолит) | Новый путь | Особенности переноса | Подготовительный статус |
|---|---|---|---|---|
| `lottery_core` | `lottery/sources/Lottery.move`, `LotteryRounds.move`, `LotteryInstances.move`, `Treasury.move`, `TreasuryMulti.move`, `Operators.move` | `supra/move_workspace/lottery_core/sources/<Module>.move` | Требуется сохранить порядок инициализации и `CoreControl` ресурсы. | 🟡 Перенос в процессе: `operators` и `instances` уже перенесены, остальные заглушки ждут наполнения |
| `lottery_support` | `lottery/sources/History.move`, `Metadata.move`, `Migration.move` | `supra/move_workspace/lottery_support/sources/<Module>.move` | Должны ссылаться на capability API из ядра. | 🟢 Заглушки и `ensure_caps_initialized` оформлены |
| `lottery_rewards` | `lottery/sources/Autopurchase.move`, `Jackpot.move`, `Referrals.move`, `Store.move`, `Vip.move`, `NftRewards.move` | `supra/move_workspace/lottery_rewards/sources/<Module>.move` | Требуется настройка scope для `MultiTreasuryCap` и ленивый кэш. | 🟢 Заглушки со `SCOPE_*` и контролем созданы |

#### Чеклисты по пакетам

**`lottery_core`**

- [x] Зафиксировать состав модулей (`Lottery`, `LotteryRounds`, `LotteryInstances`, `Treasury`, `TreasuryMulti`, `Operators`).
- [x] Согласовать требуемые ресурсы (`CoreControl`, `CapabilityRegistry`).
- [x] Создать директорию `supra/move_workspace/lottery_core` и базовый `Move.toml` с адресами `lottery`, `supra_framework`, `vrf_hub`.
- [x] Подготовить заглушки `sources/*.move` с декларациями модулей и комментариями TODO.
- [ ] Добавить минимальные smoke-тесты (если потребуется для `supra move tool test`).
- [ ] Проверить сборку `supra move tool sandbox build --package-dir supra/move_workspace/lottery_core`.

**`lottery_support`**

- [x] Составить список модулей (`History`, `Metadata`, `Migration`) и требуемых capability.
- [x] Создать директорию `supra/move_workspace/lottery_support` и `Move.toml` с зависимостью на `../lottery_core`.
- [x] Добавить заглушки модулей с функциями `ensure_caps_initialized` и `TODO` комментариями к guarded API.
- [ ] Обновить тестовый план: smoke-проверки миграции и истории (описано в шаге 7).
- [ ] Выполнить первичную сборку пакета.

**`lottery_rewards`**

- [x] Подготовить карту соответствия `scope` → модуль (`jackpot`, `referrals`, `store`, `vip`, `autopurchase`, `nft_rewards`).
- [x] Создать директорию `supra/move_workspace/lottery_rewards` и `Move.toml` с зависимостью на `../lottery_core`.
- [x] Сформировать заглушки модулей с константами `SCOPE_*` и структурами контроля (`*_Control`).
- [x] Перенести модуль `nft_rewards` в пакет `lottery_rewards`, сохранив события, view и тестовый набор.
- [ ] Зафиксировать тесты на изоляцию scope в плане (см. шаг 7).
- [ ] Проверить, что сборка проходит на заглушках.

##### Состояние каркасов (2025-10-24)

- **lottery_core** — созданы каталоги и `Move.toml`, добавлены заглушки модулей `main_v2`, `rounds`, `treasury_v1`, `treasury_multi`; модули `operators` и `instances` перенесены из монолита и содержат рабочие реализации.
- **lottery_support** — модули `metadata`, `history` и `migration` перенесены из монолита; `history::record_draw` требует `HistoryWriterCap`, `migration` временно использует friend-функции ядра до появления capability.
- **lottery_rewards** — модуль `nft_rewards` перенесён с полной логикой и тестами; остальные модули пока остаются заглушками с константами `SCOPE_*` и `ensure_caps_initialized` до внедрения capability.
- **workspace** — корневой `Move.toml` расширен пакетами `lottery_core`/`lottery_support`/`lottery_rewards`, поэтому `supra move tool` обнаружит их без ручного редактирования.
- Для совместимости путей добавлены симлинки `supra/move_workspace/lottery_*` → `SupraLottery/supra/move_workspace/lottery_*`, чтобы команды из runbook могли работать без изменения текущих инструкций.
- Добавлен автоматизированный запуск сборки через `supra/scripts/build_lottery_packages.sh`, который использует локальный `supra` либо контейнер `supra_cli`.
- Для повторного развёртывания каркасов добавлен скрипт `supra/scripts/setup_lottery_packages.sh`, создающий `Move.toml`, заглушки модулей и симлинки.

#### Первичная сборка и журнал прогресса

| Пакет | Команда | Статус | Комментарий |
|---|---|---|---|
| `lottery_core` | `supra move tool sandbox build --package-dir supra/move_workspace/lottery_core` | ⛔ Заблокировано | В контейнере отсутствует Supra CLI; запуск требует локального CLI или Docker Compose. |
| `lottery_support` | `supra move tool sandbox build --package-dir supra/move_workspace/lottery_support` | ⛔ Заблокировано | Аналогично, ожидает доступный `supra` или `docker compose run supra_cli`. |
| `lottery_rewards` | `supra move tool sandbox build --package-dir supra/move_workspace/lottery_rewards` | ⛔ Заблокировано | Стартуем после подготовки окружения; скрипт `build_lottery_packages.sh` готов к запуску. |

Порядок действий для команды при появлении CLI Supra:

1. Выполнить `bash supra/scripts/setup_lottery_packages.sh`, чтобы убедиться, что `Move.toml` и адреса синхронизированы с монолитом (`lottery_core`, `lottery_support`, `lottery_rewards` получат актуальные алиасы `lottery_*`).
2. Запустить `bash supra/scripts/build_lottery_packages.sh` или указать конкретный пакет в аргументах. Скрипт автоматически выберет установленный CLI либо `docker compose run supra_cli`.
3. Зафиксировать в таблице выше результат каждой сборки (успех/ошибка, размер байткода) и обновить чеклист шага 4.
4. После успешной сборки подготовить блокнот с измерениями размера (`move package info --bytecode-size`) для сравнения с лимитом 60 KB и приложить к runbook.

#### План подготовки к шагу 5 (перенос модулей)

| Модуль монолита | Новый пакет/модуль | Действия при переносе | Готовность | Блокеры |
|---|---|---|---|---|
| `lottery::main_v2` | `lottery_core::main_v2` | Перенести код, внедрить выдачу capability через `CoreControl`, обновить entry-функции на lazy-инициализацию. | ⏳ Планируется | Требуется финализация API `CoreControl`. |
| `lottery::rounds` | `lottery_core::rounds` | Выделить выдачу `HistoryWriterCap` и `AutopurchaseRoundCap`, адаптировать `ensure_caps_initialized` для расширений. | ⏳ Планируется | Ждём подтверждения модели capability из шага 3. |
| `lottery::instances` | `lottery_core::instances` | Адаптировать экспорт для `migration`, удалить friend, подключить `InstancesExportCap`. | 🟡 В работе | Код перенесён в `lottery_core`, предстоит внедрить capability и обновить `migration`. |
| `lottery::treasury_v1` | `lottery_core::treasury_v1` | Перенести выдачу `AutopurchaseTreasuryCap`/`LegacyTreasuryCap`, провести аудит событий. | ⏳ Планируется | Проверка совместимости с legacy-подписками. |
| `lottery::treasury_multi` | `lottery_core::treasury_multi` | Реализовать распределение по scope, синхронизировать с `SCOPE_*` из `lottery_rewards`. | ⏳ Планируется | Требуются подтверждённые значения scope. |
| `lottery::operators` | `lottery_core::operators` | Перенести админские операции, удостовериться, что ресурс операторов остаётся в ядре. | 🟢 Перенесено | Требуется прогнать smoke-тесты пакета после миграции ядра. |
| `lottery::metadata` | `lottery_support::metadata` | Перенести view API без friend, убедиться в корректности адресов. | 🟢 Перенесено | Ожидает подтверждения сборкой (Supra CLI пока недоступен). |
| `lottery::history` | `lottery_support::history` | Перенести записи розыгрышей, перевести `record_draw` на `HistoryWriterCap`. | 🟢 Перенесено | Требуется связать выдачу capability из `lottery_core::rounds`. |
| `lottery::migration` | `lottery_support::migration` | Код перенесён, сценарии миграции готовы к проверке capability. | 🟢 Перенесено | Временно использует API монолита, требуется перевод на capability и smoke-тесты. |
| `lottery::nft_rewards` | `lottery_rewards::nft_rewards` | Код перенесён: сохранены mint/burn, view и события, тесты переехали в пакет наград. | 🟢 Перенесено | — |
| `lottery::vip` | `lottery_rewards::vip` | Интегрировать `MultiTreasuryCap (SCOPE_VIP)` и ленивую инициализацию. | ⏳ Планируется | Требуется готовый `treasury_multi`. |
| `lottery::referrals` | `lottery_rewards::referrals` | Настроить начисления через capability и обновить события. | ⏳ Планируется | Зависит от `treasury_multi` и `rounds`. |
| `lottery::store` | `lottery_rewards::store` | Синхронизировать `SCOPE_STORE`, убедиться в совместимости с cap treasury. | ⏳ Планируется | Требуется финальный API `treasury_multi`. |
| `lottery::autopurchase` | `lottery_rewards::autopurchase` | Одновременно использовать cap раундов и казначейства, адаптировать `on_draw_fulfilled`. | ⏳ Планируется | Зависит от `rounds` и `treasury_v1`. |
| `lottery::jackpot` | `lottery_rewards::jackpot` | Настроить `SCOPE_JACKPOT`, пересмотреть выдачу наград. | ⏳ Планируется | Требуется `treasury_multi` и тест scope. |

#### Промежуточные результаты

- ✅ Перенесён модуль `lottery::metadata` в пакет `lottery_support` без изменений логики: сохранены события, snapshot API и публичные view-функции.
- ✅ Перенесён модуль `lottery::history` в `lottery_support::history`, `record_draw` требует `HistoryWriterCap` вместо friend-доступа.
- ✅ Перенесён модуль `lottery::migration` в `lottery_support::migration`; код повторяет функциональность монолита и ожидает перевода на capability после переноса ядра.
- ✅ Перенесён модуль `lottery::operators` в `lottery_core::operators` вместе с тестами `operators_tests`, которые теперь живут внутри пакета ядра и используют локальные `test_utils`.
- ✅ Перенесён модуль `lottery::instances` в `lottery_core::instances` вместе с тестами `instances_tests`; все зависимые модули и тесты переключены на использование нового пакета.
- ✅ Перенесён модуль `lottery::nft_rewards` в `lottery_rewards::nft_rewards`; сохранены события, snapshot/view API и переносимые тесты пакета.

Подготовительные задачи перед стартом шага 5:

- [ ] Зафиксировать финальные сигнатуры capability API (`borrow_*_cap`) в `lottery_core` и задокументировать их в `docs/architecture/modules.md`.
- [ ] Подготовить шаблоны smoke-тестов для каждого пакета (см. сценарии шага 7) и определить минимальный набор проверок после переноса.
- [ ] Назначить ответственных за перенос конкретных модулей и синхронизировать сроки с графиком публикаций.
- [ ] После успешной сборки каркасов обновить таблицу готовности (колонка «Готовность») и отметить старт реализации.
- [ ] Обновить runbook чеклист шага 5 с учётом итоговых команд публикации для каждого пакета.

#### План создания каркаса

1. **lottery_core**
   - Сгенерировать `Move.toml` с зависимостями `MoveStdlib` и `SupraFramework`.
   - Создать пустые файлы модулей и перенести заголовки документации (комментарии, `use` заглушки).
   - Подготовить заглушки тестов (`tests/`), если нужны для smoke-проверок.
2. **lottery_support**
   - Добавить зависимость на локальный `lottery_core`.
   - Описать placeholder-функции для получения capability из ядра, чтобы сборка проходила до фактического переноса логики.
3. **lottery_rewards**
   - Аналогично `support`, но с перечислением всех `scope` констант для `MultiTreasuryCap`.
4. После генерации каркасов запустить `supra move tool sandbox build`/`test` для каждого пакета и зафиксировать размеры bytecode.

##### Автоматизация подготовки

- Скрипт `supra/scripts/setup_lottery_packages.sh` создаёт директории пакетов, `Move.toml`, заглушки модулей, симлинки в `supra/move_workspace`, при необходимости дописывает пакеты в `[workspace].members` и синхронизирует секцию `[addresses]` с монолитным `lottery/Move.toml`.
- Запускать скрипт можно многократно: существующие файлы не перезаписываются.

```bash
bash supra/scripts/setup_lottery_packages.sh
```

- После переноса реализаций обновить скрипт, если появятся новые модули или зависимые пакеты.

#### Следующие шаги

- [x] Подготовить скрипт `supra/scripts/setup_lottery_packages.sh`, создающий каталоги и шаблонные файлы автоматически.
- [x] Согласовать с командой адреса аккаунтов для публикации (чтобы заполнить `addresses` в `Move.toml`). Скрипт синхронизирует значения с монолитным `lottery/Move.toml`, поэтому при изменении production-адресов нужно только подтвердить новые данные.
- [ ] После прохождения первичной сборки — перейти к переносу фактического кода модулей и обновлению runbook (шаг 5).

##### Черновик команд для сборки и тестов

Предпочтительно запускать сборку через скрипт-обёртку:

```
# собрать все пакеты сразу (использует локальный supra или docker compose)
bash supra/scripts/build_lottery_packages.sh

# собрать конкретный пакет
bash supra/scripts/build_lottery_packages.sh lottery_core
```

Ручные команды остаются на случай отладки:

```
supra move tool sandbox build --package-dir supra/move_workspace/lottery_core
supra move tool sandbox build --package-dir supra/move_workspace/lottery_support
supra move tool sandbox build --package-dir supra/move_workspace/lottery_rewards

# smoke-тесты (запускаются после наполнения тестами)
supra move tool test --package-dir supra/move_workspace/lottery_core
supra move tool test --package-dir supra/move_workspace/lottery_support
supra move tool test --package-dir supra/move_workspace/lottery_rewards
```

Для каждого пакета:

1. Создать директорию (`supra/move_workspace/lottery_core` и т. д.).
2. Сформировать `Move.toml`:
   - `name`, `version`.
   - `addresses` (скрипт подтягивает их из текущего `lottery/Move.toml`; при ручной настройке сверяйтесь с актуальными значениями).
   - `dependencies` (указать `MoveStdlib`, `SupraFramework`, и `local = "../lottery_core"` для пакетов над ядром).
3. Переместить соответствующие `.move` файлы и тесты.
4. Обновить `use` пути (например, `use lottery::treasury_v1` → `use lottery_core::treasury_v1`).
5. Запустить `supra move tool test --package-dir <dir>` для каждого пакета; убедиться, что сборка проходит.

### 5. Обновление runbook и документации

**Статус:** ⏳ Не начато.

- В `docs/testnet_runbook.md` добавить команды публикации для каждого нового пакета, например:
  ```powershell
  docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
    -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core --included-artifacts none --skip-fetch-latest-git-deps --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
  ```
- В `README.md`/`docs/architecture/modules.md` описать структуру пакетов и связи между ними.

### 6. Пошаговая публикация

**Статус:** ⏳ Не начато.

1. Развернуть `lottery_core` (после успешных тестов).
2. Развернуть `lottery_support` и/или `lottery_rewards` (последовательно, с обновлением runbook).
3. Обновить сценарии инициализации (whitelisting, migrate) для новых пакетов, если требуется.

### 7. Проверка и чеклист

**Статус:** ⏳ Не начато.

- Прогнать интеграционные тесты (`supra/scripts/move_tests.py`, smoke‑скрипты).
- Убедиться, что runbook покрывает:
  - публикацию пакетов,
  - инициализацию ресурсов,
  - whitelisting и работу VRF.
- Зафиксировать версию и сделать релизную ветку (например, `release/core-split`).

### 8. План восстановления

**Статус:** ⏳ Не начато.

- Для возврата к монолиту:
  - Переключиться на ветку `backup/lottery_monolith` или cherry-pick нужные файлы.
  - Использовать `SupraLottery/supra/move_workspace/lottery_backup` как источник кодовой базы.
- Поддерживать документ в актуальном состоянии (строки runbook, описания capability).

## Рекомендации по управлению ветками

- Все изменения выполняются в основной ветке (по решению команды), а `backup/lottery_monolith` хранится как страховка.
- Каждую группу изменений (capability, перенос модуля, новый пакет) оформлять отдельным коммитом с понятным сообщением.
- После успешной публикации и проверки пакетов оставить тег (например, `v0.2.0-core-split`) для точной точки возврата.

## Контрольные вопросы перед завершением

1. Все ли friend‑отношения заменены или помещены в один пакет?
2. Проходят ли unit-тесты для каждого пакета?
3. Обновлены ли runbook и README?
4. Восстановление в случае отката: есть ли рабочая ветка/тег?
5. Поддерживаются ли capability‑ресурсы безопасно (не `copy`, не `drop`, не «утекают» пользователям)?

Если на все пункты ответ «да», можно переходить к полноценному деплою новой структуры.
