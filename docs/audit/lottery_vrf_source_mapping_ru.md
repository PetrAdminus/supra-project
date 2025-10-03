# Соответствие интеграции Supra dVRF 3.0 официальным источникам

## 1. Supra Docs — Overview
- **Описание требований.** Разделы Supra Docs по обзору сети подчёркивают необходимость ончейн-администрирования подписки, whitelisting агрегаторов и потребителей, а также журналирования изменений конфигурации через события.
- **Реализация в проекте.** Контракт `lottery::main_v2` ограничивает административные действия адресом `@lottery`, хранит whitelisted потребителей и агрегатора, публикует события управления и запрещает VRF-запрос без заранее настроенного whitelisted агрегатора.【F:supra/move_workspace/lottery/sources/Lottery.move†L37-L498】【F:supra/move_workspace/lottery/sources/Lottery.move†L608-L671】
- **Подтверждение тестами.** Модульные тесты проверяют whitelisting агрегатора/потребителей, запреты на дубликаты и вызовы от неавторизованных адресов, следуя рекомендациям Supra по контролю доступа.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L97-L226】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L813-L903】

## 2. Supra Docs — Move SDK
- **Описание требований.** Move SDK рекомендует использовать специализированные события, `#[test_only]`-функции и модульную структуру для прозрачности аудита и тестирования.
- **Реализация в проекте.** Контракт выделяет события для whitelisting, конфигурации газа и запросов, а также предоставляет `#[test_only]`-хелперы для чтения состояния и проверки хеша запроса.【F:supra/move_workspace/lottery/sources/Lottery.move†L104-L760】
- **Подтверждение тестами.** Тесты вызывают `handle_verified_random_for_test`, `request_payload_message_for_test` и другие хелперы для прямой проверки логики VRF и расчёта лимитов, что соответствует паттернам Move SDK.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L717】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L907-L1023】

## 3. Supra Labs на GitHub
- **Описание требований.** Примеры Supra Labs демонстрируют обязательность хеширования BCS-конверта VRF-запроса, запрет изменения газовой конфигурации при pending-запросе и использование формулы VRF 3.0 для минимального баланса подписки.
- **Реализация в проекте.** `record_vrf_request` сохраняет хеш полезной нагрузки, `ensure_payload_hash_matches` сверяет сохранённое значение с фактическим `message` и проверяет `nonce`/`client_seed`, а `calculate_min_balance` использует формулу VRF 3.0 с защитой от переполнения и запретом на изменение газа при активном запросе.【F:supra/move_workspace/lottery/sources/Lottery.move†L317-L757】【F:supra/move_workspace/lottery/sources/Lottery.move†L848-L901】
- **Подтверждение тестами.** Тесты моделируют корректные и некорректные полезные нагрузки, проверяют отказ при нулевой конфигурации газа и запрет изменения параметров во время pending-запроса, повторяя best practices Supra Labs.【F:supra/move_workspace/lottery/tests/lottery_tests.move†L587-L811】【F:supra/move_workspace/lottery/tests/lottery_tests.move†L959-L1023】

## 4. Сводка аудита
- **Статус.** Текущая реализация соблюдает ключевые требования Supra dVRF 3.0 по whitelisting, проверке payload, управлению газовой конфигурацией и экономике подписки, подтверждённые модульными тестами.
- **Рекомендации.** Продолжать документировать процедуры whitelisting и мониторить события `DrawRequestedEvent`, `AggregatorWhitelistedEvent` и отказов `E_INVALID_CALLBACK_PAYLOAD` в эксплуатационных регламентах.

## Использованные источники
1. Supra Docs — Overview: https://docs.supra.com/
2. Supra Docs — Move SDK: https://docs.supra.com/network/move/
3. Supra Labs — GitHub: https://github.com/Supra-Labs
