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

## 2. Настройка Supra CLI профиля
1. Скопировать шаблон `supra/configs/profile_template.yaml` в новый файл, например `supra/configs/testnet.yaml`.
2. Заполнить:
   - `rpc_url`: endpoint testnet.
   - `account_address`: адрес администратора.
   - `private_key`: приватный ключ (hex без `0x`).
   - `gas_unit_price`, `max_gas_amount`: рабочие значения для сети.
3. Проверить конфигурацию:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "supra config show --config /supra/configs/testnet.yaml"
   ```

## 3. Миграция на dVRF v3
> Все команды ниже выполняем через Docker, подставляя реальный профиль (пример: `/supra/configs/testnet.yaml`).

### 3.1 Инициализация Fungible Asset для казначейства
> Ориентируемся на официальные стандарты Supra: [token-standards](https://docs.supra.com/network/move/token-standards) и [описание `fungible_asset`](https://docs.supra.com/network/move/supra-fungible-asset-fa-module).

1. Проверяем, развёрнут ли токен казначейства:
   ```bash
   supra move view \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::is_initialized
   ```
2. Если ответ `false`, инициализируем Metadata (значения hex соответствуют ASCII-строкам `Lottery Ticket`, `LOT` и сид `lottery_fa_seed`):
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::init_token \
     --args \
       hex:0x6c6f74746572795f66615f73656564 \
       hex:0x4c6f7474657279205469636b6574 \
       hex:0x4c4f54 \
       u8:9 \
       hex:0x \
       hex:0x
   ```
