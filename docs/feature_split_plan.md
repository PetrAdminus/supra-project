# SupraLottery Feature Split Plan

This document outlines the steps required to convert the monolithic `lottery` package into several Move packages. Goals: reduce publish size, make future features easier to plug in, and keep a clear rollback path.

## 1. Starting point

- Monolithic backup lives in branch `backup/lottery_monolith`.
- Current workspace contains packages `SupraVrf`, `vrf_hub`, `lottery_factory`, `lottery`.
- Publishing `lottery` exceeds the on-chain limit (~60 KB) even with minimal artifacts.

## 2. Target architecture

| Package            | Responsibility                                           | Key modules                                         |
|--------------------|----------------------------------------------------------|-----------------------------------------------------|
| `lottery_core`     | Base draw logic: ticket sales, round queues, treasury    | `Lottery`, `LotteryRounds`, `LotteryInstances`, `Treasury*` |
| `lottery_support`  | Administration & service tooling                         | `History`, `Metadata`, `Migration`                  |
| `lottery_rewards`  | Optional mechanics (marketing, loyalty, jackpots, etc.)  | `Vip`, `Referrals`, `Autopurchase`, `NftRewards`, `Jackpot`, `Store`, `RoundsSync` |
| `lottery_tests` (opt.) | Integration scenarios and utility helpers              | E2E flows, smoke tests                             |

Each package has its own `Move.toml`, `sources/`, tests, and publish commands in the runbook.

## 3. Migration strategy

1. **Dependency audit** — capture `use` and `friend` relationships, document them in `docs/architecture/modules.md`.
2. **Define package boundaries** — keep only critical logic in core; move optional features out.
3. **Replace `friend` with capabilities** — core owns capabilities and exposes borrow/return APIs.
4. **Create packages** — move files, update `Move.toml`, fix `use` paths, run tests per package.
5. **Update documentation** — describe architecture, add publish commands, refresh README.
6. **Publish sequentially** — `lottery_core` → `lottery_support` → `lottery_rewards`, store tx hashes.
7. **Review checklist** — ensure tests pass, runbook updated, capabilities accounted for, rollback branch tagged.
8. **Rollback path** — keep `backup/lottery_monolith` and `lottery_backup` workspace for legacy deployments.

## 4. Next steps

- Pin dependency revisions (`MoveStdlib`, `SupraFramework`) to specific commits.
- Harden capability usage in extension packages and extend test coverage.
- Update CI/publish scripts for the modular layout.
- Perform a dry-run deployment on Supra testnet and record real gas settings/transaction hashes.
