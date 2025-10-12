# Supra Lottery / Супра Лотерея

## Русский

### Обзор
Supra Lottery — пакет смарт-контрактов на Move для блокчейна Supra. Он реализует лотерею с ончейн-интеграцией Supra dVRF 3.0, whitelisting агрегатора и потребителей, а также защитой колбэка по требованиям Supra; в репозитории находятся основной модуль, тестовая батарея и Docker-инфраструктура для оффлайн-работы с Supra CLI.

#### Ключевые особенности
- Лотерейный контракт на Move, ориентированный на тестовую сеть блокчейна Supra.
- Интеграция с примитивами Supra dVRF v3 (`supra_vrf`, `deposit`) и хранение хэшей payload для VRF-запросов.
- Модуль `treasury_v1` делит оплату билетов между джекпотом, текущим призовым фондом, казной и маркетинговыми ваултами на основе базисных пунктов, предоставляет view-функции и административные настройки.
- В Move-воркспейсе присутствуют заготовки модулей `vrf_hub::hub` и `lottery_factory::registry`, формирующие основу VRF-хаба и фабрики мульти-лотерей.
- Репозиторий содержит Docker-окружение, профили Supra CLI, юнит-тесты, фронтенд на Storybook/Vitest, эксплуатационную документацию и runbook’и.

### Технологический стек
- Язык Move под Supra VM
- Клиент Supra dVRF v3 (модули `supra_vrf`, `deposit` и интеграция `lottery::main_v2`)
- Fungible Asset-токен, развёрнутый через обёртку `lottery::treasury_v1`
- Среда Supra CLI в Docker (`docker-compose.yml`)
- Расширенные Move-юнит-тесты, покрывающие whitelisting, обработку VRF и негативные сценарии (`supra/move_workspace/lottery/tests`)

### Быстрый старт
1. Запустите Docker Desktop (или совместимый рантайм).
2. Клонируйте репозиторий и перейдите в корень проекта: `cd SupraLottery`.
3. Работайте из ветки `main`; фича-потоки создавайте в отдельных ветках и оформляйте merge request’ы в `main`.
4. При необходимости откройте shell внутри контейнера Supra CLI: `docker compose run --rm --entrypoint bash supra_cli`.
5. Все команды Supra CLI и вспомогательные скрипты запускайте внутри `script -q`, чтобы сохранять логи (см. `docs/testnet_runbook.md`).

> Ключи и параметры из `supra/configs` предназначены только для локальной разработки. Перед публикацией замените их собственными значениями.

### Запуск Move-тестов
```bash
docker compose run --rm \
  --entrypoint bash supra_cli \
  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
```
Команда собирает пакет и прогоняет полный набор Move-юнит-тестов (позитивные и негативные сценарии VRF, whitelisting, переполнения счётчиков) внутри контейнера. Удобно оборачивать запуск в `script -q` для фиксации журналов.

### Структура проекта
- `docker-compose.yml` — описание контейнера Supra CLI.
- `supra/configs/` — локальные конфиги Supra с ключами и историей (только для разработки).
- `supra/move_workspace/lottery/Move.toml` — манифест Move-пакета.
- `supra/move_workspace/lottery/sources/` — контракт лотереи (`Lottery.move`) и FA-казначейство (`Treasury.move`).
- `supra/move_workspace/lottery/tests/` — Move-тесты, покрывающие события, поток VRF и админские сценарии.
- `supra/move_workspace/vrf_hub/` — заготовка VRF-хаба для маршрутизации запросов случайности между дочерними лотереями.
- `supra/move_workspace/lottery_factory/` — фабрика для выдачи идентификаторов и описаний лотерей.
- `supra/scripts/` — вспомогательные скрипты (build/publish/migration), включая CLI-команду `vrf-audit`.
- `docs/` — runbook’и, миграционные заметки по dVRF и эксплуатационная документация.
- `frontend/` — SPA, мок-данные, Storybook-истории и юнит-тесты.

### Казначейство на Fungible Asset
Модуль `lottery::treasury_v1` оборачивает стандарт `0x1::fungible_asset` и предоставляет следующие сценарии:

