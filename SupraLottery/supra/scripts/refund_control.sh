#!/bin/bash
# Usage:
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml cancel <lottery_id> <reason_code> <timestamp>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml batch <lottery_id> <refund_round> <tickets_refunded> <prize_refund> <operations_refund> <timestamp>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml progress <lottery_id>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml cancellation <lottery_id>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml status <lottery_id>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml summary <lottery_id>
#   ./refund_control.sh [--dry-run] /supra/configs/testnet.yaml archive <lottery_id> <finalized_at>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"

DRY_RUN=0

if [[ $# -ge 1 && "$1" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ $# -lt 2 ]]; then
  cat <<USAGE >&2
Usage: $0 [--dry-run] <config> <command> [args...]
Commands:
  cancel <lottery_id> <reason_code> <timestamp>
  batch <lottery_id> <refund_round> <tickets_refunded> <prize_refund> <operations_refund> <timestamp>
  progress <lottery_id>
  cancellation <lottery_id>
  status <lottery_id>
  summary <lottery_id>
  archive <lottery_id> <finalized_at>
USAGE
  exit 1
fi

CONFIG=$1
COMMAND=$2
shift 2 || true

run() {
  local command="$1"
  echo "+ $command"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] skipped execution"
    return 0
  fi
  docker compose run --rm --entrypoint bash supra_cli -lc "$command"
}

view() {
  local command="$1"
  echo "+ $command"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] skipped execution"
    return 0
  fi
  docker compose run --rm --entrypoint bash supra_cli -lc "$command"
}

case "$COMMAND" in
  cancel)
    LOTTERY_ID=${1:?"lottery id is required"}
    REASON_CODE=${2:?"reason code (u8) is required"}
    TIMESTAMP=${3:?"timestamp (u64) is required"}
    run "supra move run --config $CONFIG --function lottery_multi::lottery_registry::cancel_lottery_admin --args u64:$LOTTERY_ID u8:$REASON_CODE u64:$TIMESTAMP"
    ;;
  batch)
    LOTTERY_ID=${1:?"lottery id is required"}
    REFUND_ROUND=${2:?"refund round (u64) is required"}
    TICKETS_REFUNDED=${3:?"tickets refunded (u64) is required"}
    PRIZE_REFUND=${4:?"prize refund amount (u64) is required"}
    OPERATIONS_REFUND=${5:?"operations refund amount (u64) is required"}
    TIMESTAMP=${6:?"timestamp (u64) is required"}
    run "supra move run --config $CONFIG --function lottery_multi::payouts::force_refund_batch_admin --args u64:$LOTTERY_ID u64:$REFUND_ROUND u64:$TICKETS_REFUNDED u64:$PRIZE_REFUND u64:$OPERATIONS_REFUND u64:$TIMESTAMP"
    ;;
  progress)
    LOTTERY_ID=${1:?"lottery id is required"}
    view "supra move view --config $CONFIG --function lottery_multi::views::get_refund_progress --args u64:$LOTTERY_ID"
    ;;
  cancellation)
    LOTTERY_ID=${1:?"lottery id is required"}
    view "supra move view --config $CONFIG --function lottery_multi::views::get_cancellation --args u64:$LOTTERY_ID"
    ;;
  status)
    LOTTERY_ID=${1:?"lottery id is required"}
    view "supra move view --config $CONFIG --function lottery_multi::views::get_lottery_status --args u64:$LOTTERY_ID"
    ;;
  summary)
    LOTTERY_ID=${1:?"lottery id is required"}
    view "supra move view --config $CONFIG --function lottery_multi::views::get_lottery_summary --args u64:$LOTTERY_ID"
    ;;
  archive)
    LOTTERY_ID=${1:?"lottery id is required"}
    FINALIZED_AT=${2:?"finalized timestamp (u64) is required"}
    run "supra move run --config $CONFIG --function lottery_multi::payouts::archive_canceled_lottery_admin --args u64:$LOTTERY_ID u64:$FINALIZED_AT"
    ;;
  *)
    cat <<EOF >&2
Unknown command: $COMMAND
Supported commands:
  cancel <lottery_id> <reason_code> <timestamp>
  batch <lottery_id> <refund_round> <tickets_refunded> <prize_refund> <operations_refund> <timestamp>
  progress <lottery_id>
  cancellation <lottery_id>
  status <lottery_id>
  summary <lottery_id>
  archive <lottery_id> <finalized_at>
EOF
    exit 1
    ;;
esac

