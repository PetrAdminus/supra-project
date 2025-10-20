# Supra Lottery / Супра Лотерея

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra. Он реализует лотерею с ончейн-интеграцией Supra dVRF 3.0, whitelisting агрегатора и потребителей, а также защитой колбэка по требованиям Supra; в репозитории находятся основной модуль, тестовая батарея и Docker-инфраструктура для оффлайн-работы с Supra CLI.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v3 (модули `supra_vrf`, `deposit`, VRF-хаб `vrf_hub::hub` и мульти-лотерейные компоненты `lottery::instances`/`lottery::rounds`)
- Казначейство: Fungible Asset-токен через `lottery::treasury_v1` и многопуловое распределение через `lottery::treasury_multi`
- Среда Supra CLI в Docker (docker-compose.yml)
- Расширенные Move-юнит-тесты, покрывающие whitelisting, обработку VRF и негативные сценарии (`supra/move_workspace/lottery/tests`)

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: cd SupraLottery.
3. Переключитесь на рабочую ветку `Test` и выполняйте все коммиты только в ней; новые ветки не создаём, а после достижения ключевых вех переносим изменения в `master`.
4. При необходимости откройте shell внутри контейнера Supra CLI: docker compose run --rm --entrypoint bash supra_cli.

> Ключи и параметры из supra/configs предназначены только для локальной разработки. Перед публикацией замените их собственными значениями.

### Запуск Move-тестов
Для локального прогона используйте унифицированную команду CLI — она автоматически подбирает доступную утилиту (`supra`, `aptos` или `move`) и прокидывает нужные аргументы. Запускайте команду из каталога `SupraLottery` (или добавьте `PYTHONPATH=SupraLottery`), чтобы Python увидел пакет `supra`:

```
cd SupraLottery
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery
```

Поддерживаются дополнительные сценарии:

- `--package` — прогнать тесты конкретного пакета (`vrf_hub`, `lottery_factory`). Если флаг опустить, будет собран весь workspace.
- `--list-packages` — вывести доступные пакеты внутри workspace (определяются по наличию `Move.toml`).
- `--all-packages` — последовательно запустить тесты для каждого пакета; удобно для CI, чтобы увидеть, какой пакет дал сбой.
- `--report-json <путь>` — сохранить результаты прогона (пакет, команда, код возврата, длительность) в JSON-файл для загрузки в CI-артефакты.
- `--report-junit <путь>` — сгенерировать JUnit XML с итогами тестов для публикации в CI.
- `--keep-going` — продолжать прогон даже после провала и вернуть код первого ошибочного пакета; полезно для отчётов с полным списком неуспешных пакетов.
- `--cli-flavour {supra,aptos,move}` — подсказать flavour при `--dry-run`, если бинарь CLI недоступен (скрипт сформирует команды и отчёты без реального запуска).
- Дополнительные ключи CLI передаются после `--`, например `-- --filter snapshots`.

Если Supra CLI не установлена, скрипт автоматически переключится на `aptos move test` или `move test`. При этом параметр пакета будет проброшен в корректной форме (`--package-dir` для Supra/Aptos или `--package` для vanilla Move). В режиме `--dry-run` можно подготовить отчёты JSON/JUnit заранее, указав flavour через `--cli-flavour` (например, `--dry-run --cli-flavour supra`) — это полезно для внутренних чек-листов, когда бинарь ещё не установлен. Для запуска внутри контейнера Docker сохраните предыдущую команду:

```
docker compose run --rm \
  --entrypoint bash supra_cli \
  -lc "python -m supra.scripts.cli move-test --workspace /supra/move_workspace --package lottery -- --named-addresses lottery=$(grep '^lottery' /supra/.move/config | cut -d'=' -f2) lottery_factory=$(grep '^lottery_factory' /supra/.move/config | cut -d'=' -f2) vrf_hub=$(grep '^vrf_hub' /supra/.move/config | cut -d'=' -f2) supra_addr=$(grep '^supra_addr' /supra/.move/config | cut -d'=' -f2)"
```

> Соглашения Move 1: не используем `let mut`, комментарии оставляем в ASCII, обработчики событий создаём напрямую через `supra_framework::account::new_event_handle`,
> а публикацию выполняем через `supra_framework::event::emit_event` без обёрток. Это облегчает перенос на новые версии Supra Framework и упрощает сопровождение кода.

> **Настройка адресов:** для одиночного запуска можно добавить `-- --override-addresses lottery=0x1ee ...`. Supra CLI Move 1 также принимает адреса через `--named-addresses`; если запускаете `supra move tool test` напрямую, обязательно передайте все именованные адреса (`lottery`, `lottery_factory`, `vrf_hub`, `supra_addr`) или экспортируйте `MOVE_HOME=.move`, чтобы CLI автоматически прочитал `.move/config`. В репозитории уже есть `.move/config` с тестнет-адресами и путём workspace; скрипт `move-test` и Supra CLI используют его автоматически. Для собственных окружений скопируйте `.move/config.example` и замените адреса на нужные — файл одинаково работает локально и внутри Docker.

### Прямой запуск `supra/scripts/move_tests.py`

Если нужно получить отчёты без обёртки CLI, используйте раннер `supra/scripts/move_tests.py`: он ищет Supra/Aptos/vanilla Move CLI, подставляет workspace и адреса из `.move/config`, сохраняет JSON/JUnit (`tmp/move-test-report.json`, `tmp/move-test-report.xml`) и лог `tmp/unittest.log`.

```bash
PYTHONPATH=SupraLottery python -m supra.scripts.move_tests \
  --workspace SupraLottery/supra/move_workspace \
  --all-packages \
  --mode test \
  --keep-going \
  --report-json tmp/move-test-report.json \
  --report-junit tmp/move-test-report.xml \
  --log-path tmp/unittest.log \
  -- --skip-fetch-latest-git-deps
```

Флаги `--mode check` и `--dry-run --cli-flavour supra` помогают подготовить артефакты в окружении без установленной Supra CLI. По умолчанию раннер читает `.move/config`, начиная с указанного воркспейса и поднимаясь вверх по каталогам, собирает именованные адреса и добавляет их в `--named-addresses`. Для нестандартной конфигурации передайте путь к файлу через `--move-config` либо отключите автоподстановку флагом `--no-auto-named-addresses`. Тот же скрипт использует workflow `.github/workflows/move-tests.yml`, выгружая отчёты в CI.

Команда собирает пакет и прогоняет полный набор Move-юнит-тестов (позитивные и негативные сценарии VRF, whitelisting, переполнения счётчиков). Поскольку пакеты используют git-зависимости Supra Framework/Move Stdlib, первый запуск скачает требуемые ревизии; при оффлайн-прогоне добавьте флаг `--skip-fetch-latest-git-deps` через `-- --skip-fetch-latest-git-deps`. Для регрессионных прогонов в CI используйте `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages --keep-going --report-json ci/move-test-report.json --report-junit ci/move-test-report.xml -- --skip-fetch-latest-git-deps`, чтобы каждый пакет проходил проверку, даже если один из них падает, а артефакты включали JSON и JUnit-отчёты. На данный момент тесты запускаются вручную перед каждым релизом; автоматический CI отключён по требованию аудитора.

