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
- `supra/scripts/build_lottery_packages.sh` — builds packages via Supra CLI (локальный бинарь, Docker Compose или Podman)
- `supra/scripts/publish_lottery_packages.sh` — publishes core/support/rewards
- `supra/scripts/sync_lottery_queues.sh` — syncs history and purchase queues using capabilities
- `SupraLottery/supra/scripts/move_tests.py` — запускает Move-тесты через Supra CLI или ванильный Move CLI

## Documentation
- `docs/testnet_runbook.md` — end-to-end deployment steps
- `docs/testnet_deployment_checklist.md` — pre-flight checklist
- `docs/architecture/modules.md` — capability model and package boundaries
- `docs/feature_split_plan.md` — roadmap for modularisation
- `docs/dvrf_v3_migration_plan.md` — ход миграции SupraLottery на dVRF 3.0 с отмеченными шагами и рисками
- `docs/dvrf_error_reference.md` — таблица аварийных кодов и советов по устранению для dVRF 3.0

## Testing
Move-тесты запускаются через Python-обёртку, которая автоматически подбирает Supra CLI (`supra`) или ванильный Move CLI (`move`). Рекомендуемый сценарий — использовать Docker-контейнер Supra CLI:

```bash
# подготовить Move-фреймворки Supra (скачиваются в ~/.move)
bash supra/scripts/bootstrap_move_deps.sh

# запустить тесты пакета lottery_core через Supra CLI внутри контейнера
docker compose run --rm --entrypoint bash supra_cli \
  -lc 'cd /supra/SupraLottery && \
       PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.cli move-test \
         --workspace SupraLottery/supra/move_workspace \
         --package lottery_core \
         --cli /supra/supra \
         --report-json tmp/move-test-report.json \
         --report-junit tmp/move-test-report.xml \
         --report-log tmp/move-test-report.log'
```

Команду запускайте из корня репозитория. Python-обёртка принимает любой путь до бинаря Supra CLI (например, локально установленный `supra`), поэтому при необходимости можно заменить `/supra/supra` на абсолютный путь в вашей среде. Артефакты `tmp/move-test-report.{json,xml,log}` фиксируют статус последнего прогона; сейчас сохранён dry-run со статусом `skipped`, а после получения Supra CLI повторите команду без `--dry-run` для реального тестового отчёта.

Если Supra CLI временно недоступен, выполните «сухой» прогон с `--dry-run`, чтобы сохранить конфигурацию named addresses и проверить параметры запуска, а затем повторите команду с реальным CLI перед релизом.

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

## dVRF 3.0 migration
- Документ `docs/dvrf_v3_migration_plan.md` фиксирует прогресс (обновление модулей, тестирование, блокеры).
- Раздел 7 runbook (`docs/testnet_runbook.md`) содержит пошаговый self-service для `migrateClient`, `clientSettingMinimumBalance`, `depositFundClient`, `addContractToWhitelist` и проверок снапшотов whitelisting.
- События `SubscriptionConfiguredEvent` и `GasConfigUpdatedEvent` позволяют сверять конфигурацию газа с настройками Supra.

## Rollback
- Branch `backup/lottery_monolith` keeps the monolithic contract.
- Directory `SupraLottery/supra/move_workspace/lottery_backup` contains sources and tests for the legacy package.

## License
Files are provided as-is. Refer to project maintainers for licensing details.
