# Мониторинг lottery_multi

## 1. Общие принципы
- Все метрики попадают в Grafana-дэшборд `Lottery Multi Ops` (UID: lottery-multi-ops).
- Алёрты настраиваются через Alertmanager, ответственный канал — `#lottery-ops`.
- Источники: on-chain события (через индексатор), Supra CLI (`supra monitor`), Prometheus-экспортер AutomationBot.

## 2. Ключевые метрики
| Домены | Метрика | Описание | Порог |
|--------|---------|----------|-------|
| VRF | `vrf_effective_balance` | Текущий `effective_balance` из `views::get_vrf_deposit_status` | < `required_minimum` |
| VRF | `vrf_requests_paused` | Флаг приостановки запросов | `true` > 5 мин |
| Dual-write | `dual_write_mismatch` | Количество лотерей с `expected_hash` и `actual_hash` != | > 0 |
| Dual-write | `dual_write_pending` | Лотереи в статусе ожидания более 2 часов | > 0 |
| Status | `status_overview.vrf_retry_blocked` | Количество лотерей, заблокированных окном повторного VRF | > 0 дольше 60 мин |
| Status | `status_overview.payout_backlog` | Невыплаченные батчи (`payout_round < next_winner_batch_no`) | > 0 дольше 60 мин |
| Status | `status_overview.canceled` | Количество отменённых лотерей (в т.ч. авто-отмены после `MAX_VRF_ATTEMPTS`) | > 0 без активного плана рефанда |
| Платежи | `payout_round_gap` | `next_winner_batch_no - payout_round` | > 1 |
| Платежи | `operations_budget_remaining` | Остаток операций по `PayoutBatchCap` | < 10% |
| Automation | `automation_failure_count` | Счётчик провалов подряд | >= `max_failures` |
| Automation | `automation_pending_age` | Время с момента `AutomationDryRunPlanned` | > `timelock_secs + 15 мин` |
| Automation | `automation_timelock_breach` | Количество ботов с `ACTION_UNPAUSE`/`ACTION_PAYOUT_BATCH`/`ACTION_CANCEL` и таймлоком < 900 секунд | > 0 |
| Refund | `refund_active` | Количество отменённых лотерей с активным рефандом (по view `status_overview`) | > 0 без запущенной процедуры |
| Refund | `refund_batch_pending` | Количество оставшихся билетов к возврату (по view `status_overview`) | > 0 дольше 4 часов |
| Refund | `refund_progress.round` | Текущее значение `refund_round` из `views::get_refund_progress` | Не растёт > 60 мин при активном `refund_batch_pending` |
| Refund | `refund_progress.remaining` | `tickets_sold - tickets_refunded` из `views::get_refund_progress` | > 0 спустя 12 часов после отмены |
| Refund | `refund_progress.last_ts` | Метка `last_refund_ts` из `views::get_refund_progress` | Разница с `now()` > 120 мин при активном рефанде |
| Refund | `refund_sla_breach` | Флаг нарушения SLA возврата (первый батч > 12ч или завершение > 24ч) | `true` |
| Роли | `partner_cap_expiring` | Количество `PartnerPayoutCap` с `expires_at` < 24ч или `remaining_payout = 0` (по `roles::list_partner_caps`) | > 0 |
| Роли | `premium_cap_expiring` | Количество `PremiumAccessCap` с `expires_at` < 24ч (по `roles::list_premium_caps`) | > 0 |
| Продажи | `sales_rate` | Билеты/мин по событию `TicketPurchaseEvent` | Отклонение > 3σ |
| Прайс-фид | `price_feed_updates_total` | Количество событий `PriceFeedUpdatedEvent` за 1ч | < 1 (для активных активов) |
| Прайс-фид | `price_feed_clamp_active` | Количество активных клампов (по `price_feed::get_price_view`) | > 0 дольше 5 мин |
| Прайс-фид | `price_feed_fallback_active` | Количество активных fallback | > 0 дольше 5 мин |

