# Key Findings from Supra documentation (Sep 2025 snapshot)
- dVRF 3.0 introduces request retry queue (retries every 6h up to 48h).
- Per-client and per-consumer gas controls: `maxGasPrice`/`maxGasLimit` plus contract-level `callbackGasPrice`/`callbackGasLimit`.
- Hash of request parameters stored on-chain and verified during callbacks; we must persist the additional fields needed for validation.
- Minimum balance formula: `minBalanceLimit = minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)`; `supraMinimumPerTx` is charged on failed callbacks.
- New admin functions: camelCase entry points (`addClientToWhitelist`, `clientSettingMinimumBalance`, `addContractToWhitelist`, `removeClientFromWhitelist(force_remove)`), РїР»СЋСЃ РЅР°СЃС‚СЂРѕР№РєРё РіР°Р·Р° РґР»СЏ РєР»РёРµРЅС‚Р° Рё РєРѕРЅС‚СЂР°РєС‚РѕРІ.
- Counters for total RNG requests/responses per client (useful for monitoring/UX).

# dVRF v3 Migration Checklist (Offline Planning)

## 1. Documentation & API Review
- [ ] Track official Supra announcements / changelog for dVRF v3 release window.
- [ ] Compare `supra_vrf::rng_request` signature between v2 and v3 (parameters, return values, new flags).
- [x] Identify changes in callback payload (nonce + clientSeed + gas fields hashed and validated).
- [x] Confirm required subscription/whitelisting steps for v3 and whether existing deposits carry over (self-whitelisting via `addClientToWhitelist`, deposit required).
- [x] Note any new error codes / abort scenarios introduced by the framework (см. [dVRF error reference](./dvrf_error_reference.md)).

## 2. Contract Changes (Lottery.move)
- [ ] Update `request_draw` to use the v3 request API (gas config, confirmations, payload).
  - Статус: ожидаем публикацию официальной сигнатуры `rng_request` с параметрами газа; текущая документация Supra описывает только v2-вызов.
  - РўРµРєСѓС‰Р°СЏ СЂРµР°Р»РёР·Р°С†РёСЏ РІС‹Р·С‹РІР°РµС‚ `supra_vrf::rng_request(sender, callback_address, callback_module, callback_function, rng_count, client_seed, num_confirmations)` Р±РµР· РїР°СЂР°РјРµС‚СЂРѕРІ РіР°Р·Р° Рё С†РµРЅ, С‚Рѕ РµСЃС‚СЊ РѕСЃС‚Р°С‘С‚СЃСЏ РЅР° API v2.
