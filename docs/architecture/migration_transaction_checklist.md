# Чек-лист миграционных транзакций SupraLottery

Документ описывает последовательность действий для перевода on-chain состояния SupraLottery на новую архитектуру. Чек-лист актуален для тех же on-chain адресов, которые уже используются проектом (админский аккаунт деплоя и тестовые профили `player1`–`player5`).

## 1. Подготовка
1. Убедиться, что рабочее окружение настроено по правилам из раздела «Окружения и проверки» плана:
   - локально — `docker compose -f SupraLottery/compose.yaml run ...`;
   - в CI — `python3 -m supra.scripts.cli move-test ...`;
   - тестнет — отдельные профили supra-cli для администратора и игроков.
2. Собрать актуальный список структур и ресурсов из `docs/architecture/move_struct_inventory.md`.
3. Сверить и при необходимости обновить заполненную карту миграции `docs/architecture/move_migration_mapping.md` (при расширении — дополнять шаблон `move_migration_mapping_template.md`).
4. Подготовить конфигурацию supra-cli с указанием нужного RPC, gas-параметров и ключей.

## 2. Порядок транзакций

| Шаг | Действие | Кто выполняет | Проверки перед шагом | Результат |
| --- | --- | --- | --- | --- |
| 1 | Деплой обновлённых пакетов (`lottery_data`, `lottery_engine`, `lottery_gateway`, `lottery_utils`, `lottery_rewards_engine`, `lottery_vrf_gateway`) | Админский аккаунт | Все пакеты компилируются локально и в CI | Новые модули опубликованы на тестнете |
| 2 | Инициализация utility-слоя: публикация `lottery_utils::feature_flags` и `lottery_utils::price_feed`, перенос devnet-флагов и базовых курсов | Админский аккаунт | Подготовлены выгрузки текущих фич и котировок, заполнена карта миграции для `feature_switch` и `price_feed` | Ресурсы `FeatureRegistry` и `PriceFeedRegistry` инициализированы, devnet-override и актуальные цены перенесены |
| 3 | Подготовка миграционного слоя: `lottery_utils::migration::init_ledger`, `ensure_caps_initialized` и запись стартовых снапшотов | Админский аккаунт | Пакеты `lottery_data` и `lottery_utils` опубликованы, capability `InstancesExportCap` и `LegacyTreasuryCap` доступны в контроллерах | `MigrationLedger` создан, `MigrationSession` хранит capability, события `MigrationSnapshotUpdatedEvent` зафиксированы |
| 4 | Инициализация `lottery_data` (публикация `lottery_state`, `instances`, `rounds`, `operators`, `treasury_v1`, `treasury_multi`) | Админский аккаунт | Таблица соответствий заполнена, значения параметров подтверждены | Появились базовые ресурсы `lottery_data::LotteryState`, `InstanceRegistry`, `RoundRegistry`, `OperatorRegistry`, `TreasuryV1`, `TreasuryMulti` |
| 5 | Миграция данных `lottery_core` → `lottery_data` (`migrate_rounds`, `migrate_instances`, `migrate_treasury_v1`) | Админский аккаунт | Проверка `RoundCollection`, `LotteryCollection`, `Vaults` присутствуют и не пустые | Новые ресурсы содержат копии данных, старые помечены как архивные |
| 6 | Синхронизация владельцев и операторов через `lottery_engine::operators` (`set_owner`, `grant_operator`, `revoke_operator`) и проверка паузы/возврата (`lottery_engine::lifecycle`) | Админский аккаунт | Таблица соответствий (`move_migration_mapping.md`) заполнена для владельцев и операторов, подготовлены batched-скрипты | Новый `InstanceRegistry` содержит актуальных владельцев, `OperatorRegistry` синхронизирован, события смены владельца зафиксированы, `pause_lottery`/`resume_lottery` проходят без ошибок |
| 7 | Миграция данных `lottery_multi` → `lottery_engine`/`lottery_gateway` (`migrate_sales`, `migrate_history`, `migrate_draw_ledger`, `migrate_gateway_registry`) | Админский аккаунт | Выгружены снапшоты старых конфигураций, таблица соответствий обновлена, подготовлены CSV владельцев/лотерей | Продажи, история и VRF-раунды доступны через `lottery_engine`, `GatewayRegistry` содержит владельцев/статусы, события фасада зафиксированы |
| 8 | Миграция истории розыгрышей: инициализация `lottery_utils::history::init`, получение capability через `history::init_caps`, выполнение `sync_draws_from_rounds` и выборочная проверка `record_draw_from_rounds`/`clear_history` | Админский аккаунт | Очередь `lottery_data::rounds::PendingHistoryQueue` содержит pending-записи, карта миграции для `HistoryCollection` заполнена, подготовлены снапшоты legacy | Новый `HistoryCollection` и `HistoryWarden` опубликованы, события `DrawRecordedEvent`/`HistorySnapshotUpdatedEvent` фиксируются, история доступна через фасад |
| 9 | Миграция метаданных: перенос записей из `lottery_support::Metadata` в `lottery_utils::metadata`, публикация снапшотов `MetadataSnapshotUpdatedEvent` и проверка выдачи данных через фасад/view | Админский аккаунт | Карта соответствий обновлена, подготовлены выгрузки JSON/CSV с метаданными и скрипты фасада для проверки | `MetadataRegistry` заполнен актуальными записями, события `LotteryMetadataUpsertedEvent`/`MetadataSnapshotUpdatedEvent` зафиксированы, фронтенд получает корректные данные |
| 10 | Миграция `PayoutLedger`: перенос победителей и статусов выплат в `lottery_data::payouts`, проверка статусов через `lottery_engine::payouts::mark_payout_distributed`/`record_refund` и dry-run выдача джекпота `lottery_rewards_engine::payouts::pay_jackpot_winner` | Админский аккаунт | Старый `lottery_multi::payouts` выгружен, подготовлены CSV/JSON с победителями и суммами | Новый `PayoutLedger` содержит идентичные записи, события `WinnerRecorded`, `PayoutStatusUpdated` и `JackpotPaidEvent` зафиксированы |
| 11 | Перенос записей отмен: запустить скрипт `migrate_cancellations`, который вызывает `lottery_engine::cancellation::cancel_lottery` в режиме dry-run, сверяет суммы продаж/джекпота и публикует `LotteryCanceledEvent` | Админский аккаунт | Таблица соответствий обновлена, выгружены данные `lottery_multi::lottery_registry` (причины, суммы) | Новый `CancellationLedger` содержит записи с корректными суммами, события отмен зафиксированы, pending-запросы очищены |
| 12 | Миграция автоматизации: перенос `AutomationRegistry` и `AutomationCap` (dry-run, pending-статусы, cron) через `lottery_engine::automation` | Админский аккаунт | Выгружены списки ботов и pending-действий, проверена карта миграции, подготовлены cron-скрипты | Новый `AutomationRegistry` и capability опубликованы в `lottery_data::automation`, события dry-run/тикета фиксируются, pending-статусы восстановлены |
| 13 | Миграция автопокупок: перенос `AutopurchaseState` и capability в `lottery_rewards_engine::autopurchase`, dry-run `configure_plan`/`deposit`/`execute` с проверкой балансов, снапшотов и вызовов `lottery_engine::sales::record_prepaid_purchase` | Админский аккаунт | Выгружены планы из `lottery_rewards::rewards_autopurchase`, подготовлены CSV с балансами и tickets_per_draw, капы `AutopurchaseRoundCap`/`AutopurchaseTreasuryCap` доступны | Новый `AutopurchaseState` содержит актуальные планы, события депозитов/исполнений записаны, баланс трежери и раундов сходится, capability успешно перенесены |
| 14 | Миграция VIP-подписок: перенос `VipState` и capability `VipAccess` в `lottery_rewards_engine::vip`, dry-run `subscribe`/`cancel` через фасад с проверкой событий и пополнений мульти-трежери | Админский аккаунт | Выгружены активные подписки/expiry из `rewards_vip`, подготовлены CSV по выручке, `treasury_multi::vip_cap` доступен | Новый `VipState` содержит подписчиков и события, `VipAccess` опубликован, операции записываются через `record_operations_income_with_cap` |
| 15 | Миграция магазина призов: перенос `StoreState` и capability `StoreAccess` в `lottery_rewards_engine::store`, dry-run `upsert_item`/`purchase` с проверкой событий и мульти-трежери | Админский аккаунт | Выгружены товары и остатки из `rewards_store`, подготовлены CSV с конфигами, `treasury_multi::store_cap` доступен | Новый `StoreState` содержит каталог и остатки, `StoreAccess` опубликован, события `ItemConfigured`/`ItemPurchased` зафиксированы |
| 16 | Миграция наград (`lottery_rewards`) в новые структуры (`lottery_rewards_engine`, `lottery_data::treasury_multi`): конфигурация долей через `lottery_rewards_engine::treasury::configure_lottery_shares`, перенос балансов джекпота/операций | Админский аккаунт | Проверены балансы наград, выгружены доли BPS и реципиенты мульти-трежери | Балансы и доли перенесены, события `LotteryConfigUpdatedEvent`/`AllocationRecordedEvent` зафиксированы |
| 17 | Миграция VRF-джекпота: перенос билетов и состояния в `lottery_data::jackpot`, dry-run `lottery_rewards_engine::jackpot::{register_lottery, grant_ticket, request_randomness, fulfill_draw}` с записью событий и проверкой баланса `treasury_multi` | Админский аккаунт | Выгружены данные `lottery_rewards::rewards_jackpot`, подготовлены CSV билетов и pending-запросов, депозиты VRF в статусе `requests_paused = false` | Новый `JackpotRegistry` содержит актуальные записи, события `JackpotTicketGrantedEvent`/`JackpotFulfilledEvent` и `JackpotPaidEvent` зафиксированы, баланс мульти-трежери уменьшен корректно |
| 18 | Обновление VRF-контура: применить `lottery_engine::vrf_config` (gas-бюджеты, whitelists, client seed), затем обновить `lottery_engine::vrf` (снапшот депозита, паузы) и синхронизировать `lottery_vrf_gateway` / `SupraVrf` | Админский аккаунт + скрипт VRF | Обновлены значения в `lottery_data::lottery_state`, `lottery_data::vrf_deposit`, события `Vrf*Updated` и `VrfDeposit*` зафиксированы, баланс депозита достаточен | Новые параметры активны, dry-run цепочки `schedule → request → fulfill` через `lottery_engine::draw` проходит успешно, пауза депозита отключена |
| 19 | Активация новых entry-функций в `lottery_gateway` (включение feature-флагов, если есть) | Админский аккаунт | Проверены результаты шагов 4–18, CI-интеграционные тесты зелёные | Пользовательские вызовы идут через новый фасад |
| 20 | Архивирование старых модулей: публикация завершающего апдейта с явным `abort` во входных точках или удаление ролей | Админский аккаунт | Все клиенты переключены на новый хаб | Старые entry-функции больше не вызываются |

