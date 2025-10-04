# Supra Lottery / Супра Лотерея

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra. Он реализует лотерею с ончейн-интеграцией Supra dVRF 3.0, whitelisting агрегатора и потребителей, а также защитой колбэка по требованиям Supra; в репозитории находятся основной модуль, тестовая батарея и Docker-инфраструктура для оффлайн-работы с Supra CLI.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v3 (модули `supra_vrf`, `deposit` и интеграция `lottery::main_v2`)
- Fungible Asset-токен, развёрнутый через обёртку `lottery::treasury_v1`
- Среда Supra CLI в Docker (docker-compose.yml)
- Расширенные Move-юнит-тесты, покрывающие whitelisting, обработку VRF и негативные сценарии (`supra/move_workspace/lottery/tests`)

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: cd SupraLottery.
3. Переключитесь на рабочую ветку `Test` и выполняйте все коммиты только в ней; новые ветки не создаём, а после достижения ключевых вех переносим изменения в `master`.
4. При необходимости откройте shell внутри контейнера Supra CLI: docker compose run --rm --entrypoint bash supra_cli.

> Ключи и параметры из supra/configs предназначены только для локальной разработки. Перед публикацией замените их собственными значениями.

### Запуск Move-тестов
```
docker compose run --rm \
  --entrypoint bash supra_cli \
  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
```
Команда собирает пакет и прогоняет полный набор Move-юнит-тестов (позитивные и негативные сценарии VRF, whitelisting, переполнения счётчиков) внутри контейнера. На данный момент тесты запускаются вручную перед каждым релизом; автоматический CI отключён по требованию аудитора.

### Юнит-тесты Python-скриптов
В репозитории появились вспомогательные утилиты на Python, поэтому для регрессионной проверки формул и форматирования достаточно запустить встроенный `unittest`:

```
python -m unittest tests.test_calc_min_balance
```

Тест проверяет соответствие расчётов `calc_min_balance.calculate` формуле из `lottery::main_v2`, корректность разбора чисел с разделителями (`parse_u128`) и форматирование человекочитаемых сумм.

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

### Эксплуатация dVRF v3
Этот раздел агрегирует ончейн-функции и операционные регламенты, необходимые для сопровождения действующей подписки Supra dVRF 3.0.

