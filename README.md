# Supra Lottery / Супра Лотерея

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra. Он реализует простую лотерею с интеграцией dVRF v2; в репозитории находятся основной модуль, расширенные тесты и Docker-инфраструктура для оффлайн-работы с Supra CLI.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v2 (модули supra_vrf, deposit)
- Среда Supra CLI в Docker (docker-compose.yml)
- Развёрнутые Move-юнит-тесты в supra/move_workspace/lottery/tests

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: cd SupraLottery.
3. При необходимости откройте shell внутри контейнера Supra CLI: docker compose run --rm --entrypoint bash supra_cli.

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
- supra/move_workspace/lottery/sources/ — основной модуль (Lottery.move)
- supra/move_workspace/lottery/tests/ — Move-тесты, покрывающие события, поток VRF и админские сценарии

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
- Перед запуском заполните `supra/configs/<profile>.yaml` (rpc, адрес, приватный ключ, параметры газа).
- Для миграции и whitelisting используйте функции `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request` — они логируют события для аудита.

- Подробный runbook: см. `docs/testnet_runbook.md`.
- Все команды выполняем через Docker (`supra_cli`), указывая профиль testnet.
- Перед запуском заполните `supra/configs/<profile>.yaml` (rpc, адрес, приватный ключ, параметры газа).
- Для миграции и whitelisting используйте функции `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request` — они логируют события для аудита.

- `record_client_whitelist_snapshot` фиксирует maxGasPrice/maxGasLimit и снапшот `minBalanceLimit`; данные попадают в событие `ClientWhitelistRecordedEvent`.
- `configure_vrf_request` задаёт желаемую мощность запроса (rng_count, clientSeed) и генерирует событие `VrfRequestConfigUpdatedEvent` для аудита.
- `record_consumer_whitelist_snapshot` отмечает callbackGasPrice/callbackGasLimit для контракта; факт залогируем через `ContractWhitelistRecordedEvent`.
- Текущий статус узнаем через `get_whitelist_status`, а снапшот минимального баланса доступен в `get_min_balance_limit_snapshot`.

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
- Руководство по интеграции dVRF: https://docs.supra.com/dvrf
- Быстрый старт с Supra CLI: https://docs.supra.com/network/move/getting-started/supra-cli-with-docker
- Шаблоны dApp (есть пример dVRF): https://github.com/Supra-Labs/supra-dapp-templates
- Supra dev hub (база знаний и обсуждения): https://github.com/Supra-Labs/supra-dev-hub
- Документация по автоматизации: https://docs.supra.com/automation
- Чек-лист миграции dVRF v3: docs/dVRF_v3_checklist.md
- Снапшот интеграции dVRF v2: docs/dVRF_v2_snapshot.md

