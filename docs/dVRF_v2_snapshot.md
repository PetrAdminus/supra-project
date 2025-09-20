# Current dVRF v2 Integration Snapshot

## Entry Points
- `manual_draw` triggers `request_draw` which in turn calls `supra_vrf::rng_request`.
- `simple_draw` remains purely deterministic using timestamp (offline fallback).
- `on_random_received` validates nonce, empties pending flag, extracts random winner, emits `WinnerSelected` event.

## Stored State
- `LotteryData.pending_request: option<u64>` tracks outstanding VRF requests.
- `LotteryData.max_gas_fee: u64` is set via admin functions and reused for subscription settings.
- `LotteryData.last_request_payload_hash: option<vector<u8>>` stores the sha3-256 hash of the VRF request envelope for downstream validation.

## Events
- `DrawRequestedEvent { nonce }` emitted after requesting randomness.
- `WinnerSelected { winner, prize }` emitted both for simple and VRF flows.
- Admin/operational events: `SubscriptionConfiguredEvent`, `MinimumBalanceUpdatedEvent`, `FundsWithdrawnEvent`, `TicketBought`.

## View Functions
- `get_lottery_status` aggregates ticket count, draw scheduling flag, pending VRF request flag, jackpot amount, and RNG counters.
- `get_vrf_gas_config` / `get_callback_gas_config` expose current gas parameters.
- `get_rng_counters` returns total VRF request and response counts.

## Helper Functions
- `set_pending_request_for_test` (test-only) manipulates pending state to emulate VRF callbacks.
- `withdraw_funds_for_test`, `set_minimum_balance_for_test` avoid calling native deposit functions.

## Tests
- `simple_draw_rejects_when_pending_request` ensures fallback is blocked if VRF is pending.
- Additional tests cover admin guards, event emission, view functions, and pending-state toggling.

## TODO for v3 Migration
- Any new parameters or limits required by `rng_request` need to be stored (e.g., gas limit, callback mode).
- Update events/tests accordingly.

This document reflects the code as of commit 3009338.
