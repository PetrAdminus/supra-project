#!/bin/bash
# Usage: ./testnet_migration.sh <profile_name> <lottery_address> [deposit_address]
# Environment:
#   (см. supra/scripts/testnet_env.example для готового набора переменных)
#   SUPRA_CONFIG   — (optional) путь к YAML конфигу Supra CLI, будет экспортирован как переменная окружения.
#   MAX_GAS_PRICE, MAX_GAS_LIMIT, CALLBACK_GAS_PRICE, CALLBACK_GAS_LIMIT, VERIFICATION_GAS_VALUE — лимиты газа.
#   INITIAL_DEPOSIT — сумма депозита (u64, по умолчанию 2_000_000_000 quants).
#   MIN_BALANCE_LIMIT — при необходимости переопределяет рассчитанный минимум (u128).
#   RNG_COUNT, CLIENT_SEED — параметры запроса VRF.
#   PLAYER_MINTS — список "адрес:сумма" через запятую для регистрации store и минта.
#   AGGREGATOR_ADDR — адрес Supra VRF агрегатора для whitelisting.
#   CONSUMER_ADDRS — список дополнительных потребителей VRF через запятую.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/supra_cli.sh"

PROFILE=${1:?"Profile name is required"}
LOTTERY_ADDR=${2:?"Lottery contract address is required"}
DEPOSIT_ADDR=${3:-0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e}

MAX_GAS_PRICE=${MAX_GAS_PRICE:-1000}
MAX_GAS_LIMIT=${MAX_GAS_LIMIT:-500000}
CALLBACK_GAS_PRICE=${CALLBACK_GAS_PRICE:-100}
CALLBACK_GAS_LIMIT=${CALLBACK_GAS_LIMIT:-150000}
VERIFICATION_GAS_VALUE=${VERIFICATION_GAS_VALUE:-25000}
INITIAL_DEPOSIT=${INITIAL_DEPOSIT:-2000000000}
RNG_COUNT=${RNG_COUNT:-1}
NUM_CONFIRMATIONS=${NUM_CONFIRMATIONS:-1}
CLIENT_SEED=${CLIENT_SEED:-0}

supra_cli_init "${PROFILE}"

calc_min_balance() {
  python - <<PY
max_gas_price = int(${MAX_GAS_PRICE})
max_gas_limit = int(${MAX_GAS_LIMIT})
verification_gas = int(${VERIFICATION_GAS_VALUE})
print(30 * max_gas_price * (max_gas_limit + verification_gas))
PY
}

if [[ -z "${MIN_BALANCE_LIMIT:-}" ]]; then
  MIN_BALANCE_LIMIT=$(calc_min_balance)
fi

if (( INITIAL_DEPOSIT < MIN_BALANCE_LIMIT )); then
  supra_cli_warn "INITIAL_DEPOSIT (${INITIAL_DEPOSIT}) ниже рассчитанного минимального баланса (${MIN_BALANCE_LIMIT})."
  supra_cli_warn "Увеличьте INITIAL_DEPOSIT или задайте MIN_BALANCE_LIMIT вручную перед повторным запуском."
  exit 1
fi

supra_cli_info "Using profile ${PROFILE}"
supra_cli_info "Lottery address ${LOTTERY_ADDR}"
supra_cli_info "Deposit module ${DEPOSIT_ADDR}"
supra_cli_info "Gas config: max_gas_price=${MAX_GAS_PRICE}, max_gas_limit=${MAX_GAS_LIMIT}, callback_gas_price=${CALLBACK_GAS_PRICE}, callback_gas_limit=${CALLBACK_GAS_LIMIT}, verification_gas_value=${VERIFICATION_GAS_VALUE}"
supra_cli_info "Calculated min balance: ${MIN_BALANCE_LIMIT}"

