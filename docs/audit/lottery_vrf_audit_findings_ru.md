# Отчёт о проверке интеграции Supra dVRF 3.0 в Lottery

## 1. Источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Supra Labs GitHub](https://github.com/Supra-Labs)
- [Build with Supra dVRF — Migration to dVRF 3.0](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md)
- [Build with Supra dVRF — Gas Configurations](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md)
- [Build with Supra dVRF — VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md)
- [Build with Supra dVRF — Request Random Numbers (EVMs)](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md)

## 2. Краткое резюме
- Контракт `lottery::main_v2` и тесты `lottery_tests.move` соответствуют ключевым требованиям Supra dVRF 3.0: whitelisting агрегатора/клиентов, проверка хеша payload, контроль `rng_count`, уникальные `client_seed` и расчёт минимального баланса по формуле VRF 3.0.【F:supra/move_workspace/lottery/sources/Lottery.move†L37-L760】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L1-L1023】
- Критические несоответствия не обнаружены; остаются рекомендация документировать операционные процедуры whitelisting и мониторинг событий, а также регулярно запускать интеграционные тесты `supra move test -p supra/move_workspace`.

## 3. Основные находки

### 3.1 Валидация полезной нагрузки VRF-колбэка
- Хранится BCS-конверт запроса в `record_vrf_request`, его хеш сохраняется в `last_request_payload_hash`, а `ensure_payload_hash_matches` сравнивает его с фактическим `message`, дополнительно сверяя `nonce` и `client_seed`. Это соответствует разделу Migration to dVRF 3.0 о защите от подмены payload.【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L758】
- Тесты `validate_payload_hash_succeeds_for_matching_data` и `validate_payload_hash_fails_for_mismatch` подтверждают правильное поведение.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L717】

### 3.2 Экономика подписки и конфигурация газа
- `calculate_per_request_gas_fee` и `calculate_min_balance` реализуют формулу `minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)` в `u128` с защитой от переполнения, что соответствует гайду Gas Configurations.【F:supra/move_workspace/lottery/sources/Lottery.move†L723-L737】
- `configure_vrf_gas_internal` запрещает менять параметры при pending-запросе, предотвращая рассинхрон хеша payload; тесты `gas_configuration_blocked_during_pending_request` и `manual_draw_requires_configured_gas` фиксируют требование предварительной настройки газа.【F:supra/move_workspace/lottery/sources/Lottery.move†L317-L499】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L694-L995】

### 3.3 Whitelisting агрегатора и потребителей
- Контракт ведёт списки whitelisted адресов, публикует события добавления/удаления и проверяет `caller_address` в `handle_verified_random`, что соответствует рекомендациям Supra по подписной модели и управлению доступом.【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L671】
- Тесты whitelisting (например, `whitelisting_events_track_consumers_and_aggregator`, `handle_verified_random_rejects_unwhitelisted_caller`) покрывают позитивные и негативные сценарии.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L97-L903】

### 3.4 Контроль rng_count и уникальность client_seed
- `handle_verified_random` сверяет `rng_count` и длину `verified_nums` с ожидаемыми значениями, а `next_client_seed` обеспечивает уникальность сидов, публикуемых в `DrawRequestedEvent`. Требование описано в Request Random Numbers (EVMs).【F:supra/move_workspace/lottery/sources/Lottery.move†L352-L707】
- Тесты `handle_verified_random_rejects_wrong_rng_count`, `handle_verified_random_rejects_wrong_vector_length` и `record_request_emits_client_seed_and_increments_counter` подтверждают поведение.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L719-L995】

## 4. Риски и рекомендации
| Риск | Статус | Рекомендация |
| --- | --- | --- |
| Недостаточное документирование whitelisting | ✅ Выполнено | Runbook содержит пошаговую процедуру whitelisting агрегатора и потребителей с отсылками к Supra VRF Subscription FAQ.【F:docs/testnet_runbook.md†L1-L120】 |
| Отсутствие автоматизированного прогона Supra Move CLI | ✅ Выполнено | GitHub Actions workflow `supra-move-tests.yml` автоматически запускает `supra move test -p supra/move_workspace` при push/PR в ветки Test и master.【F:.github/workflows/supra-move-tests.yml†L1-L33】 |

## 5. Итог
Реализация `lottery::main_v2` соответствует требованиям Supra dVRF 3.0 по безопасности, whitelisting и экономике подписки. Рекомендуется закрепить процессы whitelisting и регрессионное тестирование в операционной документации, следуя руководствам Supra Docs и Supra Labs.
