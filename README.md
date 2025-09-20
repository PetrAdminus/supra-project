# Supra Lottery / Супра Лотерея

## English

### Overview
Supra Lottery is a Move smart-contract package for the Supra blockchain that implements a simple on-chain lottery with dVRF v2 integration. The repository contains the on-chain module, integration tests, and Docker tooling for working with the Supra CLI offline.

### Stack Highlights
- Move language targeting Supra VM
- Supra dVRF v2 client (`supra_vrf`, `deposit` modules)
- Docker-based Supra CLI environment (`docker-compose.yml`)
- Extensive Move unit tests under `supra/move_workspace/lottery/tests`

### Getting Started
1. Ensure Docker Desktop (or another Docker runtime) is running.
2. Clone the repository and switch to the project root: `cd SupraLottery`.
3. Start the Supra CLI container shell if you need an interactive session:
   `docker compose run --rm --entrypoint bash supra_cli`

> Sensitive keys in `supra/configs` are provided for local development only. Rotate or replace them before deploying to public networks.

### Running Move Unit Tests
```
docker compose run --rm \
  --entrypoint bash supra_cli \
  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
```
This command compiles the package, runs all Move unit tests (13 by default), and keeps host dependencies isolated inside the container.

### Project Layout
- `docker-compose.yml` - Supra CLI container definition.
- `supra/configs/` - local Supra configuration, keys, and history (development only).
- `supra/move_workspace/lottery/Move.toml` - Move package manifest.
- `supra/move_workspace/lottery/sources/` - main on-chain module (`Lottery.move`).
- `supra/move_workspace/lottery/tests/` - Move unit tests exercising events, VRF flow, and admin paths.

### Next Steps / Ideas
- Automate an offline workflow script (buy N tickets -> `simple_draw` -> print outcome).
- Add public documentation for CLI recipes and integration points.
- Prepare VRF whitelisting checklist (gas/deposit limits) for production readiness.

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra: реализует простую лотерею с поддержкой dVRF v2. В репозитории находятся исходный модуль, расширенные тесты и Docker-инфраструктура для оффлайн-работы с Supra CLI.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v2 (модули `supra_vrf`, `deposit`)
- Среда Supra CLI в Docker (`docker-compose.yml`)
- Развёрнутые Move-юнит-тесты в `supra/move_workspace/lottery/tests`

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: `cd SupraLottery`.
3. При необходимости откройте shell внутри контейнера Supra CLI:
   `docker compose run --rm --entrypoint bash supra_cli`

> Ключи и параметры из `supra/configs` предназначены только для локальной разработки. Перед публикацией в общедоступной сети замените их собственными значениями.

### Запуск Move-тестов
```
docker compose run --rm \
  --entrypoint bash supra_cli \
  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
```
Команда собирает пакет, прогоняет все Move-тесты (13 штук) и изолирует зависимости внутри контейнера.

### Структура проекта
- `docker-compose.yml` - описание контейнера Supra CLI.
- `supra/configs/` - локальные конфиги Supra с ключами и историей (только для разработки).
- `supra/move_workspace/lottery/Move.toml` - манифест Move-пакета.
- `supra/move_workspace/lottery/sources/` - основной модуль блокчейна (`Lottery.move`).
- `supra/move_workspace/lottery/tests/` - Move-тесты, покрывающие события, поток VRF и админскую логику.

### Дальнейшие шаги
- Автоматизировать оффлайн-сценарий (покупка N билетов -> `simple_draw` -> вывод результата).
- Подготовить публичную документацию по CLI и интеграционным сценариям.
- Собрать информацию для whitelist VRF (лимиты газа, депозиты) перед релизом.
