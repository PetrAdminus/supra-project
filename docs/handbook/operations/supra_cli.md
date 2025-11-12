# Supra CLI и Move-тесты

Документ описывает установку Supra Aptos CLI, проверку окружения и запуск тестов `lottery_multi`.

## 1. Требования
- macOS 13+/Ubuntu 22.04+ с установленными `curl`, `tar`, `openssl`.
- Доступ к GitHub Releases Supra для загрузки готовых бинарей или Rust toolchain (если требуется сборка из исходников).
- Права на запись в директорию `${HOME}/.local/bin` (или альтернативный путь установки).

## 2. Установка
### 2.1 Готовый бинарь
1. Загрузите архив с последним релизом Supra CLI (`supra-aptos-cli-<os>-<arch>.tar.gz`).
2. Распакуйте архив в временную директорию: `tar -xzf supra-aptos-cli-*.tar.gz`.
3. Скопируйте бинарь в `${HOME}/.local/bin` (или любой каталог из `$PATH`):
   ```bash
   install -m 0755 supra-aptos-cli ${HOME}/.local/bin/aptos
   ```
4. Убедитесь, что каталог находится в `$PATH`:
   ```bash
   export PATH="${HOME}/.local/bin:${PATH}"
   ```

### 2.2 Сборка из исходников
1. Установите nightly toolchain: `rustup toolchain install nightly`.
2. Соберите CLI:
   ```bash
   cargo +nightly install --git https://github.com/supraoracles/supra-aptos-cli aptos --locked
   ```
3. Проверьте, что `~/.cargo/bin` добавлен в `$PATH`.

## 3. Проверка установки
1. Выполните `aptos --version` и убедитесь, что версия ≥ 2.0.0-supra.
2. Запустите скрипт проверки:
   ```bash
   ./supra/scripts/run_move_tests.sh --help
   ```
   Скрипт валидирует наличие бинаря (`APTOS_BIN` может переопределить путь) и покажет синтаксис команды.
3. Добавьте alias (опционально):
   ```bash
   alias supra-aptos="APTOS_BIN=/opt/supra/bin/aptos ./supra/scripts/run_move_tests.sh"
   ```

## 4. Запуск Move-тестов
- Базовый прогон всех пакетов:
  ```bash
  ./supra/scripts/run_move_tests.sh
  ```
- Прогон конкретного теста:
  ```bash
  ./supra/scripts/run_move_tests.sh --filter payouts::force_cancel_refund_flow_records_history
  ```
- Параллельный запуск (Linux/macOS):
  ```bash
  ./supra/scripts/run_move_tests.sh --threads 4
  ```

Скрипт автоматически использует `SupraLottery/supra/move_workspace` как директорию пакета и завершится с кодом `127`, если CLI недоступен.

## 5. Диагностика проблем
| Симптом | Причина | Решение |
|---------|---------|---------|
| `command not found: aptos` | CLI не установлен или не в `$PATH` | Установить CLI, проверить переменную `PATH`, использовать `APTOS_BIN=/abs/path` |
| `Failed to open package` | Неверная директория | Убедитесь, что репозиторий синхронизирован, `SupraLottery/supra/move_workspace` существует |
| `Move unit tests failed` | Ошибка тестов/контрактов | Ознакомьтесь с логами, выполните `aptos move prove` при необходимости, задокументируйте инцидент |

## 6. Интеграция в CI/CD
- Job `move-tests` должен вызывать `./supra/scripts/run_move_tests.sh`.
- Сохраняйте артефакты `aptos_testsuite.log` и добавляйте ссылку в релизную запись.
- Перед релизом фиксируйте используемую версию CLI (`aptos --version`) в [журнале операций](incident_log.md).

## 7. Связанные материалы
- [Операционные процедуры](runbooks.md)
- [Процедура рефанда](refund.md)
- [Чек-лист релиза](release_checklist.md)
- [Журнал операций](incident_log.md)
