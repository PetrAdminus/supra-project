#!/bin/bash
# Usage:
#   ./automation_status.sh /supra/configs/testnet.yaml list
#   ./automation_status.sh /supra/configs/testnet.yaml get 0x<operator>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -lt 2 ]]; then
  cat <<USAGE >&2
Usage: $0 <config> <command> [args...]
Commands:
  list                List all registered AutomationBot operators with status snapshot
  get <operator>      Fetch AutomationBot status for a specific operator address
USAGE
  exit 1
fi

CONFIG=$1
COMMAND=$2
shift 2 || true

run_view() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

case "$COMMAND" in
  list)
    run_view "supra move view --config $CONFIG --function lottery_multi::views::list_automation_bots"
    ;;
  get)
    OPERATOR=${1:?"operator address is required"}
    run_view "supra move view --config $CONFIG --function lottery_multi::views::get_automation_bot --args address:$OPERATOR"
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    exit 1
    ;;
 esac