### Юнит-тесты Python-скриптов
В репозитории появились вспомогательные утилиты на Python, поэтому для регрессионной проверки формул и форматирования достаточно запустить встроенный `unittest`:

```
python -m unittest tests.test_calc_min_balance
```

Тест проверяет соответствие расчётов `calc_min_balance.calculate` формуле из `lottery::main_v2`, корректность разбора чисел с разделителями (`parse_u128`) и форматирование человекочитаемых сумм.

### HTTP API для фронтенда и автоматизации
Чтобы отдавать фронтенду живые данные Supra без запуска отдельных скриптов, используйте FastAPI-сервис `supra.scripts.api_server`. Он переиспользует `testnet_monitor_json` и предоставляет REST-эндпоинты:

- `GET /healthz` — проверка статуса конфигурации.
- `GET /status` — агрегированный отчёт о VRF-хабе, коллекции лотерей и депозите (тот же JSON, что у `testnet_monitor_json`).
- `GET /commands` — список доступных CLI-команд с описаниями и модулями.
- `POST /commands/{name}` — запуск любой команды из `supra.scripts.cli` с возвратом `stdout/stderr/returncode`.
- `PUT /accounts/{address}` — создание или обновление профиля пользователя (ник, аватар, соцсети, произвольные настройки).
- `GET /accounts/{address}` — чтение сохранённого профиля по адресу Supra.
- `GET /chat/messages` — список последних сообщений глобального или лотерейного чата.
- `POST /chat/messages` — публикация сообщения; бэкенд сохраняет его в БД и рассылает через WebSocket.
- `GET /chat/announcements` — объявления о новых лотереях и результатах.
- `POST /chat/announcements` — создание объявления (для админских панелей).
- `WebSocket /chat/ws/{room}` — push-уведомления о сообщениях и объявлениях в реальном времени.
- `GET /support/articles` — список статей базы знаний (опционально фильтруется по локали).
- `GET /support/articles/{slug}` — чтение конкретной статьи.
- `PUT /support/articles/{slug}` — создание или обновление статьи (используется внутренними инструментами).
- `POST /support/tickets` — отправка обращения в службу поддержки.
- `PUT /progress/checklist/{code}` — создание или редактирование шага ежедневного чек-листа.
- `GET /progress/{address}/checklist` — статус активных заданий и факт выполнения пользователем.
- `POST /progress/{address}/checklist/{code}/complete` — отметка выполнения задания, фиксация метаданных и выдачи награды.
- `PUT /progress/achievements/{code}` — создание или обновление достижения.
- `GET /progress/{address}/achievements` — список достижений с прогрессом пользователя.
- `POST /progress/{address}/achievements/{code}/unlock` — фиксация выполненного достижения и дополнительного прогресса.

Подсистема прогресса использует ту же базу данных, что и профили: таблицы `checklist_tasks`, `checklist_progress`, `achievements`
и `achievement_progress` создаются автоматически при старте API. Эндпоинты позволяют админ-панели наполнять чек-листы и достижения,
а фронтенду — отмечать выполнение шагов, выдачу наград (например, билетов на 7-й день) и получение ачивок. Сценарии покрыты тестами
`test_progress_checklist_and_achievements` и `ProgressServiceTests`, проверяющими round-trip через REST и сервисный слой.

Команды `record-client-whitelist`, `record-consumer-whitelist`, `configure-vrf-gas`, `configure-vrf-request`,
`remove-subscription`, `configure-treasury-distribution` и `set-minimum-balance` добавлены
специально для фронтенда: они вызывают
`record_client_whitelist_snapshot`/`record_consumer_whitelist_snapshot`/`configure_vrf_gas`/`configure_vrf_request`/
`configure_treasury_distribution`/`set_minimum_balance`
через Supra CLI и печатают JSON с полями `tx_hash`, `submitted_at`, `stdout`, `stderr`. Благодаря этому React-приложение
может показывать подтверждение транзакции без парсинга сырых логов. Пример запроса для whitelisting:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  http://localhost:8000/commands/record-client-whitelist \
  -d '{"args": ["--max-gas-price", "1000", "--max-gas-limit", "5000", "--min-balance-limit", "7500", "--assume-yes"]}'
```

Ответ вернёт JSON `{"tx_hash": "0x...", "submitted_at": "2024-05-01T00:00:00Z", ...}`; код возврата команды доступен в поле
`returncode` основного ответа API. Для настройки VRF фронтенд последовательно вызывает `/commands/configure-vrf-gas`
и `/commands/configure-vrf-request`, поэтому в логах появятся две транзакции: сначала обновление лимитов газа,
затем фиксация `rng_count`/`num_confirmations`/`client_seed`. При деактивации тестовой интеграции можно вызвать `/commands/remove-subscription`,
который проверяет `pending_request` и удаляет контракт из whitelist Supra. Для изменения долей казначейства используется `/commands/configure-treasury-distribution`,
который валидирует сумму basis points и вызывает `treasury_v1::set_config`. После подтверждения новых лимитов админка запускает `/commands/set-minimum-balance`,
который сверяет ожидаемые значения `min_balance`/`per_request_fee` с расчётом мониторинга и вызывает
`main_v2::set_minimum_balance`.

#### Установка зависимостей

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r SupraLottery/requirements.txt
```

#### Переменные окружения
API использует тот же набор переменных, что и `testnet_monitor_json`:

- `PROFILE`, `LOTTERY_ADDR`, `HUB_ADDR`, `FACTORY_ADDR`, `DEPOSIT_ADDR`, `CLIENT_ADDR`
- `LOTTERY_IDS` — необязательный список идентификаторов (через запятую или JSON), если нужно ограничить отчёт конкретными лотереями
- `MAX_GAS_PRICE`, `MAX_GAS_LIMIT`, `VERIFICATION_GAS_VALUE`
- `MIN_BALANCE_MARGIN`, `MIN_BALANCE_WINDOW`
- `SUPRA_CLI_BIN` (опционально) и `SUPRA_CONFIG` (для передачи пути к YAML конфигу Supra CLI)
- `SUPRA_API_CACHE_TTL` — время кэширования ответа `/status` в секундах (по умолчанию отключено)
- `SUPRA_API_CORS_ORIGINS` — список разрешённых Origin через запятую (`*` разрешит всех клиентов)
- `SUPRA_ACCOUNTS_DB_URL` — строка подключения к базе данных профилей (по умолчанию локальный SQLite `supra_accounts.db`)

