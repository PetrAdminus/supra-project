# Комплексный аудит SupraLottery по требованиям Supra dVRF 3.0

## Использованные официальные источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Supra Labs GitHub — dVRF Move Contracts & Examples](https://github.com/Supra-Labs)

## Методология
1. Сопоставление on-chain хранилищ, событий и проверок в `lottery::main_v2` с контрольными списками Supra по whitelisting, газовой конфигурации и валидации полезной нагрузки.
2. Анализ тестового модуля `lottery::lottery_tests`, чтобы убедиться, что позитивные и негативные сценарии покрывают требования Supra, включая проверки whitelisting, конфигурации газа, хеша запроса и `rng_count`.
3. Сверка расчётов минимального депозита и параметров газа с формулой VRF 3.0 `minRequests × maxGasPrice × (maxGasLimit + verificationGasValue)`, описанной в Supra Docs и репозиториях Supra Labs.

## Ключевые выводы
- **Проверка payload'а VRF-колбэка.** Контракт сохраняет sha3-256 хеш BCS-конверта запроса, а затем сверяет его с фактическим `message`, декодируя `VrfRequestEnvelope` и валидируя `nonce`, `client_seed` и инициатора до очистки pending-состояния.【F:supra/move_workspace/lottery/sources/Lottery.move†L499-L520】【F:supra/move_workspace/lottery/sources/Lottery.move†L947-L962】
- **Whitelisting и контроль источников.** Хранилище и события управляют белыми списками агрегатора и потребителей, а колбэк требует, чтобы адрес отправителя совпадал с whitelisted агрегатором, что соответствует рекомендациям Supra по защите callback-пайплайна.【F:supra/move_workspace/lottery/sources/Lottery.move†L253-L400】【F:supra/move_workspace/lottery/sources/Lottery.move†L887-L905】
- **Валидация `rng_count` и длины ответа.** Обработчик `handle_verified_random` проверяет соответствие заявленного количества случайностей `EXPECTED_RNG_COUNT` и фактической длины вектора до обработки результата, предотвращая неполные или избыточные ответы.【F:supra/move_workspace/lottery/sources/Lottery.move†L620-L716】
- **Формула минимального депозита VRF 3.0.** `calculate_per_request_gas_fee` и `calculate_min_balance` используют параметры газа и `verification_gas_value` по формуле Supra, а события фиксируют конфигурацию для мониторинга оператором.【F:supra/move_workspace/lottery/sources/Lottery.move†L208-L335】【F:supra/move_workspace/lottery/sources/Lottery.move†L887-L940】
- **Тестовое покрытие требований Supra.** Модульные тесты охватывают whitelisting, обновление газа, проверку хеша полезной нагрузки, валидацию `rng_count` и отказ для неподписанных агрегаторов, повторяя сценарии из Supra Labs.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L302-L344】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L720】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L762-L1004】

## Матрица соответствия требованиям Supra dVRF 3.0
| Требование Supra | Реализация в контракте | Покрывающий тест |
| --- | --- | --- |
| Валидация хеша запроса, `nonce`, `client_seed`, `requester` | `record_vrf_request` сохраняет хеш, `ensure_payload_hash_matches` сверяет `message` и поля конверта перед очисткой состояния.【F:supra/move_workspace/lottery/sources/Lottery.move†L499-L520】【F:supra/move_workspace/lottery/sources/Lottery.move†L947-L962】 | `validate_payload_hash_*` тесты подтверждают успех и ошибки при подмене payload'а.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L720】 |
| Контроль `rng_count` и размеров ответа | `handle_verified_random` проверяет `rng_count` и длину `verified_nums` перед обработкой и обновлением счётчиков.【F:supra/move_workspace/lottery/sources/Lottery.move†L620-L716】 | Тесты `handle_verified_random_*` проверяют отклонение неправильных значений и события успеха.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L681-L900】 |
| Предварительная конфигурация газа и whitelisting агрегатора/потребителей | `ensure_gas_configured`, `ensure_callback_sender_configured`, `ensure_consumer_whitelisted` защищают `request_draw`, а события логируют изменения для мониторинга.【F:supra/move_workspace/lottery/sources/Lottery.move†L328-L520】【F:supra/move_workspace/lottery/sources/Lottery.move†L887-L905】 | Тесты требуют настройки газа и whitelisting, проверяют события и ошибки при нарушениях.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L302-L519】 |
| Формула минимального депозита VRF 3.0 | `calculate_per_request_gas_fee` и `calculate_min_balance` реализуют `maxGasPrice × (maxGasLimit + verificationGasValue) × minRequests` с проверкой переполнения.【F:supra/move_workspace/lottery/sources/Lottery.move†L932-L940】 | Конфигурационные тесты сверяют события и вычисленную стоимость запроса.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L302-L344】 |
| On-chain whitelisting и проверка источника колбэка | Хранилище `whitelisted_callback_sender` и `ensure_callback_caller_allowed` запрещают чужие колбэки, whitelisting потребителей контролирует `request_draw`.【F:supra/move_workspace/lottery/sources/Lottery.move†L253-L400】【F:supra/move_workspace/lottery/sources/Lottery.move†L887-L905】 | Тесты фиксируют события whitelisting и отклоняют неавторизованные колбэки.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L131-L195】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L864-L1004】 |

## Наблюдения и рекомендации
1. **Мониторинг whitelisting и колбэков.** События `AggregatorWhitelistedEvent`, `AggregatorRevokedEvent`, `ConsumerWhitelistedEvent` и `DrawRequestedEvent` предоставляют полный контекст для off-chain мониторинга; рекомендуется настроить алерты на неожиданные изменения whitelisting и запросы VRF.【F:supra/move_workspace/lottery/sources/Lottery.move†L253-L520】
2. **Автоматизация Supra Move CLI.** Хотя модульные тесты покрывают критические сценарии, рекомендуется интегрировать `supra move test` в CI/CD, чтобы своевременно обнаруживать несовместимость SDK или обновлений Supra Labs.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L200】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L900】
3. **Операционный контроль баланса подписки.** События `SubscriptionConfiguredEvent` и `MinimumBalanceUpdatedEvent` отражают расчёт минимума; операторам стоит сравнивать фактический баланс с формулой VRF 3.0 при изменении параметров газа Supra сети.【F:supra/move_workspace/lottery/sources/Lottery.move†L220-L335】【F:supra/move_workspace/lottery/sources/Lottery.move†L932-L940】

## Заключение
Реализация SupraLottery соответствует ключевым рекомендациям Supra dVRF 3.0 по валидации полезной нагрузки, whitelisting, контролю `rng_count` и управлению газовой конфигурацией. Предлагаемые операционные практики (мониторинг событий и автоматизация тестов) помогут сохранить соответствие при обновлении Supra Docs и SDK.