## 3. Пост-миграционные проверки
1. Запустить интеграционный сценарий «создание лотереи → участие → VRF → выдача наград» на тестнете с игроками `player1`–`player5`, используя новые entry-функции `lottery_engine::draw`.
2. Проверить инварианты по таблице соответствий (балансы, статусы, счётчики билетов) — результаты сохранить в артефакт `migration_validation.json`.
3. Сверить события блокчейна:
   - `LotteryCreated`, `RoundEntered`, `RandomnessRequestedEvent`, `RandomnessFulfilled`, `WinnerChosen`, `RewardClaimed`;
   - убедиться, что значения идентификаторов и сумм совпадают с ожиданиями.
4. Проверить статус VRF-депозита через `lottery_engine::vrf::status()` и события `VrfDeposit*`: флаг `requests_paused` должен быть `false`, `required_minimum` и `effective_floor` согласованы с конфигурацией.
5. Зафиксировать отчёт в `docs/architecture/move_migration_mapping_template.md` (колонка «Статус» → `Готово`) и приложить ссылки на логи CI.

## 4. Откат
1. Если на любом шаге проверка провалилась, выполнить реверс:
   - деактивировать новые entry-функции `lottery_gateway` (откатываем feature-флаги);
   - восстановить старые роли/ресурсы при помощи подготовленных снапшотов.
