# Supra Lottery / Супра Лотерея

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra. Он реализует простую лотерею с интеграцией dVRF v2; в репозитории находятся основной модуль, расширенные тесты и Docker-инфраструктура для оффлайн-работы с Supra CLI.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v2 (модули supra_vrf, deposit)
- Fungible Asset-токен, развёрнутый через обёртку `lottery::treasury_v1`
- Среда Supra CLI в Docker (docker-compose.yml)
- Развёрнутые Move-юнит-тесты в supra/move_workspace/lottery/tests

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: cd SupraLottery.
3. Переключитесь на рабочую ветку `Test` и выполняйте все коммиты только в ней; новые ветки не создаём, а после достижения ключевых вех переносим изменения в `master`.
4. При необходимости откройте shell внутри контейнера Supra CLI: docker compose run --rm --entrypoint bash supra_cli.

> Ключи и параметры из supra/configs предназначены только для локальной разработки. Перед публикацией замените их собственными значениями.

### Запуск Move-тестов
`
docker compose run --rm \n  --entrypoint bash supra_cli \n  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
`
Команда собирает пакет, прогоняет 13 Move-юнит-тестов и изолирует зависимости внутри контейнера.

### Структура проекта
- docker-compose.yml — описание контейнера Supra CLI
- supra/configs/ — локальные конфиги Supra с ключами и историей (только для разработки)
- supra/move_workspace/lottery/Move.toml — манифест Move-пакета
- supra/move_workspace/lottery/sources/ — контракт лотереи (Lottery.move) и FA-казначейство (Treasury.move)
- supra/move_workspace/lottery/tests/ — Move-тесты, покрывающие события, поток VRF и админские сценарии

### Казначейство на Fungible Asset
Модуль `lottery::treasury_v1` оборачивает стандарт `0x1::fungible_asset` и предоставляет следующие сценарии:

1. **Инициализация токена** — `treasury_v1::init_token` создаёт Metadata-объект, включает primary store и сохраняет mint/burn/transfer capability на адресе лотереи.
2. **Регистрация хранилищ** — `treasury_v1::register_store` позволяет пользователям завести primary store, `register_store_for` даёт администратору возможность подготовить store для любого адреса, а `register_stores_for` регистрирует несколько адресов за один вызов.
3. **Минт/бёрн/трансфер** — функции `mint_to`, `burn_from`, `transfer_between` используют capability-ресурсы казначейства и требуют предварительно зарегистрированного store у всех участников.
4. **Заморозка store** — `treasury_v1::set_store_frozen` позволяет администратору временно заблокировать вывод и депозиты конкретного primary store (например, при разборе инцидентов). Повторный вызов с `false` снимает блокировку.
5. **Назначение получателей** — перед вызовом `set_recipients` администратор обязан зарегистрировать primary store на каждом целевом адресе (`register_store_for`/`register_stores_for`), иначе функция завершится `E_RECIPIENT_STORE_NOT_REGISTERED`; это соответствует требованиям Supra FA о переводах только между зарегистрированными store.
6. **Управление конфигурацией распределения** — `treasury_v1::set_config` обновляет доли (basis points) между джекпотом, призовым пулом и операционными направлениями, а `ConfigUpdatedEvent` фиксирует изменения; `get_config` предоставляет актуальные значения для фронтенда и скриптов.
7. **Интеграция с лотереей** — `treasury_v1::deposit_from_user` списывает токены при покупке билета, а `payout_from_treasury` (доступна модулю `lottery::main_v2`) распределяет джекпот из казначейства; обе операции проверяют наличие store у плательщика и получателя.

Просмотр балансов и состояния:

