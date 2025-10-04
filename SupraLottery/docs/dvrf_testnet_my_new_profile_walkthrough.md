# Настройка Supra dVRF для профиля `my_new_profile`

Этот сценарий повторяет команды, которые мы отладили в testnet для аккаунта администратора `my_new_profile` (адрес `0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0`).
Все команды выполняются из корня репозитория `SupraLottery`.

> **Важно:** Профиль `my_new_profile` должен уже существовать в Supra CLI и быть активированным (`supra profile list` показывает `(*) my_new_profile`).
> Если вы используете общий YAML (`supra/configs/testnet.yaml`), установите переменную `SUPRA_CONFIG=/supra/configs/testnet.yaml` перед запуском команд.
> Python-утилиты из папки `supra/scripts` удобно вызывать через общий интерфейс: `python -m supra.scripts --list` покажет все подкоманды, а `python -m supra.scripts manual-draw --profile ...`/`python -m supra.scripts monitor-json --profile ...` избавят от необходимости указывать путь к файлам.

## 1. Подготовка CLI внутри контейнера
Скопируйте YAML-профиль в каталог, который ожидает Supra CLI:
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml /supra/.aptos/config.yaml"
```

## 2. Базовые параметры и переменные окружения
Экспортируйте параметры газа, депозита и адресов, чтобы команды были компактнее (можно переиспользовать шаблон [`supra/scripts/testnet_env.example`](../supra/scripts/testnet_env.example) и выполнить `set -a; source ...; set +a`). При необходимости рассчитайте минимальный депозит через `python supra/scripts/calc_min_balance.py --max-gas-price $MAX_GAS_PRICE --max-gas-limit $MAX_GAS_LIMIT --verification-gas $VERIFICATION_GAS_VALUE --margin 0.2` — скрипт покажет значения `per_request_fee`, `min_balance` и рекомендуемый депозит с запасом.
```bash
export SUPRA_CONFIG=/supra/configs/testnet.yaml
export PROFILE=my_new_profile
export LOTTERY_ADDR=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0
export DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e
export MAX_GAS_PRICE=1000
export MAX_GAS_LIMIT=500000
export CALLBACK_GAS_PRICE=100
export CALLBACK_GAS_LIMIT=150000
export VERIFICATION_GAS_VALUE=25000
export INITIAL_DEPOSIT=20000000000
export RNG_COUNT=1
export CLIENT_SEED=1234567890
```

Минимальный баланс для таких параметров: `30 * MAX_GAS_PRICE * (MAX_GAS_LIMIT + VERIFICATION_GAS_VALUE) = 15 375 000 000`. Значение `INITIAL_DEPOSIT` (20 000 000 000) перекрывает минимум с запасом.

## 3. Настройка газа и подписки dVRF
1. Настройте лимиты газа внутри контракта:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::configure_vrf_gas --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT u128:$VERIFICATION_GAS_VALUE --assume-yes"
   ```
2. Зарегистрируйте клиента в модуле депозита Supra и добавьте его в whitelist:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"
   ```
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"
   ```
3. Создайте подписку непосредственно из контракта (депозит ≥ минимального баланса):
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::create_subscription --args u64:$INITIAL_DEPOSIT --assume-yes"
   ```
4. Зафиксируйте снапшоты whitelisting и минимального баланса для аудита:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::record_client_whitelist_snapshot --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:15375000000"
   ```
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::record_consumer_whitelist_snapshot --args u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT"
   ```
5. (Опционально) разрешите агрегатора Supra и дополнительные потребители:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::whitelist_callback_sender --args address:<АДРЕС_АГРЕГАТОРА>"
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::whitelist_consumer --args address:$LOTTERY_ADDR"
   ```

## 4. Продажа билетов и запрос VRF
1. Зарегистрируйте store и заминтите токены игрокам (пример для одного аккаунта):
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::treasury_v1::register_store_for --args address:0xPLAYER"
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::treasury_v1::mint_to --args address:0xPLAYER u64:100000000"
   ```
2. От имени игроков (их профили) купите минимум 5 билетов. Пример для `player1_profile`:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool run --profile player1_profile --function-id $LOTTERY_ADDR::main_v2::buy_ticket"
   ```
