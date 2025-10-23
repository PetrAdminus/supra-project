# SupraLottery Contracts

Move packages that implement the SupraLottery protocol.

## Layout
```
SupraLottery/
├─ supra/
│  ├─ move_workspace/
│  │  ├─ lottery_core/
│  │  ├─ lottery_support/
│  │  ├─ lottery_rewards/
│  │  ├─ lottery_factory/
│  │  ├─ vrf_hub/
│  │  ├─ SupraVrf/
│  │  └─ lottery_backup/
│  ├─ configs/
│  └─ scripts/
├─ docs/
└─ frontend/
```

## Capabilities
- `lottery_core::rounds` – issues `HistoryWriterCap` and `AutopurchaseRoundCap`.
- `lottery_core::treasury_v1` – issues treasury capabilities for autopurchase and migration flows.
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
- Legacy publish commands remain in the runbook (section “Legacy”).
