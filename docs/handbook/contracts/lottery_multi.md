# Пакет `lottery_multi`

Пакет отвечает за архитектуру параллельных лотерей и состоит из модулей, внедрённых на этапах 1 и 2 RFC v1. Ниже указаны ключевые функции, механики и события каждого модуля.

## Этап 1. Базовые модули

### `tags`
- Константы `TYPE_*` определяют основной тип розыгрыша (basic, partner, jackpot, vip).
- Константы `TAG_*` и `TAG_EXPERIMENTAL` формируют битовые теги; `assert_tag_budget` ограничивает количество активных битов.
- `validate(primary_type, tags_mask)` проверяет допустимость комбинации.

### `registry`
- `init_registry` инициализирует глобальное хранилище.
- `create_draft_admin` / `create_draft_partner` создают черновые лотереи, эмитируя `LotteryCreated` с хэшем конфигурации и тегами.
- `set_primary_type`, `set_tags_mask` позволяют редактировать классификацию до блокировки снапшота.
- `advance_status` переводит лотерею между статусами (`Draft → Active → Closing → DrawRequested → Drawn → Payout → Finalized/Cancelled`) и при переходе в `Closing` замораживает снапшот.
- `borrow_config`, `get_status`, `is_snapshot_frozen` предоставляют чтение состояния для других модулей.

### `sales`
- `purchase_tickets_public` и `purchase_tickets_premium` продают билеты, применяя лимиты на пользователя, окно продаж и флаг премиального доступа.
- Анти-DoS механики: per-block счётчик, скользящее окно и grace window; нарушение фиксируется `PurchaseRateLimitHit`.
- `emit_purchase_event` формирует `TicketPurchaseEvent` с распределением выручки.
- `accounting_snapshot` возвращает агрегаты `Accounting` для фронтенда и аудита.
- `record_payouts` обновляет агрегаты `total_allocated`/`total_prize_paid`/`total_operations_paid` по факту выплат.

### `draw`
- `init_draw` готовит ресурсы для VRF-процесса.
- `request_draw_admin` (и внутренние проверки) формируют `PayloadV1` с `closing_block_height`, `chain_id`, `schema_version` и увеличенным `attempt`.
- `vrf_callback` проверяет `request_id`, `attempt`, `consumed`, записывает seed, публикует `VrfFulfilled` и разблокирует вычисление победителей.

### `payouts`
- `init_payouts` разворачивает инфраструктуру выплат.
- `compute_winners_admin` выполняет детерминированный алгоритм выбора победителей по батчам, эмитируя `WinnerBatchComputed` с `checksum_after_batch`.
- `record_payout_batch_admin` требует `roles::PayoutBatchCap`, использует `roles::consume_payout_batch` для проверки `max_batch_size`, бюджета операций, cooldown и nonce, затем обновляет агрегаты продаж и `payout_round`.
- `record_partner_payout_admin` требует `roles::PartnerPayoutCap`, вычитает бюджет через `roles::consume_partner_payout` и публикует `PartnerPayoutEvent` с адресом партнёра, суммой, раундом и таймстампом.
- `finalize_lottery_admin` переводит розыгрыш в `Finalized`, проверяя, что все выплаты завершены.
- Юнит `lottery_multi::payouts_tests` подтверждает обновление `Accounting`, лимиты операций, сценарии партнёрских выплат и обязательность наличия капабилити.

### `views`
- `validate_config` выполняет ончейн-валидацию конфигурации перед созданием.
- `get_lottery`, `get_lottery_status`, `get_lottery_badges`, `get_badge_metadata` — основные запросы для UI.
- `list_active`, `list_by_primary_type`, `list_by_tag_mask`, `list_by_all_tags` — пагинация по статусам и тегам.
- `accounting_snapshot`, `get_vrf_deposit_status`, `get_lottery_summary`, `list_finalized_ids` — агрегированные представления.

### `feature_switch`
- Управляет режимами функций (`Disabled`, `EnabledAll`, `PremiumOnly`) с учётом критических операций и devnet-override.

### `price_feed`
- Реестр прайс-фидов Supra: `register_feed`, `update_price`, `clamp_price`, `mark_stale`.
- События `PriceUpdated`, `PriceClamp`, `PriceStale` информируют инфраструктуру.

