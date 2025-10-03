# Аудит интеграции Supra VRF в проект Lottery

## Источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Supra Docs — Build with Supra dVRF](https://docs.supra.com/network/move/dvrf/)
- [Supra Labs GitHub](https://github.com/Supra-Labs)
- [Supra Documentation — Migration to dVRF 3.0](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md)
- [Supra Documentation — Gas Configurations](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md)
- [Supra Documentation — VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md)
- [Supra Documentation — Request Random Numbers on EVMs](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md)
- [Supra Documentation — Add Contracts to Subscription](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/add-contracts-to-subscription.md)

## Резюме для руководства
- **Область аудита.** Смарт-контракт `lottery::main_v2`, управляющий подпиской Supra dVRF 3.0, генерацией запросов и обработкой колбэка, а также модульные тесты `lottery_tests.move` как основное прикладное покрытие.【F:supra/move_workspace/lottery/sources/Lottery.move†L1-L760】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L760】
- **Положительные моменты.** Код сохраняет BCS-конверт запроса, сверяет его хеш, `nonce` и `client_seed`, запрещает менять конфигурацию газа при pending-запросе, валидирует `rng_count`, рассчитывает минимальный баланс по формуле VRF 3.0 и блокирует VRF-запросы без настроенного газа; дополнительно реализован on-chain whitelisting агрегатора и потребителей с событиями, проверкой `caller_address` колбэка и требованием заранее зафиксировать whitelisted агрегатор перед отправкой VRF-запроса.[^hash-guideline][^gas-config][^subscription][^add-contract][^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L37-L498】【F:supra/move_workspace/lottery/sources/Lottery.move†L608-L671】【F:supra/move_workspace/lottery/sources/Lottery.move†L848-L861】
- **Ключевые риски.** Критические несоответствия не выявлены; необходимо документировать процедуры whitelisting и поддерживать наблюдаемость событий в эксплуатационных регламентах.
- **Следующие шаги.** Поддерживать runbook и тестовое покрытие, фиксирующее whitelisting и управление подпиской; подтвердить изменения командой `supra move test -p supra/move_workspace`.

### Сводка рисков
| Требование Supra | Статус | Риск | Пояснение |
| --- | --- | --- | --- |
| Хеширование и проверка конверта VRF | ✅ Выполнено | Низкий | `ensure_payload_hash_matches` сравнивает хеш и поля `nonce`/`client_seed` с данными колбэка, блокируя подмену payload.【F:supra/move_workspace/lottery/sources/Lottery.move†L744-L757】 |
| Экономика подписки VRF 3.0 | ✅ Выполнено | Низкий | Минимальный баланс и per-request fee рассчитываются по формуле `minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)`.【F:supra/move_workspace/lottery/sources/Lottery.move†L723-L737】 |
| Предварительная конфигурация газа | ✅ Выполнено | Низкий | `request_draw` и тестовый хелпер вызывают `ensure_gas_configured`, блокируя VRF-запрос при нулевых значениях и покрывая сценарий тестом `manual_draw_requires_configured_gas`.[^gas-config]【F:supra/move_workspace/lottery/sources/Lottery.move†L352-L457】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L694-L726】 |
| Whitelisting агрегатора/клиентов | ✅ Выполнено | Низкий | Контракт хранит список потребителей, публикует события whitelisting, проверяет `caller_address` и разрешённого агрегатора в `on_random_received` и блокирует VRF-запрос без whitelisted агрегатора.[^subscription][^add-contract]【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L498】【F:supra/move_workspace/lottery/sources/Lottery.move†L608-L861】 |
| Уникальный `client_seed` и его логирование | ✅ Выполнено | Низкий | `next_client_seed` генерирует уникальные значения, `DrawRequestedEvent` публикует сид, а тест `record_request_emits_client_seed_and_increments_counter` подтверждает инкремент счётчика.[^hash-guideline][^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L352-L529】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L728-L758】 |

## Методология
1. Изучили исходный код `Lottery.move`, включая жизненный цикл подписки, расчёт газовых лимитов, генерацию VRF-запросов и обработку колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L1-L760】
2. Сопоставили реализацию с рекомендациями Supra dVRF 3.0 по валидации полезной нагрузки, whitelisting, управлению газом и экономическим инвариантам.[^hash-guideline][^gas-config][^subscription]
3. Проанализировали тестовый модуль `lottery_tests.move`, проверив наличие позитивных и негативных сценариев, покрывающих критические ветки логики.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L1023】
4. Сопоставили реализацию с примерами Supra Labs на GitHub, где демонстрируется настройка газов, whitelisting и использование уникальных сидов до отправки VRF-запросов.[^supra-github]
5. Проверили соответствие рекомендуемым шаблонам Supra Docs Overview и Move SDK, уделив внимание on-chain контролю доступа, структуре модулей и событиям.[^supra-overview][^move-sdk]

## Сопоставление с ключевыми источниками Supra

| Источник | Ключевые требования | Реализация в проекте | Тестовое подтверждение |
| --- | --- | --- | --- |
| Supra Docs — Overview[^supra-overview] | Администрирование подписки, разграничение прав и whitelisting агрегаторов/потребителей. | Администратор ограничен адресом `@lottery`, VRF-запросы требуют whitelisted агрегатора и потребителя, события фиксируют изменения списков.【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L498】【F:supra/move_workspace/lottery/sources/Lottery.move†L848-L916】 | Тесты whitelisting и проверок колбэка подтверждают ограничения доступа и события управления.[^subscription]【F:supra/move_workspace/lottery/tests/lottery_tests.move†L97-L226】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L813-L903】 |
| Supra Docs — Move SDK[^move-sdk] | Использование событий, `#[test_only]`-функций и модульной структуры для обеспечения читаемости и тестируемости. | Контракт объявляет специализированные события, вью-функции и тестовые хелперы для валидации VRF-процесса.【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L760】 | Модульные тесты вызывают `#[test_only]`-функции (`handle_verified_random_for_test`, `request_payload_message_for_test`) для прямой проверки критической логики.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L717】 |
| Supra Labs GitHub[^supra-github] | Практики настройки газа, расчёта минимального баланса и защиты колбэка хешем запроса. | `configure_vrf_gas_internal` запрещает изменения при pending-запросе и пересчитывает per-request fee, а `ensure_payload_hash_matches` сравнивает сохранённый хеш с полезной нагрузкой и проверяет `nonce`/`client_seed`.【F:supra/move_workspace/lottery/sources/Lottery.move†L335-L499】【F:supra/move_workspace/lottery/sources/Lottery.move†L908-L920】 | Тесты проверяют расчёт хеша и обработку ответов VRF, включая негативные сценарии для `rng_count` и payload.[^hash-guideline]【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L811】 |

## Карта требований Supra
- **Валидация полезной нагрузки колбэка.** dVRF 3.0 требует сохранять и сверять хеш BCS-конверта запроса, проверять `nonce`/`clientSeed` и разрешённого провайдера перед обработкой случайности, исключая подмену данных.[^hash-guideline]
- **Экономика подписки.** Минимальный баланс и per-request fee рассчитываются как `minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)`, параметры газа должны быть согласованы и зафиксированы до отправки запроса.[^gas-config]
- **Whitelisting и управление доступом.** Модель подписки подразумевает on-chain фиксацию клиента, добавление/удаление потребителей и проверку того, что запросы исходят от whitelisted контрактов и агрегатора Supra.[^subscription][^add-contract]
- **Контроль `rngCount` и уникальности сидов.** Документация подчёркивает валидацию `_rngCount` и уникальные `clientSeed` для исключения повторов и диагностики несоответствий ответов Supra.[^evm-guide]

## Соответствие официальным источникам Supra

| Источник | Требование из документации | Реализация в коде | Тестовое покрытие |
| --- | --- | --- | --- |
| *Migration to dVRF 3.0*[^hash-guideline] | Сохранять и проверять BCS-конверт VRF-запроса, сверять `nonce` и `client_seed` до очистки состояния. | `record_vrf_request` хеширует конверт, `ensure_payload_hash_matches` сравнивает сохранённый хеш с фактическим `message`, декодирует `VrfRequestEnvelope` и вызывается из `handle_verified_random` до извлечения pending-запроса.【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L701】 | Тесты `validate_payload_hash_succeeds_for_matching_data`/`validate_payload_hash_fails_for_mismatch` проверяют корректный и подменённый payload, а `handle_verified_random_processes_single_rng_value` подтверждает успешный путь обработки.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L717】 |
| *Gas Configurations*[^gas-config] | Фиксировать параметры газа до запроса и рассчитывать минимальный баланс по формуле VRF 3.0. | `configure_vrf_gas_internal` запрещает обновления при pending-запросе, пересчитывает per-request fee через `calculate_per_request_gas_fee`, а `calculate_min_balance` умножает `MIN_REQUEST_WINDOW` на сумму `max_gas_limit + verification_gas_value` с контролем переполнения.【F:supra/move_workspace/lottery/sources/Lottery.move†L317-L901】 | Тесты `manual_draw_requires_configured_gas` и `gas_configuration_blocked_during_pending_request` фиксируют отказ без конфигурации и блокировку обновлений, а `record_request_emits_client_seed_and_increments_counter` проверяет события запроса с актуальными параметрами газа.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L907-L1023】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L959-L995】 |
| *VRF Subscription FAQ* / *Add Contracts to Subscription*[^subscription][^add-contract] | On-chain whitelisting агрегатора и потребителей, запрет запросов и колбэков от неавторизованных адресов. | `whitelist_callback_sender`/`whitelist_consumer` обновляют списки и события, `request_draw` и `handle_verified_random` проверяют whitelisted потребителя, настроенного агрегатора и `caller_address` колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L866】 | Тесты whitelisting событий и ограничений (`whitelisting_events_track_consumers_and_aggregator`, `whitelist_consumer_rejects_duplicates`, `handle_verified_random_requires_configured_aggregator`, `handle_verified_random_rejects_unwhitelisted_caller`) подтверждают защиту и аудит изменений списков.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L130-L214】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L813-L903】 |
| *Request Random Numbers — EVMs*[^evm-guide] | Проверять `rng_count`, длину массива случайностей и вести счётчики запросов/ответов. | `handle_verified_random` сверяет `rng_count` и фактическую длину `verified_nums`, обновляет счётчики только после успешной валидации и публикует `DrawHandledEvent`.[^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L657-L707】 | Тесты `handle_verified_random_rejects_wrong_rng_count` и `handle_verified_random_rejects_wrong_vector_length` эмулируют некорректные ответы, а `rng_counters_for_test` используется для проверки инкрементов после удачного колбэка.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L719-L811】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L959-L995】 |

## Соответствие требованиям
- Код строит `VrfRequestEnvelope`, хеширует фактическое `message`, сверяет `nonce` и `client_seed`, а также очищает pending-состояние только после успешной проверки, что удовлетворяет требованию Supra по on-chain валидации запроса.[^hash-guideline]【F:supra/move_workspace/lottery/sources/Lottery.move†L37-L171】【F:supra/move_workspace/lottery/sources/Lottery.move†L502-L566】
- Минимальный баланс подписки и per-request fee вычисляются по формуле VRF 3.0 в `u128` с защитой от переполнения, а итоговые значения публикуются в событиях настройки подписки.【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L228】【F:supra/move_workspace/lottery/sources/Lottery.move†L607-L671】
- Обновление газовой конфигурации запрещено, пока существует `pending_request`, что исключает рассинхронизацию сохранённого хеша и соответствует рекомендациям Supra сохранять параметры до завершения колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L235-L326】
- `handle_verified_random` сверяет `rng_count` с ожидаемым значением и длиной `verified_nums`, выполняя требование Supra контролировать количество случайностей.[^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L538-L585】

## Критические несоответствия
Критических несоответствий с требованиями Supra VRF 3.0 не выявлено: whitelisting агрегатора и потребителей реализован on-chain, события фиксируют изменения, а `on_random_received` проверяет источник колбэка перед обработкой случайности.[^subscription][^add-contract]【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L417】【F:supra/move_workspace/lottery/sources/Lottery.move†L538-L671】

## Дополнительные наблюдения
- `DrawRequestedEvent` по-прежнему не логирует whitelisted агрегатор, однако теперь whitelisting фиксируется отдельными событиями `AggregatorWhitelistedEvent` и `ConsumerWhitelistedEvent`, что упрощает аудит административных действий.[^subscription][^add-contract]【F:supra/move_workspace/lottery/sources/Lottery.move†L144-L226】【F:supra/move_workspace/lottery/sources/Lottery.move†L438-L585】
- Тестовое покрытие дополнено позитивными и негативными сценариями whitelisting, включая проверки отсутствующего агрегатора, неверного `caller_address` и дубликатов потребителей; новые тесты также подтверждают, что VRF-запрос невозможен без предварительно настроенного whitelisted агрегатора, что предотвращает зависание pending-запроса.[^evm-guide][^supra-github]【F:supra/move_workspace/lottery/tests/lottery_tests.move†L97-L226】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L520-L955】

## Рекомендации по устранению несоответствий
1. **Документировать процессы whitelisting в операционной политике.** On-chain события фиксируют изменения; рекомендуется описать процедуры добавления/отзыва агрегатора и потребителей в runbook и интеграционных тестах, чтобы синхронизировать on-chain и off-chain действия.[^subscription][^add-contract]
2. **Продолжать расширять события административных операций.** При настройке газа и обновлении лимитов подписки логировать whitelisted адреса, параметры газа и активный `nonce`, следуя рекомендациям Supra фиксировать изменения конфигурации подписки в журнале событий.[^gas-config][^subscription]
3. **Поддерживать негативные сценарии в тестах.** Новые тесты покрывают whitelisting; дальнейшие изменения должны сопровождаться сценариями для дополнительных ограничений доступа и обновлений списка потребителей на основе примеров Supra Labs.[^evm-guide][^supra-github]

## Покрытие тестами
- Тесты покрывают успешный сценарий проверки хеша, whitelisting агрегатора и потребителей, негативные кейсы на ненастроенный газ, неверный `caller_address`, дублирующих потребителей и отзыв агрегатора, что закрепляет требования Supra и предотвращает регрессии.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L1023】

## Соответствие официальным материалам Supra
- **Supra Docs — Overview.** Архитектура подписки и контроль whitelisting соответствуют разделам об управлении доступом Supra Network, включая разграничение ролей администратора и потребителя.[^supra-overview]
- **Supra Docs — Move SDK.** Использование модулей, событий и `#[test_only]`-функций следует рекомендуемым шаблонам Supra Move SDK для on-chain проектов и тестов.[^move-sdk]
- **Build with Supra dVRF.** Реализация хеширования конверта, проверки `nonce`/`client_seed` и формулы минимального баланса отражает рекомендации миграционного гайда, конфигурации газа и модели подписки.[^hash-guideline][^gas-config][^subscription]

## Итог
Контракт Lottery реализует ключевые элементы защиты dVRF 3.0: хеширование полезной нагрузки, расчёт газовой экономики, запрет изменения конфигурации при pending-запросе, проверку `rng_count`, блокировку запросов без настроенного газа, уникальные `client_seed`, а также on-chain whitelisting агрегатора и потребителей с проверкой `caller_address`. Для операционной готовности остаётся документировать процедуры whitelisting и поддерживать расширенные события/тесты в соответствии с рекомендациями Supra Labs.[^gas-config][^evm-guide][^subscription]

[^hash-guideline]: Supra Labs, *Migration to dVRF 3.0* — разделы «On-chain Request Validation» и «Enhanced Security & Integrity», https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md
[^gas-config]: Supra Labs, *Gas Configurations* — формула минимального баланса и влияние параметров газа, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md
[^subscription]: Supra Labs, *VRF Subscription FAQ* — описание whitelisting и подписной модели, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md
[^add-contract]: Supra Labs, *Add Contracts to Subscription* — требования к whitelisting контрактов, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/add-contracts-to-subscription.md
[^evm-guide]: Supra Labs, *Request Random Numbers — EVMs* — параметры `_rngCount` и замечания по валидации колбэка, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md
[^supra-github]: Supra Labs, примеры интеграции dVRF, GitHub — https://github.com/Supra-Labs
[^supra-overview]: Supra Docs, *Supra Network Overview*, https://docs.supra.com/
[^move-sdk]: Supra Docs, *Move SDK Guide*, https://docs.supra.com/network/move/
