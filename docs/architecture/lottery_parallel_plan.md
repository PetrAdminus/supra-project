# План развития архитектуры лотереи с параллельными розыгрышами

## TL;DR для новых участников
- **Цель** — превратить однопоточную лотерею в систему множества параллельных розыгрышей, сохранив совместимость с текущими
  фронтендом, dVRF v3 и операционными процессами.
- **Пакеты** — создаём новый `lottery_multi`, разбитый на тонкие модули (`registry`, `sales`, `draw`, `payouts`, `history`,
  `views`, `roles`, `economics`, `feature_switch`, `tags`) и использующий мосты к существующим `lottery_core`,
  `lottery_support`, `lottery_rewards`.
- **Классификаторы** — каждая лотерея имеет основной тип (`primary_type`) и битовую маску тегов (`tags_mask`), которые
  контролируются модулем `tags` и отображаются во view-функциях для фронтенда и партнёров.
- **Жизненный цикл** — фиксированные переходы `Draft → Active → Closing → DrawRequested → WinnerComputation → Payout → Finalized`
  с защитами VRF (schema_version, attempt, consumed) и батчевой обработкой победителей/выплат.
- **История и прозрачность** — on-chain архив `LotteryHistoryArchive`, dual-write миграция, JSON Schema для view, события с
  `event_version` и хэшами, чтобы аудиторы и фронтенд могли верифицировать каждый шаг.
- **Безопасность** — строгая система capabilities и ролей (RootAdmin, OperationalAdmin, PartnerOperator и др.),
  rate-limit покупки билетов, контроль VRF-депозита, автоматизация с dry-run и требования к Move Prover/CI.
- **Документация** — русскоязычная «книга проекта» в `docs/handbook` становится единым справочником; комментарии в коде остаются
  на английском, все файлы ведутся в UTF-8.
- **Этапность** — краткий обзор шагов см. в разделе 6, подробную дорожную карту — в разделе 10.

