# Пошаговое руководство по этапам `lottery_multi`

Документ описывает практическую сторону внедрения RFC v1 для `lottery_multi` и связывает реализованные механики с контрактными
модулями, тестами и операционными процедурами. Используйте этот файл как дополнение к [основному описанию пакета](lottery_multi.md)
и операционным runbook’ам.

## Этап 3. Продажи, экономика и выплаты

### Основные модули
- `sales` — продажи билетов с анти-DoS защитой (`block`, `window`, `grace`). События `TicketPurchaseEvent` и `PurchaseRateLimitHit`
  формируют поток мониторинга.
- `economics` — распределение выручки, контроль лимитов и токена джекпота через `assert_distribution`, `record_prize_payout`,
  `record_operations_payout`.
- `payouts` — вычисление и фиксация победителей, партнёрские выплаты, финализация и рефанды, события `WinnerBatchComputed`,
  `PayoutBatchEvent`, `PartnerPayoutEvent`, `RefundBatchEvent`.
- `roles` — управление `PayoutBatchCap`, `PartnerPayoutCap`, премиальными подписками и партнёрскими шаблонами.

### Сценарии эксплуатации
1. **Запуск продаж.** Перед активацией лотереи оператор проверяет конфигурацию (`views::validate_config`) и лимиты продаж.
   Анти-DoS механики покрыты тестами `sales_tests::{block_rate_limit_triggers, window_rate_limit_triggers,
   grace_window_blocks_first_purchase}` — при их срабатывании ожидать `E_PURCHASE_RATE_LIMIT_BLOCK`, `E_PURCHASE_RATE_LIMIT_WINDOW`,
   `E_PURCHASE_GRACE_RESTRICTED` и фиксировать инцидент.
2. **Контроль экономики.** При каждом батче `payouts::record_payout_batch_admin` сверяются агрегаты `sales::accounting_snapshot`.
   Prover-спеки в `spec/economics.move` и `spec/payouts.move` гарантируют, что `allocated >= paid`, `payout_round` возрастает
   монотонно, а токен джекпота не перерасходуется.
3. **Партнёрские выплаты.** Перед `record_partner_payout_admin` оператор проверяет остаток `PartnerPayoutCap` (`roles::list_partner_caps`).
   Отказ фиксируется ошибками `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`, `E_PARTNER_PAYOUT_COOLDOWN`, `E_PARTNER_PAYOUT_NONCE`,
   `E_PARTNER_PAYOUT_EXPIRED`. Юнит `payouts_tests::partner_payout_cannot_exceed_cap` демонстрирует защиту от перерасхода.
4. **Финализация.** `payouts_tests::{finalize_requires_all_winners, finalize_records_summary}` подтверждают блокировку, пока
   не вычислены победители и не записана сводка. После `finalize_lottery_admin` вызывается `history::record_summary` и
   запускается dual-write зеркало.
5. **VRF и повторные запросы.** `draw::request_draw_admin` использует retry-стратегию с таймлоками. Тесты `draw_tests`
   проверяют окна retry (`E_VRF_RETRY_WINDOW`), защиту от переполнения `attempt` и формирование `finalization_snapshot`.
6. **AutomationBot.** Dry-run обязателен (`automation_tests::record_success_requires_pending`), лимиты `max_failures`
   контролируются тестами `ensure_action_blocks_after_failure_limit`, `record_success_resets_failure_limit`. Публичные
   view `views::list_automation_bots`/`get_automation_bot` возвращают состояние бота для операторов и покрыты тестом
   `views_tests::automation_views_list_registered_bot`.

### Операционные артефакты
- Runbook: разделы «Администратор», «AutomationBot», «Dual-write миграция» в [operations/runbooks.md](../operations/runbooks.md).
- Мониторинг: метрики `status_overview`, `payout_round_gap`, `automation_failure_count`, `price_feed_*` и новые view
  `list_automation_bots`/`get_automation_bot` описаны в [operations/monitoring.md](../operations/monitoring.md).
- Чек-лист релиза: секции «Продажи и выплаты», «AutomationBot», «Прайс-фид» в [operations/release_checklist.md](../operations/release_checklist.md).

## Этап 4. Миграции и backfill

### Основные модули
- `history` — импорт и откат legacy-сводок (`import_legacy_summary_admin`, `rollback_legacy_summary_admin`,
  `update_legacy_classification_admin`), события `LegacySummaryImportedEvent`, `LegacySummaryRolledBackEvent`,
  `LegacySummaryClassificationUpdatedEvent`.
- `legacy_bridge` — управление dual-write (`set_expected_hash`, `clear_expected_hash`, `mirror_summary_admin`, `pending_expected_hashes`).
- Скрипты `supra/scripts/history_backfill.sh`, `supra/scripts/dual_write_control.sh` и Python-утилита `supra.tools.history_backfill_dry_run`.

