# Подготовка к этапам 3–5 для `lottery_multi`

## Контекст и цель
- Этапы 0–2 завершены, для этапов 3–5 требуется детализированный план подготовки.
- Документ служит чек-листом предварительных действий перед реализацией, чтобы не брать на себя весь этап целиком и минимизировать риски параллельной работы команд.
- Список обновляется по мере уточнения архитектуры; ответственным за актуальность является on-chain команда.

## Этап 3. Экономика и выплаты — подготовительные подэтапы
1. **Анализ зависимостей и контрактов.**
   - Проверить публичные API `lottery_rewards::{Jackpot, Store, NftRewards}` и зафиксировать необходимые обёртки в `lottery_multi::reward_bridge`.
   - Синхронизировать с `lottery_support` по структурам истории, чтобы заранее знать, какие события и архивные записи должны пополняться при выплатах.
2. **Проектирование агрегатов и событий.**
   - Подготовить схему полей `total_allocated`, `total_prize_paid`, `total_operations_paid`, описать типы и диапазоны значений.
   - Спроектировать payload для `PayoutBatchEvent`, `PartnerPayoutEvent`, `PurchaseRateLimitHitEvent` с учётом лимитов Supra на размер события (реализовано в `history.move`, `sales.move`, `payouts.move`).
3. **План тестов и ограничений.**
   - Составить таблицу тестовых сценариев для партнёрских лимитов, расчёта долей (70/15/10/5) и многослотных розыгрышей (первый блок покрыт юнит-тестом `lottery_multi::economics_tests`).
   - Определить требуемые фикстуры (моки VRF, преднастроенные партнёрские лоты) и описать их в `docs/qa`.
4. **Документация и согласование.**
   - Обновить раздел «Экономика» в «книге проекта», указать инварианты и список новых событий (обновлено в `docs/handbook/contracts/lottery_multi.md`).
   - Получить согласование у TreasuryCustodian и PartnerOperator по лимитам и форматам отчётности.

### Карта изменений по реализации подэтапа 3 (обновление 2025-11-13)
- `history::LotterySummary` расширен агрегатами `total_allocated`, `total_prize_paid`, `total_operations_paid`; добавлены события `PartnerPayoutEvent` и `PurchaseRateLimitHitEvent`.
- `economics::Accounting` контролирует лимиты через проверки в `record_prize_payout` и `record_operations_payout`, используя ошибки `E_PAYOUT_ALLOC_EXCEEDED` и `E_OPERATIONS_ALLOC_EXCEEDED`.
- `sales::record_payouts` синхронизирует выплаты с учётом продаж и переиспользует событие `PurchaseRateLimitHitEvent` из `history`.
- `payouts::record_payout_batch_admin` и `payouts::record_partner_payout_admin` публикуют новые события и обновляют агрегаты продаж.
- `roles::RoleStore` хранит `PayoutBatchCap`/`PartnerPayoutCap`/`PremiumAccessCap`, события `RoleGranted/RoleRevoked` фиксируют выдачу/отзыв, `list_partner_caps`/`list_premium_caps` и `cleanup_expired_admin` предоставляют актуальный список и автоматический клинап; функции `consume_payout_batch` и `consume_partner_payout` проверяют лимиты (размер батча, бюджет операций, cooldown, nonce, expiry) перед вызовом админских выплат.
 - Тестовая база дополнена юнитами `lottery_multi::economics_tests` и `lottery_multi::payouts_tests`, проверяющими распределение 70/15/10/5, обновление агрегатов `Accounting`, защиту лимитов операций/партнёров и обязательность `PartnerPayoutCap`.
- Руководство и тест-матрица обновлены: см. `docs/handbook/contracts/lottery_multi.md`, `docs/handbook/operations/runbooks.md`, `docs/handbook/qa/testing_matrix.md`.

## Этап 4. Миграция и backfill — подготовительные подэтапы
1. **Инвентаризация данных и схем.**
   - Составить перечень всех таблиц/ресурсов, затронутых миграцией (`lottery_support::History`, `LotteryHistoryArchive`, пользовательские индексы).
   - Подготовить черновик JSON Schema для новых view, сверив поля с требованиями фронтенда.
2. **Dual-write и инструменты.**
   - Описать целевой интерфейс `lottery_multi::legacy_bridge` и необходимые capabilities для dual-write.
   - Спроектировать CLI-команды (dry-run, сверка хэшей, переключение режима) и добавить TODO в репозиторий скриптов.
3. **Процедуры безопасности и отката.**
   - Задокументировать шаги остановки старой лотереи, проверку консистентности и условия возврата к старому контракту.
   - Определить контрольные метрики (время миграции, процент успешно перенесённых записей) и способы их сбора.
4. **Коммуникация и обучение.**
   - Подготовить инструкцию для саппорта и партнёров: как отразятся миграция и dual-write на их рабочих процессах.
   - Организовать сессии обзора с фронтендом и DevOps, задокументировать вопросы/ответы в `docs/handbook/operations/meeting_notes.md`.

