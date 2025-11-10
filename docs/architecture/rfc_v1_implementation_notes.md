# RFC v1 Implementation Notes

> ⚠️ Шаблон заполняется на русском языке. Комментарии внутри таблиц следует очищать по мере перехода к рабочей эксплуатации.

## 1. Сводка статуса по этапам

| Этап | Диапазон задач (см. [план параллельных лотерей](./lottery_parallel_plan.md)) | Статус \(Not Started / In Progress / Done\) | Основные комментарии | Дата обновления |
|------|--------------------------------------------------------------------------------|----------------------------------------------|----------------------|-----------------|
| 0    | Подготовка архитектуры, согласование RFC, публикация книги проекта             | Done               | Архитектура согласована, книга проекта опубликована | 2025-11-09 |
| 1    | Фундаментальные артефакты: схемы ресурсов, событий, view и документации        | Done               | Сформированы ключевые модули (`registry`, `sales`, `draw`, `payouts`, `automation`, `price_feed`), добавлены view `get_lottery`/`list_active`/`list_by_*`, обновлены unit-тесты жизненного цикла и документация | 2025-11-10 |
| 2    | Миграции, capabilities, тестовая инфраструктура и мониторинг VRF-депозита      | Done               | Завершены `winner_tests`, dual-write контроль и проверки VRF-депозита; подготовлены миграционные инструменты и Prover-спеки | 2025-11-12 |
| 3    | Реализация ядра lottery_multi, партнёрских ограничений и премиальных фич       | In Progress                    | Реализованы агрегаты и события выплат (`total_*`, `PayoutBatch`, `PartnerPayout`, `PurchaseRateLimitHit`), добавлены `roles::RoleStore`, капабилити `PayoutBatchCap`/`PartnerPayoutCap`; интеграционные тесты `payouts_tests::{payout_handles_multi_slot_plan, partner_payout_cannot_exceed_cap}` и `sales_tests::{block_rate_limit_triggers, window_rate_limit_triggers, grace_window_blocks_first_purchase}` закрывают многослотные призы, остаток партнёрского бюджета и анти-DoS проверки; схема view дополнена примером `json/examples/lottery_multi_view_samples.json` и Python-валидатором | 2025-11-24 |
| 4    | Расширение пользовательских сервисов, локализация, поддержка партнёров         | In Progress           | Добавлены админ-функции `history::{import_legacy_summary_admin, rollback_legacy_summary_admin, update_legacy_classification_admin}`, события `LegacySummaryImported/RolledBack/ClassificationUpdated`, view `is_legacy_summary`, тесты `history_migration_tests` и CLI-утилита `supra/scripts/history_backfill.sh` (`import`, `rollback`, `classify`, `status`, `list`) | 2025-11-25 |
| 5    | Наблюдаемость, автоматизация, прайс-фиды, очистка хранилища                    | In Progress        | Расширен runbook AutomationBot (dry-run, таймлоки, контроль `failure_count`), подготовлены `operations/release_checklist.md`, `operations/monitoring.md`, `operations/incident_log.md`; модуль `price_feed` получил тесты `price_feed_tests`, Prover-спеку и справочник `price_feeds.md`; добавлены Move-тесты `automation_tests` для `ensure_action` и сброса лимитов | 2025-11-26 |
| 6    | Пострелизная стабилизация, баг-баунти, расширенные тесты и документация        | Not Started                                   |                      | _YYYY-MM-DD_ |
| 7    | Governance/API (перенесено на позднюю фазу)                                    | Not Started                                   |                      | _YYYY-MM-DD_ |

## 2. Прогресс по модулям Move