### Сценарии эксплуатации
1. **Подготовка данных.** `history_backfill.sh dry-run` рассчитывает `sha3-256` и hex-представление BCS сводки.
   Тест `tests/test_history_backfill_dry_run.py` гарантирует корректность расчётов и формирования готовой команды `import`.
2. **Импорт legacy.** `history_migration_tests::imports_summary_successfully` подтверждает успешную запись и событие
   `LegacySummaryImportedEvent`. При расхождении хэша `history_migration_tests::import_rejects_wrong_hash` ловит
   `E_HISTORY_HASH_MISMATCH`.
3. **Откат и классификаторы.** Функция `rollback_legacy_summary_admin` доступна только для legacy-записей — отказ покрыт тестом
   `history_migration_tests::cannot_rollback_new_summary`. Команда `classify` обновляет `primary_type` и `tags_mask`,
   публикуя `LegacySummaryClassificationUpdatedEvent`.
4. **Dual-write ожидания.** Список активных ожиданий доступен через `legacy_bridge::pending_expected_hashes` и одноимённую
   команду скрипта. Тест `history_dual_write_tests::dual_write_pending_list` показывает, что лотерея исчезает из списка
   после `notify_summary_written`. При разрешённом mismatched-батче `dual_write_mismatch_requires_manual_clear` подтверждает,
   что требуется ручной `clear_expected_hash`.
5. **Документация операций.** Runbook и мониторинг включают шаги для dry-run, импорта, проверки алёртов `dual_write_pending`
   и заполнения журнала инцидентов.

### Операционные артефакты
- Runbook: разделы «Dual-write миграция» и «Администратор» в [operations/runbooks.md](../operations/runbooks.md).
- Мониторинг: таблица метрик `dual_write_*` в [operations/monitoring.md](../operations/monitoring.md).
- Статусная страница: показатели `status_overview.pending_dual_write` и `status_overview.vrf_retry_blocked` описаны в
  [operations/status_page.md](../operations/status_page.md).

## Этап 5. Администрируемый запуск

### Основные модули и механики
- `roles` — расширенный `RoleStore`, события выдачи/отзыва, листинги `list_partner_caps`, `list_premium_caps`, `event_counters`,
  `cleanup_expired_admin`.
- `automation` — процедуры dry-run, таймлоки, контроль `max_failures` и событий `AutomationTick`/`AutomationError`.
- `price_feed` — ручной кламп, fallback и восстановление (`clear_clamp`), события `PriceFeedClampEvent`, `PriceFeedClampClearedEvent`.
- `views::status_overview` и `views::list_automation_bots` — агрегированные счётчики статусов, retry-окон, бэклога выплат и текущее состояние AutomationBot; для ручных проверок и подготовки отчётов используйте CLI `./supra/scripts/automation_status.sh`.
- CLI `supra/scripts/incident_log.sh` — автоматизация журналирования решений.
- `registry::cancel_lottery_admin` — перевод розыгрыша в `STATUS_CANCELED`, сохранение `CancellationRecord` и эмиссия `LotteryCanceledEvent`.

### Сценарии эксплуатации
1. **Управление ролями.** Администратор выдаёт капабилити через `roles::set_payout_batch_cap_admin`, `roles::upsert_partner_payout_cap_admin`,
   `roles::grant_premium_access_admin`. Тесты `roles_tests::{admin_can_list_and_track_partner_caps, cleanup_expired_removes_caps,
   premium_grant_and_revoke_updates_events}` подтверждают события и автоматический клинап.
2. **AutomationBot.** Каждый dry-run заносится в журнал через `incident_log.sh --type "Dry-run"`. При достижении лимита отказов
   (`E_AUTOBOT_FAILURE_LIMIT`) оператор должен выполнить `rotate_bot` и обновить cron-спеку. Runbook описывает формат записи,
   обязательную проверку `ensure_action` перед вызовом on-chain операций и использование view `views::list_automation_bots`
   для контроля pending-действий и таймлоков.
3. **Прайс-фид.** При резких скачках цены активируется fallback/кламп. Тесты `price_feed_tests::{fallback_blocks_consumers,
   clamp_blocks_latest_price, clear_clamp_allows_recovery}` и Prover-спека `spec/price_feed.move` гарантируют поведение.
   После ручного `clear_clamp` обязательно обновить мониторинг и журнал.
4. **Статусная страница.** `status_overview` агрегирует статусы розыгрышей, retry-окна VRF, бэклог выплат и остаток dual-write.
   React Query-хук `features/dashboard/hooks/useLotteryMultiViews` и компонент `components/Dashboard.tsx` отображают активные
   розыгрыши, блокировки VRF и очередь выплат. Пример ответов и JSON Schema валидируются тестом
   `SupraLottery/tests/test_view_schema_examples.py`. Руководство по публикации графиков см. в
   [operations/status_page.md](../operations/status_page.md).
