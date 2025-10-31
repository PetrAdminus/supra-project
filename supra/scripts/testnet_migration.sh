#!/bin/bash
# Usage: ./testnet_migration.sh /supra/configs/testnet.yaml 0xDEPOSIT_ADDR 0xLOTTERY_ADDR
set -euo pipefail
CONFIG=${1:?"Path to Supra CLI config is required"}
DEPOSIT_ADDR=${2:?"Deposit contract address required"}
LOTTERY_ADDR=${3:?"Lottery contract address required"}

MAX_GAS_PRICE=${MAX_GAS_PRICE:-100}
MAX_GAS_LIMIT=${MAX_GAS_LIMIT:-200000}
CALLBACK_GAS_PRICE=${CALLBACK_GAS_PRICE:-10}
CALLBACK_GAS_LIMIT=${CALLBACK_GAS_LIMIT:-50000}
MIN_BALANCE_LIMIT=${MIN_BALANCE_LIMIT:-1000000000}
RNG_COUNT=${RNG_COUNT:-1}
CLIENT_SEED=${CLIENT_SEED:-0}
DEPOSIT_AMOUNT=${DEPOSIT_AMOUNT:-2000000000}
FA_SEED_HEX=${FA_SEED_HEX:-0x6c6f74746572795f66615f73656564}
FA_NAME_HEX=${FA_NAME_HEX:-0x4c6f7474657279205469636b6574}
FA_SYMBOL_HEX=${FA_SYMBOL_HEX:-0x4c4f54}
FA_DECIMALS=${FA_DECIMALS:-9}
FA_ICON_HEX=${FA_ICON_HEX:-0x}
FA_PROJECT_HEX=${FA_PROJECT_HEX:-0x}
PLAYER_MINTS=${PLAYER_MINTS:-}

run() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

view() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

echo "[info] Checking fungible asset state"
TREASURY_STATUS=$(view "supra move view --config $CONFIG --function lottery::treasury_v1::is_initialized" | tr -d '\r')
if [[ "$TREASURY_STATUS" == *"false"* ]]; then
  echo "[info] Initializing lottery treasury token"
  run "supra move run --config $CONFIG --function lottery::treasury_v1::init_token --args hex:$FA_SEED_HEX hex:$FA_NAME_HEX hex:$FA_SYMBOL_HEX u8:$FA_DECIMALS hex:$FA_ICON_HEX hex:$FA_PROJECT_HEX"
else
  echo "[info] Treasury already initialized"
fi

echo "[info] Treasury metadata snapshot"
view "supra move view --config $CONFIG --function lottery::treasury_v1::metadata_summary"

if [[ -n "${PLAYER_MINTS}" ]]; then
  first_target=${PLAYER_MINTS%%,*}
  if [[ -n "$first_target" && "$first_target" == *":"* ]]; then
    first_addr=${first_target%%:*}
    echo "[info] Account status for $first_addr"
    view "supra move view --config $CONFIG --function lottery::treasury_v1::account_status --args address:$first_addr"
    view "supra move view --config $CONFIG --function lottery::treasury_v1::account_extended_status --args address:$first_addr"
  fi
fi

if [[ -n "$PLAYER_MINTS" ]]; then
  IFS=',' read -ra MINT_TARGETS <<< "$PLAYER_MINTS"
  for target in "${MINT_TARGETS[@]}"; do
    addr=${target%%:*}
    amount=${target##*:}
    if [[ -z "$addr" || -z "$amount" || "$addr" == "$amount" ]]; then
      continue
    fi
    echo "[info] Registering primary store for $addr"
    run "supra move run --config $CONFIG --function lottery::treasury_v1::register_store_for --args address:$addr"
    echo "[info] Minting $amount units to $addr"
    run "supra move run --config $CONFIG --function lottery::treasury_v1::mint_to --args address:$addr u64:$amount"
  done
fi

echo "[info] Calculating min balance"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::getMinBalanceLimit --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT"

echo "[info] Migrating client"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --amount u128:$DEPOSIT_AMOUNT"

echo "[info] Whitelisting client"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT"

echo "[info] Whitelisting contract"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::addContractToWhitelist --args address:$LOTTERY_ADDR u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT"

echo "[info] Recording snapshots"
run "supra move run --config $CONFIG --function lottery::core_main_v2::record_client_whitelist_snapshot --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$MIN_BALANCE_LIMIT"
run "supra move run --config $CONFIG --function lottery::core_main_v2::record_consumer_whitelist_snapshot --args u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT"

echo "[info] Configuring VRF request"
run "supra move run --config $CONFIG --function lottery::core_main_v2::configure_vrf_request --args u8:$RNG_COUNT u64:$CLIENT_SEED"

echo "[info] Publish package (optional)"
run "supra move publish --config $CONFIG --package-dir /supra/move_workspace/lottery"

echo "[info] Requesting draw"
run "supra move run --config $CONFIG --function lottery::core_main_v2::request_draw"

