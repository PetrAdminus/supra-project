# Оценка готовности `lottery_multi`

## Резюме
- Базовая архитектура распределена между пакетами `lottery_core`, `lottery_support`, `lottery_rewards` и расширением `lottery_multi`, что удерживает размер Move-пакетов в допустимых рамках и задаёт прозрачные границы ответственности.
- Подготовительные этапы 3–5 по документу `lottery_multi_preparation.md` находятся на завершающей стадии: события выплат, агрегаты, dual-write и миграционные скрипты реализованы, остаётся завершить контроль лимитов, интеграцию с фронтендом и запуск.
- План параллельных розыгрышей из `lottery_parallel_plan.md` описывает жизненный цикл, VRF, машину состояний и требования безопасности; он остаётся базовым источником правды для синхронизации команд.

## Готовность по ключевым доменам
### Экономика и выплаты
- Модули `economics`, `payouts`, `sales` реализуют большую часть целевой логики (агрегаты `total_allocated`, `total_prize_paid`, `total_operations_paid`, события `PayoutBatch`, `PartnerPayout`).
- Обновлены Move Prover-спеки `spec/economics.move`, `spec/payouts.move`, фиксирующие рост `payout_round`, контроль `total_*` и ограничения выплат; юнит-тесты продолжают покрывать перерасход и пропуск раундов.
- Добавлены Move-тесты `payouts_tests::payout_batch_respects_prize_cap` и `payouts_tests::payout_round_cannot_skip`, подтверждающие защиту от перерасхода призового фонда и пропуска nonce при выплатах.
- Расширен набор тестов: `payouts_tests::finalize_requires_all_winners` фиксирует блокировку финализации при незавершённом распределении победителей, а `payouts_tests::finalize_records_summary` проверяет консистентность агрегатов `LotterySummary` и статуса `STATUS_FINALIZED`.
- Дополнительно тесты `payouts_tests::payout_batch_rejected_after_finalization` и `payouts_tests::partner_payout_rejected_after_finalization` подтверждают, что после финализации новые выплаты и партнёрские транши блокируются через `E_DRAW_STATUS_INVALID`.
- Добавлены сценарии `payouts_tests::{payout_handles_multi_slot_plan, partner_payout_cannot_exceed_cap}`: первый валидирует расчёт и выплаты многослотного призового плана, второй фиксирует ошибку `E_PARTNER_PAYOUT_BUDGET_EXCEEDED` при превышении остатка `PartnerPayoutCap`.
- Реализованы on-chain рефанды: `payouts::force_refund_batch_admin` публикует `RefundBatchEvent`, `sales::record_refund_batch` ведёт агрегаты (`refund_round`, `tickets_refunded`, `prize_refunded`, `operations_refunded`), а тесты `payouts_tests::{refund_batch_records_progress, refund_requires_canceled_status, refund_cannot_exceed_tickets}` проверяют позитивные и негативные сценарии.
- Модуль `sales_tests` покрывает анти-DoS логику продаж: `block_rate_limit_triggers`, `window_rate_limit_triggers`, `grace_window_blocks_first_purchase` вызывают соответствующие ошибки (`E_PURCHASE_RATE_LIMIT_BLOCK`, `E_PURCHASE_RATE_LIMIT_WINDOW`, `E_PURCHASE_GRACE_RESTRICTED`) и подтверждают работу per-block/скользящего/grace лимитов.

### История, dual-write и миграции
- Реализованы события `ArchiveDualWrite*`, ресурс `MirrorConfig`, хук `mirror_summary_to_legacy`; подготовлены CLI-скрипты для управления зеркальной записью.
- Добавлен Move-тест `history_dual_write_tests::dual_write_mismatch_requires_manual_clear`, подтверждающий, что при допущенном расхождении ожидание хэша сохраняется до ручного сброса `clear_expected_hash`.
- Добавлен view `legacy_bridge::pending_expected_hashes` и тест `history_dual_write_tests::dual_write_pending_list`, позволяющие операторам получать список лотерей с активными ожиданиями и подтверждающие автоматическое очищение после успешного зеркалирования.
- Финализационный тест `payouts_tests::finalize_records_summary` также валидирует заполнение `LotterySummary`, включая зеркалирование данных в архив, что снижает риск неконсистентной истории.
- Добавлены Move-тесты `history_migration_tests::{import_and_rollback, import_rejects_mismatched_hash, rollback_rejects_non_legacy, update_legacy_classification}`, покрывающие импорт сводок, ручной откат и переопределение классификаторов для наследуемых тиражей.
- Модуль `history` расширен событиями `LegacySummaryImported/ RolledBack/ClassificationUpdated`, функцией `is_legacy_summary` и административными входами `import_legacy_summary_admin`, `rollback_legacy_summary_admin`, `update_legacy_classification_admin`.
- В каталог `supra/scripts` добавлен `history_backfill.sh`, автоматизирующий импорт BCS-сводок, откат и обновление тегов; runbook дополнен ссылками на команды `import`, `rollback`, `classify`, `status`, `list`.
- Реализован dry-run через `history_backfill.sh dry-run`, который использует Python-утилиту `supra.tools.history_backfill_dry_run` для расчёта sha3-256 хэша, подготовки hex-строки и генерации команды `import`; утилита покрыта тестом `tests/test_history_backfill_dry_run.py` и позволяет сохранять артефакты для CI.
- Остаётся расширить интеграционные тесты CLI/DevOps (подтянуть внешние backfill-скрипты) и документировать журнал ручных операций в `incident_log.md`.

