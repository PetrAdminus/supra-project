# Supra Lottery Frontend

Интерфейс для Move-проекта Supra Lottery. Пока ждём whitelisting, используем мок-данные и даём возможность переключаться между режимами `mock` и `supra` (второй будет включён после интеграции).

## Стек
- React 19 + Vite 7 + TypeScript
- React Router, React Query, Zustand для состояния и работы с API
- Liquid glass UI (см. глобальные токены в `src/index.css` и стилевые модули в `src/components/layout`)
- Storybook 9 (Vite builder) для визуальных сценариев
- Собственный лёгкий i18n-слой (`src/i18n`) с переключением языка
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

## Структура
```
src/
+- api/                # client, mockClient, supraClient (заглушки)
+- app/providers/      # провайдеры React Query и т.д.
+- components/layout/  # ShellLayout, GlassCard
+- config/             # appConfig, режимы API
+- features/
   +- admin/           # формы конфигураций и whitelisting
   +- dashboard/
   +- logs/
   +- tickets/
   +- wallet/
+- mocks/              # JSON-данные (lottery-status, tickets, events)
+- store/              # Zustand (uiStore)
+- App.tsx
+- main.tsx
```

- По умолчанию интерфейс стартует в режиме `mock` и подставляет данные из `src/mocks/*`. Переключение режима доступно в шапке (ShellLayout).
- После получения whitelisting заменим реализации в `src/api/supraClient.ts` на реальные вызовы Supra CLI/REST.
- При появлении свежих ответов CLI обновим JSON-моки, сторисы и тесты.
- Конфигурация лежит в `.storybook/` (подключены провайдеры и Zustand).
- Для edge-кейсов используем аргументы `mockData` / `mockError`, чтобы быстро воспроизводить загрузку или ошибки.
- Unit-тесты расположены рядом с компонентами (`*.test.tsx`) и используют Testing Library.
- Для сброса Zustand-стора есть helper `resetUiStore`.
1. Дождаться whitelisting (runbook: `../SupraLottery/docs/testnet_runbook.md`).
2. Реализовать реальные функции в `src/api/supraClient.ts` (REST или CLI-обёртка).
3. Подключить настоящий кошелёк в `src/features/wallet/` вместо mock-логики.
4. Переключить UI на режим Supra testnet и пройти end-to-end сценарии.
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



