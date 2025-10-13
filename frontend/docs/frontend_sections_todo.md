
# TODO по вёрстке блоков/секций

Список функций (React-компонентов), которые нужно сверстать или серьёзно переработать под новый дизайн. Для каждой позиции указано актуальное расположение файла или комментарий, если файла пока нет.

## Разделы из плана ElyxS

- `FairnessPage` *(ожидается в `frontend/src/components/pages/FairnessPage.tsx`)* — требуется новая страница «Журнал VRF» (таблица заявок/исполнений, фильтры, поиск). Сейчас есть только legacy-версия в `frontend/src/legacy/features/fairness/pages/FairnessPage.tsx`.
- `LogsPage` *(ещё не создана)* — страница событий лотереи согласно плану (`New Design/src/...`). Нужен отдельный компонент с таблицей логов и переключателем ошибок.
- `AdminPage` *(frontend/src/components/pages/AdminPage.tsx — отсутствует)* — нужно сверстать конфигурационные формы (VRF, gas, whitelist, treasury) и блок запуска Supra-команд. Legacy-вариант находится в `frontend/src/legacy/features/admin/pages/AdminPage.tsx`.
- `ProgressPage` *(frontend/src/components/pages/ProgressPage.tsx — отсутствует)* — требуется чек-лист прогресса c достижениями/мутациями. Есть legacy-страница в `frontend/src/legacy/features/progress/pages/ProgressPage.tsx`.

## Dashboard / внутренняя навигация

- `DashboardPage` (`frontend/src/components/pages/DashboardPage.tsx`) — текущий сайдбар и контент работают, но осталось предусмотреть дополнительные секции (Fairness, Logs, Admin, Progress). После появления страниц нужно добавить соответствующие пункты в меню и маршруты.
- `WalletContent` (`frontend/src/components/pages/dashboard/WalletContent.tsx`) — удерживаем чат и блоки аккаунта, но запланированы дополнительные состояния (skeleton, error) и карточки активности кошелька.
- `TicketsContent` (`frontend/src/components/pages/dashboard/TicketsContent.tsx`) — требуется адаптировать гриды под новый фильтр/сводку, добавить пустые состояния по гайдам (skeleton, бейджи).
- `DrawsContent` (`frontend/src/components/pages/dashboard/DrawsContent.tsx`) — нужен блок таймера/статистики, карточки победителей и CTA по макету `New Design` (сейчас базовая сетка без подсветок).
- `HistoryContent` (`frontend/src/components/pages/dashboard/HistoryContent.tsx`) — добавить сегментацию по типам транзакций и состояние “error/empty” с графическими placeholder’ами.

## Глобальные компоненты

- `ShellLayout` (планируется в `frontend/src/components/layout/ShellLayout.tsx`) — нужно восстановить функциональность legacy-обёртки (`frontend/src/legacy/components/layout/ShellLayout.tsx`): переключение mock/supra, роли user/admin, выбор локали и подключение `WalletPanel`.
- `Footer` (`frontend/src/components/Footer.tsx`) — требуется блок навигации “Docs/Blog/Brand assets” и аккордеон FAQ, как в новом дизайне (сейчас только базовый набор ссылок).

> При добавлении новых секций обязательно сверяться с `docs/frontend_new_design_plan.md` и гайдом `New Design/src/guidelines/DesignSystem.md`.
