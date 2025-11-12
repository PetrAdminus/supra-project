# SupraLottery Testnet Deployment Checklist

## 0. Preparation
- [ ] Sync repository (`git pull --rebase`).
- [ ] Confirm target branch (e.g. `feature-split`).
- [ ] Ensure `supra/configs/testnet.local.yaml` is filled and ignored by git.
- [ ] Run `bash supra/scripts/bootstrap_move_deps.sh` (pins aptos-core commit `7d1e62c9a5394a279a73515a150e880200640f06`). On Windows without WSL execute the Python fallback from the runbook.

## 1. Build
 - [x] ```powershell
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
- [x] Supplementary loop run to compile `lottery_factory`, `vrf_hub`, and `SupraVrf` with the same toolchain.
- [x] Verify `build/` directories are produced without errors.
- [x] Run unit tests for each package:
  ```bash
  docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
    -lc "cd /supra/SupraLottery && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.cli move-test --workspace /supra/move_workspace --package lottery_core --cli /supra/supra"
  docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
    -lc "cd /supra/SupraLottery && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.cli move-test --workspace /supra/move_workspace --package lottery_support --cli /supra/supra"
  docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
    -lc "cd /supra/SupraLottery && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.cli move-test --workspace /supra/move_workspace --package lottery_rewards --cli /supra/supra"
  ```

### Docker Compose helper (SupraLottery/compose.yaml)
Чтобы прогнать smoke-тесты для `lottery_core`, `lottery_support`, `lottery_rewards`, используй контейнер с преднастроенным entrypoint:

```powershell
docker compose -f SupraLottery/compose.yaml run --rm supra_cli `
  bash -lc "cd /supra/SupraLottery && \
       PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.cli move-test \
         --workspace supra/move_workspace \
         --package <PACKAGE_NAME> \
         --cli /supra/supra \
         --report-json tmp/move-test-report.json \
         --report-junit tmp/move-test-report.xml \
         --report-log tmp/move-test-report.log"
```

Подставь `lottery_core`, `lottery_support` и `lottery_rewards` в `--package`, чтобы удостовериться, что все три пакета собираются и проходят тесты.

## 2. Publish
- [x] Publish `lottery_core` (store tx hash).
- [x] Publish `lottery_support`.
- [x] Publish `lottery_rewards`.
- [x] Ensure `vrf_hub` and `lottery_factory` are published and up to date.
  - Tx-хеши публикаций не зафиксированы: вывод CLI был усечён в терминале.

## 3. Initialisation
- [x] Run `bash supra/scripts/sync_lottery_queues.sh`. *(выполнено эквивалентными вызовами `support_history::sync_draws_from_rounds` и `rewards_rounds_sync::sync_purchases_from_rounds`, tx hashes записаны в журнал.)*
- [x] Configure VRF whitelisting and deposits.
- [x] Confirm treasury state (`lottery_core::core_treasury_v1::is_initialized`).

## 4. Integration tests
- [ ] Execute a manual ticket purchase and draw.
- [ ] Validate VIP/referral bonus flows (if enabled).
- [ ] Fetch history snapshot (`lottery_support::support_history::get_history_snapshot`).

## 5. Documentation
- [ ] Update `docs/testnet_runbook.md` with actual tx hashes and gas params.
- [ ] Record dependency revisions (`MoveStdlib`, `SupraFramework`).
- [ ] Note changes in `docs/architecture/modules.md` if capability/API changed.

## 6. Post-release
- [ ] Tag the release (e.g. `release/testnet-YYYYMMDD`).
- [ ] Prepare a summary of actions and any deviations.
- [ ] Update frontend/integration configs if required.

