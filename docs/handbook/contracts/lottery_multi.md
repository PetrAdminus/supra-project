# Пакет `lottery_multi`

Пакет отвечает за архитектуру параллельных лотерей и состоит из модулей, внедрённых на этапах 1 и 2 RFC v1. Ниже указаны ключевые функции, механики и события каждого модуля.

## Этап 1. Базовые модули

### `tags`
- Константы `TYPE_*` определяют основной тип розыгрыша (basic, partner, jackpot, vip).
- Константы `TAG_*` и `TAG_EXPERIMENTAL` формируют битовые теги; `assert_tag_budget` ограничивает количество активных битов.
- `validate(primary_type, tags_mask)` проверяет допустимость комбинации.
- Юнит `roles_tests::tag_budget_limits_active_bits` подтверждает, что `assert_tag_budget` блокирует маски с более чем 16 активными флагами.
- Подробная политика классификаторов и допустимых комбинаций описана в [tags_policy.md](tags_policy.md).

### `registry`
- `init_registry` инициализирует глобальное хранилище.
- `create_draft_admin` / `create_draft_partner` создают черновые лотереи, эмитируя `LotteryCreated` с хэшем конфигурации и тегами.
- `set_primary_type`, `set_tags_mask` позволяют редактировать классификацию до блокировки снапшота.
- Тест `config_tests::cannot_update_tags_after_snapshot` фиксирует, что вызов `set_tags_mask` запрещён после перехода в `STATUS_CLOSING` и заморозки снапшота (`E_TAGS_LOCKED`).
- Сценарии ручных исключений (legacy миграции, партнёрские эскалации, эксперименты) описаны в [tags_policy.md](tags_policy.md#4-исключения-и-ручные-процедуры).
- `advance_status` переводит лотерею между статусами (`Draft → Active → Closing → DrawRequested → Drawn → Payout → Finalized/Cancelled`) и при переходе в `Closing` замораживает снапшот.
- `borrow_config`, `get_status`, `is_snapshot_frozen` предоставляют чтение состояния для других модулей.
- `cancel_lottery_admin` переводит розыгрыш в `STATUS_CANCELED`, требует ненулевой `reason_code`, фиксирует количество проданных билетов и выручку на момент отмены, принудительно замораживает снапшот и публикует `LotteryCanceledEvent` с категорией `EVENT_CATEGORY_REFUND`. При наличии продаж дополнительно вызывается `sales::begin_refund`, что активирует трекинг `RefundProgressView`; публичный доступ к причине отмены обеспечивает view `views::get_cancellation`. Для операций предусмотрен CLI `SupraLottery/supra/scripts/refund_control.sh cancel`.
- Константы `CANCEL_REASON_*` и view `get_cancellation_record` документируют причину (`VRF_FAILURE`, `COMPLIANCE`, `OPERATIONS`), предыдущий статус и агрегаты отменённой лотереи; тесты `config_tests::{cancel_requires_reason, cancel_records_reason}` подтверждают валидацию и сохранение метаданных.

### `sales`
- `purchase_tickets_public` и `purchase_tickets_premium` продают билеты, применяя лимиты на пользователя, окно продаж и флаг премиального доступа.
- Анти-DoS механики: per-block счётчик, скользящее окно и grace window; нарушение фиксируется `PurchaseRateLimitHit`.
- `emit_purchase_event` формирует `TicketPurchaseEvent` с распределением выручки.
- `accounting_snapshot` возвращает агрегаты `Accounting` для фронтенда и аудита.
- `record_payouts` обновляет агрегаты `total_allocated`/`total_prize_paid`/`total_operations_paid` по факту выплат.
- Тестовый модуль `sales_tests` проверяет срабатывание анти-DoS ограничений: `block_rate_limit_triggers`, `window_rate_limit_triggers`, `grace_window_blocks_first_purchase` вызывают `E_PURCHASE_RATE_LIMIT_BLOCK`, `E_PURCHASE_RATE_LIMIT_WINDOW`, `E_PURCHASE_GRACE_RESTRICTED` соответственно.

### `draw`
- `init_draw` готовит ресурсы для VRF-процесса.
- `request_draw_admin` (и внутренние проверки) формируют `PayloadV1` с `closing_block_height`, `chain_id`, `schema_version` и увеличенным `attempt`.
- `vrf_callback` проверяет `request_id`, `attempt`, `consumed`, записывает seed, публикует `VrfFulfilled` и разблокирует вычисление победителей.
- Юнит `lottery_multi::draw_tests` проверяет остановку запросов при паузе депозита, запрет повторных запросов до завершения VRF (`E_VRF_PENDING`), соблюдение окна повторного запроса (`E_VRF_RETRY_WINDOW`), защиту от переполнения `attempt`, обновление `finalization_snapshot`, автоматическую отмену при достижении `MAX_VRF_ATTEMPTS = 5`, экспоненциальный рост интервалов при стратегии retry `=1` и блокировку без ручного расписания для стратегии `=2`.
- Prover-спека `spec/draw.move` доказывает, что `request_draw_admin` увеличивает `attempt` и `next_client_seed`, применяет `registry::Config.vrf_retry_policy` (fixed/exponential/manual) к `retry_after_ts`, фиксирует параметры `chain_id`/`closing_block_height`, а при исчерпании лимита попыток переводит состояние в `VRF_STATUS_FAILED` без нового запроса; callback устанавливает статус `VRF_STATUS_FULFILLED`, а `finalization_snapshot` возвращает неизменённые ончейн-значения.

### `payouts`
- `init_payouts` разворачивает инфраструктуру выплат.
- `compute_winners_admin` выполняет детерминированный алгоритм выбора победителей по батчам, эмитируя `WinnerBatchComputed` с `checksum_after_batch`.
- `record_payout_batch_admin` требует `roles::PayoutBatchCap`, использует `roles::consume_payout_batch` для проверки `max_batch_size`, бюджета операций, cooldown и nonce, затем обновляет агрегаты продаж и `payout_round`; вызов разрешён только пока лотерея находится в `STATUS_PAYOUT`.
- `record_partner_payout_admin` требует `roles::PartnerPayoutCap`, вычитает бюджет через `roles::consume_partner_payout` и публикует `PartnerPayoutEvent` с адресом партнёра, суммой, раундом и таймстампом; аналогично доступен только в статусе `STATUS_PAYOUT`.
- `force_refund_batch_admin` доступен после отмены тиража (`STATUS_CANCELED`), использует `PayoutBatchCap` для контроля размера батча и бюджета операций, вызывает `sales::record_refund_batch` и публикует `RefundBatchEvent` с накопительными итогами. Агрегаты доступны через `views::get_refund_progress` (обёртка над `sales::refund_progress`). CLI `SupraLottery/supra/scripts/refund_control.sh batch`/`progress` автоматизирует операции.
- `archive_canceled_lottery_admin` фиксирует отменённый розыгрыш в архиве: проверяет наличие `CancellationRecord`, завершённость on-chain рефандов (`tickets_refunded`, `last_refund_ts`, сумма возврата), собирает агрегаты из `sales::accounting_snapshot` и записывает `LotterySummary` со статусом `STATUS_CANCELED` через `history::record_summary`. Вызов можно выполнить через `SupraLottery/supra/scripts/refund_control.sh archive`/`summary`.
- `finalize_lottery_admin` переводит розыгрыш в `Finalized`, проверяя, что все победители определены, агрегаты выплат зафиксированы и архивная сводка записана через `history::record_summary`.
- Юнит `lottery_multi::payouts_tests` подтверждает обновление `Accounting`, лимиты операций, сценарии партнёрских выплат и обязательность наличия капабилити.
- Негативные сценарии покрыты отдельными тестами: `payout_batch_respects_prize_cap` выбрасывает `E_PAYOUT_ALLOC_EXCEEDED` при попытке перерасхода призового фонда, `payout_round_cannot_skip` ловит пропуск nonce через `E_PAYOUT_BATCH_NONCE`, `finalize_requires_all_winners` подтверждает блокировку финализации при неполном распределении победителей (`E_FINALIZATION_INCOMPLETE`), `finalize_records_summary` проверяет, что после финализации сводка `LotterySummary` содержит ожидаемые агрегаты и статус `STATUS_FINALIZED`, а `payout_batch_rejected_after_finalization` и `partner_payout_rejected_after_finalization` демонстрируют, что любые новые выплаты после финализации завершаются `E_DRAW_STATUS_INVALID`.
- Дополнительно `payouts_tests::payout_handles_multi_slot_plan` валидирует распределение выигрышей для многослотной конфигурации, `payouts_tests::partner_payout_cannot_exceed_cap` фиксирует ошибку `E_PARTNER_PAYOUT_BUDGET_EXCEEDED` при превышении остатка партнёрского бюджета, `partner_payout_updates_operations` отслеживает уменьшение `remaining_payout` после успешного транша, `refund_batch_records_progress`/`refund_requires_canceled_status`/`refund_cannot_exceed_tickets` покрывают позитивные и негативные сценарии on-chain рефандов, `archive_canceled_requires_record` и `archive_canceled_requires_full_refund` подтверждают обязательность `CancellationRecord` и полного возврата средств перед архивированием, `archive_canceled_records_summary` сверяет сохранённую сводку `LotterySummary`, а `views_tests::cancellation_and_refund_views` проверяет доступность причины отмены и прогресса возврата через публичные view.

### `views`
- `validate_config` выполняет ончейн-валидацию конфигурации перед созданием.
- `get_lottery`, `get_lottery_status`, `get_lottery_badges`, `get_badge_metadata` — основные запросы для UI.
- `list_active`, `list_by_primary_type`, `list_by_tag_mask`, `list_by_all_tags` — пагинация по статусам и тегам.
- `accounting_snapshot`, `get_vrf_deposit_status`, `get_lottery_summary`, `list_finalized_ids`, `status_overview` — агрегированные представления; `status_overview(now_ts)` возвращает счётчики по статусам жизненного цикла, активным/заблокированным VRF-запросам и бэклогу выплат.
- `list_automation_bots` и `get_automation_bot` предоставляют публичный снимок AutomationBot: адрес оператора, разрешённые `action_id`, таймлок, лимит `max_failures`, счётчики `failure_count`/`success_streak`, репутацию, pending-digest и срок действия регистрации. View опираются на новые публичные хелперы `automation::automation_operators` и `automation::automation_status_option`; для оперативного доступа подготовлен CLI `SupraLottery/supra/scripts/automation_status.sh`, оборачивающий оба вызова.
- Тестовый модуль `views_tests` проверяет требование полного совпадения масок (`list_by_all_tags`), порядок сортировки и пагинацию по типам (`list_by_primary_type`), ограничение `E_PAGINATION_LIMIT`, агрегированную сводку и SLA рефандов (`status_overview_counts_vrf_and_statuses`, `status_overview_tracks_refund_metrics`), а также наличие зарегистрированного бота и корректность `option`-ответа (`automation_views_list_registered_bot`).
- JSON Schema `docs/handbook/architecture/json/lottery_multi_views.schema.json` описывает структуры `BadgeMetadata`, `LotteryStatusView`, `VrfDepositStatusView`, `LotteryConfig`, `LotterySummary`, `StatusOverview`, `Accounting` и `AutomationBotView`; пример ответов версии `1.0.5` хранится в `docs/handbook/architecture/json/examples/lottery_multi_view_samples.json` и валидируется `pytest SupraLottery/tests/test_view_schema_examples.py`.
- `status_overview` используется в операционной процедуре рефанда (`operations/refund.md`) для оценки очереди отмен и соблюдения SLA, а `list_automation_bots`/`get_automation_bot` применяются в runbook AutomationBot и на статусной странице для контроля pending-действий и лимитов `max_failures`.

### `feature_switch`
- Управляет режимами функций (`Disabled`, `EnabledAll`, `PremiumOnly`) с учётом критических операций и devnet-override.

### `price_feed`
- Реестр `PriceFeedRegistry` хранит записи `PriceFeedRecord` с полями `price`, `decimals`, `staleness_window`, `clamp_threshold_bps`, `fallback_active`, `fallback_reason`, `clamp_active`; инициализация выполняется через `init_price_feed(version)`.
- `register_feed` добавляет новый источник цены (по умолчанию `DEFAULT_STALENESS_WINDOW = 300`, `DEFAULT_CLAMP_THRESHOLD_BPS = 2_000`), публикуя событие `PriceFeedUpdatedEvent`.
- `update_price` проверяет скачок цены, фиксирует кламп (`clamp_active = true`) и эмитирует `PriceFeedClampEvent`, если изменение превышает порог; при нормальном обновлении флаг fallback сбрасывается и публикуется `PriceFeedUpdatedEvent`.
- `set_fallback` включает/выключает резервный источник и эмитирует `PriceFeedFallbackEvent`; выключение автоматически снимает кламп.
- `clear_clamp` — ручное подтверждение оператора с событием `PriceFeedClampClearedEvent`, обнуляющим `clamp_active` и обновляющим `last_updated_ts`.
- View-функции `latest_price` и `get_price_view` блокируют потребителей при активном fallback или клампе (`E_PRICE_FALLBACK_ACTIVE`, `E_PRICE_CLAMP_ACTIVE`), гарантируя свежесть данных и соответствие базис-поинтов.
- Набор тестов `price_feed_tests::{register_and_read, stale_feed_rejected, fallback_blocks_consumers, clamp_marks_feed_unavailable, clamp_blocks_latest_price, clear_clamp_allows_recovery}` подтверждает поведение обновлений, блокировок и ручного разблокирования; спецификация `spec/price_feed.move` фиксирует инварианты записей и эффекты операций.

### `automation`
- `init_automation` разворачивает реестр ботов и event handle’ы `Automation*` на адресе пакета.
- `register_bot`/`rotate_bot` выпускают `AutomationCap`, настраивают `allowed_actions`, `timelock_secs`, `max_failures`, cron-спеку и эмитируют `AutomationKeyRotated`. Для действий `ACTION_UNPAUSE`, `ACTION_PAYOUT_BATCH`, `ACTION_CANCEL` таймлок обязан быть ≥ `MIN_SENSITIVE_TIMELOCK_SECS = 900` секунд (15 минут), иначе операция завершается `E_AUTOBOT_TIMELOCK`.
- `announce_dry_run` фиксирует `pending_action_hash`/`pending_execute_after` и требует, чтобы `executes_after_ts` превышал `now_ts + timelock_secs`.
- `record_success` и `record_failure` проверяют совпадение digest с анонсом (при ненулевом таймлоке), обновляют `failure_count`, `success_streak`, `reputation_score`, очищают pending и публикуют `AutomationTick` (+ `AutomationError` для ошибок).
- `report_call_rejected` и `ensure_action` используются фронтом/ботом для журналирования отказов и проверки лимитов (`max_failures`, срок действия капабилити).
- Набор тестов `automation_tests::{record_success_requires_pending, dry_run_blocks_duplicate_pending, record_failure_enforces_limit, ensure_action_blocks_after_failure_limit, record_success_resets_failure_limit, success_clears_pending_and_allows_new_dry_run}` демонстрирует обязательность dry-run перед исполнением, блокировку повторных анонсов, срабатывание порога `max_failures`, работу `ensure_action` при достижении лимита и очистку pending после успешного шага.

## Этап 2. Миграции и инфраструктура

### `history`
- `ArchiveLedger` хранит финальные сводки (`LotterySummary`) с агрегатами `total_allocated`, `total_prize_paid`, `total_operations_paid`.
- `finalize_lottery_admin` из `payouts` вызывает `history::record_summary` с проверкой `slots_checksum` и `snapshot_hash`.
- `PayoutBatchEvent`, `PartnerPayoutEvent`, `PurchaseRateLimitHitEvent` формируют неизменяемый журнал для аудита.
- `get_summary`, `list_finalized` обслуживают фронтенд «Истории».
- Административные функции `import_legacy_summary_admin`, `rollback_legacy_summary_admin`, `update_legacy_classification_admin` позволяют переносить сводки из `lottery_support::History`, откатывать некорректные записи и вручную назначать классификаторы (`primary_type`, `tags_mask`). Все операции сопровождаются событиями `LegacySummaryImportedEvent`, `LegacySummaryRolledBackEvent`, `LegacySummaryClassificationUpdatedEvent`.
- Перед импортом администратор записывает ожидаемый хэш через `legacy_bridge::set_expected_hash`; успешный вызов `import_legacy_summary_admin` зеркалирует запись в `lottery_support::history_bridge`, вызывает `legacy_bridge::notify_summary_written` и очищает pending-ожидание dual-write.
- View `is_legacy_summary` сигнализирует индексаторам и фронтенду о происхождении записи. Набор тестов `history_migration_tests` покрывает импорт по BCS, отказ при неверном хэше, запрет отката для новых розыгрышей и переопределение тегов.

### `legacy_bridge`
  - Управляет dual-write миграциями: `init_dual_write`, `update_flags`, `set_expected_hash`, `clear_expected_hash`, `enable_legacy_mirror`, `disable_legacy_mirror`, `mirror_summary_admin`, `notify_summary_written`, `dual_write_status`, `dual_write_flags`, `pending_expected_hashes`.
- События `ArchiveDualWriteStartedEvent`/`ArchiveDualWriteCompletedEvent` фиксируют жизненный цикл ожиданий; `mirror_summary_to_legacy` записывает BCS сводки в `lottery_support::history_bridge`, после чего `notify_summary_written` сравнивает ожидаемый и фактический хэш, очищает ожидание и публикует завершение (при конфигурации `abort_on_mismatch` транзакция прерывается).
- Вспомогательный view `pending_expected_hashes` возвращает список лотерей с установленным ожидаемым хэшем; тест `history_dual_write_tests::dual_write_pending_list` подтверждает, что список обновляется после успешной записи сводки и ручного сброса ожиданий.
- Тест `history_dual_write_tests::dual_write_mismatch_requires_manual_clear` показывает, что при отключенном `abort_on_mismatch` ожидание хэша остаётся в таблице и требует ручного сброса `clear_expected_hash`, тем самым фиксируя операционный контроль mismatched-батчей.
- При импорте или изменении классификаторов (`history_backfill.sh import/classify`) `legacy_bridge::mirror_summary_to_legacy` автоматически зеркалирует BCS в `lottery_support::history_bridge`, сохраняя консистентность legacy-архива.

### `vrf_deposit`
- `init_vrf_deposit`, `update_config` задают пороги.
- `record_snapshot_admin` / `record_snapshot_automation` обновляют показатели и публикуют `VrfDepositSnapshot`/`Alert`/`RequestsPaused`; автоматизированный вызов требует dry-run с `snapshot_hash` и timelock, блокируя выполнение без pending и автоматически вызывая `automation::record_success` после удачного снапшота.
- `resume_requests` снимает блокировку, `ensure_requests_allowed` используется при новом запросе VRF.

### `roles`
- `init_roles` разворачивает `RoleStore` с таблицами `PartnerPayoutCap`, `PremiumAccessCap`, индексами адресов и event handle’ами `RoleGranted/RoleRevoked` для каждой категории ролей; `set_payout_batch_cap_admin`/`revoke_payout_batch_cap_admin`, `upsert_partner_payout_cap_admin`/`revoke_partner_payout_cap_admin`, `grant_premium_access_admin`/`revoke_premium_access_admin` публикуют соответствующие события и обновляют индекс.
- `consume_payout_batch`/`consume_partner_payout` блокируют выплаты при нарушении лимитов (`E_PAYOUT_BATCH_TOO_LARGE`, `E_PAYOUT_OPERATIONS_BUDGET`, `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`, `E_PARTNER_PAYOUT_COOLDOWN`, `E_PARTNER_PAYOUT_NONCE`, `E_PARTNER_PAYOUT_EXPIRED`); для премиальных подписок `is_premium_active` учитывает бессрочные (expires_at = 0) капабилити.
- `cleanup_expired_admin` автоматически отзывает просроченные или исчерпанные капабилити и эмитирует `PartnerPayoutCapRevokedEvent`/`PremiumAccessRevokedEvent`, что фиксируется в операционном журнале.
- View-функции `list_partner_caps`, `list_premium_caps`, `has_*`, `borrow_*` и `event_counters` предоставляют фронтенду и операциям актуальный список ролей, включая остатки бюджетов, таймлоки, expiry и ссылку на реферера.
- `PartnerCreateCap` содержит белый список `allowed_primary_types` и `allowed_tags_mask`, лимиты бюджета и cooldown выплат для контроля `record_partner_payout_admin`; `ensure_primary_type_allowed`, `ensure_tags_allowed` проверяют параметры партнёров при создании лотереи. Конструктор `roles::new_partner_cap` дополнительно валидирует маску тегов через `tags::validate(TYPE_PARTNER, allowed_tags_mask)` и `tags::assert_tag_budget`, исключая неизвестные биты и превышение лимита активных тегов.
- Набор тестов `roles_tests` дополнен сценариями `partner_cap_blocks_after_expiry`, `admin_can_list_and_track_partner_caps`, `cleanup_expired_removes_caps`, `premium_grant_and_revoke_updates_events`, подтверждающими события выдачи/отзыва, листинги и автоматический клинап; прежние тесты продолжают покрывать cooldown, бюджеты и корректный шаг nonce.
- Требования комплаенса и список ограниченных юрисдикций описаны в `docs/handbook/governance/compliance.md`; при обновлении ролей партнёров необходимо сверяться с этим документом.

### Дополнительные механики
- `economics::assert_distribution` и связанные функции проверяют распределение продаж по базис-поинтам (сумма 10_000).
- `Accounting` отслеживает `total_sales`, `total_allocated`, `total_prize_paid`, `total_operations_paid`, `total_operations_allocated`; функции `record_prize_payout` и `record_operations_payout` защищают от перерасхода (`E_PAYOUT_ALLOC_EXCEEDED`, `E_OPERATIONS_ALLOC_EXCEEDED`).
- Интеграционный тест `payouts_tests::accounting_aligns_with_summary_and_view` сверяет `sales::accounting_snapshot`, view `accounting_snapshot` и `history::get_summary`, подтверждая консистентность агрегатов `total_*` и рост `payout_round` после финализации. 【F:SupraLottery/supra/move_workspace/lottery_multi/tests/payouts_tests.move†L336-L372】
- `types::prize_plan_checksum`, `types::winner_cursor` поддерживают контроль целостности слотов и батчей.
- Move Prover спецификации (`spec/*.move`) фиксируют: неизменность `snapshot_hash`, рост `payout_round`, ограничения `jackpot_allowance_token`, монотонность `attempt`/`next_client_seed` и статус `FULFILLED` VRF, а также то, что `record_payout_batch_admin`/`record_partner_payout_admin` корректно отражают выплаты в `sales::accounting_snapshot`.

## Использование в документации
- Примеры вызовов и сценариев приведены в [../operations/runbooks.md](../operations/runbooks.md), [../operations/release_checklist.md](../operations/release_checklist.md), [../operations/monitoring.md](../operations/monitoring.md), [../operations/post_release_support.md](../operations/post_release_support.md), [../operations/postmortems.md](../operations/postmortems.md) и [../frontend/overview.md](../frontend/overview.md).
- Для пошагового описания этапов и связки механик с тестами см. [lottery_multi_stage_playbook.md](lottery_multi_stage_playbook.md).
- Операционные заметки и программа безопасности доступны в [../operations/incident_log.md](../operations/incident_log.md), [../operations/post_release_support.md](../operations/post_release_support.md), [../operations/postmortems.md](../operations/postmortems.md) и [../operations/bug_bounty.md](../operations/bug_bounty.md).
- При обновлении модулей необходимо синхронно править этот файл и карточку этапа в `architecture/rfc_status.md`.