3. Зарегистрируйте primary store для всех аккаунтов, которые будут получать токены:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::register_store_for \
     --args address:<ACCOUNT>
   ```
   Пользователи также могут вызвать `lottery::treasury_v1::register_store` самостоятельно через свой кошелёк.
   Для массовой подготовки можно использовать батч-функцию администратора:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::register_stores_for \
     --args address_vector:<ADDR1,ADDR2,...>  # формат аргумента описан в официальной документации Supra CLI
   ```
   > Подробнее об аргументе `address_vector` см. раздел "Vector arguments" в [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
4. Для тестовых аккаунтов можно заранее минтить баланс, чтобы они смогли купить билеты (после регистрации store):
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::mint_to \
     --args address:<PLAYER_ADDR> u64:<AMOUNT>
   ```
5. Проверяем метаданные и адреса store через view-функции:
   ```bash
   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::metadata_summary
   # Результат возвращается в виде string::String для строковых полей (см. официальные view-функции Supra: https://docs.supra.com/network/move/token-standards#view-%D1%84%D1%83%D0%BD%D0%BA%D1%86%D0%B8%D0%B8).

   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::primary_store_address \
     --args address:<ACCOUNT>

   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::get_config

   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::account_status \
     --args address:<ACCOUNT>

   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::account_extended_status \
     --args address:<ACCOUNT>

   supra move view --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::store_frozen \
     --args address:<ACCOUNT>
   ```
6. При необходимости можно временно заморозить primary store (например, на время расследования инцидента) и затем снять блокировку:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::set_store_frozen \
     --args address:<ACCOUNT> bool:true

   # Разморозить
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::set_store_frozen \
     --args address:<ACCOUNT> bool:false
   ```

7. Перед назначением получателей распределения убедитесь, что на каждом адресе создан primary store через `register_store_for` или `register_stores_for`; затем выполните:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::set_recipients \
     --args \
       address:<TREASURY_ADDR> \
       address:<MARKETING_ADDR> \
       address:<COMMUNITY_ADDR> \
       address:<TEAM_ADDR> \
       address:<PARTNERS_ADDR>
   ```
   Если какой-то адрес не имеет зарегистрированного store, команда завершится ошибкой `E_RECIPIENT_STORE_NOT_REGISTERED` — это требование Supra FA о переводах между зарегистрированными хранилищами.

8. Обновить доли распределения (сумма basis points должна равняться 10 000):
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::treasury_v1::set_config \
     --args \
       u64:<BP_JACKPOT> \
       u64:<BP_PRIZE> \
       u64:<BP_TREASURY> \
       u64:<BP_MARKETING> \
       u64:<BP_COMMUNITY> \
       u64:<BP_TEAM> \
       u64:<BP_PARTNERS>
   ```

### 3.2 Миграция клиента dVRF
1. Получить минимальный баланс:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function 0xDEP::deposit::getMinBalanceLimit \
     --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT>
   ```
2. Мигрировать клиента, внеся депозит (значительно больше результата предыдущей команды):
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function 0xDEP::deposit::migrateClient \
     --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> \
     --amount u128:<DEPOSIT>
   ```
3. Само-whitelisting клиента:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function 0xDEP::deposit::addClientToWhitelist \
     --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT>
   ```
4. Whitelisting контракта-потребителя:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function 0xDEP::deposit::addContractToWhitelist \
     --args address:<LOTTERY_ADDR> u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT>
   ```
5. Зафиксировать параметры в on-chain состоянии лотереи:
   ```bash
   supra move run --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::record_client_whitelist_snapshot \
     --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> u128:<MIN_BALANCE_LIMIT>

   supra move run --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::record_consumer_whitelist_snapshot \
     --args u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT>
   ```

## 4. Настройка параметров VRF-запроса
```bash
supra move run --config /supra/configs/testnet.yaml \
  --function lottery::main_v2::configure_vrf_request \
  --args u8:<RNG_COUNT> u64:<CLIENT_SEED>
```
Убедитесь, что `RNG_COUNT > 0`. Событие `VrfRequestConfigUpdatedEvent` фиксирует значения.

## 5. Публикация пакета и взаимодействие
1. Публикуем контракт:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli \
     -lc "supra move publish --package-dir /supra/move_workspace/lottery --config /supra/configs/testnet.yaml"
   ```
2. Пополняем банк (при необходимости) и продаём билеты (для нескольких адресов, используйте faucet testnet и отдельный профайл для каждого игрока):
   ```bash
   supra move run --config /supra/configs/player1.yaml \
     --function lottery::main_v2::buy_ticket
   ```
   > Вызов требует подписи самого игрока, поэтому `--config` должен ссылаться на профиль с его приватным ключом. Аналогично запускаем команду для других участников (player2, player3 и т.д.).
3. Делаем запрос VRF:
   ```bash
   supra move run --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::request_draw
   ```
4. Ожидаем callback `on_random_received`. Проверяем события:
   ```bash
   supra move event --config /supra/configs/testnet.yaml \
     --address <LOTTERY_ADDR> \
     --event-type lottery::main_v2::DrawHandledEvent
   ```

## 6. Верификация и мониторинг
- `supra move view --config /supra/configs/testnet.yaml --function lottery::main_v2::get_lottery_status`
- `supra move view --config /supra/configs/testnet.yaml --function lottery::main_v2::get_whitelist_status`
- `supra move view --config /supra/configs/testnet.yaml --function lottery::main_v2::get_vrf_request_config`
- Проверять баланс депозита через `supra move view --function 0xDEP::deposit::getClientBalance` (если доступно).

## 7. Troubleshooting
- **Недостаток средств**: увеличить депозит и повторно вызвать `record_client_whitelist_snapshot` для фиксации нового лимита.
- **Нет callback-а**: проверить `DrawRequestedEvent`, убедиться, что `callbackGasLimit` достаточен и что контракт whitelisted.
- **Abort по кодам 11/12**: payload-хеш не совпал, запустить `request_draw` повторно.

Записывайте tx hash каждого шага и добавляйте в README/CHANGELOG для аудита.

## 8. Чеклист деплоя (FA + VRF)
Ориентируемся на официальные инструкции Supra по токенам и CLI: [token-standards](https://docs.supra.com/network/move/token-standards), [fungible_asset module](https://docs.supra.com/network/move/supra-fungible-asset-fa-module), [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).

1. **Подготовка окружения**
   - Скопировать профиль CLI, указать RPC testnet, адрес администратора и приватный ключ.
   - Проверить подключение к сети: `supra status --config <profile>`.
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
   - Выполнить `deposit::getMinBalanceLimit`, `deposit::migrateClient`, `deposit::addClientToWhitelist`, `deposit::addContractToWhitelist`.
   - Зафиксировать события и tx hash.
6. **Конфигурация лотереи**
   - `lottery::main_v2::record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request`.
   - Проверить `lottery::main_v2::get_lottery_status` и `get_vrf_request_config`.
7. **Smoke-тест**
   - Минт токенов двум игрокам, купить билеты (`buy_ticket`), запросить розыгрыш (`request_draw`).
   - Убедиться, что `WinnerSelected` и `DrawHandledEvent` появились в истории событий.

Все шаги логируем в таблицу (дата, команда, tx hash, ответ view) для последующего аудита.

## 9. План отката
Если необходимо временно вернуться к предыдущей экономике или отключить продажи:

1. **Зафиксировать состояние**
   - Снять снапшоты `treasury_v1::treasury_balance`, `total_supply`, `get_config` и `account_extended_status` для ключевых адресов.
   - Экспортировать список билетов и текущий `jackpot_amount` через view-функции `lottery::main_v2`.
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