## 0. Контекст и исходные предпосылки
- **Цель документа.** Этот план описывает переход от текущей однораундовой лотереи Supra к многопоточной системе розыгрышей. Документ задуман как самостоятельное руководство: он повторяет ключевые выводы из предыдущих обсуждений, поэтому может использоваться командами, которые не участвовали в исходном диалоге.
- **Текущая кодовая база.** Контракты расположены в репозитории `SupraLottery` и собраны в три Move-пакета — `lottery_core`, `lottery_support`, `lottery_rewards`. Дополнительные скрипты управления находятся в каталоге `supra/scripts`, фронтенд — в `frontend/`.
- **Внешние зависимости.** Платформа интегрируется с dVRF v3 согласно официальной документации Supra ([github.com/Supra-Labs/documentation/blob/main/dvrf](https://github.com/Supra-Labs/documentation/blob/main/dvrf)). Обязательные требования (валидация payload, лимиты газа, повторные запросы) собраны в файле `docs/dVRF_v3_checklist.md`.
- **Ограничения деплоя.** Исторически пакеты разделены на три части, чтобы укладываться в лимит 60 000 байт на публикацию Move-пакета. Любое расширение логики должно учитывать этот предел, поэтому новая функциональность планируется в отдельном пакете.
- **Связь с фронтендом и индексаторами.** Пользовательский интерфейс (React 18 + TypeScript 5) уже содержит раздел «История» и сервисы просмотра билетов. Новая архитектура обязана предоставить совместимые view-функции и события, чтобы существующий фронт можно было адаптировать без полной переработки.

## 1. Исходные наблюдения
- Текущая логика размещена в трёх пакетах `lottery_core`, `lottery_support`, `lottery_rewards` и уже близка к лимиту 60 000 байт на пакет (`lottery_core/sources/Lottery.move`, `LotteryRounds.move`, `Operators.move` и др.).
- Основной контракт `core_main_v2` оперирует глобальным состоянием (`LotteryData`) и допускает только один активный розыгрыш; `pending_request` запрещает параллельные VRF-запросы.
- Поддерживающие модули (`lottery_support::History`, `Metadata`, `Migration`) и наградные (`lottery_rewards::Jackpot`, `Store`, `NftRewards`, `Vip`) предполагают единственный поток выплат.
- dVRF v3 требует сохранения и проверки хэша полезной нагрузки (`sha3-256`), хранения параметров газа и счётчиков запросов (см. `docs/dVRF_v3_checklist.md`).

## 2. Общие цели новой архитектуры
1. Обеспечить произвольное число параллельных лотерей с независимым жизненным циклом и набором параметров. Это подразумевает переход от «глобального» `LotteryData` к реестру экземпляров `Lottery`.
2. Сохранить соответствие dVRF v3: отдельный запрос/ответ для каждого розыгрыша, повторная валидация payload в момент колбэка и соблюдение лимитов `rng_count`, `maxGasLimit`, `maxGasPrice`.
3. Обеспечить прозрачность: события и view-функции должны позволять восстановить историю любого розыгрыша, подтвердить доказательство VRF и вычисление победителей без дополнительного доверия к off-chain-сервисам.
4. Масштабируемость по газу: тяжёлые операции (расчёт победителей, выплаты, архивирование) должны выполняться батчами или вынесены в отдельные транзакции, чтобы вписаться в лимиты Supra.
5. Оставить совместимость с существующим фронтендом и админскими CLI: план должен явно указывать, какие API изменяются и какие новые вызовы появятся.

## 3. Архитектурные контуры
### 3.1 Пакеты Move
- **Новый пакет `lottery_multi`.** Он разбит на «тонкие» модули (`registry`, `sales`, `draw`, `payouts`, `history`, `views`, `roles`, `economics`, `feature_switch`, `tags`), чтобы каждый файл оставался значительно ниже лимита 60 000 байт. Общие типы и константы выносятся в `lottery_multi::types`, валидации — в `lottery_multi::validators`, а базовые классификаторы находятся в новом модуле `lottery_multi::tags`. Пакет зависит от `lottery_core` (повторное использование библиотек работы с билетами, сейфами и комиссией) и `lottery_support` (существующие структуры истории и миграций). Дополнительно следует задокументировать зависимости в `SupraLottery/supra/move_workspace/Move.toml`.
- **`lottery_rewards`.** Пакет сохраняет ответственность за агрегирование наград (`Jackpot`, `Store`, `NftRewards`). Новый пакет `lottery_multi` взаимодействует с ним только через мост `lottery_multi::reward_bridge`, который предоставляет узкий набор функций (`reserve_from_sales`, `release_to_partner_vault`, `escrow_nft`, `mint_reward_nft`). Прямые обращения других модулей к хранилищам наград запрещены и сопровождаются lint-проверками.
- **`lottery_factory`.** Существующий модуль фабрики расширяется функциями для выпуска идентификаторов (`run_id`), хранения глобального счётчика и выдачи capability создания лотерей. Пакет перестраивается так, чтобы создавать ресурсы `LotteryInstance`, которые потом регистрируются в `lottery_multi::registry`.

### 3.2 Структуры данных (черновик)
```move
module lottery_multi::tags {

    const TYPE_BASIC: u8   = 0;
    const TYPE_PARTNER: u8 = 1;
    const TYPE_JACKPOT: u8 = 2;
    const TYPE_VIP: u8     = 3;

    const TAG_NFT: u64         = 1 << 0;
    const TAG_DAILY: u64       = 1 << 1;
    const TAG_WEEKLY: u64      = 1 << 2;
    const TAG_SPLIT_PRIZE: u64 = 1 << 3;
    const TAG_PROMO: u64       = 1 << 4;
    const TAG_EXPERIMENTAL: u64 = 1u64 << 63;

    public fun validate(primary_type: u8, tags_mask: u64) {
        assert!(
            primary_type == TYPE_BASIC ||
            primary_type == TYPE_PARTNER ||
            primary_type == TYPE_JACKPOT ||
            primary_type == TYPE_VIP,
            errors::E_TAG_PRIMARY_TYPE
        );
        let _ = tags_mask;
    }
}

// `errors::E_TAG_PRIMARY_TYPE` объявляется в `lottery_multi::errors` и добавляется в общий каталог кодов.

// Документация в `docs/handbook/architecture/tags.md` содержит «карту битов»: какие маски разрешены, какие зарезервированы
// под будущие фичи, и сколько тегов можно активировать одновременно. Lint проверяет, что `tags_mask` не содержит неизвестных
// битов (`tags_mask & !KNOWN_TAG_BITS == 0`) и что число активных флагов не превышает `MAX_ACTIVE_TAGS` (по умолчанию 4),
// что защищает от коллизий между фронтендом и ончейн-логикой и удерживает бейджи читабельными.

#### Таблица основных типов и тегов

| Классификатор       | Значение  | Назначение и ограничения                                                                 |
|---------------------|-----------|------------------------------------------------------------------------------------------|
| `TYPE_BASIC`        | `0`       | Базовые розыгрыши оператора. Доступны всем администраторам и партнёрам по умолчанию.     |
| `TYPE_PARTNER`      | `1`       | Розыгрыши, созданные партнёрами. Требует явного разрешения в `PartnerCreateCap`.         |
| `TYPE_JACKPOT`      | `2`       | Лотереи, связанные с глобальным джекпотом. Управляются только оператором.               |
| `TYPE_VIP`          | `3`       | Эксклюзивные розыгрыши с премиальным доступом. Требуют `PremiumAccessCap`.               |
| `TAG_NFT`           | `1 << 0`  | Призы в формате NFT. Требует подготовленного `PartnerNftEscrow` или mint-on-claim.      |
| `TAG_DAILY`         | `1 << 1`  | Суточные розыгрыши. Используется для фильтров и статистики активности.                   |
| `TAG_WEEKLY`        | `1 << 2`  | Недельные серии. В отчётах группируются отдельно от дневных.                             |
| `TAG_SPLIT_PRIZE`   | `1 << 3`  | Приз делится на несколько победителей. Активируется только при `winners_dedup=true`.     |
| `TAG_PROMO`         | `1 << 4`  | Промо-лотереи с дополнительными бонусами или внешним финансированием.                   |
| `TAG_EXPERIMENTAL`  | `1 << 63` | Временные/экспериментальные розыгрыши для A/B-тестов. По умолчанию скрываются на фронте. |

Для фронтенда и документации фиксируется правило: одновременно может быть активно не более `MAX_ACTIVE_TAGS` битов; маски,
не входящие в таблицу, считаются зарезервированными и приводят к `abort(errors::E_TAG_UNKNOWN_BIT)` на этапе валидации. Флаг
`TAG_EXPERIMENTAL` помечает «скрытые» розыгрыши: фронтенд по умолчанию фильтрует такие записи, админские панели и индексаторы
могут включать отображение через отдельный переключатель.

module lottery_multi::registry {

    use std::option;
    use std::vector;

    use lottery_multi::tags;
    use lottery_multi::types::{AutoClosePolicy, PrizeSlot, RewardBackend, SalesWindow, VrfStatus};

    struct Lottery has key {
        id: u64,
        config: Config,
        state: State,
        accounting: Accounting,
        vrf: VrfState,
    }

    struct Config has copy, drop, store {
        sales_window: SalesWindow,
        ticket_price: u64,
        ticket_limits: TicketLimits,
        sales_distribution: SalesDistribution,
        prize_plan: vector<PrizeSlot>,
        auto_close_policy: AutoClosePolicy,
        reward_backend: RewardBackend,
        primary_type: u8,
        tags_mask: u64,
        winners_dedup: bool,
        draw_algo: u8,
    }

    struct VrfState has copy, drop, store {
        request_id: option::Option<u64>,
        payload_hash: option::Option<vector<u8>>,
        seed: option::Option<vector<u8>>,
        status: VrfStatus,
        schema_version: u16,
        attempt: u8,
        consumed: bool,
        retry_after_ts: u64,
        retry_strategy: u8,
    }
}
```
- `State` хранит моментальные значения (проданные билеты, уникальные участники, закрыта ли продажа) и копию распределения продаж, зафиксированную в момент первой покупки.
- `Accounting` резервирует доли джекпота/продаж, средства для NFT и комиссию, а также хранит накопительные агрегаты (`total_sales`, `total_allocated`, `total_prize_paid`, `total_operations_paid`, `jackpot_allowance_token`). Контрольная сумма `slots_checksum = sha3-256(prize_plan)` и сериализация `accounting` входят в `snapshot_hash`, чтобы фронтенд и индексаторы могли быстро сверять данные без полного перебора записей.
- `PrizeSlot` содержит информацию о типе награды (`FromSales`, `FromJackpot`, `NftEscrow`, `CustomHook`). Все конфигурации проходят через `tags::validate(config.primary_type, config.tags_mask)`, а также соответствующие проверки партнёрских квот.

### 3.3 Жизненный цикл
1. **Draft.** Создание и проверка конфигурации; резервирование призов и регистрация в `registry`. На этом шаге запускаются валидации (корректность временных окон, допустимые идентификаторы, наличие лимитов).
2. **Active.** Продажа билетов, учёт лимитов, публикация событий `TicketPurchase`. Пользовательские билеты заносятся в чанки, формируется индекс по адресам.
3. **Closing.** Завершение продаж, фиксация снапшота участников, подготовка данных к VRF-запросу (расчёт `payload_hash`, сохранение количества билетов, запись `snapshot_id` и `snapshot_total_tickets`, которые затем входят в payload и любые проверки).
4. **AwaitingVRF.** Создание VRF-запроса и публикация события `VrfRequested`. В состоянии хранятся параметры газа и идентификатор запроса.
5. **VrfFulfilled.** Получение seed и валидация payload (в т.ч. `rng_count`). Колбэк только сохраняет данные и публикует `VrfFulfilled`, вычисления откладываются.
6. **WinnerComputation.** Расчёт победителей вне колбэка; поддержка батчей, маппинг `winner → prize_slot`. Возможен повторный запуск при сбоях, прогресс батчей хранится в `WinnerCursor { last_processed_index, checksum_after_batch }`.
7. **Payout.** Поэтапная выдача наград (финансовых и NFT), запись прогресса, события `PayoutBatch`/`PartnerPayout`. Лимиты контролируются через capabilities.
8. **Finalized/Archived.** Перенос статистики в историю, очистка оперативных структур (чанки билетов, временные таблицы), публикация `LotteryFinalized`. При финализации сверяется `slots_checksum` и `snapshot_hash`, чтобы предотвратить изменение данных между расчётом и архивом.
9. **Canceled.** Сценарии отказа (невыполненный VRF, ручная отмена) и рефанд. Должны быть предусмотрены события `LotteryCanceled` и функции возврата средств.

**Редактирование классификаторов.** Значение `Config.primary_type` доступно к изменению только в состоянии `Draft`; переход в `Active` фиксирует его окончательно. Поле `Config.tags_mask` разрешено корректировать в `Draft` и `Active`, но после установки статуса `Closing` любые изменения запрещены (за исключением аварийных операций с явным подтверждением `RootAdmin`).

#### 3.3.0 Машина состояний и строгие переходы
- **Единственный контроллер.** Изменение `state.status` разрешено только из функций модуля `lottery_multi::registry::set_status`, который принимает ожидаемое состояние (`from`) и новое (`to`). Все остальные модули вызывают его опосредованно, что гарантирует единое место проверки.
- **Допустимые пары.** Разрешены переходы: `Draft → Active`, `Draft → Canceled`, `Active → Closing`, `Closing → AwaitingVRF`, `AwaitingVRF → VrfFulfilled`, `VrfFulfilled → WinnerComputation`, `WinnerComputation → Payout`, `Payout → Finalized`, `Payout → Canceled`, `AwaitingVRF → Canceled`, `Closing → Canceled`. Любая другая комбинация приводит к `abort(E_STATE_TRANSITION_INVALID)`.
- **Документация abort_if.** Для каждой `entry`-функции документируется `abort_if state.status != EXPECTED`, и тесты проверяют, что нарушение ожидания приводит к ошибке. В «книге проекта» приводится диаграмма состояний и таблица переходов для аудита.
- **Фиксация снапшота.** Переход `Active → Closing` дополнительно записывает `snapshot_hash = sha3-256(ticket_chunks)` и `snapshot_block_height`, а также устанавливает `state.snapshot_frozen = true`. Любая попытка изменить билеты после установки флага должна начинаться с проверки `assert!(!state.snapshot_frozen, E_SNAPSHOT_FROZEN)`; изменение данных при `snapshot_frozen = true` приводит к `abort(E_SNAPSHOT_FROZEN)`.
- **Заморозка классификаторов.** `Config.primary_type` разрешено изменять только в статусе `Draft`. После перевода лотереи в `Active` попытка редактирования приводит к `abort(E_TAG_PRIMARY_LOCKED)`. Поле `tags_mask` допускает изменения в статусах `Draft` и `Active`; переход `Active → Closing` автоматически блокирует модификацию тегов (если только не активирован аварийный режим).
- **Проверка входных данных батча.** `WinnerComputation` при каждом запуске сверяет `snapshot_hash` и накопительную `checksum_after_batch`, вычисляемую по чанкам победителей. Несовпадение приводит к `abort(E_WINNER_INPUT_CHANGED)` и инициирует аварийную остановку.

#### 3.3.1 Детерминированный выбор победителей и защита от bias
- **Схема слотов.** Каждая лотерея хранит `vector<PrizeSlotSpec>` с идентификаторами призовых слотов, указанием типа награды и требуемым количеством победителей. Параметр `rng_count` всегда равен длине списка слотов, поэтому при создании розыгрыша выполняется проверка `rng_count == prize_slots.len()`; при необходимости нескольких случайных чисел в рамках одного слота (например, для мульти-победителей с равными долями) слот задаёт `winners_per_slot`. Поля `Config.winners_dedup` и `Config.draw_algo` определяют, разрешён ли повтор адреса в разных слотах и какую стратегию применяет алгоритм модуля `payouts` (0 — «без замены», 1 — «с заменой», 2 — «stride/прослойки»); значения валидируются при инициализации.
- **Алгоритм сопоставления.** После получения VRF seed модуль `payouts::compute_winners_admin` декодирует его в `vector<u256>` и для каждого призового слота вычисляет детерминированный хэш `digest = sha3_256(bcs(seed) || snapshot_hash || payload_hash || lottery_id || ordinal || local_index || schema_version || attempt)`. Индекс билета определяется как `winner_index = digest_u64 % total_tickets` (где `digest_u64` — первые 8 байт хэша в little-endian). При `winners_dedup = true` используется таблица `assigned_indices`; при коллизии запускается повторное хэширование `digest = sha3_256(digest)` с лимитом 16 попыток. Если лимит исчерпан, процесс аварийно останавливается с `E_WINNER_DEDUP_EXHAUSTED`. Таким образом, распределение остаётся равномерным и жёстко привязано к снапшоту билетов.
- **Идемпотентность батчей.** Результаты вычислений пишутся в чанки `WinnerChunk` (по 64 записи) и сопровождаются событием `WinnersComputed`, содержащее `batch_no`, `assigned_in_batch`, `total_assigned`, `winners_batch_hash` и `checksum_after_batch`. Перед записью проверяется, что `winner_index` не встречался ранее (для dedup), а `checksum_after_batch` обновляется по формуле `sha3_256(prev_checksum || ticket_index || digest)`. Порядок обхода слотов фиксирован (`ordinal` растёт монотонно), поэтому повторный запуск батча либо не изменяет состояние (если весь объём уже посчитан), либо завершается `E_WINNER_ALL_ASSIGNED`.
- **Fail-safe при нехватке билетов.** Если количество уникальных билетов меньше суммарного числа призовых слотов, батч немедленно останавливается с `abort(E_INSUFFICIENT_TICKETS)`, а `RootAdmin` или партнёр обязаны инициировать отмену розыгрыша. Этот сценарий отражён в разделе аварийных процедур.

#### 3.3.2 Правила времени и финальности
- **Источник времени.** Вся логика продаж опирается на `timestamp_seconds` из заголовка блока Supra. `SalesWindow` хранит значения `start_ts` и `end_ts`, а функции создания/активации проверяют `start_ts < end_ts` и принадлежность обеих границ допустимому диапазону (не позже `now + MAX_SALES_HORIZON_SECS`, по умолчанию 2 592 000 секунд ≈ 30 дней). Константы `MAX_SALES_HORIZON_SECS` и `DRIFT_ALLOWANCE_SECS` объявлены в `lottery_multi::types` и публикуются в книге проекта.
- **Граничные блоки.** Продажа разрешена, если `start_ts ≤ now < end_ts`. При достижении `now ≥ end_ts` лотерея автоматически переходит в `Closing` (через `AutomationBot` или ручной вызов). Для предотвращения дрейфа допускается максимум `±DRIFT_ALLOWANCE_SECS` (по умолчанию 300 секунд) между объявленным окончанием и фактическим блоком закрытия; превышение лимита фиксируется событием `SalesWindowDrift` и требует ручного подтверждения администратора.
- **Финальность и reorg.** После перехода в `Closing` модуль записывает `closing_block_height` и `closing_timestamp`. При обнаружении reorg на глубину > `REORG_TOLERANCE` (по данным индексатора) AutomationBot повторно выполняет процедуру `assert_closing_state`, сверяя снапшот билетов и хэш состояния. В разделе мониторинга добавлен runbook по обработке reorg-сценариев.
- **Публикация расписаний.** Все события, связанные с временными границами (`LotteryCreated`, `SalesClosingScheduled`, `SalesClosed`), содержат UNIX-времена и идентификаторы блоков, чтобы фронтенд и внешние сервисы могли корректно подсвечивать статусы без опоры на локальные часы.

#### 3.3.3 Версионирование payload VRF и защита от повторов
- **Schema ID.** Для каждого VRF-запроса формируется структура `PayloadV1 { lottery_id, run_id, ticket_supply, prize_plan_hash, entropy_salt, closing_block_height, chain_id }`. Порядок полей и их типы документируются в `docs/handbook/architecture/vrf-integration.md` вместе с примером BCS-представления (hex-дамп little-endian целых, без выравнивания). Хэш структуры вычисляется как `sha3-256(bcs::to_bytes(payload))` и сохраняется в `VrfState.payload_hash`. Поле `schema_version: u16` монотонно увеличивается при изменении формата payload; описание изменений фиксируется в миграции и документации. Добавленные поля `closing_block_height: u64` и `chain_id: u8` защищают от коллизий при миграциях и повторных fulfill (хэш включает номер блока фиксации снапшота и идентификатор сети).
- **Request ledger.** В `VrfState` хранится `request_id`, `attempt` и флаг `consumed`. При каждом вызове `request_vrf` счётчик `attempt` увеличивается на 1, `consumed` сбрасывается в `false`, а `request_id` обновляется. Колбэк `on_vrf_fulfilled` проверяет, что `consumed == false`, сверяет `schema_version`, хэш payload, `request_id` и подпись провайдера (через официальный verifier Supra). После успешной проверки `consumed` устанавливается в `true`, а событие `VrfFulfilled` включает `schema_version`, `payload_hash`, `attempt` и `request_id`.
- **Replay-защита и порядок.** Если колбэк приходит повторно с тем же `request_id`, но `consumed == true`, транзакция завершается `abort(E_VRF_ALREADY_CONSUMED)`. Ответы с меньшим `attempt`, чем записанный, игнорируются как устаревшие. Если подпись или хэш не совпадают, выбрасывается `abort(E_VRF_PAYLOAD_MISMATCH)` и публикуется событие `VrfReplayDetected`. AutomationBot и мониторинг реагируют на событие, переводя лотерею в аварийный режим и инициируя расследование.
- **Повторные попытки.** `VrfState.retry_after_ts` задаёт момент, когда разрешён новый запрос, а `retry_strategy` (0 — фиксированный интервал, 1 — экспоненциальный рост, 2 — ручной контроль администратором) определяет, как AutomationBot вычисляет следующий дедлайн. Число попыток ограничено параметром `MAX_VRF_ATTEMPTS`; его превышение автоматически переводит лотерею в `Canceled` и инициирует возврат средств.
- **Миграции и тесты.** В тестовом наборе появляются сценарии: (1) успешный колбэк с новой схемой payload, (2) повторный колбэк, (3) подмена хэша. Дополнительно документируется процедура обновления схемы payload в разделе `docs/handbook/architecture/vrf-integration.md`.

### 3.4 События
- `LotteryCreated(event_version, event_category, id, cfg_hash, config_version, creator, event_code, series_code, run_id, primary_type, tags_mask)`
- `TicketPurchase(event_version, event_category, lottery_id, buyer, quantity, sale_amount, prize_allocation, jackpot_allocation, operations_allocation, reserve_allocation, tickets_sold, proceeds_accum)`
- `SalesClosed(event_version, event_category, id, total_tickets, timestamp, closing_block)`
- `VrfRequested(event_version, event_category, id, request_id, payload_hash, schema_version, max_gas_limit, max_gas_price)`
- `VrfFulfilled(event_version, event_category, id, request_id, payload_hash, attempt, proof_hash, seed_hash)`
- `WinnerComputed(event_version, event_category, id, batch_no, assigned_in_batch, total_assigned, winners_batch_hash, checksum_after_batch)`
- `PayoutBatch(event_version, event_category, id, payout_round, winners_paid, prize_paid, operations_paid, timestamp)`
- `PartnerPayout(event_version, event_category, id, partner_addr, payout_slot_code, asset_type_code, amount, payout_nonce)`
- `LotteryFinalized(event_version, event_category, id, archive_slot_hash, primary_type, tags_mask)`
- `LotteryCanceled(event_version, event_category, id, reason_code)`
- `PurchaseRateLimitHit(event_version, event_category, id, signer, limit_code)`
- `SalesGraceRejected(event_version, event_category, id, signer, submitted_at)`
- `AutomationDryRunPlanned(event_version, event_category, action_hash, executes_after_ts)`
- `AutomationCallRejected(event_version, event_category, action_hash, reason_code)`
- `AutomationKeyRotated(event_version, event_category, new_key_hash)`
- `PriceFeedUpdatedEvent(event_version, event_category, asset_id, price, decimals, updated_ts)`
- `PriceFeedFallbackEvent(event_version, event_category, asset_id, fallback_active, reason)`
- `PriceFeedClampEvent(event_version, event_category, asset_id, old_price, new_price, threshold_bps)`
- `VrfGasBudgetLow(event_version, event_category, id, remaining_budget)`
- `VrfRequestsPausedByDeposit(event_version, event_category, effective_balance, minimum_balance)`
- `RefundBatchStarted(event_version, event_category, id, batch_no, total_refunds)`
- `RefundBatchCompleted(event_version, event_category, id, batch_no, processed_refunds)`
- `RefundSlaBreached(event_version, event_category, id, breached_metric)`
- `GarbageCollected(event_version, event_category, id, reclaimed_slots)`
- `ArchiveDualWriteCompleted(event_version, event_category, series_code, run_id)`

События должны обеспечивать трассировку «розыгрыш ↔ VRF ↔ победители» для аудиторов и фронтенда. Каждое событие включает базовые поля `event_version` и `event_category` (Sales/VRF/Draw/Payout/Admin), что упрощает группировку на индексаторах. Поля с суффиксом `_code` используют короткие числовые/байтовые идентификаторы вместо строк, уменьшая газовые затраты и нагрузку на индексаторы. Поле `event_version` позволяет эволюционировать формат без ломки парсеров: изменения происходят через инкремент версии и описание миграции в `docs/handbook/reference/events.md`. Поле `payout_nonce` соответствует `payout_round` и обеспечивает защиту от повторных выплат.

### 3.5 Хранение истории и пользовательские представления
- **Ончейн-архив.** При переходе в состояние `Finalized/Archived` формируется `LotterySummary`, который переносится в постоянный ресурс (рабочее название — `lottery_multi::history::LotteryHistoryArchive`). В таблице `table<u64, LotterySummary>` хранятся обязательные поля: `id`, `status`, `event_slug`, `series_code`, `run_id`, `tickets_sold`, `proceeds_accum`, `vrf_status`, `primary_type`, `tags_mask`, `snapshot_hash`, `slots_checksum`, `winners_batch_hash`, `checksum_after_batch`, `payout_round`, временные метки `created_at/closed_at/finalized_at` и агрегированные суммы выплат. Этот минимум гарантирует, что фронтенд и аналитика смогут восстановить историю без дополнительных запросов.
- **Чанки билетов и индекс пользователей.** Продажи внутри активной лотереи складываются в чанки (`TicketChunk`) фиксированного размера, а для быстрого доступа фронтенда ведётся `table<address, vector<UserTicketRef>>`, где `UserTicketRef` содержит ID лотереи, номер чанка и локальный индекс билета. При финализации нужные ссылки копируются в архив, чтобы личная история не пропадала после очистки рабочего состояния. Для экономии газа предусматривается механизм «lazy cleanup», когда устаревшие чанки удаляются по мере переноса в архив.
- **Избыточные индексы и обслуживание.** Чтобы избежать разрастания таблиц, каждая лотерея имеет лимиты `max_chunks`, `max_user_refs` и счётчик «грязных» записей. AutomationBot периодически выполняет процедуру `defragment_user_index`: объединяет малозаполненные чанки, удаляет пустые ссылки и переносит переполненные записи в off-chain кеш (с фиксацией хэша в событии `UserIndexSnapshot`). При превышении лимитов продажа новых билетов блокируется `abort(E_INDEX_SATURATED)`, а фронтенд показывает требование дождаться обслуживания. В документации описывается план эвакуации данных в случае приближения к лимиту газа/памяти, а также стратегия дефрагментации по расписанию, чтобы поддерживать постоянное время выборок.
- **События как неизменяемый журнал.** Архив дополняется событиями `LotteryFinalized`, `PayoutBatch`, `PartnerPayout`, `WinnerComputed`, что позволяет внешним индексаторам и фронтенду поддерживать собственные БД/кеши без потери проверяемости и всегда сверять данные с ончейн-источником. В документе нужно хранить описание форматов событий, чтобы аналитики могли настроить парсеры без изучения кода.
- **Pagination и сортировка.** Все view возвращают данные с пагинацией `from/limit` и стабильной сортировкой: для глобальных списков — `id DESC`, затем `status`, затем `created_at`; для пользовательских историй — по паре `(lottery_id DESC, local_index DESC)`. Такие правила фиксируются в документации и дублируются тестами.
- **View-функции для фронтенда.** Модуль `lottery_multi::views` предоставляет выборки `get_lottery_summary(id)`, `get_lottery_status(id)` (компактный агрегат `status`, `tickets_sold`, `proceeds_accum`, `vrf_status`, `primary_type`, `tags_mask`), `get_lottery_badges(id)` (возвращает `(primary_type, tags_mask)` для бейджей и подсветки на фронтенде), `get_badge_metadata(primary_type, tags_mask)` (JSON-описание бейджа без хардкода на фронте), `accounting_snapshot(id)` (возвращает агрегированные суммы `total_sales`, `total_allocated`, `total_prize_paid`, `total_operations_paid`, `jackpot_allowance_token`), `list_lotteries(status, from, limit)`, `list_by_primary_type(primary_type, from, limit)`, `list_by_tag_mask(tag_mask, from, limit)` (возвращает ID лотерей, где `(tags_mask & tag_mask) != 0`), `list_by_all_tags(tag_mask, from, limit)` (возвращает ID, удовлетворяющие `(tags_mask & tag_mask) == tag_mask`), `get_user_participation(addr, from, limit)`, `get_user_rewards(addr)` и `get_partner_allowance(addr)`. Все списки следуют стабильной сортировке `id DESC` и пагинации `(from, limit)`.
- **Валидация конфигураций.** `views::validate_config` и любые функции редактирования конфигурации вызывают `tags::validate` и проверяют согласованность с capability инициатора: для партнёров — вхождение `primary_type` в белый список и принадлежность всех битов `tags_mask` разрешённой маске.
- **Контроль согласованности.** `UserTicketRef` содержит `snapshot_hash` и `ticket_local_index`. Если фронтенд обнаруживает расхождение хэша с актуальным архивом, он инициирует процедуру восстановления (запрос по событиям) и сообщает об этом пользователю.

### 3.6 Управление способностями (capabilities)
- **Сохранение текущих инвариантов.** Существующие пакеты (`lottery_core::LotteryRounds`, `lottery_core::Treasury`, `lottery_support::History`)
  уже опираются на выдачу и возврат возможностей (`HistoryWriterCap`, `AutopurchaseCap`, `LegacyMigrationCap`). В новом пакете необходимо
  не только переиспользовать эти механизмы, но и явно зафиксировать, какие capabilities требуются каждому подсистемному модулю.
- **Новые capabilities для мультираундовой логики.** Планируется ввести отдельные возможности `LotteryAdminCap` (создание/настройка
  розыгрышей), `PayoutBatchCap` (инициация батчевых выплат) и `ArchiveWriterCap` (публикация сводок в `LotteryHistoryArchive`). Эти ресурсы
  хранятся в контроллере пакета и выдаются только тем операциям, которые должны выполнять чувствительные действия.
- **Совместимость с текущими пакетами.** `lottery_multi` получает доступ к существующим возможностям через контроллер `lottery_core`:
  функции выпуска/возврата capabilities остаются точкой интеграции, чтобы избежать конфликтов при миграции. Для утилит поддержки
  предусматриваем функции `borrow_history_cap_or_abort`, `try_borrow_autopurchase_cap`, аналогичные имеющимся, но учитывающие множественность
  активных лотерей.
- **Учёт в плане миграции.** В разделе миграции нужно заложить шаги по передаче существующих capabilities новому контроллеру (`lottery_multi::controller`)
  и по тестированию сценариев утраты/восстановления возможностей. Дополнительно следует расширить тесты (`lottery_support/tests`) кейсами на
  одновременную работу нескольких капабилити, чтобы гарантировать отсутствие дедлоков и утечек.

### 3.7 Иерархия ролей и управление доступом
- **Базовая матрица ролей.** В системе закрепляется иерархия `RootAdmin → OperationalAdmin → PartnerOperator`, дополненная сервисными и
  наблюдательными ролями. Роль пользователя по умолчанию (`User`) ограничена публичными `entry`-функциями (покупка билетов, запрос view) и не
  получает никаких capability. Все остальные роли выдаются и отзываются ончейн через `RoleRegistry`.
- **Роль `RootAdmin` (RootAdminCap).**
  - **Полномочия.** Единственная capability с правом чеканки/отзыва всех остальных капабилити (`mint_*`, `revoke_*`), управления глобальными
    флагами (`pause_new`, `pause_payouts`, `emergency_stop`), утверждения новых пресетов конфигураций и ручного распределения лимитов между ролями.
  - **Ограничения.** Капа хранится на выделенном административном кошельке; все вызовы, требующие `&RootAdminCap`, сопровождаются событием
    `AdminAction`. На текущих этапах решения принимаются напрямую администратором, а переход к on-chain governance вынесен в поздний этап (см. Этап 7).
  - **Страховки.** Регламент в «книге проекта» требует дублирования критических транзакций (подтверждение во внутреннем журнале и уведомление
    оперативной команды), чтобы ручное управление оставалось контролируемым до запуска governance.
- **Роль `OperationalAdmin` (LotteryAdminCap + PayoutBatchCap + ArchiveWriterCap).**
  - **Полномочия.** Создание и активация лотерей в разрешённых сегментах, закрытие продаж, запуск VRF-запросов и батчей выплат, публикация
    архивов, пауза конкретных розыгрышей, запуск сценариев миграции. Все действия фиксируются событиями `AdminAction`/`PayoutBatch`.
  - **Ограничения.** Каждая capability несёт `vector<LotteryScope>` и квоты `max_open`, `max_batch_size`, `remaining_budget`. Попытка выйти за
    лимиты приводит к `abort`. Операторы не имеют доступа к глобальным хранилищам (`JackpotVault`, системные настройки), не могут чеканить
    новые capability и не меняют пресеты конфигураций.
  - **Наблюдаемость.** План предусматривает ежедневные отчёты по использованию лимитов (`operational_usage_report`), которые фронтенд и
    аудиторы могут выгружать через view.
- **Роль `TreasuryCustodian` (TreasuryCap).**
  - **Полномочия.** Пополнение глобальных резервов (джекпот, операционный фонд, резерв развития), распределение средств между пулами и
    подтверждение крупных выводов в пользу партнёров.
  - **Ограничения.** Capability содержит списки разрешённых активов и суточные/месячные лимиты. Любой перевод требует совпадения с
    утверждённым бюджетом и дублируется событием `TreasuryMovement`. Капа не даёт доступа к созданию лотерей или управлению статусами.
  - **Страховки.** При попытке выйти за лимиты операция блокируется до ручного подтверждения `RootAdmin`; факт подтверждения публикуется
    отдельным событием `TreasuryOverride`. После запуска governance этот контроль будет перенесён в соответствующий процесс (см. Этап 7).
- **Роль `PartnerOperator` (PartnerCreateCap + PartnerPayoutCap).** Уже описана в разделе 4.C; этот пункт делает ссылку на строгую привязку к
  `PartnerVault`, пресетам конфигураций и rate-limit’ам. Партнёр не видит и не модифицирует системные ресурсы, а любое действие вне
  собственной песочницы немедленно останавливается проверками capability. Создание розыгрышей выполняется только через фронтенд-
  панель партнёра: UI выводит утверждённые шаблоны (basic, split, nft и т.п.), разрешённые значения базовых параметров (стоимость
  билета, окно продаж, количество победителей) и автоматически подписывает транзакцию `create_from_template`. Клиент обязан
  проверять лимиты песочницы до отправки транзакции, а контракт повторно валидирует шаблон и параметры по capability. Панель не
  показывает скрытых полей — партнёр выбирает только допустимые опции и видит оставшиеся квоты (`allowance`, `max_parallel`, лимит
  VRF-запросов) в режиме read-only.
- **Роль `AutomationBot` (AutomationCap).**
  - **Полномочия.** Выполнение повторяющихся задач: автозакрытие продаж, повторный запуск VRF, проведение батчей выплат по расписанию,
    технический мониторинг лимитов.
  - **Ограничения.** В capability хранится расписание (`cron_spec`), список разрешённых процедур и счётчик попыток. Бот не может создавать
    или отменять лотереи, запускать выплаты вне заявленных батчей и не имеет доступа к партнёрским пулам. Rate-limit проверяется на каждый
    тип действия.
  - **Аудит.** Каждая операция порождает `AutomationTick` с параметрами выполнения, а отклонения/ошибки логируются как `AutomationError`. Для безопасного тестирования предусмотрен `automation::dry_run(view)`, который возвращает план действий без отправки транзакций.
- **Роль `AuditObserver` (AuditViewCap).**
  - **Полномочия.** Read-only доступ к агрегированным архивам, конфигурациям, логу выплат и статистике резервов для проведения регулярных
    аудитов.
  - **Ограничения.** Capability позволяет только чтение; попытка вызвать функции, требующие записи, завершается `abort`. Наблюдатели не
    видят приватных off-chain данных, а их запросы логируются событием `AuditAccess`.
- **Дополнительные сервисные роли.**
  - `SupportAgent` — ограниченная capability для открытия/закрытия тикетов поддержки, участия в процедурах рефанда и публикации сообщений в
    публичные каналы. Капа содержит `ticket_scope`, `max_refund_amount` и `escalation_required_above`; превышение порогов требует участия
    `OperationalAdmin`. Денежные операции или изменение конфигураций недоступны.
  - `NotificationBot` — сервис отправки уведомлений; capability разрешает ставить события в очередь (`NotificationQueued`) в пределах суточного
    лимита и контролирует шаблоны сообщений (`template_whitelist`). При превышении лимита бот блокируется до следующего окна.
- **Распределение capabilities и хранение ограничений.** Все перечисленные капабилити реализуются как структуры с `drop | store`, содержащие
  параметры scope/лимитов. `RoleRegistry` хранит `table<address, RoleSlot<T>>` для каждого типа инициализированной capability. Любая entry-
  функция начинает выполнение с проверки `roles::borrow_*_cap_or_abort(&signer)`; отсутствие записи или истечение `expires_at` приводит к
  `abort`. На уровне типов предусмотрены дополнительные поля:
  - `LotteryAdminCap` — `vector<LotteryScope>`, `max_open`, `max_config_version` (нельзя создавать лотереи на неподдерживаемой версии).
  - `PayoutBatchCap` — `max_batch_size`, `remaining_budget`, `cooldown_secs` между батчами, `last_nonce` и `nonce_stride` для контроля идемпотентности.
  - `TreasuryCap` — `asset_whitelist`, `daily_cap`, `monthly_cap`, `requires_root_admin_above` (порог, после которого требуется ручное подтверждение `RootAdmin`; перевод этого контроля в governance запланирован на Этап 7).
  - `AutomationCap` — `cron_spec`, `allowed_actions`, `max_failures`, `expires_at`.
  - `AuditViewCap` — `allowed_reports`; rate-limit для чтения фиксируется на уровне индексаторов и backend-шлюза, на ончейне хранится только признак допуска.
  - `PartnerPayoutCap`/`PartnerCreateCap` — см. раздел 4.C (песочница, allowance, пресеты, VRF-квоты).
- **Модель доверия и аудит.** Все операции, выполняемые с чувствительными capabilities (создание лотереи, резервирование джекпота, выдача
  призов), обязаны публиковать события (`AdminAction`, `PartnerPayout`, `TreasuryMovement`, `AutomationTick`). Фронтенд, индексаторы и
  аудиторы используют их для построения журналов действий. Дополнительно предусмотрена агрегированная view `roles::get_activity_log` с
  хэшами событий для быстрой сверки.
- **Ревокация, паузы и истечение сроков.** В план включены функции `revoke_*` для всех capability и глобальные флаги (`pause_new`,
  `pause_payouts`, `pause_partner(partner)`), которые доступны `RootAdmin`. Каждая capability содержит `expires_at`; по наступлении срока
  `RoleRegistry::cleanup_expired` удаляет записи и эмитирует `RoleExpired`. Это обеспечивает автоматическое прекращение прав без участия
  оператора.
- **Персональные rate-limit.** Чувствительные entry-функции (`create_from_template`, `request_vrf`, `payout_batch`) дополнительно проверяют `rate_limit_per_signer`, который хранится в `RoleSlot`. Попытка превысить лимит приводит к `abort(E_RATE_LIMIT)`, а события `RateLimitHit` помогают автоматизации диагностировать неверные конфигурации.
- **Безопасные сценарии по партнёрам.** Партнёры регистрируют `PartnerVault`, подтверждаемый `RootAdmin`. Выдача приза требует активного
  `PartnerPayoutCap`, положительного остатка и валидного пресета; транзакция публикует событие расхода и обновляет статистику партнёра, что
  позволяет пользователям проверять дисциплину выплат.

#### 3.6.1 FeatureSwitch и премиальные возможности
- **Назначение.** Чтобы гибко включать/отключать функции и ограничивать их премиальными подписками, вводится модуль `lottery_multi::feature_switch` с ресурсом `FeatureSwitchRegistry`. Он хранит `table<u64, FeatureGate>`, где `FeatureGate` содержит идентификатор функции, режим (`Disabled`, `EnabledAll`, `PremiumOnly`), ссылку на текущую версию конфигурации и временные ограничения (`not_before`, `expires_at`). По умолчанию все новые функции создаются в режиме `Disabled` и явно активируются администратором.
- **Операции и события.** `RootAdmin` (на ранних этапах — вручную, позже через governance) использует функции `set_feature_mode`/`update_feature_window`, которые проверяют допустимость режима и публикуют событие `FeatureSwitchUpdated { feature_id, mode, actor, version }`. Любая попытка изменить режим вне разрешённого окна завершается `abort`. Все события агрегируются в view `get_feature_switch_log`, чтобы фронтенд и аудиторы могли отследить историю переключений. Дополнительно в реестре хранится флаг `force_enable_devnet`: в devnet/testnet-профилях он позволяет включить функцию в обход обычных процедур, но в mainnet этот флаг игнорируется и служит только для CI/QA.
- **Премиальный доступ.** Для адресов с платной подпиской выпускается ресурс `PremiumAccessCap` (структура с `tier`, `quota`, `expires_at`, `auto_renew`, `referrer`, `feature_allowlist`). Капабилити выдаётся `RootAdmin` через `mint_premium_cap` и хранится в `RoleRegistry` наряду с другими ролями. Поле `auto_renew` разрешает автоматическое продление при достаточном балансе, а `referrer` фиксирует, кто инициировал выдачу для построения партнёрских цепочек. Выдача, продление и отзыв сопровождаются событиями `PremiumAccessGranted` и `PremiumAccessRevoked`, содержащими адрес, уровень подписки и срок действия. Контракты и фронтенд обязаны проверять `expires_at`, `auto_renew` и остаток квоты перед использованием капы.
- **Гейт в entry-функциях.** Каждая функция, доступ к которой регулируется, начинает выполнение с вызова `feature_switch::ensure_enabled(feature_id, &signer)`. Внутри проверяется текущее состояние `FeatureGate`; если режим `Disabled`, происходит немедленный `abort` с кодом `E_FEATURE_DISABLED`. Для режима `PremiumOnly` дополнительно извлекается `PremiumAccessCap`; отсутствие или истечение капы порождает `abort(E_PREMIUM_REQUIRED)`. Для сценариев с расходованием лимита (например, ограниченное число премиальных вызовов в сутки) `PremiumAccessCap` включает счётчик `remaining_calls`, который уменьшает `ensure_enabled` и публикует событие `PremiumAllowanceUsed`.
- **Критические функции.** Для операций `purchase_ticket`, `close_sales`, `request_vrf` и `payout_batch` режим `Disabled` недоступен; остановка выполняется только через аварийные паузы. Допустимые `feature_id` объявляются в `feature_switch::const FEATURE_*`, а их перечень фиксируется в книге проекта, чтобы избежать расхождений между кодом и документацией.
- **Интеграция с фронтендом и документацией.** В «книге проекта» добавляется раздел `docs/handbook/governance/feature_switch.md` с описанием идентификаторов функций, уровней подписок и процедур продления. Фронтенд считывает состояния через view `get_feature_gate(feature_id)` и отображает предупреждения пользователям без подписки. Для тестовых окружений планируется утилита `feature_switch::set_dev_override`, позволяющая включать функции в devnet без влияния на боевую сеть.
- **Миграции и безопасность.** При деплое новой версии `lottery_multi` в шаги миграции включается синхронизация `FeatureSwitchRegistry` (заведение записей для новых функций, перенос счётчиков, проверка просроченных окон). Пакет тестов должен покрывать сценарии истечения сроков, попытки доступа без капы и изменение режима во время выполнения. В разделе управления рисками фиксируется требование: критические функции (покупка билета, VRF, выплаты) не должны попадать под `Disabled` без ручного подтверждения `RootAdmin`; логика аварийных пауз (`pause_new`, `pause_payouts`) остаётся отдельным слоем предохранения.

#### 3.6.2 Приоритеты пауз и проверок доступа
- **Слои остановки.** Все entry-функции проходят цепочку проверок в фиксированном порядке: (1) `emergency_stop` (глобальный флаг), (2) `pause_partner(address)` или другой точечный флаг роли, (3) `lottery.paused` (персональный флаг лотереи), (4) `FeatureSwitch`. Нарушение порядка запрещено lint-правилом в тестах (`assert_priority_order`), чтобы исключить обходы через разные комбинации флагов.
- **Единая точка управления.** Флаги хранятся в модуле `pause_center`: `emergency_stop` и карта `paused_roles` доступны только `RootAdmin`; `lottery.paused` устанавливается операторами с `LotteryAdminCap`; `FeatureSwitch` регулирует функциональные фичи. Каждое изменение публикует событие (`EmergencyStopToggled`, `RolePauseUpdated`, `LotteryPauseUpdated`, `FeatureSwitchUpdated`).
- **Реакция на конфликты.** Если одновременно активированы несколько слоёв, пользователю возвращается код ошибки слоя с наивысшим приоритетом, а в лог (`PauseConflictDetected`) записывается подробность комбинации. AutomationBot следит за конфликтами и при их появлении уведомляет операторов.
- **Тестовое покрытие.** Набор интеграционных тестов включает сценарии: (1) глобальная пауза блокирует все функции независимо от состояния остальных флагов, (2) разблокировка глобальной паузы возвращает систему к проверкам более низкого уровня, (3) партнёр не может обойти `pause_partner`, даже если `FeatureSwitch` в режиме `EnabledAll`.

- **Иерархия «мероприятие → серия → выпуск».** Каждая лотерея описывается тройкой `<event_slug>/<series_code>#<run_id>`:
  - `event_slug` — человекочитаемый идентификатор мероприятия (например, `supra-summit`, `daily-draw`, `community-week`). Формируется из
    латинских букв/цифр и дефисов, хранится в `Config` и публикуется в событиях `LotteryCreated`/`LotteryFinalized`.
  - `series_code` — короткий код типа розыгрыша внутри мероприятия (`main`, `daily`, `jackpot`, `vip`). Он позволяет оператору вести
    параллельные подсерии с разными правилами и облегчает фильтрацию во фронтенде.
  - `run_id` — монотонно растущий числовой идентификатор конкретного запуска внутри пары `<event_slug, series_code>` (например, `#042`).
    Генерируется `lottery_factory` при создании, хранится в счётчике серии и гарантирует уникальность сочетания `event_slug/series_code/run_id`
    без необходимости глобального инкремента по всем сериям.
- **Текущее соглашение по умолчанию.** На первом этапе `event_slug` фиксируется значением `lottery`, чтобы фронтенд мог группировать все
  розыгрыши в разделе «Лотереи». Формат остаётся расширяемым: при появлении других типов мероприятий (турниры, кампании) будет достаточно
  добавить новые значения первого уровня без пересмотра кода и данных.
- **Системные ограничения.** В план включаем проверку: общая длина строкового идентификатора ≤ 96 байт, `event_slug` и `series_code`
  валидируются на допустимые символы (регулярное выражение `[a-z0-9-]+`). Это предотвращает переполнение событий и упрощает индексацию.
- **Отражение во фронтенде и истории.** Архив `LotteryHistoryArchive` хранит структурированные поля (`event_slug`, `series_code`, `run_id`),
  а фронтенд отображает собранный alias, например `community-week/main #012`. Для пользовательской истории допускается группировка по
  `event_slug` с раскрытием всех выпусков.
- **Связь с наградами и джекпотом.** При резервировании призов в событиях `PrizePlan` дополнительно публикуется alias лотереи, чтобы
  операторы могли прозрачно выделять джекпот под конкретную серию и выпуск.

### 3.8 Зависимости модулей и критический путь
- **Связи между модулями.**
  - `registry` зависит от `roles` (проверка капабилити), `economics` (резервы/allowance), `history` (архивирование) и `views` (агрегаты для фронтенда).
  - `sales` вызывает `registry` (статус `Active`, лимиты пользователей), `economics` (начисление долей), `history` (события продаж) и `views` для обновления индексов.
  - `draw` использует `registry` (снапшот и статусы), адаптер `supra_vrf` (формирование payload/валидация), `roles` (кто может повторить запрос) и `history` (`VrfRequested`/`VrfFulfilled`).
  - `payouts::compute_winners_admin` читает `draw` (payload и статусы VRF), `sales` (владельцев билетов) и `history` (курсоры), формирует чанки победителей и события `WinnersComputed`.
  - `payouts` требует административных capabilities, взаимодействует с `economics` (учёт выплат), `history` (логирование батчей) и `views` (агрегаты для фронтенда).
  - `history` подписывается на события всех модулей, но его сбой не должен блокировать core-потоки — запись событий оформляется как побочный эффект с минимальным газом.
  - `views` работают только в режиме чтения, используют `borrow_global` без `*_mut`, чтобы исключить блокировки и deadlock-сценарии.
- **Критический путь исполнения.** Основная последовательность розыгрыша: `sales → closing (snapshot) → draw (VRF) → compute (payouts) → payouts (выплаты) → archive`. В «книге проекта» требуется диаграмма зависимостей и критического пути; каждый модуль обязан ссылаться на эту схему, чтобы разработчики и аудиторы видели, где может возникнуть риск остановки.
- **Контроль целостности зависимостей.** В CI добавляется проверка, запрещающая появление циклических `use` между модулями `registry`, `sales`, `draw`, `payouts`, `history`, `views`, `roles`, `economics`. Любые новые связи оформляются через отдельные bridge-модули и описываются в документации перед мерджем. Отдельно фиксируется правило: пакеты `lottery_core` и `lottery_rewards` не должны импортировать `lottery_multi`; интеграция допускается только в сторону нового пакета через мосты `reward_bridge`/`history_bridge`, что предотвращает замыкание зависимостей.

## 4. Дополнительные требования, которые нужно учесть заранее
1. **Лимиты хранения.** Каждое `Lottery` может содержать до нескольких тысяч билетов, поэтому список билетов должен храниться в компактном виде (например, `vector<address>` + индексация через `table::Table<u64, TicketChunk>`). Необходимо прописать политику очистки после архивирования и лимиты на размер чанка.
2. **Параллельные VRF-колбэки.** Предусмотреть очередь обработчиков, чтобы одновременные ответы не блокировали друг друга и не приводили к конфликту `pending_request`. План должен описать, как распределяются повторные вызовы и как ведётся журнал попыток.
3. **Обновление CLI/скриптов.** Python-утилиты (`supra/scripts`) нужно адаптировать к новым видам запросов, добавить команды для управления множеством лотерей (создание, пауза, батчи выплат, архив). В документации указать новые флаги и параметры.
4. **Backfill истории.** Разработать миграцию, которая перенесёт данные из `lottery_support::History` в новую модель или отметит старые розыгрыши как архив. Требуется пошаговый сценарий миграции с оценкой газа.
5. **Аудит газовых лимитов.** Заранее определить верхние пределы размера батча и допустимого числа победителей, чтобы гарантировать выполнение транзакций с запасом. План должен включать таблицу «операция → ожидаемый gas usage → лимит».
6. **Повторные VRF-запросы.** Реализовать стратегию повторного запроса при истечении таймаута (dVRF 3.0 описывает очередь повторных попыток до 48 ч, см. `docs/dVRF_v3_checklist.md`). Нужно отразить состояние «ожидаем повтор» в `VrfState` и описать, кто может инициировать повтор.
7. **Индексация и фронтенд.** Обновить контракты событий так, чтобы индексаторы могли фильтровать лотереи по статусу. В план включить описание API для внешних сервисов и требования к адаптации раздела «История» на фронтенде.
8. **Роли и разрешения.** Определить права операторов: кто может создавать лотереи, кто запускает выплаты, кто отменяет. Нужно явно описать соответствие ролей (`RootAdmin`, `OperationalAdmin`, `PartnerOperator`, `AuditObserver`, `AutomationBot`, `TreasuryCustodian`) и их capabilities, включая процедуру выдачи и отзыва.
9. **Безопасность наград.** Проверка, что совокупные выплаты не превышают резервы (в т.ч. NFT), а джекпот не может быть зарезервирован дважды. Требуется инвариант в модуле учёта и автоматические проверки при создании/изменении конфигурации.
10. **Документация и runbook.** Реализовать предложенную серию материалов: завести «книгу проекта» (`docs/handbook/README.md`) с подразделами по архитектуре, ролям, контрактам и операциям, связать её ссылками из `README.md` и комментариев в коде, а также обновить существующие runbook'и (`docs/testnet_runbook.md`) под многолотовую модель. Книга создаётся на русском языке, при этом первое правило для контрактов — все комментарии внутри Move-модулей должны оставаться на английском, чтобы не провоцировать жалобы компилятора и поддерживать единый стиль.
11. **Миграция истории.** Разработать пошаговый план переноса данных из `lottery_support::History` в `LotteryHistoryArchive`. Отдельно описать сценарий, когда часть розыгрышей помечается как legacy и отображается во фронтенд-разделе «История» через вспомогательный индексатор, и указать, как фронтенд отличает legacy-данные от новых.
12. **Интеграция с партнёрами.** Для ролей `PartnerOperator` и `TreasuryCustodian` требуется описать процедуру регистрации `PartnerVault`, лимиты использования и порядок отчётности (события `PartnerPayout`).
13. **Совместимость с внешними аудиторами.** Предусмотреть роль `AuditObserver` с read-only доступом к архиву и специальными view-функциями, чтобы третьи стороны могли проверять честность без запросов к приватным данным.
14. **Наблюдаемость и оповещения.** Заложить требования к логированию и метрикам: события об ошибках VRF, паузах, превышении лимитов газа должны сопровождаться публикацией в отдельном канале (on-chain события + off-chain Webhook). В документации описать, какие показатели собираются (время ответа VRF, длительность батча выплат, объём неразобранных лотерей) и какие пороги срабатывания алертов обязательны для 24/7 мониторинга.
15. **Версионирование и миграции конфигураций.** Каждая лотерея должна хранить номер схемы конфигурации (`config_version`), чтобы при обновлении пакета можно было поэтапно мигрировать только новые розыгрыши. План должен включать сценарий «катящегося» деплоя: как выпускаются новые версии `lottery_multi`, как фронтенд и CLI определяют, какие функции доступны, и как обрабатываются legacy-инстансы без простоя. Дополнительно требуется синхронизировать on-chain версии с релизами репозитория и номерами Move-пакетов.
16. **Экономика комиссий и учёт доходов.** Необходимо зафиксировать правила распределения комиссий (операторские сборы, доля партнёров, процент на инфраструктуру) и описать инварианты, предотвращающие отрицательные балансы. В план нужно добавить требование вести агрегированную статистику по доходам/расходам (в архиве и off-chain отчётности), чтобы можно было проводить аудит выручки и выплат.
17. **Ончейн-губернанс и процедуры принятия решений.** План необходимо дополнить построением `RoleRegistry` поверх `RootAdminCap`, где ключевые изменения (параметры лотерей, выпуск новых capabilities, обновление глобальных флагов безопасности) проводятся через формализованные предложения. На текущем цикле решения принимаются вручную `RootAdmin`; описание модели голосования или мультисиг (например, N-of-M для состава операторов), перечня событий (`GovernanceProposalCreated`, `ProposalApproved`, `ProposalExecuted`) и регламента публикации решений в «книге проекта» выносится на отдельный Этап 7. Уже сейчас резервируем capability `ProposalCap`, который будет необходим для создания предложений после включения governance: его хранение и выдача фиксируются в `RoleRegistry`, но он не задействован до запуска процесса. Это обеспечит прозрачность для игроков и партнёров и снизит зависимость от единственного администратора после перехода к governance.
18. **Децентрализованный доступ и публичные интерфейсы.** Нужно определить официальный API для сторонних интеграций: перечень view-функций, REST/GraphQL-эндпоинтов и CLI-команд, правила аутентификации (подписи, API-токены), политику rate limiting и требования к логированию обращений. На текущем цикле фиксируем требования и угрозы; реализация и публикация API отнесены к позднему этапу (см. Этап 8), после завершения threat modeling и аудитов. В документе следует зафиксировать, какие данные доступны без доверия (через события и view), как внешние сервисы подписываются на обновления (WebSocket/Webhook), и каким образом capabilities ограничивают привилегированные действия.
19. **Ончейн-прайс-фиды и поддержка нескольких активов Supra.** Используем модуль `lottery_multi::price_feed` как обёртку над Supra Price Oracle. Реестр `PriceFeedRegistry` хранит `version`, таблицу фидов (ключ — `asset_id` типа `u64`) и три EventHandle (`PriceFeedUpdatedEvent`, `PriceFeedFallbackEvent`, `PriceFeedClampEvent`). Запись фида (`PriceFeedRecord`) включает цену в целочисленной форме, `decimals`, `staleness_window`, `clamp_threshold_bps`, признак fallback и активность клампа. Базовые константы — `DEFAULT_STALENESS_WINDOW = 300 сек`, `DEFAULT_CLAMP_THRESHOLD_BPS = 2_000`, предопределённые активы `ASSET_SUPRA_USD = 1`, `ASSET_USDT_USD = 2`. Любое обновление, регистрация и активация fallback сопровождаются событиями. Абсолютная смена цены свыше порога запускает `PriceFeedClampEvent` и устанавливает `clamp_active = true`, из-за чего боевые операции получают `abort(E_PRICE_CLAMP_ACTIVE)` до ручного разблокирования.
20. **Контроль VRF-депозита и газового баланса.** Supra уведомила, что при нулевом эффективном остатке депозита (`effective balance = 0`) новые VRF-запросы не обслуживаются даже при наличии «сырых» средств на аккаунте. План должен включать требования к мониторингу `minimum balance` и `effective balance`, автоматическому пополнению колбэк-депозита до порога (например, `minBalance × 1.2`) и runbook для ручного пополнения, чтобы не повторилась ситуация, когда при `total balance = 214.7484` и `minimum balance = 13271.4489` запросы блокируются. Необходимо определить ответственных, расписание проверок и события (`VrfDepositLow`), которые срабатывают при падении остатка ниже заданного порога.

### 4.A Комплексная безопасность и реагирование на инциденты
- **Регулярные проверки.** Планом предусмотрены цикличные аудиты: внутренний код-ревью перед релизом, затем внешний аудит пакета `lottery_multi` и вспомогательных модулей, а после запуска — публичная bug bounty. Каждое прохождение фиксируется в «книге проекта» и сопровождается чек-листом исправлений.
- **Процедуры реагирования.** Для критических находок описываем стандартный сценарий: активация `emergency_stop`, публикация уведомления, выпуск патча, проверка его on-chain и документирование в changelog. План требует готовых скриптов для быстрого включения/отключения продаж и выплат.
- **Pre-/post-deploy чек-листы.** Перед деплоем обязательно проходят `move check`, газовые тесты и обновление документации; после деплоя — сверка состояния лотерей, проверка метрик и подтверждение, что версии пакетов/конфигураций синхронизированы.
- **Защита транзакций выплат.** Каждая батчевая транзакция принимает `payout_round` (инкрементируемый счётчик) и публикует его в событии `PayoutBatch`. Повторное использование старого `payout_round` приводит к `abort(E_PAYOUT_REPLAY)`, что защищает от повтора транзакций.

### 4.B Экономическая модель и учёт потоков
- **Версионирование конфигураций.** В `LotteryShareConfig` и `AllocationRecordedEvent` должен храниться `config_version`, отражающий, какая схема распределения была активна при конкретном тираже. Это поддерживает аудит и связывает выплаты с релизами.
- **Агрегаты по пулам.** План предусматривает расширение `LotteryPool` полями `total_allocated`, `total_prize_paid`, `total_operations_paid`, а также view-функции для выгрузки статистики. Так фронтенд и отчётность получают данные без off-chain перерасчётов. Дополнительно вводится `jackpot_allowance_token` — счётчик, который уменьшает доступный остаток в момент резервирования призов и предотвращает двойное резервирование джекпота.
- **Профили получателей.** Получатели комиссий и долей джекпота описываются в реестре профилей с возможностью наследования значений по умолчанию и локального переопределения на уровне лотереи. Любое изменение сопровождается событием и проверкой лимитов.
- **Лимиты на бонусы.** Механизмы `OperationsBonusPaid` и `OperationsIncomeRecorded` дополняются бюджетами на период и требованием ручного подтверждения `RootAdmin` при превышении лимита. После запуска governance контроль планируется передать в соответствующий процесс (см. Этап 7).
- **Предложенное распределение продаж.** Базовая схема: 70 % в призовой пул текущей лотереи, 15 % в глобальный джекпот, 10 % на операционные расходы, 5 % в фонд развития/резерва. Значения хранятся в базис-пойнтах (10 000 = 100 %) и валидируются проверкой `Σ allocations == 10_000`, что избавляет от ошибок округления и упрощает тестирование.
- **Единая деноминация и коды ошибок.** Все денежные значения и события (например, `TicketPurchase`, `PayoutBatch`) публикуются в минимальной ончейн-единице SUPRA, чтобы исключить расхождения округлений. Для новых модулей создаётся `lottery_multi::errors` с перечислением `E_*`-кодов; документация и комментарии в коде ссылаются на этот модуль, а произвольные `abort` без ссылок запрещены lint-проверкой. В `docs/handbook/reference/errors.md` поддерживается таблица (hex-коды, описание, ответственный модуль) с зарезервированными диапазонами для `registry`, `sales`, `draw`, `payouts`, `history`, `views`, `roles`, `economics`, `feature_switch` и `tags`.

### 4.C Партнёрская роль: scoped capability и страховые механизмы
- **Выдача ограниченной capability.** Партнёр получает `PartnerCreateCap` со строгими параметрами: `allowed_event_slug`, список разрешённых `series_code`, `max_parallel` активных розыгрышей, `expires_at`, `allowed_primary_types` и `allowed_tags_mask`. Все ограничения проверяются при создании `Draft`: `primary_type` обязан входить в белый список, а `config.tags_mask & ~allowed_tags_mask == 0`. При попытке выхода за лимиты происходит `abort`.
- **Собственные источники наград.** Для каждого партнёра регистрируется `PartnerVault` (монеты) и `PartnerNftEscrow` (NFT). Партнёрские лотереи могут резервировать призы только из этих ресурсов; доступ к джекпоту или операционным средствам проекта запрещён на уровне типов. Попытка выбрать `PrizeSlot::FromJackpot` приводит к ошибке. `PartnerVault` хранит `last_payout_ts`; контракт запрещает новую выплату, если `now - last_payout_ts < partner_payout_cooldown`, предотвращая флуд-транзакции.
- **Шаблоны конфигураций.** Создание допускается только по утверждённым пресетам (`basic`, `split`, `nft`). Пресет содержит ограничители по `allowance`, `max_winners`, `max_ticket_price`, `max_duration`, `rng_count` и запрет `ticket_price == 0` (бесплатные билеты оформляются отдельным флагом `free_mint` с суточной квотой). Партнёр передаёт ссылку на пресет, а контракт сверяет, что параметры не выходят за рамки шаблона.
- **Ончейн-инварианты.** При создании проверяются условия: `sales_start < sales_end`, `winners_count > 0`, `max_tickets ≥ winners_count`, цена билета попадает в разрешённый диапазон, сумма долей + комиссий ≤ 100 %, а также `tags::validate` и соблюдение партнёрских масок. Перед активацией проверяется наличие достаточного резерва в `PartnerVault` и эскроу NFT (при `mint_on_claim=false`). Недостаток средств ⇒ автоматический `Canceled` и возврат билетов.
- **Газ и VRF.** Партнёр обязан пополнять депозит VRF-колбэка для своих розыгрышей (либо использовать квоту, выделенную оператором). Контракт отслеживает расход квоты, при превышении — блокирует новые запросы до пополнения.
- **Idempotency и изоляция.** VRF-колбэк партнёра только записывает `seed/proof`; вычисления и выплаты проводятся в батчах через отдельные функции, требующие `PartnerPayoutCap` и соблюдающие лимиты газа.
- **Управление рисками.** Предусмотрена двухэтапная активация: новые партнёры запускают розыгрыш как `Draft`, и только `OperationalAdmin` переводит его в `Active`. Дополнительно вводятся функции `pause_partner`, `revoke_partner_cap` и автоматическая экспирация `PartnerCreateCap`. Есть rate-limit на частоту `create` и VRF-запросов, чтобы исключить злоупотребления.
- **Аудит и прозрачность.** Все действия публикуют события `PartnerLotteryCreated`, `PartnerVaultReserved`, `PartnerPayout`, `PartnerCapRevoked` с указанием адреса и alias лотереи. View-функции `get_partner_stats` и `list_partner_lotteries` показывают пользователям и аудиторам историю розыгрышей и выплат. Фронтенд помечает такие лотереи бейджем «Partner» и отображает политику рефанда: при нехватке средств — автоматический возврат всем участникам.
- **Аудит и прозрачность.** Все действия публикуют события `PartnerLotteryCreated`, `PartnerVaultReserved`, `PartnerPayout`, `PartnerCapRevoked` с указанием адреса и alias лотереи. View-функции `get_partner_stats` и `list_partner_lotteries` показывают пользователям и аудиторам историю розыгрышей и выплат. Фронтенд помечает такие лотереи бейджем «Partner» и отображает политику рефанда: при нехватке средств — автоматический возврат всем участникам. Тесты проверяют, что попытка обойти ограничения путём комбинирования разрешённых тегов приводит к `abort(E_PARTNER_TAG_DENIED)` и событию `PartnerPresetViolation`.

### 4.D Сетевые и UX-аспекты
- **Мультисетевые профили.** Для devnet/testnet/mainnet заводятся отдельные наборы параметров (лимиты газа, цены билетов, расписание) и сценарии миграции. План требует таблицы соответствия и инструкций по переключению фронтенда.
- **Подключение кошельков.** В документации фиксируем поддерживаемые кошельки Supra, последовательность подписей и UX-подсказки по подтверждениям. Сервисные ошибки должны транслироваться в понятные пользователю статусы.
- **Кросс-сетевые переносы.** При апгрейде сети описывается порядок переноса незавершённых лотерей и архивов, чтобы пользователи не теряли историю; допускаются временные мосты или off-chain экспорт/импорт с проверками.

### 4.E Наблюдаемость и публичные статусы
- **Метрики.** Обязательные показатели с фиксированными именами: `lottery_active_count`, `tickets_sold_total`, `vrf_requests_inflight`, `vrf_fulfill_latency_ms`, `payout_batch_latency_ms`, `payout_backlog_count`, `partner_quota_remaining`, `effective_balance`, `min_balance_required`, `feature_mode{feature_id}`, `pause_flags{scope}`. Для каждого показателя указываются целевые диапазоны и обновляются в документации.
- **Алерты.** Настраиваются пороги и каналы уведомлений (Slack, Telegram, почта). Каждое срабатывание логируется и попадает в журнал эксплуатации, который хранится в `docs/handbook/operations/incident_log.md`.
- **SLO.** Базовые целевые значения: `VRF TTFB p95 < 5 минут`, `выплата призов p95 < 3 батчей`, `пауза партнёра снимается < 30 минут`, `effective_balance >= 1.2 × minimum_balance`. Нарушение SLO инициирует пост-мортем и обновление runbook.
- **Статусная страница.** План подразумевает запуск публичного статуса сервиса с историей инцидентов и текущим состоянием (продажи, VRF, выплаты). Ссылка на страницу добавляется в `README.md` и «книгу проекта».

### 4.F Стратегия данных и приватности
- **Политика конфиденциальности.** Определяем, какие данные собираются оффчейн (например, контакт партнёра), как они хранятся и как соответствуют требованиям GDPR/аналогичных норм. Политика публикуется в `docs/handbook/governance/privacy.md`.
- **Уведомления.** При изменении политики пользователи информируются через фронтенд и официальный канал, а согласие фиксируется событиями или off-chain логами.
- **Минимизация данных.** В ончейн-структурах используем только необходимые идентификаторы (адреса, хэши). На текущем цикле любые расширения данных проходят ручную проверку `RootAdmin`; перевод проверки в рамки governance запланирован на поздний этап (см. Этап 7).

### 4.G Комьюнити и поддержка
- **Каналы взаимодействия.** Планом закрепляются официальные площадки (Discord, Telegram, форум) и регламент публикации обновлений. Ссылки добавляются в `docs/handbook/frontend/community.md`.
- **Дорожная карта.** Публичная roadmap поддерживается в `docs/handbook/roadmap.md` и синхронизируется с релизами и `config_version`.
- **Обработка запросов.** Описывается SLA для обращений игроков и партнёров, шаблоны ответов и порядок эскалации в `RootAdmin`.
- **Обратная связь.** В событиях `FeedbackReceived` фиксируется обратная связь, которую можно анализировать off-chain.

### 4.H Пользовательские сервисы, социальные механики и маркетинг
- **Профили пользователей.** На ончейне заводится минимальный ресурс `UserProfile` (ник и ссылка на мультимедиа-аватар), который подписывается владельцем адреса и связывается с `UserParticipation`. Расширенные поля профиля (соцсети, биография, публичные ссылки) ведутся off-chain в сервисе профайлинга: он хранит хэши записей, публикует события подтверждения и даёт фронтенду единый API. При публикации результатов в архив `LotteryHistoryArchive` добавляются ссылки на профили, чтобы история и профили были связаны.
- **Личная история и шаринг.** Архив пользователя расширяется индексом `UserParticipation`, а фронтенд получает view-функции `get_user_profile(addr)` и `get_user_feed(addr, from, limit)`. Любой выигрыш или новое достижение сопровождается событием `UserHighlightPosted`, которое фронтенд может преобразовать в кнопку «Поделиться» (социальные сети, мессенджеры). Все операции шаринга фиксируются событиями без хранения чувствительных данных on-chain.
- **Социальный чат и лайв-фид.** Поверх событий лотерей строится WebSocket/GraphQL-шлюз, через который пользователи получают уведомления о новых розыгрышах, победителях и сообщениях чата. На цепочке записываются только хэши сообщений (`ChatMessagePosted`), а сами тексты хранятся в off-chain журнале с подписями участников, что обеспечивает проверяемость без перегрузки блокчейна.
- **Геймификация и удержание.** Ежедневные чек-листы и квесты оформляются как подписки на автоматизацию: пользователь подтверждает выполнение шага, событие `ChecklistStepCompleted` фиксирует прогресс, а на 7‑й день автоматически выпускается билет в отдельную серию. Достижения выдаются в виде NFT-бейджей через `lottery_rewards::NftRewards`; условия проверяются автоматизацией и событиями `AchievementUnlocked`. План автопокупки билетов хранится как on-chain ресурс `AutoPurchasePlan`, который исполняет `AutomationBot` в рамках лимита пользователя.
- **Реферальная программа и уведомления.** Таблица `ReferralLink` фиксирует связи `owner → invitee`, а события `ReferralConversion` подтверждают покупки приглашённых. Вознаграждения начисляются через выделенный пул комиссий и отображаются в профиле. Сервис уведомлений читает события `NotificationQueued` и доставляет сообщения через Telegram-бота, e-mail и push.
- **Клиентский сервис и локализация.** В «книге проекта» создаётся раздел `docs/handbook/frontend/support.md` с описанием SLA, процессов обработки тикетов и сценариев эскалации. Ончейн события `SupportTicketOpened`/`SupportTicketClosed` позволяют отслеживать прогресс обращений. Фронтенд расширяет i18n-настройки (`react-i18next`), чтобы интерфейс (история, чек-листы, поддержка) был минимум на русском и английском; тексты синхронизируются с документацией.
- **Брендинг и юридические артефакты.** В roadmap выделяется этап «Брендирование»: утверждение названия, логотипа, фирменного стиля и публикация промо-страницы. Юридические документы (лицензии, политика конфиденциальности, пользовательское соглашение) хранятся в `docs/handbook/governance/legal.md`, а обновления сопровождаются событиями `LegalDocVersionUpdated`, чтобы индексаторы отслеживали актуальные правила.

### 4.I Фронтенд-панели создания лотерей
- **Админская консоль.** Для ролей `RootAdmin` и `OperationalAdmin` проектируется отдельный интерфейс «Конструктор лотерей» с полным доступом ко всем параметрам конфигурации (`event_slug`, `series_code`, пресет призов, лимиты билетов, окна продаж, параметры VRF, `primary_type`, `tags_mask`). Панель подтягивает текущие `config_version`, позволяет собирать индивидуальные конфигурации, вызывает `lottery_multi::views::validate_config` и получает структурированный список нарушений (`error_code`, `field`, `hint`), который немедленно отображается в UI. Перед отправкой транзакции пользователь видит дифф по сравнению с утверждёнными пресетами и подтверждает изменения. Поддерживаются черновики: админ может сохранить Draft без публикации и вернуться к нему позже. Все действия завершаются транзакциями `create_custom_lottery`/`update_lottery_config`, подписываемыми кошельком администратора.
- **Партнёрский мастер.** Партнёры работают только через упрощённый мастер из заранее утверждённых шаблонов. UI показывает доступные пресеты, остаток квот (`allowance`, `max_parallel`, `expires_at`), доступные интервалы дат и автоматические ограничения (`max_ticket_price`, `max_duration`, допустимые `primary_type` и биты `tags_mask`). Перед отправкой транзакции `create_from_template` фронтенд выполняет локальную валидацию и вызывает view `get_partner_template_limits(partner)` для сверки лимитов; данные из view возвращаются в реальном времени и отображают текущее состояние песочницы. Если лимиты превышены или выбран недопустимый тег, интерфейс блокирует шаг и показывает ссылку на процедуру продления через `RootAdmin`; автоматизация через governance добавится на позднем этапе.
- **Единый backend API.** Обе панели используют один backend-шлюз (GraphQL/REST) для чтения вспомогательных данных (пресеты, словари серий, статистику партнёров). Шлюз не имеет права подписи — он лишь агрегирует публичные view и события (включая `get_lottery_badges`, `list_by_primary_type`, `list_by_tag_mask`, `list_by_all_tags`). Все транзакции формируются и подписываются на стороне клиента, что исключает появление «скрытых» действий.
- **Синхронизация с документацией.** Для каждой панели в «книге проекта» создаются отдельные руководства (`docs/handbook/frontend/admin_console.md`, `docs/handbook/frontend/partner_console.md`) с описанием UX-потока, проверок и ссылками на соответствующие разделы контрактов. Комментарии в функциях `create_custom_lottery` и `create_from_template` ссылаются на эти документы.

### 4.J Ончейн-прайс-фиды и многовалютная поддержка
- **Выбор источника.** Supra Price Oracle используется как основной поставщик цен: в `lottery_multi::price_feed` хранится реестр фидов (`SUPRA/USD`, `USDT/USD`, `PARTNER/USD` и т.п.), а доступ к значениям инкапсулирован в функции, проверяющие подписи валидаторов и свежесть данных.
- **Расширяемость и версии.** Реестр фидов хранит `version`; добавление нового актива на текущих этапах утверждается вручную `RootAdmin`, который вызывает `register_feed` и тем самым публикует `PriceFeedUpdatedEvent`. Партнёрские розыгрыши могут получать отдельные cap для регистрации собственных активов (событие `PriceFeedUpdatedEvent` с их `asset_id`), но только в пределах выданной capability; перенос процедуры в governance остаётся задачей позднего этапа.
- **Fallback и проверки.** Резервный агрегатор активируется через `set_fallback`, что приводит к `PriceFeedFallbackEvent(fallback_active=true)` и блокировке боевых операций (`E_PRICE_FALLBACK_ACTIVE`). Все финансовые операции проверяют `staleness_window` (по умолчанию ≤ 300 секунд); при устаревших данных вызывается `abort(E_PRICE_STALE)`. Для защиты от резких скачков применяется «кламп»: если `|Δ|` превышает `clamp_threshold_bps`, генерируется `PriceFeedClampEvent`, фид получает `clamp_active = true`, а операции завершаются `abort(E_PRICE_CLAMP_ACTIVE)` до ручной разблокировки. Таблица десятичных знаков описана в `docs/handbook/architecture/price_feeds.md`, что защищает от ошибок округления (например, $0.0099). Тесты покрывают границы округления и сценарии аномальных скачков.
- **Документация и фронтенд.** В «книге проекта» создаётся раздел `docs/handbook/architecture/price_feeds.md`, где описываются источники данных, требования к добавлению новых токенов и шаги для обновления конфигураций. Фронтенд отображает актуальные курсы и предупреждения о fallback, используя view-функции `get_price_feed(asset_id)` и события оракула.

### 4.K Управление VRF-депозитом и газовыми лимитами
- **Оперативный мониторинг.** Supra сообщила, что при падении `effective balance` до нуля новые VRF-запросы не принимаются, даже если на кошельке остаётся `total balance`. В инфраструктуру включаем периодическую проверку метрик `total balance`, `minimum balance`, `effective balance` и `window` через официальный API Supra, а также публикацию события `VrfDepositLow(id, effective_balance, minimum_balance)` при падении ниже порога `minBalance × safety_factor`.
- **Пополнение и runbook.** В `docs/testnet_runbook.md` и будущей «книге проекта» нужно описать процедуру ручного пополнения (`depositFundClient`) с расчётом суммы `minBalance = window × maxGasPrice × (maxGasLimit + verificationGas)` и рекомендацией держать запас ≥ 20 %. При срабатывании алерта автоматизация формирует транзакцию пополнения либо уведомляет `RootAdmin`/`TreasuryCustodian`. Для партнёров требуем подтверждение, что их `PartnerVault` покрывает потребности VRF.
- **Газовые лимиты колбэка.** При создании лотереи конфигурация хранит `callback_gas_limit` и `callback_gas_price`. Реестр VRF следит за расходом газа и уменьшает allowance при каждом fulfill. При приближении к лимиту инициируется событие `VrfGasBudgetLow`, чтобы админы успели обновить параметры или пополнить депозит.
- **Черновая таблица газовых профилей.** В приложении `docs/handbook/qa/gas_profiles.md` фиксируется таблица `операция → средний gas → верхний лимит`, обновляемая после каждого релиза. До запуска тестов таблица заполняется оценочными значениями: `request_vrf` ≤ 1200 gas, `on_vrf_fulfilled` (write-only) ≤ 1800 gas, `winner_compute_batch` на 1000 записей ≤ 4200 gas, `payout_batch` на 200 выплат ≤ 5000 gas. Эти ориентиры используются как чек-лист при code review и корректируются по мере появления фактических измерений.
- **Автоматические проверки.** `AutomationBot` добавляет задачу «проверить VRF-депозит» с периодичностью (например, каждый час). При выявлении нулевого `effective balance` бот блокирует новые `request_random` до пополнения, публикуя событие `VrfRequestsPausedByDeposit`. После успешного пополнения выполняется сценарий повторной активации с подтверждением в журнале.
- **Документация и ответственность.** В матрице RACI закрепляется ответственность DevOps за мониторинг и пополнение депозитов, RootAdmin — за утверждение лимитов, TreasuryCustodian — за перевод средств. В «книге проекта» создаётся отдельный раздел `docs/handbook/operations/vrf_deposit.md` с чек-листом и ссылкой на официальный канал Supra для уведомлений о изменениях требований по газу.

### 4.L Формальная верификация и Move Prover
- **Спецификации.** Для ключевых модулей `registry`, `economics`, `draw`, `payouts`, `history` и `feature_switch` добавляется папка `supra/move_workspace/lottery_multi/spec/` с `*.move`-спеками. В v1 уже заведены базовые инварианты для `types` (консистентность `VrfState` и хэшей курсора), `registry` (заморозка снапшота только после `Closing`), `economics` (неотрицательные остатки и контроль выделенных средств) и `payouts` (монотонный рост `total_assigned` и `payout_round`). Обязательные утверждения следующего этапа: (1) `snapshot_hash` и `slots_checksum` неизменны после установки `state.snapshot_frozen = true`; (2) `payout_round` строго растёт при каждом успешном батче выплат; (3) агрегированное `allocated_total` всегда ≥ `paid_total`; (4) `jackpot_allowance_token` никогда не увеличивается после резервирования (только уменьшается). Дополнительные свойства могут добавляться сверх этой базы, но эти четыре инварианта должны доказываться всегда.
- **CI-ворота.** В пайплайне GitHub Actions/CI добавляется шаг `move prove` по каждому изменённому модулю; PR не может быть смёрджен, пока все доказательства не проходят. Для тяжёлых спецификаций разрешён кэш доказательств; изменения в логике требуют обновления или пометки TODO с обоснованием и сроками закрытия.
- **Документация.** Раздел `docs/handbook/qa/move_prover.md` описывает структуру инвариантов, методику запуска `move prove`, а также список утверждений, которые покрывают бизнес-риски (двойная выплата, несогласованные балансы, переполнение allowance).

### 4.M Предохранители CI по размеру пакета и газу
- **Budget-файлы.** Для каждого модуля `lottery_multi` заводится бюджет размера (`MAX_BYTES`) и сохраняется в `supra/move_workspace/ci/budgets.toml`. Скрипт CI сравнивает фактический байткод с бюджетом и падёт сборку, если рост превышает 5 % без явного обновления бюджета. Это не позволит незаметно приблизиться к лимиту 60 000 байт.
- **Газовые снапшоты.** Тестовый сценарий `tests/gas_profiles.move` измеряет газ для ключевых `entry`-функций (`purchase_ticket`, `request_vrf`, `winner_compute_batch`, `payout_batch`). Результаты сохраняются в `tests/gas_snapshots.json`; при регрессии > 10 % CI требует согласования и обновления таблицы в `docs/handbook/qa/gas_profiles.md`.
- **Публикация зависимостей.** Скрипт `ci/check_publish_size.sh` проверяет сумму размеров пакетов и убеждается, что обновлённый workspace можно опубликовать в сеть Supra. Скрипт обязан запускаться перед каждым релизом и включён в чек-лист Definition of Done.
- **Size growth metric.** CI публикует метрику `size_growth_pct` (рост байткода относительно предыдущего релиза); если тренд превышает установленный порог (например, 2 % за релиз), задача попадает в бэклог оптимизации. Это позволяет отслеживать постепенное приближение к лимитам заранее.

### 4.N Защита от DoS при покупке и «честное закрытие» продаж
- **Анти-флуд лимиты.** `purchase_ticket` получает конфигурацию локальных ограничений: максимум билетов за транзакцию, максимум транзакций пользователя за блок и за rolling-окно (по умолчанию 5 минут). При превышении публикуется событие `PurchaseRateLimitHit { event_version, lottery_id, signer, limit_code }`, фронтенд показывает понятное сообщение, а контракт возвращает `abort(E_PURCHASE_RATE_LIMIT)`.
- **Fairness в конце окна.** Когда `now` приближается к `sales_window.end_ts`, автоматизация включает «grace window»: принимаются только транзакции, хэши которых уже находились в мемпуле до `end_ts`. Для новых попыток публикуется событие `SalesGraceRejected`. В документации фиксируется, как индексатор вычисляет попадание в grace (по полю `submitted_at`), чтобы участники не считали продажи несправедливыми.
- **Тесты и мониторинг.** В тестах моделируются всплески покупок, чтобы убедиться, что лимиты не мешают честным пользователям. Мониторинг собирает метрику `purchase_rate_limit_hits`, что позволяет реагировать на аномалии.

### 4.O Безопасность AutomationBot и управление ключами
- **Белый список вызовов.** `AutomationBot` работает только с заранее утверждённым списком call-targets (`auto_close`, `retry_vrf`, `defragment_user_index`, `top_up_vrf_deposit`). Любая попытка вызвать другую функцию приводит к `abort(E_AUTOBOT_FORBIDDEN_TARGET)` и событию `AutomationCallRejected`.
- **Таймлоки и dry-run.** Для чувствительных действий (`unpause`, `payout_batch`, `cancel_lottery`) вводится таймлок ≥ 15 минут: бот сначала публикует событие `AutomationDryRunPlanned { hash(plan) }`, спустя таймлок подписывает и отправляет транзакцию. Это даёт операторам время отменить действие. Для DevOps предусмотрен режим dry-run, возвращающий план действий без отправки транзакции.
- **Репутация автоматизации.** `AutomationBot` ведёт счётчик `success_streak` и `failure_count`, которые публикуются в событии `AutomationTick`. Governance (или RootAdmin до его запуска) может автоматически отключить бота, если `failure_count` превышает лимит, что защищает от сломанных сценариев.
- **Ротация ключей.** В операционном плане фиксируется периодическая смена ключей AutomationBot и резервный «break-glass» аккаунт с минимальными правами, который может остановить бота при компрометации. Все изменения ключей сопровождаются событием `AutomationKeyRotated` и записью в журнал.

### 4.P Рефанды, SLA и fallback_draw
- **Runbook отмены.** В `docs/handbook/operations/refund.md` описывается процедура `Canceled/Refund`: сроки запуска батчей (не позднее 24 ч после решения), размер партии (по умолчанию 200 выплат), события прогресса (`RefundBatchStarted`, `RefundBatchCompleted`) и отображение статуса во фронтенде. Коды причин отмены (`reason_code`) сопоставляются с человекочитаемой матрицей, которую видит пользователь.
- **Fallback draw.** Пока fallback отключён и функции `fallback_draw` завершаются `abort(E_FALLBACK_DISABLED)`. Одновременно документируется процедура, при которой `RootAdmin` может инициировать fallback: публикация `FallbackDrawProposed`, ожидание таймлока, предоставление доказательства честности (seed, внешнее свидетельство) и возможность для пользователей оспорить через обращение в поддержку. Реализация откладывается до появления governance, но документация готова заранее.
- **SLA уведомлений.** В разделе поддержки задаются сроки оповещения пользователей об отменах и рефандах (например, push/e-mail в течение 30 минут). AutomationBot формирует событие `RefundSlaBreached`, если дедлайны нарушены.

### 4.Q Управление юридическими ограничениями и соответствием
- **Юрисдикции и KYC.** В «книге проекта» заводится раздел `docs/handbook/governance/compliance.md`, описывающий запрещённые юрисдикции, требования KYC/AML для партнёров и текст предупреждений, которые фронтенд обязан отображать при входе пользователя.
- **Отказоустойчивость документации.** Все юридические документы версионируются (через `LegalDocVersionUpdated`) и имеют локализации. Изменение документа вызывает требование повторного согласия пользователя.
- **План компрометации.** Matrix доступа включает сценарий «утрата ключей RootAdmin/OperationalAdmin»: шаги по немедленной ревокации капабилити, активации `emergency_stop` и передаче управления «break-glass» аккаунту до восстановления контроля.

### 4.R Доступность (a11y), i18n и политика переводов
- **Требования a11y.** Фронтенд должен соответствовать WCAG 2.1 AA: отсутствие ловушек фокуса, достаточный контраст, поддержка клавиатурной навигации, aria-live для статусов VRF/платежей. В `docs/handbook/frontend/a11y.md` фиксируются чек-листы и ссылки на автотесты.
- **Политика переводов.** Ключи i18n хранятся в `frontend/src/i18n/keys.ts`; добавление строк напрямую в компоненты запрещено линтером. Перевод замораживается на момент релиза (`i18n-freeze.json`), а обновление словаря требует PR в документацию и синхронизацию с «книгой проекта».
- **Мониторинг локалей.** Автоматические тесты проверяют, что все ключи имеют переводы минимум на русском и английском, а отсутствующие значения вызывают падение CI.

### 4.S Управление хранением и сборка мусора
- **Квоты на структуру.** Каждая лотерея получает лимиты на количество чанков билетов, размер пользовательского индекса и глубину истории выплат. При достижении лимита продажа останавливается до завершения процедуры `GarbageCollect`. Событие `GarbageCollected { event_version, lottery_id, reclaimed_slots }` фиксирует объём освобождённых ресурсов.
- **Двойная запись при миграции.** Во время миграции на новый архив включается режим dual-write: данные пишутся и в старый `lottery_support::History`, и в новый `LotteryHistoryArchive`, пока индексатор не подтвердит совпадение хэшей. После каждого batched-записи выполняется автоматическая проверка `if archive_new.hash != archive_old.hash { abort(E_ARCHIVE_MISMATCH); }`, что предотвращает расхождение архивов. После успешной финальной сверки публикуется `ArchiveDualWriteCompleted` и старый путь выключается.
- **JSON-схемы view.** Для всех публичных view (`get_lottery_status`, `get_lottery_badges`, `list_by_primary_type`, `get_user_feed` и др.) описываются JSON Schema в `docs/handbook/frontend/schemas/`. Фронтенд и интеграторы валидируют ответы, что помогает ловить breaking changes до релиза.
## 5. Структура «книги проекта»

Цель — создать единое русскоязычное руководство по платформе Supra Lottery и обеспечить двусторонние ссылки между кодовой базой и документацией. Ниже — подробная структура, которой нужно следовать при заведении материалов в каталоге `docs/handbook`.

1. **Главная книга проекта (`docs/handbook/README.md`)**
   - Назначение: единая точка входа.
   - Краткое описание платформы, карта разделов, ссылки на базовые документы, глоссарий терминов и требования к обновлению документации.
   - На неё ссылаются корневой `README.md`, документация фронтенда и комментарии в контрактах.

2. **Архитектура и концепции (`docs/handbook/architecture/overview.md`)**
   - Общая схема компонентов (пакеты Move, off-chain сервисы, фронт).
   - Жизненный цикл лотерей, интеграция с dVRF, описание хранения данных и истории.
   - Подразделы: `state-model.md`, `vrf-integration.md`, `storage-and-history.md`.

3. **Роли и управление доступом (`docs/handbook/governance/roles.md`)**
   - Полное дерево ролей (RootAdmin, OperationalAdmin, PartnerOperator, AuditObserver, AutomationBot, TreasuryCustodian, User).
   - Таблицы с правами, требованиями и процедурами выдачи/отзыва капабилити.
   - Описание событий аудита и механизмов ограничения действий.

4. **Каталог контрактов (`docs/handbook/contracts/`)**
   - На каждый пакет Move — отдельный файл (`core.md`, `support.md`, `reward.md`, `lottery_multi.md`).
   - Для каждого модуля: назначение, ключевые ресурсы, публичные функции, ограничения, связанные события.
   - Переходы состояний, инварианты и зависимости от других модулей.
   - Комментарии в коде содержат ссылки на соответствующие разделы каталога.

5. **Каталог функций (`docs/handbook/contracts/<module>/functions.md`)**
   - Структура: «Название → Сигнатура → Назначение → Предусловия → Постусловия → Используемые события → Связанные правила».
   - Отдельные блоки для сценариев использования (пример вызова, необходимая роль/капа, типичные ошибки).

6. **Операционные процедуры (`docs/handbook/operations/`)**
   - Руководства для администраторов: запуск новой лотереи, закрытие продаж, обработка VRF, батч-выплаты, аварийная остановка.
   - Руководства для партнёров: подготовка призов, выдача наград.
   - Сценарии миграций и обновлений.

7. **Фронтенд и API (`docs/handbook/frontend/`)**
   - Спецификация раздела «История»: источники данных, используемые view-функции, формат отображения глобальной и персональной информации.
   - Раздел о REST/GraphQL/Websocket-интерфейсах ведётся в режиме будущей работы: фиксируем требования и связь с on-chain документами, а финальная спецификация публикуется только после выполнения этапа 7 (безопасность и аудит API).

8. **Тестирование и контроль качества (`docs/handbook/qa/`)**
   - Перечень обязательных тестов (юнит, интеграционные, газовые).
   - Чек-листы перед деплоем, требования к документации при внесении изменений.
   - Регламенты по обновлению разделов в случае изменения логики.

9. **Справочные материалы (`docs/handbook/reference/`)**
   - `glossary.md` — термины, обозначения, диапазоны параметров.
   - `diagrams/` — схемы состояний, последовательности VRF-процесса, отношения ролей.
   - `faq.md` — типовые вопросы по эксплуатации и архитектуре.

10. **Связи с кодом**
    - В корневом `README.md` и в заголовках модулей Move добавить ссылки на соответствующие разделы книги.
    - Комментарии над ключевыми функциями указывают на `contracts/.../functions.md#<anchor>`, чтобы разработчик сразу переходил к правилам использования.

Каждый раздел книги создаётся на русском языке, а комментарии в Move-контрактах остаются на английском, чтобы не вызывать предупреждений компилятора и поддерживать единый стиль исходного кода.

## 6. Следующие шаги (краткий обзор)

| Этап | Название (см. подробности в разделе 10)                 | Ключевые результаты и артефакты                                           |
|------|---------------------------------------------------------|----------------------------------------------------------------------------|
| 0    | Подготовительный                                         | RFC по структуре пакета, подтверждённые зависимости, словарь тегов.       |
| 1    | Фундамент: контракты и документация                      | Каркас `lottery_multi`, базовые view, русскоязычная «книга проекта», runbook VRF-депозита. |
| 2    | Инфраструктура, миграция, тестирование                   | План миграции, расширенные тесты, распределение ролей, мониторинг VRF-депозита. |
| 3    | Интеграции и пользовательские сервисы (ручное управление)| Требования к будущим API, проработка пользовательских сервисов и панелей, модуль `price_feed`, подготовка поддержки и брендирования, партнёрская модель. |
| 4    | Миграция и backfill                                      | Dual-write архивов, перенос истории, обновление CLI/фронтенда, назначение тегов по умолчанию. |
| 5    | Запуск ядра под управлением администратора               | Выдача capabilities, регламенты ручных решений, релиз и баг-баунти, операционные процедуры. |
| 6    | Пострелизная поддержка                                   | Наблюдаемость, статусная страница, отчёты по SLA и ретроспективы.         |
| 7    | Переход к on-chain governance                            | Проектирование governance, миграция ролей, обновление документации.       |
| 8    | Публичные API и внешние интеграции                       | Threat modeling, прототип защищённого шлюза, аудит и публикация спецификаций. |

> Документ остаётся рабочим черновиком: по мере проработки этапов сводная таблица и подробная дорожная карта будут уточняться.

## 7. Механизм версионирования и отслеживания истории
- **Git-релизы.** Каждое крупное обновление репозитория сопровождается тегом (`vYYYY.MM.patch`) и записью в `CHANGELOG.md`. План требует, чтобы в changelog фиксировались версии Move-пакетов, обновлённые разделы «книги проекта» и краткое описание затронутых ролей/процессов.
- **Move-пакеты.** В `SupraLottery/supra/move_workspace/Move.toml` для `lottery_multi` и зависимых пакетов поддерживаются явные номера версий. Публикация новой версии сопровождается RFC и указанием совместимых диапазонов версий зависимостей, чтобы сборка и деплой ссылались на корректные артефакты.
- **On-chain конфигурации.** Ресурс `Lottery` хранит поле `config_version`, а глобальный реестр — активную «схему» конфигурации. Новые розыгрыши получают последнюю версию, legacy-лотереи завершают цикл на прежних правилах. CLI и фронтенд обязаны проверять `config_version`, чтобы выбирать корректные функции и структуры данных.
- **Документация.** «Книга проекта» в `docs/handbook` ведёт историю версий: в каждом разделе размещается шапка с текущим номером версии и ссылкой на соответствующий релиз в Git. Любое изменение контрактов требует синхронного обновления раздела книги и фиксации версии в таблице «История обновлений».
- **Совместимость и мониторинг.** Автоматизация (боты, индексаторы) при запуске проверяют три слоя: git-релиз, версию Move-пакета и `config_version` активных лотерей. Несовпадение трактуется как требование к миграции и фиксируется событием `VersionDriftDetected { detected_layer, recommended_action }`, где `recommended_action` — enum (`PauseSales`, `AllowLegacy`, `ForceUpgrade`).
- **Несовместимые изменения layout.** Любое изменение структуры Move-ресурсов, несовместимое по layout/abilities, выполняется через введение новых ресурсов и явную миграцию (`migrate_vX_to_vY`). Прямое изменение существующих структур без миграции запрещено.
- **Будущая документация.** Дополнительно к текущему плану необходимо подготовить отдельный раздел в книге проекта (`docs/handbook/governance/versioning.md`), где будут описаны правила версионирования, матрица совместимости и история всех релизов. Фронтенд-раздел «История» должен ссылаться на этот документ, чтобы пользователи могли отследить изменения правил.

## 8. Технологический стек проекта
- **Ончейн-уровень (Supra AutoFi Stack).** Платформа строится на вертикально интегрированном стеке Supra 2.0, который объединяет
  нативные oracle-фиды, автоматизацию блокчейна и кроссчейн-месседжинг; эта модель официально позиционируется Supra как основа
  для AutoFi-приложений и подчёркивает необходимость держать логику лотерей как onchain-примитивы с прозрачными VRF-доказательствами.
- **Move-пакеты.** Базовые модули (`lottery_core`, `lottery_support`, `lottery_rewards`) остаются фундаментом, а новый пакет
  `lottery_multi` инкапсулирует ресурсы `Lottery`, архив, контроллер ролей и оркестрацию VRF. Дополнительно планируется модуль
  автоматизации для `AutomationBot`, отвечающий за плановые закрытия окон и запуск батчей выплат.
- **Оффчейн-утилиты и индексаторы.** Административные CLI-скрипты (Python) и сервисы мониторинга используют официальные Supra SDK
  для отправки транзакций, ведут учёт событий (через WebSocket/RPC) и наполняют кеши фронтенда. Для хранения производных данных
  допускаются SQL/TimeSeries-хранилища, но источником правды остаются onchain-ресурсы и события.
- **Фронтенд.** Клиентская часть реализована на React 18 с TypeScript 5, Vite 7 и Storybook 9; для состояния и запросов используются
  `@tanstack/react-query`, `zustand`, `react-router-dom`, а UI-компоненты строятся на Radix UI и Tailwind-экосистеме (`class-variance-authority`,
  `tailwind-merge`). Такой стек соответствует современной web3-практике Supra и обеспечивает быстрый рендер, модульность и
  интеграцию с i18n (`react-i18next`).
- **Тестирование и качество.** Фронтенд покрывается Vitest/Testing Library, бэкенд-скрипты — pytest/интеграционными сценариями,
  Move-модули — `move unit-test`. В CI закрепляем `move check`, линтеры ESLint/Prettier и статический анализ
  для контрактов и фронтенда.

## 9. Синтаксический аудит и требования Move
- **Актуальные пакеты и стиль кода.** Просмотрены основные модули (`lottery_core/sources/Lottery.move`, `LotteryRounds.move`,
  `Operators.move`, `Treasury.move`, `TreasuryMulti.move`, а также вспомогательные пакеты `lottery_support`,
  `lottery_rewards`, `lottery_factory`, `SupraVrf`). Все они используют стандартный синтаксис Move 1.8/1.9 без нестабильных
  конструкций и полагаются на `resolver = "v2"` в `Move.toml`.
- **Объявления и атрибуты.** Структуры снабжены способностями `has key | store | drop | copy` по необходимости, события помечены
  `#[event]`, а тестовые утилиты — `#[test]`/`#[test_only]`. Для публичных транзакционных функций используется стиль
  `public entry fun ... acquires Resource`, соответствующий требованиям Supra Move.
- **Присваивания и мутации.** В кодовой базе не используется `let mut`; мутация переменных выполняется через повторное
  присваивание (`x = ...;`) и работу с ссылками (`vector::borrow_mut`, `table::borrow_mut`). При разработке новых модулей нужно
  придерживаться того же подхода: объявление переменной делается один раз через `let`, последующие изменения — операторами
  присваивания без ключевого слова `mut`.
- **Циклы и управление потоком.** Используются стандартные `while`-циклы и `break` (см. `lottery_core/sources/LotteryRounds.move`
  и `Lottery.move`). Supra Move не поддерживает `continue`, поэтому логика пропуска итераций реализуется через условные блоки.
- **Обработка ошибок.** Базовые модули SupraLottery используют `assert!(условие, E_CODE)` с кодами ошибок вместо голого `abort`;
  новые компоненты `lottery_multi` должны сохранять тот же стиль, чтобы сообщения оставались компактными и единообразными.
- **Кодировка.** Весь исходный код, комментарии и документация должны сохраняться в UTF-8 без BOM. Это предотвращает появление «кракозябр» в Move-модулях и Markdown-файлах и обеспечивает корректную работу компилятора, линтеров и генераторов артефактов.
- **Глобальное состояние.** Все функции, которые читают/пишут глобальные ресурсы, явно перечисляют их в `acquires` и работают
  через `borrow_global[_mut]`. Это обязательное требование: пропуск `acquires` приводит к ошибке компиляции Move.
- **dVRF-специфика.** Колбэк `supra_vrf` ожидает сохранённый ранее хэш полезной нагрузки и проверку `rng_count`. При миграции
  в новый пакет нужно не только копировать логику из `core_main_v2`, но и удерживать синтаксический контракт с Supra
  (`module supra_addr::supra_vrf`), чтобы компиляция не падала из-за несовместимых сигнатур.
- **Рекомендация по проверке.** Перед реализацией новой логики запускать `move fmt` и `move check` внутри `SupraLottery/supra/
  move_workspace` — это быстрее выявит синтаксические ошибки, чем полный тестовый прогон. В план включить отдельную задачу на
  автоматический `move check` для нового пакета `lottery_multi` в CI.

### 9.1 Тест-матрица (минимальный набор)
- **Unit-тесты.** Создание/пауза/закрытие лотерей, лимиты на пользователя и общий лимит, пограничные значения временных окон; VRF-сценарии (одиночный колбэк, повторный, out-of-order, retry); расчёт победителей для 1, N-1 и N победителей при `winners_dedup=true/false`; валидация `lottery_multi::tags` (неизвестный `primary_type` → `abort`, корректный `TYPE_BASIC`/`tags_mask=0` → success); партнёрские ограничения по типам и тегам; газовые тесты на 10 000 билетов (≤ 80 % лимита); батчевые выплаты, повторный запуск того же батча (идемпотентность) и случаи исчерпания бюджета.
- **Property-based тесты.** Проверка неизменности результата при одинаковом `seed`, отсутствие дубликатов при `winners_dedup=true`, сохранение `slots_checksum` и `snapshot_hash` между вычислениями, стабильная сортировка и отсутствие пропусков при генерации выборок `list_by_primary_type`/`list_by_tag_mask`/`list_by_all_tags`. Дополнительно настраивается дифференциальный тест: on-chain алгоритм выбора победителей сравнивается с off-chain эталонной реализацией на наборе случайных `seed`, чтобы убедиться в полном совпадении индексов.
- **Интеграционные сценарии.** Партнёрские квоты и allowance, VRF-депозит и повторные запросы, backfill старой истории, миграция тегов (`TYPE_BASIC`, `tags_mask = 0`), аварийные паузы и восстановление, автоматические задачи `AutomationBot` (в том числе `dry_run`). Отдельно проводится fuzz-тест сериализации/десериализации ответов view (JSON Schema) и проверка dual-write при миграции архива.
- **Security-тесты.** Попытки реэнтранси (через внешние вызовы), replay выплат (`payout_round`), эскалация ролей, подмена payload VRF, атаки на rate-limit. Добавляется проверка: повторная отправка того же батча с тем же `payout_round` → `abort`, повтор с новым `payout_round`, но неизменённым набором записей → идемпотентный no-op. Для каждого сценария фиксируются ожидаемые коды из `lottery_multi::errors`.
- **Документация тестов.** Каждая группа тестов ссылается на соответствующий раздел «книги проекта»; при добавлении нового сценария обновляется таблица `docs/handbook/qa/test_matrix.md` с статусом покрытия.

## 10. Дорожная карта реализации (обязательные этапы)
- **Этап 0 — подготовительный.**
  - Подтвердить состав модулей `lottery_multi::{registry, views, history, roles, automation, economics}` и схему зависимостей.
  - Согласовать с командами фронтенда и DevOps формат событий, alias лотерей и список view-функций (зафиксировать протокол созвона в `docs/handbook/operations/meeting_notes.md`).
  - Выпустить RFC с описанием миграции и получить утверждение `RootAdmin`/губернанса.
  - Утвердить словарь классификаторов: значения `tags::TYPE_*`, доступные биты `tags::TAG_*`, требования к бейджам и отображению на фронтенде.
- **Этап 1 — инфраструктура пакета.**
  - Реализовать ресурсы `Lottery`, `LotteryRegistry`, `LotteryFactoryState`, `RoleRegistry` с минимальными проверками.
  - Поддержать создание/закрытие лотерей без VRF и выплат, убедившись, что архив и события генерируются корректно.
  - Настроить базовые view-функции (`get_lottery`, `list_active`, `get_lottery_badges`), интегрировать `move check`/`move unit-test` в CI.
  - Заложить каркас для Move Prover (`spec/` с шаблонными инвариантами) и подключить проверки размера пакета/газовых снапшотов к CI (бюджеты можно заполнить оценочными значениями).
- **Этап 2 — VRF и расчёт победителей.**
  - Перенести из `core_main_v2` механику формирования payload, проверки `rng_count`, хэширования и хранения `VrfState`.
  - Внедрить очередь повторных запросов и обработку колбэка без тяжёлых вычислений, добавить тесты на параллельные VRF.
  - Реализовать стадию `WinnerComputation` с батчами и проверить корректность `mod`-расчёта для произвольного числа билетов.
  - Описать и задокументировать справедливый алгоритм `draw_algo` (включая `stride`) и подготовить дифференциальные тесты с off-chain эталоном.
- **Этап 3 — выплаты и экономический учёт.**
  - Подключить `lottery_rewards::{Jackpot, Store, NftRewards}` через слой `economics`, реализовать распределение 70/15/10/5.
  - Добавить агрегаты `total_allocated`, `total_prize_paid`, `total_operations_paid`, настроить события `PayoutBatch` и `PartnerPayout`.
  - Написать интеграционные тесты на многослотные призы, партнёрские выплаты и лимиты `PartnerPayoutCap`.
  - Интегрировать партнёрские лимиты: пресеты, `max_parallel`, allowance, контроль депозитов VRF и публикацию `PartnerVaultReserved`.
  - Реализовать анти-DoS лимиты для `purchase_ticket`, события `PurchaseRateLimitHit`/`SalesGraceRejected` и отладить мониторинг `purchase_rate_limit_hits`.
- **Этап 4 — миграция и backfill.**
  - Заморозить текущий контракт, экспортировать историю (`lottery_support::History`) и импортировать в `LotteryHistoryArchive`.
  - Протестировать сценарий отката: в случае сбоя уметь восстановить старую модель без потери билетов и резервов.
  - Назначить для всех унаследованных розыгрышей `primary_type = tags::TYPE_BASIC` и `tags_mask = 0`, зафиксировать миграцию в событиях `LotteryFinalized`/`LotteryHistoryArchive`.
  - Обновить CLI/фронтенд, провести UAT со списком тестовых лотерей.
  - Запустить режим dual-write (старый и новый архив), подготовить JSON Schema для всех view и завершить миграцию после сверки хэшей (`ArchiveDualWriteCompleted`).
- **Этап 5 — запуск ядра под управлением администратора.**
  - Активировать `RoleRegistry`, выдать capabilities администраторам, партнёрам, аудиторам и автоматизации, закрепив ручное управление за `RootAdmin`.
  - Задокументировать регламенты ручных решений: как `RootAdmin` подтверждает операции сверх лимитов, как фиксируются overrides и как вести журнал `AdminAction`.
  - Выпустить релиз (`git tag`, обновление `Move.toml`, запись в «книге проекта»), провести баг-баунти и собрать обратную связь.
  - Настроить операционные процедуры: ротацию ключей AutomationBot, таймлоки для чувствительных действий, runbook компрометации и обновление разделов compliance/a11y.
- **Этап 6 — пострелизная поддержка.**
  - Настроить наблюдаемость, алерты и статусную страницу; убедиться, что метрики покрывают продажи, VRF, выплаты.
  - Обновить дорожную карту: определить следующие итерации (кастомные серии, дополнительные призовые механики).
  - Провести ретроспективу и зафиксировать уроки в `docs/handbook/operations/postmortems.md`.
  - Проверить SLA рефандов, уведомлений и работу анти-DoS лимитов, задокументировать результаты в отчётах эксплуатации.

- **Этап 7 — переход к on-chain governance (future update).**
  - Спроектировать и описать ончейн-процедуру принятия решений (мультисиг/голосование) для `RoleRegistry`, определить набор событий `GovernanceProposal`, `GovernanceVote`, `GovernanceExecuted`.
  - Подготовить миграционный план: как переводить существующие capability и лимиты из ручного режима в governance, какие таймлоки и пороги необходимы.
  - Обновить «книгу проекта», добавив разделы о governance, и провести аудит безопасности перед включением механизма.

- **Этап 8 — публичные API и внешние интеграции (future update).**
  - На основе собранных требований и угроз провести детальную проработку архитектуры API: threat modeling, выбор схем аутентификации, лимитов и аудита.
  - Реализовать прототип защищённого шлюза (REST/GraphQL/WebSocket) поверх публичных view, пройти внутренний и внешний аудит безопасности до публикации.
  - Обновить «книгу проекта» и фронтенд-документацию, подготовить SDK/CLI-примеры и только после этого открыть API для партнёров и сообщества.

## 11. Матрица ответственности (RACI)
| Подсистема / задача                               | Ответственный (R) | Согласование (A)                | Консультации (C)                        | Информирование (I)                 |
|---------------------------------------------------|-------------------|---------------------------------|-----------------------------------------------------|------------------------------------|
| Проектирование `lottery_multi::registry`          | On-chain команда  | RootAdmin (до Этапа 7)          | Frontend, DevOps                      | Партнёры, аудиторы                 |
| Архив и пользовательские view                     | On-chain команда  | OperationalAdmin Lead           | Индексаторы, Frontend                               | Support-команда                    |
| Экономика и распределение продаж                  | On-chain команда  | TreasuryCustodian               | Finance/Ops, PartnerOperator                    | RootAdmin, аудиторы                |
| Миграция истории и данных                         | On-chain команда  | RootAdmin                       | DevOps, Support                                     | Все заинтересованные стороны       |
| Управление capabilities и подготовка к governance | RootAdmin         | RootAdmin                       | OperationalAdmin, Legal                  | Партнёры, аудиторы                 |
| Публичные API (этап 8) и документация             | DevOps + DocsTeam | RootAdmin                       | Frontend, On-chain, Security           | Комьюнити, партнёры                |
| Фронтенд раздел «История»                         | Frontend команда  | Product Owner                   | On-chain, DocsTeam      | Пользователи, партнёры             |
| Мониторинг, алерты и статусная страница           | DevOps            | RootAdmin                       | On-chain, Frontend                                  | Все команды                        |
| Коммуникация с партнёрами и bug bounty            | Product/Community | RootAdmin                       | Legal, PartnerOperator    | Пользователи, аудиторы             |

## 12. Критерии приёмки и Definition of Done
- **Функциональные критерии.**
  - Не менее трёх параллельных лотерей могут находиться в разных стадиях (Active, AwaitingVRF, Payout) без блокировок.
  - Архив и view-функции позволяют восстановить историю любой лотереи и билетов конкретного пользователя, сверяя данные с событиями.
  - Распределение продаж автоматически отражается в агрегатах и соответствует настроенным долям.
  - Регламенты ручного управления описаны: `RootAdmin` может выдать/отозвать capability и зафиксировать событие без передачи приватных ключей команде. Подготовка on-chain governance выносится на Этап 7.
- **Нефункциональные критерии.**
  - Газовые лимиты всех `entry`-функций задокументированы, тесты подтверждают выполнение ≤ 80 % доступного лимита.
  - Метрики и алерты покрывают все критические пути (продажи, VRF, выплаты, миграции).
  - Документация («книга проекта») содержит актуальные описания модулей, функций, ролей и тестов; все ссылки из кода валидны.
  - Механизм версионирования задействован: релиз помечен тегом, обновлены версии пакетов и таблица совместимости.

## 13. Риски и меры снижения
- **Риск: превышение газовых лимитов при вычислении победителей.**
  - *Меры*: заранее определить максимально допустимый размер батча, внедрить адаптивную разбивку и стресс-тесты на ≥ 10 000 билетов.
- **Риск: рассинхронизация конфигураций между ончейн, фронтом и документацией.**
  - *Меры*: использовать обязательный чек-лист релиза, включающий обновление «книги проекта», `Move.toml` и фронтовых констант; автоматический `VersionDriftDetected` при несовпадении версий.
- **Риск: задержки VRF или отказ провайдера.**
  - *Меры*: реализовать очередь повторных запросов, тайм-ауты и алерты; предусмотреть ручной `fallback_draw` под контролем `RootAdmin` (до запуска governance на Этапе 7).
- **Риск: компрометация партнёрского адреса.**
  - *Меры*: лимитировать `PartnerPayoutCap` по суммам и времени, добавить мгновенную ревокацию и автоматический аудит транзакций.
- **Риск: сложность миграции и потеря истории.**
  - *Меры*: выполнять миграцию поэтапно (devnet → testnet → mainnet), хранить бэкапы, проводить dry-run с сохранением метрик.
- **Риск: отклонение команды реализации от плана.**
  - *Меры*: закрепить за каждым этапом ответственного, требовать письменного отчёта и обновления плана; использовать «книгу проекта» как единственный источник истины и запрещать внедрение функционала вне описанных требований без отдельного RFC.

## 14. Запреты и оговорки (чтобы избежать отклонений)
- Нельзя удалять или существенно изменять текущие модули `lottery_core`, `lottery_support`, `lottery_rewards` до завершения миграции и подтверждения архивов.
- Нельзя использовать глобальные переменные или хранить состояние лотерей вне `lottery_multi::registry` — все данные должны быть on-chain и трассируемы.
- Нельзя изменять формат событий, перечисленных в разделе 3.4, без обновления фронтенда, индексаторов и документации; любое изменение требует согласованного RFC.
- Нельзя выдавать capabilities напрямую из тестов или утилит, минуя `RoleRegistry`; нарушение приводит к отказу приёмки.
- Нельзя публиковать новые конфигурации без обновления `config_version` и записи в changelog — такие релизы считаются недействительными.

