# SupraLottery Package Architecture

## Package overview

| Package           | Purpose                                         | Key modules                                           |
|-------------------|-------------------------------------------------|--------------------------------------------------------|
| `lottery_core`    | Core draw mechanics: ticket lifecycle, treasury | `Lottery`, `LotteryRounds`, `LotteryInstances`, `Store`, `Treasury`, `TreasuryMulti` |
| `lottery_support` | Administrative and service tooling              | `History`, `Metadata`, `Migration`                      |
| `lottery_rewards` | Optional player incentives                      | `Autopurchase`, `Jackpot`, `Referrals`, `Store` ext., `Vip`, `RoundsSync`, `NftRewards` |

`SupraVrf`, `vrf_hub`, `lottery_factory` remain independent infrastructure packages and are used by all others.

## Capability model

### `lottery_core::rounds`
- Provides `HistoryWriterCap` and `AutopurchaseRoundCap` for safe access to round queues.
- Public API includes `borrow_*_cap`, `try_borrow_*_cap`, `return_*_cap`, plus view helpers to inspect state.

### `lottery_core::treasury_v1`
- Issues treasury capabilities (`AutopurchaseTreasuryCap`, `LegacyTreasuryCap`) used by rewards and migration flows.
- Payout functions accept capability parameters, preventing unauthorized transfers.

### `lottery_support`
- `history` consumes `HistoryWriterCap` via `rounds::borrow_history_writer_cap`.
- `migration` relies on `LegacyTreasuryCap` to move balances atomically.

### `lottery_rewards`
- `autopurchase` borrows both round and treasury capabilities and returns them after processing.
- Other modules interact with core through public APIs without friend declarations.

## Guidelines for new features

1. When adding a new mechanic, create a dedicated package that depends on `lottery_core` (and optionally `lottery_support`). Request capabilities through core APIs instead of using `friend`.
2. Migration logic should live in `lottery_support`. Provide tests and scripts to run migrations safely.
3. Keep unit tests close to package sources. Integration scenarios can live in a separate test package or Python helpers.
4. Document new capabilities and public functions here so the team understands how extensions coordinate with the core.
