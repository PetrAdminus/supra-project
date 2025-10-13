# Внутренний чек-лист аудита SupraLottery

Документ помогает пройти этап G1 плана выравнивания: внутреннюю проверку контрактов, тестов и документации SupraLottery перед
передачей результатов внешним аудиторам Supra. Чек-лист составлен на основе официальных требований Supra Move/dVRF и артефактов
репозитория (runbook, планы миграции, отчёты мониторинга).

## Метаданные ревью
- **Дата прогона**: 2025-02-14
- **Исполнитель**: команда SupraLottery (внутренний аудит)
- **Артефакты**: `docs/supra_alignment_status.md`, отчёты Move-тестов (в процессе), ссылки для передачи Supra (см. `external_handover_summary.md`).

## 1. Подготовка окружения
- [x] Обновить git-репозиторий и убедиться, что рабочее дерево чистое (`git status`).
- [x] Синхронизировать git-зависимости Move (`PYTHONPATH=SupraLottery python -m supra.scripts.move_tests --workspace SupraLottery/supra/move_workspace --mode check --dry-run --cli-flavour supra`). 14.02 выполнен `--all-packages --dry-run --cli-flavour supra`, сформирован шаблон отчёта (см. `docs/audit/move_test_reports/2025-02-14-move-test-dry-run.json`).
- [ ] Проверить наличие Supra CLI или Aptos CLI в PATH либо подготовить Docker-контейнер `supra_cli` (dry-run задействовал fallback `--cli-flavour supra`, требуется фактический бинарь для запуска тестов). См. инструкции в `internal_audit_dynamic_runbook.md`, раздел 1.
- [ ] Обновить `.env`/YAML-профиль Supra CLI актуальными адресами и ключами перед ручными проверками (подробнее — `internal_audit_dynamic_runbook.md`, шаг 1.4).

## 2. Контракты и конфигурация Move
- [x] Подтвердить, что `SupraLottery/supra/move_workspace/Move.toml` использует `resolver = "v2"` и git-зависимость `move-stdlib` из `Entropy-Foundation/aptos-core`.
- [x] Проверить `SupraVrf/Move.toml` и другие пакеты на использование именованного адреса `supra_addr` без жёстко прошитых hex-значений.
- [x] Сверить события и структуры `lottery`, `vrf_hub`, `lottery_factory` со снимком `docs/dvrf_reference_snapshot.md` (наличие `payload_hash`, `CallbackRequest`, `WhitelistSnapshotUpdatedEvent`) — см. `internal_audit_static_review.md`, раздел 1.
- [x] Убедиться, что `treasury_v1` и `treasury_multi` используют `supra_framework::fungible_asset` и публикуют агрегированные снапшоты получателей — см. `internal_audit_static_review.md`, раздел 2.
- [x] Проверить наличие view-функций и событий в вспомогательных модулях (`Metadata`, `Referrals`, `Vip`, `Autopurchase`, `Store`, `History`, `Jackpot`, `LotteryRounds`, `LotteryInstances`) — см. `internal_audit_static_review.md`, раздел 3.

## 3. Тестирование
- [ ] Прогнать юнит-тесты Move для всех пакетов: `PYTHONPATH=SupraLottery python -m supra.scripts.move_tests --workspace SupraLottery/supra/move_workspace --all-packages --mode test --keep-going --report-json tmp/move-test-report.json --report-junit tmp/move-test-report.xml --log-path tmp/unittest.log -- --skip-fetch-latest-git-deps`. 14.02 выполнен промежуточный `--dry-run --cli-flavour supra`, отчёт сохранён в `docs/audit/move_test_reports/2025-02-14-move-test-dry-run.json`/`...xml`; запуск с реальной CLI остаётся в плане (см. `internal_audit_dynamic_runbook.md`, раздел 2).
- [ ] Зафиксировать артефакты `tmp/move-test-report.json`, `tmp/move-test-report.xml` и `tmp/unittest.log` в CI или загрузить для ревью (для dry-run приложена версионированная копия в `docs/audit/move_test_reports/`; порядок публикации описан в `internal_audit_dynamic_runbook.md`, шаг 2.3).
- [ ] Выполнить Python-юнит-тесты: `python -m unittest` (при наличии известных падений задокументировать исключения в отчёте; см. `internal_audit_dynamic_runbook.md`, раздел 3).
- [ ] При необходимости выполнить смоук-тест testnet: `supra/scripts/testnet_smoke_test.sh` или ручной сценарий из runbook (фиксировать tx hash и результаты; подробности — `internal_audit_dynamic_runbook.md`, раздел 4).

## 4. Документация и операционные регламенты
- [x] Просмотреть `docs/testnet_runbook.md` и `docs/testnet_deployment_checklist.md`, актуализировать адреса, лимиты газа и последовательность команд.
- [ ] Сверить `docs/dvrf_monitoring_automation.md`, `supra/scripts/testnet_monitor_json.py` и Slack/Prometheus-скрипты с фактическими требованиями мониторинга (см. финальный блок `internal_audit_dynamic_runbook.md`).
- [ ] Обновить `docs/module_inventory.md` ссылками на официальные источники или отметить ожидание доступа (пометка о необходимости сохранить артефакты после смоук-теста — см. `internal_audit_dynamic_runbook.md`, раздел 5).
- [x] Проверить наличие ссылок на новый чек-лист в README и runbook (раздел «Дополнительные справочники и чек-листы»).

## 5. Соответствие аудиту Supra
- [x] Сопоставить выводы существующих отчётов в `docs/audit/*.md` с текущим кодом (актуальность статусов, отсутствие устаревших замечаний) — статическая проверка зафиксирована в `internal_audit_static_review.md`.
- [x] Обновить `docs/supra_alignment_plan.md` и `docs/supra_alignment_status.md` актуальным прогрессом по этапам A–G.
- [x] Зафиксировать оставшиеся вопросы и риски в `docs/alignment_gaps.md`, указав ответственных и следующие шаги — добавлен пункт «Внутренний аудит G1» с пометкой о динамических тестах.
- [x] Подготовить summary для внешней стороны Supra (короткий обзор статуса, ссылки на отчёты и тестовые артефакты) — обновлён `external_handover_summary.md` с ссылкой на статический обзор.

## 6. Финализация
- [x] Собрать результаты в `docs/supra_alignment_status.md` (таблица статусов этапов, ключевые достижения, открытые задачи) — добавлен прогресс статической проверки.
- [x] Проверить, что все изменения закоммичены в ветку `Test` и задокументированы в PR с ссылкой на релевантные артефакты.
- [ ] Создать напоминание о повторении аудита перед каждым релизом или значительным изменением dVRF/казначейства (рекомендованный тайминг — `internal_audit_dynamic_runbook.md`, раздел 6).

## Примечания к текущему прогрессу
- Статические проверки конфигурации Move и операционной документации завершены.
- Динамические шаги (прогон тестов, смоук-тест сети, сверка мониторинга и обновление gap-реестра) остаются запланированными в рамках этапа G1.
- После получения артефактов тестов и смоук-прогона необходимо дополнить разделы 3–6 и приложить ссылки в `external_handover_summary.md`.

> После прохождения чек-листа обновите дату и исполнителя в итоговом отчёте, приложите ссылки на лог тестов, tx hash'и смоук-теста и сопроводительное письмо для Supra Labs.