Запросы могут переопределять любую из переменных через query-параметры (`?profile=...&lottery_addr=...`).
Параметр `refresh=true` сбрасывает кэш и принудительно обращается к Supra CLI, даже если TTL ещё не истёк.

#### Запуск

```bash
python -m supra.scripts.cli api-server --host 0.0.0.0 --port 8000 --cache-ttl 5 --cors-origins http://localhost:5173
```

Параметры `--host`, `--port`, `--log-level`, `--reload`, `--cache-ttl` и `--cors-origins` также можно задавать через переменные окружения `SUPRA_API_HOST`, `SUPRA_API_PORT`, `SUPRA_API_LOG_LEVEL`, `SUPRA_API_CACHE_TTL`, `SUPRA_API_CORS_ORIGINS`.

#### Подсистема аккаунтов

FastAPI включает модуль `/accounts`, который хранит профили пользователей в базе данных и позволяет фронтенду управлять никнеймом, аватаром, контактами и будущими настройками (например, автопокупкой билетов). По умолчанию используется файл `supra_accounts.db` (SQLite) в корне репозитория; для продуктивных окружений задайте `SUPRA_ACCOUNTS_DB_URL`, указывая, например, на PostgreSQL. Схема таблиц создаётся автоматически при старте API и покрыта юнит-тестами `tests/test_accounts.py`.

#### Real-time чат и объявления

Подпространство `/chat` использует ту же БД, что и аккаунты, и обеспечивает базовую инфраструктуру коммуникаций:

- `GET /chat/messages?room=global&limit=50` — возвращает отсортированный список сообщений выбранной комнаты (по умолчанию глобальная).
- `POST /chat/messages` — сохраняет сообщение, нормализует адрес отправителя и рассылает payload всем WebSocket-подписчикам комнаты.
- `GET /chat/announcements` и `POST /chat/announcements` — управление административными объявлениями, которые параллельно отправляются в комнату `announcements`.
- `WebSocket /chat/ws/{room}` — клиенты подключаются к нужной комнате и получают JSON-пакеты в реальном времени; отключения отслеживаются автоматически.

Функциональность покрыта тестами `test_chat_rest_roundtrip` и `test_websocket_receives_broadcast`, гарантирующими корректность REST-операций и доставки push-сообщений.

### Структура проекта
- docker-compose.yml — описание контейнера Supra CLI
- supra/configs/ — локальные конфиги Supra с ключами и историей (только для разработки)
- supra/move_workspace/Move.toml — корневой workspace для пакетов `lottery`, `vrf_hub`, `lottery_factory`
- supra/move_workspace/lottery/Move.toml — манифест исходного контракта лотереи
- supra/move_workspace/lottery/sources/ — контракт лотереи (Lottery.move), коллекция экземпляров (`LotteryInstances.move`), управление раундами мульти-лотереи (`LotteryRounds.move`), FA-казначейство (`Treasury.move`), многопуловое распределение (`TreasuryMulti.move`), модуль глобального джекпота (`Jackpot.move`), выпуск NFT-бейджей победителей (`NftRewards.move`), автопокупка билетов по расписанию (`Autopurchase.move`), VIP-подписки (`Vip.move`), реферальные бонусы (`Referrals.move`), магазин цифровых товаров (`Store.move`), управление делегированными операторами (`Operators.move`) и реестр витринных метаданных лотерей (`Metadata.move`)
- supra/move_workspace/lottery/sources/Migration.move — переходный модуль, который переносит состояние из `main_v2` в мульти-лотерейные таблицы (`instances`, `rounds`, `treasury_multi`) и публикует снапшоты миграции для аудита Supra
- supra/move_workspace/lottery/tests/ — Move-тесты, покрывающие события, поток VRF, админские сценарии и мульти-лотерейные проверки
- supra/move_workspace/vrf_hub/ — VRF-хаб с таблицей зарегистрированных лотерей, очередью запросов случайности, whitelisting callback-отправителя и событиями регистрации/статуса/выполнения запросов; покрыт Move-тестами, предоставляет view-функции `list_lottery_ids`, `list_active_lottery_ids`, `list_pending_request_ids`, `get_request` и `get_callback_sender_status`, а также публикует `CallbackSenderUpdatedEvent` при каждом обновлении агрегатора Supra
- supra/move_workspace/lottery_factory/ — фабрика, которая регистрирует лотереи в VRF-хабе, хранит планы розыгрышей, публикует снапшоты `LotteryRegistrySnapshotUpdatedEvent` с актуальным админом и параметрами каждой лотереи и предоставляет view `get_registry_snapshot`/`list_lottery_ids`; покрыта собственными Move-тестами

> Сборка отдельных пакетов выполняется через `supra move tool build --package-dir /supra/move_workspace/<пакет>`.

> Зеркальные каталоги (`SupraLottery/supra/...` и `supra/...`) заменены симлинками на единый Move-workspace; поддерживаем код только в `SupraLottery/supra/...`.

### Казначейство на Fungible Asset
Модуль `lottery::treasury_v1` оборачивает стандарт `0x1::fungible_asset` и предоставляет следующие сценарии:

1. **Инициализация токена** — `treasury_v1::init_token` создаёт Metadata-объект, включает primary store и сохраняет mint/burn/transfer capability на адресе лотереи.
2. **Регистрация хранилищ** — `treasury_v1::register_store` позволяет пользователям завести primary store, `register_store_for` даёт администратору возможность подготовить store для любого адреса, а `register_stores_for` регистрирует несколько адресов за один вызов.
3. **Минт/бёрн/трансфер** — функции `mint_to`, `burn_from`, `transfer_between` используют capability-ресурсы казначейства и требуют предварительно зарегистрированного store у всех участников.
4. **Заморозка store** — `treasury_v1::set_store_frozen` позволяет администратору временно заблокировать вывод и депозиты конкретного primary store (например, при разборе инцидентов). Повторный вызов с `false` снимает блокировку.
5. **Назначение получателей** — перед вызовом `set_recipients` администратор обязан зарегистрировать primary store на каждом целевом адресе (`register_store_for`/`register_stores_for`) и убедиться, что ни один из них не заморожен; иначе вызов завершится `E_RECIPIENT_STORE_NOT_REGISTERED` или стандартным `E_STORE_FROZEN`, что соответствует требованиям Supra FA о переводах только между готовыми store.
6. **Управление конфигурацией распределения** — `treasury_v1::set_config` обновляет доли (basis points) между джекпотом, призовым пулом и операционными направлениями, а `ConfigUpdatedEvent` фиксирует изменения; `get_config` предоставляет актуальные значения для фронтенда и скриптов.
7. **Наблюдаемость получателей** — view `treasury_v1::get_recipient_statuses` и тестовый декодер `recipient_status_fields_for_test` возвращают для каждого направления адрес, регистрацию, freeze-статус, адрес primary store и баланс, что позволяет мониторингу Supra оперативно проверять готовность кошельков перед распределением. Событие `RecipientsUpdatedEvent` теперь публикует два снапшота: предыдущие статусы направлений (для сравнения с новым конфигом) и актуальные данные после вызова, поэтому off-chain системы видят полную историю смены получателей.

