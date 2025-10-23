# Архитектура пакетов SupraLottery

## Пакеты и ответственность

| Пакет | Основные модули | Ключевые обязанности |
|-------|-----------------|----------------------|
| `lottery_core` | `Lottery.move`, `LotteryRounds.move`, `LotteryInstances.move`, `Treasury.move`, `TreasuryMulti.move`, `Operators.move` | Управление раундами и билетами, хранение базового состояния, выдача capability для поддержки и пакета наград. |
| `lottery_support` | `History.move`, `Metadata.move`, `Migration.move` | Администрирование, миграция состояния и синхронизация истории с использованием capability ядра. |
| `lottery_rewards` | `Autopurchase.move`, `Jackpot.move`, `Referrals.move`, `Store.move`, `Vip.move`, `RoundsSync.move`, `NftRewards.move` | Дополнительные сервисы для игроков (автопокупка, VIP, рефералы, магазин, джекпот) с ленивым кэшированием capability. |

## Capability API ядра

### `lottery_core::rounds`
- Выдаёт и возвращает capability истории через `borrow_history_writer_cap`/`return_history_writer_cap` и аналогичный API для автопокупок (`borrow_autopurchase_round_cap`/`return_autopurchase_round_cap`). Оба набора поддерживают *try*-варианты и view-флаги доступности, что позволяет внешним пакетам безопасно кэшировать capability.【F:SupraLottery/supra/move_workspace/lottery_core/sources/LotteryRounds.move†L602-L700】
- Поддерживает очереди розыгрышей и покупок (`history_queue_length`, `drain_history_queue`, `drain_purchase_queue_admin`), а также админские операции `grant_bonus_tickets_admin` для последующей обработки в `support`/`rewards`. Сами записи ставятся в очередь через `enqueue_history_record`.【F:SupraLottery/supra/move_workspace/lottery_core/sources/LotteryRounds.move†L532-L600】【F:SupraLottery/supra/move_workspace/lottery_core/sources/LotteryRounds.move†L1031-L1056】

### `lottery_core::treasury_v1`
- Предоставляет capability автопокупок и миграции (`borrow_autopurchase_treasury_cap`, `borrow_legacy_treasury_cap`) вместе с функциями возврата и view-проверками (`autopurchase_cap_available`, `legacy_cap_available`).【F:SupraLottery/supra/move_workspace/lottery_core/sources/Treasury.move†L841-L947】
- Выплаты, выполняемые расширениями, ограничены методами `payout_with_autopurchase_cap` и `payout_with_legacy_cap`, принимающими соответствующие capability и перенаправляющими транзакцию в общее казначейство.【F:SupraLottery/supra/move_workspace/lottery_core/sources/Treasury.move†L949-L965】

### `lottery_core::treasury_multi`
- Реализует выдачу `MultiTreasuryCap` по scope и проверяет, что каждый из четырёх слотов (`jackpot`, `referrals`, `store`, `vip`) не занят повторно. Возврат capability и проверка соответствия scope выполняются в `return_multi_treasury_cap` и `ensure_scope`.【F:SupraLottery/supra/move_workspace/lottery_core/sources/TreasuryMulti.move†L620-L711】

### `lottery_core::instances`
- Экспортирует capability `InstancesExportCap` для миграции через `borrow_instances_export_cap`/`return_instances_export_cap` и защищает операции модификации статистики (`migrate_override_stats`) требованием предъявить capability.【F:SupraLottery/supra/move_workspace/lottery_core/sources/LotteryInstances.move†L400-L437】

## Использование capability в пакете поддержки

- `history::HistoryWarden` лениво кэширует `HistoryWriterCap`; модуль предоставляет `ensure_caps_initialized`, `caps_ready` и `release_caps`, а синхронизация очереди розыгрышей выполнена функцией `sync_draws_from_rounds`, которая выгружает записи ядра и переписывает их в события истории.【F:SupraLottery/supra/move_workspace/lottery_support/sources/History.move†L71-L109】【F:SupraLottery/supra/move_workspace/lottery_support/sources/History.move†L240-L275】
- `migration::MigrationSession` удерживает `InstancesExportCap` и `LegacyTreasuryCap`, обеспечивая атомарное получение и возврат через `ensure_caps_initialized`/`release_caps`, а также проверку готовности `caps_ready`. Основная операция `migrate_from_legacy` использует эти capability и API ядра для переноса состояния.【F:SupraLottery/supra/move_workspace/lottery_support/sources/Migration.move†L48-L119】

## Использование capability в пакете наград

- `autopurchase::AutopurchaseAccess` сохраняет пары `AutopurchaseRoundCap`/`AutopurchaseTreasuryCap`, выдаваемые ядром через `ensure_caps_initialized`; ресурс возвращается функцией `release_caps`, что гарантирует однократность владения.【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/Autopurchase.move†L425-L463】
- `jackpot::JackpotAccess`, `referrals::ReferralsControl`, `store::StoreAccess` и `vip::VipAccess` используют `treasury_multi::borrow_multi_treasury_cap` для своих scope и реализуют симметричные операции возврата и проверки готовности (`caps_ready`).【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/Jackpot.move†L300-L343】【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/Referrals.move†L320-L355】【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/Store.move†L360-L407】【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/Vip.move†L428-L448】
- `rounds_sync::sync_purchases_from_rounds` загружает очередь покупок из ядра, начисляет VIP-бонусы и передаёт суммы в реферальный модуль, выступая мостом между очередями ядра и capability пакета наград.【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/RoundsSync.move†L1-L41】

## Автоматизация синхронизации

Скрипт `supra/scripts/sync_lottery_queues.sh` запускает `history::sync_draws_from_rounds` и `rounds_sync::sync_purchases_from_rounds` через Supra CLI (локально, Docker Compose или Podman) и принимает пределы обработки очередей в параметрах командной строки.【F:supra/scripts/sync_lottery_queues.sh†L1-L155】

## Smoke-тесты и покрытие

- `lottery_support` содержит smoke-наборы `history_sync_tests` и `migration_tests`, которые проверяют работу очереди истории и жизненный цикл capability миграции (см. раздел 7 плана для сценариев).
- `lottery_rewards` включает тесты `rounds_sync_tests`, `autopurchase_tests`, `jackpot_tests`, `referrals_tests`, `store_tests`, `vip_tests`, подтверждающие выдачу/возврат capability и обработку очередей; тестовые утилиты разворачивают окружение и гарантируют готовность ресурсов.

> Актуальные команды запуска тестов задокументированы в `docs/testnet_runbook.md` и `supra/scripts/build_lottery_packages.sh`.
