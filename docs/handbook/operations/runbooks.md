# Операционные процедуры

## Администратор (Root/Operational)
1. Проверить статус VRF-депозита через `views::get_vrf_deposit_status` (или Supra CLI) и при необходимости зафиксировать снапшот функцией `vrf_deposit::record_snapshot_admin`.
2. Получить конфигурацию черновика `views::get_lottery` / `get_lottery_status`, убедиться, что статус `Draft` и `snapshot_frozen = false`.
3. Создать лотерею в состоянии `Draft` и заполнить конфигурацию, указав `primary_type`, `tags_mask`, распределение продаж (`economics::assert_distribution`).
4. Запустить `views::validate_config` и убедиться в отсутствии ошибок.
5. Перевести лотерею в `Active`, открыть продажи.
6. Мониторить продажи через `views::list_active`, `views::accounting_snapshot` и события `TicketPurchaseEvent`; при срабатывании `PurchaseRateLimitHit` оценить DoS-активность.
7. По окончании `sales_end` вызвать `draw::request_draw_admin` (перед этим `vrf_deposit::ensure_requests_allowed`).
8. Дождаться события `VrfFulfilled` и выполнить батчи `payouts::compute_winners_admin` → `payouts::record_payout_batch_admin` → `payouts::finalize_lottery_admin`.
9. Проверить, что `history::get_summary` возвращает запись и dual-write прошёл без ошибок.

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
1. Настроить `legacy_bridge::init_dual_write` и список ожидаемых хэшей `legacy_bridge::set_expected_hash`.
2. Перед запуском бэкапа убедиться, что флаг включён (`legacy_bridge::is_enabled`).
3. После финализации каждой лотереи сравнить хэши старого и нового архива. При `E_HISTORY_MISMATCH`/`E_HISTORY_EXPECTED_MISSING` активировать паузу и восстановить синхронизацию.

## Мониторинг VRF-депозита
- Регулярно выполнять `vrf_deposit::record_snapshot_automation` через бота (при наличии capability).
- При `requests_paused = true` пополнять депозит и вызывать `vrf_deposit::resume_requests`.
- События `VrfDepositAlert` и `VrfRequestsPaused` должны попадать в журнал эксплуатации.

## Экстренный рефанд
- Активировать `emergency_stop`.
- Запустить `payouts::force_refund_batch` (при наличии) или скрипт рефанда из CLI.
- Снять флаг после завершения и опубликовать отчёт в разделе поддержки.

Дополнительные процедуры см. в [support/sla.md](../support/sla.md), [vrf_deposit.md](vrf_deposit.md) и runbook Supra CLI.
