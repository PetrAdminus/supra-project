# Чек-лист релиза lottery_multi

> Документ применяется для релизов on-chain компонентов `lottery_multi` на тестовые и боевые окружения. Ответственные лица подписываются под каждой отметкой.

## 1. Подготовка (T-3 дня)
- [ ] Подтвердить, что все задачи этапов 3–5 закрыты в `docs/architecture/lottery_multi_readiness_review.md`.
- [ ] Проверить отсутствие незапланированных миграций в `docs/architecture/rfc_v1_implementation_notes.md`.
- [ ] Согласовать окно релиза с DevOps и поддержкой, зафиксировать в `incident_log.md` (CLI `supra/scripts/incident_log.sh --type "Релиз" ...`).
- [ ] Убедиться, что `automation::ensure_action` и runbook бота актуализированы; dry-run запланирован.
- [ ] Провести контрольное чтение `lottery_multi_views.schema.json` и примеров `lottery_multi_view_samples.json`.

## 2. Заморозка и сбор артефактов (T-1 день)
- [ ] Обновить `config_version` в `registry::config` и записать значение в журнал (`supra/scripts/incident_log.sh --type "Релиз" ...`).
- [ ] Создать git-тег `lottery_multi-release-<date>` и приложить его к релизной записи.
- [ ] Сформировать список миграций/скриптов (`supra/scripts/*.sh`) и подтвердить их выполнимость без CLI-ошибок (dry-run), включая `refund_control.sh` (`cancel`, `batch`, `progress`, `archive`).
- [ ] Прогнать `history_backfill.sh dry-run <summary>` для всех подготовленных сводок, сохранить hex/хэши в артефакты и приложить вывод утилиты `supra.tools.history_backfill_dry_run` к журналу миграции (`incident_log.sh --type "Dry-run" ...`).
- [ ] Зафиксировать контрольные хэши dual-write через `dual_write_control.sh status` и обновить журнал (`incident_log.sh --type "Инцидент" ...`).
- [ ] Проверить состояние прайс-фидов: `price_feed::get_price_view` по активным `asset_id`, отсутствие `clamp_active`/`fallback_active`, последнее событие `PriceFeedClampClearedEvent` зафиксировано в журнале (`incident_log.sh --type "Инцидент" ...`).
- [ ] Зафиксировать состояние AutomationBot через `./supra/scripts/automation_status.sh <config> list` и при необходимости `get <operator>`: подтвердить корректность `has_pending`, `pending_execute_after`, `failure_count`/`max_failures`; обновить заметку статусной страницы при отклонениях.
- [ ] Выгрузить список ролей через `roles::list_partner_caps` и `roles::list_premium_caps`, проверить остатки/expiry и задокументировать необходимые `cleanup_expired_admin`/`revoke_*` операции в `incident_log.md` (через `incident_log.sh`).
- [ ] Убедиться, что план коммуникаций на случай отмены лотерей актуален: обновить шаблоны уведомлений и контактные точки в [refund.md](refund.md) и согласовать с поддержкой.
- [ ] Проверить готовность фронтенд- и индексаторных команд.

## 3. Окно релиза (T0)
- [ ] Выполнить миграции (если есть) и обновления модулей Move.
- [ ] Запустить smoke-тесты: `aptos move test -p lottery_multi` (или эквивалент) и `pytest tests/test_view_schema_examples.py`.
- [ ] Включить обновлённые флаги feature-switch и подтвердить события `FeatureSwitchUpdated`.
- [ ] Мониторить `ArchiveDualWrite*`, `Automation*`, `Vrf*` события в реальном времени.
- [ ] Приостановить продажи при критических алертах, задокументировать действия.

## 4. Пост-релиз (T+1 день)
- [ ] Провести сверку агрегатов `Accounting` и `LotterySummary` по контрольным лотереям.
- [ ] Проверить `views::status_overview` и `views::list_automation_bots`, обновить [статусную страницу](status_page.md); при обнаружении `vrf_retry_blocked`/`payout_backlog`/`has_pending = true` дольше таймлока выполнить шаги из [monitoring.md](monitoring.md).
- [ ] Обновить `docs/handbook/contracts/lottery_multi.md` и runbook’и, если появились новые шаги.
- [ ] Подготовить публичную заметку в баг-баунти-программе при изменении угроз/поведения.
- [ ] Зафиксировать результаты smoke-тестов и мониторинга в `incident_log.md` (`incident_log.sh --type "Dry-run" ...`).
- [ ] Запустить ретроспективу с участием DevOps, продуктовой и поддержки.
- [ ] Обновить [post_release_support.md](post_release_support.md) (ежедневный и еженедельный план) и создать запись в [postmortems.md](postmortems.md) с итогами релиза.

## 5. Релизная запись
- Ссылка на PR: ____
- Хэш ревизии: ____
- Конфигурация `config_version`: ____
- Дата и время релиза: ____
- Ответственные: ____

## 6. Контрольный список отката
- [ ] Проверить доступность резервной версии пакетов.
- [ ] Подготовить скрипты `disable-mirror`, `clear-expected-hash` для dual-write.
- [ ] Задокументировать действия по откату в runbook и оповестить заинтересованных лиц.