### Автопокупка билетов
Модуль `lottery::autopurchase` хранит планы игроков на автоматическую покупку билетов и позволяет оффчейн-сервисам выполнять их без повторного участия пользователя. Основные сценарии:

1. **Настройка плана** — `configure_plan` записывает желаемое число билетов на один розыгрыш и флаг активности. План может быть создан заранее, ещё до пополнения баланса.
2. **Пополнение** — `deposit` списывает средства из primary store пользователя и увеличивает баланс плана, при этом токены остаются в казначействе до фактической покупки; состояние хранит агрегированную сумму по лотерее.
3. **Выполнение** — `execute` доступен администратору или самому игроку; функция рассчитывает, сколько билетов можно оплатить из текущего баланса, вызывает `rounds::record_prepaid_purchase` и фиксирует события `AutopurchaseExecutedEvent`.
4. **Возврат** — `refund` позволяет пользователю забрать неиспользованный остаток через `treasury_v1::payout_from_treasury`, что полезно перед отключением плана или сменой лотереи.

Дополнительные view-функции обеспечивают наблюдаемость:

- `get_plan(lottery_id, player)` — возвращает параметры и баланс конкретного игрока.
- `get_lottery_summary(lottery_id)` — агрегированное состояние (общий баланс, число игроков, число активных планов), которое использует мониторинг и API.
- `list_players(lottery_id)` и `list_lottery_ids()` — перечисления участников и лотерей с активными планами, пригодные для дашбордов и AutoFi-скриптов.
- `get_lottery_snapshot(lottery_id)` — полный снимок лотереи с балансами, счётчиками активных планов и детальным списком игроков.
- `get_autopurchase_snapshot()` и событие `AutopurchaseSnapshotUpdatedEvent` возвращают администратора и агрегированное состояние выбранной лотереи после `configure_plan`, `deposit`, `execute`, `refund` и `set_admin`, поэтому Supra CLI и мониторинг получают актуальные данные одним запросом.

Move-тесты `autopurchase_tests` покрывают пополнение, выполнение, возврат средств, агрегированные view и поток `AutopurchaseSnapshotUpdatedEvent`.

### Миграция legacy-лотерей
`lottery::migration` обеспечивает перенос накопленного состояния из исторической версии контракта в актуальные таблицы мульти-лотереи и теперь фиксирует полный снапшот операции:

1. **Агрегированный журнал** — после каждого `migrate_from_legacy` публикуется `MigrationSnapshotUpdatedEvent`, содержащий идентификатор лотереи, число мигрированных билетов, флаги розыгрыша до/после, исходный `next_ticket_id`, итоговый `next_ticket_id`, отсутствие pending-запросов, объём перенесённого джекпота и актуальные доли `prize/jackpot/operations` в basis points. Это позволяет Supra сверять миграцию с требованиями `Migration to dVRF 3.0` без ручного чтения storage.
2. **View для мониторинга** — `list_migrated_lottery_ids` возвращает все обработанные лотереи, а `get_migration_snapshot` выдаёт последнюю структуру `MigrationSnapshot`, пригодную для Supra CLI/дашбордов. В тестовом режиме `migration_snapshot_fields_for_test` помогает декодировать структуру, что используется в `migration_tests.move` для проверки событий и содержимого view.
3. **Защита от повторного запуска** — перед записью снапшота модуль убеждается, что для лотереи ещё не создан пул `treasury_multi`, а pending-заявки отсутствуют; нарушения приводят к `E_ALREADY_MIGRATED` и `E_PENDING_REQUEST` соответственно.

Move-тест `migration_tests` подтверждает корректность переноса тикетов, обновлённых событий и работы view-функций.

### VIP-подписки
Модуль `lottery::vip` добавляет платные подписки, которые дают игрокам дополнительные билеты при каждой покупке и пополняют операционный пул:

1. **Конфигурация** — администратор задаёт цену, длительность и количество бонусных билетов через `vip::upsert_config`; данные доступны во view `get_lottery_summary` и включают агрегированную выручку и число активных участников.
2. **Подписка** — `vip::subscribe` списывает оплату с кошелька игрока, депонирует сумму в казначейство (`treasury_multi::record_operations_income_internal`) и активирует бонус. Для подарков предусмотрен `vip::subscribe_for`, который разрешён администратору и списывает средства с его адреса.
3. **Бонусные билеты** — `lottery::rounds` автоматически вызывает `vip::bonus_tickets_for` и добавляет бесплатные билеты с событием `TicketPurchasedEvent` (с `amount = 0`), а `vip::record_bonus_usage` накапливает статистику и публикует `VipBonusIssuedEvent`.
4. **Отмена** — `vip::cancel` и `vip::cancel_for` позволяют игроку или администратору завершить подписку; состояние переводится в неактивное, а view-структуры отражают актуальный статус.
5. **Наблюдаемость** — помимо точечных view `list_lottery_ids`, `list_players`, `get_subscription` и `get_lottery_summary`, добавлены агрегированные `get_lottery_snapshot` и `get_vip_snapshot`, а событие `VipSnapshotUpdatedEvent` публикует полный снимок администратора, конфигураций, активных участников, выручки и начисленных бонусов после `init`, `set_admin`, `upsert_config`, `subscribe`/`subscribe_for`, `cancel`/`cancel_for` и `record_bonus_usage`. Это избавляет Supra CLI и мониторинг от реконструкции состояния по истории одиночных событий.

Move-тесты `vip_tests` проверяют выдачу бонусных билетов, пополнение операционного пула, агрегированные view и поток `VipSnapshotUpdatedEvent`, а также сценарий подарочной подписки с последующей отменой, подтверждая корректность снапшотов.

### Магазин цифровых товаров
Модуль `lottery::store` реализует продажу цифровых активов (например, кастомных аватаров или NFT-скинов), поступления от которой пополняют операционный пул лотереи:

1. **Каталог** — администратор добавляет или обновляет товар через `store::upsert_item`, задавая цену, описание и ограниченный запас (через `option::some(stock)`), либо оставляя безлимитную выдачу (`option::none`).
2. **Управление доступностью** — `store::set_availability` позволяет временно отключить товар без потери статистики продаж; событие `ItemConfiguredEvent` фиксирует изменения и доступно для мониторинга.
3. **Покупка** — `store::purchase` списывает оплату напрямую из кошелька игрока (через `treasury_v1::deposit_from_user`), уменьшает складской остаток, накапливает счётчик проданных единиц и отправляет выручку в `treasury_multi::record_operations_income_internal` с маркером `b"store"`.
4. **Наблюдаемость** — помимо точечных view `list_lottery_ids`, `list_item_ids`, `get_item` и `get_lottery_summary`, добавлены агрегированные `get_lottery_snapshot` и `get_store_snapshot`, а событие `StoreSnapshotUpdatedEvent` публикует администратора магазина и полный список товаров по лотерее после `upsert_item`, `set_availability`, `purchase` и `set_admin`. Это избавляет Supra CLI и мониторинг от необходимости реконструировать остатки и продажи по разрозненным событиям.