#### Дополнительные справочники и чек-листы
- [Testnet runbook](docs/testnet_runbook.md) — полный регламент настройки казначейства, депозита и VRF-запросов.
- [Walkthrough для профиля `my_new_profile`](docs/dvrf_testnet_my_new_profile_walkthrough.md) — готовый набор команд с подстановкой адресов и лимитов газа.
- [Справочник по модулю `deposit`](docs/dvrf_deposit_cli_reference.md) — все команды Supra CLI для управления подпиской и проверок whitelisting.
- [Скрипт расчёта минимального депозита](supra/scripts/calc_min_balance.py) — вычисляет `per_request_fee` и рекомендуемый депозит с запасом.
- [Пример переменных окружения для миграции](supra/scripts/testnet_env.example) — шаблон `.env` для скрипта миграции и ручных команд.
- [Мониторинг событий dVRF](docs/dvrf_event_monitoring.md) — команды `events list/tail` и подсказки по парсингу результатов.
- [Справочник ошибок dVRF](docs/dvrf_error_reference.md) — расшифровка кодов `E*` и рекомендации по устранению.
- [Чек-лист миграции dVRF v3](docs/dVRF_v3_checklist.md) — статус перехода и TODO для команды разработки.
- [Скрипт смоук-теста testnet](supra/scripts/testnet_smoke_test.sh) — автоматизирует покупку билетов и запуск `manual_draw` для проверки подписки.
- [Скрипт отчёта о статусе подписки](supra/scripts/testnet_status_report.sh) — собирает ключевые view-команды для контракта и депозита Supra dVRF.
- [Скрипт проверки депозита](supra/scripts/testnet_monitor_check.sh) — выполняет расчёт `min_balance`, сравнивает его с фактическим депозитом и завершает работу с ошибкой при срабатывании порогов мониторинга.
- [Проверка готовности к розыгрышу](supra/scripts/testnet_draw_readiness.py) — запускает `testnet_monitor_json.py`, проверяет билеты, whitelisting агрегатора и состояние депозита перед вызовом `manual_draw`.
- [Автозапуск manual_draw](supra/scripts/testnet_manual_draw.py) — повторяет проверку готовности и вызывает `manual_draw`, выводя команду Supra CLI.
- [JSON-отчёт о подписке](supra/scripts/testnet_monitor_json.py) — агрегирует `view`-данные контракта и модуля `deposit`, возвращая машиночитаемый вывод и необязательный `exit=1`, если баланс ниже `min_balance`.
- [Webhook-уведомление о статусе](supra/scripts/testnet_monitor_slack.py) — формирует сообщение и отправляет его в Slack/любой совместимый webhook на основе `testnet_monitor_json.py`.
- [Prometheus-метрики подписки](supra/scripts/testnet_monitor_prometheus.py) — конвертирует отчёт мониторинга в формат Prometheus и опционально отправляет его на Pushgateway/HTTP endpoint.
- [Единый CLI для скриптов](supra/scripts/cli.py) — позволяет вызывать все Python-утилиты одной командой `python -m supra.scripts <подкоманда>`.
- [Автоматизация мониторинга Supra dVRF](docs/dvrf_monitoring_automation.md) — рекомендации по запуску скриптов через cron, CI и Supra AutoFi.
### Запуск на Supra testnet
- RPC testnet: `https://rpc-testnet.supra.com` (chain id 6).
- Подробный runbook: см. `docs/testnet_runbook.md`.
- Все команды выполняем через Docker (`supra_cli`), указывая профиль testnet.
- Перед запуском заполните `supra/configs/<profile>.yaml` (RPC, адрес, приватный ключ, параметры газа) — формат и параметры описаны в [официальной инструкции Supra CLI](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
- Для миграции и whitelisting используйте функции `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request` — они логируют события для аудита и соответствуют разделу dVRF в [официальной документации](https://docs.supra.com/dvrf).
- В разделе 8 runbook-а есть чеклист деплоя FA + VRF, а в разделе 9 — план отката на случай инцидентов.
- `record_client_whitelist_snapshot` фиксирует maxGasPrice/maxGasLimit и снапшот `minBalanceLimit`; данные попадают в событие `ClientWhitelistRecordedEvent`.
- `configure_vrf_request` задаёт желаемую мощность запроса (`rng_count`, `client_seed`) и генерирует событие `VrfRequestConfigUpdatedEvent` для аудита.
- `record_consumer_whitelist_snapshot` отмечает `callbackGasPrice`/`callbackGasLimit` для контракта; факт логируется событием `ConsumerWhitelistSnapshotRecordedEvent`.
- Текущий статус узнаём через `get_whitelist_status`, а снапшот минимального баланса доступен в `get_min_balance_limit_snapshot`.
- Стоимость билета можно получить через view-функцию `lottery::main_v2::get_ticket_price()`, что упрощает синхронизацию фронтенда.

### Дорожная карта
- Отслеживать обновления Supra dVRF 3.x и при изменении API оперативно обновлять клиент и тестовый стенд.
- Интегрировать фронтенд (React + TypeScript + Supra SDK + StarKey) с новыми view-функциями (`get_ticket_price`, `get_whitelist_status`).
- Подготовить REST/CLI-скрипты и пайплайны деплоя, используя `docs/testnet_runbook.md` как основу для автоматизации.
- Расширить мониторинг: парсинг событий whitelisting и конфигурации газа, алерты по минимальному депозиту, проверки CI.
- Разработать стратегию архивации исторических розыгрышей и аналитики выплат (графики, выгрузки в BI).

### Текущий статус
- Подписка Supra dVRF 3.0 настроена с whitelisting агрегатора и потребителей, а события фиксируют актуальную конфигурацию газа и nonce.
- Контракт проверяет хеш полезной нагрузки, `rng_count`, инициатора и параметры газа перед обработкой колбэка.
- Move-тесты покрывают сценарии переполнения, неверного whitelisting и повторной очистки состояния, обеспечивая регрессионный контроль интеграции.

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

