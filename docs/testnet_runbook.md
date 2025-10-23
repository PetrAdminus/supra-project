# SupraLottery Testnet Runbook

This runbook describes how to prepare the environment, build, publish and verify the modular SupraLottery contracts on Supra testnet.

## 1. Requirements
- Docker Desktop (or Podman) with `docker compose`.
- Python 3.10+ for helper scripts.
- Local Supra CLI profile: copy `supra/configs/testnet.yaml` to `supra/configs/testnet.local.yaml`, fill `account_address` and `private_key`.
- Test SUPRA balance on the selected account.

## 2. Bootstrap Move dependencies
```bash
bash supra/scripts/bootstrap_move_deps.sh
```
This pulls commit `7d1e62c9a5394a279a73515a150e880200640f06` of aptos-core and hydrates the local Move cache.
This downloads `aptos-core` (branch `dev`) and seeds the `~/.move` cache so further builds do not fetch git deps every time.

## 3. Build packages
```bash
bash supra/scripts/build_lottery_packages.sh lottery_core lottery_support lottery_rewards
```
The script uses Docker/Podman or Aptos CLI (if `MOVE_CLI` is set) and writes artifacts to `supra/move_workspace/<pkg>/build`.

## 4. Run unit tests
```bash
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_core --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_support --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_rewards --skip-fetch-latest-git-deps
```

## 5. Publish packages
Example for Docker (replace `my_profile`):
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
```
Run the same command for `lottery_support` and `lottery_rewards`. For Podman see `supra/scripts/publish_lottery_packages.sh` (handles volume suffixes and extra args).

## 6. Post-publish initialisation
```bash
bash supra/scripts/sync_lottery_queues.sh
```
Use capability APIs to drain/initialise history and purchase queues. Ensure VRF whitelisting and deposits are configured (see docs).

## 7. Validation checklist
- Inspect events via `supra move tool show` or `supra move tool view`.
- Confirm treasury and queue state via view functions (`lottery_core::treasury_v1::is_initialized`, etc.).
- Execute a manual draw or integration script.

## 8. Legacy fallback
If monolithic deployment is required:
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_backup         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 200000 --expiration-secs 600 --assume-yes"
```
Follow historical instructions for initialisation (see `SupraLottery/docs/testnet_deployment_checklist.md`).

## 9. References
- https://docs.supra.com
- `supra/scripts/publish_lottery_packages.sh`
- `supra/scripts/sync_lottery_queues.sh`
