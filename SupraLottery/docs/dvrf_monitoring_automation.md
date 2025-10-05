# Автоматизация мониторинга Supra dVRF

Документ описывает способы регулярного контроля состояния подписки Supra dVRF 3.0 и интеграцию уже существующих скриптов репозитория с планировщиками задач (cron, CI/CD раннерами, Supra AutoFi).

## 1. Основные цели мониторинга

* Отслеживание остатка депозита и сравнение его с минимально допустимым балансом.
* Контроль whitelisting агрегатора и потребителей, лимитов газа и состояния запросов VRF.
* Проверка появления ожидаемых событий (`DrawRequestedEvent`, `DrawHandledEvent`, whitelisting-события).
* Автоматическое оповещение при отклонениях (депозит ниже лимита, отсутствие обработанных событий, зависание запроса).

## 2. Набор готовых скриптов

| Скрипт | Назначение | Обязательные переменные окружения |
|-------|------------|------------------------------------|
| `supra/scripts/testnet_status_report.sh` | Формирует отчёт по ключевым `view`-функциям контракта и модуля `deposit`. | `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR` |
| `supra/scripts/testnet_monitor_check.sh` | Вычисляет ожидаемый `min_balance`, проверяет фактический остаток и завершает работу с ошибкой, если депозит опустился ниже порога. | `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR`, `MAX_GAS_PRICE`, `MAX_GAS_LIMIT`, `VERIFICATION_GAS_VALUE` |
| `supra/scripts/testnet_monitor_json.py` | Собирает агрегированный JSON (статус лотереи, VRF-конфигурация, whitelisting, данные депозита) и опционально завершает работу с `exit=1`, если баланс ниже `min_balance`. | `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR`, `MAX_GAS_PRICE`, `MAX_GAS_LIMIT`, `VERIFICATION_GAS_VALUE` |
| `supra/scripts/testnet_monitor_slack.py` | Формирует человеко-читаемое сообщение, отправляет его в Slack/Teams webhook и возвращает код `testnet_monitor_json.py` (например, `1`, если баланс ниже порога). | Все переменные, что и у `testnet_monitor_json.py`, плюс `MONITOR_WEBHOOK_URL` |
| `supra/scripts/testnet_monitor_prometheus.py` | Преобразует JSON-отчёт в Prometheus-метрики, печатает их в stdout и, при необходимости, отправляет на Pushgateway/HTTP endpoint. | Все переменные, что и у `testnet_monitor_json.py`, а также `METRIC_PREFIX`, `MONITOR_PUSH_URL`, `MONITOR_PUSH_METHOD`, `MONITOR_PUSH_TIMEOUT` |
| `python -m supra.scripts <подкоманда>` | Унифицированный способ запуска Python-скриптов без указания пути к файлу. Используйте `--list`, чтобы посмотреть доступные команды. | Совпадают с выбранной подкомандой (например, `monitor-json`, `manual-draw`) |
| `python -m supra.scripts auto-draw` | Новая подкоманда, совмещающая проверку готовности и запуск `manual_draw`, печатает результат в формате JSONL. | `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR` и остальные параметры проверки/розыгрыша |
| `supra/scripts/testnet_smoke_test.sh` | Выполняет смоук-тест (настройка, покупка билетов, запрос VRF) и проверяет события. | `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR`, `AGGREGATOR_ADDR`, `PLAYER_PROFILES` и т.д. |

> Шаблон `supra/scripts/testnet_env.example` содержит полный список переменных, рекомендуемых для автоматизации. Скопируйте его в `.env`, подставьте значения и подключайте через `set -a; source ...; set +a`.
> Для получения JSON с тем же кодом возврата, что и у `testnet_monitor_check.sh`, запускайте `python supra/scripts/testnet_monitor_json.py --pretty --fail-on-low`.
> Для webhook-уведомлений добавьте в `.env` переменную `MONITOR_WEBHOOK_URL` (Slack/Teams) и при необходимости `MONITOR_WEBHOOK_TYPE`, `MONITOR_TITLE`.
> Для экспорта метрик в Prometheus используйте `python supra/scripts/testnet_monitor_prometheus.py --metric-prefix supra_dvrf --label env=test --fail-on-low` и задайте `MONITOR_PUSH_URL`, если требуется автоматическая отправка на Pushgateway.

## 3. Пример запуска по расписанию (cron)

