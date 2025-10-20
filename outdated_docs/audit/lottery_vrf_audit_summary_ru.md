# Краткий аудит интеграции Supra dVRF 3.0

## Использованные источники
- [Supra Docs — Overview](https://docs.supra.com/)
- [Supra Docs — Move SDK](https://docs.supra.com/network/move/)
- [Supra Labs на GitHub](https://github.com/Supra-Labs)
- [Supra Docs — Build with Supra dVRF](https://docs.supra.com/network/move/dvrf/)

## Итоговые выводы
- **Подпись и полезная нагрузка колбэка.** Контракт сохраняет хеш BCS-конверта запроса и сверяет его с фактическим `message`, дополнительно декодируя `nonce` и `client_seed`, что соответствует рекомендациям Supra по проверке payload на цепи.[^hash-guideline][^evm-guide]【F:supra/move_workspace/lottery/sources/Lottery.move†L484-L757】
- **Экономика подписки и газовые настройки.** Минимальный баланс подписки вычисляется по формуле VRF 3.0, обновления газовой конфигурации запрещены при pending-запросе, а события фиксируют параметры, что согласуется с Supra Docs и примерами Supra Labs.[^gas-config][^supra-github]【F:supra/move_workspace/lottery/sources/Lottery.move†L317-L521】【F:supra/move_workspace/lottery/sources/Lottery.move†L723-L737】
- **Whitelisting и контроль доступа.** Реализация требует whitelisted агрегатора и потребителей, проверяет адрес отправителя колбэка и публикует события управления доступом, что соответствует рекомендациям по подписной модели.[^subscription][^add-contract]【F:supra/move_workspace/lottery/sources/Lottery.move†L205-L671】
- **Тестовое покрытие.** Позитивные и негативные тесты проверяют конфигурацию газа, whitelisting, обработку колбэка и валидацию хеша/`rng_count`, отражая руководства Supra по Move SDK и dVRF.[^move-sdk][^hash-guideline]【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L1023】

## Рекомендации
1. Продолжать документировать операционные процедуры whitelisting и обновления подписки в runbook, синхронизируя их с on-chain событиями.[^subscription]
2. Добавить эксплуатационный мониторинг за событиями `DrawRequestedEvent`, whitelisting и отказами `E_INVALID_CALLBACK_PAYLOAD`, чтобы оперативно выявлять ошибки агрегатора или конфигурации газа.[^gas-config]
3. Поддерживать автоматический прогон `supra move test -p supra/move_workspace` перед релизом, подтверждая покрытие критических сценариев, описанных в документации Supra Move SDK.[^move-sdk]

[^hash-guideline]: Supra Labs, *Migration to dVRF 3.0*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0.md
[^gas-config]: Supra Labs, *Gas Configurations*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/gas-configurations.md
[^subscription]: Supra Labs, *VRF Subscription FAQ*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md
[^add-contract]: Supra Labs, *Add Contracts to Subscription*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/add-contracts-to-subscription.md
[^evm-guide]: Supra Labs, *Request Random Numbers — EVMs*, https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md
[^supra-github]: Supra Labs, GitHub, https://github.com/Supra-Labs
[^move-sdk]: Supra Docs, *Move SDK Guide*, https://docs.supra.com/network/move/
