# Key Findings from Supra documentation (Sep 2025 snapshot)
- dVRF 3.0 introduces request retry queue (retries every 6h up to 48h).
- Per-client and per-consumer gas controls: `maxGasPrice`/`maxGasLimit` plus contract-level `callbackGasPrice`/`callbackGasLimit`.
- Hash of request parameters stored on-chain and verified during callbacks; we must persist the additional fields needed for validation.
- Minimum balance formula: `minBalanceLimit = minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)`; `supraMinimumPerTx` is charged on failed callbacks.
- New admin functions: camelCase entry points (`addClientToWhitelist`, `clientSettingMinimumBalance`, `addContractToWhitelist`, `removeClientFromWhitelist(force_remove)`), плюс настройки газа для клиента и контрактов.
- Counters for total RNG requests/responses per client (useful for monitoring/UX).

# dVRF v3 Migration Checklist (Offline Planning)

## 1. Documentation & API Review
- [ ] Track official Supra announcements / changelog for dVRF v3 release window.
- [ ] Compare `supra_vrf::rng_request` signature between v2 and v3 (parameters, return values, new flags).
- [x] Identify changes in callback payload (nonce + clientSeed + gas fields hashed and validated).
- [x] Confirm required subscription/whitelisting steps for v3 and whether existing deposits carry over (self-whitelisting via `addClientToWhitelist`, deposit required).
- [ ] Note any new error codes / abort scenarios introduced by the framework (и обновлять [dVRF error reference](./dvrf_error_reference.md)).

## 2. Contract Changes (Lottery.move)
- [ ] Update `request_draw` to use the v3 request API (gas config, confirmations, payload).
  - Текущая реализация вызывает `supra_vrf::rng_request(sender, callback_address, callback_module, callback_function, rng_count, client_seed, num_confirmations)` без параметров газа и цен, то есть остаётся на API v2.
- [x] Adjust stored state (LotteryData хранит `max_gas_price`/`max_gas_limit`, `callback_gas_price`/`callback_gas_limit`, `verification_gas_value`, вычисленный `max_gas_fee`, счётчики запросов/ответов, `last_requester` и `last_request_payload_hash`).
- [x] Extend events (DrawRequested/DrawHandled фиксируют callback-газы, request hash, nonce и полную полезную нагрузку; FundsWithdrawn остаётся без изменений, дополнительных полей не требуется).
- [x] Align admin flows with `addClientToWhitelist`/`addContractToWhitelist`; Move-контракт фиксирует снапшоты whitelisting и события, интеграция с SDK v3 — после релиза.
- [x] Document post-onboarding verification через view-функции `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot` и проверки модуля `deposit` (`check_*`, `checkClientFund`, `isMinimumBalanceReached`, `listAllWhitelistedContractByClient`, `getSubscriptionInfoByClient`) в runbook/скриптах.
- [x] Expose `configure_vrf_request` entry for rng_count/numConfirmations/clientSeed tracking with audit event.
- [x] Add sha3-256 payload hash validation inside `on_random_received` (maintains v2 callback signature for now).
- [x] Описать онбординг подписки через `deposit::migrateClient` → `deposit::addClientToWhitelist` → `lottery::main_v2::create_subscription` (формула `min_balance`, проверки `ECLIENT_NOT_EXIST`, camelCase имена API, подтверждение `"status": "Success"` после `addClientToWhitelist`, вызовы `clientSettingMinimumBalance`/`depositFundClient`, советы по копированию YAML в `/supra/.aptos`, автоматическая проверка `INITIAL_DEPOSIT >= MIN_BALANCE_LIMIT`).
- [ ] Extend `on_random_received` for multi-value RNG arrays once v3 payload format is published.
  - Текущий обработчик проверяет длину `verified_nums`, но для выбора победителя использует только `vector::borrow(&verified_nums, 0)`.
- [x] Keep `simple_draw` as offline fallback and document when it should be used.

## 3. Testing Strategy
- [x] Update existing Move unit tests to reflect new abort codes / state transitions (см. негативные сценарии на `INVALID_REQUEST_CONFIG`, `CLIENT_SEED_REGRESSION`, `REQUEST_STILL_PENDING`, `UNEXPECTED_RNG_COUNT` в `lottery_tests.move`).
- [ ] Add tests covering новые VRF-фейлы:
  - [x] pending request guard (`#[expected_failure ... REQUEST_STILL_PENDING_ERROR]`).
  - [ ] nonce mismatch (нет отдельного теста на `E_NONCE_MISMATCH`).
  - [ ] replay protection (нет проверки повторного `message`/payload hash).
  - [x] event emission (`record_request_emits_client_seed_and_increments_counter` проверяет `DrawRequestedEvent`).
- [x] Add payload hash validation unit tests (match/mismatch scenarios, offline harness).
- [x] Document whitelist snapshot helpers в README и операционных инструкциях.
  - Runbook фиксирует команды `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot` и примеры запуска через Supra CLI.
- [x] Maintain offline tests (without VRF) via helper functions (e.g., `set_pending_request_for_test`).
  - Юнит-тесты `lottery_tests.move` и `migration_tests.move` используют `set_pending_request_for_test` для сценариев без VRF.

