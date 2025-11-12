# Чек-лист релиза lottery_multi

> Документ применяется для релизов on-chain компонентов `lottery_multi` на тестовые и боевые окружения. Ответственные лица подписываются под каждой отметкой.

## 1. Подготовка (T-3 дня)
- [ ] Подтвердить, что все задачи этапов 3–5 закрыты в `docs/architecture/lottery_multi_readiness_review.md`.
- [ ] Проверить отсутствие незапланированных миграций в `docs/architecture/rfc_v1_implementation_notes.md`.
- [ ] Сверить актуальность программы баг-баунти: таблица наград и матрица охвата в [bug_bounty.md](bug_bounty.md) совпадают с согласованной версией Security.
- [ ] Согласовать окно релиза с DevOps и поддержкой, зафиксировать в `incident_log.md` (CLI `supra/scripts/incident_log.sh --type "Релиз" ...`).
- [ ] Убедиться, что `automation::ensure_action` и runbook бота актуализированы; dry-run запланирован.
- [ ] Провести контрольное чтение `lottery_multi_views.schema.json` и примеров `lottery_multi_view_samples.json`.

## 2. Заморозка и сбор артефактов (T-1 день)
- [ ] Обновить `config_version` в `registry::config` и записать значение в журнал (`supra/scripts/incident_log.sh --type "Релиз" ...`).
- [ ] Создать git-тег `lottery_multi-release-<date>` и приложить его к релизной записи.
- [ ] Сформировать список миграций/скриптов (`supra/scripts/*.sh`) и подтвердить их выполнимость без CLI-ошибок (dry-run), включая `refund_control.sh` (`cancel`, `batch`, `progress`, `archive`).
- [ ] Прогнать `history_backfill.sh dry-run <summary>` (с `--json --quiet --json-output <file>`) для всех подготовленных сводок, сохранить hex/хэши и JSON-артефакты и приложить их к журналу миграции (`incident_log.sh --type "Backfill" ...`).
- [ ] Зафиксировать контрольные хэши dual-write через `dual_write_control.sh status` и обновить журнал (`incident_log.sh --type "Инцидент" ...`).
- [ ] Проверить состояние прайс-фидов: `price_feed::get_price_view` по активным `asset_id`, отсутствие `clamp_active`/`fallback_active`, последнее событие `PriceFeedClampClearedEvent` зафиксировано в журнале (`incident_log.sh --type "Инцидент" ...`).
- [ ] Зафиксировать состояние AutomationBot через `./supra/scripts/automation_status.sh <config> list` и при необходимости `get <operator>`: подтвердить корректность `has_pending`, `pending_execute_after`, `failure_count`/`max_failures`; обновить заметку статусной страницы при отклонениях.
- [ ] Проверить, что для ботов с действиями `ACTION_UNPAUSE`/`ACTION_PAYOUT_BATCH`/`ACTION_CANCEL` таймлок ≥ 900 секунд (через `automation_status.sh` или дашборд `automation_timelock_breach = 0`); при нарушении обновить конфигурацию и задокументировать решение в журнале.
- [ ] Выгрузить список ролей через `roles::list_partner_caps` и `roles::list_premium_caps`, проверить остатки/expiry и задокументировать необходимые `cleanup_expired_admin`/`revoke_*` операции в `incident_log.md` (через `incident_log.sh`).
- [ ] Убедиться, что план коммуникаций на случай отмены лотерей актуален: обновить шаблоны уведомлений и контактные точки в [refund.md](refund.md) и согласовать с поддержкой.
- [ ] Проверить готовность фронтенд- и индексаторных команд.

## 3. Окно релиза (T0)
- [ ] Выполнить миграции (если есть) и обновления модулей Move.
- [ ] Запустить smoke-тесты: `./supra/scripts/run_move_tests.sh` (или `APTOS_BIN=<path> ./supra/scripts/run_move_tests.sh`) и `pytest tests/test_view_schema_examples.py`.
- [ ] Включить обновлённые флаги feature-switch и подтвердить события `FeatureSwitchUpdated`.
- [ ] Мониторить `ArchiveDualWrite*`, `Automation*`, `Vrf*` события в реальном времени.
- [ ] Приостановить продажи при критических алертах, задокументировать действия.

## 4. Пост-релиз (T+1 день)
- [ ] Провести сверку агрегатов `Accounting` и `LotterySummary` по контрольным лотереям с помощью `./supra/scripts/accounting_check.sh <config> compare <lottery_id>`; сохранить JSON-отчёт в `incident_log.md`.
- [ ] Проверить `views::status_overview` и `views::list_automation_bots`, обновить [статусную страницу](status_page.md); при обнаружении `vrf_retry_blocked`/`payout_backlog`/`refund_sla_breach`/`refund_batch_pending > 0` > 4ч/`has_pending = true` дольше таймлока выполнить шаги из [monitoring.md](monitoring.md).
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
