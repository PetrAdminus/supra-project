# Пошаговый план миграции SupraLottery на Move 1

Документ отражает последовательность работ по выполнению требований из `docs/move_migration_next_steps.md` и набор проверок для каждого этапа.

## Этап A — инфраструктура и адреса

### Подзадачи
- Обновить `SupraLottery/supra/move_workspace/Move.toml`, убедиться в единой структуре `[package]` и `[addresses]`.
- Заменить шаблонные адреса (`{{supra_addr}}` и др.) на реальные значения либо механизмы переопределения в пакетах `lottery`, `lottery_factory`, `vrf_hub`, `SupraVrf`.
- Привести `.move/config` к новой структуре профилей и адресов, обновить инструкции в `README.md` и `SupraLottery/README.md`.

### Статус
- Добавлены `.move/config` с тестнет-адресами и `.move/config.example` для собственных окружений; инструкции в `README.md` и `SupraLottery/README.md` обновлены в текущем коммите.

### Проверки
- `move package build` из `SupraLottery/supra/move_workspace`.
- Статическая проверка шаблонов адресов (`rg "{{" SupraLottery/supra/move_workspace`).

## Этап B — события и хэндлы

### Подзадачи
- Заменить `event::new_event_handle` на `supra_framework::account::new_event_handle` во всех перечисленных модулях.
- После `move_to` сразу вызывать `borrow_global_mut` и формировать первый снапшот.
- Удалить или упростить обёртки `lottery::events::new_handle`.

### Статус
- Все модули пакета `lottery`, фабрики и VRF-хаба создают обработчики через `supra_framework::account::new_event_handle` и публикуют события напрямую через `supra_framework::event::emit_event`.
- В ресурсах с событиями добавлены начальные снапшоты после `move_to`, для `lottery::rounds` реализован список лотерей и итерация по снапшотам.
- Модули-обёртки `events` удалены, документация обновлена под прямой вызов API Supra Framework.

### Проверки
- `move tool test --package-dir SupraLottery/supra/move_workspace/lottery`.
- `move tool test --package-dir SupraLottery/supra/move_workspace/lottery_factory`.
- Просмотр предупреждений компилятора на наличие устаревших API.

## Этап C — синтаксис и видимость

### Подзадачи
- Привести циклы с `let mut` к синтаксису Move 1, очистить код от кириллицы.
- Пересмотреть `public(package)` функции и friend-списки в пакетах.
- Обновить обработку `copy` внутри событий.

### Статус
- Циклы в пакетах `lottery`, `lottery_factory`, `vrf_hub` и `SupraVrf` переписаны под синтаксис Move 1: переменные счётчиков объявляются без `mut`, инкрементируются внутри тела и проходят проверку `rg "let mut" SupraLottery/supra/move_workspace`.
- Исходники и тесты очищены от не-ASCII символов (`rg "[^\\x00-\\x7F]" SupraLottery/supra/move_workspace`), комментарии оставлены только на английском.
- Функции `public(package)` в пакете `lottery` переведены на `public(friend)` или локальные `fun`, добавлены явные friend-списки для `autopurchase`, `migration`, `rounds`, `referrals`, `vip`, `store`, `jackpot` и тестового модуля `treasury_multi_tests`.
- Операторы `copy event.request_hash` и сопутствующие обращения размещены внутри корректных кортежей, чтобы удовлетворить требованиям Move 1 к завершающим скобкам.

### Проверки
- `move check --package-dir SupraLottery/supra/move_workspace/lottery` и аналогичные для остальных пакетов.
- Скрипт статического анализа (`rg "let mut" SupraLottery/supra/move_workspace`).
- Проверка отсутствия не-ASCII (`rg "[^\\x00-\\x7F]" SupraLottery/supra/move_workspace`).

## Этап D — тесты и скрипты

