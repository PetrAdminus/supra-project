# Операционные процедуры

## Администратор (Root/Operational)
1. Проверить статус VRF-депозита через `views::get_vrf_deposit_status` (или Supra CLI) и при необходимости зафиксировать снапшот функцией `vrf_deposit::record_snapshot_admin`.
2. Получить конфигурацию черновика `views::get_lottery` / `get_lottery_status`, убедиться, что статус `Draft` и `snapshot_frozen = false`.
3. Создать лотерею в состоянии `Draft` и заполнить конфигурацию, указав `primary_type`, `tags_mask`, распределение продаж (`economics::assert_distribution`).
4. Запустить `views::validate_config` и убедиться в отсутствии ошибок.
5. Перевести лотерею в `Active`, открыть продажи.
6. Мониторить продажи через `views::list_active`, `views::accounting_snapshot` и события `TicketPurchaseEvent`; при срабатывании `PurchaseRateLimitHit` оценить DoS-активность.
7. По окончании `sales_end` вызвать `draw::request_draw_admin` (перед этим `vrf_deposit::ensure_requests_allowed`).
8. Дождаться события `VrfFulfilled` и выполнить батчи `payouts::compute_winners_admin` → `payouts::record_payout_batch_admin`, предварительно проверив в `roles::PayoutBatchCap` остаток операций (`roles::consume_payout_batch` выбрасывает `E_PAYOUT_BATCH_TOO_LARGE`/`E_PAYOUT_OPERATIONS_BUDGET`/`E_PAYOUT_BATCH_COOLDOWN`/`E_PAYOUT_BATCH_NONCE`). После успешного батча контролировать через `sales::accounting_snapshot`, что `total_prize_paid` и `total_operations_paid` не превышают резерв `total_allocated`, затем вызвать `payouts::finalize_lottery_admin` по завершении цикла.
9. При партнёрских выплатах вызвать `payouts::record_partner_payout_admin`, предварительно сверив остаток `PartnerPayoutCap` (`roles::consume_partner_payout` защищает от перерасхода и нарушений cooldown/nonce, выбрасывая `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`/`E_PARTNER_PAYOUT_COOLDOWN`/`E_PARTNER_PAYOUT_NONCE`) и остаток операций по `sales::accounting_snapshot`, затем зафиксировать событие `PartnerPayoutEvent`.
10. Проверить, что `history::get_summary` возвращает запись и dual-write прошёл без ошибок.

## Партнёр
1. Открыть партнёрскую панель фронтенда и выбрать доступный шаблон.
2. Убедиться, что `primary_type`/`tags_mask` входят в разрешённые списки capability.
3. Перед созданием запустить `views::validate_config`; попытки установить запрещённые теги приведут к `abort`.
4. Подписать транзакцию создания, проверив лимиты бюджета и cooldown выплат.
5. Контролировать `PartnerVault` и своевременно пополнять награды.

## AutomationBot
- Выполняет dry-run через `automation::dry_run` и публикует digest в событии.
- Проверяет таймлоки перед `execute`.
- При ошибке повышает счётчик `reputation_score` и отправляет событие `AutomationError`.

## Dual-write миграция
1. Запустить `./supra/scripts/dual_write_control.sh init <abort_on_mismatch> <abort_on_missing>` (или `update-flags`) в выбранном окружении (`--backend local|docker|podman`, `--profile/--config` при необходимости) и включить зеркальную запись командой `enable-mirror`. Скрипт автоматически определяет Supra CLI или контейнер и публикует `ArchiveDualWriteStarted` при установке ожиданий.
2. Для каждой лотереи добавить эталонный хэш: `./supra/scripts/dual_write_control.sh set <lottery_id> <hash_hex>`; контролировать результаты через `dual_write_control.sh status <lottery_id>` (возвращает `DualWriteStatus`) и события `ArchiveDualWriteStarted`. Для проверки глобальных переключателей запускать `dual_write_control.sh flags` (делает `view` к `legacy_bridge::dual_write_flags`). При необходимости выключить зеркало (`disable-mirror`) перед обслуживанием.
3. После финализации лотереи убедиться, что `history::record_summary` сработал: событие `ArchiveDualWriteCompleted`, запись `LegacySummaryEvent` и статус `expected_hash = None`. При расхождении запустить `dual_write_control.sh mirror <lottery_id>`, повторно установить ожидание (`set`) и инициировать обновление сводки; журнал `history_bridge::get_summary` использовать для сверки BCS.

## Мониторинг VRF-депозита
- Регулярно выполнять `vrf_deposit::record_snapshot_automation` через бота (при наличии capability).
- При `requests_paused = true` пополнять депозит и вызывать `vrf_deposit::resume_requests`.
- События `VrfDepositAlert` и `VrfRequestsPaused` должны попадать в журнал эксплуатации.

## Экстренный рефанд
- Активировать `emergency_stop`.
- Запустить `payouts::force_refund_batch` (при наличии) или скрипт рефанда из CLI.
- Снять флаг после завершения и опубликовать отчёт в разделе поддержки.

Дополнительные процедуры см. в [support/sla.md](../support/sla.md), [vrf_deposit.md](vrf_deposit.md) и runbook Supra CLI.
