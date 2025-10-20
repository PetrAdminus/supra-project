# Обзор аудита интеграции Supra dVRF 3.0 для Lottery

## Источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Supra Labs на GitHub](https://github.com/Supra-Labs)
- [Build with Supra dVRF — Migration to dVRF 3.0](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md)
- [Build with Supra dVRF — Gas Configurations](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md)
- [Build with Supra dVRF — VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md)

## Методология
1. Проанализирован модуль `lottery::main_v2`, управляющий конфигурацией газа, whitelisting, формированием VRF-запросов и обработкой колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L1-L940】
2. Изучены модульные тесты `lottery_tests.move`, подтверждающие позитивные и негативные сценарии для whitelisting, валидации payload и расчёта лимитов газа.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L1033】
3. Требования Supra сверялись с официальными документами и репозиториями Supra Labs, чтобы убедиться в соответствии реализаций рекомендациям dVRF 3.0.

## Соответствие требованиям Supra
- **Валидация полезной нагрузки.** Контракт хранит sha3-256 хеш BCS-конверта VRF-запроса и в `ensure_payload_hash_matches` сверяет его с фактическим `message`, дополнительно проверяя `nonce`, `client_seed` и `requester`, как предписывает Migration to dVRF 3.0.【F:supra/move_workspace/lottery/sources/Lottery.move†L499-L520】【F:supra/move_workspace/lottery/sources/Lottery.move†L908-L927】
- **Контроль количества случайностей.** `handle_verified_random` проверяет `rng_count` и фактическую длину `verified_nums`, предотвращая приём лишних или отсутствующих значений согласно рекомендациям Supra по обработке колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L661-L679】
- **Экономика подписки.** Формула минимального баланса использует `minRequests × maxGasPrice × (maxGasLimit + verificationGasValue)` в `u128`, что совпадает с гайдом Gas Configurations и VRF Subscription FAQ.【F:supra/move_workspace/lottery/sources/Lottery.move†L132-L198】【F:supra/move_workspace/lottery/sources/Lottery.move†L932-L939】
- **Whitelisting и контроль доступа.** Лотерея хранит whitelisted агрегатора и потребителей, публикует события и проверяет `caller_address` перед VRF-запросами и при колбэке, что согласуется с VRF Subscription FAQ и рекомендациями Supra Docs.【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L671】
- **Уникальность `client_seed`.** Счётчик `next_client_seed` обеспечивает уникальные значения для каждого запроса, а событие `DrawRequestedEvent` делает сид и хеш наблюдаемыми, что соответствует рекомендациям Supra отслеживать запросы on-chain.【F:supra/move_workspace/lottery/sources/Lottery.move†L492-L520】

## Подтверждение тестами
- `validate_payload_hash_succeeds_for_matching_data` и два негативных теста доказывают корректность проверки хеша и адреса инициатора.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L586-L649】
- Тесты `handle_verified_random_rejects_wrong_rng_count` и `handle_verified_random_rejects_wrong_vector_length` демонстрируют отказ при несоответствии `rng_count` или числа значений.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L719-L811】
- `manual_draw_requires_configured_gas` и сценарии whitelisting подтверждают блокировку запросов без настроенной конфигурации газа или неавторизованных участников.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1013-L1033】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L832-L1009】

## Остаточные рекомендации
1. Подготовить операционный runbook whitelisting и мониторинга событий, чтобы соблюсти требования Supra к эксплуатационной готовности VRF-подписок.
2. Настроить автоматический запуск `supra move test -p supra/move_workspace` при появлении CLI, ориентируясь на примеры Supra Labs, для раннего выявления регрессий.
3. Интегрировать мониторинг метрик `rng_request_count`/`rng_response_count` и событий `DrawHandledEvent`, чтобы фиксировать сбои агрегатора и соответствовать рекомендациям Supra по наблюдаемости подписки.【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L701】
