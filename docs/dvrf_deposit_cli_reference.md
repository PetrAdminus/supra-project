# Supra dVRF 3.0 — CLI справочник по модулю `deposit`

Документ дополняет [testnet_runbook](./testnet_runbook.md) и собирает все
актуальные команды Supra CLI для взаимодействия с модулем
`0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit`.
Все примеры запускаются через Docker и предполагают, что вы уже создали
профиль (`supra profile new …`) и, при необходимости, экспортировали
`SUPRA_CONFIG=/supra/configs/testnet.yaml`.

> Для быстрой проверки статуса подписки можно воспользоваться скриптом
> [`supra/scripts/testnet_status_report.sh`](../supra/scripts/testnet_status_report.sh):
> он вызывает ключевые view-функции депозита и контракта и выводит их
> в одном отчёте. Для автоматизированного контроля минимального баланса
> используйте [`supra/scripts/testnet_monitor_check.sh`](../supra/scripts/testnet_monitor_check.sh) —
> скрипт рассчитывает `min_balance` по текущим лимитам газа,
> сравнивает с результатом `checkClientFund` и завершает работу с ошибкой,
> если депозит опустился до порогового значения. Рекомендации по запуску по расписанию, через CI и Supra AutoFi смотрите в [отдельном руководстве](./dvrf_monitoring_automation.md).
> Для машиночитаемого вывода и интеграции с AutoFi/CI используйте `python supra/scripts/testnet_monitor_json.py --pretty --fail-on-low` — скрипт повторно использует формулы `calc_min_balance.py`, вызывает `view`-функции `deposit` и возвращает `exit=1`, если баланс ниже расчётного `min_balance`.

> Начиная с Supra CLI 2025.05 утилита ищет активный профиль в
> `/supra/.aptos/config.yaml`. Перед запуском команд скопируйте YAML
> (например, `supra/configs/testnet.yaml`) в контейнер: `docker compose run
> --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp
> /supra/configs/testnet.yaml /supra/.aptos/config.yaml"`.

## Базовые переменные окружения

```bash
export PROFILE=my_new_profile
export SUPRA_CONFIG=/supra/configs/testnet.yaml
export DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e
export LOTTERY_ADDR=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0
export MAX_GAS_PRICE=1000
export MAX_GAS_LIMIT=500000
export CALLBACK_GAS_PRICE=100
export CALLBACK_GAS_LIMIT=150000
export MIN_BALANCE_LIMIT=15375000000   # пример из runbook
```

> Вместо ручного экспорта можно скопировать `supra/scripts/testnet_env.example`,
> отредактировать значения и выполнить `set -a; source supra/scripts/testnet_env.local; set +a`.
> Для расчёта `MIN_BALANCE_LIMIT` используйте `python supra/scripts/calc_min_balance.py --max-gas-price $MAX_GAS_PRICE --max-gas-limit $MAX_GAS_LIMIT --verification-gas $VERIFICATION_GAS_VALUE --margin 0.15` — скрипт покажет `per_request_fee`, `min_balance` и рекомендуемый депозит.

> Supra CLI ищет `config.yaml` в каталоге `/supra/.aptos`. При работе
> в контейнере выполните один раз: `docker compose run --rm --entrypoint
> bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml
> /supra/.aptos/config.yaml"`.

## Онбординг клиента dVRF

| Команда | Назначение | Пример |
| --- | --- | --- |
| `migrateClient(max_gas_price, max_gas_limit)` | Регистрирует клиента в dVRF 3.0, сохраняя лимиты газа. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"` |
| `addClientToWhitelist(max_gas_price, max_gas_limit)` | Активирует клиента на стороне Supra. Возвращает ошибку `ECLIENT_NOT_EXIST`, если `migrateClient` ещё не прошёл. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"` |
| `clientSettingMinimumBalance(min_balance)` | Фиксирует минимальный баланс, который Supra будет контролировать. Контракт вызывает эту функцию внутри `create_subscription`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::clientSettingMinimumBalance --args u128:$MIN_BALANCE_LIMIT --assume-yes"` |
| `depositFundClient(amount)` | Пополняет депозит клиента. При использовании `create_subscription` эта функция вызывается автоматически. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::depositFundClient --args u64:20000000000 --assume-yes"` |
| `addContractToWhitelist(contract_addr, callback_gas_price, callback_gas_limit)` | Привязывает конкретный контракт-потребитель к подписке. `create_subscription` вызывает её для адреса лотереи. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addContractToWhitelist --args address:$LOTTERY_ADDR u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT --assume-yes"` |

