# План приведения SupraLottery к официальной документации Supra

## 1. Обзор текущей Move-структуры
- **Workspace**: `SupraLottery/supra/move_workspace/Move.toml` объявляет пакеты `lottery`, `lottery_factory`, `vrf_hub`, `SupraVrf` и использует git-зависимость `move-stdlib` из `Entropy-Foundation/aptos-core`.
- **Пакет `lottery`** (`SupraLottery/supra/move_workspace/lottery/sources`):
  - Управление лотереями и раундами — `Lottery.move`, `LotteryRounds.move`, `LotteryInstances.move`.
  - Казначейство и джекпоты — `Treasury.move`, `TreasuryMulti.move`, `Jackpot.move`.
  - Дополнительная логика — `Store.move`, `Metadata.move`, `NftRewards.move`, `Referrals.move`, `Vip.move`, `Operators.move`, `Autopurchase.move`, `History.move`, `Migration.move`.
- **Пакет `SupraVrf`** (`SupraLottery/supra/move_workspace/SupraVrf/sources`): обёртки над Supra dVRF (`supra_vrf.move`, `deposit.move`) и вспомогательные типы.
- **Пакет `vrf_hub`** (`SupraLottery/supra/move_workspace/vrf_hub/sources`): очередь запросов, whitelisting callback-модулей, функции просмотра состояния.
- **Пакет `lottery_factory`** (`SupraLottery/supra/move_workspace/lottery_factory/sources`): создание и регистрация лотерей, проксирование к VRF hub.
- **Автоматизация и тестовые утилиты**: Python-скрипты в `supra/scripts` и `supra/automation`, тестовые сценарии `tests`.

## 2. Авторитетные источники
1. Документация Supra по Move: <https://docs.supra.com/network/move> — требования к пакетам, деплою, стандартной библиотеке.
2. Репозитории Supra-Labs: <https://github.com/Supra-Labs> — эталонные реализации и шаблоны CI.
3. dVRF v3 документация и примеры: <https://github.com/Supra-Labs/documentation/tree/main/dvrf> — структуры запросов, события, CLI.

## 3. Цели соответствия
- Синхронизировать `Move.toml`, адреса и зависимые пакеты с актуальными указаниями Supra.
- Подчинить интерфейсы dVRF (запрос, fulfill, события) шаблонам из `documentation/dvrf`.
- Обновить работу с `0x1::fungible_asset` и другими стандартными модулями Move согласно последним гайдам.
- Привести роли, списки доступа и администрирование к официальным паттернам (aggregator/client whitelist, операторские capability).
- Гармонизировать события, структуры метаданных и журналы с референсными схемами наблюдаемости Supra.
- Обеспечить тестовое покрытие и пайплайны, рекомендованные Supra CLI/CI.

## 4. Поэтапный план работ

### Этап A. Инвентаризация и сравнительный анализ (2–3 дня)
1. Сгенерировать перечень публичных entry-функций, ресурсов и событий в каждом модуле (`move package info`, `move docgen`).
2. Сопоставить их со структурами из официальных репозиториев Supra-Labs и таблицами в документации.
3. Зафиксировать отклонения (тип адреса, сигнатуры, guard-условия, события) в отчёте `docs/alignment_gaps.md`.

