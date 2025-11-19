# Контекст-резюме реструктуризации Supra Lottery

## Основные цели и требования
- Перенос легаси-пакетов (`lottery_core`, `lottery_multi`, `lottery_rewards`, `lottery_support`, `vrf_hub`, `lottery_factory`) в целевую архитектуру ядра (`lottery_data`, `lottery_engine`, `lottery_rewards_engine`, `lottery_utils`, `lottery_gateway`, `lottery_vrf_gateway`) в соответствии с подробным [планом реструктуризации](./supra_restructuring_detailed_plan.md).
- Строгое соблюдение правил Move v1: только ASCII, без `let mut`, контроль размера модулей, явные ошибки и чёткое разделение ролей между слоями (см. раздел «Жёсткие правила Move» в [плане](./supra_restructuring_detailed_plan.md)).

## Карта миграции и инструменты контроля
- Таблица соответствий и статусы ресурсов ведутся в [карте миграции](./move_migration_mapping.md); последняя фиксация — 0 ресурсов «готово», 51 «в работе», 0 «запланировано», 1 «не требуется».
- Для проверки карты используются утилиты `export_move_inventory.py` (генерирует Markdown и JSON-инвентарь) и `check_migration_mapping.py` (сверяет таблицу со сводкой и инвентарём), описанные в разделе «Быстрые проверки» [карты миграции](./move_migration_mapping.md#быстрые-проверки).

## Выполненные работы
1. Создан пакет `lottery_vrf_gateway` с модулем `hub`, импортными entry-функциями и view для точечных снапшотов; все легаси-пакеты и фабрика переведены на новый VRF-хаб.
2. Добавлены агрегированные health-view (`lottery_gateway::health`) и многочисленные readiness/snapshot view в `lottery_data`, `lottery_rewards_engine`, `lottery_utils`, покрывающие automation, cancellations, payouts, jackpot, history, rounds, gateway и операторы.
3. Для каждого из указанных модулей добавлены Move-тесты, журнал изменений и инструкции в [карте миграции](./move_migration_mapping.md#журнал-изменений) с датами 2026‑02‑16 — 2026‑02‑23.

## Следующие шаги
- Выбрать ресурс из раздела «Следующие шаги» [карты миграции](./move_migration_mapping.md#следующие-шаги) (например, `SalesLedger`, `PayoutLedger`, VRF-депозит, HistoryCollection, automation/auto-purchase/store/VIP) и свериться с описанными dry-run проверками и зависимостями перед началом разработки.
- При переходе в новый чат передать ссылку на настоящее резюме и убедиться, что исполнитель ориентируется в [главном плане](./supra_restructuring_detailed_plan.md) и актуальном статусе [карты миграции](./move_migration_mapping.md).
