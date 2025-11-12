# Операционные процедуры

> Дополнительные документы: [чек-лист релиза](release_checklist.md), [мониторинг](monitoring.md), [журнал операций](incident_log.md), [программа баг-баунти](bug_bounty.md), [процедура рефанда](refund.md), [пострелизная поддержка](post_release_support.md), [шаблон постмортема](postmortems.md), [Supra CLI и Move-тесты](supra_cli.md).
> Для фиксации событий используйте `supra/scripts/incident_log.sh`, который автоматически добавляет записи в журнал.

## Мультисиг и утверждения ролей
- Все операции, связанные с выдачей/отзывом capability, выполняются через согласованные мультисиг-кошельки (`RootAdmin`, `OperationalAdmin`). Перед подписью транзакции необходимо создать задачу в ticketing-системе и приложить ссылку на запись в [incident_log.md](incident_log.md).
- Для действий, требующих двойного контроля (отмена тиража, выплаты, unpause), фиксируйте подтверждения обоих операторов мультисиг-пула и указывайте `tx_hash` в журнале. При несовпадении участников обновите матрицу в [governance/roles.md](../governance/roles.md).

## Администратор (Root/Operational)
1. Проверить статус VRF-депозита через `views::get_vrf_deposit_status` (или Supra CLI) и при необходимости зафиксировать снапшот функцией `vrf_deposit::record_snapshot_admin`; результат занести в [журнале операций](incident_log.md) через `supra/scripts/incident_log.sh --type "VRF-пополнение" ...`.
2. Получить конфигурацию черновика `views::get_lottery` / `get_lottery_status`, убедиться, что статус `Draft` и `snapshot_frozen = false`.
3. Создать лотерею в состоянии `Draft` и заполнить конфигурацию, указав `primary_type`, `tags_mask`, распределение продаж (`economics::assert_distribution`). Перед сохранением свериться с [политикой тегов](../contracts/tags_policy.md), чтобы избежать запрещённых комбинаций и соблюсти таймлоки партнёрских whitelists.
4. Запустить `views::validate_config` и убедиться в отсутствии ошибок.
5. Перевести лотерею в `Active`, открыть продажи.
6. Мониторить продажи через `views::list_active`, `views::accounting_snapshot` и события `TicketPurchaseEvent`; при срабатывании `PurchaseRateLimitHit` оценить DoS-активность. Для сверки агрегатов используйте `./supra/scripts/accounting_check.sh [--dry-run] <config> snapshot|compare <lottery_id>` — команда `compare` выводит JSON-отчёт о совпадении `total_*` между учётом продаж и `LotterySummary`.
7. По окончании `sales_end` вызвать `draw::request_draw_admin` (перед этим `vrf_deposit::ensure_requests_allowed`).
   - Повторный вызов после каждой неудачной попытки увеличивает счётчик `attempt`; при достижении `MAX_VRF_ATTEMPTS = 5` функция автоматически отменяет тираж (`STATUS_CANCELED`, `CANCEL_REASON_VRF_FAILURE`) и включает рефанд, поэтому на 6-й попытке AutomationBot должен зафиксировать инцидент и перейти к runbook рефанда.