## 3. Источники данных
- **On-chain события:** индексатор `supra-indexer` публикует в Kafka (`topic: lottery_multi.events`).
- **AutomationBot Exporter:** `/metrics` endpoint с `failure_count`, `pending_age`, `success_streak`.
- **Supra CLI:** `supra monitor dual-write --json` и `supra monitor vrf`.
- **Supra CLI (учёт продаж):** `./supra/scripts/accounting_check.sh <config> compare <lottery_id>` выводит отчёт о совпадении `total_*` между `sales::accounting_snapshot` и `LotterySummary`; используйте для ручного подтверждения агрегатов при расследованиях аномалий.
- **View `status_overview`:** опрос `lottery_multi::views::status_overview` (см. [status_page.md](status_page.md)) каждые 60 секунд для внутренних панелей и публикации статусной страницы.
- **View `get_refund_progress`:** опрос по всем отменённым лотереям каждые 5 минут. Метрики `refund_progress.round`, `refund_progress.remaining` и `refund_progress.last_ts` строятся на основе этого view, значение `canceled_ts` берётся из `views::get_cancellation`.
- **View `list_automation_bots`:** периодический опрос (каждые 60 секунд для внутренних панелей) для отображения pending-действий, лимитов `max_failures` и таймлоков AutomationBot; при ручных проверках используйте `./supra/scripts/automation_status.sh <config> list|get` для оперативного снимка через Supra CLI. На основе этого view рассчитывается индикатор `automation_timelock_breach`, сравнивающий таймлок с порогом 900 секунд для чувствительных действий.

## 4. Алерты и реагирование
- `VrfDepositLow`: `effective_balance < required_minimum` → уведомление DevOps, запуск runbook VRF.
- `DualWriteMismatch`: расхождение хэшей > 10 минут → блокировка финализации, запуск runbook dual-write.
- `PayoutBacklog`: `payout_round_gap > 1` → уведомление on-chain команды, проверка AutomationBot.
- `AutomationDryRunStale`: dry-run старше таймлока → напоминание оператору бота.
- `AutomationTimelockBreach`: `automation_timelock_breach > 0` → срочно поднять таймлок до ≥900 секунд или отключить чувствительные действия, обновить журнал dry-run.
- `SalesDrop`: падение `sales_rate` > 50% без плановых изменений → расследование маркетинга/поддержки.
- `PriceFeedFallback`: `price_feed_fallback_active > 0` > 5 мин → уведомление RootAdmin, выполнить шаги runbook прайс-фида.
- `PriceFeedClamp`: `price_feed_clamp_active > 0` > 5 мин → проверить поставщика цены, задокументировать `clear_clamp` и обновить котировку.
- `RoleCapExpiring`: `partner_cap_expiring` или `premium_cap_expiring` > 0 → уведомление RootAdmin, выполнить `roles::cleanup_expired_admin`/`revoke_*`, обновить `incident_log.md` и удостовериться, что события `PartnerPayoutCapRevoked`/`PremiumAccessRevoked` зафиксированы.
- `RefundBacklog`: `refund_batch_pending > 0` > 4 часов → уведомление RootAdmin и Treasury, следовать процедуре [refund.md](refund.md).
- `RefundRoundStalled`: `refund_progress.round` не меняется > 60 минут при активном `refund_batch_pending` → проверить, что батч опубликован и нет ошибок Supra CLI.
- `RefundAging`: `refund_progress.last_ts` старше 120 минут при активном рефанде → эскалировать в Treasury, сверить ручные батчи.
- `RefundSlaBreach`: `refund_sla_breach = true` → срочное уведомление поддержки, обновление фронтенд-баннеров и коммуникаций с игроками.

## 5. Процедуры обновления
- Раз в релиз проверять соответствие метрик документации (`lottery_multi_readiness_review.md`) и обновлять [status_page.md](status_page.md).
- Еженедельно сверять дашборды с контрольным списком [post_release_support.md](post_release_support.md) и фиксировать итоги в [postmortems.md](postmortems.md).
- При добавлении новых событий обновить схемы в `docs/handbook/architecture/json/` и алёрты.
- Все изменения алёртов заносятся в `incident_log.md`.

## 6. SLA мониторинга
- Время реакции на критический алёрт — ≤ 15 минут.
- Время реакции на высокий алёрт — ≤ 30 минут.
- Weekly review метрик с продуктовой и безопасностью (см. расписание в [post_release_support.md](post_release_support.md)).

## 7. Контакты
- **On-call DevOps:** @ops-oncall
- **Automation Owner:** @automation-lead
- **Security:** @asecurity