Move-тесты `store_tests` проверяют корректное списание запаса, пополнение операционного пула, поток `StoreSnapshotUpdatedEvent` и обновление агрегированных view при смене администратора магазина.

### Витринные метаданные лотерей
Модуль `lottery::metadata` хранит описания розыгрышей, которые нужны фронтенду, промо-сайту и партнёрам без обращения к внешнему CMS:

1. **Публикация и администрирование** — `metadata::init` разворачивает реестр под адресом `@lottery`, а `metadata::set_admin` позволяет передать управление другому адресу (например, мультисигу маркетинговой команды); все изменения администратора фиксируются событием `MetadataAdminUpdatedEvent`.
2. **Запись описаний** — `metadata::upsert_metadata` принимает структурированные поля (`title`, `description`, `image_uri`, `website_uri`, `rules_uri`) и сохраняет их в таблице без дублирования идентификаторов. Каждое обновление генерирует `LotteryMetadataUpsertedEvent` с признаком `created`, что упрощает синхронизацию оффчейн-кешей и CDN.
3. **Удаление** — `metadata::remove_metadata` удаляет запись и публикует `LotteryMetadataRemovedEvent`, освобождая идентификатор из витрины; попытка удалить отсутствующую запись приводит к `E_METADATA_MISSING`.
4. **Наблюдаемость** — событие `MetadataSnapshotUpdatedEvent` публикует полный снимок администратора и всех описаний после `init`, `set_admin`, `upsert_metadata` и `remove_metadata`, а view `get_metadata_snapshot` возвращает те же данные в удобном для Supra CLI JSON-виде; точечные запросы остаются доступны через `list_lottery_ids`, `has_metadata` и `get_metadata`.

Move-тесты `metadata_tests` проверяют запись, обновление, публикацию снапшотов и защиту от неавторизованных операций.

### Делегирование операторов лотерей
Модуль `lottery::operators` фиксирует владельцев отдельных розыгрышей и выданные им делегированные роли:

1. **Инициализация и администрирование** — `operators::init` публикует состояние под `@lottery`, а `operators::set_admin` позволяет передавать глобальное управление (например, мультисигу команды операций). Событие `AdminUpdatedEvent` помогает отслеживать историю смены администратора.
2. **Назначение владельцев** — `operators::set_owner` связывает конкретную лотерею с адресом владельца и эмитит `OwnerUpdatedEvent`. Запись создаётся один раз и может обновляться при передаче ответственности другой команде.
3. **Выдача и отзыв прав** — `operators::grant_operator` и `operators::revoke_operator` разрешены глобальному администратору и владельцу лотереи. Функции проверяют отсутствие дубликатов, ведут список операторов и публикуют события `OperatorGrantedEvent`/`OperatorRevokedEvent`, а также обновляют снапшот `OperatorSnapshotUpdatedEvent` с полным списком делегатов.
4. **Наблюдаемость** — помимо view-функций `list_lottery_ids`, `get_owner`, `list_operators` и `can_manage`, теперь доступна `get_operator_snapshot`, возвращающая владельца и текущий список операторов одним вызовом. Событие `OperatorSnapshotUpdatedEvent` помогает Supra и внутренним дашбордам отслеживать историю изменений без повторного опроса storage. Отчёт `/status` содержит раздел `operators` с агрегированной информацией, что упрощает интеграцию Supra AutoFi и админских панелей.

Move-тесты `operators_tests` подтверждают, что владелец может выдавать и отзывать роли, а сторонние адреса не получают доступ к делегированию.

### История розыгрышей
Модуль `lottery::history` сохраняет результаты розыгрышей и предоставляет API для панели честности и аналитики:

1. **Публикация и администрирование** — `history::init` развёртывает коллекцию под `@lottery`, фиксирует администратора и создаёт event handle `DrawRecordedEvent`. Администратор может быть переопределён через `history::set_admin`.
2. **Запись результатов** — дружественная функция `history::record_draw` вызывается `lottery::rounds::fulfill_draw`: она добавляет `DrawRecord` (победитель, номер билета, сумма приза, случайные байты, payload и отметка времени), сокращает историю до 128 записей и эмитит событие `DrawRecordedEvent`.
3. **Очистка** — `history::clear_history` позволяет администратору обнулить записи конкретной лотереи без удаления самой коллекции, что полезно для архивирования или соблюдения политики хранения.
4. **Агрегированные снапшоты** — после каждой инициализации, записи и очистки публикуется `HistorySnapshotUpdatedEvent`, содержащий администратора, список лотерей и актуальные `DrawRecord` по каждой. View-функции `get_lottery_snapshot` и `get_history_snapshot` возвращают тот же агрегированный срез, а базовые `list_lottery_ids`, `get_history`, `latest_record` и `has_history` позволяют API и мониторингу получать выборочные данные.

Move-тесты `history_tests` подтверждают сохранение записей при fulfill draw, корректное отражение последнего результата, публикацию снапшотов и очистку истории администратором.

### Реферальные бонусы
Модуль `lottery::referrals` позволяет гибко настраивать бонусы за приглашение и автоматически выплачивать их из операционного пула:

1. **Конфигурация на уровне лотереи** — `set_lottery_config` задаёт доли в базисных пунктах для реферера и приглашённого. Функция валидирует, что сумма бонусов не превышает операционную долю, заданную в `treasury_multi`.
2. **Регистрация связей** — игроки указывают пригласившего их адрес через `register_referrer`, а администратор может скорректировать или очистить связь (`admin_set_referrer`/`admin_clear_referrer`). Все изменения фиксируются событиями `ReferralRegisteredEvent` и `ReferralClearedEvent`.
3. **Автовыплаты при покупке** — `rounds::complete_purchase` вызывает `referrals::record_purchase`, который рассчитывает положенные суммы, списывает их из операционного пула через `treasury_multi::pay_operations_bonus_internal` и эмитит событие `ReferralRewardPaidEvent`.
4. **Наблюдаемость** — view-функции `get_referrer`, `get_lottery_stats`, `list_lottery_ids`, `get_referral_snapshot` и счётчик `total_registered` позволяют API и мониторингу строить отчёты по реферальной активности, а событие `ReferralSnapshotUpdatedEvent` публикует агрегированный снимок (админ, общее число рефералов, настройки и статистику по каждой лотерее) при инициализации, обновлении конфигурации, регистрации/удалении рефералов и выплатах бонусов.

