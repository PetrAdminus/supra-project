# Supra Lottery — Testnet Runbook

## 1. Предварительные требования
- Рабочая ветка `Test`: все изменения вносятся только сюда, новые ветки не создаём; релизные слияния выполняются в `master` после завершения ключевых этапов.
- Аккаунт Supra с доступом к testnet и приватным ключом StarKey.
- Ознакомьтесь с официальными гайдами Supra: [token-standards](https://docs.supra.com/network/move/token-standards), [fungible_asset module](https://docs.supra.com/network/move/supra-fungible-asset-fa-module), [Supra CLI с Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
- RPC endpoint Supra testnet: `https://rpc-testnet.supra.com` (chain id 6).
- Mainnet (для справки): `https://rpc-mainnet.supra.com` (chain id 8).
- Адреса контрактов: депозит dVRF v3 и `lottery` (см. официальную документацию).
- Значения газа: `maxGasPrice`, `maxGasLimit`, `callbackGasPrice`, `callbackGasLimit`, коэффициент безопасности для депозита.
- Установленный Docker и подготовленный `supra_cli` (см. `docker-compose.yml`).

> Быстрый контроль перед релизом: воспользуйтесь [чек-листом деплоя](./testnet_deployment_checklist.md), где собраны адреса, значения газа и обязательные команды.
>
> После выполнения всех шагов runbook пройдите [внутренний чек-лист аудита](./audit/internal_audit_checklist.md), чтобы сверить конфигурацию, тесты и документацию перед передачей статуса Supra.
> Для динамических проверок (Supra CLI, Move-тесты, Python-тесты, смоук-прогон) используйте [сценарий G1](./audit/internal_audit_dynamic_runbook.md).

## 2. Настройка Supra CLI профиля
Supra CLI начиная с релиза 2025.05 хранит ключи и параметры сети в профилях. Перед запуском остальных команд создайте и активируйте профиль администратора (в примерах используется имя `lottery_admin`). Приватный ключ передаётся **без префикса `0x`**.

1. Создайте профиль testnet:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile new lottery_admin <PRIVATE_KEY_HEX> --network testnet"
   ```
2. При необходимости активируйте его (если несколько профилей):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile activate lottery_admin"
   ```
3. Проверьте список профилей и убедитесь, что `lottery_admin` помечен `*`:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile -l"
   ```

> Если вы продолжаете вести общие параметры (RPC, лимиты газа) в YAML, задайте `SUPRA_CONFIG=/supra/configs/testnet.yaml` перед командами. Этот файл может быть создан из шаблона `profile_template.yaml`, но команды ниже всегда используют `--profile`, чтобы соответствовать новой CLI.

## 3. Миграция на dVRF v3
> Все команды ниже запускаются одной строкой через Docker. Подставляйте своё имя профиля (например, `lottery_admin`) и при необх
одимости экспортируйте `SUPRA_CONFIG=/supra/configs/testnet.yaml`, чтобы CLI подхватил общий YAML.
> Примеры используют алиас `lottery::` из `Move.toml`; при запуске вне репозитория указывайте полный адрес, например `0xbc95…::main_v2::configure_vrf_gas`.

### 3.1 Инициализация Fungible Asset для казначейства
> Ориентируемся на официальные стандарты Supra: [token-standards](https://docs.supra.com/network/move/token-standards) и [описание `fungible_asset`](https://docs.supra.com/network/move/supra-fungible-asset-fa-module).

1. Проверяем, развёрнут ли токен казначейства:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::is_initialized"
   ```
2. Если ответ `false`, инициализируем Metadata (значения hex соответствуют ASCII-строкам `Lottery Ticket`, `LOT` и сид `lottery_fa_seed`):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::init_token --args hex:0x6c6f74746572795f66615f73656564 hex:0x4c6f7474657279205469636b6574 hex:0x4c4f54 u8:9 hex:0x hex:0x"
   ```
3. Зарегистрируйте primary store для всех аккаунтов, которые будут получать токены:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::register_store_for --args address:<ACCOUNT>"
   ```
   Пользователи также могут вызвать `lottery::treasury_v1::register_store` самостоятельно через свой кошелёк.
   Для массовой подготовки можно использовать батч-функцию администратора:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::register_stores_for --args address_vector:<ADDR1,ADDR2,...>"
   ```
   > Подробнее об аргументе `address_vector` см. раздел "Vector arguments" в [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
   > ⚠️ Перед запуском `lottery::treasury_multi::init` убедитесь, что адреса джекпота и операционного пула уже зарегистрированы как primary store; контракт валидирует условие и при нарушении вернёт коды `E_TREASURY_NOT_READY`, `E_JACKPOT_RECIPIENT_UNREGISTERED` или `E_OPERATIONS_RECIPIENT_UNREGISTERED`.
4. Для тестовых аккаунтов можно заранее минтить баланс, чтобы они смогли купить билеты (после регистрации store):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::mint_to --args address:<PLAYER_ADDR> u64:<AMOUNT>"
   ```
5. Проверяем метаданные и адреса store через view-функции (каждая команда — отдельный запуск):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::metadata_summary"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::primary_store_address --args address:<ACCOUNT>"

    Функция возвращает детерминированный адрес объекта primary store из `supra_framework::primary_fungible_store`. Значение можно
    сравнить с `object::create_user_derived_object_address` на бэкенде и использовать в мониторинге для сверки freeze-статуса и
    баланса.
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::get_config"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::account_status --args address:<ACCOUNT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::account_extended_status --args address:<ACCOUNT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_v1::store_frozen --args address:<ACCOUNT>"
   ```

   С миграцией на Move 1 все события казначейства создаются через `supra_framework::account::new_event_handle`, поэтому GUID определяется адресом лотереи и `creation_num`. Сверить значения можно командой:

   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool resource --profile <PROFILE> --account <LOTTERY_ADDR> --resource-id lottery::treasury_v1::TreasuryState"
   ```

   Поля `*_events.guid.id.creation_num` в выводе подскажут, какие GUID передавать в `supra move tool event --start <seq>` при выгрузке логов. Адрес лотереи возьмите из `.move/config` или чек-листа деплоя. Благодаря начальному `event::emit_event` сразу после `move_to` (см. модули `LotteryRounds`, `TreasuryMulti`, `Autopurchase`) счётчик начинается с `0`, так что мониторинг не пропускает первые события.
6. При необходимости можно временно заморозить primary store (например, на время расследования инцидента) и затем снять блокировку:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::set_store_frozen --args address:<ACCOUNT> bool:true"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::set_store_frozen --args address:<ACCOUNT> bool:false"
   ```

7. Перед назначением получателей распределения убедитесь, что на каждом адресе создан primary store через `register_store_for` или `register_stores_for` и store не заморожен (проверьте `treasury_v1::account_extended_status`/`store_frozen`); затем выполните:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::set_recipients --args address:<TREASURY_ADDR> address:<MARKETING_ADDR> address:<COMMUNITY_ADDR> address:<TEAM_ADDR> address:<PARTNERS_ADDR>"
   ```
   Если какой-то адрес не имеет зарегистрированного store, команда завершится ошибкой `E_RECIPIENT_STORE_NOT_REGISTERED`; при замороженном store вернётся стандартный `E_STORE_FROZEN` — оба требования соответствуют правилам Supra FA о переводах только между готовыми хранилищами.

8. Обновить доли распределения (сумма basis points должна равняться 10 000):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::treasury_v1::set_config --args u64:<BP_JACKPOT> u64:<BP_PRIZE> u64:<BP_TREASURY> u64:<BP_MARKETING> u64:<BP_COMMUNITY> u64:<BP_TEAM> u64:<BP_PARTNERS>"
   ```

### 3.2 Настройка подписки Supra dVRF 3.0
> Модуль депозита Supra dVRF 3.0 размещён по адресу `0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit` и использует camelCase из официальной документации Supra (`migrateClient`, `addClientToWhitelist`, `clientSettingMinimumBalance`, `depositFundClient`, ...). Ошибка `FUNCTION_RESOLUTION_FAILURE` означает, что указан неверный идентификатор функции или адрес модуля. Если Supra CLI продолжает искать `~/.aptos/config.yaml`, скопируйте используемый YAML-профиль (например, `/supra/configs/testnet.yaml`) в контейнер: `docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml /supra/.aptos/config.yaml"`.
>
> Полный справочник команд модуля `deposit` приведён в отдельном документе [dvrf_deposit_cli_reference.md](./dvrf_deposit_cli_reference.md) — используйте его, если требуется настроить лимиты вручную или проверить сохранённые значения на стороне Supra.
>
> Все Python-утилиты проекта можно запускать через единый CLI: `python -m supra.scripts --list` покажет доступные подкоманды, а `python -m supra.scripts calc-min-balance ...`/`python -m supra.scripts manual-draw ...` упростят вызов расчётов и автоматизации без прямого обращения к файлам.

1. **Сконфигурируйте лимиты газа для VRF.** Параметры участвуют в расчёте депозита и проверках whitelisting.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::configure_vrf_gas --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT> u128:<VERIFICATION_GAS_VALUE> --assume-yes"

   > Ограничения Supra VRF subscription: `callback_gas_price` и `callback_gas_limit` контракта должны быть ≤ `max_gas_price`/`max_gas_limit` подписки. Контракт и CLI проверяют эти неравенства перед выполнением команды.【F:SupraLottery/supra/move_workspace/lottery/sources/Lottery.move†L700-L711】【F:SupraLottery/supra/scripts/configure_vrf_gas.py†L52-L65】【F:SupraLottery/docs/dvrf_reference_snapshot.md†L53-L60】
   ```
   Дождитесь события `GasConfigUpdatedEvent`.

2. **Рассчитайте минимальный депозит.** Формула из `lottery::main_v2::calculate_min_balance`:
   ```bash
   python - <<'PY'
   max_gas_price = <MAX_GAS_PRICE>
   max_gas_limit = <MAX_GAS_LIMIT>
   verification_gas = <VERIFICATION_GAS_VALUE>
   print(30 * max_gas_price * (max_gas_limit + verification_gas))
   PY
   ```
   или воспользуйтесь скриптом `supra/scripts/calc_min_balance.py`, который дополнительно показывает рекомендованный депозит с учётом запаса:
   ```bash
   python supra/scripts/calc_min_balance.py \
     --max-gas-price <MAX_GAS_PRICE> \
     --max-gas-limit <MAX_GAS_LIMIT> \
     --verification-gas <VERIFICATION_GAS_VALUE> \
     --margin 0.2
   ```
   Рекомендуется добавить 10–20 % запаса, чтобы исключить `E_INITIAL_DEPOSIT_TOO_LOW` при росте комиссий. Создавая подписку, проверяйте, что передаваемый депозит не меньше расчётного значения — скрипт `testnet_migration.sh` прерывает выполнение, если `INITIAL_DEPOSIT < MIN_BALANCE_LIMIT`.

3. **Скопируйте CLI-конфиг внутрь контейнера (однократно за сессию).** Supra CLI ищет `config.yaml` в `/supra/.aptos`. Скопируйте используемый YAML-профиль (например, `supra/configs/testnet.yaml`) в нужное место:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml /supra/.aptos/config.yaml"
   ```
   После копирования можно запускать остальные команды без повторного шага (до перезапуска контейнера).

4. **Выполните регистрацию клиента (`migrateClient`).** Supra требует, чтобы каждый клиент прошёл онбординг до whitelisting — функция сохраняет лимиты газа и возвращает ошибку `ECLIENT_ALREADY_EXIST`, если профиль уже мигрирован.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::migrateClient --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> --assume-yes"
   ```
   Убедитесь, что в выводе присутствует `"status": "Success"`; при `FUNCTION_RESOLUTION_FAILURE` проверьте адрес модуля и camelCase-имя функции.

5. **Добавьте клиента в whitelist депозита.** Этот шаг активирует подписку на стороне Supra и позволяет связывать контракты.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::addClientToWhitelist --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> --assume-yes"
   ```
   Если команда возвращает `ECLIENT_NOT_EXIST`, повторите `migrateClient` и сверьте лимиты газа; иногда Supra активирует адрес с задержкой — в таком случае дождитесь подтверждения от поддержки.

6. **Создайте подписку и пополните депозит.** Значение `<INITIAL_DEPOSIT>` должно быть ≥ рассчитанного минимума.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::create_subscription --args u64:<INITIAL_DEPOSIT> --assume-yes"
   ```
   Функция вызывает `deposit::clientSettingMinimumBalance`, `deposit::depositFundClient` и `deposit::addContractToWhitelist`, а событие `SubscriptionConfiguredEvent` фиксирует параметры.

   > Если `create_subscription` завершилась ошибкой `ECLIENT_NOT_EXIST`, значит Supra ещё не зафиксировала ваш клиент. Повторите шаги 4–5 позднее; между онбордингом и whitelisting может потребоваться до нескольких минут.

7. **(Опционально) синхронизируйте минимальный баланс вручную.** Используйте при изменении лимитов газа на стороне Supra.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::set_minimum_balance --assume-yes"
   ```

8. **Зафиксируйте снапшоты whitelisting для аудита.**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::record_client_whitelist_snapshot --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> u128:<MIN_BALANCE_LIMIT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::record_consumer_whitelist_snapshot --args u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT>"
   ```

9. **Управление депозитом напрямую (при необходимости).** Все функции принимают camelCase-имена при вызове через Supra CLI.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::clientSettingMinimumBalance --args u128:<MIN_BALANCE> --assume-yes"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::depositFundClient --args u64:<DEPOSIT> --assume-yes"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::addContractToWhitelist --args address:<LOTTERY_ADDR> u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT> --assume-yes"
   ```
   Эти команды пригодятся при корректировке параметров напрямую в модуле депозита.

10. **Проверьте настройки депозита после онбординга.** Модуль `deposit` предоставляет view-функции для аудита лимитов газа и минимального баланса. Команды возвращают JSON-структуру; при ошибке `FUNCTION_RESOLUTION_FAILURE` убедитесь, что используете camelCase и актуальный адрес модуля.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMinBalanceClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMaxGasPriceClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMaxGasLimitClient --args address:<CLIENT_ADDR>"
   ```
   Для проверки конкретного контракта используйте `deposit::getContractDetails`:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::getContractDetails --args address:<LOTTERY_ADDR>"
   ```
   Чтобы оценить текущий баланс депозита и whitelisting, выполните дополнительные view-команды:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkClientFund --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::isMinimumBalanceReached --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::countTotalWhitelistedContractByClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::listAllWhitelistedContractByClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::getSubscriptionInfoByClient --args address:<CLIENT_ADDR>"
   ```
   Ответы покажут текущий баланс, достижение минимального лимита и список whitelisted контрактов Supra.

   После назначения агрегатора Supra проверьте, что VRF-хаб зафиксировал событие и view:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @vrf_hub --event-type @vrf_hub::hub::CallbackSenderUpdatedEvent --limit 5"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id @vrf_hub::hub::get_callback_sender_status"
   ```
   JSON-ответ должен содержать `"current": "Some(<AGGREGATOR_ADDR>)"`; если приходит `None`, повторно вызовите `hub::set_callback_sender` и убедитесь, что транзакция прошла без ошибок.

11. **Удаление контракта из подписки.** Перед удалением убедитесь, что в лотерее нет активного `pending_request` (скрипт проверит это автоматически). Быстрый путь — использовать унифицированный CLI:
    ```bash
    python -m supra.scripts remove-subscription \
      --profile $PROFILE \
      --lottery-addr $LOTTERY_ADDR \
      --deposit-addr $DEPOSIT_ADDR \
      --supra-cli-bin /supra/supra \
      --supra-config $SUPRA_CONFIG
    ```
    Скрипт вызывает `lottery::main_v2::remove_subscription`, публикует событие `SubscriptionContractRemovedEvent` и проксирует `deposit::remove_contract_from_whitelist`. При необходимости можно выполнить команду напрямую через Supra CLI:
    ```bash
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::remove_subscription --assume-yes"
    ```
    Используйте опцию `--allow-pending-request`, только если осознанно завершаете контракт с активными запросами (по умолчанию операция блокируется).
12. **Проверка адресов и статуса пулов `treasury_multi`.** После инициализации казначейства выполните view-команды, чтобы убедиться, что используются ожидаемые адреса джекпота/операционного пула и что для них зарегистрированы primary store без freeze:
    ```bash
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_multi::get_recipients"
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_multi::get_recipient_statuses"
    ```
    Поле `recipient` должно совпадать с ожидаемыми адресами, а флаги `registered=true` и `frozen=false` подтверждают готовность primary store. Значение `balance` отражает актуальные выплаты Supra FA для каждого пула. Дополнительно отслеживайте события `lottery::treasury_v1::RecipientsUpdatedEvent` и `lottery::treasury_multi::RecipientsUpdatedEvent` в Supra Explorer или логах CLI — оба события публикуют снапшоты `RecipientStatus` при инициализации и каждой смене получателей, причём `treasury_v1` теперь выводит пары «предыдущее → текущее» состояния направлений, чтобы можно было сравнить старый и новый конфиг по freeze-флагам и балансам.
    Если `withdraw_operations`, `pay_operations_bonus_internal` или `distribute_jackpot` завершаются с кодами `14`, `15`, `16`, `17` или `18`, повторно зарегистрируйте store через `treasury_v1::register_store_for` и снимите freeze (`treasury_v1::set_store_frozen`), затем повторите выплату.

**Снапшот фабрики лотерей.** Для аудита Supra выгрузите текущее состояние фабрики: снапшот `lottery_factory::registry::get_registry_snapshot` возвращает администратора и все зарегистрированные лотереи с ценой билета и долей джекпота, а `list_lottery_ids` показывает только идентификаторы.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_factory::registry::get_registry_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_factory::registry::list_lottery_ids"
```

**Снапшот экземпляров лотерей.** После создания или обновления экземпляров проверьте агрегированное событие и view, чтобы Supra видела актуальные параметры (адреса контрактов, владельцы, цены билетов, доли джекпота, продажи и статус активности):

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::instances::LotteryInstancesSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::instances::get_instances_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::instances::get_instance_snapshot --args u64:<LOTTERY_ID>"
```

Убедитесь, что в событии/JSON указаны `admin` (адрес управляющего @lottery), `hub` (текущий VRF-хаб), а также массив `instances`, где для каждого `lottery_id` отображаются `owner`, адрес контракта `lottery`, `ticket_price`, `jackpot_share_bps`, накопленные `tickets_sold`, `jackpot_accumulated` и флаг `active`. Если данные не обновились, повторите `create_instance`, `sync_blueprint` или синхронизацию статуса (`set_instance_active`), чтобы модуль опубликовал свежий `LotteryInstancesSnapshotUpdatedEvent`.

**Снапшот витринных метаданных.** После загрузки описаний вызовите view `lottery::metadata::get_metadata_snapshot`, чтобы убедиться, что Supra CLI и панели мониторинга увидят актуального администратора и список `MetadataEntry`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::metadata::get_metadata_snapshot"
```

Команда вернёт JSON с полями `admin` и `entries`; каждый элемент `entries[i]` содержит `lottery_id` и все текстовые поля (`title`, `description`, `image_uri`, `website_uri`, `rules_uri`). При необходимости сравните результат с событием `MetadataSnapshotUpdatedEvent`, используя `move tool events list` для адреса лотереи.

**Снапшот истории розыгрышей.** Supra ожидает агрегированный журнал draw, поэтому после fulfill или очистки истории сравните событие и view:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::history::HistorySnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::history::get_history_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::history::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

Убедитесь, что в событии и JSON указаны `admin`, полный список `lottery_ids` и массив `histories`, где каждая запись содержит `lottery_id` и массив `records` с `request_id`, `winner`, `ticket_index`, `prize_amount`, `random_bytes` и `timestamp_seconds`. Если снапшот отсутствует, инициируйте `lottery::rounds::fulfill_draw` или вызовите `history::clear_history`, чтобы модуль опубликовал актуальное состояние.

**Снапшот автопокупки билетов.** Для контроля автоматических планов Supra требует агрегированного события и view:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::autopurchase::AutopurchaseSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::autopurchase::get_autopurchase_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::autopurchase::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

В событии и ответе view проверьте поле `admin`, суммарный `total_balance`, количество игроков и массив `players`: каждый элемент содержит адрес, баланс, `tickets_per_draw` и флаг `active`. Если снапшот отсутствует, выполните `configure_plan`/`deposit` или тестовое `execute`, чтобы модуль опубликовал актуальные данные.

**Снапшот NFT-бейджей.** Supra просила публиковать агрегированное состояние наград, поэтому проверяйте как view, так и поток событий:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_rewards::nft_rewards::get_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_rewards::nft_rewards::get_owner_snapshot --args address:<PLAYER_ADDR>"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery_rewards::nft_rewards::NftRewardsSnapshotUpdatedEvent --limit 5"
```

View `get_snapshot` возвращает администратора, `next_badge_id` и массив владельцев с их `BadgeSnapshot` (лотерея, розыгрыш, URI метаданных, адрес минтера). `get_owner_snapshot` позволяет проверять конкретного игрока, а событие `NftRewardsSnapshotUpdatedEvent` публикуется после `init`, `mint_badge` и `burn_badge`. Если после бёрна владелец по-прежнему числится с бейджами, убедитесь, что транзакция завершилась успешно и повторите команду для очистки состояния.

**Снапшот глобального джекпота.** После выдачи билетов, планирования розыгрыша или выполнения колбэка проверьте, что Supra фиксирует агрегированный снимок и view возвращает те же значения:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::jackpot::JackpotSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::jackpot::get_snapshot"
```

Убедитесь, что в событии и JSON поля `admin` и `lottery_id` совпадают с ожиданиями, `ticket_count` отражает количество выданных билетов, `draw_scheduled` соответствует текущему статусу подготовки, а `pending_request_id` появляется только после `request_randomness` и обнуляется после `fulfill_draw`.

**Снапшот VIP-подписок.** После обновления конфигураций или операций убедитесь, что Supra CLI видит агрегированные данные:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::vip::VipSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::vip::get_vip_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::vip::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

Проверьте, что в событии/вью корректно указаны `admin`, список лотерей (`lotteries`) с полями `config`, `total_members`, `active_members`, `total_revenue` и `bonus_tickets_issued`. При необходимости вызовите `upsert_config`, выполните `subscribe`/`subscribe_for` и совершите покупку билета, чтобы `record_bonus_usage` обновил счётчики и опубликовал свежий `VipSnapshotUpdatedEvent`.

**Снапшот реферальных бонусов.** После настройки конфигураций и тестовых выплат убедитесь, что событие и view публикуют агрегированный снимок:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::referrals::ReferralSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::referrals::get_referral_snapshot"
```

В ответе проверьте поле `admin`, значение `total_registered` и массив `lotteries`: каждый элемент содержит `lottery_id`, доли `referrer/referee_bps`, счётчик `rewarded_purchases` и суммы выплат. Если событие отсутствует, повторно вызовите `set_lottery_config` и выполните тестовую покупку билета, чтобы модуль `lottery::referrals` опубликовал актуальный снимок.

#### Быстрая последовательность (пример)
Ниже приведён пример запуска всех ключевых команд. Сначала заполните значения переменных в первых строках (адреса, лимиты газа, профили), затем выполните блок целиком. Вместо ручного редактирования экспортов можно скопировать файл [`supra/scripts/testnet_env.example`](../supra/scripts/testnet_env.example) в `testnet_env.local`, подставить значения и выполнить `set -a; source supra/scripts/testnet_env.local; set +a`.
Для готового набора команд под профиль `my_new_profile` см. [dVRF walkthrough](./dvrf_testnet_my_new_profile_walkthrough.md).

```bash
export SUPRA_CONFIG=/supra/configs/testnet.yaml
PROFILE=my_new_profile
DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e
LOTTERY_ADDR=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0
export MAX_GAS_PRICE=1000
export MAX_GAS_LIMIT=500000
export CALLBACK_GAS_PRICE=100
export CALLBACK_GAS_LIMIT=150000
export VERIFICATION_GAS_VALUE=25000
export INITIAL_DEPOSIT=20000000000
export RNG_COUNT=1
export NUM_CONFIRMATIONS=1 # допустимый диапазон Supra dVRF: 1..20
export CLIENT_SEED=1234567890
AGGREGATOR_ADDR=""   # заполните фактическим адресом агрегатора Supra testnet
PLAYER_PROFILE=player1
PLAYER_CONFIG=/supra/configs/player1.yaml   # профиль/YAML игрока, повторите для других аккаунтов

docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp $SUPRA_CONFIG /supra/.aptos/config.yaml"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::configure_vrf_gas --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT u128:$VERIFICATION_GAS_VALUE --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"

MIN_BALANCE_LIMIT=$(python - <<'PY'
import os
max_gas_price = int(os.environ["MAX_GAS_PRICE"])
max_gas_limit = int(os.environ["MAX_GAS_LIMIT"])
verification_gas = int(os.environ["VERIFICATION_GAS_VALUE"])
print(30 * max_gas_price * (max_gas_limit + verification_gas))
PY
)
echo "Calculated MIN_BALANCE_LIMIT=$MIN_BALANCE_LIMIT"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::create_subscription --args u64:$INITIAL_DEPOSIT --assume-yes"

if [[ -n "$AGGREGATOR_ADDR" ]]; then
  docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::whitelist_callback_sender --args address:$AGGREGATOR_ADDR --assume-yes"
fi
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::whitelist_consumer --args address:$LOTTERY_ADDR --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::record_client_whitelist_snapshot --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$MIN_BALANCE_LIMIT --assume-yes"
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::record_consumer_whitelist_snapshot --args u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::configure_vrf_request --args u8:$RNG_COUNT u64:$NUM_CONFIRMATIONS u64:$CLIENT_SEED --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$PLAYER_CONFIG /supra/supra move tool run --profile $PLAYER_PROFILE --function-id lottery::main_v2::buy_ticket"
# Повторите команду для остальных игроков, чтобы суммарно продать ≥5 билетов

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool view --profile $PROFILE --function-id lottery::main_v2::get_lottery_status"

PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  python supra/scripts/testnet_draw_readiness.py

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::main_v2::manual_draw --assume-yes"
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool events tail --profile $PROFILE --address $LOTTERY_ADDR --event-type lottery::main_v2::DrawHandledEvent"

# Проверка депозита и минимального баланса (завершится exit=1 при срабатывании порога)
MONITOR_MARGIN=0.2 PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  supra/scripts/testnet_monitor_check.sh

# Машиночитаемый JSON-отчёт (можно сохранять в CI/AutoFi артефакты)
PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  python supra/scripts/testnet_monitor_json.py --pretty

# Отправка уведомления в Slack/Teams (использует те же переменные + MONITOR_WEBHOOK_URL)
PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR MONITOR_WEBHOOK_URL=$MONITOR_WEBHOOK_URL \
  ./supra/scripts/testnet_monitor_slack.py --fail-on-low
```

> Если переменная `AGGREGATOR_ADDR` оставлена пустой (`""`), шаг whitelisting агрегатора будет пропущен — подставьте фактический адрес Supra testnet, чтобы разрешить callback-узел.

После выполнения блоков проверьте события `SubscriptionConfiguredEvent` и убедитесь, что ошибок `ECLIENT_NOT_EXIST` нет.

### 3.3 Whitelisting агрегатора и потребителей
> Основано на [Supra VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md) и рекомендациях Supra о контроле доступа.

1. **Whitelisting агрегатора колбэков** — выполняется только администратором лотереи (`@lottery`) после успешного депозита и настройки газа. Команда запрещена, пока активен незавершённый VRF-запрос (`E_REQUEST_STILL_PENDING`).
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::whitelist_callback_sender --args address:<AGGREGATOR_ADDR>"
   ```
   - Зафиксируйте tx hash и событие `WhitelistSnapshotUpdatedEvent` (последняя запись покажет агрегатора и весь список потребителей). При необходимости сохраняйте также `AggregatorWhitelistedEvent` для истории доступа.
   - При необходимости сменить агрегатор сначала убедитесь, что `pending_request` пуст (проверьте `lottery::main_v2::get_whitelist_status`).
   - Для временного отключения агрегатора используйте `lottery::main_v2::revoke_callback_sender`, но только когда нет активного запроса.

2. **Whitelisting потребителей VRF** — Supra VRF Subscription FAQ требует явно разрешать каждому контракту отправку запросов.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::whitelist_consumer --args address:<CONSUMER_ADDR>"
   ```
   - Повторите для всех вспомогательных контрактов (операторских или будущих интеграций).
   - Проверяйте наличие адреса в списке через `lottery::main_v2::get_whitelist_status` или по событию `WhitelistSnapshotUpdatedEvent`.

3. **Удаление потребителя** при отзыве доступа или компрометации ключа:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::remove_consumer --args address:<CONSUMER_ADDR>"
   ```
   - Команда аварийно завершится `E_CONSUMER_NOT_WHITELISTED`, если адрес отсутствует в whitelist.
   - После ревока проверяйте событие `ConsumerRemovedEvent` и убедитесь, что свежий `WhitelistSnapshotUpdatedEvent` содержит только валидных потребителей.

4. **Контроль whitelisting через события**. Для аудита используйте CLI:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::main_v2::WhitelistSnapshotUpdatedEvent"
   ```
   ```bash
   # При необходимости дополнительно отслеживайте отдельные события grant/revoke
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::main_v2::AggregatorWhitelistedEvent"
   ```
   Сохраняйте timestamp, tx hash и payload событий в runbook журналах.

5. **Снимок делегатов операторов** — после whitelisting/ревокации убедитесь, что список операторов синхронизирован:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view --profile <PROFILE> --function-id $LOTTERY_ADDR::operators::get_operator_snapshot --args u64:<LOTTERY_ID>"
   ```
   - Команда возвращает текущего владельца и массив делегатов; храните JSON-ответ в контрольном отчёте.
   - Для live-мониторинга истории используйте событие `operators::OperatorSnapshotUpdatedEvent`:
     ```bash
     docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address $LOTTERY_ADDR --event-type $LOTTERY_ADDR::operators::OperatorSnapshotUpdatedEvent"
     ```


### 3.4 Миграция legacy-лотерей
> Основано на руководстве Supra *Migration to dVRF 3.0* и требованиях к наблюдаемости при переносе данных.

1. **Подготовка** — убедитесь, что:
   - для нужной лотереи нет активного VRF-запроса (`lottery::main_v2::get_pending_request_view` → `option::none`),
   - конфигурация долей (`prize_bps`, `jackpot_bps`, `operations_bps`) согласована с новым казначейством,
   - `treasury_multi::get_pool(<LOTTERY_ID>)` возвращает `option::none` (лотерея ещё не мигрирована).

2. **Запуск миграции**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::migration::migrate_from_legacy --args u64:<LOTTERY_ID> u64:<PRIZE_BPS> u64:<JACKPOT_BPS> u64:<OPERATIONS_BPS> --assume-yes"
   ```
   - При наличии незавершённого запроса функция завершится `E_PENDING_REQUEST`.
   - Повторный запуск для уже перенесённой лотереи приведёт к `E_ALREADY_MIGRATED`.

3. **Проверка события** — миграция публикует агрегированный снапшот с билетами, `next_ticket_id` и долями распределения:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address $LOTTERY_ADDR --event-type lottery::migration::MigrationSnapshotUpdatedEvent"
   ```
   Сохраните payload события в журнал аудита (включает `ticket_count`, `legacy_next_ticket_id`, `migrated_next_ticket_id`, `jackpot_amount_migrated`, `prize_bps`, `jackpot_bps`, `operations_bps`).

4. **View-функции для отчётов**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::migration::list_migrated_lottery_ids"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::migration::get_migration_snapshot --args u64:<LOTTERY_ID>"
   ```
   Результат `get_migration_snapshot` содержит структуру `MigrationSnapshot`; сохраните JSON для сверки с off-chain отчётами.

5. **Кросс-проверка** — после миграции выполните `treasury_multi::get_pool(<LOTTERY_ID>)` и `lottery::rounds::get_round_snapshot(<LOTTERY_ID>)`, чтобы убедиться, что билеты и джекпот перенесены, `pending_request_id` отсутствует и `draw_scheduled` соответствует ожиданиям. Дополнительно просмотрите события `RoundSnapshotUpdatedEvent` (`events list ... --event-type $LOTTERY_ADDR::rounds::RoundSnapshotUpdatedEvent`), чтобы сверить, что последние снапшоты совпадают с данными view.


## 4. Настройка параметров VRF-запроса

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::configure_vrf_request --args u8:<RNG_COUNT> u64:<NUM_CONFIRMATIONS> u64:<CLIENT_SEED>"
```
Убедитесь, что `RNG_COUNT > 0`, а `NUM_CONFIRMATIONS` находится в диапазоне `1..20` (ограничение Supra dVRF). Событие `VrfRequestConfigUpdatedEvent` фиксирует значения.

## 5. Публикация пакета и взаимодействие
1. Публикуем контракт:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool publish --profile <PROFILE> --package-dir /supra/move_workspace/lottery"
   ```
2. Пополняем банк (при необходимости) и продаём билеты (для нескольких адресов, используйте faucet testnet и отдельный профайл для каждого игрока). **Розыгрыш планируется автоматически, только когда в пуле ≥ 5 билетов** — иначе `manual_draw`/`request_draw` завершатся ошибкой.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/player1.yaml /supra/supra move tool run --profile <PLAYER_PROFILE> --function-id lottery::main_v2::buy_ticket"
   ```
   > Вызов требует подписи самого игрока, поэтому указывайте профиль с его приватным ключом (`--profile <PLAYER_PROFILE>` и соответствующий `SUPRA_CONFIG`, если используете YAML). Аналогично запускаем команду для других участников (player2, player3 и т.д.).
   После продажи пятого билета проверьте статус:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_lottery_status"
   ```
   В ответе поле `draw_scheduled` должно быть `true`, а `pending_request` — `false`.
   Для автоматизированной проверки перед запуском VRF можно выполнить скрипт `python supra/scripts/testnet_draw_readiness.py` (см. раздел 6) — он проверит количество билетов, whitelisting агрегаторов и достижение минимального депозита.
3. Делаем запрос VRF:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::main_v2::manual_draw"
   ```
   Функция проверяет whitelisting агрегатора и потребителей, убеждается, что `draw_scheduled = true` и нет активного `pending_request`. При несоблюдении условий вернёт `Move abort … manual_draw at code offset 11` — значит, необходимо продать недостающие билеты или дождаться обработки предыдущего запроса.
4. Ожидаем callback `on_random_received`. Проверяем события:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::main_v2::DrawHandledEvent"
   ```

## 6. Верификация и мониторинг
- Быстрый способ собрать основные view-команды — скрипт [`supra/scripts/testnet_status_report.sh`](../supra/scripts/testnet_status_report.sh). Он принимает переменные `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR` (и опционально `CLIENT_ADDR`/`SUPRA_CONFIG`) и выводит состояние контракта и депозита в одном отчёте.
- Перед запуском `manual_draw` можно использовать [`supra/scripts/testnet_draw_readiness.py`](../supra/scripts/testnet_draw_readiness.py). Скрипт запускает `testnet_monitor_json.py`, проверяет количество билетов, отсутствие `pending_request`, whitelisting агрегаторов и достижение минимального депозита, возвращая код 0/1.
- Для полного автоматического запуска предусмотрен [`supra/scripts/testnet_manual_draw.py`](../supra/scripts/testnet_manual_draw.py) — он повторяет проверку готовности (можно выключить флагом `--skip-readiness`), выводит фактическую команду Supra CLI и при необходимости выполняет `manual_draw`.
- Для автоматизированного мониторинга минимального баланса используйте [`supra/scripts/testnet_monitor_check.sh`](../supra/scripts/testnet_monitor_check.sh). Скрипт рассчитывает `min_balance` по текущим лимитам газа, сравнивает с on-chain-остатком `deposit::checkClientFund` и завершает работу с кодом 1, если депозит опустился до порога (`isMinimumBalanceReached = true`) или ниже ожидаемого значения. Рекомендации по запуску скриптов по расписанию, в CI и Supra AutoFi собраны в [отдельном руководстве](./dvrf_monitoring_automation.md).
- Для получения машиночитаемого статуса подписки (баланс, whitelisting, конфигурация VRF) воспользуйтесь [`supra/scripts/testnet_monitor_json.py`](../supra/scripts/testnet_monitor_json.py). Скрипт повторно использует расчёт `calc_min_balance.py`, обращается к `view`-функциям контракта и модуля `deposit` и при флаге `--fail-on-low` завершает работу с кодом 1, если баланс меньше `min_balance`.
- Для отправки уведомлений в Slack/Teams или любой совместимый webhook используйте [`supra/scripts/testnet_monitor_slack.py`](../supra/scripts/testnet_monitor_slack.py). Он запускает `testnet_monitor_json.py`, формирует текстовое сообщение и возвращает тот же код возврата (поддерживает `--fail-on-low` и опцию `--include-json`).
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_lottery_status"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_whitelist_status"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_vrf_request_config"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_client_whitelist_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_min_balance_limit_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::main_v2::get_consumer_whitelist_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::store::get_store_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::store::get_lottery_snapshot --args u64:<LOTTERY_ID>"`
- Контролируйте остаток депозита по событиям `SubscriptionConfiguredEvent`/`MinimumBalanceUpdatedEvent` и отчётам Supra dVRF (Supra CLI/Explorer отражает баланс клиента после `depositFundClient`).
- Для подробного мониторинга событий см. отдельный документ [dVRF event monitoring](./dvrf_event_monitoring.md) с примерами `events list` и `events tail`.
- Для контроля ассортимента и продаж магазина используйте поток `StoreSnapshotUpdatedEvent` (`events tail --event-type lottery::store::StoreSnapshotUpdatedEvent`) и агрегированные view выше.

## 7. Troubleshooting
Сводная таблица расшифровок и решений доступна в отдельном документе [dVRF error reference](./dvrf_error_reference.md).

- Для оперативного анализа событий VRF используйте [dVRF event monitoring](./dvrf_event_monitoring.md): он содержит команды `events list` и `events tail` для основных событий лотереи и модуля `deposit`.

- **Недостаток средств**: увеличить депозит и повторно вызвать `record_client_whitelist_snapshot` для фиксации нового лимита.
- **Нет callback-а**: проверить `DrawRequestedEvent`, убедиться, что `callbackGasLimit` достаточен и что контракт whitelisted.
- **Abort в `manual_draw` с offset 11**: убедитесь, что в пуле ≥ 5 билетов, флаг `draw_scheduled = true` (см. `get_lottery_status`), нет активного `pending_request`, а адрес отправителя и агрегатор whitelisted.
- **Abort по кодам 11/12**: payload-хеш не совпал, запустить `manual_draw` повторно после проверки параметров.

Записывайте tx hash каждого шага и добавляйте в README/CHANGELOG для аудита.

## 8. Чеклист деплоя (FA + VRF)
Ориентируемся на официальные инструкции Supra по токенам и CLI: [token-standards](https://docs.supra.com/network/move/token-standards), [fungible_asset module](https://docs.supra.com/network/move/supra-fungible-asset-fa-module), [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).

1. **Подготовка окружения**
   - Создать профиль CLI: `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile new <PROFILE> <PRIVATE_KEY_HEX> --network testnet"`.
   - При необходимости активировать и проверить список: `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile -l"`.
   - Проверить подключение к сети: `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra status --profile <PROFILE>"`.
2. **Инициализация казначейства**
   - `treasury_v1::is_initialized` → если `false`, вызвать `treasury_v1::init_token` с параметрами проекта.
   - Зафиксировать tx hash и адрес Metadata из `treasury_v1::metadata_address`.
3. **Регистрация primary store**
   - Для адреса лотереи: `treasury_v1::register_store_for`.
   - Для игроков и сервисных аккаунтов: батч `treasury_v1::register_stores_for` или вручную.
   - Проверить `treasury_v1::account_extended_status` для каждого адреса (регистрация + freeze-флаг).
4. **Загрузка балансов**
   - Минт тестовых сумм через `treasury_v1::mint_to` → `treasury_v1::balance_of` для проверки.
   - При необходимости заморозить подозрительные аккаунты `treasury_v1::set_store_frozen`.
5. **VRF-депозит и whitelisting**
   - Настроить лимиты газа через `lottery::main_v2::configure_vrf_gas`.
   - Рассчитать минимальный депозит (формула `30 * maxGasPrice * (maxGasLimit + verificationGasValue)`), вызвать `lottery::main_v2::create_subscription` с запасом и убедиться в событии `SubscriptionConfiguredEvent`.
   - При необходимости обновить минимальный баланс (`lottery::main_v2::set_minimum_balance`).
6. **Конфигурация лотереи**
   - `lottery::main_v2::record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request`.
   - Провести whitelisting агрегатора/потребителей (`whitelist_callback_sender`, `whitelist_consumer`).
   - Проверить `lottery::main_v2::get_lottery_status`, `get_whitelist_status`, `get_vrf_request_config`, `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot`.
7. **Smoke-тест**
   - Минт токенов двум игрокам, купить билеты (`buy_ticket`), запросить розыгрыш (`manual_draw`).
   - Убедиться, что `WinnerSelected` и `DrawHandledEvent` появились в истории событий.
   - Для автоматизации базовой проверки используйте скрипт [`supra/scripts/testnet_smoke_test.sh`](../supra/scripts/testnet_smoke_test.sh):
     он копирует YAML-профиль (если задан `SUPRA_CONFIG`), регистрирует store администратора, минтит средства, покупает 5 билетов,
     настраивает `configure_vrf_request` и вызывает `manual_draw`, после чего остаётся отследить `DrawHandledEvent`.

Все шаги логируем в таблицу (дата, команда, tx hash, ответ view) для последующего аудита.

## 9. План отката
Если необходимо временно вернуться к предыдущей экономике или отключить продажи:

1. **Зафиксировать состояние**
   - Снять снапшоты `treasury_v1::treasury_balance`, `total_supply`, `get_config` и `account_extended_status` для ключевых адресов.
   - Экспортировать список билетов и текущий `jackpot_amount` через view-функции `lottery::main_v2`.

## 10. Автоматизация Supra Move тестов
- Перед публикацией релиза вручную запустите `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages --keep-going --report-json ci/move-test-report.json --report-junit ci/move-test-report.xml -- --skip-fetch-latest-git-deps` и зафиксируйте результат в отчёте. Команда последовательно проверит `lottery`, `lottery_factory`, `vrf_hub` и другие пакеты workspace, не прерываясь на первом провале; JSON (`ci/move-test-report.json`) и JUnit (`ci/move-test-report.xml`) можно приложить к релизному отчёту или загрузить в CI-артефакты. Автоматический GitHub Actions workflow отключён по договорённости — регрессионные проверки выполняются оператором вручную.
- Для запуска внутри Docker сохраните ту же команду: `docker compose run --rm --entrypoint bash supra_cli -lc "python -m supra.scripts.cli move-test --workspace /supra/move_workspace --all-packages -- --skip-fetch-latest-git-deps"`. При необходимости можно предварительно вывести список пакетов через `python -m supra.scripts.cli move-test --workspace /supra/move_workspace --list-packages` либо локально выполнить `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --list-packages`.
- Для локальной отладки без docker compose используйте команду ниже (идентична основной, но запуск через `docker run`):
  ```bash
  docker run --rm \
    -e SUPRA_HOME=/supra/configs \
    -v $(pwd)/supra/move_workspace:/supra/move_workspace \
    -v $(pwd)/supra/configs:/supra/configs \
    --entrypoint bash \
    asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12 \
    -lc "python -m supra.scripts.cli move-test --workspace /supra/move_workspace --all-packages -- --skip-fetch-latest-git-deps"
  ```
- Ведите журнал запусков (дата, commit, конфигурация), чтобы демонстрировать регулярную валидацию клиента Supra VRF согласно рекомендациям Supra VRF Subscription FAQ.
2. **Заморозить операции**
   - Временно заблокировать покупку билетов через административную настройку фронтенда/скриптов.
   - По необходимости заморозить primary store игроков `treasury_v1::set_store_frozen(account, true)`.
3. **Распределить остатки**
   - Выплатить джекпот победителям `treasury_v1::payout_from_treasury`.
   - Сжечь излишки у казначейства `treasury_v1::burn_from`.
4. **Отключить FA-потоки**
   - Обновить `treasury_v1::set_config`, установив 100% на казначейство до завершения отката.
   - При необходимости архивировать capability: хранить seed Metadata и tx hash `init_token` (см. [официальную документацию](https://docs.supra.com/network/move/token-standards)).
5. **Документировать**
- Задокументировать причину отката, время, ответственных и ссылки на tx.
- Обновить README/runbook с указанием, когда и как FA будет повторно включена.

Возврат к работе выполняем в обратном порядке: разблокировка store, восстановление конфигурации, smoke-тест.

## 11. Чек-лист типичных ошибок Supra Move
- `error[E01002]: unexpected token` с ключевым словом `mut` — удаляйте `mut`, переменные Move изменяемые по умолчанию.
- `error[E03002]: unbound module '0x1::u64'/'0x1::u128'` — используйте проектные хелперы для чисел (`safe_add_u64`, `safe_mul_u128`, `u8_to_u64`).
- `error[E04001]`/`error[E04013]` при доступе к константам модулей — обращайтесь через публичные view-функции и тестовые обёртки.
- `error[E04004]`/`error[E04005]` при оборачивании кортежей в `Option` — заменяйте кортежи отдельными структурами `*_View`.
- Полный справочник с кодами ошибок см. в документе [docs/move_common_errors_ru.md](move_common_errors_ru.md).
