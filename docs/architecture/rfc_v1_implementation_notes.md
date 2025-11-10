# RFC v1 Implementation Notes

> ⚠️ Шаблон заполняется на русском языке. Комментарии внутри таблиц следует очищать по мере перехода к рабочей эксплуатации.

## 1. Сводка статуса по этапам

| Этап | Диапазон задач (см. [план параллельных лотерей](./lottery_parallel_plan.md)) | Статус \(Not Started / In Progress / Done\) | Основные комментарии | Дата обновления |
|------|--------------------------------------------------------------------------------|----------------------------------------------|----------------------|-----------------|
| 0    | Подготовка архитектуры, согласование RFC, публикация книги проекта             | Done               | Архитектура согласована, книга проекта опубликована | 2025-11-09 |
| 1    | Фундаментальные артефакты: схемы ресурсов, событий, view и документации        | Done               | Сформированы ключевые модули (`registry`, `sales`, `draw`, `payouts`, `automation`, `price_feed`), добавлены view `get_lottery`/`list_active`/`list_by_*`, обновлены unit-тесты жизненного цикла и документация | 2025-11-10 |
| 2    | Миграции, capabilities, тестовая инфраструктура и мониторинг VRF-депозита      | Done               | Завершены `winner_tests`, dual-write контроль и проверки VRF-депозита; подготовлены миграционные инструменты и Prover-спеки | 2025-11-12 |
| 3    | Реализация ядра lottery_multi, партнёрских ограничений и премиальных фич       | In Progress                    | Реализованы агрегаты и события выплат (`total_*`, `PayoutBatch`, `PartnerPayout`, `PurchaseRateLimitHit`), добавлены `roles::RoleStore`, капабилити `PayoutBatchCap`/`PartnerPayoutCap`, юниты `payouts_tests` покрывают лимиты и отсутствие капы | 2025-11-14 |
| 4    | Расширение пользовательских сервисов, локализация, поддержка партнёров         | In Progress           | Dual-write мост обновлён: события `ArchiveDualWriteStarted/Completed`, функции `notify_summary_written` и `dual_write_flags`, view `dual_write_status`, добавлен CLI-скрипт для управления | 2025-11-16 |
| 5    | Наблюдаемость, автоматизация, прайс-фиды, очистка хранилища                    | Not Started                                   |                      | _YYYY-MM-DD_ |
| 6    | Пострелизная стабилизация, баг-баунти, расширенные тесты и документация        | Not Started                                   |                      | _YYYY-MM-DD_ |
| 7    | Governance/API (перенесено на позднюю фазу)                                    | Not Started                                   |                      | _YYYY-MM-DD_ |

## 2. Прогресс по модулям Move

