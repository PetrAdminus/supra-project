# SupraLottery

SupraLottery is a family of Move packages for running lottery draws on the Supra network.

## Packages
- `lottery_core` — ticket lifecycle, round queues, treasury logic
- `lottery_support` — history, metadata, migration utilities
- `lottery_rewards` — VIP tiers, referrals, autopurchase, jackpot, NFT rewards
- `vrf_hub`, `lottery_factory`, `SupraVrf` — shared infrastructure

Each package lives in `SupraLottery/supra/move_workspace/<name>` and has its own tests and publish commands (see `docs/testnet_runbook.md`).

## Scripts
- `supra/scripts/bootstrap_move_deps.sh` — downloads aptos-core and prepares the Move cache
- `supra/scripts/build_lottery_packages.sh` — builds packages via Docker/Podman or Aptos CLI
- `supra/scripts/publish_lottery_packages.sh` — publishes core/support/rewards
- `supra/scripts/sync_lottery_queues.sh` — syncs history and purchase queues using capabilities
- `supra/scripts/move_tests.py` — runs Move tests using Supra CLI / Aptos CLI / plain Move

## Documentation
- `docs/testnet_runbook.md` — end-to-end deployment steps
- `docs/testnet_deployment_checklist.md` — pre-flight checklist
- `docs/architecture/modules.md` — capability model and package boundaries
- `docs/feature_split_plan.md` — roadmap for modularisation

## Quick start
```bash
bash supra/scripts/bootstrap_move_deps.sh
bash supra/scripts/build_lottery_packages.sh
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_core
```

## Publishing to Supra testnet
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core \n        --included-artifacts none --skip-fetch-latest-git-deps \n        --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
```
Repeat for `lottery_support` and `lottery_rewards`.

## Rollback
- Branch `backup/lottery_monolith` keeps the monolithic contract.
- Directory `SupraLottery/supra/move_workspace/lottery_backup` contains sources and tests for the legacy package.

## License
Files are provided as-is. Refer to project maintainers for licensing details.