```bash
# /etc/cron.d/supra_dvrf_monitor
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

*/10 * * * * root \
  cd /opt/SupraLottery && \
  set -a && source supra/scripts/testnet_env && set +a && \
  ./supra/scripts/testnet_monitor_check.sh >> /var/log/supra_monitor.log 2>&1

0 * * * * root \
  cd /opt/SupraLottery && \
  set -a && source supra/scripts/testnet_env && set +a && \
  ./supra/scripts/testnet_status_report.sh >> /var/log/supra_status.log 2>&1

30 * * * * root \
  cd /opt/SupraLottery && \
  set -a && source supra/scripts/testnet_env && set +a && \
  python supra/scripts/testnet_monitor_json.py --pretty > /var/log/supra_monitor.json

15 * * * * root \
  cd /opt/SupraLottery && \
  set -a && source supra/scripts/testnet_env && set +a && \
  ./supra/scripts/testnet_monitor_slack.py --fail-on-low >> /var/log/supra_monitor_slack.log 2>&1

45 * * * * root \
  cd /opt/SupraLottery && \
  set -a && source supra/scripts/testnet_env && set +a && \
  python supra/scripts/testnet_monitor_prometheus.py --metric-prefix supra_dvrf --label env=test >> /var/log/supra_monitor.prom 2>&1
```

* `testnet_monitor_check.sh` завершится с кодом `1`, если депозит ниже лимита. Используйте этот код для интеграции с системами оповещения.
* `testnet_status_report.sh` выводит структурированный отчёт, который можно дополнительно обрабатывать `jq`.
* `testnet_monitor_json.py` создаёт машиночитаемый JSON, который удобно передавать в AutoFi webhook или системам анализа логов.
* `testnet_monitor_slack.py` отправляет компактное сообщение в Slack/Teams и возвращает код возврата, который можно использовать в триггерах AutoFi.
* `testnet_monitor_prometheus.py` печатает и при необходимости пушит метрики в формате Prometheus, поэтому его удобно подключать к Pushgateway или системам метрик вроде VictoriaMetrics.
* `testnet_draw_readiness.py` поддерживает флаг `--json-summary`, который выводит краткое резюме (готовность, причины отказа, счётчик билетов) без текстовых строк. При необходимости добавьте `--include-report`, чтобы вложить полный JSON из `testnet_monitor_json.py` в то же резюме и не печатать второй объект в stdout — это упрощает парсинг cron/AutoFi.
* `testnet_manual_draw.py` теперь умеет печатать структурированный результат через `--json-result`: код возврата Supra CLI, stdout/stderr и использованную команду попадают в JSON вместо обычных логов.

## 4. Интеграция с Supra AutoFi

1. Создайте job в AutoFi с типом «Command» и укажите Docker-образ/контейнер, который используется для ручного запуска CLI.
2. Добавьте шаг `set -a && source supra/scripts/testnet_env && set +a`, чтобы пробросить переменные окружения.
3. В качестве основного действия используйте один из скриптов, например:
   ```bash
   ./supra/scripts/testnet_monitor_check.sh || supra-alert "Deposit below minimum"
   ./supra/scripts/testnet_monitor_slack.py --include-json --fail-on-low || supra-alert "Slack webhook error"
   python supra/scripts/testnet_draw_readiness.py || supra-alert "Draw readiness failed"
   python -m supra.scripts auto-draw --execute || supra-alert "Auto draw failed"
   ```
4. Для мониторинга событий добавьте дополнительный шаг с `supra/scripts/testnet_status_report.sh` или командой `supra/supra move tool events list ...` из справочника `docs/dvrf_event_monitoring.md`.
5. При необходимости сохраните машиночитаемый отчёт: `python supra/scripts/testnet_monitor_json.py --pretty > autofi-artifacts/dvrf_status.json` и прикрепите файл в AutoFi job.
6. Настройте нотификации AutoFi (Slack, email, webhook) на основании кода возврата скрипта и содержимого логов.

## 5. Использование в CI/CD

* Запускайте `testnet_monitor_check.sh`, `testnet_monitor_json.py`, `testnet_monitor_slack.py` и `testnet_status_report.sh` в nightly-пайплайнах GitHub Actions/GitLab CI, подгружая `.env` из защищённых секретов.
* Дополнительно прогоняйте `supra/scripts/testnet_smoke_test.sh` в QA-контурах перед мажорными релизами, чтобы убедиться в корректной работе VRF. Для одиночного запуска розыгрыша без полного smoke-теста используйте [`supra/scripts/testnet_manual_draw.py`](../supra/scripts/testnet_manual_draw.py) — скрипт проверяет готовность и вызывает `manual_draw`.
* Используйте `calc_min_balance.py` для автоматического пересчёта лимита при изменении конфигурации газа; результаты можно коммитить в отчёт или размещать в артефактах CI.

## 6. Рекомендации по логированию и алертам