| Модуль | Ключевые обязанности | Текущее состояние | Ответственный | Последний апдейт |
|--------|----------------------|-------------------|---------------|------------------|
| `registry` | Жизненный цикл лотерей, статусы, идентификаторы | In Progress | Стартовая версия с тегами, событиями и блокировкой snapshot, добавлены unit-тесты `config_tests` для базовой валидации | 2025-11-09 |
| `sales` | Выпуск билетов, лимиты, анти-DoS | In Progress | Реализованы события `TicketPurchase`/`PurchaseRateLimitHit`, хранение чанков, выдача владельца билета через `ticket_owner`, учёт `SalesDistribution`, блоковые/оконные лимиты, grace-window; добавлен `record_payouts` и покрыт тестами `payouts_tests` для синхронизации агрегатов выплат | 2025-11-14 |
| `draw` | VRF-запросы, обработка retry, анти-bias | In Progress | Создан ledger запросов, события `VrfRequested/VrfFulfilled`, хэш снапшота билетов, подготовка payload для winners, финализационный снимок | 2025-11-08 |
| `payouts` | Подсчёт победителей, батчи выплат, идемпотентность | In Progress | Ledger победителей, события `WinnersComputed`/`PayoutBatch`; `record_payout_batch_admin`/`record_partner_payout_admin` требуют соответствующие капабилити, обновляют агрегаты и публикуют события, добавлены тесты `payouts_tests` | 2025-11-14 |
| `economics` | Резервы, распределение долей, джекпот | In Progress | Учёт распределения 70/15/10/5, контроль `total_operations_allocated`, проверки выплат и ошибки `E_PAYOUT_ALLOC_EXCEEDED`/`E_OPERATIONS_ALLOC_EXCEEDED` | 2025-11-13 |
| `history` | Архивы, dual-write, снапшоты | In Progress | `ArchiveLedger`, финальные сводки, dual-write контроль; добавлены агрегаты `total_*`, события `PartnerPayoutEvent`/`PurchaseRateLimitHitEvent`, вызовы `mirror_summary_to_legacy` + `notify_summary_written` и синхронизация с legacy архивом | 2025-11-17 |
| `legacy_bridge` | Dual-write контроль, ожидание хэшей | In Progress | Ресурсы `DualWriteControl` и `MirrorConfig`, события `ArchiveDualWriteStarted/Completed`, функции `mirror_summary_to_legacy`/`notify_summary_written`, view `dual_write_status`, Supra CLI-скрипт `dual_write_control.sh` (`init`, `update-flags`, `set`, `clear`, `enable-mirror`, `disable-mirror`, `mirror`, `status`, `flags`) | 2025-11-17 |
| `views` | Публичные API, фильтры, JSON-схемы | In Progress | Реализованы фильтры по типам и тегам, выдача бейджей, `get_lottery`, `list_active`, доступ к архивным summary и спискам финализированных ID | 2025-11-09 |
| `roles` | Capabilities, партнёры, премиальные подписки | In Progress | Реализован `RoleStore`, выдача `PayoutBatchCap`/`PartnerPayoutCap`, проверки `consume_payout_batch`/`consume_partner_payout`, сохранены PartnerCreate/Premium капы | 2025-11-14 |
| `tags` | Классификаторы, фильтрация, маски | In Progress | Валидация масок, ограничение по бюджету тегов | 2025-11-08 |
| `price_feed` | Оракулы SUPRA/USD и прочие активы | In Progress | Реализован `PriceFeedRegistry` с событиями обновления/фолбэка/клампа, добавлены константы SUPRA/USDT | 2025-11-08 |
| `feature_switch` | Управление доступом к функциям | In Progress | Добавлен реестр режимов и devnet override | 2025-11-08 |
| `automation` | AutomationBot, dry-run, репутация | In Progress | Реализован модуль `automation` с регистрацией ботов, событиями dry-run/tick/error и учётом репутации | 2025-11-08 |

## 3. Контроль ключевых инвариантов

| Инвариант | Инструменты проверки | Текущий статус | Комментарий |
|-----------|----------------------|----------------|-------------|
| `snapshot_hash` неизменен после `Closing` | Move Prover, unit-тесты | In Progress | Инварианты длины хэшей и заморозки добавлены в `spec/registry.move`, требуется доказательство неизменности |
| `payout_round` строго возрастает | Move Prover | In Progress | `spec/payouts.move` теперь фиксирует длины хэшей и связь `next_winner_batch_no ≥ payout_round`, остаётся формальное доказательство роста |
| `allocated >= paid` во всех пулах | Unit-тесты, property-тесты | In Progress | Инвариант `spec/economics.move` + юнит-тест `lottery_multi::economics_tests` контролируют базовое условие, остаются интеграционные сценарии |
| `jackpot_allowance_token` не увеличивается | Move Prover | In Progress | Инвариант `spec/economics.move` ограничивает рост, необходимо формальное доказательство |
| Детерминированный выбор победителей | Differential / property tests | In Progress | Юнит-тесты `winner_tests.move` сравнивают on-chain расчёт с эталонной реализацией |
| Dual-write архива остаётся консистентным | Unit-тесты, интеграционные тесты | In Progress | Добавлены `legacy_bridge`, `history_bridge` и юнит-тест `history_dual_write_tests::dual_write_mirror_summary`; требуется связка с внешним backfill-скриптом |

