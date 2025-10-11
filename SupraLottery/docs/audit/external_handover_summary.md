# SupraLottery — сводка для передачи Supra

Документ служит сопроводительным письмом при передаче результатов внутреннего аудита команде Supra. Он фиксирует готовность кодовой базы, статус тестов, операционные регламенты и outstanding-задачи, требующие внимания перед внешним ревью.

## 1. Обзор
- **Ответственная команда:** SupraLottery
- **Контакты для связи:** infra@supra-lottery.example (обновить при формировании фактической рассылки)
- **Цель передачи:** подтверждение выполнения этапов A–F плана выравнивания и консолидация шага G1 (внутренний аудит).

## 2. Готовность кодовой базы
- Move workspace использует `resolver = "v2"` и git-зависимость `SupraFramework`/`move-stdlib` из официального репозитория `Entropy-Foundation/aptos-core`.
- Пакет `SupraVrf` и зависимые модули работают через именованный адрес `supra_addr`; жёсткие hex-значения удалены.
- dVRF-события и снапшоты whitelisting соответствуют эталону `docs/dvrf_reference_snapshot.md`, обеспечивая прозрачность для операторов Supra.
- Казначейство (`treasury_v1`, `treasury_multi`) использует `supra_framework::fungible_asset`, публикует снапшоты и защищает операции от использования незарегистрированных или замороженных адресов.
- Документация (README, runbook, чек-листы деплоя и аудита) ссылается на актуальные скрипты CLI и регламенты Supra.
- Статическая проверка модулей (`docs/audit/internal_audit_static_review.md`) подтвердила корректность событий и snapshot-view перед запуском динамических тестов этапа G1.

## 3. Статус тестирования
- `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages --keep-going --report-json tmp/move-test-report.json --report-junit tmp/move-test-report.xml -- --skip-fetch-latest-git-deps` — **в процессе**: 14.02 выполнен `--dry-run --cli-flavour supra`, шаблон отчёта приложен в `docs/audit/move_test_reports/2025-02-14-move-test-dry-run.json`/`...xml`; запуск с фактической Supra CLI остаётся обязательным перед передачей.
- `python -m unittest` — **запланировано** (при наличии известных падений будет приложено объяснение в отчёте).
- Смоук-тест testnet (скрипт `supra/scripts/testnet_smoke_test.sh`) — **запланировано**; результаты с tx hash будут внесены по завершении.
- После прогона все артефакты тестов прикладываются в `tmp/` и фиксируются ссылками в этом документе.

## 4. Операционные материалы
- Чек-лист деплоя testnet: `docs/testnet_deployment_checklist.md` — содержит prerequisites, параметры dVRF, последовательность CLI-команд и смоук-проверку.
- Runbook: `docs/testnet_runbook.md` — описывает подготовку окружения, регистрацию подписки и наблюдение за событиями.
- Мониторинг dVRF: `docs/dvrf_monitoring_automation.md` и скрипты в `supra/scripts` — требуют финальной сверки с актуальными требованиями Supra (см. раздел 5).
- Динамический runbook аудита: `docs/audit/internal_audit_dynamic_runbook.md` — описывает запуск Supra CLI, сбор JSON/JUnit, `python -m unittest` и смоук-тест testnet.
- Внутренний аудит: `docs/audit/internal_audit_checklist.md` — отмечены завершённые и оставшиеся шаги этапа G1.

## 5. Outstanding-задачи перед внешним ревью
- Завершить динамические проверки: Move-тесты, Python-юнит-тесты, смоук-тест testnet (шаги детализированы в `docs/audit/internal_audit_dynamic_runbook.md`).
- Сверить мониторинговые скрипты и документацию с текущими требованиями Supra и обновить `docs/dvrf_monitoring_automation.md` при необходимости.
- Дополнить `docs/module_inventory.md` ссылками на официальные источники Supra после получения доступа.
- Обновить `docs/alignment_gaps.md` оставшимися вопросами и ответственными.
- Подготовить каналы связи для оперативной обратной связи (email/Slack) и подтвердить состав участников внешнего ревью.

## 6. Приложения и ссылки
- План выравнивания: `docs/supra_alignment_plan.md`
- Таблица статусов этапов: `docs/supra_alignment_status.md`
- Внутренний чек-лист и отметки прогресса: `docs/audit/internal_audit_checklist.md`
- Итоговые отчёты тестов: будут добавлены после выполнения раздела 3 (см. TODO в `tmp/` каталоге)
- Gap-реестр: `docs/alignment_gaps.md`

> После закрытия outstanding-задач обновите разделы 3 и 6, приложите ссылки на артефакты тестов и смоук-прогонов и отправьте документ вместе с сопроводительным письмом Supra Labs.
