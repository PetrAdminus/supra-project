# Supra dVRF 3.0 — справочник ошибок

Документ описывает типичные ошибки, которые мы встречаем при настройке подписки Supra dVRF 3.0 в testnet, и способы их устранения. Список основан на официальной документации Supra (сентябрь 2025) и фактических сценариях из runbook.

## Таблица ошибок и решений

| Код/Сообщение | Когда возникает | Как исправить |
| --- | --- | --- |
| `FUNCTION_RESOLUTION_FAILURE` | Supra CLI не находит указанную функцию модуля. Чаще всего происходит, если использовать snake_case из устаревших примеров (`migrate_client`, `add_client_to_whitelist`, `deposit_fund`) вместо camelCase из официальной документации (`migrateClient`, `addClientToWhitelist`, `depositFundClient`). | Проверьте адрес модуля (`0x186b…::deposit` для dVRF) и убедитесь, что идентификатор функции указан в camelCase. При работе с кастомным YAML скопируйте его в `/supra/.aptos/config.yaml`, чтобы CLI не искал локальный `aptos init`. |
| `ECLIENT_NOT_EXIST (0x60001)` | Вызов `lottery::main_v2::create_subscription` или `deposit::addClientToWhitelist` выполнен до того, как Supra активировала клиента. | Сначала выполните `deposit::migrateClient` с нужными лимитами газа, дождитесь статуса `Success`, затем повторите `addClientToWhitelist`. При необходимости подождите несколько минут: Supra активирует адрес не мгновенно. |
| `E_INITIAL_DEPOSIT_TOO_LOW` | Депозит при создании подписки меньше расчётного минимума (`30 * maxGasPrice * (maxGasLimit + verificationGasValue)`). | Рассчитайте минимум по формуле (см. `lottery::main_v2::calculate_min_balance`) и добавьте запас 10–20 %. В скрипте `testnet_migration.sh` значение `INITIAL_DEPOSIT` сравнивается с минимумом автоматически. |
| `Move abort … manual_draw at code offset 11` | Контракт отклоняет запуск VRF-запроса. Причина — не выполнены условия: `draw_scheduled = true`, билетов < 5, есть активный `pending_request` или отправитель не whitelisted. | Проверьте `lottery::main_v2::get_lottery_status`, убедитесь, что продано ≥ 5 билетов, нет незавершённого запроса и адрес администратора whitelisted. |
| `E_ALREADY_INITIALIZED (0x2)` | Повторный вызов `treasury_v1::init_token` после успешной инициализации. | Игнорируйте ошибку и переходите к следующему шагу — токен уже развернут. Перед развёртыванием можно проверять статус через `treasury_v1::is_initialized`. |
| `E_CONSUMER_NOT_WHITELISTED` | Попытка удалить потребителя VRF, которого нет в whitelist. | Сначала вызовите `lottery::main_v2::get_whitelist_status`, чтобы убедиться в наличии адреса. |
| `E_REQUEST_STILL_PENDING` | Попытка whitelisting агрегатора или повторный `manual_draw`, пока ожидается предыдущий ответ dVRF. | Дождитесь события `DrawHandledEvent`, убедитесь, что `pending_request = false`, затем повторите команду. |
| Нет callback-а после `DrawRequestedEvent` | Supra не вызвала колбэк `on_random_received` (агрегатор не whitelisted, недостаточный `callbackGasLimit`, ошибка подписи). | Проверьте, что адрес агрегатора whitelisted (`get_whitelist_status`), увеличьте `callbackGasLimit`, просмотрите события `DrawHandledEvent` на наличие ошибок. |
| `Supra CLI: unexpected argument '--amount'` | Используется синтаксис старой версии CLI для `move run`. | В Supra CLI ≥2025.05 команды вызываются через `supra move tool run --profile … --function-id … --args …`; флаг `--amount` удалён. |

## Порядок диагностики

1. **Проверка CLI**: `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile list"` — профиль должен быть активен.
2. **Копирование YAML**: если используете `SUPRA_CONFIG`, скопируйте файл в `/supra/.aptos/config.yaml` перед запуском команд.
3. **Повтор запуска**: при ошибках Supra часто советует повторить команду через 1–2 минуты — whitelisting клиента может занимать время.
4. **Журнал событий**: `supra move tool events tail` для `SubscriptionConfiguredEvent`, `DrawRequestedEvent`, `DrawHandledEvent` помогает понять, на каком этапе произошла остановка.
5. **Просмотр view-функций депозита**: `deposit::checkMinBalanceClient`, `deposit::getContractDetails` показывают зафиксированные лимиты и whitelisting на стороне Supra.

## Полезные ссылки

- [Supra dVRF 3.0 migration guide](https://docs.supra.com/dvrf/build-with-supra-dvrf/migration-to-dvrf-3.0)
- [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker)
- [VRF subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md)

Документ обновляется по мере появления новых кейсов и ошибок в testnet/mainnet.
