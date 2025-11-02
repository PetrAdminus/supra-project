# SupraLottery — Testnet Runbook

Актуальная пошаговая инструкция для развёртывания и проверки лотереи в Supra testnet. Документ обновлён с учётом реальной работы в Windows + Docker + PowerShell/Git Bash.

## Временные допущения для тестового развёртывания

- Пока VRF-поток обкатываем, все доли (приз, джекпот, операции) временно направляем на аккаунт администратора (`lottery_admin`). Это упрощает контроль балансов во время тестов.
- Перед вызовами `core_treasury_multi::init` или `set_recipients` обязательно создаём primary store через `core_treasury_v1::register_store_for` для выбранного адреса.
- Когда перейдём к боевой конфигурации, замените адреса на отдельные кошельки для джекпота и операционного фонда и обновите документацию/скрипты публикации.

---

## 0. Предпосылки и соглашения

- Установлен Docker Desktop (используется `docker compose`).
- Профили Supra CLI подготовлены в репозитории: `SupraLottery/supra/configs/*.yaml` (например, `testnet.yaml` — админ, `player1.yaml`… — игроки).
- Все команды выполняются из корня репозитория: `C:\Users\spell\Desktop\projects\supra-project`.

Общий шаблон вызова Supra CLI в контейнере (PowerShell):

```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/<profile>.yaml /supra/.aptos/config.yaml && <supra command>"
```

Где `<profile>.yaml` — файл профиля (например, `testnet.yaml`, `player1.yaml`). Важно:
- Ключ `-lc` передаётся как отдельный аргумент (в кавычках).
- Путь к бинарю — строго `/supra/supra` (латиница).
- Для интерактивного ввода пароля удобно зайти внутрь контейнера:  
  `docker compose -f SupraLottery/compose.yaml run --rm -it --entrypoint bash supra_cli`

Плейсхолдеры в командах:
- `LOTTERY_ADDR` — адрес аккаунта, где опубликованы модули лотереи (например, `0xbc9595…caafe0`).
- `PLAYER_ADDR` — адрес игрока из соответствующего `playerN.yaml`.

---

## 1. Сборка пакетов Move

```
# lottery_core
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_core --skip-fetch-latest-git-deps"
# lottery_support
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_support --skip-fetch-latest-git-deps"
# lottery_rewards
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_rewards --skip-fetch-latest-git-deps"
```

---

## 2. Публикация (Supra testnet)

Публикация производится для `lottery_core` (далее по необходимости — support/rewards):

```
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core \
       --included-artifacts none --skip-fetch-latest-git-deps \
       --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
```

После публикации запомните адрес аккаунта (далее `LOTTERY_ADDR`).

---

## 3. Инициализация основного контракта (core_main_v2)

Новый основной модуль — `core_main_v2`. Перед покупкой билетов требуется создать ресурс лотереи.

```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id LOTTERY_ADDR::core_main_v2::init \
            --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
```

Проверка статуса:

```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool view --profile my_new_profile --function-id LOTTERY_ADDR::core_main_v2::get_lottery_status"
```

### Настройка параметров лотереи

По умолчанию `core_main_v2` стартует с ценой билета 0.01 SUPRA (`1_000_000` микросупра) и автоматическим запуском розыгрыша при 5 билетах. Эти значения можно менять без обновления пакета.

```
# Установка новой цены (пример: 0.02 SUPRA = 2_000_000 микросупра)
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool run \
        --profile my_new_profile \
        --function-id LOTTERY_ADDR::core_main_v2::set_ticket_price \
        --args u64:2000000 \
        --gas-unit-price 100 --max-gas 2000 --expiration-secs 300"

# Изменение порога автоматического розыгрыша (пример: 3 билета)
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool run \
        --profile my_new_profile \
        --function-id LOTTERY_ADDR::core_main_v2::set_auto_draw_threshold \
        --args u64:3 \
        --gas-unit-price 100 --max-gas 2000 --expiration-secs 300"
```

Проверить текущие значения можно `view`-запросами:

```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool view \
        --profile my_new_profile \
        --function-id LOTTERY_ADDR::core_main_v2::get_ticket_price"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool view \
        --profile my_new_profile \
        --function-id LOTTERY_ADDR::core_main_v2::get_auto_draw_threshold"
```

---

## 4. Подготовка игроков и покупка билетов

Для каждого игрока `playerN`:

1) Зарегистрировать primary store (однократно):
```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/playerN.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile playerN \
            --function-id LOTTERY_ADDR::core_treasury_v1::register_store \
            --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
```