### `automation`
- `register_bot` и `issue_cap` выдают права боту.
- `dry_run` публикует digest предстоящего действия, `execute` проверяет таймлок и разрешённые цели.
- Счётчик `reputation_score` отражает надёжность бота.

## Этап 2. Миграции и инфраструктура

### `history`
- `ArchiveLedger` хранит финальные сводки (`LotterySummary`) с агрегатами `total_allocated`, `total_prize_paid`, `total_operations_paid`.
- `finalize_lottery_admin` из `payouts` вызывает `history::record_summary` с проверкой `slots_checksum` и `snapshot_hash`.
- `PayoutBatchEvent`, `PartnerPayoutEvent`, `PurchaseRateLimitHitEvent` формируют неизменяемый журнал для аудита.
- `get_summary`, `list_finalized` обслуживают фронтенд «Истории».

### `legacy_bridge`
  - Управляет dual-write миграциями: `init_dual_write`, `update_flags`, `set_expected_hash`, `clear_expected_hash`, `enable_legacy_mirror`, `disable_legacy_mirror`, `mirror_summary_admin`, `notify_summary_written`, `dual_write_status`, `dual_write_flags`.
- События `ArchiveDualWriteStartedEvent`/`ArchiveDualWriteCompletedEvent` фиксируют жизненный цикл ожиданий; `mirror_summary_to_legacy` записывает BCS сводки в `lottery_support::history_bridge`, после чего `notify_summary_written` сравнивает ожидаемый и фактический хэш, очищает ожидание и публикует завершение (при конфигурации `abort_on_mismatch` транзакция прерывается).

### `vrf_deposit`
- `init_vrf_deposit`, `update_config` задают пороги.
- `record_snapshot_admin` / `record_snapshot_automation` обновляют показатели и публикуют `VrfDepositSnapshot`/`Alert`/`RequestsPaused`.
- `resume_requests` снимает блокировку, `ensure_requests_allowed` используется при новом запросе VRF.

### `roles`
- `init_roles` разворачивает `RoleStore` с таблицей `PartnerPayoutCap` и опциональной `PayoutBatchCap` (хранится на адресе пакета).
- `set_payout_batch_cap_admin` и `upsert_partner_payout_cap_admin` позволяют операторам обновлять лимиты капабилити (`max_batch_size`, бюджеты, cooldown, `nonce_stride`).
- `consume_payout_batch`/`consume_partner_payout` блокируют выплаты при нарушении лимитов (`E_PAYOUT_BATCH_TOO_LARGE`, `E_PAYOUT_OPERATIONS_BUDGET`, `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`, `E_PARTNER_PAYOUT_COOLDOWN`, `E_PARTNER_PAYOUT_NONCE`).
- `PartnerCreateCap` содержит белый список `allowed_primary_types` и `allowed_tags_mask`, лимиты бюджета и cooldown выплат для контроля `record_partner_payout_admin`.
- `ensure_primary_type_allowed`, `ensure_tags_allowed` проверяют параметры партнёров при создании лотереи.

### Дополнительные механики
- `economics::assert_distribution` и связанные функции проверяют распределение продаж по базис-поинтам (сумма 10_000).
- `Accounting` отслеживает `total_sales`, `total_allocated`, `total_prize_paid`, `total_operations_paid`, `total_operations_allocated`; функции `record_prize_payout` и `record_operations_payout` защищают от перерасхода (`E_PAYOUT_ALLOC_EXCEEDED`, `E_OPERATIONS_ALLOC_EXCEEDED`).
- `types::prize_plan_checksum`, `types::winner_cursor` поддерживают контроль целостности слотов и батчей.
- Move Prover спецификации (`spec/*.move`) фиксируют: неизменность `snapshot_hash`, рост `payout_round`, ограничения `jackpot_allowance_token`.

## Использование в документации
- Примеры вызовов и сценариев приведены в [../operations/runbooks.md](../operations/runbooks.md) и [../frontend/overview.md](../frontend/overview.md).
- При обновлении модулей необходимо синхронно править этот файл и карточку этапа в `architecture/rfc_status.md`.
