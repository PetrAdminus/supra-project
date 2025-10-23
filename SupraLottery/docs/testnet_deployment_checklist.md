# SupraLottery Testnet Deployment Checklist

## 0. Preparation
- [ ] Sync repository (`git pull --rebase`).
- [ ] Confirm target branch (e.g. `feature-split`).
- [ ] Ensure `supra/configs/testnet.local.yaml` is filled and ignored by git.
- [ ] Run `bash supra/scripts/bootstrap_move_deps.sh` (pins aptos-core commit `7d1e62c9a5394a279a73515a150e880200640f06`). On Windows without WSL execute the Python fallback from the runbook.

## 1. Build
- [ ] ```powershell
# lottery_core
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_core \
        --skip-fetch-latest-git-deps"
# lottery_support
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_support \
        --skip-fetch-latest-git-deps"
# lottery_rewards
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_rewards \
        --skip-fetch-latest-git-deps"
```
- [ ] Verify `build/` directories are produced without errors.
- [ ] Run unit tests for each package:
  ```bash
  python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_core
  python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_support
  python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_rewards
  ```

## 2. Publish
- [ ] Publish `lottery_core` (store tx hash).
- [ ] Publish `lottery_support`.
- [ ] Publish `lottery_rewards`.
- [ ] Ensure `vrf_hub` and `lottery_factory` are published and up to date.

## 3. Initialisation
- [ ] Run `bash supra/scripts/sync_lottery_queues.sh`.
- [ ] Configure VRF whitelisting and deposits.
- [ ] Confirm treasury state (`lottery_core::treasury_v1::is_initialized`).

## 4. Integration tests
- [ ] Execute a manual ticket purchase and draw.
- [ ] Validate VIP/referral bonus flows (if enabled).
- [ ] Fetch history snapshot (`lottery_support::history::get_history_snapshot`).

## 5. Documentation
- [ ] Update `docs/testnet_runbook.md` with actual tx hashes and gas params.
- [ ] Record dependency revisions (`MoveStdlib`, `SupraFramework`).
- [ ] Note changes in `docs/architecture/modules.md` if capability/API changed.

## 6. Post-release
- [ ] Tag the release (e.g. `release/testnet-YYYYMMDD`).
- [ ] Prepare a summary of actions and any deviations.
- [ ] Update frontend/integration configs if required.