supra_cli_info "Checking fungible asset initialization"
TREASURY_STATUS=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::treasury_v1::is_initialized" | tr -d '\r')
if [[ "${TREASURY_STATUS}" == *"false"* ]]; then
  supra_cli_info "Initializing treasury token"
  supra_cli_move_run "--function-id ${LOTTERY_ADDR}::treasury_v1::init_token --args hex:${FA_SEED_HEX:-0x6c6f74746572795f66615f73656564} hex:${FA_NAME_HEX:-0x4c6f7474657279205469636b6574} hex:${FA_SYMBOL_HEX:-0x4c4f54} u8:${FA_DECIMALS:-9} hex:${FA_ICON_HEX:-0x} hex:${FA_PROJECT_HEX:-0x} --assume-yes"
else
  supra_cli_info "Treasury already initialized"
fi

if [[ -n "${PLAYER_MINTS:-}" ]]; then
  IFS=',' read -ra MINT_TARGETS <<< "${PLAYER_MINTS}"
  for target in "${MINT_TARGETS[@]}"; do
    addr=${target%%:*}
    amount=${target##*:}
    if [[ -z "${addr}" || -z "${amount}" || "${addr}" == "${amount}" ]]; then
      supra_cli_warn "Skip malformed mint target '${target}'"
      continue
    fi
    STATUS=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::treasury_v1::store_registered --args address:${addr}" | tr -d '\r' || true)
    if [[ "${STATUS}" == *"true"* ]]; then
      supra_cli_info "Store already registered for ${addr}"
    else
      supra_cli_info "Registering primary store for ${addr}"
      supra_cli_move_run "--function-id ${LOTTERY_ADDR}::treasury_v1::register_store_for --args address:${addr} --assume-yes"
    fi
    supra_cli_info "Minting ${amount} tokens to ${addr}"
    supra_cli_move_run "--function-id ${LOTTERY_ADDR}::treasury_v1::mint_to --args address:${addr} u64:${amount} --assume-yes"
  done
fi

supra_cli_info "Configuring VRF gas"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::configure_vrf_gas --args u128:${MAX_GAS_PRICE} u128:${MAX_GAS_LIMIT} u128:${CALLBACK_GAS_PRICE} u128:${CALLBACK_GAS_LIMIT} u128:${VERIFICATION_GAS_VALUE} --assume-yes"

supra_cli_info "Migrating client in deposit module"
if ! supra_cli_move_run "--function-id ${DEPOSIT_ADDR}::deposit::migrateClient --args u128:${MAX_GAS_PRICE} u128:${MAX_GAS_LIMIT} --assume-yes"; then
  supra_cli_warn "migrateClient failed — убедитесь, что адрес модуля (${DEPOSIT_ADDR}) и лимиты газа указаны верно"
  supra_cli_warn "Если видите FUNCTION_RESOLUTION_FAILURE, проверьте версию Supra CLI и camelCase имя функции"
  exit 1
fi

supra_cli_info "Whitelisting client in deposit module"
if ! supra_cli_move_run "--function-id ${DEPOSIT_ADDR}::deposit::addClientToWhitelist --args u128:${MAX_GAS_PRICE} u128:${MAX_GAS_LIMIT} --assume-yes"; then
  supra_cli_warn "addClientToWhitelist failed — проверьте адрес модуля (${DEPOSIT_ADDR}) и параметры газа"
  supra_cli_warn "При ошибке ECLIENT_NOT_EXIST повторите migrateClient или обратитесь в Supra Support для активации адреса"
  exit 1
fi

supra_cli_info "Creating Supra dVRF subscription"
set +e
if ! supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::create_subscription --args u64:${INITIAL_DEPOSIT} --assume-yes"; then
  supra_cli_warn "create_subscription failed; если видите ECLIENT_NOT_EXIST — убедитесь, что Supra активировала ваш адрес или повторите addClientToWhitelist после апдейта лимитов"
  exit 1
fi
set -e

supra_cli_info "Recording whitelist snapshots"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::record_client_whitelist_snapshot --args u128:${MAX_GAS_PRICE} u128:${MAX_GAS_LIMIT} u128:${MIN_BALANCE_LIMIT} --assume-yes"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::record_consumer_whitelist_snapshot --args u128:${CALLBACK_GAS_PRICE} u128:${CALLBACK_GAS_LIMIT} --assume-yes"
supra_cli_info "Client whitelist snapshot:"
supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_client_whitelist_snapshot"
supra_cli_info "Minimum balance snapshot:"
supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_min_balance_limit_snapshot"
supra_cli_info "Consumer whitelist snapshot:"
supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_consumer_whitelist_snapshot"

supra_cli_info "Checking deposit module settings"
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkMinBalanceClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить checkMinBalanceClient — проверьте адрес модуля и camelCase имя функции"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkMaxGasPriceClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить checkMaxGasPriceClient"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkMaxGasLimitClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить checkMaxGasLimitClient"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::getContractDetails --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить getContractDetails"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkClientFund --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить checkClientFund"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::isMinimumBalanceReached --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить isMinimumBalanceReached"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::countTotalWhitelistedContractByClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить countTotalWhitelistedContractByClient"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::listAllWhitelistedContractByClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить listAllWhitelistedContractByClient"
fi
if ! supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::getSubscriptionInfoByClient --args address:${LOTTERY_ADDR}"; then
  supra_cli_warn "Не удалось получить getSubscriptionInfoByClient"
fi

if [[ -n "${AGGREGATOR_ADDR:-}" ]]; then
  supra_cli_info "Whitelisting callback sender ${AGGREGATOR_ADDR}"
  supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::whitelist_callback_sender --args address:${AGGREGATOR_ADDR} --assume-yes"
fi

if [[ -n "${CONSUMER_ADDRS:-}" ]]; then
  IFS=',' read -ra CONSUMERS <<< "${CONSUMER_ADDRS}"
  for consumer in "${CONSUMERS[@]}"; do
    if [[ -z "${consumer}" ]]; then
      continue
    fi
    supra_cli_info "Whitelisting consumer ${consumer}"
    supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::whitelist_consumer --args address:${consumer} --assume-yes"
  done
fi

supra_cli_info "Configuring VRF request"
supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::configure_vrf_request --args u8:${RNG_COUNT} u64:${NUM_CONFIRMATIONS} u64:${CLIENT_SEED} --assume-yes"

if [[ -n "${PUBLISH_PACKAGE:-}" ]]; then
  supra_cli_info "Publishing Move package"
  supra_cli_move_publish "--package-dir /supra/move_workspace/lottery"
fi

if [[ -n "${REQUEST_DRAW:-}" ]]; then
  supra_cli_info "Checking lottery status before manual_draw"
  STATUS_JSON=$(supra_cli_move_view "--function-id ${LOTTERY_ADDR}::main_v2::get_lottery_status" | tr -d '\r')
  if ! python - "$STATUS_JSON" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])["result"][0]
except Exception:
    sys.exit(10)
if not data.get("draw_scheduled"):
    sys.exit(11)
if data.get("pending_request"):
    sys.exit(12)
PY
then
    case "$?" in
      10)
        supra_cli_warn "Не удалось разобрать ответ get_lottery_status; продолжайте вручную"
        ;;
      11)
        supra_cli_warn "Розыгрыш ещё не запланирован (draw_scheduled = false) — продайте ≥5 билетов"
        exit 1
        ;;
      12)
        supra_cli_warn "Есть активный pending_request — дождитесь DrawHandledEvent перед повторной попыткой"
        exit 1
        ;;
    esac
  fi
  supra_cli_info "Requesting VRF draw via manual_draw"
  supra_cli_move_run "--function-id ${LOTTERY_ADDR}::main_v2::manual_draw --assume-yes"
  supra_cli_info "Tip: monitor DrawRequestedEvent/DrawHandledEvent via 'supra move tool events tail' (см. docs/dvrf_event_monitoring.md)"
fi

supra_cli_info "Migration completed"