### Этап B. Обновление интеграции dVRF (4–5 дней)
1. (Выполнено) Сверить `SupraVrf/sources/supra_vrf.move` с эталоном Supra — сигнатуры подтверждены по пакету [`Entropy-Foundation/vrf-interface@testnet`](https://github.com/Entropy-Foundation/vrf-interface/tree/testnet/supra/testnet).
2. Обновить схемы `CallbackRequest`, сериализацию seed, обработку комиссий, проверку ключей в `SupraVrf` и зависимых модулях лотереи.
3. Перепроверить `vrf_hub` и `lottery_factory` на соответствие API (регистрация, очереди, whitelisting).
4. Добавить интеграционные тесты: успешный запрос, недостаточный депозит, невалидный callback-адрес.

### Этап C. Казначейство и работа с активами (3–4 дня)
1. Перейти на актуальные практики `0x1::fungible_asset`: капабилити, фризы, чекеры прав.
2. Перепроверить курирование доходов и распределения (`Treasury.move`, `TreasuryMulti.move`, `Jackpot.move`).
3. Добавить unit-тесты на корректность базисных точек, лимитов, сценариев инициализации.

### Этап D. Роли и управление доступом (2–3 дня)
1. Согласовать роли операторов/агрегаторов с официальными whitelist-паттернами Supra.
2. Рефакторить `Operators.move`, `Lottery.move`, `vrf_hub` под использование capability-модулей Supra.
3. Обновить документацию по управлению (`README.md`, runbook) с командами Supra CLI.

### Этап E. Метаданные, миграции и наблюдаемость (2 дня)
1. Синхронизировать определения событий (пример: `LotteryDrawnEvent`, `TicketPurchasedEvent`) с эталонными JSON-схемами.
2. Обновить `Metadata.move`, `Migration.move`, а также скрипты мониторинга (`supra/scripts`, `supra/automation`).
3. Настроить экспорт логов и dashboard согласно рекомендациям из `documentation/dvrf/monitoring`.

### Этап F. Тестирование и пайплайн деплоя (2 дня)
1. Обновить `Move.toml` и зависимости на версии из Supra-Labs (git-revision или release tags).
2. Настроить команду `supra move test`, e2e-тесты Python (FastAPI/CLI), включить их в CI.
3. Подготовить чек-лист деплоя с адресами, sequence шагами, параметрами конфигурации сети.

### Этап G. Валидация и финальный аудит (1–2 дня)
1. Провести внутренний аудит кода с чек-листом Supra (`docs/audit/*`).
2. Собрать feedback от Supra (issues/PR в официальные репо при необходимости).
3. Зафиксировать результаты и открытые вопросы в отчёте `docs/supra_alignment_status.md`.

## 5. Требуемые артефакты
- Обновлённые Move-модули и миграции, соответствующие Supra.
- Документация по управлению и деплою (README, runbook, чек-листы).
- Тестовые сценарии и CI-конфигурации, покрывающие ключевые кейсы Supra.
- Отчёт по расхождениям и их устранению.

## 6. Риски и предпосылки
- Необходимо подтвердить целевую сеть (testnet/mainnet) и набор on-chain адресов перед правками.
- Важно получить последние версии эталонных модулей (возможны приватные репозитории Supra-Labs).
- Требуется доступ к Supra CLI и сервисам dVRF для интеграционных тестов.

## 7. Ближайшие шаги
1. Назначить ответственных за каждый этап и согласовать график.
2. (Выполнено) Создать файл `docs/alignment_gaps.md` и зафиксировать стартовые расхождения.
3. Запросить у Supra актуальные адреса, ключи и требования к whitelisting.

## 8. Текущий прогресс и наблюдения
- Подготовлен файл `docs/module_inventory.md` с перечислением всех публичных entry-функций, ресурсов и событий, что закрывает пункт A1 плана.
- Создан шаблон отчёта `docs/alignment_gaps.md` с первыми замечаниями по адресам и зависимостям (пункт A3). Для дальнейшего сравнения требуются эталонные контракты Supra-Labs; прямой доступ к репозиторию `Supra-Labs/documentation` ограничен (ошибка 403 при попытке `git clone`).
- Зафиксирован снимок официального шаблона `Supra dVRF Template` в `docs/dvrf_reference_snapshot.md` и добавлены новые наблюдения в `alignment_gaps.md`, что покрывает анализ зависимости dVRF (пункт A2).
- Подтверждено соответствие нативных модулей `supra_vrf` и `deposit` публичному репозиторию `Entropy-Foundation/vrf-interface@testnet`; подготовлен сравнительный срез в `docs/dvrf_reference_snapshot.md` (пункт B1 закрыт).
- Начат этап B: добавлен алиас `supra_addr` в workspace и обновлён `Lottery.move` на использование `supra_addr::supra_vrf`/`deposit`, что устраняет жёсткую привязку к адресу и повторяет паттерн официального шаблона Supra.
- Move.toml пакета `SupraVrf` синхронизирован с официальным `vrf-interface`: вместо локальной `move-stdlib` используется git-зависимость `SupraFramework` из `Entropy-Foundation/aptos-core`, оставлен только именованный адрес `supra_addr` (прогресс по пункту B2).
- Пакеты `lottery`, `lottery_factory` и `vrf_hub` подключают `SupraFramework`, а события мигрированы на `supra_framework::event`, что повторяет практику шаблонов Supra и закрывает часть этапа B2 по интеграции фреймворка.
- `RandomnessRequestedEvent` VRF-хаба дополнен полем `payload_hash` (SHA3-256 от BCS-конверта), что позволяет операторам и Supra CLI сверять заявки с `CallbackRequest` и закрывает требование B2 по прозрачности очереди запросов.
- В `lottery::main_v2` реализован `CallbackRequest` с адресом и именами колбэка, `rng_count` и числом подтверждений; событие `DrawRequestedEvent` теперь транслирует полный набор полей, а `configure_vrf_request`/`VrfRequestConfigUpdatedEvent` сохраняют `num_confirmations` для аудита, что закрывает требование этапа B2 по хранению dVRF-конверта согласно Supra.
- View-функция `get_pending_request_view` публикует `PendingRequestView` с nonce, whitelisted requester, `request_hash`, параметрами газа и подтверждений, позволяя аудиторам сверять очередь заявок без парсинга событий и дополняя контроль Supra над `CallbackRequest`.
- События `DrawRequestedEvent` и `DrawHandledEvent` синхронно публикуют `request_hash`, whitelisted `callback_sender`, конфигурацию газа, параметры подтверждений и список `randomness`, что зеркалирует требования Supra к журналированию dVRF и облегчает аудит fulfilled заявок.
- Учтены ограничения Supra VRF subscription: `configure_vrf_gas` блокирует значения `callbackGasPrice`/`callbackGasLimit` выше подписочных лимитов, CLI `configure_vrf_gas.py` валидирует параметры до вызова Supra CLI, а документация связывает требования с `VRF Subscription FAQ` (этап B2 — обработка комиссий и лимитов).
- Лимит Supra dVRF на `numConfirmations ≤ 20` применён в контракте (`configure_vrf_request`) и CLI: некорректные значения отклоняются до вызова Supra CLI, новые Move/Python-тесты покрывают сценарии превышения (этап B2 — проверка настроек запросов).
- Завершена on-chain обёртка `remove_subscription`: контракт вызывает `deposit::remove_contract_from_whitelist`, логирует `SubscriptionContractRemovedEvent` и закрывает pending-запросы, а новый CLI `remove-subscription` повторяет проверки мониторинга (этап B3 — операционные сценарии подписки).
- Казначейство `treasury_v1` переписано на Supra Fungible Asset: `TokenState` хранит Metadata-объект и capability (`MintRef`, `BurnRef`, `TransferRef`), `register_*` создают primary store через `supra_framework::primary_fungible_store`, операции депозита/выплат используют `transfer_with_ref`, а view-функции возвращают адреса store, supply и freeze-статус (этап C1 выполнен, начата реализация этапа C2).
- `treasury_v1::set_recipients` проверяет регистрацию и freeze primary store, `RecipientsUpdatedEvent` публикует прошлые и новые статусы направлений (парные `VaultRecipientsSnapshot`) при инициализации и обновлении, `get_recipient_statuses` предоставляет мониторингу адреса, регистрацию, freeze и баланс направлений казначейства, а Move-тесты фиксируют блокировку замороженных получателей (этап C2).
- `treasury_multi::init` и `set_recipients` теперь требуют завершённой инициализации `treasury_v1` и заранее зарегистрированных primary store для адресов джекпота и операционного пула, а view `get_recipients` помогает операторам сверять адреса перед выплатами (прогресс этапа C2).
- Для аудита Supra FA добавлена view-функция `treasury_multi::get_recipient_statuses`, публикующая регистрацию, freeze-статус и баланс primary store для джекпота и операционного пула; юнит-тесты покрывают позитивные и негативные сценарии (этап C2).
- Усилена защита выплат Supra FA: `treasury_multi::init/set_recipients` блокируют замороженные адреса пулов, `withdraw_operations` и `pay_operations_bonus_internal` проверяют регистрацию/ freeze получателей, а `distribute_jackpot` требует готовности кошелька победителя. Добавлены негативные Move-тесты на новые коды ошибок (`14`, `15`, `16`, `17`, `18`), фиксируя требования этапа C2 к операциям с primary store.
- Журналирование мультипулов выровнено с требованиями Supra: `treasury_multi::RecipientsUpdatedEvent` логирует `RecipientStatus` для прошлых и новых адресов, эмитится при `init` и `set_recipients`, а новые Move-тесты проверяют корректность снапшотов (этап C2 — наблюдаемость казначейства).
- Для соответствия требованиям Supra по whitelisting операторов добавлено событие `operators::OperatorSnapshotUpdatedEvent` и view `get_operator_snapshot`, которые публикуют владельца и полный список делегатов после каждого `set_owner`/`grant`/`revoke`; Move-тесты подтверждают историю событий (этап D1).
- Whitelisting агрегатора и потребителей теперь публикует `WhitelistSnapshotUpdatedEvent` после `init`, `whitelist_callback_sender`, `revoke_callback_sender`, `whitelist_consumer` и `remove_consumer`, что даёт Supra единый снапшот агрегатора и списка потребителей; юнит-тесты проверяют снимки при добавлении и удалении адресов (этап D1 — наблюдаемость VRF whitelisting).
- VRF-хаб публикует `CallbackSenderUpdatedEvent` при каждом `set_callback_sender`, а view `get_callback_sender_status` возвращает текущий whitelisted агрегатор; тесты проверяют событие и снапшот, что закрывает часть этапа D1 по наблюдаемости VRF hub на уровне Supra.
- Фабрика лотерей журналирует `LotteryRegistrySnapshotUpdatedEvent` и предоставляет view `get_registry_snapshot`/`list_lottery_ids`, фиксируя администратора и все зарегистрированные лотереи с параметрами билетов; Move-тесты проверяют снапшоты при создании, обновлении blueprint и смене администратора (этап D1 — наблюдаемость фабрики).
- Коллекция экземпляров `lottery::instances` публикует `LotteryInstancesSnapshotUpdatedEvent` и предоставляет view `get_instance_snapshot`/`get_instances_snapshot`, чтобы Supra могла одним запросом получить администратора, адрес VRF-хаба и полный набор параметров (владельцы, адреса контрактов, цены билетов, доли джекпота, статистика продаж и статус активности) по всем экземплярам; тесты `instances_tests` проверяют содержимое снапшотов после создания, синхронизации blueprint и смены статуса (этап D1 — наблюдаемость мульти-лотерейного каталога).
- Реестр витринных метаданных публикует событие `MetadataSnapshotUpdatedEvent` с полным списком описаний и предоставляет view `get_metadata_snapshot`, что позволяет Supra и фронтенду получать актуальный витринный срез одной командой (этап E1 — метаданные и наблюдаемость).
- Завершён аудит миграции legacy-лотерей: `migration::migrate_from_legacy` пишет снапшоты в `MigrationLedger`, публикует `MigrationSnapshotUpdatedEvent` и предоставляет view `list_migrated_lottery_ids`/`get_migration_snapshot`, что закрывает требование этапа E2 по наблюдаемости переноса данных.
- Реферальный модуль публикует событие `ReferralSnapshotUpdatedEvent` с администратором, счётчиком зарегистрированных игроков и статистикой по каждой лотерее, а view `get_referral_snapshot` предоставляет тот же агрегированный срез для Supra CLI и мониторинга, закрывая gap этапа D по наблюдаемости бонусных программ.
- `lottery::rounds` публикует `RoundSnapshotUpdatedEvent`, а view `get_round_snapshot` возвращает тот же `RoundSnapshot` с `pending_request_id`, что позволяет Supra мониторить готовность каждого раунда и активные VRF-заявки без чтения storage (этап D1 — наблюдаемость основных лотерейных процессов).
- Автопокупка билетов публикует `AutopurchaseSnapshotUpdatedEvent` и предоставляет view `get_lottery_snapshot`/`get_autopurchase_snapshot`, что фиксирует администратора, балансы и активные планы без реконструкции истории событий и закрывает требования этапа D по наблюдаемости автоматических продаж.
- VIP-подписки снабжены `VipSnapshotUpdatedEvent`, а view `get_lottery_snapshot` и `get_vip_snapshot` позволяют Supra отслеживать конфигурации, активность участников и выручку без сканирования одиночных событий, закрывая gap этапа D по наблюдаемости платных подписок.
- Глобальный джекпот публикует `JackpotSnapshotUpdatedEvent`, а view `jackpot::get_snapshot` возвращает тот же снимок (администратор, `lottery_id`, количество билетов, статус расписания и `pending_request_id`), что выполняет требование Supra по ончейн-наблюдаемости готовности джекпота и завершает часть этапа C2.
- Магазин цифровых товаров (`lottery::store`) публикует `StoreSnapshotUpdatedEvent` и предоставляет view `get_lottery_snapshot`/`get_store_snapshot`, что позволяет Supra отслеживать администратора магазина, остатки и продажи без реконструкции по событиям `ItemConfiguredEvent` и `ItemPurchasedEvent`.
- История розыгрышей (`lottery::history`) публикует агрегированный `HistorySnapshotUpdatedEvent` после инициализации, записи и очистки, а view `get_lottery_snapshot`/`get_history_snapshot` возвращают тот же набор `DrawRecord`, что упрощает аудит результатов Supra без чтения таблиц напрямую.
- NFT-бейджи (`lottery::nft_rewards`) теперь публикуют `NftRewardsSnapshotUpdatedEvent`, а view `list_owner_addresses`/`get_owner_snapshot`/`get_snapshot` предоставляют агрегированные данные (администратор, `next_badge_id`, владельцы и их бейджи), что закрывает gap наблюдаемости наград без сканирования таблиц и истории событий.
- Workspace Move переведён на резолвер `v2`, пакеты `lottery`, `vrf_hub` и `lottery_factory` используют git-зависимость `move-stdlib` из `Entropy-Foundation/aptos-core` вместо локальной копии, README обновлён инструкциями по fetch git-зависимостей, что закрывает пункт F1 плана о синхронизации зависимостей с официальными репозиториями Supra.
- Добавлена команда `python -m supra.scripts.cli move-test`, автоматически подбирающая доступную CLI (`supra`, `aptos` или `move`) и принимающая дополнительные аргументы через `--`. README описывает сценарии запуска, что закрывает локальную часть этапа F2 по стандартизации `supra move test` и готовит основу для интеграции в CI.
- CLI `move-test` научился перечислять пакеты и выполнять тесты последовательно для всего workspace (`--list-packages`, `--all-packages`), а runbook/README фиксируют новые сценарии. Добавлен вывод отчётов `--report-json` и `--report-junit` плюс флаг `--keep-going`, чтобы CI и операторы могли прикладывать JSON/JUnit со статусами всех пакетов, даже если один из них упал. Это формализует прогон `lottery`, `lottery_factory`, `vrf_hub` в отчётах и приближает выполнение требования этапа F2 по подготовке CI.
- Подготовлен чек-лист деплоя `docs/testnet_deployment_checklist.md`, который собирает адреса контрактов, рекомендуемые лимиты газа и последовательность команд Supra CLI для подписки dVRF, конфигурации лотереи, смоук-теста и пост-деплой мониторинга. Runbook ссылается на чек-лист в разделе требований, что закрывает пункт F3 о чек-листе деплоя.
- Запущен этап G: создан внутренний чек-лист аудита `docs/audit/internal_audit_checklist.md` и сводка статуса `docs/supra_alignment_status.md`, которые консолидируют прогресс и подготавливают внутреннюю валидацию перед передачей результатов Supra.
- Заполнена статическая часть чек-листа G1 (конфигурация Move и документация), подготовлено сопроводительное письмо `docs/audit/external_handover_summary.md` для передачи результатов Supra после завершения тестов и смоук-прогона.
- Для поддержки аудита без установленной Supra CLI `supra.scripts.move_tests` получил флаг `--cli-flavour`, позволяющий выполнять `--dry-run` с записью JSON/JUnit, а документация (README, runbook, чек-листы) описывает запуск через `PYTHONPATH=SupraLottery`.
- Выполнен dry-run `move-test --all-packages --keep-going` с `--cli-flavour supra`, сформирован шаблон отчёта (`docs/audit/move_test_reports/2025-02-14-move-test-dry-run.json`/`...xml`), подтвердивший готовность workspace к полноценному прогону Supra CLI.
- Подготовлен `docs/audit/internal_audit_dynamic_runbook.md`, описывающий шаги для завершения динамического аудита G1 (Supra CLI, Move-тесты, Python-тесты, смоук-прогон и публикация артефактов).