- `treasury_v1::treasury_balance()` — текущий запас токена в казначействе (эквивалент `fungible_asset::balance` для адреса лотереи).
- `treasury_v1::balance_of(account)` — баланс пользователя.
- `treasury_v1::metadata_summary()` — имя, символ, decimals и URI метадаты токена в формате `string::String` (совместимо с [официальными view-функциями Supra](https://docs.supra.com/network/move/token-standards#view-%D1%84%D1%83%D0%BD%D0%BA%D1%86%D0%B8%D0%B8)).
- `treasury_v1::get_config()` — текущие доли распределения джекпота и операционных направлений в basis points.
- `treasury_v1::account_status(account)` — регистрация primary store, адрес стора и баланс в одном вызове.
- `treasury_v1::account_extended_status(account)` — то же, плюс флаг freeze из `primary_fungible_store::is_frozen`.
- `treasury_v1::store_frozen(account)` — статус заморозки primary store (при `true` модуль `fungible_asset` заблокирует минт/депозиты/выводы).
- `treasury_v1::total_supply()` и `treasury_v1::metadata_address()` — мониторинг выпуска и адреса Metadata.

Юнит-тесты в `supra/move_workspace/lottery/tests/lottery_tests.move` включают регистрацию store, минт в пользу тестовых аккаунтов и проверку, что покупка билетов/выплата приза расходуют FA-токен. Добавлены негативные сценарии: покупка билета, минт и депозит без предварительной регистрации store завершаются abort с кодами `13` (на уровне `main_v2`) и `4` (в `treasury_v1`).

### План версионирования
- Текущая версия Move-пакета: `0.0.1`.
- Поднимаем до `0.0.2` после интеграции SDK dVRF v3 и обновления Docker-образа.
- Синхронизируем `Move.toml`, `README.md` и `docs/dVRF_v3_checklist.md` при каждом бумпе версии.
- Перед релизом прогоняем `supra move tool test` и фиксируем итоги в changelog (раздел README или docs).

### Подготовка к dVRF v3
### Запуск на Supra testnet
- RPC testnet: `https://rpc-testnet.supra.com` (chain id 6).
- Подробный runbook: см. `docs/testnet_runbook.md`.
- Все команды выполняем через Docker (`supra_cli`), указывая профиль testnet.
- Перед запуском заполните `supra/configs/<profile>.yaml` (RPC, адрес, приватный ключ, параметры газа) — формат и параметры описаны в [официальной инструкции Supra CLI](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
- Для миграции и whitelisting используйте функции `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request` — они логируют события для аудита и соответствуют разделу dVRF в [официальной документации](https://docs.supra.com/dvrf).
- В разделе 8 runbook-а есть чеклист деплоя FA + VRF, а в разделе 9 — план отката на случай инцидентов.
- `record_client_whitelist_snapshot` фиксирует maxGasPrice/maxGasLimit и снапшот `minBalanceLimit`; данные попадают в событие `ClientWhitelistRecordedEvent`.
- `configure_vrf_request` задаёт желаемую мощность запроса (`rng_count`, `client_seed`) и генерирует событие `VrfRequestConfigUpdatedEvent` для аудита.
- `record_consumer_whitelist_snapshot` отмечает `callbackGasPrice`/`callbackGasLimit` для контракта; факт логируется событием `ContractWhitelistRecordedEvent`.
- Текущий статус узнаём через `get_whitelist_status`, а снапшот минимального баланса доступен в `get_min_balance_limit_snapshot`.

### Дорожная карта
- Следить за релизом Supra dVRF v3, изучить обновлённый API и подготовить план миграции (https://docs.supra.com/dvrf).
- Обновить лотерейный модуль под dVRF v3, адаптировать события/тесты и задокументировать fallback для простых розыгрышей.
- Собрать интерактивный фронтенд (React + TypeScript + Supra SDK + StarKey) с покупкой билетов, запуском розыгрыша и историей событий.
- Подготовить REST/CLI-скрипты и демонстрационные пайплайны вокруг фронтенда и CLI-инструментов.
- Задокументировать развёртывание/эксплуатацию (эндпоинты devnet/testnet, переменные окружения, хостинг, runbook).

### Текущий статус
- Работаем в оффлайн-режиме на simple_draw, пока не завершена миграция на Supra dVRF v3.
- Регистрация VRF и ончейн-колбэки временно отключены в тестах и демонстрациях.
- Сначала обновляем контракт и фронтенд, затем включим живую генерацию случайных чисел.

### Полезные материалы
- Документация для разработчиков Supra: https://docs.supra.com/move/getting-started
- Стандарт Fungible Asset: https://docs.supra.com/network/move/token-standards
- Детали модуля fungible_asset и primary_fungible_store: https://docs.supra.com/network/move/supra-fungible-asset-fa-module
- Руководство по интеграции dVRF: https://docs.supra.com/dvrf
- Быстрый старт с Supra CLI: https://docs.supra.com/network/move/getting-started/supra-cli-with-docker
- Шаблоны dApp (есть пример dVRF): https://github.com/Supra-Labs/supra-dapp-templates
- Supra dev hub (база знаний и обсуждения): https://github.com/Supra-Labs/supra-dev-hub
- Документация по автоматизации: https://docs.supra.com/automation
- Чек-лист миграции dVRF v3: docs/dVRF_v3_checklist.md
- Снапшот интеграции dVRF v2: docs/dVRF_v2_snapshot.md