| Модуль | Ключевые обязанности | Текущее состояние | Ответственный | Последний апдейт |
|--------|----------------------|-------------------|---------------|------------------|
| `registry` | Жизненный цикл лотерей, статусы, идентификаторы | In Progress | Стартовая версия с тегами, событиями и блокировкой snapshot, тест `config_tests::cannot_update_tags_after_snapshot` фиксирует запрет изменения тегов после заморозки | 2025-11-18 |
| `sales` | Выпуск билетов, лимиты, анти-DoS | In Progress | Реализованы события `TicketPurchase`/`PurchaseRateLimitHit`, хранение чанков, выдача владельца билета через `ticket_owner`, учёт `SalesDistribution`, блоковые/оконные лимиты, grace-window; добавлен `record_payouts`, а модуль `sales_tests` подтверждает срабатывание ограничений (`block_rate_limit_triggers`, `window_rate_limit_triggers`, `grace_window_blocks_first_purchase`) и их ошибки | 2025-11-24 |
| `draw` | VRF-запросы, обработка retry, анти-bias | In Progress | Создан ledger запросов, события `VrfRequested/VrfFulfilled`, контроль retry/attempt и финализационный снимок; тесты `draw_tests` покрывают повторные запросы и окна retry, а Prover-спека `spec/draw.move` гарантирует монотонность `attempt`/`next_client_seed`, фиксацию `RETRY_STRATEGY_FIXED` и корректность `finalization_snapshot` | 2025-11-22 |
| `payouts` | Подсчёт победителей, батчи выплат, идемпотентность | In Progress | Ledger победителей, события `WinnersComputed`/`PayoutBatch`; функции выплат требуют капабилити, обновляют агрегаты, блокируются после `STATUS_FINALIZED`; тесты `payouts_tests` покрывают лимиты, финализацию, партнёрские выплаты и многослотные призовые планы (`payout_handles_multi_slot_plan`, `partner_payout_cannot_exceed_cap`); Prover-спека `spec/payouts.move` проверяет рост `payout_round` и отражение сумм в `sales::accounting_snapshot` | 2025-11-24 |
| `economics` | Резервы, распределение долей, джекпот | In Progress | Учёт распределения 70/15/10/5, контроль `total_operations_allocated`, проверки выплат и ошибки `E_PAYOUT_ALLOC_EXCEEDED`/`E_OPERATIONS_ALLOC_EXCEEDED`; Prover-спека `spec/economics.move` фиксирует суммы `apply_sale`, `record_*_payout` и ограничения `jackpot_allowance_token` | 2025-11-21 |
| `history` | Архивы, dual-write, снапшоты | In Progress | `ArchiveLedger`, dual-write контроль, импорт/откат наследуемых сводок; тесты `history_migration_tests` покрывают `import`/`rollback`/классификацию, добавлены события `LegacySummaryImported/RolledBack/ClassificationUpdated` и view `is_legacy_summary` | 2025-11-25 |
| `legacy_bridge` | Dual-write контроль, ожидание хэшей | In Progress | Ресурсы `DualWriteControl` и `MirrorConfig`, события `ArchiveDualWriteStarted/Completed`, функции `mirror_summary_to_legacy`/`notify_summary_written`; синхронизируется с импортом через `history_backfill.sh` (зеркалирование сводок при `import`/`classify`), view `dual_write_status`/`pending_expected_hashes`, CLI `dual_write_control.sh` | 2025-11-25 |
| `views` | Публичные API, фильтры, JSON-схемы | In Progress | Реализованы фильтры по типам и тегам, выдача бейджей, `get_lottery`, `list_active`, доступ к архивным summary и спискам финализированных ID; добавлены тесты `views_tests`, JSON Schema `docs/handbook/architecture/json/lottery_multi_views.schema.json`, пример `json/examples/lottery_multi_view_samples.json` и Python-валидатор `tests/test_view_schema_examples.py` | 2025-11-20 |
| `roles` | Capabilities, партнёры, премиальные подписки | In Progress | `RoleStore` теперь хранит `PayoutBatchCap`/`PartnerPayoutCap`/`PremiumAccessCap`, выдача и отзыв сопровождаются событиями и листингами `list_partner_caps`/`list_premium_caps`, добавлены `cleanup_expired_admin` и тесты `roles_tests::{partner_cap_blocks_after_expiry, admin_can_list_and_track_partner_caps, cleanup_expired_removes_caps, premium_grant_and_revoke_updates_events}` | 2025-11-24 |
| `tags` | Классификаторы, фильтрация, маски | In Progress | Валидация масок, ограничение по бюджету тегов, блокировка изменения тегов после `snapshot_frozen` через `registry` | 2025-11-18 |
| `price_feed` | Оракулы SUPRA/USD и прочие активы | In Progress | `PriceFeedRegistry` дополнился ручным снятием клампа (`clear_clamp`), событием `PriceFeedClampClearedEvent`, тестами `price_feed_tests` и Prover-спекой `spec/price_feed.move`; подготовлен справочник [price_feeds.md](../handbook/architecture/price_feeds.md) | 2025-11-26 |
| `feature_switch` | Управление доступом к функциям | In Progress | Добавлен реестр режимов и devnet override | 2025-11-08 |
| `automation` | AutomationBot, dry-run, репутация | In Progress | Реализован модуль `automation` с регистрацией ботов, событиями dry-run/tick/error; тесты `automation_tests` покрывают лимит `max_failures`, поведение `ensure_action` и сброс pending | 2025-11-18 |

## 3. Контроль ключевых инвариантов