- [x] Adjust stored state (LotteryData С…СЂР°РЅРёС‚ `max_gas_price`/`max_gas_limit`, `callback_gas_price`/`callback_gas_limit`, `verification_gas_value`, РІС‹С‡РёСЃР»РµРЅРЅС‹Р№ `max_gas_fee`, СЃС‡С‘С‚С‡РёРєРё Р·Р°РїСЂРѕСЃРѕРІ/РѕС‚РІРµС‚РѕРІ, `last_requester` Рё `last_request_payload_hash`).
- [x] Extend events (DrawRequested/DrawHandled С„РёРєСЃРёСЂСѓСЋС‚ callback-РіР°Р·С‹, request hash, nonce Рё РїРѕР»РЅСѓСЋ РїРѕР»РµР·РЅСѓСЋ РЅР°РіСЂСѓР·РєСѓ; FundsWithdrawn РѕСЃС‚Р°С‘С‚СЃСЏ Р±РµР· РёР·РјРµРЅРµРЅРёР№, РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅС‹С… РїРѕР»РµР№ РЅРµ С‚СЂРµР±СѓРµС‚СЃСЏ).
- [x] Align admin flows with `addClientToWhitelist`/`addContractToWhitelist`; Move-РєРѕРЅС‚СЂР°РєС‚ С„РёРєСЃРёСЂСѓРµС‚ СЃРЅР°РїС€РѕС‚С‹ whitelisting Рё СЃРѕР±С‹С‚РёСЏ, РёРЅС‚РµРіСЂР°С†РёСЏ СЃ SDK v3 вЂ” РїРѕСЃР»Рµ СЂРµР»РёР·Р°.
- [x] Document post-onboarding verification С‡РµСЂРµР· view-С„СѓРЅРєС†РёРё `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot` Рё РїСЂРѕРІРµСЂРєРё РјРѕРґСѓР»СЏ `deposit` (`check_*`, `checkClientFund`, `isMinimumBalanceReached`, `listAllWhitelistedContractByClient`, `getSubscriptionInfoByClient`) РІ runbook/СЃРєСЂРёРїС‚Р°С….
- [x] Expose `configure_vrf_request` entry for rng_count/numConfirmations/clientSeed tracking with audit event.
- [x] Add sha3-256 payload hash validation inside `on_random_received` (maintains v2 callback signature for now).
- [x] РћРїРёСЃР°С‚СЊ РѕРЅР±РѕСЂРґРёРЅРі РїРѕРґРїРёСЃРєРё С‡РµСЂРµР· `deposit::migrateClient` в†’ `deposit::addClientToWhitelist` в†’ `lottery::core_main_v2::create_subscription` (С„РѕСЂРјСѓР»Р° `min_balance`, РїСЂРѕРІРµСЂРєРё `ECLIENT_NOT_EXIST`, camelCase РёРјРµРЅР° API, РїРѕРґС‚РІРµСЂР¶РґРµРЅРёРµ `"status": "Success"` РїРѕСЃР»Рµ `addClientToWhitelist`, РІС‹Р·РѕРІС‹ `clientSettingMinimumBalance`/`depositFundClient`, СЃРѕРІРµС‚С‹ РїРѕ РєРѕРїРёСЂРѕРІР°РЅРёСЋ YAML РІ `/supra/.aptos`, Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєР°СЏ РїСЂРѕРІРµСЂРєР° `INITIAL_DEPOSIT >= MIN_BALANCE_LIMIT`).
- [ ] Extend `on_random_received` for multi-value RNG arrays once v3 payload format is published.
  - Статус: блокирующее внешнее требование — Supra пока не раскрыла формат массива случайностей в v3.
  - РўРµРєСѓС‰РёР№ РѕР±СЂР°Р±РѕС‚С‡РёРє РїСЂРѕРІРµСЂСЏРµС‚ РґР»РёРЅСѓ `verified_nums`, РЅРѕ РґР»СЏ РІС‹Р±РѕСЂР° РїРѕР±РµРґРёС‚РµР»СЏ РёСЃРїРѕР»СЊР·СѓРµС‚ С‚РѕР»СЊРєРѕ `vector::borrow(&verified_nums, 0)`.
- [x] Keep `simple_draw` as offline fallback and document when it should be used.

## 3. Testing Strategy
- [x] Update existing Move unit tests to reflect new abort codes / state transitions (СЃРј. РЅРµРіР°С‚РёРІРЅС‹Рµ СЃС†РµРЅР°СЂРёРё РЅР° `INVALID_REQUEST_CONFIG`, `CLIENT_SEED_REGRESSION`, `REQUEST_STILL_PENDING`, `UNEXPECTED_RNG_COUNT` РІ `lottery_tests.move`).
- [x] Add tests covering РЅРѕРІС‹Рµ VRF-С„РµР№Р»С‹:
  - [x] pending request guard (`#[expected_failure ... REQUEST_STILL_PENDING_ERROR]`).
  - [x] nonce mismatch (`core_vrf_callback_tests::on_random_received_rejects_nonce_mismatch`).
  - [x] replay protection (`core_vrf_callback_tests::on_random_received_rejects_payload_mismatch`).
  - [x] event emission (`record_request_emits_client_seed_and_increments_counter` РїСЂРѕРІРµСЂСЏРµС‚ `DrawRequestedEvent`).
- [x] Add payload hash validation unit tests (match/mismatch scenarios, offline harness).
- [x] Document whitelist snapshot helpers РІ README Рё РѕРїРµСЂР°С†РёРѕРЅРЅС‹С… РёРЅСЃС‚СЂСѓРєС†РёСЏС….
  - Runbook С„РёРєСЃРёСЂСѓРµС‚ РєРѕРјР°РЅРґС‹ `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot` Рё РїСЂРёРјРµСЂС‹ Р·Р°РїСѓСЃРєР° С‡РµСЂРµР· Supra CLI.
