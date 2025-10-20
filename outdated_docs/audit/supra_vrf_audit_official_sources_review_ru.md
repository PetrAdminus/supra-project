# Аудит интеграции Supra dVRF 3.0

## Использованные источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK и dVRF](https://docs.supra.com/network/move/)
- [Репозиторий Supra Labs](https://github.com/Supra-Labs)

## Методология
1. Изучена реализация смарт-контракта лотереи в файле `supra/move_workspace/lottery/sources/Lottery.move`, включая хранение состояния, события, проверки whitelisting и обработку VRF-колбэков.
2. Проанализированы модульные тесты `supra/move_workspace/lottery/tests/lottery_tests.move`, покрывающие whitelisting, валидацию хеша полезной нагрузки, контроль `rng_count` и конфигурацию газа.
3. Сопоставлены требования Supra dVRF 3.0 из официальной документации (формула минимального баланса, проверка хеша запроса, whitelisting агрегатора и потребителей, логирование `client_seed`) с текущим кодом и тестами.

## Соответствие ключевым требованиям Supra
### Валидация хеша полезной нагрузки VRF-колбэка
- Контракт сохраняет sha3-256 хеш BCS-кодированного `VrfRequestEnvelope`, включая `nonce`, `client_seed`, параметры газа и адрес инициатора. Поле `last_request_payload_hash` очищается только после успешной проверки колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L44-L90】【F:supra/move_workspace/lottery/sources/Lottery.move†L512-L560】
- `ensure_payload_hash_matches` пересчитывает хеш по пришедшему `message`, декодирует конверт и сверяет `nonce`, `client_seed` и `requester` перед обработкой случайности. Несоответствие приводит к `E_INVALID_CALLBACK_PAYLOAD`, что соответствует требованию Supra проверять целостность полезной нагрузки колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L914-L948】

### Контроль `rng_count` и размера результата
- Обработчик `handle_verified_random` требует, чтобы `rng_count` и фактическая длина `verified_nums` совпадали с константой `EXPECTED_RNG_COUNT`, что предотвращает принятие ответов с неожиданным количеством случайностей.【F:supra/move_workspace/lottery/sources/Lottery.move†L66-L78】【F:supra/move_workspace/lottery/sources/Lottery.move†L874-L910】

### Газовая конфигурация и минимальный баланс подписки
- Конфигурация газа может обновляться только при отсутствии активного запроса (`E_REQUEST_STILL_PENDING`), а значения сохраняются в состоянии и транслируются через событие `GasConfigUpdatedEvent` для мониторинга.【F:supra/move_workspace/lottery/sources/Lottery.move†L320-L380】
- Минимальный баланс подписки вычисляется по формуле VRF 3.0 `MIN_REQUEST_WINDOW * max_gas_price * (max_gas_limit + verification_gas_value)`, при этом выполняется проверка переполнения и синхронизация с депозитным модулем через `MinimumBalanceUpdatedEvent`. Это реализует рекомендации Supra по обеспечению достаточного депозита до отправки запросов.【F:supra/move_workspace/lottery/sources/Lottery.move†L220-L312】【F:supra/move_workspace/lottery/sources/Lottery.move†L900-L934】

### Whitelisting и контроль источника колбэка
- Контракт хранит whitelisted-потребителей и адрес агрегатора, эмитируя события при изменениях. Вызов VRF-запроса возможен только от whitelisted-адреса, а обработка колбэка сверяет `caller_address` с сохранённым агрегатором, что соответствует требованиям Supra по whitelisting.【F:supra/move_workspace/lottery/sources/Lottery.move†L48-L90】【F:supra/move_workspace/lottery/sources/Lottery.move†L832-L908】

### Логирование `client_seed` и отслеживание запросов
- `request_draw` использует уникальный `client_seed`, увеличиваемый функцией `next_client_seed`, и публикует его в событии `DrawRequestedEvent`, позволяя аудиторам сопоставлять хеши и инициаторов запросов.【F:supra/move_workspace/lottery/sources/Lottery.move†L430-L520】
- Счётчики `rng_request_count` и `rng_response_count` обновляются при успешных операциях, что отражает рекомендации Supra отслеживать жизненный цикл запросов.【F:supra/move_workspace/lottery/sources/Lottery.move†L44-L86】【F:supra/move_workspace/lottery/sources/Lottery.move†L848-L884】

## Тестовое покрытие
- Тесты проверяют whitelisting, события и ограничения повторного добавления потребителей/агрегатора, что подтверждает корректность on-chain контроля доступа.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L140】
- Модульные проверки `record_request_for_test`, `handle_verified_random_for_test` и связанные сценарии моделируют корректные и ошибочные колбэки, включая расхождение хеша и `rng_count`, тем самым подтверждая защиту от подмены payload'а и некорректных ответов Supra dVRF.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L200-L360】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L360-L520】

## Выводы и рекомендации
1. Реализация соответствует ключевым требованиям Supra dVRF 3.0: проверка хеша полезной нагрузки, whitelisting агрегатора/потребителей, контроль `rng_count`, хранение и публикация `client_seed`, а также расчёт минимального баланса по формуле VRF 3.0.
2. Рекомендуется поддерживать синхронизацию с обновлениями в репозитории Supra Labs и документации Move SDK, чтобы своевременно добавить поддержку новых полей payload'а или изменений в API.
3. Операционным командам следует мониторить события `GasConfigUpdatedEvent`, `DrawRequestedEvent` и `DrawHandledEvent`, чтобы фиксировать конфигурацию газа и статус запросов в off-chain системах наблюдения.