8. Дождаться события `VrfFulfilled` и выполнить батчи `payouts::compute_winners_admin` → `payouts::record_payout_batch_admin`, предварительно проверив через `roles::borrow_payout_batch_cap`/`roles::has_payout_batch_cap` остаток операций (`roles::consume_payout_batch` выбрасывает `E_PAYOUT_BATCH_TOO_LARGE`/`E_PAYOUT_OPERATIONS_BUDGET`/`E_PAYOUT_BATCH_COOLDOWN`/`E_PAYOUT_BATCH_NONCE`). После успешного батча контролировать через `sales::accounting_snapshot`, что `total_prize_paid` и `total_operations_paid` не превышают резерв `total_allocated`; при необходимости выполните `./supra/scripts/accounting_check.sh <config> compare <lottery_id>` для автоматического отчёта по совпадению `total_allocated`/`total_prize_paid`/`total_operations_paid`, затем вызвать `payouts::finalize_lottery_admin` по завершении цикла. Сверяйте метрики с [monitoring.md](monitoring.md) и при отклонениях документируйте в [incident_log.md](incident_log.md) (рекомендуемый формат записи — `supra/scripts/incident_log.sh --type "Инцидент"|"Dry-run" ...`). Перед релизом убедитесь, что `aptos` CLI доступен (`./supra/scripts/run_move_tests.sh --help`) и финальные батчи покрыты `aptos move test` (см. [supra_cli.md](supra_cli.md)).
9. При необходимости отмены вызвать `registry::cancel_lottery_admin(lottery_id, reason_code, now_ts)`, проверить `views::get_cancellation` и зафиксировать решение в [журнале](incident_log.md) (`supra/scripts/incident_log.sh --type "Cancellation" ...`). Скрипт `./supra/scripts/refund_control.sh` поддерживает флаг `--dry-run` — используйте его для предварительной проверки команд (`cancel`, `batch`, `archive`) в средах без Supra CLI. После завершения on-chain рефандов обязательно вызвать `payouts::archive_canceled_lottery_admin(lottery_id, finalized_ts)`, чтобы зафиксировать `LotterySummary` со статусом `STATUS_CANCELED`. Справочник причин и чек-лист возвратов см. в [refund.md](refund.md); отказ с пустым кодом приводит к `E_CANCEL_REASON_INVALID`.
10. При партнёрских выплатах вызвать `payouts::record_partner_payout_admin`, предварительно сверив остаток `PartnerPayoutCap` через `roles::list_partner_caps`/`roles::has_partner_payout_cap` (`roles::consume_partner_payout` защищает от перерасхода, нарушений cooldown/nonce и expiry, выбрасывая `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`/`E_PARTNER_PAYOUT_COOLDOWN`/`E_PARTNER_PAYOUT_NONCE`/`E_PARTNER_PAYOUT_EXPIRED`) и остаток операций по `sales::accounting_snapshot`, затем зафиксировать событие `PartnerPayoutEvent`.
11. После завершения партнёрских выплат проверить `roles::list_premium_caps` для премиальных подписок (актуален показатель `expires_at` и `referrer`), при необходимости вызвать `roles::cleanup_expired_admin <now>` и убедиться в публикации `PartnerPayoutCapRevokedEvent`/`PremiumAccessRevokedEvent`; результаты занести в [журнал](incident_log.md) через `supra/scripts/incident_log.sh`.
12. Проверить, что `history::get_summary` возвращает запись и dual-write прошёл без ошибок (для отменённых тиражей — после `payouts::archive_canceled_lottery_admin`).
13. Снять агрегированную сводку `views::status_overview(now_ts)` и обновить [статусную страницу](status_page.md); при наличии `vrf_retry_blocked` или `payout_backlog` зафиксировать инцидент и следовать порогам из [monitoring.md](monitoring.md).

## Прайс-фид
1. Мониторить `price_feed::get_price_view(asset_id)` и метрики `price_feed_updates_total`, `price_feed_clamp_active`, `price_feed_fallback_active` (см. [monitoring.md](monitoring.md)).
2. При резком скачке цены вызвать `price_feed::set_fallback(<cap>, asset_id, true, reason)` и зафиксировать событие `PriceFeedFallbackEvent` в [incident_log.md](incident_log.md).
3. После подтверждения поставщика цены выполнить `price_feed::clear_clamp(<cap>, asset_id, cleared_ts)` — событие `PriceFeedClampClearedEvent` фиксирует ручное решение; добавьте запись в журнал (`supra/scripts/incident_log.sh --type "Инцидент" ...`).
4. Опубликовать новую котировку через `price_feed::update_price(<cap>, asset_id, price, updated_ts)`, убедившись, что изменение укладывается в `clamp_threshold_bps`; при успешном обновлении fallback сбрасывается автоматически.
5. В release checklist добавить ссылку на событие `PriceFeedClampClearedEvent` и обновлённый `last_updated_ts` для каждого активного `asset_id`.