### VRF и жизненный цикл
- Документированы переходы состояний, хэширование снапшотов и контроль `payload_hash`; AutomationBot подключён к новой логике.
- Добавлены Move-тесты `draw_tests::{request_fails_while_pending, request_respects_retry_window, request_prevents_attempt_overflow, request_updates_finalization_snapshot}`, подтверждающие блокировку повторных запросов до завершения VRF, ожидание окна retry, защиту от переполнения `attempt` и фиксацию финализационного снапшота после запроса.
- Move Prover-спецификация `spec/draw.move` усилила гарантию VRF: попытки и `next_client_seed` монотонно растут, retry-настройка фиксируется как `RETRY_STRATEGY_FIXED`, callback переводит статус в `FULFILLED`, а финализационный снимок возвращает ончейн-значения без искажений.
- Требуются финальные проверки retry-стратегий, инварианты `snapshot_hash`, `payout_round`, а также обновление Prover-спек.

### Автоматизация и операционные боты
- Модуль `automation` управляет реестром ботов, таймлоком dry-run, счётчиками `failure_count`/`success_streak` и событиями `Automation*`.
- Добавлены Move-тесты `automation_tests::{record_success_requires_pending, dry_run_blocks_duplicate_pending, record_failure_enforces_limit, success_clears_pending_and_allows_new_dry_run}`, которые фиксируют обязательность анонса перед исполнением, запрет двойного dry-run без сброса, предел `max_failures` и очистку ожиданий после успешного шага.
- Дополнительно тесты `automation_tests::{ensure_action_blocks_after_failure_limit, record_success_resets_failure_limit}` показывают, что `ensure_action` блокирует выполнение при достижении порога `max_failures`, а успешное завершение шага сбрасывает счётчик и разблокирует последующие действия.
- Runbook AutomationBot расширен подробными шагами по dry-run, таймлокам, контролю `ensure_action` и управлению `failure_count`; интеграционные проверки закрыты скриптом `supra/scripts/automation_status.sh`, который оборачивает view `list_automation_bots`/`get_automation_bot`.
- Публичные view `views::list_automation_bots`/`views::get_automation_bot` предоставляют операторам состояние ботов (таймлоки, pending, лимиты `max_failures`), покрыты тестом `views_tests::automation_views_list_registered_bot`, задокументированы в runbook, статусной странице и мониторинге.

