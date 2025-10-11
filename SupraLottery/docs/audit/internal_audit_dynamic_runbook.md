# Внутренний аудит G1 — сценарий динамических проверок

Этот документ описывает практические шаги для завершения динамических пунктов чек-листа G1:
прогон Move-тестов с фактической Supra CLI, запуск `python -m unittest`, сбор артефактов и смоук-тест testnet.
Он расширяет `docs/audit/internal_audit_checklist.md`, где зафиксированы статические проверки и outstanding-задачи.

## 1. Подготовка окружения Supra CLI
1. Установите бинарь Supra CLI или соберите Docker-образ с предустановленной CLI. Рекомендуемый вариант —
   использовать официальный образ `supraoracles/supra-cli:latest`:
   ```bash
   docker pull supraoracles/supra-cli:latest
   docker run --rm -it \
     -v "$PWD":/workspace \
     -w /workspace/supra-project \
     supraoracles/supra-cli:latest bash
   ```
2. Убедитесь, что в PATH доступна одна из CLI: `supra`, `aptos` или `move`. Для динамического прогона Move-тестов 
   потребуется именно `supra` (адаптированный Move CLI от Supra). Проверить наличие можно командой:
   ```bash
   which supra || supra --version
   ```
3. Перед запуском тестов обновите git-зависимости Move:
   ```bash
   PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test \
     --workspace SupraLottery/supra/move_workspace \
     --list-packages -- --fetch-latest-git-deps
   ```
4. Подготовьте `.env` или YAML-профиль Supra CLI с адресами и ключами, которые используются в runbook и смоук-тестах.
   Проверьте, что значения `supra_addr`, `lottery_admin`, `vrf_hub_admin` и подписка dVRF соответствуют актуальной сети.

## 2. Прогон Move-тестов
1. Запустите последовательный прогон всех пакетов с генерацией JSON и JUnit:
   ```bash
   PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test \
     --workspace SupraLottery/supra/move_workspace \
     --all-packages --keep-going \
     --report-json tmp/move-test-report.json \
     --report-junit tmp/move-test-report.xml \
     -- --skip-fetch-latest-git-deps
   ```
2. Убедитесь, что Supra CLI действительно выполняет тесты (в логах команды отображаются команды `supra move test`).
   Скрипт завершится кодом 0, если все пакеты прошли, либо вернёт код первого упавшего пакета при `--keep-going`.
3. Скопируйте полученные артефакты в `docs/audit/move_test_reports/` с датой запуска, например:
   ```bash
   cp tmp/move-test-report.json docs/audit/move_test_reports/2025-02-28-move-test.json
   cp tmp/move-test-report.xml  docs/audit/move_test_reports/2025-02-28-move-test.xml
   ```
4. Обновите разделы «Тестирование» в `docs/audit/internal_audit_checklist.md` и `docs/audit/external_handover_summary.md`,
   указав дату, CLI и ссылку на артефакты.

## 3. Python-юнит-тесты
1. Выполните полный набор Python-тестов из корня репозитория:
   ```bash
   python -m unittest
   ```
2. Если известные тесты падают (например, API/monitor), зафиксируйте причину и ссылку на issue в разделе чек-листа.
   Дополнительно можно приложить лог запуска в `tmp/logs/python-unittest-YYYYMMDD.txt`.

## 4. Смоук-тест testnet
1. Следуя `docs/testnet_deployment_checklist.md`, убедитесь, что подписка dVRF активна и адреса контрактов заданы.
2. Запустите смоук-тест (через готовый скрипт или вручную):
   ```bash
   bash SupraLottery/supra/scripts/testnet_smoke_test.sh \
     --profile <supra_profile> \
     --lottery <lottery_addr> \
     --vrf-hub <vrf_hub_addr>
   ```
   При отсутствии готового скрипта выполните последовательность команд из раздела «Смоук-тест» чек-листа деплоя.
3. Зафиксируйте результаты: tx hash операций, статус выполнения, подтверждение выполнения dVRF callback.
   Сохраните лог в `docs/audit/smoke_tests/YYYY-MM-DD-testnet-smoke.log` и добавьте краткий вывод в чек-лист аудита.

## 5. Обновление артефактов и документации
1. После получения JSON/JUnit и логов смоук-теста обновите:
   - `docs/audit/internal_audit_checklist.md` — отметьте выполненные пункты 1.3, 1.4, разделы 3 и 6.
   - `docs/supra_alignment_status.md` — перенесите этап G в статус ✅, перечислите новые артефакты.
   - `docs/audit/external_handover_summary.md` — добавьте ссылки на отчёты Move-тестов, Python-тесты и smоук-тест.
   - `docs/alignment_gaps.md` — отметьте закрытие gap «Внутренний аудит G1».
2. Проверьте, что новые файлы добавлены в git и попадают в pull request.
3. В summary PR перечислите полученные артефакты и подтверждение прохождения динамических проверок.

## 6. Тайминг и повторное использование
- Рекомендуемый тайминг на полный динамический прогон — 1 рабочий день при наличии готовой Supra CLI.
- Документ сохраняйте как шаблон для повторного аудита перед каждым релизом или обновлением Supra Framework.
- При изменении CLI/скриптов обновляйте команды и пути артефактов в этом runbook.
