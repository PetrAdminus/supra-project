#!/bin/bash
# Usage:
#   ./history_backfill.sh /supra/configs/testnet.yaml import 42 0x<summary_bcs_hex> 0x<expected_hash>
#   ./history_backfill.sh /supra/configs/testnet.yaml rollback 42
#   ./history_backfill.sh /supra/configs/testnet.yaml classify 42 1 255
#   ./history_backfill.sh /supra/configs/testnet.yaml status 42
#   ./history_backfill.sh /supra/configs/testnet.yaml list [from] [limit]
#   ./history_backfill.sh /supra/configs/testnet.yaml dry-run <summary_path> [--lottery-id <id>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <config> <command> [args...]" >&2
  exit 1
fi

CONFIG=$1
COMMAND=$2
shift 2 || true

run() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

view() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

case "$COMMAND" in
  import)
    LOTTERY_ID=${1:?"lottery id is required"}
    SUMMARY_HEX=${2:?"summary BCS hex (with 0x prefix) is required"}
    HASH_HEX=${3:?"expected sha3-256 hash (with 0x prefix) is required"}
    run "supra move run --config $CONFIG --function lottery_multi::history::import_legacy_summary_admin --args u64:$LOTTERY_ID hex:$SUMMARY_HEX hex:$HASH_HEX"
    ;;
  rollback)
    LOTTERY_ID=${1:?"lottery id is required"}
    run "supra move run --config $CONFIG --function lottery_multi::history::rollback_legacy_summary_admin --args u64:$LOTTERY_ID"
    ;;
  classify)
    LOTTERY_ID=${1:?"lottery id is required"}
    PRIMARY_TYPE=${2:?"primary type (u8) is required"}
    TAGS_MASK=${3:?"tags mask (u64) is required"}
    run "supra move run --config $CONFIG --function lottery_multi::history::update_legacy_classification_admin --args u64:$LOTTERY_ID u8:$PRIMARY_TYPE u64:$TAGS_MASK"
    ;;
  status)
    LOTTERY_ID=${1:?"lottery id is required"}
    view "supra move view --config $CONFIG --function lottery_multi::history::is_legacy_summary --args u64:$LOTTERY_ID"
    ;;
  list)
    FROM=${1:-0}
    LIMIT=${2:-10}
    view "supra move view --config $CONFIG --function lottery_multi::history::list_finalized --args u64:$FROM u64:$LIMIT"
    ;;
  dry-run)
    if [[ $# -lt 1 ]]; then
      echo "summary path is required" >&2
      exit 1
    fi
    SUMMARY_PATH=$1
    shift || true
    SUPRA_HISTORY_BACKFILL_CONFIG="$CONFIG" PYTHONPATH="$PROJECT_ROOT" python3 -m supra.tools.history_backfill_dry_run "$SUMMARY_PATH" "$@"
    ;;
  *)
    cat <<EOF >&2
Unknown command: $COMMAND
Supported commands:
  import <lottery_id> <summary_hex> <hash_hex>
  rollback <lottery_id>
  classify <lottery_id> <primary_type> <tags_mask>
  status <lottery_id>
  list [from] [limit]
  dry-run <summary_path> [--lottery-id <id>] [--hex-output path] [--hash-output path]
EOF
    exit 1
    ;;
esac
