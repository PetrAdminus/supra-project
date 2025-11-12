# JSON Schema view для `lottery_multi`

Этот документ фиксирует структуру ответов on-chain view функций пакета `lottery_multi` и связывает их с фронтенд- и индексаторными компонентами. Схема опубликована в файле [`json/lottery_multi_views.schema.json`](./json/lottery_multi_views.schema.json) (актуальная версия `1.0.3`) и синхронизируется с юнит-тестами `lottery_multi::views_tests`, примером [`json/examples/lottery_multi_view_samples.json`](./json/examples/lottery_multi_view_samples.json) и Python-валидатором `SupraLottery/tests/test_view_schema_examples.py`.

## Область применения

- Веб-клиенту и партнёрским панелям необходимо валидировать ответы `get_lottery`, `get_lottery_status`, `get_lottery_badges`, `get_vrf_deposit_status`, `accounting_snapshot`, `list_*`, `list_automation_bots`/`get_automation_bot` (панель AutomationBot).
- Индексатору требуется единый контракт на структуры `LotteryConfig`, `LotteryStatusView`, `BadgeMetadata`, `VrfDepositStatusView`, `Accounting`, `LotterySummary`.
- QA-команда использует схему и пример ответов для генерации моков и проверки совместимости мобильных клиентов.

## Структура схемы

| Объект | Поле | Тип | Описание |
|--------|------|-----|----------|
| `BadgeMetadata` | `primary_label` | `string` | Текстовая метка основного типа (`basic`, `partner`, `jackpot`, `vip`). |
| | `is_experimental` | `boolean` | Флаг наличия бита `TAG_EXPERIMENTAL`. |
| | `tags_mask` | `integer` (u64) | Маска тегов в десятичном виде. |
| `LotteryBadges` | `primary_type` | `integer` (u8) | Ответ `get_lottery_badges`, основная категория лотереи. |
| | `tags_mask` | `integer` (u64) | Маска тегов для текущей конфигурации. |
| `LotteryStatusView` | `status` | `integer` (u8) | Текущий статус (`registry::STATUS_*`). |
| | `snapshot_frozen` | `boolean` | Признак замороженного снапшота. |
| | `primary_type` | `integer` (u8) | Значение `tags::TYPE_*`. |
| | `tags_mask` | `integer` (u64) | Маска тегов. |
| `LotteryConfig` | `event_slug`, `series_code` | `string (0x<hex>)` | Байтовые поля (`vector<u8>`), сериализуются в hex c префиксом `0x`. |
| | `sales_window.sales_start` | `integer` (u64) | Начало окна продаж. |
| | `sales_window.sales_end` | `integer` (u64) | Завершение окна продаж. |
| | `ticket_limits.max_tickets_total` | `integer` (u64) | Общий лимит билетов. |
| | `ticket_limits.max_tickets_per_address` | `integer` (u64) | Лимит на адрес (0 — без ограничения). |
| | `sales_distribution.prize_bps` | `integer` (u16) | Доля призового фонда в базис-поинтах. |
| | `prize_plan[].reward_payload` | `string (0x<hex>)` | BCS-представление награды. |
| | `auto_close_policy.enabled` | `boolean` | Флаг автоматического закрытия. |
| | `reward_backend.backend_type` | `integer` (u8) | Тип backend’а (`BACKEND_*`). |
| `VrfDepositStatusView` | `total_balance` | `integer` (u64) | Общий баланс депозита. |
| | `minimum_balance` | `integer` (u64) | Конфигурационный минимум. |
| | `effective_balance` | `integer` (u64) | Баланс после удержания резервов. |
| | `required_minimum` | `integer` (u64) | Расчётный минимум для активных запросов. |
| | `last_update_ts` | `integer` (u64) | Временная метка последнего снапшота. |
| | `requests_paused` | `boolean` | Признак паузы на новые VRF-запросы. |
| | `paused_since_ts` | `integer` (u64) | Таймстемп начала паузы (0, если паузы нет). |
| `Accounting` | `total_sales` | `integer` (u64) | Сумма продаж по билетам. |
| | `total_allocated` | `integer` (u64) | Всего зарезервировано для призов. |
| | `total_prize_paid` | `integer` (u64) | Фактически выплачено призов. |
| | `total_operations_paid` | `integer` (u64) | Выплаты на операционные нужды. |
| | `total_operations_allocated` | `integer` (u64) | Резерв под операции. |
| | `jackpot_allowance_token` | `integer` (u64) | Допустимый остаток джекпота. |
| `LotterySummary` | `snapshot_hash`, `slots_checksum`, `winners_batch_hash`, `checksum_after_batch` | `string (0x<hex>)` | Контрольные суммы архива (SHA3-256 в hex). |
| | `tickets_sold`, `proceeds_accum`, `total_allocated`, `total_prize_paid`, `total_operations_paid` | `integer` (u64) | Агрегаты продаж и выплат. |
| | `created_at`, `closed_at`, `finalized_at` | `integer` (u64) | Временные метки жизненного цикла. |
| `StatusOverview` | `total`, `draft`, `active`, `closing`, `draw_requested`, `drawn`, `payout`, `finalized`, `canceled` | `integer` (u64) | Подсчёты лотерей по ключевым статусам. |
| | `vrf_requested`, `vrf_fulfilled_pending`, `vrf_retry_blocked` | `integer` (u64) | Метрики VRF: активные запросы, выполненные, но не потреблённые, и заблокированные повторные запросы. |
| | `winners_pending`, `payout_backlog` | `integer` (u64) | Бэклоги расчёта победителей и невыплаченных батчей. |
| `AutomationBotView` | `operator` | `string (0x<hex>)` | Адрес оператора бота. |
| | `allowed_actions[]` | `integer` (u64) | Разрешённые `action_id`. |
| | `timelock_secs`, `max_failures`, `failure_count`, `success_streak`, `reputation_score` | `integer` (u64) | Таймлок dry-run, предел и счётчики отказов/успехов, агрегированная репутация. |
| | `has_pending`, `pending_execute_after` | `boolean`, `integer` (u64) | Наличие pending-действия и момент, после которого разрешено выполнение. |
| | `pending_action_hash`, `cron_spec`, `last_action_hash` | `string (0x<hex>)` | Digest текущего pending-действия, cron-спека и последний выполненный hash. |
| | `expires_at`, `last_action_ts` | `integer` (u64) | Срок действия регистрации и время последнего действия. |

