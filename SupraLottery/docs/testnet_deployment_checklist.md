# Чек-лист деплоя SupraLottery на тестнете Supra

> Документ покрывает требование этапа F3 плана выравнивания: единая памятка со всеми
> адресами, командами и контрольными точками для выпуска новой версии SupraLottery.
> Подробные инструкции и сценарии остаются в [testnet_runbook.md](./testnet_runbook.md),
> чек-лист служит быстрым контрольным списком перед запуском.

## 1. Предварительные условия
- ✅ Supra CLI версии `2025.05` или новее доступна локально либо в Docker (`docker compose run supra_cli`).
- ✅ Файл конфигурации сети (`SUPRA_CONFIG=/supra/configs/testnet.yaml` либо локальный путь) присутствует.
- ✅ Настроен профиль администратора лотереи (пример: `PROFILE=lottery_admin`).
- ✅ Приватные ключи операторов и игроков добавлены в Supra CLI (см. [walkthrough](./dvrf_testnet_my_new_profile_walkthrough.md)).
- ✅ Репозиторий обновлён и зависимости Move подтянуты (`PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --dry-run --cli-flavour supra`).

## 2. Базовые адреса и параметры
| Переменная | Значение по умолчанию | Описание |
| --- | --- | --- |
| `LOTTERY_ADDR` | `0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0` | Текущий адрес основного пакета SupraLottery на тестнете. |
| `DEPOSIT_ADDR` | `0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e` | Модуль Supra dVRF `deposit`. |
| `CLIENT_ADDR` | `0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0` | Адрес клиента dVRF (совпадает с адресом лотереи). |
| `HUB_ADDR` | `0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0` | Контракт VRF hub. |
| `FACTORY_ADDR` | `0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0` | Контракт фабрики лотерей. |
| `MAX_GAS_PRICE` | `1000` | Максимальная цена газа в gwei для клиента dVRF. |
| `MAX_GAS_LIMIT` | `500000` | Максимальный лимит газа для клиента dVRF. |
| `CALLBACK_GAS_PRICE` | `100` | Цена газа для callback Supra VRF. |
| `CALLBACK_GAS_LIMIT` | `150000` | Лимит газа для callback Supra VRF. |
| `VERIFICATION_GAS_VALUE` | `25000` | Значение газа для верификации (используется в `calc_min_balance`). |
| `MIN_BALANCE_LIMIT` | `15375000000` | Минимальный баланс депозита в субрах при указанных лимитах газа. |

> При изменении адресов/лимитов обязательно обновите `.env`, конфиги мониторинга и входные параметры скриптов из `supra/scripts`.

## 3. Проверка кода перед деплоем
> Детальные инструкции по запуску Supra CLI, сбору отчётов и фиксации артефактов см. в [сценарии динамического аудита](./audit/internal_audit_dynamic_runbook.md).
1. `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages --keep-going --report-json ci/move-test-report.json --report-junit ci/move-test-report.xml -- --skip-fetch-latest-git-deps`
2. Зафиксируйте JSON и JUnit отчёты в артефакты релиза.
3. Убедитесь, что `ci/move-test-report.json` содержит `"status": "passed"` для всех пакетов.

## 4. Настройка подписки dVRF
1. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"`
2. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"`
3. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::clientSettingMinimumBalance --args u128:$MIN_BALANCE_LIMIT --assume-yes"`
4. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::depositFundClient --args u64:<DEPOSIT> --assume-yes"`
5. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addContractToWhitelist --args address:$LOTTERY_ADDR u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT --assume-yes"`
6. Проверка: `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMinBalanceClient --args address:$LOTTERY_ADDR"`

## 5. Конфигурация лотереи
1. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::configure_vrf_gas --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT u128:$VERIFICATION_GAS_VALUE --assume-yes"`
2. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::configure_vrf_request --args u8:<RNG_COUNT> u64:<NUM_CONFIRMATIONS> u64:<CLIENT_SEED> --assume-yes"`
3. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::whitelist_callback_sender --args address:<AGGREGATOR_ADDR> --assume-yes"`
4. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::whitelist_consumer --args address:$LOTTERY_ADDR --assume-yes"`
5. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::treasury_v1::set_config --args address:<JACKPOT_ADDR> address:<OPERATIONS_ADDR> u16:<JACKPOT_SHARE_BPS> --assume-yes"`
6. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::operators::grant_operator --args address:<OPERATOR_ADDR> --assume-yes"`
7. Проверка: `python -m supra.scripts testnet-status-report --profile $PROFILE --lottery-addr $LOTTERY_ADDR --deposit-addr $DEPOSIT_ADDR --supra-config $SUPRA_CONFIG`

## 6. Смоук-тест перед релизом
1. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::treasury_v1::mint_to --args address:<PLAYER_ADDR> u64:<AMOUNT> --assume-yes"`
2. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile player1_profile --function-id $LOTTERY_ADDR::main_v2::buy_ticket --args u64:<LOTTERY_ID> --assume-yes"`
3. `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::manual_draw --assume-yes"`
4. Проверка событий: `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events tail --profile $PROFILE --address $LOTTERY_ADDR --event-type $LOTTERY_ADDR::main_v2::DrawHandledEvent"`
5. Подсумок: `python -m supra.scripts testnet-monitor-json --profile $PROFILE --lottery-addr $LOTTERY_ADDR --deposit-addr $DEPOSIT_ADDR --max-gas-price $MAX_GAS_PRICE --max-gas-limit $MAX_GAS_LIMIT --verification-gas-value $VERIFICATION_GAS_VALUE`

## 7. Пост-деплой контроль
- Сохраните отчёт `testnet-monitor-json` и скриншоты событий `DrawHandledEvent` и `WhitelistSnapshotUpdatedEvent`.
- Проверьте, что `isMinimumBalanceReached` возвращает `false` и баланс депозита выше `MIN_BALANCE_LIMIT`.
- Убедитесь, что `LotteryRegistrySnapshotUpdatedEvent` содержит актуальные экземпляры и `operators::OperatorSnapshotUpdatedEvent` отражает делегатов.
- Запланируйте мониторинг через `testnet_monitor_check.sh` (cron/CI) с переменными `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR`, `MAX_GAS_PRICE`, `MAX_GAS_LIMIT`, `VERIFICATION_GAS_VALUE`.

> После прохождения всех пунктов чек-листа обновите релизные заметки и приложите JSON/JUnit отчёты, чтобы Supra могла воспроизвести прогон.
