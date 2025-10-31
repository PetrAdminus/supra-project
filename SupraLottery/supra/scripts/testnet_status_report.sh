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

supra_cli_info "РСЃРїРѕР»СЊР·СѓРµРј РїСЂРѕС„РёР»СЊ Supra CLI: ${PROFILE}"
if [[ -n ${SUPRA_CONFIG:-} ]]; then
  supra_cli_info "РљРѕРЅС„РёРі CLI: ${SUPRA_CONFIG}"
else
  supra_cli_warn "SUPRA_CONFIG РЅРµ Р·Р°РґР°РЅ вЂ” РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ Р°РєС‚РёРІРЅС‹Р№ РїСЂРѕС„РёР»СЊ Supra CLI РІРЅСѓС‚СЂРё РєРѕРЅС‚РµР№РЅРµСЂР°"
fi
supra_cli_info "РђРґСЂРµСЃ Р»РѕС‚РµСЂРµРё: ${LOTTERY_ADDR}"
supra_cli_info "РђРґСЂРµСЃ РєР»РёРµРЅС‚Р° РґРµРїРѕР·РёС‚Р°: ${CLIENT_ADDR}"
supra_cli_info "РњРѕРґСѓР»СЊ РґРµРїРѕР·РёС‚Р°: ${DEPOSIT_ADDR}::deposit"

run_view() {
  local title=${1:?}
  shift
  printf '\n[view] %s\n' "${title}"
  supra_cli_move_view "$*"
}

run_view "lottery::core_main_v2::get_lottery_status" "--function-id ${LOTTERY_ADDR}::core_main_v2::get_lottery_status"
run_view "lottery::core_main_v2::get_whitelist_status" "--function-id ${LOTTERY_ADDR}::core_main_v2::get_whitelist_status"
run_view "lottery::core_main_v2::get_vrf_request_config" "--function-id ${LOTTERY_ADDR}::core_main_v2::get_vrf_request_config"
run_view "lottery::core_main_v2::get_client_whitelist_snapshot" "--function-id ${LOTTERY_ADDR}::core_main_v2::get_client_whitelist_snapshot"
run_view "lottery::core_main_v2::get_consumer_whitelist_snapshot" "--function-id ${LOTTERY_ADDR}::core_main_v2::get_consumer_whitelist_snapshot"

run_view "deposit::checkMinBalanceClient" "--function-id ${DEPOSIT_ADDR}::deposit::checkMinBalanceClient --args address:${CLIENT_ADDR}"
run_view "deposit::checkClientFund" "--function-id ${DEPOSIT_ADDR}::deposit::checkClientFund --args address:${CLIENT_ADDR}"
run_view "deposit::isMinimumBalanceReached" "--function-id ${DEPOSIT_ADDR}::deposit::isMinimumBalanceReached --args address:${CLIENT_ADDR}"
run_view "deposit::listAllWhitelistedContractByClient" "--function-id ${DEPOSIT_ADDR}::deposit::listAllWhitelistedContractByClient --args address:${CLIENT_ADDR}"
run_view "deposit::getContractDetails (Р»РѕС‚РµСЂРµСЏ)" "--function-id ${DEPOSIT_ADDR}::deposit::getContractDetails --args address:${LOTTERY_ADDR}"

printf '\n[info] Р”Р»СЏ СЃРѕР±С‹С‚РёР№ РёСЃРїРѕР»СЊР·СѓР№С‚Рµ СЃРєСЂРёРїС‚ testnet_smoke_test.sh РёР»Рё СЃРїСЂР°РІРѕС‡РЅРёРє dvrf_event_monitoring.md\n'