2. При невозможности отката (данные уже перезаписаны) — подготовить новый патч-модуль с функцией `rollback_*`, которая переносит данные обратно на основе резервных копий.
3. Все шаги отката документируются в отдельном отчёте CI (артефакт `migration_rollback.log`).

## 5. Журнал изменений

| Дата (UTC) | Изменение | Автор |
| --- | --- | --- |
| 2025-11-15 | Создан чек-лист миграционных транзакций и проверок. | Supra refactoring bot |
| 2025-11-18 | Дополнен чек-лист шагами миграции VRF и dry-run цепочки `lottery_engine::draw`. | Supra refactoring bot |
| 2025-11-19 | Добавлены действия по `lottery_engine::vrf_config` и фиксации событий VRF-конфигурации. | Supra refactoring bot |
| 2025-11-21 | Расширен шаг VRF миграции `lottery_engine::vrf`, добавлены проверки статуса депозита и событий `VrfDeposit*`. | Supra refactoring bot |
| 2025-11-22 | Добавлен шаг синхронизации владельцев и операторов через `lottery_engine::operators` с обязательными проверками событий. | Supra refactoring bot |
| 2025-11-23 | Обновлён шаг 4: добавлена проверка `lottery_engine::lifecycle::pause_lottery`/`resume_lottery` и соответствующих событий. | Supra refactoring bot |
| 2025-11-24 | Добавлен шаг миграции выплат (`lottery_data::payouts`, `lottery_engine::payouts`) и требования к валидации событий `WinnerRecorded`/`PayoutStatusUpdated`. | Supra refactoring bot |
| 2025-11-25 | Дополнен чек-лист переносом записей отмен (`lottery_data::cancellations`, `lottery_engine::cancellation`) и проверками очистки pending-запросов. | Supra refactoring bot |
| 2025-11-26 | Зафиксировано обновление модулей на рекурсивные хелперы без циклов, чтобы шаги миграции `SalesLedger`, `DrawLedger` и `PayoutLedger` соответствовали ограничениям Move v1 и успешно проходили проверки. | Supra refactoring bot |
| 2025-11-27 | Добавлен шаг переноса автоматизации (`lottery_data::automation`, `lottery_engine::automation`) с требованиями к восстановлению pending-действий и cron-расписаний. | Supra refactoring bot |
| 2025-11-28 | Обновлён шаг 5: добавлен перенос `lottery_multi::lottery_registry` в `lottery_gateway::GatewayRegistry` и проверки событий фасада. | Supra refactoring bot |
| 2025-11-29 | Обновлён шаг 9: добавлена конфигурация мульти-трежери через `lottery_rewards_engine::treasury` и требования к валидации событий `LotteryConfigUpdatedEvent`/`AllocationRecordedEvent`. | Supra refactoring bot |
| 2025-11-30 | Добавлен шаг миграции VRF-джекпота (`lottery_data::jackpot`, `lottery_rewards_engine::jackpot`) с dry-run запросов и проверкой `JackpotPaidEvent`. | Supra refactoring bot |
| 2025-12-02 | Дополнен чек-лист шагом миграции автопокупок (`lottery_rewards_engine::autopurchase`) и проверками переноса capability `AutopurchaseRoundCap`/`AutopurchaseTreasuryCap`. | Supra refactoring bot |
| 2025-12-03 | Добавлен шаг миграции VIP-подписок (`lottery_rewards_engine::vip`) с dry-run `subscribe`/`cancel` и валидацией событий мульти-трежери. | Supra refactoring bot |
| 2025-12-04 | Добавлен шаг миграции магазина призов (`lottery_rewards_engine::store`) и проверки событий `ItemConfigured`/`ItemPurchased`. | Supra refactoring bot |
| 2025-12-05 | Зафиксирован шаг миграции истории (`lottery_utils::history`) с требованиями к `sync_draws_from_rounds` и dry-run очистке очереди; обновлены номера последующих шагов. | Supra refactoring bot |
| 2025-12-06 | Добавлен шаг миграции метаданных (`lottery_utils::metadata`), расширены проверки фасада и обновлены номера шагов. | Supra refactoring bot |
| 2025-12-07 | Добавлен шаг подготовки миграционного слоя (`lottery_utils::migration`), обновлены номера шагов и проверки capability. | Supra refactoring bot |
