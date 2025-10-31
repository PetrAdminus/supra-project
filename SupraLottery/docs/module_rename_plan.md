# Module Rename Plan (Monolith -> Split)

## Checklist
- [x] 1. Confirm new module names  
  - `lottery_core`: `core_instances`, `core_treasury_v1`, `core_main_v2`, `core_operators`, `core_treasury_multi`, `core_rounds`
  - `lottery_support`: `support_history`, `support_metadata`, `support_migration`
  - `lottery_rewards`: `rewards_autopurchase`, `rewards_jackpot`, `rewards_nft`, `rewards_referrals`, `rewards_vip`, `rewards_rounds_sync`, `rewards_store`
- [x] 2. Decide on upgrade policy configuration (current CLI warns on `upgrade_policy`, so the field is omitted for now)
- [x] 3. Rename module declarations and related structs in source files
- [x] 4. Update all `use` / `friend` imports, fully-qualified calls, docs, and scripts
- [x] 5. Recompile packages in order `lottery_core` -> `lottery_support` -> `lottery_rewards`
- [x] 6. Run Move unit tests for all three packages (core/support/rewards)
- [ ] 7. Publish updated packages to address `0xbc95…` (core -> support -> rewards) and record tx hashes
- [ ] 8. Verify on-chain state via `move tool list`, update runbook/checklist, append to `supra_history`
- [ ] 9. (Optional) Prepare data migration from legacy modules or document that legacy state is abandoned

## Notes
- Legacy `lottery::*` modules remain deployed; new `core_*`, `support_*`, `rewards_*` modules coexist on the same address.
- Future updates can reuse the new names without additional renames.
- Keep TTL <= 600s when publishing to avoid `TRANSACTION_EXPIRED` errors.*** End Patch