### Подзадачи
- Доработать `SupraLottery/supra/scripts/move_tests.py` (режимы `--mode check`, Docker/Aptos CLI, fallback на `move test`).
- Интегрировать запуск в GitHub Actions (`.github/workflows/*`).
- Сохранять отчёты `tmp/move-test-report.json`, `tmp/move-test-report.xml`, `tmp/unittest.log`.

### Статус
- `move_tests.py` формирует JSON/JUnit отчёты и лог `tmp/unittest.log` по умолчанию, транслируя вывод CLI и позволяя отключить
  сохранение файлов при необходимости; для Aptos CLI 7.x режим `check` автоматически мапится на `aptos move compile`, а команды
  `aptos move` получают флаг `--skip-fetch-latest-git-deps` для офлайн-запуска без доступа к git-зависимостям. Скрипт
  автоматически читает `.move/config`, собирает именованные адреса и дополняет команды параметром `--named-addresses`; при
  необходимости можно передать `--move-config` или `--no-auto-named-addresses`.
- Fallback на ванильный Move CLI использует `move <mode> --package-dir <target>`, поэтому проверки и тесты запускаются из корня пакета без дополнительных ключей.
- Добавлен workflow `.github/workflows/move-tests.yml`, который пытается установить Aptos CLI и запускает `move_tests.py` для всех
  пакетов (при отсутствии CLI выполняется dry-run и всё равно сохраняются артефакты).
- Обновлены юнит-тесты `tests/test_move_tests_script.py`: они проверяют потоковый запуск `_run_with_streaming`, флаг `--skip-fetch-latest-git-deps`,
  автоматическое формирование `--named-addresses` и отключение артефактов отчётности.

### Проверки
- `python -m supra.scripts.move_tests --mode check` (локально, с заглушками при необходимости).
- Просмотр логов GitHub Actions (локально — `act` или `pytest` для workflow).

## Этап E — документация и конфигурация CLI

### Подзадачи
- Обновить `README.md`, `SupraLottery/README.md`, `docs/testnet_runbook.md`, `docs/dvrf_reference_snapshot.md`, `docs/audit/internal_audit_*`.
- Добавить `.move/config.example` и раздел в README о настройке профилей.
- Актуализировать раздел о whitelist и операционных процедурах.

### Статус
- `README.md` и `SupraLottery/README.md` описывают `python -m supra.scripts.move_tests`, автоматическую генерацию JSON/JUnit/лога и необходимость `--named-addresses` при ручных запусках Supra CLI.
- Runbook-и (`docs/testnet_runbook.md`, `SupraLottery/docs/testnet_runbook.md`) дополнены инструкциями по проверке GUID событий через `supra move tool resource` и уточнениями об адресах из `.move/config`.
- `SupraLottery/docs/dvrf_reference_snapshot.md` и `docs/audit/internal_audit_{checklist,dynamic_runbook,static_review}.md` отражают использование `account::new_event_handle`, стартовых снапшотов и новый pipeline отчётности (`tmp/move-test-report.json/xml`, `tmp/unittest.log`).

### Проверки
- Ручная вычитка и проверка ссылок (`markdown-link-check`, при наличии).
- Проверка отсутствия упоминаний устаревших команд (`rg "move test" docs README.md SupraLottery/README.md`).

## Этап F — финализация и выверка путей

### Подзадачи
- Убедиться, что скрипты и CI используют актуальные пути в `/supra/move_workspace`.
- Сверить README и служебные материалы с конечной структурой.

### Статус
- В `supra/move_workspace` развернуты симлинки на canonical workspace `SupraLottery/supra/move_workspace`, поэтому Docker и CLI
  используют единую структуру. Дублирующие исходники и устаревшие `.aptos` конфиги удалены.

### Проверки
- `move tool test` по всему workspace.
- `python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages`.
- `PYTHONPATH=SupraLottery python -m unittest`.

## Учёт прогресса

После завершения каждого этапа фиксировать результаты отдельным коммитом, прикладывать ссылки на отчёты тестов (JSON/JUnit, unittest logs). Финальный критерий успеха — успешный `move tool test` для workspace и закрытые чек-листы (internal audit + dVRF v3).