1. **Инициализация токена** — `treasury_v1::init_token` создаёт Metadata-объект, включает primary store и сохраняет mint/burn/transfer capability на адресе лотереи.
2. **Регистрация хранилищ** — `treasury_v1::register_store` позволяет пользователям завести primary store, `register_store_for` даёт администратору возможность подготовить store для любого адреса, а `register_stores_for` регистрирует несколько адресов за один вызов.
3. **Минт/бёрн/трансфер** — функции `mint_to`, `burn_from`, `transfer_between` используют capability-ресурсы казначейства и требуют предварительно зарегистрированного store у всех участников.
4. **Заморозка store** — `treasury_v1::set_store_frozen` позволяет администратору временно заблокировать вывод и депозиты конкретного primary store (например, при разборе инцидентов). Повторный вызов с `false` снимает блокировку.
5. **Назначение получателей** — перед вызовом `set_recipients` администратор обязан зарегистрировать primary store на каждом целевом адресе (`register_store_for`/`register_stores_for`), иначе функция завершится `E_RECIPIENT_STORE_NOT_REGISTERED`; это соответствует требованиям Supra FA о переводах только между зарегистрированными store.
6. **Управление конфигурацией распределения** — `treasury_v1::set_config` обновляет доли (basis points) между джекпотом, призовым пулом и операционными направлениями, а `ConfigUpdatedEvent` фиксирует изменения; `get_config` предоставляет актуальные значения для фронтенда и скриптов.
7. **Интеграция с лотереей** — `treasury_v1::deposit_from_user` списывает токены при покупке билета, а `payout_from_treasury` (пакетная функция, доступная всем модулям `lottery`) распределяет джекпот из казначейства; обе операции проверяют наличие store у плательщика и получателя.

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
- Чек-лист миграции dVRF v3: `docs/dVRF_v3_checklist.md`
- Снапшот интеграции dVRF v2: `docs/dVRF_v2_snapshot.md`
- Поддержка Supra: `techsupport@supra.com`

## Дополнительная информация по SupraLottery

### План трансформации
- Дорожная карта мульти-лотерей и VRF-хаба зафиксирована в [docs/project_plan.md](docs/project_plan.md). Документ выступает источником правды: актуализируйте его при любых изменениях договорённостей с владельцем продукта.

### Текущее состояние (сентябрь 2025)
- Move-пакет успешно компилируется, юнит-тесты проходят внутри контейнера Supra CLI.
- Аккаунт тестовой сети `0x9a969d3b77941cec267f03b9bbb323c0333fa63d0e9e15204edabc415f134490` **ещё не добавлен в whitelist**; функции `deposit::*` возвращают `EUNAUTHORIZED_ACCESS`.
- Команды мониторинга (`get_lottery_status`, `get_whitelist_status`, `get_vrf_request_config`, `get_registered_tickets`, `treasury_v1::get_config`, `treasury_v1::get_balances`) доступны через `supra move tool view`.
- Фронтенд (`frontend/`) запускается с мок-данными, содержит заглушку кошелька StarKey и переключатель между mock/Supra API; после получения whitelisting обновляем `src/api/supraClient.ts`.

### Move 1: правила и тесты
- Соблюдайте соглашения Move 1: не используйте `let mut`, оставляйте только ASCII-комментарии, инициализируйте события через модуль `events` соответствующего пакета (`lottery::events::new_handle`, `lottery_factory::events::new_handle`, `vrf_hub::events::new_handle`), подключайте стандартную библиотеку через алиас `std`.
- Для точечного прогона пакета выполните `python -m supra.scripts.cli move-test --package lottery` — скрипт по умолчанию работает в `SupraLottery/supra/move_workspace`, показывает список пакетов через `--list-packages` и поддерживает прогон всех пакетов через `--all-packages`.
- Если Supra CLI недоступна, утилита автоматически переключится на `aptos move test` или «ванильный» `move test`, сохранив выбор пакета (`--package-dir` или `--package` в зависимости от CLI) для запуска внутри общего воркспейса.
- Для статической проверки без запуска тестов используйте `--mode check`, например: `python -m supra.scripts.cli move-test --package lottery --mode check`.

#### Настройка адресов для локальных прогонов
- Для единичного запуска можно переопределить адреса прямо в команде: `python -m supra.scripts.cli move-test --package lottery -- --override-addresses lottery=0x1ee ...`.
- Если тесты выполняются регулярно, создайте файл `.move/config` в корне workspace с секцией `[addresses]` и пропишите значения (`lottery = "0x1ee"`, `supra_addr = "0x42"`). Скрипт `move-test` передаст файл всем flavour CLI автоматически.
- При работе в Docker-контейнере адреса из `.move/config` доступны как для `supra move tool`, так и для запасных `aptos move`/`move`, что избавляет от ручного редактирования `Move.toml` перед каждым прогоном.

