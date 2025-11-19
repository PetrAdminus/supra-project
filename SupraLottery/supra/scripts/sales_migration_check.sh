#!/bin/bash
# Usage:
#   ./sales_migration_check.sh /supra/configs/testnet.yaml summary
#   ./sales_migration_check.sh /supra/configs/testnet.yaml lottery 42
#   ./sales_migration_check.sh /supra/configs/testnet.yaml legacy 42
#   ./sales_migration_check.sh /supra/configs/testnet.yaml new 42
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<USAGE >&2
Usage: $0 <config> <command> [args...]
Commands:
  summary             Dump lottery_engine::sales::sales_snapshots for all lotteries
  lottery <id>        Fetch all relevant snapshots for a lottery (new sales, treasury shares, legacy accounting)
  new <id>            Fetch lottery_engine::sales::sales_snapshot for a single lottery
  legacy <id>         Fetch lottery_multi::views::accounting_snapshot for a single lottery
USAGE
  exit 1
fi

CONFIG=$1
COMMAND=$2
shift 2 || true

run_view() {
  local description="$1"
  local function_name="$2"
  local args="$3"
  printf '==> %s: %s %s\n' "$description" "$function_name" "${args:-<no args>}"

  local command
  printf -v command 'supra move view --config %q --function %q' "$CONFIG" "$function_name"
  if [[ -n "$args" ]]; then
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
  summary)
    run_view "sales snapshots" "lottery_engine::sales::sales_snapshots" ""
    ;;
  lottery)
    require_lottery_id "$@"
    run_view "lottery_engine sales snapshot" "lottery_engine::sales::sales_snapshot" "u64:$LOTTERY_ID"
    run_view "treasury share config" "lottery_rewards_engine::treasury::lottery_config" "u64:$LOTTERY_ID"
    run_view "legacy accounting snapshot" "lottery_multi::views::accounting_snapshot" "u64:$LOTTERY_ID"
    ;;
  new)
    require_lottery_id "$@"
    run_view "lottery_engine sales snapshot" "lottery_engine::sales::sales_snapshot" "u64:$LOTTERY_ID"
    ;;
  legacy)
    require_lottery_id "$@"
    run_view "legacy accounting snapshot" "lottery_multi::views::accounting_snapshot" "u64:$LOTTERY_ID"
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    exit 1
    ;;
esac
