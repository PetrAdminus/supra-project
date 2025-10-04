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
- [x] Adjust stored state (store maxGasPrice/maxGasLimit, contract-level callbackGasPrice/Limit, request counters, sha3-256 request hash).
- [x] Extend events (DrawRequested, FundsWithdrawn) with fields necessary for v3 tracing, if applicable.
- [x] Align admin flows with `addClientToWhitelist`/`addContractToWhitelist`; Move-контракт фиксирует снапшоты whitelisting и события, интеграция с SDK v3 — после релиза.
- [x] Document post-onboarding verification через view-функции `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot` и проверки модуля `deposit` (`check_*`, `checkClientFund`, `isMinimumBalanceReached`, `listAllWhitelistedContractByClient`, `getSubscriptionInfoByClient`) в runbook/скриптах.
- [x] Expose `configure_vrf_request` entry for rng_count/clientSeed tracking with audit event.
- [x] Add sha3-256 payload hash validation inside `on_random_received` (maintains v2 callback signature for now).
- [x] Описать онбординг подписки через `deposit::migrateClient` → `deposit::addClientToWhitelist` → `lottery::main_v2::create_subscription` (формула `min_balance`, проверки `ECLIENT_NOT_EXIST`, camelCase имена API, подтверждение `"status": "Success"` после `addClientToWhitelist`, вызовы `clientSettingMinimumBalance`/`depositFundClient`, советы по копированию YAML в `/supra/.aptos`, автоматическая проверка `INITIAL_DEPOSIT >= MIN_BALANCE_LIMIT`).
- [ ] Extend `on_random_received` for multi-value RNG arrays once v3 payload format is published.
- [x] Keep `simple_draw` as offline fallback and document when it should be used.

## 3. Testing Strategy
- [ ] Update existing Move unit tests to reflect new abort codes / state transitions.
- [ ] Add tests covering: pending request guard, nonce mismatch, replay protection, and event emission under v3 rules.
- [x] Add payload hash validation unit tests (match/mismatch scenarios, offline harness).
- [ ] Document whitelist snapshot helpers в README и операционных инструкциях.
- [ ] Maintain offline tests (without VRF) via helper functions (e.g., `set_pending_request_for_test`).

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

## Notes
- Online docs currently require interactive session; capture key API diffs manually once access available.