| Инвариант | Инструменты проверки | Текущий статус | Комментарий |
|-----------|----------------------|----------------|-------------|
| `snapshot_hash` неизменен после `Closing` | Move Prover, unit-тесты | In Progress | Инварианты длины хэшей и заморозки добавлены в `spec/registry.move`; `spec/draw.move` фиксирует, что callback и пост-обработка не меняют снапшот, требуется общее доказательство по всем путям |
| `payout_round` строго возрастает | Move Prover | In Progress | `spec/payouts.move` проверяет рост `payout_round` и отслеживает, что партнёрские выплаты не изменяют раунд; остаётся формальное доказательство на уровне Prover |
| `allocated >= paid` во всех пулах | Move Prover, unit-тесты | In Progress | Инварианты и постусловия `spec/economics.move` фиксируют приращения `apply_sale`/`record_*_payout`; юнит-тест `lottery_multi::economics_tests` покрывает базовый сценарий, остаются интеграционные проверки |
| `jackpot_allowance_token` не увеличивается | Move Prover | In Progress | `spec/economics.move` ограничивает рост и фиксирует, что `consume_jackpot_allowance` только уменьшает токен; необходимо формальное доказательство |
| Детерминированный выбор победителей | Differential / property tests | In Progress | Юнит-тесты `winner_tests.move` сравнивают on-chain расчёт с эталонной реализацией |
| Dual-write архива остаётся консистентным | Unit-тесты, интеграционные тесты | In Progress | Юнит-тесты `history_dual_write_tests` и `history_migration_tests` закрывают зеркалирование, ручной сброс ожиданий, импорт/откат наследуемых сводок; CLI `history_backfill.sh` автоматизирует операции, остаётся интегрировать внешний backfill-драйвер |

## 4. Архив и миграции

- **Legacy backfill**: ответственный Backend (А. Петров). Черновой скрипт преобразования `lottery_support::History` → `ArchiveLedger` готов; on-chain импорт выполняется через `history::import_legacy_summary_admin` и CLI `supra/scripts/history_backfill.sh`. Dry-run devnet перенесён на 2025-11-26, целевой запуск prod — 2025-11-29.
- **Dual-write мониторинг**: метрика `archive_dual_hash_match`, события `ArchiveDualWriteStarted/Completed`, зеркальные `LegacySummaryEvent` и журнал `dual_write.log` обновляются cron-скриптом каждые 30 минут; статус, ожидания и зеркальные записи проверяются через view `legacy_bridge::{dual_write_status, pending_expected_hashes}`, `history_bridge::get_summary` и Supra CLI (`supra/scripts/dual_write_control.sh`, команды `status`, `flags`, `pending`, `mirror`). Последняя сверка хэшей (2025-11-11 09:30 UTC) — совпадение, расхождений не обнаружено.
- **Состояние миграции `LotteryHistoryArchive`**: активная схема `ArchiveSummaryV1`, подготовлена JSON Schema v1 и чек-лист сверки; остаётся задокументировать процедуру отката и покрыть сценарий «finalize + cancel» интеграционным тестом.

## 5. Фронтенд и API

| Компонент | Зависимости от on-chain | Статус | Комментарии |
|-----------|-------------------------|--------|-------------|
| Раздел «История» | `views::list_by_primary_type`, `get_lottery_status`, JSON Schema v1 | In Progress | Тесты `views_tests` подтверждают фильтры/пагинацию; подготовлена схема `lottery_multi_views.schema.json`, пример `lottery_multi_view_samples.json` и Python-валидатор схемы |
| Админ-конструктор | `views::validate_config`, таблица тегов, FeatureSwitch dev override | Not Started |  |
| Партнёрский мастер | Preset API, квоты песочницы, allowed tags/types | Not Started |  |
| API/индексатор | Dual-write архив, события v1 с `event_version` | In Progress | Схема ответов view добавлена, требуется связка с индексатором и миграциями | 

## 6. Операционные регламенты