- [x] Maintain offline tests (without VRF) via helper functions (e.g., `set_pending_request_for_test`).
  - Р®РЅРёС‚-С‚РµСЃС‚С‹ `lottery_tests.move` Рё `migration_tests.move` РёСЃРїРѕР»СЊР·СѓСЋС‚ `set_pending_request_for_test` РґР»СЏ СЃС†РµРЅР°СЂРёРµРІ Р±РµР· VRF.

## 4. Tooling & Infrastructure
- [x] Record Supra endpoints: testnet `https://rpc-testnet.supra.com` (chain id 6), mainnet `https://rpc-mainnet.supra.com` (chain id 8).
- [x] РћР±РЅРѕРІРёС‚СЊ CLI/Docker СЃРєСЂРёРїС‚С‹ РїРѕРґ `supra move tool` Рё Р°РєС‚СѓР°Р»СЊРЅС‹Р№ РјРѕРґСѓР»СЊ РґРµРїРѕР·РёС‚Р° (`clientSettingMinimumBalance`, `depositFundClient`).
- [x] Document Supra testnet runbook (`docs/testnet_runbook.md`) with migration, whitelisting, publish, request flow.
- [x] РџСЂРѕРІРµСЂРёС‚СЊ С‚СЂРµР±РѕРІР°РЅРёСЏ Supra CLI (РїСЂРѕС„РёР»Рё РІРјРµСЃС‚Рѕ `--config`, РѕС‚РєР°Р· РѕС‚ `--amount`).
- [x] Р—Р°С„РёРєСЃРёСЂРѕРІР°С‚СЊ РёРЅСЃС‚СЂСѓРєС†РёРё РїРѕ РјРѕРЅРёС‚РѕСЂРёРЅРіСѓ СЃРѕР±С‹С‚РёР№ VRF (`docs/dvrf_event_monitoring.md`) Рё СЃСЃС‹Р»РєСѓ РЅР° РЅРёС… РІ runbook/troubleshooting.
- [x] РЎРѕСЃС‚Р°РІРёС‚СЊ РѕС‚РґРµР»СЊРЅС‹Р№ СЃРїСЂР°РІРѕС‡РЅРёРє РїРѕ CLI-РєРѕРјР°РЅРґР°Рј РјРѕРґСѓР»СЏ `deposit` (`docs/dvrf_deposit_cli_reference.md`) Рё СЃСЃС‹Р»Р°С‚СЊСЃСЏ РЅР° РЅРµРіРѕ РІ runbook.
- [x] РџРѕРґРіРѕС‚РѕРІРёС‚СЊ Рё РїРѕРґРґРµСЂР¶РёРІР°С‚СЊ С€Р°Р±Р»РѕРЅ РїРµСЂРµРјРµРЅРЅС‹С… РѕРєСЂСѓР¶РµРЅРёСЏ (`supra/scripts/testnet_env.example`) РґР»СЏ СЃРєСЂРёРїС‚Р° РјРёРіСЂР°С†РёРё Рё СЂСѓС‡РЅС‹С… РєРѕРјР°РЅРґ.
- [x] Р”РѕР±Р°РІРёС‚СЊ РІСЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹Р№ СЃРєСЂРёРїС‚ `supra/scripts/calc_min_balance.py` РґР»СЏ СЂР°СЃС‡С‘С‚Р° `min_balance`/`per_request_fee` РїРѕ РєРѕРЅС‚СЂР°РєС‚РЅРѕР№ С„РѕСЂРјСѓР»Рµ.
- [x] Р’РІРµСЃС‚Рё РµРґРёРЅС‹Р№ CLI (`python -m supra.scripts <РїРѕРґРєРѕРјР°РЅРґР°>`) РґР»СЏ Р·Р°РїСѓСЃРєР° РІСЃРµС… Python-СѓС‚РёР»РёС‚ Р±РµР· СѓРєР°Р·Р°РЅРёСЏ РїСѓС‚РµР№ Рё Р·Р°РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ РµРіРѕ РІ runbook/walkthrough.
- [x] Р”РѕР±Р°РІРёС‚СЊ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРёР№ РјРѕРЅРёС‚РѕСЂРёРЅРі РґРµРїРѕР·РёС‚Р° (`supra/scripts/testnet_monitor_check.sh`) Рё СЃСЃС‹Р»РєСѓ РЅР° РЅРµРіРѕ РІ runbook/СЃРїСЂР°РІРѕС‡РЅРёРєР°С….
- [x] РџРѕРґРіРѕС‚РѕРІРёС‚СЊ РјР°С€РёРЅРѕС‡РёС‚Р°РµРјС‹Р№ РѕС‚С‡С‘С‚ (`supra/scripts/testnet_monitor_json.py`) Рё Р·Р°РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ РІ runbook/automation guide.
- [x] Р РµР°Р»РёР·РѕРІР°С‚СЊ webhook-СѓРІРµРґРѕРјР»РµРЅРёРµ (`supra/scripts/testnet_monitor_slack.py`) Рё РѕРїРёСЃР°С‚СЊ РёРЅС‚РµРіСЂР°С†РёСЋ СЃРѕ Slack/AutoFi РІ РґРѕРєСѓРјРµРЅС‚Р°С†РёРё.
- [x] РџРѕРґРґРµСЂР¶РёРІР°С‚СЊ СЌРєСЃРїРѕСЂС‚ РјРµС‚СЂРёРє Prometheus (`supra/scripts/testnet_monitor_prometheus.py`) Рё РїСЂРёРјРµСЂС‹ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёСЏ РІ runbook/automation guide.
- [x] Р”РѕР±Р°РІРёС‚СЊ Р°РІС‚РѕРјР°С‚РёР·РёСЂРѕРІР°РЅРЅС‹Р№ Р·Р°РїСѓСЃРє СЂРѕР·С‹РіСЂС‹С€Р° (`supra/scripts/testnet_manual_draw.py`) Рё Р·Р°РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ СЃС†РµРЅР°СЂРёР№ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёСЏ.
- [x] Keep sandbox/offline mode documented for demo environments until v3 is fully whitelisted (см. runbook, раздел «Оффлайн и демо режим»).

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
| Changelog / announcements | РљР°С‚Р°Р»РѕРі `documentation/dvrf` СЃРѕРґРµСЂР¶РёС‚ С‚РѕР»СЊРєРѕ README, SUMMARY Рё РїРѕРґСЂР°Р·РґРµР»С‹ `build-*`; С„Р°Р№Р»РѕРІ `changelog` РёР»Рё СѓРїРѕРјРёРЅР°РЅРёР№ dVRF v3 РЅРµС‚, РїРѕСЌС‚РѕРјСѓ СЂРµР»РёР·С‹ РїСЂРёС…РѕРґРёС‚СЃСЏ РѕС‚СЃР»РµР¶РёРІР°С‚СЊ РІСЂСѓС‡РЅСѓСЋ. | [Directory listing](https://api.github.com/repos/Supra-Labs/documentation/contents/dvrf) |
| `rng_request` signature diff | РћС„РёС†РёР°Р»СЊРЅС‹Р№ РіРёРґ РїРѕРєР°Р·С‹РІР°РµС‚ РІС‹Р·РѕРІ `supra_vrf::rng_request(sender, callback_address, callback_module, callback_function, rng_count, client_seed, num_confirmations)` Р±РµР· РїР°СЂР°РјРµС‚СЂРѕРІ РіР°Р·Р°, С‡С‚Рѕ РїРѕРґС‚РІРµСЂР¶РґР°РµС‚ РѕС‚СЃСѓС‚СЃС‚РІРёРµ РїСѓР±Р»РёС‡РЅРѕРіРѕ РѕРїРёСЃР°РЅРёСЏ v3 API. | [`documentation/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md#example-implementation) |
| РќРѕРІС‹Рµ РєРѕРґС‹ РѕС€РёР±РѕРє | Р’ `supra-dev-hub/Knowledge base/Oracles_and_VRF_Errors.md` РїРѕ-РїСЂРµР¶РЅРµРјСѓ РѕРїРёСЃР°РЅС‹ С‚РѕР»СЊРєРѕ РєРµР№СЃС‹ v2; СЂР°Р·РґРµР» РїСЂРѕ СѓРґР°Р»РµРЅРёРµ Р·Р°РїСЂРѕСЃРѕРІ РїРѕРґС‡С‘СЂРєРёРІР°РµС‚, С‡С‚Рѕ С„РёРєСЃРёСЂРѕРІР°РЅРЅС‹Р№ С‚Р°Р№РјРµСЂ РїРѕСЏРІРёС‚СЃСЏ В«РІ СЃР»РµРґСѓСЋС‰РµР№ РІРµСЂСЃРёРёВ». | [`supra-dev-hub/Knowledge base/Oracles_and_VRF_Errors.md`](https://github.com/Supra-Labs/supra-dev-hub/blob/main/Knowledge%20base/Oracles_and_VRF_Errors.md#issue-summary-time-period-for-request-tobe-permanently-dropped) |
| РњСѓР»СЊС‚Рё-Р·РЅР°С‡РЅС‹Рµ RNG РјР°СЃСЃРёРІС‹ | РџСЂРёРјРµСЂС‹ Supra РёСЃРїРѕР»СЊР·СѓСЋС‚ `vector::borrow(&verified_vec, 0)` Рё РЅРµ РѕРїРёСЃС‹РІР°СЋС‚ СЂР°Р±РѕС‚Сѓ СЃ РјР°СЃСЃРёРІР°РјРё СЃР»СѓС‡Р°Р№РЅС‹С… С‡РёСЃРµР», РїРѕСЌС‚РѕРјСѓ СЂР°СЃС€РёСЂРµРЅРёРµ `on_random_received` РїРѕРєР° РЅРµРІРѕР·РјРѕР¶РЅРѕ. | [`documentation/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/build-supra-l1-dvrf-2.0/v2-guide.md#example-implementation) |
| Sandbox/offline СЂРµР¶РёРј | README РІРµС‚РєРё dVRF РЅРµ СЃРѕРґРµСЂР¶РёС‚ СѓРїРѕРјРёРЅР°РЅРёР№ `offline`/`sandbox`, РѕРїРёСЃР°РЅС‹ С‚РѕР»СЊРєРѕ С‚РµСЃС‚РЅРµС‚/РјРµР№РЅРЅРµС‚, С‚Р°Рє С‡С‚Рѕ РґРѕРєСѓРјРµРЅС‚Р°С†РёСЋ РїРѕ РґРµРјРѕ-СЃСЂРµРґР°Рј РЅСѓР¶РЅРѕ РїРёСЃР°С‚СЊ СЃР°РјРѕСЃС‚РѕСЏС‚РµР»СЊРЅРѕ. | [`documentation/dvrf/README.md`](https://github.com/Supra-Labs/documentation/blob/main/dvrf/README.md) |
| Frontend mocked responses | РЁР°Р±Р»РѕРЅ `Supra dVRF Template` РІС‹Р·С‹РІР°РµС‚ Р±РѕРµРІРѕР№ `supra_vrf::rng_request` Рё РЅРµ РїСЂРµРґРѕСЃС‚Р°РІР»СЏРµС‚ РјРѕРєРѕРІ VRF, С‡С‚Рѕ РїРѕРґС‚РІРµСЂР¶РґР°РµС‚ РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚СЊ РІРЅСѓС‚СЂРµРЅРЅРёС… РёРЅС‚РµРіСЂР°С†РёРѕРЅРЅС‹С… С‚РµСЃС‚РѕРІ. | [`supra-dapp-templates/templates/Supra dVRF Template/sources/contract.move`](https://github.com/Supra-Labs/supra-dapp-templates/blob/main/templates/Supra%20dVRF%20Template/sources/contract.move) |

## Notes
- Online docs currently require interactive session; capture key API diffs manually once access available.


