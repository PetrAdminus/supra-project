# SupraLottery Package Architecture

## Package overview

| Package           | Purpose                                         | Key modules                                                                 |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `lottery_core`    | Core draw mechanics: ticket lifecycle, treasury | `core_main_v2`, `core_rounds`, `core_instances`, `core_operators`, `core_treasury_v1`, `core_treasury_multi` |
| `lottery_support` | Administrative and service tooling              | `support_history`, `support_metadata`, `support_migration`                  |
| `lottery_rewards` | Optional player incentives                      | `rewards_autopurchase`, `rewards_jackpot`, `rewards_nft`, `rewards_referrals`, `rewards_store`, `rewards_vip`, `rewards_rounds_sync` |

`SupraVrf`, `vrf_hub`, `lottery_factory` remain independent infrastructure packages and are used by all others.

## Capability model

### `lottery_core::core_rounds`
- Provides `HistoryWriterCap` and `AutopurchaseRoundCap` for safe access to round queues.
- Public API includes `borrow_*_cap`, `try_borrow_*_cap`, `return_*_cap`, plus view helpers to inspect state.

### `lottery_core::core_treasury_v1`
- Issues treasury capabilities (`AutopurchaseTreasuryCap`, `LegacyTreasuryCap`) used by rewards and migration flows.
- Payout functions accept capability parameters, preventing unauthorized transfers.

### `lottery_support`
- `support_history` consumes `HistoryWriterCap` via `core_rounds::borrow_history_writer_cap`.
- `support_migration` relies on `LegacyTreasuryCap` to move balances atomically.

### `lottery_rewards`
- `rewards_autopurchase` borrows both round and treasury capabilities and returns them after processing.
- Other modules interact with core through public APIs without friend declarations.

## Guidelines for new features

1. When adding a new mechanic, create a dedicated package that depends on `lottery_core` (and optionally `lottery_support`). Request capabilities through core APIs instead of using `friend`.
2. Migration logic should live in `lottery_support`. Provide tests and scripts to run migrations safely.
3. Keep unit tests close to package sources. Integration scenarios can live in a separate test package or Python helpers.
4. Document new capabilities and public functions here so the team understands how extensions coordinate with the core.