- **VRF-депозит**: 2025-11-11 — runbook [operations/vrf_deposit.md](../handbook/operations/vrf_deposit.md) в рабочем режиме; Ops-инженер Н. Иванова отслеживает `effective_balance` и `required_minimum` через дашборд Grafana. Автономное возобновление запросов планируется через AutomationBot (ETA 2025-11-25); записи заносятся в [incident_log.md](../handbook/operations/incident_log.md).
- **AutomationBot**: последняя ротация ключей — 2025-11-08; счётчик успешных задач 24/24, предупреждений нет. Обновлённый runbook описывает dry-run, таймлоки, `ensure_action` и контроль `failure_count`; мониторинг метрик агрегирован в [monitoring.md](../handbook/operations/monitoring.md). Требуется связка с `vrf_deposit::record_snapshot_automation` и настройка таймлоков перед запуском на prod.
- **Рефанд-процедуры**: SLA 24 часа, контрольный прогон runbook завершён 2025-11-07; необходимо добавить интеграционный тест «force_cancel → refund» до этапа 3.
- **Прайс-фид**: `staleness_window` = 300 c, кламп фиксируется событиями `PriceFeedClampEvent`/`PriceFeedClampClearedEvent`, fallback переключается через `PriceFeedFallbackEvent`. Проверка 2025-11-26 подтвердила отсутствие активных клампов и fallback; runbook требует ручного подтверждения `clear_clamp` после расследования скачка.
- **Supra CLI**: 2025-11-09 — попытка запуска `build_lottery_packages.sh lottery_multi` завершилась ошибкой (бинарь отсутствует). Ответственный DevOps (К. Смирнов) устанавливает CLI и обновляет runbook до 2025-11-13.
- **Баг-баунти**: черновик [operations/bug_bounty.md](../handbook/operations/bug_bounty.md) опубликован, требуется финализация таблицы вознаграждений и согласование с отделом безопасности.

## 7. Журнал решений (RFC Notes)

| Дата | Решение | Область (модуль/процесс) | Следующие действия |
|------|---------|--------------------------|--------------------|
| 2025-11-16 | Включить события `ArchiveDualWriteStarted/Completed`, view `dual_write_status` и Supra CLI-скрипт для управления dual-write | `legacy_bridge`, операции миграции | Подготовить интеграционные тесты dual-write и dry-run миграции |
| 2025-11-17 | Включить зеркальную запись `mirror_summary_to_legacy` и модуль `history_bridge`, расширить Supra CLI командами `enable/disable-mirror`, `mirror` | `legacy_bridge`, `history`, операции миграции | Проверить dry-run миграции с использованием `history_bridge::get_summary` |
| 2025-11-18 | Зафиксировать лимиты AutomationBot через тесты `ensure_action` и обновить runbook наблюдаемости | `automation`, операции | Подготовить интеграционные проверки CLI и графики мониторинга `failure_count` |
| 2025-11-19 | Подготовить JSON Schema ответов view и покрыть фильтры UI тестами `views_tests` | `views`, фронтенд/API | Согласовать схему с фронтендом и индексаторами, добавить smoke-тесты REST |
| 2025-11-20 | Зафиксировать пример ответов view и Python-проверку JSON Schema | `views`, фронтенд/API | Подключить схему и пример в smoke-тесты REST и пайплайн индексатора |
| 2025-11-21 | Ввести релизный чек-лист, журнал операций и документ мониторинга | Операции, AutomationBot, dual-write | Интегрировать заполнение `incident_log.md` в Ops-процессы и согласовать баг-баунти вознаграждения |
| 2025-11-22 | Усилить Move Prover-спеки модуля `draw`: контроль retry, статуса `FULFILLED` и финализационного снимка | `draw`, VRF жизненный цикл | Провести прогон Move Prover после установки CLI, дополнить интеграционные тесты retry-стратегий |
| 2025-11-23 | Добавить view `pending_expected_hashes` и CLI-команду `pending` для контроля dual-write ожиданий | `legacy_bridge`, операции миграции | Привязать список ожиданий к процедурам backfill и автоматическому журналу dual-write |
| 2025-11-24 | Зафиксировать анти-DoS тесты продаж и многослотные партнёрские выплаты (`sales_tests`, `payouts_tests`) | `sales`, `payouts`, экономика | После установки CLI прогнать `aptos move test` для новых сценариев и обновить runbook по мониторингу rate-limit событий |
| 2025-11-25 | Добавить импорт/откат наследуемых сводок (`history_migration_tests`, `history_backfill.sh`) | `history`, `legacy_bridge`, операции миграции | Связать CLI с внешним backfill-скриптом, задокументировать dry-run и журнал ручных операций |
| 2025-11-26 | Ввести ручное снятие клампа (`clear_clamp`), события `PriceFeedClampClearedEvent`, тесты `price_feed_tests` и спецификацию `spec/price_feed.move`; опубликовать справочник `price_feeds.md` | `price_feed`, наблюдаемость | Интегрировать проверку событий клампа в мониторинг и добавить сценарий `clear_clamp` в release checklist |

> Обновляя таблицы, не забывайте ссылаться на коммиты, PR или внешние документы. При необходимости расширяйте разделы, но сохраняйте структуру шаблона для единообразия.
