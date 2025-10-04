#!/bin/bash
set -euo pipefail

# Report the current status of the Supra Lottery subscription and deposit.
# Requires the helper functions from lib/supra_cli.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/supra_cli.sh
source "${SCRIPT_DIR}/lib/supra_cli.sh"

supra_cli_require_env PROFILE LOTTERY_ADDR DEPOSIT_ADDR
supra_cli_init "${PROFILE}"

CLIENT_ADDR="${CLIENT_ADDR:-$LOTTERY_ADDR}"

supra_cli_info "Используем профиль Supra CLI: ${PROFILE}"
if [[ -n ${SUPRA_CONFIG:-} ]]; then
  supra_cli_info "Конфиг CLI: ${SUPRA_CONFIG}"
else
  supra_cli_warn "SUPRA_CONFIG не задан — используется активный профиль Supra CLI внутри контейнера"
fi
supra_cli_info "Адрес лотереи: ${LOTTERY_ADDR}"
supra_cli_info "Адрес клиента депозита: ${CLIENT_ADDR}"
supra_cli_info "Модуль депозита: ${DEPOSIT_ADDR}::deposit"

run_view() {
  local title=${1:?}
  shift
  printf '\n[view] %s\n' "${title}"
  supra_cli_move_view "$*"
}

run_view "lottery::main_v2::get_lottery_status" "--function-id ${LOTTERY_ADDR}::main_v2::get_lottery_status"
run_view "lottery::main_v2::get_whitelist_status" "--function-id ${LOTTERY_ADDR}::main_v2::get_whitelist_status"
run_view "lottery::main_v2::get_vrf_request_config" "--function-id ${LOTTERY_ADDR}::main_v2::get_vrf_request_config"
run_view "lottery::main_v2::get_client_whitelist_snapshot" "--function-id ${LOTTERY_ADDR}::main_v2::get_client_whitelist_snapshot"
run_view "lottery::main_v2::get_consumer_whitelist_snapshot" "--function-id ${LOTTERY_ADDR}::main_v2::get_consumer_whitelist_snapshot"

run_view "deposit::checkMinBalanceClient" "--function-id ${DEPOSIT_ADDR}::deposit::checkMinBalanceClient --args address:${CLIENT_ADDR}"
run_view "deposit::checkClientFund" "--function-id ${DEPOSIT_ADDR}::deposit::checkClientFund --args address:${CLIENT_ADDR}"
run_view "deposit::isMinimumBalanceReached" "--function-id ${DEPOSIT_ADDR}::deposit::isMinimumBalanceReached --args address:${CLIENT_ADDR}"
run_view "deposit::listAllWhitelistedContractByClient" "--function-id ${DEPOSIT_ADDR}::deposit::listAllWhitelistedContractByClient --args address:${CLIENT_ADDR}"
run_view "deposit::getContractDetails (лотерея)" "--function-id ${DEPOSIT_ADDR}::deposit::getContractDetails --args address:${LOTTERY_ADDR}"

printf '\n[info] Для событий используйте скрипт testnet_smoke_test.sh или справочник dvrf_event_monitoring.md\n'
