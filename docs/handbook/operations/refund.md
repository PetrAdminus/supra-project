# Рефанды и отмены лотерей

> Документ описывает порядок действий при переводе лотереи `lottery_multi` в статус `STATUS_CANCELED` и возврате средств
> игрокам. Используйте его совместно с [runbooks.md](runbooks.md), [monitoring.md](monitoring.md) и [incident_log.md](incident_log.md).

## Когда запускать процедуру
- **Сбой VRF или расчёта победителей.** Колбэк не приходит в пределах `MAX_VRF_ATTEMPTS`, `draw::retry_strategy` достигла лимита,
  инварианты `snapshot_hash`/`checksum_after_batch` нарушены.
- **Регуляторные и юридические ограничения.** Compliance-команда фиксирует нарушение условий участия, требующее остановки розыгрыша.
- **Системные инциденты.** Утрата доступа к премиум-фиду, критический баг фронтенда, массовый DoS в продажах.

RootAdmin принимает решение о переводе статуса и фиксирует событие в `incident_log.md` (тип `"Cancellation"`).
Практическая работа выполняется через CLI `supra/scripts/refund_control.sh`, который оборачивает
он-чейн вызовы и предоставляет команды `cancel`, `batch`, `progress`, `cancellation`, `status`, `summary`, `archive`.

Справочник причин отмены:
- `CANCEL_REASON_VRF_FAILURE (1)` — исчерпаны попытки VRF или нарушены инварианты `snapshot_hash`.
- `CANCEL_REASON_COMPLIANCE (2)` — требования регуляторов, юридические ограничения или блокировка в партнёрском регионе.
- `CANCEL_REASON_OPERATIONS (3)` — технические инциденты (DoS-продаж, сбой прайс-фида, аварийное обновление фронтенда).


## Подготовка
1. Проверить `views::get_lottery_status(lottery_id)` — статус должен быть `STATUS_ACTIVE`, `STATUS_CLOSING`, `STATUS_DRAW_REQUESTED`
   или `STATUS_DRAWN`. Отмена после `STATUS_PAYOUT` требует ручной оценки выплаченных сумм.
2. Убедиться, что `sales::accounting_snapshot(lottery_id)` содержит актуальные агрегаты (`total_sales`, `total_allocated`,
   `total_prize_paid`, `total_operations_paid`) и записать текущее значение `views::get_cancellation(lottery_id)` (ожидаем `None`).
3. Снять показания мониторинга: `status_overview(now_ts)`, метрики `payout_backlog`, `vrf_retry_blocked`, `purchase_rate_limit_hits`,
   а также зафиксировать базовый `views::get_refund_progress(lottery_id)` (ожидаем `active = false`).
4. Оповестить поддержку: создать черновик обращения по SLA (см. [support/sla.md](../support/sla.md)).

## Основная процедура
1. **Заморозка автоматизации.** Выполнить `automation::announce_dry_run` с планом отмены и дождаться таймлока; при необходимости
   отключить бота через `automation::ensure_action` и `rotate_bot`.
2. **Перевод статуса.** Вызвать `registry::cancel_lottery_admin(lottery_id, reason_code, now_ts)`.
   - Функция публикует `LotteryCanceledEvent` (категория `EVENT_CATEGORY_REFUND`), сохраняет `CancellationRecord` и автоматически замораживает снапшот. Зафиксируйте `reason_code` и `now_ts` в журнале (см. список `CANCEL_REASON_*`).
   - Рекомендуемый CLI: `./supra/scripts/refund_control.sh <config> cancel <lottery_id> <reason_code> <timestamp>`.
   - После транзакции проверьте `views::get_cancellation(lottery_id)` — запись должна содержать `previous_status`, `reason_code`, `tickets_sold`, `proceeds_accум` и `canceled_ts`. Быстрая проверка: `./supra/scripts/refund_control.sh <config> cancellation <lottery_id>`.
3. **Формирование реестра возвратов.**
   - Если лотерея была на этапе продаж (`STATUS_ACTIVE`/`STATUS_CLOSING`), сформируйте список билетов через
     `sales::ticket_chunks(lottery_id)` (CLI `supra/scripts/build_lottery_packages.sh` поддерживает экспорт).
   - Если победители уже вычислены (`STATUS_DRAWN`), снимите `payouts::winner_progress_view(lottery_id)` для оценки объёма возврата.
