#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MOVE_DIR="$REPO_ROOT/SupraLottery/supra/move_workspace"

APTOS_BIN=${APTOS_BIN:-aptos}

if ! command -v "$APTOS_BIN" >/dev/null 2>&1; then
  cat <<MSG
[run_move_tests] Не найден бинарь Supra Aptos CLI ('$APTOS_BIN').
Установите CLI (см. docs/handbook/operations/supra_cli.md) и убедитесь, что он доступен в PATH
или задайте переменную окружения APTOS_BIN с абсолютным путём до бинаря.
MSG
  exit 127
fi

if [ ! -d "$MOVE_DIR" ]; then
  echo "[run_move_tests] Не найдена директория Move-пакета: $MOVE_DIR" >&2
  exit 2
fi

# Пробуем получить версию для логов CI/операций
if ! "$APTOS_BIN" --version >/dev/null 2>&1; then
  echo "[run_move_tests] Не удалось получить версию CLI через '$APTOS_BIN --version'." >&2
fi

exec "$APTOS_BIN" move test --package-dir "$MOVE_DIR" "$@"