5. **Инцидентный журнал.** Инструмент `supra/tools/incident_log.py` обеспечивает сортировку по убыванию даты и удаляет шаблонные
   заголовки. Тест `tests/test_incident_log_tool.py` подтверждает корректность CLI. Используйте его для протоколирования dry-run,
   ручных выплат, клампов прайс-фида и обновлений ролей.
6. **Отмена тиража.** Решение фиксируется через `registry::cancel_lottery_admin(lottery_id, reason_code, now_ts)`, после чего
   проверяется `views::get_cancellation`. Тесты `config_tests::{cancel_requires_reason, cancel_records_reason}` подтверждают
   проверку кода и сохранение агрегатов, а `views_tests::cancellation_and_refund_views` — доступность данных во view. После отмены
   запускаются on-chain рефанды `payouts::force_refund_batch_admin` (контроль `refund_round`, `tickets_refunded`, `RefundBatchEvent`)
   и мониторинг `views::get_refund_progress`. Завершение процедуры фиксируется вызовом `payouts::archive_canceled_lottery_admin`,
   который проверяет полноту возвратов и записывает `LotterySummary` со статусом `STATUS_CANCELED`; покрытие обеспечивают тесты
   `payouts_tests::{archive_canceled_requires_record, archive_canceled_requires_full_refund, archive_canceled_records_summary}`.
   Runbook [operations/refund.md](../operations/refund.md) описывает выбор `CANCEL_REASON_*`, требования к журналированию, чек-лист
   батчей и шаг архивирования, а CLI `supra/scripts/refund_control.sh` оборачивает сценарии `cancel`, `batch`, `progress`, `summary`, `archive`.

### Операционные артефакты
- Release checklist: разделы «Роли и доступы», «AutomationBot», «Прайс-фид», «Журнал операций».
- Мониторинг: метрики `automation_failure_count`, `price_feed_*`, `status_overview.*`.
- Bug bounty и поддержка: [operations/bug_bounty.md](../operations/bug_bounty.md) и [support/sla.md](../support/sla.md).

## Этап 6. Пострелизная поддержка

### Основные задачи
- Поддержание наблюдаемости: актуализация дашбордов, алёртов и статуса готовности (`docs/architecture/lottery_multi_readiness_review.md`).
- Регулярные ретроспективы по AutomationBot и dual-write, обновление процедур в `operations/runbooks.md`, `operations/refund.md` и `incident_log.md`.
- Подготовка к переходу на on-chain governance (см. `docs/architecture/lottery_parallel_plan.md`).
- Актуализация пользовательской и партнёрской документации, включая FAQ и фронтенд-гайды, a11y-плейбук (`frontend/a11y.md`) и раздел комплаенса (`governance/compliance.md`).
- Пострелизные активности документируются в [operations/post_release_support.md](../operations/post_release_support.md), а отчёты и ретроспективы заносятся в [operations/postmortems.md](../operations/postmortems.md) в течение 24 часов после события.

### Метрики зрелости
- «Зелёный» статус всех алёртов в Grafana/Alertmanager.
- SLA по обработке инцидентов ≤ 24 часов для высоких приоритетов, ≤ 72 часов для средних.
- Zero mismatches в dual-write > 7 дней подряд или документированная процедура анализа отклонений.
- Обновлённые примеры API и JSON Schema после каждого релиза.

### Рекомендации
- Ежемесячно сверять документацию с фактическими Prover-спеками и юнит-тестами.
- Поддерживать синхронизацию между `docs/handbook/contracts/` и `docs/architecture/` — любые изменения в коде должны сопровождаться
  обновлением обоих наборов документов.
- Использовать `incident_log.sh` для публикации отчётов о ретроспективах и результатах баг-баунти.

## Навигация
- Контрактные детали: [lottery_multi.md](lottery_multi.md)
- Архитектура: [../architecture/overview.md](../architecture/overview.md)
- План этапов: [../../architecture/lottery_parallel_plan.md](../../architecture/lottery_parallel_plan.md)
- Операции: [../operations/runbooks.md](../operations/runbooks.md), [../operations/monitoring.md](../operations/monitoring.md),
  [../operations/status_page.md](../operations/status_page.md), [../operations/post_release_support.md](../operations/post_release_support.md), [../operations/postmortems.md](../operations/postmortems.md)
- Инструменты CLI: `supra/scripts/history_backfill.sh`, `supra/scripts/dual_write_control.sh`, `supra/scripts/incident_log.sh`, `supra/scripts/refund_control.sh`
