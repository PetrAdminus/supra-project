# Фронтенд и API

## Раздел «История»
- Источник списка — `views::list_active`, `views::list_by_primary_type`, `views::list_by_tag_mask` и `views::list_by_all_tags`.
- Для архивов используются `views::list_finalized_ids`, `views::get_lottery_summary` и `views::accounting_snapshot`.
- Детальный просмотр подтягивает `views::get_lottery`, `views::get_lottery_status`, `views::get_lottery_badges` и `views::get_badge_metadata`.
- Пагинация выполняется по `(from, limit)` с сортировкой `id desc`, во фронте нужно хранить курсор.

## Панели
- **Админский конструктор** — вызывает `views::validate_config` и отображает список нарушений.
- **Партнёрский мастер** — показывает квоты capability (`allowed_primary_types`, `allowed_tags_mask`) в реальном времени, скрывает недоступные поля.
- **Премиальный кабинет** — доступен адресам с `PremiumAccessCap`.
- **Инфраструктурная панель** — использует `views::get_vrf_deposit_status` для отображения баланса и статуса паузы VRF.

## Live Dashboard
- Хук `features/dashboard/hooks/useLotteryMultiViews` оборачивает `fetchLotteryMultiViews` из клиентского API и опрашивает `/lottery-multi/views` каждые 30 секунд (React Query, ключ `['lottery','multi','views']`).
- Компонент `components/Dashboard.tsx` заменяет статические карточки данными `status_overview`: активные розыгрыши, блокировки VRF retry и очередь выплат, а также выводит таблицы жизненного цикла и операционного бэклога.
- Заголовок блока отображает `info.version` и `info.updatedAt`, чтобы операторы видели актуальность данных и могли сопоставлять их со статусной страницей.

## i18n и a11y
- Все строки хранятся в `frontend/src/i18n`. Изменения синхронизируются с русскоязычной «книгой проекта».
- Интерфейс должен поддерживать контраст, управление клавиатурой и live-region для статусов VRF/выплат. Детализированные требования и тесты — в [a11y.md](a11y.md).

## API и интеграции
- Публичный REST/GraphQL слой запланирован на отдельный этап (см. roadmap). До релиза используется только on-chain view.
- Подписки на события реализует индексатор; внешние клиенты читают `event_category` и `tags_mask` для фильтрации.
- Фронтенд-клиент `supraClient.fetchLotteryMultiViewsSupra` обращается к `/lottery-multi/views`, преобразует `status_overview` в camelCase и обеспечивает единый источник данных для статусной страницы и внутренних панелей.

## Supra CLI
- Для локальных прогонов используйте `SupraLottery/supra/scripts/build_lottery_packages.sh` и профили testnet/mainnet.
- Состояние CLI фиксируется в `docs/architecture/rfc_v1_implementation_notes.md`.
