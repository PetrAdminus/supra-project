# Операционные процедуры

> Дополнительные документы: [чек-лист релиза](release_checklist.md), [мониторинг](monitoring.md), [журнал операций](incident_log.md), [программа баг-баунти](bug_bounty.md).

## Администратор (Root/Operational)
1. Проверить статус VRF-депозита через `views::get_vrf_deposit_status` (или Supra CLI) и при необходимости зафиксировать снапшот функцией `vrf_deposit::record_snapshot_admin`; результат зафиксировать в [журнале операций](incident_log.md).
2. Получить конфигурацию черновика `views::get_lottery` / `get_lottery_status`, убедиться, что статус `Draft` и `snapshot_frozen = false`.
3. Создать лотерею в состоянии `Draft` и заполнить конфигурацию, указав `primary_type`, `tags_mask`, распределение продаж (`economics::assert_distribution`).
4. Запустить `views::validate_config` и убедиться в отсутствии ошибок.
5. Перевести лотерею в `Active`, открыть продажи.
6. Мониторить продажи через `views::list_active`, `views::accounting_snapshot` и события `TicketPurchaseEvent`; при срабатывании `PurchaseRateLimitHit` оценить DoS-активность.
7. По окончании `sales_end` вызвать `draw::request_draw_admin` (перед этим `vrf_deposit::ensure_requests_allowed`).
8. Дождаться события `VrfFulfilled` и выполнить батчи `payouts::compute_winners_admin` → `payouts::record_payout_batch_admin`, предварительно проверив через `roles::borrow_payout_batch_cap`/`roles::has_payout_batch_cap` остаток операций (`roles::consume_payout_batch` выбрасывает `E_PAYOUT_BATCH_TOO_LARGE`/`E_PAYOUT_OPERATIONS_BUDGET`/`E_PAYOUT_BATCH_COOLDOWN`/`E_PAYOUT_BATCH_NONCE`). После успешного батча контролировать через `sales::accounting_snapshot`, что `total_prize_paid` и `total_operations_paid` не превышают резерв `total_allocated`, затем вызвать `payouts::finalize_lottery_admin` по завершении цикла; сверить метрики с [monitoring.md](monitoring.md) и при отклонениях задокументировать в [incident_log.md](incident_log.md).
9. При партнёрских выплатах вызвать `payouts::record_partner_payout_admin`, предварительно сверив остаток `PartnerPayoutCap` через `roles::list_partner_caps`/`roles::has_partner_payout_cap` (`roles::consume_partner_payout` защищает от перерасхода, нарушений cooldown/nonce и expiry, выбрасывая `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`/`E_PARTNER_PAYOUT_COOLDOWN`/`E_PARTNER_PAYOUT_NONCE`/`E_PARTNER_PAYOUT_EXPIRED`) и остаток операций по `sales::accounting_snapshot`, затем зафиксировать событие `PartnerPayoutEvent`.
10. После завершения партнёрских выплат проверить `roles::list_premium_caps` для премиальных подписок (актуален показатель `expires_at` и `referrer`), при необходимости вызвать `roles::cleanup_expired_admin <now>` и убедиться в публикации `PartnerPayoutCapRevokedEvent`/`PremiumAccessRevokedEvent`; результаты занести в [incident_log.md](incident_log.md).
11. Проверить, что `history::get_summary` возвращает запись и dual-write прошёл без ошибок.

## Прайс-фид
1. Мониторить `price_feed::get_price_view(asset_id)` и метрики `price_feed_updates_total`, `price_feed_clamp_active`, `price_feed_fallback_active` (см. [monitoring.md](monitoring.md)).
2. При резком скачке цены вызвать `price_feed::set_fallback(<cap>, asset_id, true, reason)` и зафиксировать событие `PriceFeedFallbackEvent` в [incident_log.md](incident_log.md).
3. После подтверждения поставщика цены выполнить `price_feed::clear_clamp(<cap>, asset_id, cleared_ts)` — событие `PriceFeedClampClearedEvent` фиксирует ручное решение.
4. Опубликовать новую котировку через `price_feed::update_price(<cap>, asset_id, price, updated_ts)`, убедившись, что изменение укладывается в `clamp_threshold_bps`; при успешном обновлении fallback сбрасывается автоматически.
5. В release checklist добавить ссылку на событие `PriceFeedClampClearedEvent` и обновлённый `last_updated_ts` для каждого активного `asset_id`.