2) Начислить LOT игроку (от админа):
```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id LOTTERY_ADDR::core_treasury_v1::mint_to \
            --args address:PLAYER_ADDR --args u64:100000000 \
            --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
```

3) Купить билет (у функции нет аргументов):
```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/playerN.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile playerN \
            --function-id LOTTERY_ADDR::core_main_v2::buy_ticket \
            --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
```

После не менее 5 покупок (можно с разных игроков) проверьте статус:
```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool view --profile my_new_profile --function-id LOTTERY_ADDR::core_main_v2::get_lottery_status"
```

---

## 5. Планирование розыгрыша

```
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli `
  "-lc" "/supra/supra move tool run --profile my_new_profile \
          --function-id LOTTERY_ADDR::core_rounds::schedule_draw \
          --args u64:0 --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
```

---

## 6. Статус‑репорт (Git Bash)

Скрипты bash удобно запускать из Git Bash:

```
"C:\\Program Files\\Git\\bin\\bash.exe" -lc '
  cd "/c/Users/spell/Desktop/projects/supra-project/SupraLottery" &&
  PROFILE=my_new_profile \
  LOTTERY_ADDR=0xbc9595...caafe0 \
  DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e \
  bash supra/scripts/testnet_status_report.sh --cli /supra/supra --profile my_new_profile
'
```

---

## 7. Типичные ошибки и решения

- `Status: Fail` в PowerShell без подробностей — выполняйте команды в интерактивной сессии контейнера (`docker compose … -it`) или через Git Bash с `winpty`.
- `E_STORE_NOT_REGISTERED` на `buy_ticket` — выполните `core_treasury_v1::register_store` под игроком, затем `core_treasury_v1::mint_to` от админа, затем повторите покупку.
- `429 Too Many Requests` у faucet — подождите указанное время или переведите газ с другого аккаунта (`move account transfer`).
- Модуль/функции — используйте `core_main_v2::*` вместо устаревшего `main_v2::*`.
- Пути: убедитесь, что везде используется латиница (`/supra/supra`).

---

## 8. Конфигурация VRF и депозита (важно перед подпиской)

Перед созданием подписки задайте лимиты газа и снимки whitelist, иначе `create_subscription` может падать:

1) Задать газ‑конфиг VRF (примеры):
```
/supra/supra move tool run --profile my_new_profile \
  --function-id LOTTERY_ADDR::core_main_v2::configure_vrf_gas \
  --args u128:1000 --args u128:500000 --args u128:1000 --args u128:500000 --args u128:25000 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```

2) Зафиксировать снимки whitelist под эти значения:
```
/supra/supra move tool run --profile my_new_profile \
  --function-id LOTTERY_ADDR::core_main_v2::record_client_whitelist_snapshot \
  --args u128:1000 --args u128:500000 --args u128:<MIN_BALANCE_LIMIT> \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300

/supra/supra move tool run --profile my_new_profile \
  --function-id LOTTERY_ADDR::core_main_v2::record_consumer_whitelist_snapshot \
  --args u128:1000 --args u128:500000 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```

Примечание: минимальный баланс рассчитывается как
```
min_balance = (max_gas_limit + verification_gas_value) * max_gas_price * window
```
При `1000/500000/25000` и `window=30` получается `15_750_000_000`. Если баланс SUPRA на админском профиле меньше — уменьшите параметры (например, `100/100000/10000` даёт `330_000_000`) и внесите меньший депозит.

Дополнительные коды ошибок и способы их устранения собраны в [справочнике dVRF 3.0](./dvrf_error_reference.md).

### 8.1 Оффлайн и демо режим

Иногда требуется показать розыгрыш без живого ответа от Supra dVRF (например, на демо или до завершения whitelisting). Контракт сохраняет упрощённый путь `simple_draw`, который использует локальные данные билетов.

1) Убедитесь, что билеты куплены и розыгрыш запланирован (`core_rounds::schedule_draw`). Если планирование не требуется, можно просто подтвердить наличие билетов через `get_lottery_status`.
2) Запустите оффлайн-розыгрыш от имени администратора:
   ```bash
   docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
     "-lc" "/supra/supra move tool run --profile my_new_profile \
            --function-id LOTTERY_ADDR::core_main_v2::simple_draw \
            --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
   ```
3) Проверьте событие `WinnerSelected` и состояние через `get_lottery_status` — колбэк VRF в этом сценарии не вызывается.
4) Перед возвращением к полноценному VRF-потоку убедитесь, что `pending_request` очищен и при необходимости заново вызовите `request_draw`.

> Предупреждение: `simple_draw` не обновляет счётчики VRF, поэтому не используйте его одновременно с активными dVRF-запросами.

3) Создать подписку (депозит в SUPRA):
```
/supra/supra move tool run --profile my_new_profile \
  --function-id LOTTERY_ADDR::core_main_v2::create_subscription \
  --args u64:<DEPOSIT_AMOUNT> \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```

После подписки можно запрашивать случайность (`core_rounds::request_randomness`) и отслеживать исполнение.

---

## 9. Покупка билетов и VRF-поток (пример на новой лотерее)

Ниже — последовательность, которую мы проходили на лотерее ID = 4. Подставляйте свой `LOTTERY_ID` и текущий `REQUEST_ID`.

1) Зарегистрировать primary store для администратора и направить туда все доли (в тестах используем `lottery_admin`):
```
/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_v1::register_store_for \
  --args address:0x3bd5cb43528ea967459e0741d8120fa4472f0c580a8b7c04f598cc3dd3341fbc \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300