Тесты `referrals_tests` проверяют успешную выплату бонусов, корректность статистики и защиту от некорректной конфигурации.

### NFT-бейджи победителей
Модуль `lottery::nft_rewards` позволяет отмечать победителей уникальными NFT-бейджами:

1. `nft_rewards::init` развёртывает глобальное состояние под адресом @lottery, публикует счётчик бейджей и события `BadgeMintedEvent`/`BadgeBurnedEvent`.
2. `nft_rewards::mint_badge` может вызываться только администратором (адрес @lottery); она резервирует новый `badge_id`, сохраняет метаданные (`lottery_id`, `draw_id`, `metadata_uri`, адрес минтера) и эмитит событие, пригодное для панели честности и фронтенда.
3. `nft_rewards::burn_badge` доступна администратору или владельцу бейджа и полностью удаляет запись, публикуя `BadgeBurnedEvent`.
4. Для мониторинга доступны `has_badge`, `list_badges`, `list_owner_addresses`, `get_owner_snapshot` и `get_snapshot`: они возвращают как индивидуальные бейджи, так и агрегированные снимки (администратор, счётчик `next_badge_id`, владельцы и их награды). Событие `NftRewardsSnapshotUpdatedEvent` публикуется после `init`, минта и бёрна, поэтому Supra и аудиторы получают актуальный снимок без реконструкции истории событий. Обновлённые Move-тесты `nft_rewards_tests.move` покрывают выпуск, запрет минта неадминистратором, бёрн владельцем и корректность snapshot/view/событий.
7. **Интеграция с лотереей** — `treasury_v1::deposit_from_user` списывает токены при покупке билета, а `payout_from_treasury` (пакетная функция, доступная всем модулям `lottery`) распределяет призы, глобальный джекпот и операционные доли; обе операции проверяют наличие store у плательщика и получателя.

#### Коллекция экземпляров `lottery::instances`
- Публикуется под `@lottery` и связывается с VRF-хабом (адрес хранится в поле `hub`).
- При создании экземпляра через `create_instance` проверяет регистрацию в VRF-хабе и фабрике, переносит blueprint в локальное состояние и эмитирует `LotteryInstanceCreatedEvent`.
- Статистика продаж и вкладов в джекпот аккумулируется внутри `InstanceState` и доступна через view-функции `get_lottery_info`, `get_instance_stats`, `get_instance_snapshot`; структура статистики теперь включает признак активности экземпляра.
- `set_instance_active` позволяет администратору синхронизировать статус лотереи с VRF-хабом (требует, чтобы `hub::set_lottery_active` уже вызван с тем же значением) и публикует `LotteryInstanceStatusUpdatedEvent`.
- После каждого `create_instance`, `sync_blueprint`, `set_instance_active`, записи продаж (`record_ticket_sale`) и миграционных операций модуль публикует агрегированный `LotteryInstancesSnapshotUpdatedEvent`: событие содержит администратора, адрес VRF-хаба и полный набор параметров экземпляра (владельца, адрес контракта, цену билета, долю джекпота, накопленные продажи и статус активности), что позволяет Supra и мониторингу отслеживать актуальное состояние без реконструкции истории событий.
- View-функция `get_instances_snapshot` возвращает такую же структуру (`LotteryInstancesSnapshot` с админом, адресом VRF-хаба и списком всех экземпляров), а `get_instance_snapshot` позволяет запрашивать отдельный экземпляр. Это дополняет базовые `list_lottery_ids` и `list_active_lottery_ids`, благодаря чему оффчейн-сервисы (API, мониторинг, Supra AutoFi) получают полный перечень и параметры активных/архивных лотерей одним вызовом.

#### Многопуловое казначейство `treasury_multi`
- Инициализируется под адресом `@lottery`, хранит администратора и адреса получателей глобальных пулов (джекпот и операционный бюджет).
- Перед вызовом `treasury_multi::init` требуется завершить `treasury_v1::init_token` и зарегистрировать primary store для адресов джекпота и операционного пула (`treasury_v1::register_store_for`); контракт проверяет условия и вернёт `E_TREASURY_NOT_READY`/`E_JACKPOT_RECIPIENT_UNREGISTERED`/`E_OPERATIONS_RECIPIENT_UNREGISTERED` при нарушении.
- Перед инициализацией, сменой адресов и выплатами модуль дополнительно проверяет freeze-статус primary store: `init`/`set_recipients` блокируют замороженные адреса (`E_JACKPOT_RECIPIENT_FROZEN`, `E_OPERATIONS_RECIPIENT_FROZEN`), `withdraw_operations` и `pay_operations_bonus_internal` завершаются с кодами `E_OPERATIONS_RECIPIENT_FROZEN`/`E_BONUS_RECIPIENT_UNREGISTERED`/`E_BONUS_RECIPIENT_FROZEN`, а выплаты джекпота требуют готовности кошелька победителя (`E_JACKPOT_WINNER_UNREGISTERED`, `E_JACKPOT_WINNER_FROZEN`).
- Для аудита Supra FA используйте `treasury_multi::get_recipient_statuses`: функция возвращает адрес получателя, признак регистрации, freeze-статус и баланс primary store, что помогает сверять готовность пулов перед выплатами.
- История изменений пулов фиксируется событием `treasury_multi::RecipientsUpdatedEvent`: оно публикует статусы primary store для предыдущих и новых адресов при `init` и каждом `set_recipients`, что позволяет Supra и операторам отслеживать смену кошельков и freeze-флаги.
- Для каждой лотереи хранит конфигурацию распределения (`prize_bps`, `jackpot_bps`, `operations_bps`) и накапливает отдельные балансы приза и операционного пула.
- Функция `record_allocation` записывает поступления от продажи билетов, раскладывая их по трём направлениям и эмитя событие `AllocationRecordedEvent`.
- View-функции `list_lottery_ids`, `get_lottery_summary`, `get_config`, `get_pool` и `jackpot_balance` позволяют фронтенду и скриптам Supra AutoFi получать перечень настроенных лотерей, актуальные доли и накопленные суммы для визуализации каталога и планирования розыгрыша глобального джекпота.
- View-функция `get_recipients` возвращает адреса текущих пулов, чтобы операторы могли быстро сверить регистрацию стора и freeze-статус через `treasury_v1::account_extended_status`.
- Выплаты осуществляются функциями `distribute_prize`, `withdraw_operations` и `distribute_jackpot`, которые вызывают `treasury_v1::payout_from_treasury`, обнуляют соответствующие балансы и публикуют события `PrizePaidEvent`, `OperationsWithdrawnEvent`, `JackpotPaidEvent`.
- Для реферальных бонусов добавлен внутренний помощник `pay_operations_bonus_internal`, списывающий часть операционного пула и фиксирующий событие `OperationsBonusPaidEvent`; его используют модули роста (`lottery::referrals`) и мониторинг.
- VIP-подписки пополняют операционный пул через `record_operations_income_internal`, который увеличивает баланс, сохраняет событие `OperationsIncomeRecordedEvent` и позволяет мониторингу учитывать выручку подписок отдельно от продаж билетов.

