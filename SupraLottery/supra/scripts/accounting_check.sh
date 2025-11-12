#!/bin/bash
# Usage:
#   ./accounting_check.sh [--dry-run] <config> snapshot <lottery_id>
#   ./accounting_check.sh [--dry-run] <config> summary <lottery_id>
#   ./accounting_check.sh [--dry-run] <config> compare <lottery_id>
#
# Команда `compare` выполняет оба view и выводит контрольный отчёт об агрегатах,
# сверяя `total_allocated`, `total_prize_paid` и `total_operations_paid`.
set -euo pipefail

DRY_RUN=0

if [[ $# -ge 1 && "$1" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ $# -lt 3 ]]; then
  cat <<USAGE >&2
Usage: $0 [--dry-run] <config> <command> <lottery_id>
Commands:
  snapshot <lottery_id>  # views::accounting_snapshot
  summary  <lottery_id>  # views::get_lottery_summary
  compare  <lottery_id>  # snapshot + summary with consistency check
USAGE
  exit 1
fi

CONFIG=$1
COMMAND=$2
LOTTERY_ID=$3

run_view() {
  local function_name="$1"
  local command="supra move view --config $CONFIG --function $function_name --args u64:$LOTTERY_ID"
  echo "+ $command"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] skipped execution"
    return 0
  fi
  docker compose run --rm --entrypoint bash supra_cli -lc "$command"
}

compare_views() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ supra move view --config $CONFIG --function lottery_multi::views::accounting_snapshot --args u64:$LOTTERY_ID"
    echo "[dry-run] skipped execution"
    echo "+ supra move view --config $CONFIG --function lottery_multi::views::get_lottery_summary --args u64:$LOTTERY_ID"
    echo "[dry-run] skipped execution"
    return 0
  fi

  local accounting_json
  local summary_json
  accounting_json=$(docker compose run --rm --entrypoint bash supra_cli -lc     "supra move view --config $CONFIG --function lottery_multi::views::accounting_snapshot --args u64:$LOTTERY_ID" )
  summary_json=$(docker compose run --rm --entrypoint bash supra_cli -lc     "supra move view --config $CONFIG --function lottery_multi::views::get_lottery_summary --args u64:$LOTTERY_ID" )

  echo "$accounting_json"
  echo "$summary_json"

  docker compose run --rm --entrypoint python3 supra_cli - <<'PYTHON' "$accounting_json" "$summary_json"
import json
import sys
accounting_raw = sys.argv[1]
summary_raw = sys.argv[2]
try:
    accounting = json.loads(accounting_raw)
    summary = json.loads(summary_raw)
except json.JSONDecodeError as exc:
    print(f"Failed to parse JSON output: {exc}", file=sys.stderr)
    sys.exit(2)
if isinstance(accounting, list) and accounting:
    accounting = accounting[0]
if isinstance(summary, list) and summary:
    summary = summary[0]
required_snapshot_fields = [
    "total_sales",
    "total_allocated",
    "total_prize_paid",
    "total_operations_paid",
    "total_operations_allocated",
]
missing = [field for field in required_snapshot_fields if field not in accounting]
if missing:
    print(f"Accounting view missing fields: {', '.join(missing)}", file=sys.stderr)
    sys.exit(3)
required_summary_fields = [
    "total_allocated",
    "total_prize_paid",
    "total_operations_paid",
]
missing_summary = [field for field in required_summary_fields if field not in summary]
if missing_summary:
    print(f"Summary view missing fields: {', '.join(missing_summary)}", file=sys.stderr)
    sys.exit(4)
report = {
    "total_sales": accounting["total_sales"],
    "total_allocated_match": accounting["total_allocated"] == summary["total_allocated"],
    "total_prize_paid_match": accounting["total_prize_paid"] == summary["total_prize_paid"],
    "total_operations_paid_match": accounting["total_operations_paid"] == summary["total_operations_paid"],
    "total_operations_allocated": accounting["total_operations_allocated"],
}
print(json.dumps(report, indent=2, sort_keys=True))
PYTHON
}

case "$COMMAND" in
  snapshot)
    run_view "lottery_multi::views::accounting_snapshot"
    ;;
  summary)
    run_view "lottery_multi::views::get_lottery_summary"
    ;;
  compare)
    compare_views
    ;;
  *)
    cat <<EOF >&2
Unknown command: $COMMAND
Supported commands:
  snapshot <lottery_id>
  summary  <lottery_id>
  compare  <lottery_id>
EOF
    exit 1
    ;;
esac
