# Supra Lottery Frontend

Интерфейс для Move-проекта Supra Lottery. Пока ждём whitelisting, используем мок-данные и даём возможность переключаться между режимами `mock` и `supra` (во втором читаем статус из FastAPI и подключаем StarKey-кошелёк).

## Стек
- React 19 + Vite 7 + TypeScript
- React Router, React Query, Zustand для состояния и работы с API
- Liquid glass UI (см. глобальные токены в `src/index.css` и стилевые модули в `src/components/layout`)
- Storybook 9 (Vite builder) для визуальных сценариев
- i18next + react-i18next (`src/i18n`), экспорт словарей в JSON и переключение языка через Zustand
- Vitest + Testing Library для unit-тестов
- Husky + lint-staged, ESLint (flat config), Prettier

## Установка
```bash
corepack enable  # если pnpm ещё не активирован
pnpm install
```

## Скрипты
- `pnpm run dev` — dev-сервер Vite (порт 5173)
- `pnpm run lint` — ESLint
- `pnpm run format` / `pnpm run format:check` — форматирование Prettier
- `pnpm run storybook` — Storybook (порт 6006)
- `pnpm run test` — Vitest (jsdom)
- `pnpm run build` / `pnpm run preview` — production-сборка и предпросмотр
- `pnpm run i18n:extract` — выгрузка словарей в `public/locales/<locale>/translation.json`

## Настройки окружения

Создайте `.env` на основе `.env.example` и задайте ключевые переменные:

```bash
cp .env.example .env
```

- `VITE_API_MODE` — режим API (`mock` или `supra`). По умолчанию приложение запускается с мок-данными.
- `VITE_SUPRA_API_BASE_URL` — адрес FastAPI-сервиса из директории `SupraLottery` (см. раздел HTTP API в README корневого проекта). Значение по умолчанию — `http://localhost:8000`.

## Подключение Supra StarKey

1. Установите расширение [Supra StarKey](https://chrome.google.com/webstore/detail/supra-starkey-wallet) и авторизуйтесь.
2. В настройках StarKey переключитесь на Supra Testnet и разблокируйте кошелёк перед запуском фронтенда.
3. В интерфейсе Supra Lottery активируйте режим `supra` (панель в шапке). После этого кнопка «Подключить» запросит `eth_requestAccounts` у StarKey.
4. После подключения в блоке «Кошелёк» появится адрес и chainId. Если расширение не найдено, UI подскажет установить или разблокировать его. Поддержка WalletConnect появится позже.

В режиме `supra` фронтенд обращается к эндпоинту `/status` для получения данных мониторинга (draw_scheduled, whitelisting, подписка dVRF, распределение казначейства). Формы фиксации client/consumer whitelist, конфигурации VRF, расчёта минимального баланса и обновления долей казначейства вызывают FastAPI-эндпоинты `/commands/record-client-whitelist`, `/commands/record-consumer-whitelist`, `/commands/configure-vrf-gas`, `/commands/configure-vrf-request`, `/commands/configure-treasury-distribution` и `/commands/set-minimum-balance`, оборачивающие Supra CLI. Остальные админские сценарии по-прежнему используют мок-реализации до появления безопасных RPC/CLI-обёрток.

Карточка «Команды Supra CLI» в админке обращается к `GET /commands` и показывает список доступных скриптов с описаниями и модулями — это помогает проверить, что FastAPI поднят и экспортирует все вспомогательные утилиты для Supra-режима.

## Структура
```
src/
+- api/                # client, mockClient, supraClient
+- app/providers/      # провайдеры React Query и т.д.
+- components/layout/  # ShellLayout, GlassCard
+- config/             # appConfig, режимы API
+- features/
   +- admin/           # формы конфигураций и whitelisting
   +- dashboard/
   +- chat/            # real-time чат, объявления
   +- progress/
   +- fairness/
   +- logs/
   +- tickets/
   +- wallet/
+- mocks/              # JSON-данные (lottery-status, tickets, events)
+- store/              # Zustand (uiStore)
+- App.tsx
+- main.tsx
```

- По умолчанию интерфейс стартует в режиме `mock` и подставляет данные из `src/mocks/*`. Переключение режима доступно в шапке (ShellLayout).
- В режиме `supra` используем `src/api/supraClient.ts` для HTTP-запросов к FastAPI и `src/features/wallet/walletSupra.ts` для управления StarKey-кошельком.
- Страница `/fairness` отображает VRF-журнал выбранной лотереи (снепшот раунда, события хаба и лимит событий), поддерживает фильтрацию по типу события и текстовый поиск как в mock-режиме, так и при подключении к Supra API.
- На дашборде добавлен чат сообщества с блоком объявлений: сообщения подгружаются из `/chat/messages`, подписка в Supra-режиме работает через WebSocket, а в mock-режиме используется локальный стор.
- Страница `/progress` показывает чек-листы и достижения аккаунта: данные подгружаются из FastAPI (`/progress/*`), можно отмечать задания выполненными, а макеты поддерживают мок-режим.
- Страница `/profile` позволяет менять никнейм, соцсети, NFT-аватар и JSON-настройки через эндпоинты `/accounts/*` в mock- и Supra-режимах.
- При появлении свежих ответов CLI обновим JSON-моки, сторисы и тесты.
- Конфигурация лежит в `.storybook/` (подключены провайдеры и Zustand).
- Для edge-кейсов используем аргументы `mockData` / `mockError`, чтобы быстро воспроизводить загрузку или ошибки.
- Unit-тесты расположены рядом с компонентами (`*.test.tsx`) и используют Testing Library.
- Для сброса Zustand-стора есть helper `resetUiStore`.
1. Дождаться whitelisting (runbook: `../SupraLottery/docs/testnet_runbook.md`).
2. Проверить работу FastAPI (`/status`) и StarKey в Supra-режиме на тестовой сети.
3. После открытия мутаций переключить mock-формы на реальные транзакции Supra.
- Основной README: `../README.md`
- Runbook с CLI-командами: `../SupraLottery/docs/testnet_runbook.md`
- Дополнительные заметки по интеграции: `docs/supra_integration.md`

- Пример event-driven подхода для StarKey (события кошелька, обработка состояния).
- Next.js-роуты для blind-box можно использовать как ориентир для интеграционного слоя (mock → реальный API).
- Tailwind-токены `rand.*` и уведомления (Sonner + Framer Motion) показывают, как быстро собрать «жидко-стеклянный» UX.
## Полезные ссылки
- Основной README: ../README.md
- Runbook с CLI-командами: ../SupraLottery/docs/testnet_runbook.md
- Доп. заметки по интеграции: docs/supra_integration.md

## Наблюдения по Crystara SDK
- Реализован event-driven подход для StarKey (события кошелька, обработка состояния).
- NextJS-роуты для blind-box можно взять как пример интеграционного слоя (mock → реальный API).
- Tailwind-токены (rand.*) и уведомления (Sonner + Framer Motion) помогают собрать «жидкое стекло» UX.