### Роли и безопасность
- `roles.move` хранит `PayoutBatchCap`, `PartnerPayoutCap`, `PremiumAccessCap` и `PartnerCreateCap`, сопровождая выдачу/отзыв событиями `PayoutBatchCapGranted/Revoked`, `PartnerPayoutCapGranted/Revoked`, `PremiumAccessGranted/Revoked`; реализованы вьюхи `list_partner_caps`, `list_premium_caps`, флаги `has_*` и административный `cleanup_expired_admin` для автоматического удаления просроченных или исчерпавших бюджет капабилити.
- Набор Move-тестов `roles_tests` дополнен сценариями `partner_cap_blocks_after_expiry`, `admin_can_list_and_track_partner_caps`, `cleanup_expired_removes_caps`, `premium_grant_and_revoke_updates_events`, которые фиксируют события выдачи/отзыва, листинги и автоматический клинап; прежние тесты покрывают cooldown, бюджеты и корректный шаг nonce. Добавлена проверка `E_PARTNER_PAYOUT_EXPIRED` при попытке выплат после истечения срока.
- Подготовлена детальная [матрица выдачи и ревокации](../handbook/governance/roles.md#матрица-выдачи-и-ревокации-capability), фиксирующая инициаторов, таймлоки и требования по журналированию для каждой capability; документ синхронизирован с runbook’ами и чек-листом релиза.
- Остаётся автоматизировать контроль мультисиг-процедур и внедрить в CI проверку таймлоков/журналирования; исключения по тегам описаны в отдельной политике.

### Фронтенд и внешние интерфейсы
- View `lottery_multi::views` покрыты тестами `views_tests`, подтверждающими фильтры, сортировку и лимит пагинации; подготовлен документ [view_schemas.md](../handbook/architecture/view_schemas.md), JSON Schema `json/lottery_multi_views.schema.json`, пример ответов `json/examples/lottery_multi_view_samples.json` и Python-валидатор `SupraLottery/tests/test_view_schema_examples.py`.
- Добавлены агрегированные view `status_overview` (сводные статусы, VRF-бэклог, выплаты) и `list_automation_bots` (состояние AutomationBot). Тесты `views_tests::{status_overview_counts_vrf_and_statuses, automation_views_list_registered_bot}` и JSON Schema v1.0.3 фиксируют структуры ответов; пример `lottery_multi_view_samples.json` обновлён и проходит `pytest SupraLottery/tests/test_view_schema_examples.py`.
- Фронтенд-клиент `frontend/src/api/supraClient.ts` реализовал `fetchLotteryMultiViewsSupra`, нормализующий параметры `now_ts/limit/primary_type/tag_mask` и мапящий поля `status_overview` в camelCase-типы; витест `supraClient.test.ts` подтверждает работу парсера и запрос к `/lottery-multi/views`.
- Реализован React Query-хук `features/dashboard/hooks/useLotteryMultiViews`, а компонент `components/Dashboard.tsx` переводит карточки и таблицы на данные `status_overview`, показывая активные розыгрыши, блокировки VRF retry и очередь выплат вместе с метаданными `info.version`/`info.updatedAt`.
- Остаётся синхронизировать API с фронтендом и индексаторами, подготовить smoke-тесты для внешних сервисов и связать схему с pipeline валидации.

### Операционный запуск и наблюдаемость
- Runbook’и VRF, AutomationBot и прайс-фида описаны, дополнены ссылками на [release_checklist.md](../handbook/operations/release_checklist.md), [monitoring.md](../handbook/operations/monitoring.md), [incident_log.md](../handbook/operations/incident_log.md).
- Модуль `price_feed` получил ручное снятие клампа (`clear_clamp`), события `PriceFeedClampClearedEvent`, тесты `price_feed_tests`, Prover-спеку `spec/price_feed.move` и справочник [price_feeds.md](../handbook/architecture/price_feeds.md); мониторинг пополнен метриками `price_feed_*`, а release checklist включает проверку последнего `PriceFeedClampClearedEvent`.
- Автоматизировано заполнение журнала через CLI `supra/scripts/incident_log.sh` (использует Python-модуль `supra.tools.incident_log`), документированы примеры и чек-лист обновлён с новыми ссылками.
- Реализована on-chain отмена: `registry::cancel_lottery_admin` публикует `LotteryCanceledEvent`, сохраняет `CancellationRecord` и активирует `sales::begin_refund`; тесты `config_tests::{cancel_requires_reason, cancel_records_reason}` фиксируют обязательность причины и сохранение агрегатов, `views_tests::cancellation_and_refund_views` проверяет доступность данных во view, `payouts_tests::{refund_batch_records_progress, refund_requires_canceled_status, refund_cannot_exceed_tickets}` покрывают запуск `payouts::force_refund_batch_admin`, а `payouts_tests::{archive_canceled_requires_record, archive_canceled_requires_full_refund, archive_canceled_records_summary}` подтверждают, что `payouts::archive_canceled_lottery_admin` требует `CancellationRecord`, полный возврат и записывает `LotterySummary` со статусом `STATUS_CANCELED`. Runbook [operations/refund.md](../handbook/operations/refund.md) описывает `CANCEL_REASON_*`, `RefundBatchEvent`, `views::{get_cancellation, get_refund_progress}`, шаг архивирования и CLI `supra/scripts/refund_control.sh` (`cancel`, `batch`, `progress`, `archive`).
- Программа баг-баунти описана в [bug_bounty.md](../handbook/operations/bug_bounty.md); остаётся синхронизировать таблицу наград с отделом безопасности.
- Подготовлены пострелизные процессы: [operations/post_release_support.md](../handbook/operations/post_release_support.md) фиксирует ежедневные/еженедельные активности, [operations/postmortems.md](../handbook/operations/postmortems.md) задаёт шаблон отчётов; runbook, мониторинг, статусная страница и чек-лист релиза обновлены ссылками на новые документы.

## Следующие шаги
1. Завершить контроль инвариантов экономики и выплат: Prover-спеки обновлены, зафиксированы ограничения `total_*` и рост `payout_round`; остаётся закрыть интеграционные сценарии и актуализировать документацию агрегатов после включения внешних CLI.
2. Довести dual-write и миграционные сценарии: интеграционные тесты, связка внешних backfill-скриптов с `history_backfill.sh dry-run`, расширение журнала ручных операций (CLI автоматизация готова, требуется подключить внешние инструменты).
3. Закрыть вопросы VRF и машины состояний: инварианты, retry-стратегии, обновление AutomationBot и документации.
4. Завершить настройку ролей и ограничений тегов: матрица выдачи и ревокации задокументирована, остаётся донести требования по мультисигу до DevOps-процессов и подключить автоматическую проверку таймлоков в CI.
5. Адаптировать фронтенд и внешние сервисы: JSON Schema, совместные сессии с фронтом, smoke-тесты.
6. Подготовить операционный запуск и наблюдаемость: runbook’и дополнены ссылками на релизный чек-лист и мониторинг; автоматизация `incident_log.md` внедрена, осталось утвердить награды баг-баунти и связать журнал с внешними инструментами DevOps.

## Требования к обновлению
- Документ обновляется после завершения каждого шага и синхронизируется с `docs/handbook/contracts/lottery_multi.md` и `docs/handbook/operations/runbooks.md`.
- При изменении сроков или приоритетов необходимо добавить ссылку на PR/коммит и кратко описать корректировку.