## 4. Архив и миграции

- **Legacy backfill**: ответственный Backend (А. Петров). Черновой скрипт преобразования `lottery_support::History` → `ArchiveLedger` готов, запланированный dry-run на devnet — 2025-11-18, целевой переход на prod — 2025-11-22.
- **Dual-write мониторинг**: метрика `archive_dual_hash_match`, события `ArchiveDualWriteStarted/Completed`, зеркальные `LegacySummaryEvent` и журнал `dual_write.log` обновляются cron-скриптом каждые 30 минут; статус и зеркальные записи проверяются через view `legacy_bridge::dual_write_status`, `history_bridge::get_summary` и Supra CLI (`supra/scripts/dual_write_control.sh`, команды `status`, `flags`, `mirror`). Последняя сверка хэшей (2025-11-11 09:30 UTC) — совпадение, расхождений не обнаружено.
- **Состояние миграции `LotteryHistoryArchive`**: активная схема `ArchiveSummaryV1`, подготовлена JSON Schema v1 и чек-лист сверки; остаётся задокументировать процедуру отката и покрыть сценарий «finalize + cancel» интеграционным тестом.

## 5. Фронтенд и API

| Компонент | Зависимости от on-chain | Статус | Комментарии |
|-----------|-------------------------|--------|-------------|
| Раздел «История» | `views::list_by_primary_type`, `get_lottery_status`, JSON Schema v1 | Not Started |  |
| Админ-конструктор | `views::validate_config`, таблица тегов, FeatureSwitch dev override | Not Started |  |
| Партнёрский мастер | Preset API, квоты песочницы, allowed tags/types | Not Started |  |
| API/индексатор | Dual-write архив, события v1 с `event_version` | Not Started |  |

## 6. Операционные регламенты

- **VRF-депозит**: 2025-11-11 — runbook [operations/vrf_deposit.md](../handbook/operations/vrf_deposit.md) в рабочем режиме; Ops-инженер Н. Иванова отслеживает `effective_balance` и `required_minimum` через дашборд Grafana. Автономное возобновление запросов планируется через AutomationBot (ETA 2025-11-25).
- **AutomationBot**: последняя ротация ключей — 2025-11-08; счётчик успешных задач 24/24, предупреждений нет. Требуется связка с `vrf_deposit::record_snapshot_automation` и настройка таймлоков перед запуском на prod.
- **Рефанд-процедуры**: SLA 24 часа, контрольный прогон runbook завершён 2025-11-07; необходимо добавить интеграционный тест «force_cancel → refund» до этапа 3.
- **Прайс-фид**: `staleness_window` = 120 c, `price clamp` в статусе `Inactive` (последняя проверка 2025-11-10). При отклонении более 5% срабатывает событие `PriceClampTriggered` и блокировка покупок.
- **Supra CLI**: 2025-11-09 — попытка запуска `build_lottery_packages.sh lottery_multi` завершилась ошибкой (бинарь отсутствует). Ответственный DevOps (К. Смирнов) устанавливает CLI и обновляет runbook до 2025-11-13.

## 7. Журнал решений (RFC Notes)

| Дата | Решение | Область (модуль/процесс) | Следующие действия |
|------|---------|--------------------------|--------------------|
| 2025-11-16 | Включить события `ArchiveDualWriteStarted/Completed`, view `dual_write_status` и Supra CLI-скрипт для управления dual-write | `legacy_bridge`, операции миграции | Подготовить интеграционные тесты dual-write и dry-run миграции |
| 2025-11-17 | Включить зеркальную запись `mirror_summary_to_legacy` и модуль `history_bridge`, расширить Supra CLI командами `enable/disable-mirror`, `mirror` | `legacy_bridge`, `history`, операции миграции | Проверить dry-run миграции с использованием `history_bridge::get_summary` |

> Обновляя таблицы, не забывайте ссылаться на коммиты, PR или внешние документы. При необходимости расширяйте разделы, но сохраняйте структуру шаблона для единообразия.
