# Key Findings from Supra documentation (Sep 2025 snapshot)
- dVRF 3.0 introduces request retry queue (retries every 6h up to 48h).
- Per-client and per-consumer gas controls: `maxGasPrice`/`maxGasLimit` plus contract-level `callbackGasPrice`/`callbackGasLimit`.
- Hash of request parameters stored on-chain and verified during callbacks; we must persist the additional fields needed for validation.
- Minimum balance formula: `minBalanceLimit = minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)`; `supraMinimumPerTx` is charged on failed callbacks.
- New admin functions: `addClientToWhitelist`, `addContractToWhitelist`, setters for gas parameters, `removeClientFromWhitelist(forceRemove)`.
- Counters for total RNG requests/responses per client (useful for monitoring/UX).

# dVRF v3 Migration Checklist (Offline Planning)

## 1. Documentation & API Review
- [ ] Track official Supra announcements / changelog for dVRF v3 release window.
- [ ] Compare `supra_vrf::rng_request` signature between v2 and v3 (parameters, return values, new flags).
- [x] Identify changes in callback payload (nonce + clientSeed + gas fields hashed and validated).
- [x] Confirm required subscription/whitelisting steps for v3 and whether existing deposits carry over (self-whitelisting via `addClientToWhitelist`, deposit required).
- [ ] Note any new error codes / abort scenarios introduced by the framework.

## 2. Contract Changes (Lottery.move)
- [ ] Update `request_draw` to use the v3 request API (gas config, confirmations, payload).
- [x] Adjust stored state (store maxGasPrice/maxGasLimit, contract-level callbackGasPrice/Limit, request counters, sha3-256 request hash).
- [x] Extend events (DrawRequested, FundsWithdrawn) with fields necessary for v3 tracing, if applicable.
- [x] Align admin flows with `addClientToWhitelist`/`addContractToWhitelist`; Move-контракт фиксирует снапшоты whitelisting и события, интеграция с SDK v3 — после релиза.
- [x] Expose `configure_vrf_request` entry for rng_count/clientSeed tracking with audit event.
- [x] Add sha3-256 payload hash validation inside `on_random_received` (maintains v2 callback signature for now).
- [ ] Track migrateClient onboarding flow (готовим утилиту для `deposit::migrateClient` и мониторинга `minBalanceLimit`).
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
- [ ] Prepare CLI/Docker scripts for re-running tests after integrating new framework dependency (likely updated supra-cli image).
- [x] Document Supra testnet runbook (`docs/testnet_runbook.md`) with migration, whitelisting, publish, request flow.
- [ ] Verify whether `supra-cli` requires upgrades or flags for dVRF v3.
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