## Правила версионирования

- Основная версия схемы — `v1`. Изменения с обратной совместимостью (добавление необязательных полей) повышают минорную версию в объекте `info.version`.
- Изменения, нарушающие совместимость (удаление, переименование полей), требуют согласования с фронтендом и индексаторами, подготовка PR в `view_schemas.md` и `lottery_multi_views.schema.json` обязательна.
- При изменениях view-функций необходимо:
  1. Обновить JSON Schema и пример `json/examples/lottery_multi_view_samples.json`.
  2. Добавить/исправить тесты в `views_tests` и Python-валидатор `SupraLottery/tests/test_view_schema_examples.py`.
  3. Обновить раздел «Фронтенд и API» в `rfc_v1_implementation_notes.md`.
  4. Уведомить DevOps об ожиданиях для мониторинга `requests_paused` и пагинации.

## План интеграции

1. **Фронтенд** — подключить JSON Schema в пайплайн проверки API-моделей (TypeScript `zod`/`ajv`), использовать пример ответов и smoke-тесты view.
2. **Индексатор** — адаптировать десериализацию `LotteryConfig`, `LotteryStatusView`, `LotterySummary`, покрыть фильтрацию по тегам и статусам.
3. **QA** — использовать схему и пример `lottery_multi_view_samples.json` для генерации фиктивных payload и проверки новых клиентов.
4. **Документация** — держать ссылку на схему и пример в `contracts/lottery_multi.md`, статусной таблице RFC и операционных документах (`operations/runbooks.md`, `operations/release_checklist.md`).

## Ссылки

- `SupraLottery/supra/move_workspace/lottery_multi/tests/views_tests.move`
- `SupraLottery/tests/test_view_schema_examples.py`
- `docs/architecture/rfc_v1_implementation_notes.md`
- `docs/handbook/contracts/lottery_multi.md`
- `docs/handbook/architecture/json/examples/lottery_multi_view_samples.json`