## Партнёр
1. Открыть партнёрскую панель фронтенда и выбрать доступный шаблон.
2. Убедиться, что `primary_type`/`tags_mask` входят в разрешённые списки capability.
3. Перед созданием запустить `views::validate_config`; попытки установить запрещённые теги приведут к `abort`.
4. Подписать транзакцию создания, проверив лимиты бюджета и cooldown выплат.
5. Контролировать `PartnerVault` и своевременно пополнять награды.

## AutomationBot
- Выполняет dry-run через `automation::announce_dry_run`, публикуя digest в событии `AutomationDryRunPlanned`; повторный вызов с другим digest до завершения будет отклонён (`E_AUTOBOT_PENDING_EXISTS`).
- Проверяет таймлоки перед `execute`: при `timelock_secs > 0` требуется дождаться `pending_execute_after`, иначе `record_success`/`record_failure` завершатся `E_AUTOBOT_TIMELOCK`. После успешного dry-run внести запись в [incident_log.md](incident_log.md).
- Перед фактическим вызовом on-chain действия выполняет `automation::ensure_action` для контроля лимитов `max_failures` и срока действия капабилити; после достижения порога функция завершается с `E_AUTOBOT_FAILURE_LIMIT`.
- При ошибке вызывает `automation::record_failure`, что публикует `AutomationTick` и `AutomationError`, увеличивает `failure_count` и очищает pending; при успехе `record_success` сбрасывает `failure_count` и позволяет публиковать новый dry-run. Метрики доступны в [monitoring.md](monitoring.md).
- Операторы обязаны мониторить `failure_count` и при необходимости вращать ключ или повышать `max_failures` через `rotate_bot`; любые изменения cron-спека автоматически сбрасывают pending и digest предыдущей попытки.

## Dual-write миграция
1. Запустить `./supra/scripts/dual_write_control.sh init <abort_on_mismatch> <abort_on_missing>` (или `update-flags`) в выбранном окружении (`--backend local|docker|podman`, `--profile/--config` при необходимости) и включить зеркальную запись командой `enable-mirror`. Скрипт автоматически определяет Supra CLI или контейнер и публикует `ArchiveDualWriteStarted` при установке ожиданий.
2. Для каждой лотереи добавить эталонный хэш: `./supra/scripts/dual_write_control.sh set <lottery_id> <hash_hex>`; контролировать результаты через `dual_write_control.sh status <lottery_id>` (возвращает `DualWriteStatus`) и события `ArchiveDualWriteStarted`. Для сводного контроля используйте `dual_write_control.sh pending`, чтобы получить список всех лотерей с активным ожиданием хэша, а для проверки глобальных переключателей — `dual_write_control.sh flags` (делает `view` к `legacy_bridge::dual_write_flags`). При необходимости выключить зеркало (`disable-mirror`) перед обслуживанием.
3. После финализации лотереи убедиться, что `history::record_summary` сработал: событие `ArchiveDualWriteCompleted`, запись `LegacySummaryEvent` и статус `expected_hash = None`. При расхождении запустить `dual_write_control.sh mirror <lottery_id>`, повторно установить ожидание (`set`) и инициировать обновление сводки; журнал `history_bridge::get_summary` использовать для сверки BCS.
4. Для импортированных розыгрышей используйте `./supra/scripts/history_backfill.sh`:
   - `import <lottery_id> 0x<summary_bcs_hex> 0x<sha3_hash>` — переносит BCS-сводку в `ArchiveLedger`, публикует `LegacySummaryImportedEvent` и автоматически зеркалирует данные в `lottery_support::history_bridge`.
   - `rollback <lottery_id>` — удаляет импортированную сводку и фиксирует `LegacySummaryRolledBackEvent` (применимо только к записям, отмеченным как legacy).
   - `classify <lottery_id> <primary_type> <tags_mask>` — обновляет классификаторы и эмитирует `LegacySummaryClassificationUpdatedEvent`; после команды необходимо синхронизировать фронтенд бейджей.
   - `status <lottery_id>`/`list [from] [limit]` — проверка флага legacy и итогового списка `history::list_finalized`.

## Мониторинг VRF-депозита
- Регулярно выполнять `vrf_deposit::record_snapshot_automation` через бота (при наличии capability).
- При `requests_paused = true` пополнять депозит и вызывать `vrf_deposit::resume_requests`.
- События `VrfDepositAlert` и `VrfRequestsPaused` должны попадать в журнал эксплуатации.

## Экстренный рефанд
- Активировать `emergency_stop`.
- Запустить `payouts::force_refund_batch` (при наличии) или скрипт рефанда из CLI.
- Снять флаг после завершения и опубликовать отчёт в разделе поддержки.

Дополнительные процедуры см. в [support/sla.md](../support/sla.md), [vrf_deposit.md](vrf_deposit.md) и runbook Supra CLI.
