#!/bin/bash
# Usage:
#   ./migration_session_control.sh /supra/configs/testnet.yaml ensure
#   ./migration_session_control.sh /supra/configs/testnet.yaml release
#   ./migration_session_control.sh /supra/configs/testnet.yaml snapshot
#   ./migration_session_control.sh /supra/configs/testnet.yaml ledger
#   ./migration_session_control.sh /supra/configs/testnet.yaml lottery 42
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<USAGE >&2
Usage: $0 <config> <command> [args...]
Commands:
  ensure           Fetch InstancesExportCap and LegacyTreasuryCap into MigrationSession
  release          Return MigrationSession caps back to their controllers
  snapshot         View lottery_utils::migration::session_snapshot
  caps-ready       View lottery_utils::migration::caps_ready
  session-ready    View lottery_utils::migration::session_initialized
  ledger-ready     View lottery_utils::migration::is_initialized
  ledger           View lottery_utils::migration::ledger_snapshot
  list             View lottery_utils::migration::list_migrated_lottery_ids
  lottery <id>     View lottery_utils::migration::get_migration_snapshot for a lottery
USAGE
  exit 1
fi

CONFIG=$1
COMMAND=$2
shift 2 || true

run_entry() {
  local description=$1
  local function_name=$2
  local args=$3
  printf '==> %s\n' "$description"
  local command
  printf -v command 'supra move run --config %q --function %q' "$CONFIG" "$function_name"
  if [[ -n $args ]]; then
    command+=" --args $args"
  fi
  docker compose run --rm --entrypoint bash supra_cli -lc "$command"
  echo
}

run_view() {
  local description=$1
  local function_name=$2
  local args=$3
  printf '==> %s\n' "$description"
  local command
  printf -v command 'supra move view --config %q --function %q' "$CONFIG" "$function_name"
  if [[ -n $args ]]; then
    command+=" --args $args"
  fi
  docker compose run --rm --entrypoint bash supra_cli -lc "$command"
  echo
}

require_lottery_id() {
  if [[ $# -lt 1 ]]; then
    echo "lottery_id is required" >&2
    exit 1
  fi
  LOTTERY_ID=$1
}

case "$COMMAND" in
  ensure)
    run_entry "Ensuring migration caps" "lottery_utils::migration::ensure_caps_initialized" ""
    ;;
  release)
    run_entry "Releasing migration caps" "lottery_utils::migration::release_caps" ""
    ;;
  snapshot)
    run_view "Migration session snapshot" "lottery_utils::migration::session_snapshot" ""
    ;;
  caps-ready)
    run_view "Migration caps ready" "lottery_utils::migration::caps_ready" ""
    ;;
  session-ready)
    run_view "Migration session initialized" "lottery_utils::migration::session_initialized" ""
    ;;
  ledger-ready)
    run_view "Migration ledger initialized" "lottery_utils::migration::is_initialized" ""
    ;;
  ledger)
    run_view "Migration ledger snapshot" "lottery_utils::migration::ledger_snapshot" ""
    ;;
  list)
    run_view "Migrated lottery ids" "lottery_utils::migration::list_migrated_lottery_ids" ""
    ;;
  lottery)
    require_lottery_id "$@"
    run_view "Migration snapshot for lottery ${LOTTERY_ID}" \
      "lottery_utils::migration::get_migration_snapshot" "u64:$LOTTERY_ID"
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    exit 1
    ;;
esac