3. После пятого билета проверьте статус лотереи:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::get_lottery_status"
   ```
   Поле `draw_scheduled` должно быть `true`, а `pending_request` — `false`.
4. Настройте параметры VRF-запроса и инициируйте розыгрыш:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::configure_vrf_request --args u8:$RNG_COUNT u64:$CLIENT_SEED"
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $LOTTERY_ADDR::main_v2::manual_draw"
   ```
   > Чтобы объединить проверку готовности и сам вызов, используйте [`supra/scripts/testnet_manual_draw.py`](../supra/scripts/testnet_manual_draw.py). Скрипт повторно запустит `testnet_monitor_json.py`, выведет итоговую команду Supra CLI и выполнит `manual_draw` (или завершится с кодом 1, если контракт не готов).
5. Отслеживайте событие обработки случайности:
   ```powershell
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events tail --profile $PROFILE --address $LOTTERY_ADDR --event-type $LOTTERY_ADDR::main_v2::DrawHandledEvent"
   ```

## 5. Проверка настроек депозита после онбординга
Сравните сохранённые значения с лимитами газа:
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMinBalanceClient --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasPriceClient --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasLimitClient --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getContractDetails --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkClientFund --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::isMinimumBalanceReached --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::countTotalWhitelistedContractByClient --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::listAllWhitelistedContractByClient --args address:$LOTTERY_ADDR"
```
```powershell
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getSubscriptionInfoByClient --args address:$LOTTERY_ADDR"
```

Полученные значения должны совпадать с параметрами из шага 2. Если Supra CLI возвращает `FUNCTION_RESOLUTION_FAILURE`, проверьте версию CLI и что функции вызываются в camelCase (`migrateClient`, `addClientToWhitelist`, и т.д.).

> Быстрый способ вывести эти данные — скрипт [`supra/scripts/testnet_status_report.sh`](../supra/scripts/testnet_status_report.sh). Задайте `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR` (при необходимости `CLIENT_ADDR`) и получите агрегированный отчёт о контракте и депозите Supra dVRF. Для автоматизации мониторинга по расписанию или через Supra AutoFi воспользуйтесь рекомендациями из [отдельного руководства](./dvrf_monitoring_automation.md).
> Для автоматической проверки минимума депозита и выдачи кода возврата используйте [`supra/scripts/testnet_monitor_check.sh`](../supra/scripts/testnet_monitor_check.sh) — он рассчитывает `min_balance`, сравнивает его с `checkClientFund` и сигнализирует об отклонении.
> Чтобы получить машиночитаемый JSON-отчёт для CI/AutoFi, вызовите [`python supra/scripts/testnet_monitor_json.py --pretty`](../supra/scripts/testnet_monitor_json.py). Скрипт собирает `get_lottery_status`, `get_vrf_request_config`, данные whitelisting и функции модуля `deposit`, при флаге `--fail-on-low` возвращает `exit=1`, если баланс ниже расчётного `min_balance`.
> Для отправки уведомлений в Slack/Teams воспользуйтесь [`supra/scripts/testnet_monitor_slack.py`](../supra/scripts/testnet_monitor_slack.py) — скрипт переиспользует JSON-отчёт, формирует текстовое сообщение и возвращает тот же код возврата (можно включить `--fail-on-low`).
> Для экспорта метрик в Prometheus или Pushgateway запустите [`python supra/scripts/testnet_monitor_prometheus.py --metric-prefix supra_dvrf`](../supra/scripts/testnet_monitor_prometheus.py); при необходимости добавьте `--label env=test` и `--push-url https://pushgateway.example/metrics/job/supra`.

## 6. Смоук-тест и логирование
- Зафиксируйте tx hash команд `create_subscription`, `manual_draw` и `DrawHandledEvent` в журнале QA.
- При повторном деплое обновляйте `INITIAL_DEPOSIT` и `CLIENT_SEED`, чтобы исключить конфликт nonce.
- Для регрессионного тестирования периодически запускайте `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"`.

Этот документ дополняет основной [testnet_runbook](./testnet_runbook.md) и служит эталонным примером для профиля `my_new_profile`.

> Быструю проверку розыгрыша можно выполнить через скрипт [`supra/scripts/testnet_smoke_test.sh`](../supra/scripts/testnet_smoke_test.sh),
> передав `PROFILE`, `LOTTERY_ADDR` и `ADMIN_ADDR`. Он повторяет шаги покупки билетов, конфигурации VRF и вызывает `manual_draw`.
