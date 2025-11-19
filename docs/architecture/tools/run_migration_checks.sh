#!/usr/bin/env bash
set -euo pipefail

# Скрипт для CI/локальных проверок карты миграции SupraLottery.
# Генерирует JSON-инвентарь Move и запускает строгую проверку таблицы миграции.

resolve_repo_root() {
  if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$git_root"
    return 0
  fi
  script_dir=$(cd "$(dirname "$0")" && pwd)
  printf '%s\n' "$(cd "$script_dir/../../.." && pwd)"
}

REPO_ROOT=$(resolve_repo_root)
TOOLS_DIR="$REPO_ROOT/docs/architecture/tools"
WORKSPACE_ROOT="$REPO_ROOT/SupraLottery/supra/move_workspace"
TMP_DIR="$REPO_ROOT/tmp"

mkdir -p "$TMP_DIR"

INVENTORY_JSON="${1:-$TMP_DIR/move_struct_inventory.json}"
MAPPING_JSON="${2:-$TMP_DIR/migration_plan_status.json}"
INVENTORY_MD="$TMP_DIR/move_struct_inventory.md"

mkdir -p "$(dirname "$INVENTORY_JSON")"
mkdir -p "$(dirname "$MAPPING_JSON")"

printf '[1/2] Экспорт инвентаризации Move → %s\n' "$INVENTORY_JSON"
python "$TOOLS_DIR/export_move_inventory.py" \
  --workspace-root "$WORKSPACE_ROOT" \
  --output "$INVENTORY_MD" \
  --json-output "$INVENTORY_JSON"

printf '[2/2] Проверка карты миграции → %s\n' "$MAPPING_JSON"
python "$TOOLS_DIR/check_migration_mapping.py" \
  --mapping-path "$REPO_ROOT/docs/architecture/move_migration_mapping.md" \
  --inventory-json "$INVENTORY_JSON" \
  --json-output "$MAPPING_JSON" \
  --strict

printf 'Готово: сводка статусов сохранена в %s\n' "$MAPPING_JSON"