## 4. Tooling & Infrastructure
- [x] Record Supra endpoints: testnet `https://rpc-testnet.supra.com` (chain id 6), mainnet `https://rpc-mainnet.supra.com` (chain id 8).
- [x] Обновить CLI/Docker скрипты под `supra move tool` и актуальный модуль депозита (`clientSettingMinimumBalance`, `depositFundClient`).
- [x] Document Supra testnet runbook (`docs/testnet_runbook.md`) with migration, whitelisting, publish, request flow.
- [x] Проверить требования Supra CLI (профили вместо `--config`, отказ от `--amount`).
- [x] Зафиксировать инструкции по мониторингу событий VRF (`docs/dvrf_event_monitoring.md`) и ссылку на них в runbook/troubleshooting.
- [x] Составить отдельный справочник по CLI-командам модуля `deposit` (`docs/dvrf_deposit_cli_reference.md`) и ссылаться на него в runbook.
- [x] Подготовить и поддерживать шаблон переменных окружения (`supra/scripts/testnet_env.example`) для скрипта миграции и ручных команд.
- [x] Добавить вспомогательный скрипт `supra/scripts/calc_min_balance.py` для расчёта `min_balance`/`per_request_fee` по контрактной формуле.
- [x] Ввести единый CLI (`python -m supra.scripts <подкоманда>`) для запуска всех Python-утилит без указания путей и задокументировать его в runbook/walkthrough.
- [x] Добавить автоматический мониторинг депозита (`supra/scripts/testnet_monitor_check.sh`) и ссылку на него в runbook/справочниках.
- [x] Подготовить машиночитаемый отчёт (`supra/scripts/testnet_monitor_json.py`) и задокументировать использование в runbook/automation guide.
- [x] Реализовать webhook-уведомление (`supra/scripts/testnet_monitor_slack.py`) и описать интеграцию со Slack/AutoFi в документации.
- [x] Поддерживать экспорт метрик Prometheus (`supra/scripts/testnet_monitor_prometheus.py`) и примеры использования в runbook/automation guide.
- [x] Добавить автоматизированный запуск розыгрыша (`supra/scripts/testnet_manual_draw.py`) и задокументировать сценарий использования.
- [ ] Keep sandbox/offline mode documented for demo environments until v3 is fully whitelisted.

## 5. Frontend Impact
- [x] Expose status indicators (pending VRF request, fallback mode) via new view functions if necessary (`get_lottery_status`).
- [ ] Plan integration tests against mocked responses so frontend can demo without live VRF.

## 6. Open Questions
- Does v3 require new authentication tokens or whitelisting forms beyond current deposit/whitelist flow?
- Are there quota/fee changes that should be surfaced to admins in the frontend?
- Is there support for batching random draws/RNG arrays beyond `rng_count`, and do we need multi-draw UI?

> Keep this document updated as soon as new information about dVRF v3 becomes available.

## Source verification for pending items (Supra-Labs public repositories)

| Pending item | Supra-Labs observation (Oct 2025) | Reference |
| --- | --- | --- |
| Changelog / announcements | Каталог `documentation/dvrf` содержит только README, SUMMARY и подразделы `build-*`; файлов `changelog` или упоминаний dVRF v3 нет, поэтому релизы приходится отслеживать вручную. | [Directory listing](https://api.github.com/repos/Supra-Labs/documentation/contents/dvrf) |
| `rng_request` signature diff | Официальный гид показывает вызов `supra_vrf::rng_request(sender, callback_address, callback_module, callback_function, rng_count, client_seed, num_confirmations)` без параметров газа, что подтверждает отсутствие публичного описания v3 API. | [`documentation/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md#example-implementation) |
| Новые коды ошибок | В `supra-dev-hub/Knowledge base/Oracles_and_VRF_Errors.md` по-прежнему описаны только кейсы v2; раздел про удаление запросов подчёркивает, что фиксированный таймер появится «в следующей версии». | [`supra-dev-hub/Knowledge base/Oracles_and_VRF_Errors.md`](https://github.com/Supra-Labs/supra-dev-hub/blob/main/Knowledge%20base/Oracles_and_VRF_Errors.md#issue-summary-time-period-for-request-tobe-permanently-dropped) |
| Мульти-значные RNG массивы | Примеры Supra используют `vector::borrow(&verified_vec, 0)` и не описывают работу с массивами случайных чисел, поэтому расширение `on_random_received` пока невозможно. | [`documentation/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md#example-implementation) |
| Sandbox/offline режим | README ветки dVRF не содержит упоминаний `offline`/`sandbox`, описаны только тестнет/мейннет, так что документацию по демо-средам нужно писать самостоятельно. | [`documentation/dvrf/README.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/README.md) |
| Frontend mocked responses | Шаблон `Supra dVRF Template` вызывает боевой `supra_vrf::rng_request` и не предоставляет моков VRF, что подтверждает необходимость внутренних интеграционных тестов. | [`supra-dapp-templates/templates/Supra dVRF Template/sources/contract.move`](https://github.com/Supra-Labs/supra-dapp-templates/blob/main/templates/Supra%20dVRF%20Template/sources/contract.move) |

## Notes
- Online docs currently require interactive session; capture key API diffs manually once access available.

