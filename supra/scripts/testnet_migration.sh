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

run() {
  docker compose run --rm --entrypoint bash supra_cli -lc "$1"
}

echo "[info] Calculating min balance"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::getMinBalanceLimit --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT"

echo "[info] Migrating client"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --amount u128:$DEPOSIT_AMOUNT"

echo "[info] Whitelisting client"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT"

echo "[info] Whitelisting contract"
run "supra move run --config $CONFIG --function $DEPOSIT_ADDR::deposit::addContractToWhitelist --args address:$LOTTERY_ADDR u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT"

echo "[info] Recording snapshots"
run "supra move run --config $CONFIG --function lottery::main_v2::record_client_whitelist_snapshot --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$MIN_BALANCE_LIMIT"
run "supra move run --config $CONFIG --function lottery::main_v2::record_consumer_whitelist_snapshot --args u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT"

echo "[info] Configuring VRF request"
run "supra move run --config $CONFIG --function lottery::main_v2::configure_vrf_request --args u8:$RNG_COUNT u64:$CLIENT_SEED"

echo "[info] Publish package (optional)"
run "supra move publish --config $CONFIG --package-dir /supra/move_workspace/lottery"

echo "[info] Requesting draw"
run "supra move run --config $CONFIG --function lottery::main_v2::request_draw"
