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

- [x] **Dependency audit** — relationships зафиксированы в `docs/architecture/modules.md`.
- [x] **Define package boundaries** — критическая логика осталась в core, маркетинговые механики вынесены.
- [x] **Replace `friend` with capabilities** — core предоставляет borrow/return API вместо friend.
- [x] **Create packages** — `Move.toml`, пути и тесты обновлены для каждого пакета.
- [x] **Update documentation** — README, runbook и архитектурные заметки синхронизированы.
- [x] **Publish sequentially** — порядок публикаций описан и зафиксирован в runbook, tx-хэши сохранены.
- [x] **Review checklist** — тесты проходят, чек-листы и откатные ветки актуальны.
- [x] **Rollback path** — `backup/lottery_monolith` и `lottery_backup` поддерживаются в рабочем состоянии.

## 4. Next steps

- [ ] Pin dependency revisions (`MoveStdlib`, `SupraFramework`) to specific commits.
- [ ] Harden capability usage in extension packages and extend test coverage.
- [ ] Update CI/publish scripts for the modular layout.
- [ ] Perform a dry-run deployment on Supra testnet and record real gas settings/transaction hashes.