#### Глобальный джекпот `lottery::jackpot`
- Инициализируется администратором `@lottery` с заранее выделенным идентификатором VRF-хаба (`hub::register_lottery`), что позволяет рассматривать джекпот как отдельную лотерею в очереди запросов случайности.
- Хранит список билетов (адреса участников), флаг запланированного розыгрыша и pending-запрос VRF; события `JackpotTicketGrantedEvent` фиксируют выдачу билетов (например, за прохождение чек-листа).
- `schedule_draw`, `request_randomness` и `reset` управляют жизненным циклом розыгрыша и публикуют события `JackpotScheduleUpdatedEvent`/`JackpotRequestIssuedEvent`, которые читают оффчейн-сервисы и фронтенд.
- Каждое изменение состояния фиксируется событием `JackpotSnapshotUpdatedEvent`: оно публикует администратора, `lottery_id`, количество билетов, флаг запланированного розыгрыша и pending-запрос (включая `pending_request_id`, если заявка отправлена), поэтому Supra и мониторинг получают актуальный снимок без реконструкции истории событий.
- `fulfill_draw` проверяет соответствие `lottery_id`, выбирает победителя по случайным байтам, убеждается в регистрации primary store и перечисляет весь накопленный глобальный пул через `treasury_multi::distribute_jackpot_internal`, эмитя `JackpotFulfilledEvent`.
- View-функции `get_snapshot`, `pending_request` и `lottery_id` предоставляют агрегированное состояние для API и мониторинга: `get_snapshot` возвращает того же вида структуру, что и событие `JackpotSnapshotUpdatedEvent`, позволяя Supra CLI сверять администратора, количество билетов и `pending_request_id` с событиями.

#### Миграция со старого контракта `lottery::migration`
- `migrate_from_legacy` переносит состояние из `lottery::main_v2`: копирует список билетов, призовой пул, флаг расписания и обновляет таблицы `instances`, `rounds`, `treasury_multi`.
- Функция автоматически создаёт пул распределения и сбрасывает старый `LotteryData`, поэтому её достаточно вызвать один раз после подготовки VRF-хаба и фабрики.
- Перед миграцией требуется зарегистрировать лотерею в фабрике и VRF-хабе, создать экземпляр через `instances::create_instance` и выбрать новые доли распределения (`prize_bps`, `jackpot_bps`, `operations_bps`).

