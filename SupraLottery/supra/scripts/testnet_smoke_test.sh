#!/bin/bash
# Usage: ./testnet_smoke_test.sh <profile_name> <lottery_address> <admin_address>
# Быстрый смоук-тест: покупает 5 билетов, настраивает VRF-запрос и вызывает manual_draw.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/supra_cli.sh"

PROFILE=${1:?"Profile name is required"}
LOTTERY_ADDR=${2:?"Lottery contract address is required"}
ADMIN_ADDR=${3:?"Admin address is required"}

TICKETS_REQUIRED=${TICKETS_REQUIRED:-5}
TICKET_FUND=${TICKET_FUND:-100000000}
RNG_COUNT=${RNG_COUNT:-1}
NUM_CONFIRMATIONS=${NUM_CONFIRMATIONS:-1}
CLIENT_SEED=${CLIENT_SEED:-$(date +%s)}

supra_cli_init "${PROFILE}"

supra_cli_info "Profile: ${PROFILE}"
supra_cli_info "Lottery: ${LOTTERY_ADDR}"
supra_cli_info "Admin address: ${ADMIN_ADDR}"
supra_cli_info "Tickets to buy: ${TICKETS_REQUIRED}"

supra_cli_info "Ensuring primary store for admin"
STORE_STATUS=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::treasury_v1::store_registered --args address:${ADMIN_ADDR}" | tr -d '\r')
if [[ "${STORE_STATUS}" == *"false"* ]]; then
  supra_cli_move_run "--function-id ${LOTTERY_ADDR}::treasury_v1::register_store_for --args address:${ADMIN_ADDR} --assume-yes"
fi

supra_cli_info "Minting ${TICKET_FUND} tokens to admin"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::treasury_v1::mint_to --args address:${ADMIN_ADDR} u64:${TICKET_FUND} --assume-yes"

supra_cli_info "Reading ticket price"
PRICE_JSON=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_ticket_price" | tr -d '\r')
TICKET_PRICE=$(python - "$PRICE_JSON" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])["result"][0]
    print(int(data))
except Exception:
    sys.exit(1)
PY
)
if [[ -z "${TICKET_PRICE}" ]]; then
  supra_cli_warn "Не удалось получить ticket_price; продолжайте вручную"
else
  supra_cli_info "Ticket price: ${TICKET_PRICE} quants"
  if (( TICKET_FUND < TICKETS_REQUIRED * TICKET_PRICE )); then
    supra_cli_warn "TICKET_FUND (${TICKET_FUND}) меньше суммы, необходимой для ${TICKETS_REQUIRED} билетов ($((TICKETS_REQUIRED * TICKET_PRICE)))."
    supra_cli_warn "Увеличьте переменную TICKET_FUND или уменьшите количество билетов."
  fi
fi

supra_cli_info "Buying tickets"
for ((i = 1; i <= TICKETS_REQUIRED; ++i)); do
  supra_cli_info "Ticket #${i}"
  supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::buy_ticket --assume-yes"
  sleep 1
done

supra_cli_info "Checking lottery status"
STATUS_JSON=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_lottery_status" | tr -d '\r')
python - "$STATUS_JSON" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])["result"][0]
except Exception:
    sys.exit(10)
print("draw_scheduled:", data.get("draw_scheduled"))
print("pending_request:", data.get("pending_request"))
PY

supra_cli_info "Configuring VRF request"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::configure_vrf_request --args u8:${RNG_COUNT} u64:${NUM_CONFIRMATIONS} u64:${CLIENT_SEED} --assume-yes"

supra_cli_info "Calling manual_draw"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::manual_draw --assume-yes"

supra_cli_info "Smoke test triggered manual_draw. Monitor DrawHandledEvent via docs/dvrf_event_monitoring.md"
