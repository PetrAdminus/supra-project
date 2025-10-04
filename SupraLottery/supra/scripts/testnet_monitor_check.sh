#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/supra_cli.sh
source "${SCRIPT_DIR}/lib/supra_cli.sh"

supra_cli_require_env PROFILE LOTTERY_ADDR DEPOSIT_ADDR MAX_GAS_PRICE MAX_GAS_LIMIT VERIFICATION_GAS_VALUE
supra_cli_init "${PROFILE}"

CLIENT_ADDR="${CLIENT_ADDR:-$LOTTERY_ADDR}"
MONITOR_MARGIN="${MONITOR_MARGIN:-0.15}"
REQUEST_WINDOW="${REQUEST_WINDOW:-30}"

supra_cli_info "Профиль Supra CLI: ${PROFILE}"
if [[ -n ${SUPRA_CONFIG:-} ]]; then
  supra_cli_info "Используем конфиг: ${SUPRA_CONFIG}"
fi
supra_cli_info "Адрес лотереи: ${LOTTERY_ADDR}"
supra_cli_info "Клиент депозита: ${CLIENT_ADDR}"

supra_cli_info "Вычисляем ожидаемый минимальный баланс через calc_min_balance.py"
CALC_JSON=$(python "${SCRIPT_DIR}/calc_min_balance.py" \
  --max-gas-price "${MAX_GAS_PRICE}" \
  --max-gas-limit "${MAX_GAS_LIMIT}" \
  --verification-gas "${VERIFICATION_GAS_VALUE}" \
  --margin "${MONITOR_MARGIN}" \
  --window "${REQUEST_WINDOW}" \
  --json)

supra_cli_info "Получаем on-chain данные депозита"
FUND_JSON=$(supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkClientFund --args address:${CLIENT_ADDR}")
MIN_JSON=$(supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::checkMinBalanceClient --args address:${CLIENT_ADDR}")
REACHED_JSON=$(supra_cli_move_view "--function-id ${DEPOSIT_ADDR}::deposit::isMinimumBalanceReached --args address:${CLIENT_ADDR}")

export CALC_JSON FUND_JSON MIN_JSON REACHED_JSON
export PROFILE LOTTERY_ADDR CLIENT_ADDR DEPOSIT_ADDR MONITOR_MARGIN REQUEST_WINDOW
export EXPECTED_MIN_BALANCE="${MIN_BALANCE_LIMIT:-}"

python - <<'PY'
import json
import os
import sys
from typing import Any, Dict


def decode(node: Any) -> Any:
    if isinstance(node, list):
        return [decode(item) for item in node]
    if isinstance(node, dict):
        for key in ("u8", "u16", "u32", "u64", "u128", "u256"):
            if key in node:
                return int(node[key])
        if "bool" in node:
            value = node["bool"]
            if isinstance(value, str):
                return value.lower() == "true"
            return bool(value)
        if "address" in node:
            return node["address"]
        if "string" in node:
            return node["string"]
        if "bytes" in node:
            return node["bytes"]
        if "vector" in node:
            return [decode(item) for item in node["vector"]]
        if "struct" in node:
            struct = node["struct"]
            fields = struct.get("fields", [])
            type_tag = struct.get("type", "")
            values: Dict[str, Any] = {field["name"]: decode(field["value"]) for field in fields}
            if type_tag.endswith("::option::Option"):
                vec = values.get("vec")
                if isinstance(vec, list) and vec:
                    return vec[0]
                return None
            return values
    return node


def load_json(name: str) -> Dict[str, Any]:
    raw = os.environ.get(name)
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"[error] Невозможно разобрать {name}: {exc}", file=sys.stderr)
        sys.exit(2)


calc = load_json("CALC_JSON")
fund_raw = load_json("FUND_JSON")
min_raw = load_json("MIN_JSON")
reached_raw = load_json("REACHED_JSON")

result_summary: Dict[str, Any] = {
    "profile": os.environ.get("PROFILE"),
    "lottery_addr": os.environ.get("LOTTERY_ADDR"),
    "client_addr": os.environ.get("CLIENT_ADDR"),
    "deposit_module": os.environ.get("DEPOSIT_ADDR"),
    "monitor_margin": float(os.environ.get("MONITOR_MARGIN", "0")),
    "request_window": int(os.environ.get("REQUEST_WINDOW", "30")),
    "calc": calc,
    "onchain": {},
}

violations = []

if fund_raw.get("result"):
    fund_decoded = decode(fund_raw["result"][0])
else:
    fund_decoded = None

if fund_decoded is not None:
    result_summary["onchain"]["checkClientFund"] = fund_decoded
    available = None
    if isinstance(fund_decoded, dict):
        for key in ("available_fund", "available_balance", "available_amount", "available"):
            value = fund_decoded.get(key)
            if value is not None:
                available = int(value)
                break
    result_summary["onchain"]["available_quants"] = str(available) if available is not None else None
else:
    available = None

if min_raw.get("result"):
    min_decoded = decode(min_raw["result"][0])
else:
    min_decoded = None

if min_decoded is not None:
    result_summary["onchain"]["min_balance_client"] = str(min_decoded)

if reached_raw.get("result"):
    min_reached = bool(decode(reached_raw["result"][0]))
else:
    min_reached = None

result_summary["onchain"]["isMinimumBalanceReached"] = min_reached
if min_reached:
    violations.append("DEPOSIT_AT_OR_BELOW_MIN_BALANCE")

calc_min = None
calc_recommended = None
if calc:
    try:
        calc_min = int(calc.get("min_balance"))
        calc_recommended = int(calc.get("recommended_deposit"))
    except (TypeError, ValueError):
        calc_min = None
        calc_recommended = None

expected_min_env = os.environ.get("EXPECTED_MIN_BALANCE")
expected_min = None
if expected_min_env:
    try:
        expected_min = int(expected_min_env)
    except ValueError:
        print(f"[warn] Некорректное значение MIN_BALANCE_LIMIT: {expected_min_env}", file=sys.stderr)
        expected_min = None

checks: Dict[str, Any] = {
    "available_quants": str(available) if available is not None else None,
    "min_balance_onchain": str(min_decoded) if min_decoded is not None else None,
    "min_balance_expected": str(expected_min if expected_min is not None else calc_min) if (expected_min or calc_min) else None,
    "recommended_deposit": str(calc_recommended) if calc_recommended is not None else None,
    "violations": violations,
}

if available is not None:
    if expected_min is not None and available < expected_min:
        violations.append("AVAILABLE_BELOW_EXPECTED_MIN_BALANCE")
    elif expected_min is None and calc_min is not None and available < calc_min:
        violations.append("AVAILABLE_BELOW_CALCULATED_MIN_BALANCE")

    if calc_recommended is not None and available < calc_recommended:
        checks.setdefault("warnings", []).append("available_below_recommended_deposit")

result_summary["checks"] = checks
status = "alert" if violations else "ok"
result_summary["status"] = status

print(json.dumps(result_summary, ensure_ascii=False, indent=2))
if violations:
    sys.exit(1)
PY
