# Архитектура SupraLottery

## Компоненты
- **Пакет `core`** — базовые ресурсы сети, депозиты VRF и миграции.
- **Пакет `support`** — вспомогательные утилиты и общие хранилища.
- **Пакет `reward`** — управление призовыми пулами и NFT-наградами.
- **Пакет `lottery_multi`** — параллельные лотереи, включающие модули `registry`, `sales`, `draw`, `payouts`, `economics`, `history`, `views`, `feature_switch`, `price_feed`, `automation`, `vrf_deposit`, `tags` (подробности по оракулу цен см. в [price_feeds.md](price_feeds.md)).
- **Off-chain сервисы** — Supra CLI для деплоя, AutomationBot, индексатор истории, фронтенд.

## Жизненный цикл лотереи
1. `Draft` — подготовка конфигурации и проверка тегов.
2. `Active` — окно продаж, анти-DoS лимиты и контроль распределения выручки.
3. `Closing` — фиксация снапшота билетов, freeze `snapshot_hash` и подготовка payload VRF.
4. `DrawRequested` → `Drawn` — запрос dVRF, обработка `PayloadV1` с `closing_block_height` и `chain_id`.
5. `WinnerComputation` — батчи `WinnerBatchComputed` с `checksum_after_batch` и защитой от повторов.
6. `Payout` — выдача призов и резервов, события `PayoutBatchExecuted`.
7. `Finalized` — перенос сводки в архив и очистка оперативных данных.
8. `Canceled` — аварийное закрытие и рефанд.

## Механики этапов 1–2
- **Этап 1:** классификаторы (`primary_type`, `tags_mask`), анти-DoS продажи с событиями `TicketPurchaseEvent`, защищённый `PayloadV1` и батчевые выплаты с `checksum_after_batch`.
- **Этап 2:** dual-write архив `ArchiveLedger`, контроль VRF-депозита (`VrfDepositStatus` и события паузы), миграционный `legacy_bridge` и Move Prover-инварианты для снапшота, выплат и allowance джекпота.

## Хранение данных
- **Registry** хранит конфигурации, статусы и хэши снапшотов.
- **Sales** оперирует чанками билетов и агрегатами распределений.
- **History** ведёт события и архив `ArchiveLedger` с dual-write проверкой.
- **Views** предоставляют пагинацию по типам, тегам и статусам, а также агрегированную сводку `status_overview` для статусной страницы; структура ответов зафиксирована в [view_schemas.md](view_schemas.md).

## Внешние зависимости
- **Supra dVRF v3** — поставщик случайных чисел.
- **Supra Price Oracle** — курсы SUPRA/USD и прочих токенов.
- **AutomationBot** — автоматизация батчей и проверка депозита VRF.

Подробнее см. [rfc_status.md](rfc_status.md), [../operations/runbooks.md](../operations/runbooks.md), [../operations/monitoring.md](../operations/monitoring.md), [../operations/release_checklist.md](../operations/release_checklist.md) и [../architecture/lottery_parallel_plan.md](../../architecture/lottery_parallel_plan.md).