## Управление лимитами

После онбординга Supra позволяет обновлять лимиты без повторного создания
подписки.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateMaxGasPrice \
  --args u128:1200 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateMaxGasLimit \
  --args u128:600000 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateCallbackGasPrice \
  --args address:$LOTTERY_ADDR u128:150 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateCallbackGasLimit \
  --args address:$LOTTERY_ADDR u128:180000 --assume-yes"
```

> При обновлении лимитов не забывайте пересчитать минимальный баланс через
> `lottery::main_v2::calculate_min_balance` и вызвать `set_minimum_balance`,
> если Supra требует синхронизации значения.

## Проверка состояния подписки

| Функция | Что показывает | Пример |
| --- | --- | --- |
| `checkMinBalanceClient(address)` | Текущий минимальный баланс для клиента. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMinBalanceClient --args address:$LOTTERY_ADDR"` |
| `checkMaxGasPriceClient(address)` | Сохранённый `maxGasPrice`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasPriceClient --args address:$LOTTERY_ADDR"` |
| `checkMaxGasLimitClient(address)` | Сохранённый `maxGasLimit`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasLimitClient --args address:$LOTTERY_ADDR"` |
| `getContractDetails(address)` | Пара `(callbackGasPrice, callbackGasLimit)` для whitelisted контракта. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getContractDetails --args address:$LOTTERY_ADDR"` |
| `checkClientFund(address)` | Текущий баланс депозита клиента. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkClientFund --args address:$LOTTERY_ADDR"` |
| `isMinimumBalanceReached(address)` | Показывает, опустился ли депозит до минимального баланса. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::isMinimumBalanceReached --args address:$LOTTERY_ADDR"` |
| `countTotalWhitelistedContractByClient(address)` | Количество whitelisted контрактов для клиента. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::countTotalWhitelistedContractByClient --args address:$LOTTERY_ADDR"` |
| `listAllWhitelistedContractByClient(address)` | Список адресов whitelisted контрактов. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::listAllWhitelistedContractByClient --args address:$LOTTERY_ADDR"` |
| `getSubscriptionInfoByClient(address)` | Метаданные подписки (например, SNAP-программа, таймстемп). | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getSubscriptionInfoByClient --args address:$LOTTERY_ADDR"` |

Для получения истории операций (например, пополнения депозита) используйте
`move tool events list --address $DEPOSIT_ADDR --limit 20`.

## Финансовые операции

```bash
# Дополнительно пополнить депозит
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::depositFundClient \
  --args u64:5000000000 --assume-yes"

# Вывести средства (если нет активных запросов)
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::withdrawFundClient \
  --args u64:1000000000 --assume-yes"
```

> Supra запрещает вывод, если у клиента есть незавершённые запросы VRF.
> Проверяйте `lottery::main_v2::get_lottery_status` и события `DrawHandledEvent`.

## Распространённые ошибки

| Сообщение | Причина | Что делать |
| --- | --- | --- |
| `ECLIENT_ALREADY_EXIST` | Клиент уже зарегистрирован через `migrateClient`. | Продолжайте с `addClientToWhitelist` — повторный вызов `migrateClient` не требуется. |
| `ECLIENT_NOT_EXIST` | Supra ещё не зафиксировала клиента; попытка добавить в whitelist или создать подписку слишком рано. | Повторите `migrateClient`, дождитесь подтверждения и повторите команду через 1–2 минуты. |
| `FUNCTION_RESOLUTION_FAILURE` | Неверное имя функции (snake_case вместо camelCase) или устаревшая версия CLI. | Используйте идентификаторы из официальной документации Supra (`migrateClient`, `addClientToWhitelist`, и т.д.) и вызывайте их через `move tool run --profile … --function-id deposit::functionName`. |
| `E_CALLBACK_LIMIT_INVALID` | Значения `callbackGasPrice`/`callbackGasLimit` ниже минимально допустимых. | Увеличьте лимиты (см. официальную таблицу минимальных значений в документации Supra). |

## Связанные материалы

- [Testnet runbook](./testnet_runbook.md)
- [Walkthrough для профиля `my_new_profile`](./dvrf_testnet_my_new_profile_walkthrough.md)
- [Справочник ошибок dVRF](./dvrf_error_reference.md)
- [Мониторинг событий dVRF](./dvrf_event_monitoring.md)
- [Автоматизация мониторинга (cron/AutoFi, Slack webhook)](./dvrf_monitoring_automation.md)
