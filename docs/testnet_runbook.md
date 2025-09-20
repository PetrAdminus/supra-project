# Supra Lottery — Testnet Runbook

## 1. Предварительные требования
- Аккаунт Supra с доступом к testnet и приватным ключом StarKey.
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
2. Пополняем банк (при необходимости) и продаём билеты (для нескольких адресов, использовать faucet testnet):
   ```bash
   supra move run --config /supra/configs/testnet.yaml \
     --function lottery::main_v2::buy_ticket \
     --args address:<PLAYER_ADDR>
   ```
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