## Партнёр
1. Открыть партнёрскую панель фронтенда и выбрать доступный шаблон.
2. Убедиться, что `primary_type`/`tags_mask` входят в разрешённые списки capability и соответствуют [политике тегов](../contracts/tags_policy.md#2-допустимые-комбинации-тегов).
3. Перед созданием запустить `views::validate_config`; попытки установить запрещённые теги приведут к `abort`.
4. Подписать транзакцию создания, проверив лимиты бюджета и cooldown выплат.
5. Контролировать `PartnerVault` и своевременно пополнять награды.

## AutomationBot
- Выполняет dry-run через `automation::announce_dry_run`, публикуя digest в событии `AutomationDryRunPlanned`; повторный вызов с другим digest до завершения будет отклонён (`E_AUTOBOT_PENDING_EXISTS`).
- Проверяет таймлоки перед `execute`: при `timelock_secs > 0` требуется дождаться `pending_execute_after`, иначе `record_success`/`record_failure` завершатся `E_AUTOBOT_TIMELOCK`. После успешного dry-run внести запись в [incident_log.md](incident_log.md).
- Для действий `ACTION_UNPAUSE`, `ACTION_PAYOUT_BATCH`, `ACTION_CANCEL` таймлок не может быть меньше 900 секунд (15 минут); требование зафиксировано Move-тестами `automation_tests::register_enforces_sensitive_timelock` и `automation_tests::rotate_enforces_sensitive_timelock` и проверяется в CI.
- Перед фактическим вызовом on-chain действия выполняет `automation::ensure_action` для контроля лимитов `max_failures` и срока действия капабилити; после достижения порога функция завершается с `E_AUTOBOT_FAILURE_LIMIT`.
- При ошибке вызывает `automation::record_failure`, что публикует `AutomationTick` и `AutomationError`, увеличивает `failure_count` и очищает pending; при успехе `record_success` сбрасывает `failure_count` и позволяет публиковать новый dry-run. Метрики доступны в [monitoring.md](monitoring.md).
- Операторы обязаны мониторить `failure_count` и при необходимости вращать ключ или повышать `max_failures` через `rotate_bot`; любые изменения cron-спека автоматически сбрасывают pending и digest предыдущей попытки.
- Для контроля pending-действий и таймлоков используйте публичные view `views::list_automation_bots`/`views::get_automation_bot` (см. [architecture/json/lottery_multi_views.schema.json](../architecture/json/lottery_multi_views.schema.json)); данные отображаются также на статусной странице. Для оперативного доступа и журналирования снимков используйте CLI `./supra/scripts/automation_status.sh <config> list|get`, который проксирует соответствующие view через Supra CLI.
- Сценарий VRF-снапшота: подготовить `snapshot_hash = sha3-256(bcs::to_bytes(total, minimum, effective, timestamp))`, выполнить dry-run с `ACTION_TOPUP_VRF_DEPOSIT`, дождаться `pending_execute_after` и затем вызвать `vrf_deposit::record_snapshot_automation(..., snapshot_hash)` — функция сама вызывает `automation::record_success` и очищает pending.

## Dual-write миграция
1. Запустить `./supra/scripts/dual_write_control.sh init <abort_on_mismatch> <abort_on_missing>` (или `update-flags`) в выбранном окружении (`--backend local|docker|podman`, `--profile/--config` при необходимости) и включить зеркальную запись командой `enable-mirror`. Скрипт автоматически определяет Supra CLI или контейнер и публикует `ArchiveDualWriteStarted` при установке ожиданий.
2. Для каждой лотереи добавить эталонный хэш: `./supra/scripts/dual_write_control.sh set <lottery_id> <hash_hex>`; контролировать результаты через `dual_write_control.sh status <lottery_id>` (возвращает `DualWriteStatus`) и события `ArchiveDualWriteStarted`. Для сводного контроля используйте `dual_write_control.sh pending`, чтобы получить список всех лотерей с активным ожиданием хэша, а для проверки глобальных переключателей — `dual_write_control.sh flags` (делает `view` к `legacy_bridge::dual_write_flags`). При необходимости выключить зеркало (`disable-mirror`) перед обслуживанием.
3. После финализации лотереи убедиться, что `history::record_summary` (для отменённых — `payouts::archive_canceled_lottery_admin`) сработал: событие `ArchiveDualWriteCompleted`, запись `LegacySummaryEvent` и статус `expected_hash = None`. При расхождении запустить `dual_write_control.sh mirror <lottery_id>`, повторно установить ожидание (`set`) и инициировать обновление сводки; журнал `history_bridge::get_summary` использовать для сверки BCS.
4. Для импортированных розыгрышей используйте `./supra/scripts/history_backfill.sh`:
   - `dry-run <summary_path> [--lottery-id <id>] [--hex-output path] [--hash-output path] [--json] [--json-output path] [--quiet]` — рассчитывает sha3-256 хэш файла BCS (поддерживаются бинарные и hex-представления), формирует готовую команду `import` и может отдать JSON-структуру для внешних пайплайнов; опции `--json --quiet` печатают только JSON, `--json-output` сохраняет файл для артефактов CI.
   - JSON вывод содержит `summary_hex`, `expected_hash`, `size_bytes`, `suggested_command` и абсолютный путь к сводке; сохраняйте файл и прикладывайте его к записи в журнал через `supra/scripts/incident_log.sh --type "Backfill" ...`.
   - После импорта запускайте `dual_write_control.sh status <lottery_id>` и прикладывайте вывод к той же записи журнала, чтобы зафиксировать очистку ожиданий dual-write.
   - `import <lottery_id> 0x<summary_bcs_hex> 0x<sha3_hash>` — переносит BCS-сводку в `ArchiveLedger`, публикует `LegacySummaryImportedEvent` и автоматически зеркалирует данные в `lottery_support::history_bridge`.
   - `rollback <lottery_id>` — удаляет импортированную сводку и фиксирует `LegacySummaryRolledBackEvent` (применимо только к записям, отмеченным как legacy).
   - `classify <lottery_id> <primary_type> <tags_mask>` — обновляет классификаторы и эмитирует `LegacySummaryClassificationUpdatedEvent`; после команды необходимо синхронизировать фронтенд бейджей.
   - `status <lottery_id>`/`list [from] [limit]` — проверка флага legacy и итогового списка `history::list_finalized`.

## Мониторинг VRF-депозита
- Регулярно выполнять dry-run и `vrf_deposit::record_snapshot_automation` через бота (используя согласованный `snapshot_hash`).
- При `requests_paused = true` пополнять депозит и вызывать `vrf_deposit::resume_requests`.
- События `VrfDepositAlert` и `VrfRequestsPaused` должны попадать в журнал эксплуатации.

## Экстренный рефанд
- Перед началом выполните `./supra/scripts/refund_control.sh --dry-run <config> status <lottery_id>`, чтобы убедиться в корректности аргументов и подготовленных команд. Dry-run выводит предполагаемый вызов Supra CLI и позволяет проверить пайплайн без доступа к бинарю.
- Активировать `emergency_stop`.
- Использовать `./supra/scripts/refund_control.sh [--dry-run] <config> cancel <lottery_id> <reason_code> <timestamp>` для перевода статуса и фиксации `CancellationRecord`.
- Запускать батчи возвратов через `./supra/scripts/refund_control.sh [--dry-run] <config> batch <lottery_id> <round> <tickets> <prize_refund> <operations_refund> <timestamp>`.
- После каждого батча проверить `./supra/scripts/refund_control.sh <config> cancellation <lottery_id>` и `./supra/scripts/refund_control.sh <config> progress <lottery_id>` (агрегаты возврата), результаты занести в журнал.
- По завершении вызвать `./supra/scripts/refund_control.sh [--dry-run] <config> archive <lottery_id> <finalized_ts>` и убедиться, что `summary` содержит статус `STATUS_CANCELED`.
- Снять флаг после завершения и опубликовать отчёт в разделе поддержки.

Дополнительные процедуры см. в [support/sla.md](../support/sla.md), [vrf_deposit.md](vrf_deposit.md), [post_release_support.md](post_release_support.md) и runbook Supra CLI. Отчёты по инцидентам и ретроспективам ведутся согласно [postmortems.md](postmortems.md).