/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_multi::set_recipients \
  --args address:0x3bd5cb43528ea967459e0741d8120fa4472f0c580a8b7c04f598cc3dd3341fbc \
  --args address:0x3bd5cb43528ea967459e0741d8120fa4472f0c580a8b7c04f598cc3dd3341fbc \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300

/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_multi::upsert_lottery_config \
  --args u64:4 \
  --args u64:6000 \
  --args u64:3000 \
  --args u64:1000 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```
> Замените `4` на фактический `LOTTERY_ID`.

2) Покупка билета игроком:
```
APTOS_CONFIG=/supra/SupraLottery/supra/configs/player1.yaml \
/supra/supra move tool run \
  --profile player1 \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::buy_ticket \
  --args u64:4 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```

3) Подготовка розыгрыша:
```
/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::schedule_draw \
  --args u64:4 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300

/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::hub::set_callback_sender \
  --args address:0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0 \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300

/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::request_randomness \
  --args u64:4 \
  --args hex:0x \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```

4) Мониторинг ожидания VRF:
```
/supra/supra move tool view \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::pending_request_id \
  --args u64:4

/supra/supra move tool view \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::hub::get_request \
  --args u64:2

/supra/supra move tool view \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::hub::list_pending_request_ids
```
Если `pending_request_id` пуст, заявка отработана. Пока `hub::get_request` возвращает запись, Supra VRF ещё не прислал ответ.

5) Завершение розыгрыша:
- **Боевой сценарий.** Ждём появления `hub::RandomnessFulfilledEvent` и того, что `hub::get_request` вернул `null`, затем вызываем `core_rounds::fulfill_draw`, передавая реальный `random_bytes`.
- **Тестовый сценарий (ручной).** Пока ждём боевой ответ, можно закрыть раунд тестовыми байтами:
```
/supra/supra move tool run \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::fulfill_draw \
  --args u64:2 \
  --args hex:0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --gas-unit-price 100 --max-gas 5000 --expiration-secs 300
```
> Замените `2` на фактический `REQUEST_ID`.

6) Проверяем итоги:
```
/supra/supra move tool view \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_rounds::get_round_snapshot \
  --args u64:4

/supra/supra move tool view \
  --profile my_new_profile \
  --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_multi::get_lottery_summary \
  --args u64:4
```

> Статус на момент обновления: лотерея ID = 3 продолжает ожидать реального ответа Supra VRF (request_id = 1); лотерея ID = 4 прошла ручной цикл — вручную вызван `core_rounds::fulfill_draw` с тестовыми байтами (request_id = 2), игрок 0x553fd4...1762 получил приз 18 000 000 SUPRA, операционный пул пополнился на 3 000 000.

---

## 7. Миграция подписки dVRF 3.0

Порядок действий соответствует camelCase API Supra и предполагает, что Move-пакеты уже опубликованы на `LOTTERY_ADDR`.

### 7.1. Перевод клиента Supra на v3

```powershell
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id DEPOSIT_ADDR::deposit::migrateClient \
            --args u128:100000 --args u128:150000 \
            --gas-unit-price 100 --max-gas 20000 --expiration-secs 300"
```

Значения `u128` аргументов соответствуют `max_gas_price` и `max_gas_limit` клиента. После миграции запускаем self-whitelisting:

```powershell
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id DEPOSIT_ADDR::deposit::addClientToWhitelist \
            --args u128:100000 --args u128:150000 \
            --gas-unit-price 100 --max-gas 20000 --expiration-secs 300"