- Публикует `RoundCollection` под `@lottery`, где хранятся состояния всех розыгрышей: проданные билеты, флаг запланированного дро, pending-запрос VRF и счётчик ticket_id.
- `buy_ticket` регистрирует покупку через `LotteryInstances`, автоматически создаёт запись раунда, списывает `ticket_price` из кошелька игрока через `treasury_v1::deposit_from_user`, фиксирует вклад в джекпот и прокидывает сумму в `treasury_multi`.
- `schedule_draw`, `request_randomness` и `reset_round` позволяют администратору отмечать подготовку к VRF-запросу, ставить заявку в очередь VRF-хаба и очищать раунд после розыгрыша; все шаги сопровождаются событиями для off-chain сервисов и блокируют действия, если лотерея деактивирована.
- `fulfill_draw` проверяет whitelisting callback-отправителя, извлекает запрос из VRF-хаба, выбирает победителя на основе случайных байтов, распределяет приз через `treasury_multi::distribute_prize_internal`, фиксирует событие `DrawFulfilledEvent` (с суммой выигрыша) и обнуляет состояние раунда.
- Каждое изменение состояния публикует `RoundSnapshotUpdatedEvent`, который содержит `ticket_count`, флаг `draw_scheduled`, `pending_request_id` (при наличии активной заявки) и `next_ticket_id`. Этого достаточно для мониторинга Supra — не требуется восстанавливать состояние раунда из набора событий покупок и расписания.
- View-функция `get_round_snapshot` возвращает тот же `RoundSnapshot`, что и событие `RoundSnapshotUpdatedEvent`, поэтому Supra CLI может сверять `pending_request_id` и статус расписания одним вызовом. Отдельная view `pending_request_id` сохранена для обратной совместимости и выдаёт идентификатор pending-заявки при наличии.

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
- [Чек-лист деплоя Supra testnet](docs/testnet_deployment_checklist.md) — быстрый контрольный список адресов, лимитов газа и обязательных команд перед релизом.
- [Внутренний чек-лист аудита SupraLottery](docs/audit/internal_audit_checklist.md) — пошаговая проверка кода, тестов и документации перед передачей результатов Supra.
- [Сценарий динамического аудита G1](docs/audit/internal_audit_dynamic_runbook.md) — инструкции по запуску Supra CLI, сбору JSON/JUnit, `python -m unittest` и смоук-тесту testnet.
- [Чек-лист миграции dVRF v3](docs/dVRF_v3_checklist.md) — статус перехода и TODO для команды разработки.
- [Скрипт смоук-теста testnet](supra/scripts/testnet_smoke_test.sh) — автоматизирует покупку билетов и запуск `manual_draw` для проверки подписки.
- [Скрипт отчёта о статусе подписки](supra/scripts/testnet_status_report.sh) — собирает ключевые view-команды для контракта и депозита Supra dVRF.
- [Скрипт проверки депозита](supra/scripts/testnet_monitor_check.sh) — выполняет расчёт `min_balance`, сравнивает его с фактическим депозитом и завершает работу с ошибкой при срабатывании порогов мониторинга.
- [Проверка готовности к розыгрышу](supra/scripts/testnet_draw_readiness.py) — запускает `testnet_monitor_json.py`, проверяет билеты, whitelisting агрегатора и состояние депозита перед вызовом `manual_draw`.
- [Автозапуск manual_draw](supra/scripts/testnet_manual_draw.py) — повторяет проверку готовности и вызывает `manual_draw`, выводя команду Supra CLI.
- [JSON-отчёт о подписке](supra/scripts/testnet_monitor_json.py) — агрегирует `view`-данные контракта и модуля `deposit`, возвращая машиночитаемый вывод и необязательный `exit=1`, если баланс ниже `min_balance`. Отчёт включает разделы `lotteries` (фабрика и экземпляры), `autopurchase` (планы автопокупки), `vip` (подписки с бонусами) и `referrals` (конфигурация и статистика бонусов по лотереям), поэтому фронтенд и Supra AutoFi получают единый источник правды по мульти-лотерейной экономике.
- [Webhook-уведомление о статусе](supra/scripts/testnet_monitor_slack.py) — формирует сообщение и отправляет его в Slack/любой совместимый webhook на основе `testnet_monitor_json.py`.
- [Prometheus-метрики подписки](supra/scripts/testnet_monitor_prometheus.py) — конвертирует отчёт мониторинга в формат Prometheus и опционально отправляет его на Pushgateway/HTTP endpoint.
- [Единый CLI для скриптов](supra/scripts/cli.py) — позволяет вызывать все Python-утилиты одной командой `python -m supra.scripts <подкоманда>`.
- [Автоматизация мониторинга Supra dVRF](docs/dvrf_monitoring_automation.md) — рекомендации по запуску скриптов через cron, CI и Supra AutoFi.
### Запуск на Supra testnet
- RPC testnet: `https://rpc-testnet.supra.com` (chain id 6).
- Подробный runbook: см. `docs/testnet_runbook.md`.
- Все команды выполняем через Docker (`supra_cli`), указывая профиль testnet.
- Перед запуском заполните `supra/configs/<profile>.yaml` (RPC, адрес, приватный ключ, параметры газа) — формат и параметры описаны в [официальной инструкции Supra CLI](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
- Для миграции и whitelisting используйте функции `record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request` — они логируют события для аудита и соответствуют разделу dVRF в [официальной документации](https://docs.supra.com/dvrf). `configure_vrf_request` принимает `rng_count`/`num_confirmations`/`client_seed`.
- В разделе 8 runbook-а есть чеклист деплоя FA + VRF, а в разделе 9 — план отката на случай инцидентов.
- `record_client_whitelist_snapshot` фиксирует maxGasPrice/maxGasLimit и снапшот `minBalanceLimit`; данные попадают в событие `ClientWhitelistRecordedEvent`.
- `configure_vrf_request` задаёт желаемую мощность запроса (`rng_count`, `num_confirmations`, `client_seed`) и генерирует событие `VrfRequestConfigUpdatedEvent` для аудита.
- `record_consumer_whitelist_snapshot` отмечает `callbackGasPrice`/`callbackGasLimit` для контракта; факт логируется событием `ConsumerWhitelistSnapshotRecordedEvent`.
- Любая операция whitelisting публикует `WhitelistSnapshotUpdatedEvent` с агрегатором и полным списком потребителей; последнее состояние доступно через `get_whitelist_status` и события, что повторяет требования Supra к наблюдаемости очереди.
- VRF-хаб фиксирует whitelisting агрегатора событием `CallbackSenderUpdatedEvent`, а view `get_callback_sender_status` возвращает текущий адрес агрегатора или `None` — используйте их, чтобы убедиться, что колбэки Supra будут доставлены в нужный модуль.
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

## Состояние SupraLottery (Move): события и тесты

Этот раздел фиксирует прогресс по модульным тестам лотереи и контракту событий, чтобы сохранялся общий контекст между сессиями.

- Актуальный результат тестов: 136/136 PASSED
- Команда запуска (Docker):
  - `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"`
- Спецификация контракта событий: `docs/specs/events_contract.md`

Что сделано
- Переписаны «хрупкие» проверки событий на подход с baseline (assert_grew_by) там, где эмит снапшотов не гарантирован.
- Добавлены строгие ассерт‑хелперы в тестовые утилиты:
  - `assert_delta_eq(baseline, events, expected_delta, code)`
  - `assert_len_eq(events, expected, code)`
- Частично усилены проверки «core» событий (grant/revoke, request/fulfill) в тестах — без нарушения стабильности сборки.
- Зафиксирован контракт событий (MUST/MAY/NEVER) и шаблоны тестирования в `docs/specs/events_contract.md`.

Файлы, затронутые в тестовой части (основное)
- `SupraLottery/supra/move_workspace/lottery/tests/TestUtils.move` — добавлены ассерт‑хелперы.
- `SupraLottery/supra/move_workspace/lottery/tests/*` — локальные правки проверок событий (baseline, защита чтения последнего события и т.д.).

Рекомендации по проверкам
- «Core» события (grant/revoke, request/fulfill): можно переводить на строгие проверки по мере стабилизации кода (ровно один эмит на шаг).
- Снапшот‑события: до стабилизации эмита лучше использовать baseline‑проверки (рост ≥ 0) с дренажом событий перед целевым вызовом.

План/прогресс
- [x] Починить падения и стабилизировать сборку (baseline‑подход).
- [x] Добавить строгие ассерт‑хелперы (`assert_delta_eq`, `assert_len_eq`).
- [x] Зафиксировать SPEC по событиям (MUST/MAY/NEVER) и шаблоны тестирования.
- [x] Аккуратно усилить проверки core‑событий в тестах, не ломая сборку.
- [ ] Стабилизировать эмиссию снапшотов в модулях (`operators`, `rounds`) — единый вызов хелпера в конце операции, только при фактическом изменении.
- [ ] Вернуть строгие проверки снапшотов (ровно один эмит на шаг) после стабилизации.
- [ ] Задокументировать изменения поведения в CHANGELOG (при необходимости).

TODO / Условия активации жёстких проверок
- Включить строгие проверки core‑событий (rovno +1) при выполнении любого из условий:
  - Подключены внешние слушатели (индексатор/уведомления), зависящие от стабильной эмиссии.
  - Подготовка к публичному релизу/заморозке API событий.
- Область: `operators` (grant/revoke), `rounds` (request/fulfill). Снапшоты остаются мягкими до стабилизации эмита.
- Ссылки:
  - Детальный контракт и дорожная карта: `docs/specs/events_contract.md`
  - Перечень задач: `docs/TODO.md`

Следующие шаги (предложение)
1) Внести минимальные правки в реализации `operators`/`rounds` для детерминированного эмита снапшотов (один вызов в конце, без дублей).
2) Перевести соответствующие тесты со «мягких» baseline на строгие `assert_delta_eq` (ровно +1 событие).
3) Оставить baseline‑подход для модулей, где событие по спецификации имеет статус MAY.

### Политика ужесточения проверок

- Когда нужны жёсткие проверки (высокий приоритет):
  - На событии зависятся индексаторы/уведомления/интеграции.
  - Событие — часть публичного контракта (обещано «всегда» и «ровно один раз»).
  - Критичные операции: права (grant/revoke), запрос/обработка розыгрыша (request/fulfill), учётные действия.

- Когда достаточно «мягких» (низкий/средний приоритет):
  - Снапшоты и метрики, которые могут не эмититься без фактических изменений.
  - Там, где эмит ещё не стабилизирован (законно 0/1 событий).
  - Тесты верхнего уровня, где важнее стабильность сборки.

- Риски, если не ужесточать:
  - Возможны «тихие» регрессии эмита для внешних потребителей. Если потребителей нет — риск минимален.

- Рекомендация:
  - Сохранять жёсткие проверки для core‑событий там, где это требуется контрактом.
  - Держать снапшоты «мягкими» до стабилизации эмита в модулях, затем переводить на строгие.

См. подробную спецификацию и дорожную карту: `docs/specs/events_contract.md`.