4. **Запуск батчей рефанда.**
   - Вызывайте `payouts::force_refund_batch_admin` с капабилити `PayoutBatchCap`, последовательно увеличивая `refund_round` (начиная
     с 1). Параметры `tickets_refunded`, `prize_refund` и `operations_refund` должны отражать фактический объём возврата. После
     каждого вызова функция обновляет агрегаты `views::get_refund_progress(lottery_id)` и публикует событие `RefundBatchEvent` (категория
     `EVENT_CATEGORY_REFUND`).
   - Рекомендуемый CLI: `./supra/scripts/refund_control.sh <config> batch <lottery_id> <round> <tickets> <prize_refund> <operations_refund> <timestamp>`.
   - Если on-chain батч временно недоступен, оформляйте возвраты вручную: выгрузите CSV со списком адресов и сумм, передайте его
     казначейской команде, подпишите транзакции мультисигом и для каждой операции приложите tx hash к записи в журнале
     инцидентов.
5. **Контроль остатков.** После каждого батча проверяйте `sales::accounting_snapshot` и `views::get_refund_progress`: значения
   `total_prize_paid`/`total_operations_paid` не должны превышать `total_allocated`, а суммарные возвраты — `proceeds_accum`.
   Остаток резервов согласуйте с `TreasuryCustodian`. Быстрая проверка прогресса: `./supra/scripts/refund_control.sh <config> progress <lottery_id>`.
6. **Архивирование отмены.** После обработки всех билетов вызовите `payouts::archive_canceled_lottery_admin(lottery_id, finalized_ts)`;
   функция проверит наличие `CancellationRecord`, завершённость рефандов (`tickets_refunded`, `last_refund_ts`, сумма возврата)
   и запишет `LotterySummary` со статусом `STATUS_CANCELED`. Убедитесь, что транзакция опубликована в журнале. Команда CLI: `./supra/scripts/refund_control.sh <config> archive <lottery_id> <finalized_ts>`.
7. **Публикация статуса.** Обновите статусную страницу (`operations/status_page.md`) и фронтенд-баннер. Используйте
   `views::status_overview(now_ts)` для агрегированных данных (`canceled`, `refund_in_progress`).

## Завершение
1. Все билеты должны быть обработаны (`refund_remaining = 0`). Подтвердите в журнале, указав время завершения и общее количество
   транзакций. Для проверки используйте `./supra/scripts/refund_control.sh <config> progress <lottery_id>`.
2. Убедитесь, что `payouts::archive_canceled_lottery_admin` успешно записал сводку: проверьте `history::get_summary(lottery_id)`
   (статус `STATUS_CANCELED`, `payout_round = refund_round`) и при необходимости зеркалируйте запись через `legacy_bridge::mirror_summary_admin`.
   Быстрая проверка архива: `./supra/scripts/refund_control.sh <config> summary <lottery_id>`.
3. Обновите документацию: добавьте запись в `docs/architecture/lottery_multi_readiness_review.md` (раздел «Инциденты и уроки»)
   и `docs/architecture/rfc_v1_implementation_notes.md`.
4. Проведите ретроспективу: в течение 72 часов описать причины отмены, принятые решения и рекомендации в `docs/handbook/operations/incident_log.md`.

## SLA и коммуникации
| Этап | Срок | Ответственный |
| --- | --- | --- |
| Оповещение пользователей (push/email) | ≤ 30 минут после `LotteryCanceledEvent` | Support + Marketing |
| Первый батч рефанда | ≤ 12 часов | RootAdmin + Treasury |
| Полное завершение возвратов | ≤ 24 часов | Treasury |
| Постмортем в «книге проекта» | ≤ 72 часов | RootAdmin |

## Мониторинг и алерты
- `refund_batch_pending` — количество адресов в очереди. Алерт при росте > 1000.
- `refund_sla_breach` — автоматическая метрика, если дедлайн превышен.
- `automation_failure_count` — должен оставаться 0 во время отмены; при росте задокументировать причину.

## Связанные документы и тесты
- План этапов: [architecture/lottery_parallel_plan.md](../../architecture/lottery_parallel_plan.md) — разделы 4.P и 6.
- Юнит-тесты: `lottery_multi::payouts_tests::{refund_batch_records_progress, refund_requires_canceled_status, refund_cannot_exceed_tickets, archive_canceled_requires_record, archive_canceled_requires_full_refund, archive_canceled_records_summary}`, `SupraLottery/tests/test_history_backfill_dry_run.py`.
- Процедуры поддержки: [support/sla.md](../support/sla.md).
- Программа баг-баунти: [operations/bug_bounty.md](bug_bounty.md) — содержит правила компенсаций.

Документ обновляется по мере реализации on-chain батчей рефанда и интеграции с автоматикой.
