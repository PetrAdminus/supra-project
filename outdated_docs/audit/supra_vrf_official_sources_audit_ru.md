# Аудит интеграции Supra dVRF 3.0 для Lottery

## Использованные источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Build with Supra dVRF — Migration to dVRF 3.0](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md)
- [Build with Supra dVRF — Gas Configurations](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md)
- [Build with Supra dVRF — VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md)
- [Примеры Supra Labs на GitHub](https://github.com/Supra-Labs)

## Краткое резюме
- Контракт сохраняет sha3-256 хеш BCS-конверта dVRF-запроса и сверяет его с фактической полезной нагрузкой колбэка, дополнительно валидируя `nonce`, `client_seed` и адрес инициатора. Это отражает рекомендации разделов Migration to dVRF 3.0 по on-chain проверке payload.【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L701】【F:supra/move_workspace/lottery/sources/Lottery.move†L908-L927】
- Минимальный баланс подписки и per-request fee рассчитываются по формуле VRF 3.0 `minRequests × maxGasPrice × (maxGasLimit + verificationGasValue)` и публикуются в событиях конфигурации, что соответствует гайду Gas Configurations и требованиям управления депозитом.【F:supra/move_workspace/lottery/sources/Lottery.move†L63-L87】【F:supra/move_workspace/lottery/sources/Lottery.move†L894-L904】
- On-chain whitelisting агрегатора и потребителей, проверка источника колбэка и блокировка запросов без предварительно настроенного газа реализуют требования Supra Docs и VRF Subscription FAQ по контролю доступа и операционной готовности.【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L671】【F:supra/move_workspace/lottery/sources/Lottery.move†L744-L861】

## Ключевые выводы
- **Валидация payload.** `ensure_payload_hash_matches` сравнивает сохранённый хеш с фактическим `message`, декодирует `VrfRequestEnvelope` и проверяет поля `nonce`, `client_seed` и `requester`, что предотвращает повторное использование полезной нагрузки и соответствует миграционному гайду Supra.【F:supra/move_workspace/lottery/sources/Lottery.move†L908-L927】
- **Экономика подписки.** `calculate_per_request_gas_fee` и `calculate_min_balance` работают в `u128` и используют параметры газа и `verification_gas_value`, совпадая с формулой VRF 3.0; события конфигурации фиксируют новые значения для аудита.【F:supra/move_workspace/lottery/sources/Lottery.move†L894-L904】【F:supra/move_workspace/lottery/sources/Lottery.move†L142-L198】
- **Whitelisting и контроль доступа.** Контракт хранит whitelisted агрегатора и потребителей, публикует события изменения списков, проверяет `caller_address` и запрещает запросы для неавторизованных адресов согласно VRF Subscription FAQ и Supra Docs Overview.【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L671】【F:supra/move_workspace/lottery/sources/Lottery.move†L744-L861】
- **Тестовое покрытие.** Модуль `lottery_tests.move` включает позитивные и негативные сценарии для payload, whitelisting, `rng_count` и конфигурации газа, следуя рекомендациям Supra Labs публиковать тесты, подтверждающие интеграцию.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L995】

## Остаточные риски и рекомендации
1. **Операционный runbook.** Документировать последовательность whitelisting агрегатора и потребителей, а также ограничения на обновление конфигурации газа, чтобы эксплуатация соответствовала VRF Subscription FAQ и Supra Docs Overview.
2. **Автоматизация тестов.** Настроить периодический запуск `supra move test -p supra/move_workspace`, чтобы подтверждать сохранение требований Supra при изменениях Move-кода, как демонстрируют репозитории Supra Labs.
3. **Мониторинг событий.** Интегрировать сбор событий `SubscriptionConfiguredEvent`, `GasConfigUpdatedEvent`, `DrawRequestedEvent` и whitelisting-событий для последующего аудита и быстрой диагностики, что соответствует рекомендациям Supra по наблюдаемости подписки.

