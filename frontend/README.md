# Supra Lottery Frontend

Интерфейс для Move-проекта Supra Lottery. Пока идёт ожидание whitelisting, работаем на моках и даём возможность быстро переключиться между режимами mock и supra (второй выключен до интеграции).

## Стек
- React 19 + Vite 7 + TypeScript
- React Router, React Query, Zustand для состояния и работы с API
- Liquid glass UI (см. src/index.css, src/App.css)
- Storybook 9 (Vite builder) для визуальных сценариев\n- Свой минимальный i18n-слой (src/i18n) с переключением языка\n- Vitest + Testing Library для unit-тестов
- Husky + lint-staged, ESLint (flat config), Prettier

## Установка
`ash
corepack enable     # если pnpm ещё не активирован
pnpm install
`

## Скрипты
- pnpm run dev — dev-сервер Vite (порт 5173)
- pnpm run lint — линтер ESLint
- pnpm run format / pnpm run format:check — форматирование Prettier
- pnpm run storybook — Storybook (порт 6006)
- pnpm run test — Vitest (jsdom)
- pnpm run build / pnpm run preview — production-сборка и предпросмотр

## Структура
`
src/
+- api/                # клиент, mockClient, supraClient (заглушки)
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
`

## Рабочий процесс\n- Тексты вынесены в src/i18n/messages.ts и доступны через хук useI18n; текущий дефолтный язык — u, переключение через шапку UI.\n- По умолчанию используем mock и подсовываем данные из src/mocks/*.
- Режим API переключается в шапке (ShellLayout). После получения whitelisting заменим функции в src/api/supraClient.ts на реальные вызовы Supra CLI/REST.
- Когда появятся свежие ответы CLI, обновим JSON моков и сторисы, чтобы Storybook и тесты соответствовали будущему поведению.

## Storybook
- Настройки в .storybook/ (подключены провайдеры и Zustand).
- Страницы (Pages/*) и компоненты (Tickets/*, Logs/*, Wallet/*) имеют сценарии с мок-данными.
- Для кейсов используем аргументы mockData/mockError; можно быстро воспроизводить состояния загрузки или ошибок.

## Тесты
- Unit-тесты лежат рядом с компонентами (*.test.tsx), используют Testing Library.
- Для очистки Zustand есть helper esetUiStore.

## Интеграция со StarKey / Supra
1. Дождаться whitelisting (runbook лежит в ../SupraLottery/docs/testnet_runbook.md).
2. Реализовать реальные функции в src/api/supraClient.ts (REST или CLI-обёртка).
3. Подключить настоящий кошелёк в src/features/wallet/ вместо mock-логики.
4. Переключить UI на режим Supra testnet и проверить end-to-end сценарии.

## Полезные ссылки
- Основной README: ../README.md
- Runbook с CLI-командами: ../SupraLottery/docs/testnet_runbook.md
- Доп. заметки по интеграции: docs/supra_integration.md

## Наблюдения по Crystara SDK
- Реализован event-driven подход для StarKey (события кошелька, обработка состояния).
- NextJS-роуты для blind-box можно взять как пример интеграционного слоя (mock → реальный API).
- Tailwind-токены (rand.*) и уведомления (Sonner + Framer Motion) помогают собрать «жидкое стекло» UX.



