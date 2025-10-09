# Аудит соответствия Supra dVRF 3.0 для Lottery

## Источники и методология
- Supra Docs Overview, Supra Move SDK и раздел "Build with Supra dVRF" использованы как базовые руководства по подписке, whitelisting и обработке колбэка.[^supra-overview][^move-sdk][^dvrf]
- Репозиторий Supra Labs на GitHub применён для сопоставления примеров конфигурации газа и расчёта минимального депозита.[^supra-github]
- Анализ охватил модуль `lottery::main_v2`, управляющий подпиской, whitelisting и обработкой VRF, а также модульные тесты `lottery_tests.move` для подтверждения поведения.【F:supra/move_workspace/lottery/sources/Lottery.move†L1-L966】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L1100】

## Архитектура и ключевые инварианты
- Состояние хранит хеш последнего запроса, конфигурацию газа VRF и whitelisting потребителей/агрегатора, что соответствует требованию Supra вести on-chain контроль параметров подписки.【F:supra/move_workspace/lottery/sources/Lottery.move†L38-L176】
- Формирование VRF-запроса использует уникальный `client_seed`, сохраняет pending `nonce` и хеш BCS-конверта, а событие фиксирует параметры колбэка.【F:supra/move_workspace/lottery/sources/Lottery.move†L452-L498】
- Обработчик колбэка сверяет источник вызова, хеш полезной нагрузки, `nonce`, `client_seed` и `rng_count` до очистки состояния и выбора победителя.【F:supra/move_workspace/lottery/sources/Lottery.move†L657-L701】

## Соответствие ключевым требованиям Supra

| Требование | Источник Supra | Реализация в коде | Подтверждение тестами | Статус |
| --- | --- | --- | --- | --- |
| Проверка хеша запроса и параметров колбэка до очистки состояния | Migration to dVRF 3.0[^dvrf] | `record_vrf_request` хеширует BCS-конверт, `ensure_payload_hash_matches` сравнивает хеш и декодирует `nonce`/`client_seed` | `validate_payload_hash_succeeds_for_matching_data` и `validate_payload_hash_fails_for_mismatch` проверяют успешный и негативный сценарии | ✅【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L920】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L586-L641】 |
| Расчёт минимального баланса по формуле VRF 3.0 и фиксация параметров газа | Gas Configurations[^gas-config] | `calculate_min_balance` умножает `minRequests` на `maxGasPrice * (maxGasLimit + verificationGasValue)`; обновление газа запрещено при pending-запросе | `gas_configuration_blocked_during_pending_request` ожидает `E_REQUEST_STILL_PENDING` | ✅【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L363】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L997-L1023】 |
| On-chain whitelisting агрегатора и потребителей перед VRF-запросом | VRF Subscription FAQ[^subscription] | Функции `whitelist_callback_sender` и `whitelist_consumer` обновляют списки и события; `request_draw` требует whitelist для отправителя и агрегатора | Тесты `manual_draw_requires_whitelisted_callback_sender`, `handle_verified_random_rejects_unwhitelisted_caller` | ✅【F:supra/move_workspace/lottery/sources/Lottery.move†L238-L457】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L858-L956】 |
| Контроль `rng_count` и длины массива случайностей | Request Random Numbers — EVMs[^evm-guide] | `handle_verified_random` сравнивает заявленное и фактическое количество значений | Тесты `handle_verified_random_rejects_wrong_rng_count` и `handle_verified_random_rejects_wrong_vector_length` | ✅【F:supra/move_workspace/lottery/sources/Lottery.move†L657-L679】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L719-L811】 |
| Уникальный `client_seed` и наблюдаемость событий запроса | Migration to dVRF 3.0[^dvrf] | `next_client_seed` инкрементирует значение, `DrawRequestedEvent` публикует сид и хеш | `record_request_emits_client_seed_and_increments_counter` проверяет рост счётчиков и значение сидов | ✅【F:supra/move_workspace/lottery/sources/Lottery.move†L452-L498】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L958-L995】 |

## Обнаруженные риски и рекомендации
1. **Операционные процедуры whitelisting.** Код полагается на события whitelisting, однако документация Supra требует сопровождать on-chain операции операционными регламентами; рекомендуется актуализировать runbook и мониторинг событий `AggregatorWhitelistedEvent`/`ConsumerWhitelistedEvent`.[^subscription]【F:supra/move_workspace/lottery/sources/Lottery.move†L238-L274】
2. **Мониторинг ошибок колбэка.** При несоответствии хеша или `rng_count` выполнение аварийно завершается; стоит внедрить off-chain оповещение по событиям отказов и счётчикам `rng_request_count`/`rng_response_count`, чтобы оперативно реагировать на сбои агрегатора.[^dvrf][^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L701】

## Покрытие тестами
- Позитивный сценарий обработки VRF подтверждает очистку pending-состояния и публикацию событий победителя.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L643-L717】
- Негативные сценарии проверяют whitelisting, конфигурацию газа и отклонение колбэка при неверных параметрах.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L719-L1023】
- Тесты на хеширование и генерацию `client_seed` гарантируют неизменность параметров между повторными запросами.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L568-L995】

## Заключение
Код `lottery::main_v2` соблюдает ключевые требования Supra dVRF 3.0: запросы формируются с уникальными сидом и хешем, колбэки валидируются до очистки состояния, конфигурация газа и минимальный баланс соответствуют формуле VRF 3.0, а whitelisting агрегатора и потребителей реализован on-chain. Рекомендуется дополнительно оформить операционные процедуры whitelisting и мониторинга событий, чтобы закрыть эксплуатационные аспекты, отмеченные в официальных руководствах Supra.[^supra-overview][^subscription]

[^supra-overview]: Supra Docs, *Supra Network Overview*, https://docs.supra.com/
[^move-sdk]: Supra Docs, *Move SDK Guide*, https://docs.supra.com/network/move/
[^dvrf]: Supra Labs, *Migration to dVRF 3.0*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md
[^gas-config]: Supra Labs, *Gas Configurations*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md
[^subscription]: Supra Labs, *VRF Subscription FAQ*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md
[^evm-guide]: Supra Labs, *Request Random Numbers — EVMs*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md
[^supra-github]: Supra Labs, GitHub, https://github.com/Supra-Labs