### Карта изменений по реализации подэтапа 4 (обновление 2025-11-17)
- `legacy_bridge` расширен событиями `ArchiveDualWriteStartedEvent`/`ArchiveDualWriteCompletedEvent`, функцией `notify_summary_written` и view `dual_write_status`, обеспечивающими контроль dual-write и очистку ожидаемых хэшей.
- Добавлены ресурс-маркер `MirrorConfig`, функции `enable_legacy_mirror`/`disable_legacy_mirror` и хук `mirror_summary_to_legacy`, который пишет сводку в `lottery_support::history_bridge` при каждом `history::record_summary`.
- View `legacy_bridge::dual_write_flags` позволяет операторам запросить глобальные переключатели dual-write (enabled/abort_on_*), а CLI-команда `dual_write_control.sh flags` теперь использует эту view без необходимости указывать `lottery_id`.
- Реализованы функции `history::{import_legacy_summary_admin, rollback_legacy_summary_admin, update_legacy_classification_admin}`, события `LegacySummaryImported/RolledBack/ClassificationUpdated`, view `is_legacy_summary`, юнит-тесты `history_migration_tests` и CLI `history_backfill.sh`, фиксирующие подготовку к backfill и ручным сценариям отката.
- Новый модуль `lottery_support::history_bridge` хранит зеркальные сводки (`LegacySummary`), эмитирует `LegacySummaryEvent` и предоставляет view `get_summary` для dry-run сверок.
- Юнит `lottery_multi::history_dual_write_tests::dual_write_mirror_summary` подтверждает, что зеркальная запись создаёт хэш, совпадающий с ожидаемым, и что BCS-декод суммарного объекта соответствует исходной сводке.
- Скрипт `supra/scripts/dual_write_control.sh` дополнен командами `enable-mirror`, `disable-mirror`, `mirror` для управления зеркальной записью и ручного повторного прогона.
- Runbook операций обновлён: описаны команды скрипта, обработка событий `ArchiveDualWriteStarted/Completed`, проверка `dual_write_status` и зеркальных записей через Supra CLI.

## Этап 5. Операционный запуск — подготовительные подэтапы
1. **Роли и capabilities.**
   - Составить матрицу выдачи `LotteryAdminCap`, `PayoutBatchCap`, `ArchiveWriterCap`, определить владельцев и таймлоки.
   - Проверить необходимость новых событий аудита (`AdminActionLogged`, `RoleRevoked`) и согласовать их формат с аудиторами.
2. **Релизный процесс и контроль версий.**
   - Подготовить шаблон релизной записи (git-тег, версия Move-пакета, обновлённые разделы «книги проекта»).
   - Описать процедуру проверки `config_version` и сопоставления с фронтендом/индексаторами.
3. **Операционные runbook’и.**
   - Собрать черновики инструкций: ротация ключей AutomationBot, manual override выплат, обработка инцидентов VRF.
   - Зафиксировать требования к мониторингу: какие алерты должны быть включены к запуску.
4. **Обратная связь и баг-баунти.**
   - Определить критерии отбора баг-репортов, подготовить форму отчёта и FAQ для сообщества.
   - Назначить ответственных за обработку обращений и обновление статуса задач.

### Карта изменений по реализации подэтапа 5 (обновление 2025-11-26)
- Runbook’и дополнились разделом прайс-фида, мониторинг — метриками `price_feed_updates_total`, `price_feed_clamp_active`, `price_feed_fallback_active`, а релизный чек-лист — проверкой последнего `PriceFeedClampClearedEvent`.
- Модуль `price_feed` расширен функцией `clear_clamp`, событием `PriceFeedClampClearedEvent`, тестами `price_feed_tests`, Prover-спекой `spec/price_feed.move` и справочником [price_feeds.md](../handbook/architecture/price_feeds.md).

## Синтаксис и рекомендации Move (краткая памятка)
- Использовать Move 1.8/1.9 без нестабильных фич, соблюдать объявленные abilities (`key`, `store`, `drop`, `copy`).
- Для `entry`-функций явно указывать `acquires` и работать с глобальными ресурсами через `borrow_global[_mut]`.
- Мутации переменных выполняются через повторное присваивание без `let mut`; циклы — `while` + условные блоки (без `continue`).
- Ошибки оформлять через `assert!(условие, E_CODE)`, каталог кодов хранить в `lottery_multi::errors`.
- Поддерживать UTF-8 без BOM для исходников и документации; перед коммитом запускать Supra CLI (`supra/scripts/build_lottery_packages.sh lottery_multi --fmt --check`) в `supra/move_workspace`.
- Сохранять контракт с `supra_vrf`: payload, `rng_count`, подписи функций должны соответствовать спецификации Supra.

## Порядок обновления документа
1. Обновляйте список подэтапов при появлении новых зависимостей или требований от команд.
2. После завершения каждого подэтапа фиксируйте результат и ссылку на соответствующий PR/коммит.
3. Сверяйте документ с `docs/architecture/lottery_parallel_plan.md`, чтобы не возникало расхождений в терминологии и критериях.