### Профили Supra CLI, тестнет и мейннет
- `supra/configs/testnet.yaml` и `supra/.aptos/config.yaml` описывают профиль лотереи (`lottery_v3`) в тестовой сети — используем его для разработки и интеграционных проверок.
- Для ручного whitelisting на тестнете отправьте письмо на `techsupport@supra.com` с темой «Request for Manual Whitelisting on Testnet», указав адрес из раздела выше.
- Перед релизом подготовьте отдельный профиль Supra CLI для мейннета (например, `supra/configs/mainnet.yaml`) и продублируйте runbook whitelisting/деплоя с боевыми ключами. В документации фиксируйте версии пакетов и параметры газа для обеих сетей.
- До подтверждения Supra пропускайте вызовы `deposit::*` и `request_draw`; сосредотачивайтесь на разделах 2–3 runbook’а и фронтенд-моках.
- После появления мейннет-профиля убедитесь, что переменные окружения (`SUPRA_PROFILE`, `SUPRA_NETWORK`, `VRF_HUB_ADDRESS` и др.) настроены и для `testnet`, и для `mainnet`.

### Фронтенд (mock-first)
- Расположение: `frontend/` — команды запуска смотрите в `frontend/README.md` (`pnpm run dev`, `pnpm run storybook`, `pnpm run test`).
- Стек: React 19, Vite, React Query, Zustand, Storybook 9, Vitest, Prettier/Husky.
- Мок-данные лежат в `frontend/src/mocks/{lottery-status-*,tickets-*,events-*}.json`.
- `frontend/src/api/client.ts` переключается между mock и Supra реализациями по `VITE_API_MODE` или селектору в UI; реальные интеграции живут в `frontend/src/api/supraClient.ts`.
- Клиент Supra API агрегирует `/status` VRF-хаба в список лотерей и повторно использует тот же формат, что и mock-режим; типы `LotteryStatus` поддерживают коллекцию экземпляров, данные казначейства и статус VRF.
- Локализация построена на `i18next + react-i18next`, словари хранятся в `frontend/src/i18n/messages.ts`, а скрипт `pnpm run i18n:extract` выгружает JSON в `frontend/public/locales/*`.
- Заглушка кошелька (`frontend/src/features/wallet/`) эмулирует StarKey; заменим её на SDK после подтверждения Supra.

### Дополнительные директории и скрипты
- `supra/move_workspace/Move.toml` объединяет пакеты `lottery`, `vrf_hub` и `lottery_factory`.
- `supra/scripts/` содержит сценарии build/publish/migration; CLI-команда `python -m supra.scripts.cli vrf-audit --lottery-id <ID>` собирает события VRF для панели честности, а FastAPI-служба отдаёт агрегированный лог по маршруту `/lotteries/{id}/vrf-log`.

### После получения whitelisting
1. Следуйте разделу 4 `docs/testnet_runbook.md`, чтобы завершить dVRF-флоу и опубликовать пакет.
2. Зафиксируйте хэши транзакций и сохраните их в документации для аудита.
3. Замените стабы в `frontend/src/api/supraClient.ts` на адаптеры Supra REST/CLI (или бэкенд-прокси).
4. Переключите фронтенд в режим Supra и проверьте end-to-end сценарии (покупка билетов, админский VRF, логи).
5. Обновите мок-файлы актуальными данными, чтобы Storybook/Vitest оставались репрезентативными.

### Следующие шаги
- Отслеживать прогресс whitelisting вместе с командой Supra.
- Поддерживать `frontend/README.md` и Storybook-сценарии в актуальном состоянии по мере поступления данных CLI.
- Использовать `supra/scripts/testnet_migration.sh` для автоматизации деплоя, когда появятся разрешения.
- Подключить Supra API-клиент после whitelisting (покупка билетов, казначейство, админские флоу).
- Синхронизировать Storybook-моки с реальными балансами казначейства после появления данных в сети.

### Наблюдения по опыту Crystara SDK
- SDK оборачивает blind box через NextJS API-роуты (`/api/batch-metadata`, `/api/lootbox`, `/api/lootbox-info`, `/api/metadata`, `/api/whitelist-amount`).
- Tailwind-токены (`rand.primary/secondary/accent/dark/light`) и компоненты `BlindBoxPage` помогают собрать интерфейс «жидкого стекла».
- Интеграция со StarKey построена на событиях (`walletEvents.on(WALLET_EVENTS.TRANSACTION_START)`), что демонстрирует event-driven подход.
- Используются переменные окружения `NEXT_PUBLIC_SUPRA_RPC_URL` и `NEXT_PUBLIC_SUPRA_CHAIN_ID` (8/6) плюс закрытые API-роуты Crystara.
- Для UX применяются Sonner и Framer Motion — можно взять как ориентир при работе с Supra.
