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

   После инициализации все события ресурса используют `supra_framework::account::new_event_handle`, поэтому GUID событий детерминирован: `id.addr` совпадает с адресом лотереи, а `creation_num` уникален для каждого типа события. Для проверки выполните:

   ```bash
   docker compose run --rm \
     --entrypoint bash supra_cli \
     -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool resource --profile <PROFILE> --account <LOTTERY_ADDR> --resource-id lottery::treasury_v1::TreasuryState"
   ```

   В выводе поля `*_events.guid.id.creation_num` показывают, какие GUID нужно передать в `supra move tool event --start <seq>` при выгрузке логов. Подставьте фактический адрес лотереи из `.move/config` или runbook-а. Благодаря начальному `emit_event` сразу после `move_to` (см. модули `LotteryRounds`, `TreasuryMulti`, `Autopurchase` и др.) номер последовательности начинается с `0`, что облегчает синхронизацию с off-chain мониторингом.
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

### 3.3 Whitelisting агрегатора и потребителей
> Основано на [Supra VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md) и рекомендациях Supra о контроле доступа.

1. **Whitelisting агрегатора колбэков** — выполняется только администратором лотереи (`@lottery`) после успешного депозита и настройки газа. Команда запрещена, пока активен незавершённый VRF-запрос (`E_REQUEST_STILL_PENDING`).
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::whitelist_callback_sender \
     --args address:<AGGREGATOR_ADDR>
   ```
   - Зафиксируйте tx hash и событие `AggregatorWhitelistedEvent`.
   - При необходимости сменить агрегатор сначала убедитесь, что `pending_request` пуст (проверьте `lottery::main_v2::get_whitelist_status`).
   - Для временного отключения агрегатора используйте `lottery::main_v2::revoke_callback_sender`, но только когда нет активного запроса.

2. **Whitelisting потребителей VRF** — Supra VRF Subscription FAQ требует явно разрешать каждому контракту отправку запросов.
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::whitelist_consumer \
     --args address:<CONSUMER_ADDR>
   ```
   - Повторите для всех вспомогательных контрактов (операторских или будущих интеграций).
   - Проверяйте наличие адреса в списке через `lottery::main_v2::get_whitelist_status`.

3. **Удаление потребителя** при отзыве доступа или компрометации ключа:
   ```bash
   supra move run \
     --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::remove_consumer \
     --args address:<CONSUMER_ADDR>
   ```
   - Команда аварийно завершится `E_CONSUMER_NOT_WHITELISTED`, если адрес отсутствует в whitelist.
   - После ревока проверяйте событие `ConsumerRemovedEvent`.

4. **Контроль whitelisting через события**. Для аудита используйте CLI:
   ```bash
   supra move event --config /supra/configs/testnet.yaml \
     --address <LOTTERY_ADDR> \
     --event-type lottery::main_v2::AggregatorWhitelistedEvent

   supra move event --config /supra/configs/testnet.yaml \
     --address <LOTTERY_ADDR> \
     --event-type lottery::main_v2::ConsumerWhitelistedEvent
   ```
   Сохраняйте timestamp, tx hash и payload событий в runbook журналах.


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

## 10. Автоматизация Supra Move тестов
- Перед публикацией релиза вручную запустите `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"` и зафиксируйте результат в отчёте. Автоматический GitHub Actions workflow отключён по договорённости — регрессионные проверки выполняются оператором вручную.
- Для локальной отладки без docker compose используйте команду ниже (идентична основной, но запуск через `docker run`):
  ```bash
  docker run --rm \
    -e SUPRA_HOME=/supra/configs \
    -v $(pwd)/supra/move_workspace:/supra/move_workspace \
    -v $(pwd)/supra/configs:/supra/configs \
    --entrypoint bash \
    asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12 \
    -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
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