* Храните логи мониторинга отдельно от основных логов приложения (`/var/log/supra_*`). Для JSON-отчёта лучше использовать отдельный файл или S3-бакет с версионированием.
* Настройте парсинг сообщений `[warning]` и `[error]`, которые выводят скрипты (например, через `promtail`/`loki` или `filebeat`).
* При срабатывании алерта проверяйте справочник `docs/dvrf_error_reference.md` — там описаны типичные ошибки Supra dVRF и способы их устранения.

## 7. Дальнейшее развитие

* Автоматизировать покупку тестовых билетов перед запуском `manual_draw`, чтобы гарантировать выполнение условий розыгрыша.
* Расширить `testnet_monitor_check.sh` метриками количества успешных/неудачных запросов VRF (по событиям) и интегрировать с Prometheus.
* Подготовить ansible-роль/terraform-модуль, разворачивающий cron/AutoFi job вместе с необходимыми конфигами.

## 8. Авто-оркестратор розыгрышей

`python -m supra.scripts auto-draw` объединяет проверку готовности (`testnet_draw_readiness.py`) и запуск `manual_draw` в один шаг. Команда всегда выводит одну строку JSON со статусом `not_ready`, `ready_dry_run`, `executed` или `manual_draw_failed`, а также включает использованные аргументы и коды возврата дочерних скриптов. Благодаря прокси-флагу `--include-report` в подкоманде readiness полный отчёт мониторинга автоматически попадает в лог.

Примеры использования:

```bash
# Только проверка готовности, без вызова manual_draw
python -m supra.scripts auto-draw \
  --profile $PROFILE \
  --lottery-addr $LOTTERY_ADDR \
  --deposit-addr $DEPOSIT_ADDR > logs/auto_draw.log

# Полноценный запуск manual_draw с JSON-логом для AutoFi
python -m supra.scripts auto-draw --execute \
  --profile $PROFILE \
  --lottery-addr $LOTTERY_ADDR \
  --deposit-addr $DEPOSIT_ADDR \
  --assume-yes >> logs/auto_draw.jsonl
```

JSON-лог удобно собирать в файл (`.jsonl`) и отправлять в централизованное хранилище: каждая строка содержит время запуска, команду readiness/manual_draw и результат исполнения. При необходимости можно включить дополнительные проверки (`--require-aggregator`, `--expect-aggregator`, `--skip-min-balance`) — все флаги проксируются в оба скрипта.

## 9. Текущий статус и дальнейший план с AutoFi

### Зафиксированные результаты

* Скрипт `testnet_draw_readiness.py` возвращает структурированный ответ через `--json-summary` и может включать полный отчёт мониторинга (`--include-report`), поэтому планировщики получают весь контекст одним JSON-объектом.
* `testnet_manual_draw.py` поддерживает флаг `--json-result`, что позволяет AutoFi job анализировать исход Supra CLI, коды возврата и stdout/stderr без дополнительного парсинга логов.
* Подкоманда `python -m supra.scripts auto-draw` объединяет проверку готовности и запуск розыгрыша, автоматически пробрасывает `--include-report` и печатает одну строку JSONL со статусом `not_ready`, `ready_dry_run`, `executed` или `manual_draw_failed`.
* Документация обновлена шаблонами Cron/AutoFi: достаточно подключить `.env` и вызвать `python -m supra.scripts auto-draw --execute` (или dry-run), чтобы получать машиночитаемые журналы.

### Дальнейший план

1. **Пилот в AutoFi.** Создать отдельную AutoFi job, которая использует контейнер из runbook, подгружает `.env` и запускает `python -m supra.scripts auto-draw --execute --assume-yes`. Сохранить stdout в артефакт `auto_draw.jsonl` и включить уведомления по ненулевому `exit_code`.
2. **Верификация логов.** Проверить, что JSONL корректно парсится в AutoFi и в downstream-инструментах (например, Loki/Elastic). При необходимости добавить шаг с выгрузкой файла в S3 или push на централизованный лог-сервис.
3. **Алерты и ретраи.** Настроить правила AutoFi: при статусе `not_ready` оставлять информационное уведомление, при `manual_draw_failed` — критический алерт и автоматический повтор через `retry policy`. Для успеха фиксировать метрику/событие (например, webhooks).
4. **Безопасность параллельных запусков.** Добавить файловый лок (`--lock-file`) в `auto_draw_runner`, чтобы предотвращать пересечение cron/AutoFi запусков и дублирование `manual_draw`; после реализации обновить документацию и пилотный job.
5. **Расширение мониторинга.** На следующем этапе автоматизировать покупку тестовых билетов перед запуском, добавить проверки whitelisting и депозитов через Prometheus-метрики, чтобы AutoFi мог строить дашборды по готовности розыгрыша.

Все изменения следует тестировать командой `PYTHONPATH=SupraLottery pytest SupraLottery/tests` перед выкладкой на production и фиксировать заметки о каждом запуске AutoFi в журнале сопровождения.

