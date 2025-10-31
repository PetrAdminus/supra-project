# SupraLottery Contracts

Move packages that implement the SupraLottery protocol.

## Layout
```
SupraLottery/
в”њв”Ђ supra/
в”‚  в”њв”Ђ move_workspace/
в”‚  в”‚  в”њв”Ђ lottery_core/
в”‚  в”‚  в”њв”Ђ lottery_support/
в”‚  в”‚  в”њв”Ђ lottery_rewards/
в”‚  в”‚  в”њв”Ђ lottery_factory/
в”‚  в”‚  в”њв”Ђ vrf_hub/
в”‚  в”‚  в”њв”Ђ SupraVrf/
в”‚  в”‚  в””в”Ђ lottery_backup/
в”‚  в”њв”Ђ configs/
в”‚  в””в”Ђ scripts/
в”њв”Ђ docs/
в””в”Ђ frontend/
```

## Capabilities
- `lottery_core::core_rounds` вЂ“ issues `HistoryWriterCap` and `AutopurchaseRoundCap`.
- `lottery_core::core_treasury_v1` вЂ“ issues treasury capabilities for autopurchase and migration flows.
- Support and rewards packages obtain capabilities only through public APIs.

## Useful scripts
| Script | Purpose |
|--------|---------|
| `bootstrap_move_deps.sh` | Fetch aptos-core/dev and prime the Move cache |
| `build_lottery_packages.sh` | Build core/support/rewards |
| `publish_lottery_packages.sh` | Publish packages to Supra testnet |
| `sync_lottery_queues.sh` | Sync history and purchase queues |
| `move_tests.py` | Run Move tests across packages |

## Testing example
```bash
python -m supra.scripts.cli move-test   --workspace supra/move_workspace   --package lottery_support
```

## Deployment checklist
See `SupraLottery/docs/testnet_deployment_checklist.md` and the runbook in `docs/testnet_runbook.md`.

## Rollback
- Use `backup/lottery_monolith` or `lottery_backup` for the legacy contract.
- Legacy publish commands remain in the runbook (section вЂњLegacyвЂќ).

