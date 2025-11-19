#!/bin/bash
# Usage:
#   ./payout_migration_check.sh /supra/configs/testnet.yaml summary
#   ./payout_migration_check.sh /supra/configs/testnet.yaml lottery 42
#   ./payout_migration_check.sh /supra/configs/testnet.yaml record 1234
#   ./payout_migration_check.sh /supra/configs/testnet.yaml legacy 42
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<USAGE >&2
Usage: $0 <config> <command> [args...]
Commands:
  summary             Check lottery_data::payouts readiness and dump ledger snapshots
  lottery <id>        Fetch new lottery snapshot, rewards alias and legacy winner progress
  record <payout_id>  Fetch lottery_data::payouts::payout_record_snapshot for a payout id
  legacy <id>         Fetch lottery_multi::payouts::winner_progress for a legacy lottery
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

require_payout_id() {
  if [[ $# -lt 1 ]]; then
    echo "payout_id is required" >&2
    exit 1
  fi
  PAYOUT_ID=$1
}

case "$COMMAND" in
  summary)
    run_view "payout ledger ready" "lottery_data::payouts::ready" ""
    run_view "lottery_engine payout ledger snapshot" "lottery_engine::payouts::ledger_snapshot" ""
    run_view "lottery_rewards_engine payout ledger snapshot" "lottery_rewards_engine::payouts::ledger_snapshot" ""
    ;;
  lottery)
    require_lottery_id "$@"
    run_view "lottery_engine lottery payout snapshot" "lottery_engine::payouts::lottery_snapshot" "u64:$LOTTERY_ID"
    run_view "lottery_rewards_engine lottery payout snapshot" "lottery_rewards_engine::payouts::lottery_snapshot" "u64:$LOTTERY_ID"
    run_view "legacy winner progress" "lottery_multi::payouts::winner_progress" "u64:$LOTTERY_ID"
    ;;
  record)
    require_payout_id "$@"
    run_view "lottery_data payout record snapshot" "lottery_data::payouts::payout_record_snapshot" "u64:$PAYOUT_ID"
    ;;
  legacy)
    require_lottery_id "$@"
    run_view "legacy winner progress" "lottery_multi::payouts::winner_progress" "u64:$LOTTERY_ID"
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    exit 1
    ;;
 esac
