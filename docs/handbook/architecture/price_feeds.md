# Прайс-фиды Supra Lottery

Документ описывает устройство модуля `lottery_multi::price_feed`, события мониторинга и операционные процедуры по управлению
оракулами цен в многопоточной лотерее.

## 1. Назначение и структуры
- `PriceFeedRegistry` хранит версию схемы, таблицу `feeds` и четыре event handle’а: `PriceFeedUpdatedEvent`, `PriceFeedFallbackEvent`,
  `PriceFeedClampEvent`, `PriceFeedClampClearedEvent`.
- Запись `PriceFeedRecord` содержит:
  - `asset_id` — идентификатор актива (резерв `ASSET_SUPRA_USD = 1`, `ASSET_USDT_USD = 2`).
  - `price`, `decimals` — последняя котировка и число десятичных знаков.
  - `last_updated_ts` — отметка времени последнего подтверждённого значения.
  - `staleness_window` — допустимая задержка в секундах (по умолчанию `DEFAULT_STALENESS_WINDOW = 300`).
  - `clamp_threshold_bps` — порог резкого изменения в базис-пойнтах (по умолчанию `DEFAULT_CLAMP_THRESHOLD_BPS = 2_000`, то есть 20%).
  - `fallback_active`, `fallback_reason` — признак и код причины перехода на резервный источник.
  - `clamp_active` — флаг ручной блокировки, выставляемый при превышении порога.

## 2. Операции
- `init_price_feed(admin, version)` — публикует реестр на адресе пакета `@lottery_multi` (однократно).
- `register_feed(admin, asset_id, price, decimals, staleness?, clamp?, updated_ts)` — добавляет новую запись и эмитирует `PriceFeedUpdatedEvent`.
- `update_price(admin, asset_id, price, updated_ts)` —
  - вычисляет абсолютную дельту и сравнивает её с `clamp_threshold_bps`;
  - при нормальном обновлении записывает цену, сбрасывает fallback и публикует `PriceFeedUpdatedEvent`;
  - при превышении порога выставляет `clamp_active = true`, эмитирует `PriceFeedClampEvent` и оставляет прежние `price/last_updated_ts`.
- `set_fallback(admin, asset_id, active, reason)` — переключает резервный источник и эмитирует `PriceFeedFallbackEvent`.
  - При выключении fallback (`active = false`) кламп сбрасывается автоматически.
- `clear_clamp(admin, asset_id, cleared_ts)` — ручное подтверждение оператора, снимающее `clamp_active`, обновляющее `last_updated_ts`
  и публикующее `PriceFeedClampClearedEvent`.
- View-функции `latest_price(asset_id, now_ts)` и `get_price_view(asset_id)` блокируют потребителей при активном fallback (`E_PRICE_FALLBACK_ACTIVE`),
  включённом клампе (`E_PRICE_CLAMP_ACTIVE`) или при устаревших данных (`E_PRICE_STALE`).

## 3. Инварианты и спецификации
- Move Prover-спецификация `spec/price_feed.move` закрепляет:
  - ограничения на поля `PriceFeedRecord` (≤ 18 десятичных знаков, положительные окна и пороги);
  - отсутствие fallback после успешного `update_price` и неизменность значения при срабатывании клампа;
  - обязательное снятие `clamp_active` и обновление `last_updated_ts` в `clear_clamp`.
- Тесты `price_feed_tests` проверяют:
  - чтение свежей котировки (`register_and_read`);
  - отклонение устаревших значений (`stale_feed_rejected`);
  - блокировку потребителей при включённом fallback (`fallback_blocks_consumers`);
  - фиксацию скачков и сохранение предыдущей цены (`clamp_marks_feed_unavailable`);
  - остановку `latest_price` при активном клампе (`clamp_blocks_latest_price`);
  - ручное снятие клампа и повторную публикацию цены в допустимых пределах (`clear_clamp_allows_recovery`).

## 4. Мониторинг и операционные процессы
- Метрики и алерты:
  - `price_feed_updates_total` — счётчик событий `PriceFeedUpdatedEvent` (отслеживает частоту обновлений).
  - `price_feed_fallback_active` — бинарный индикатор активных fallback по каждому `asset_id`.
  - `price_feed_clamp_active` — индикатор включённого клампа; алерт при продолжительности > 5 минут.
- Runbook (см. [../operations/runbooks.md](../operations/runbooks.md)) дополняется шагами:
  1. Подтвердить источник скачка, запросить подтверждение у Supra Oracle.
  2. В случае ложного изменения активировать fallback (`set_fallback(..., true, reason)`).
  3. После расследования снять кламп через `clear_clamp` и опубликовать новую котировку.
- Release checklist (см. [../operations/release_checklist.md](../operations/release_checklist.md)) требует проверки события `PriceFeedClampClearedEvent`
  и актуальности окна `staleness_window` для всех зарегистрированных активов.

## 5. Связанные документы
- [../architecture/overview.md](overview.md) — обзор модулей и зависимостей.
- [../contracts/lottery_multi.md](../contracts/lottery_multi.md) — справочник функций модуля.
- [../../architecture/rfc_v1_implementation_notes.md](../../architecture/rfc_v1_implementation_notes.md) — статус реализации и дальнейшие шаги.
- [../../architecture/lottery_parallel_plan.md](../../architecture/lottery_parallel_plan.md) — дорожная карта, раздел 4.19 «Ончейн-прайс-фиды».