```

### 7.2. Настройка минимума и депозита

```powershell
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id DEPOSIT_ADDR::deposit::clientSettingMinimumBalance \
            --args u128:5000000000 \
            --gas-unit-price 100 --max-gas 20000 --expiration-secs 300"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id DEPOSIT_ADDR::deposit::depositFundClient \
            --args u64:10000000000 \
            --gas-unit-price 100 --max-gas 20000 --expiration-secs 300"
```

После первого вызова `create_subscription` контракт записывает снапшоты whitelisting. Любой последующий вызов `lottery::core_main_v2::configure_vrf_gas` автоматически выполнит `deposit::updateMaxGasPrice` и `deposit::updateMaxGasLimit`, поэтому ручной CLI пригодится только для отладки или аварийной синхронизации.

### 7.3. Добавление контракта-Consumer

```powershell
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "mkdir -p /supra/.aptos && cp /supra/SupraLottery/supra/configs/testnet.yaml /supra/.aptos/config.yaml && \
          /supra/supra move tool run \
            --profile my_new_profile \
            --function-id DEPOSIT_ADDR::deposit::addContractToWhitelist \
            --args address:LOTTERY_ADDR \
            --args u128:30000 --args u128:120000 \
            --gas-unit-price 100 --max-gas 20000 --expiration-secs 300"
```

Для callback-газа действует та же схема: `configure_vrf_gas` синхронизирует `deposit::updateCallbackGasPrice` и `deposit::updateCallbackGasLimit`, пока в контракте сохранён снапшот consumer whitelist. Ручные команды Supra CLI оставьте в резерв на случай отсутствия снапшота.

### 7.4. Проверка конфигурации dVRF 3.0

```powershell
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "/supra/supra move tool view --profile my_new_profile \
          --function-id LOTTERY_ADDR::core_main_v2::get_client_whitelist_snapshot"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "/supra/supra move tool view --profile my_new_profile \
          --function-id LOTTERY_ADDR::core_main_v2::get_consumer_whitelist_snapshot"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli \
  "-lc" "/supra/supra move tool view --profile my_new_profile \
          --function-id DEPOSIT_ADDR::deposit::checkClientFund \
          --args address:LOTTERY_ADDR"
```

Сравните возвращаемые значения с конфигурацией в `LotteryData` (события `SubscriptionConfiguredEvent`, `GasConfigUpdatedEvent`).

---

## 8. Тестирование Move-пакетов

Для автоматизации используем Python-обёртку, которая ищет Supra CLI (`supra`) или vanilla Move CLI (`move`). Рекомендуется запускать тесты в контейнере Supra CLI:

```bash
# 1. Устанавливаем Move-фреймворки Supra во внутренний кэш (~/.move).
bash supra/scripts/bootstrap_move_deps.sh

# 2. Запускаем Move-тесты (пример для пакета lottery_core) внутри Docker-контейнера.
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

Артефакты выполнения (`tmp/move-test-report.{json,xml,log}`) сохраняются в каталоге `SupraLottery/tmp` и фиксируют используемый CLI, команду и статус. 02.11.2025 прогон для `lottery_core`, `lottery_support` и `lottery_rewards` завершился статусом `success`; результаты доступны в `SupraLottery/tmp/move-test-report.log`.

Команду запускаем из каталога `SupraLottery` (или с переменной `PYTHONPATH=SupraLottery`), чтобы Python нашёл модуль `supra.scripts`. Если в среде нет доступа к Docker, передайте путь к локальному бинарю через `--cli=/path/to/supra`. При отсутствии Supra CLI временно используйте `--dry-run`, чтобы проверить конфигурацию named addresses и зафиксировать набор команд.

Если Supra CLI временно недоступен, выполните сухой прогон, чтобы убедиться в корректности конфигурации named addresses и зафиксировать набор команд:

```bash
PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test \
  --workspace SupraLottery/supra/move_workspace \
  --package lottery_core \
  --dry-run \
  --report-json tmp/move-test-report.json \
  --report-junit tmp/move-test-report.xml \
  --report-log tmp/move-test-report.log
```

Отчёты с префиксом `tmp/move-test-report.*` пригодятся для аудита: JSON и JUnit содержат команды и статусы пакетов, лог отражает используемые бинарии и именованные адреса. Для регрессионных проверок повторяйте прогон после каждого значимого изменения Move-пакетов.

---

Документ проверен в среде Windows + Docker + PowerShell/Git Bash и отражает фактические шаги, необходимые для корректной покупки билетов и последующего розыгрыша.
