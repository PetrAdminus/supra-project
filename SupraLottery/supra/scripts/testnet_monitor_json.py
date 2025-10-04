#!/usr/bin/env python3
"""Aggregate Supra dVRF subscription status into JSON.

The script reuses calc_min_balance to compute theoretical limits and
collects on-chain data via Supra CLI view functions. The output is
suitable for automation (AutoFi, CI, cron) and can fail when the
current deposit balance is below the minimum threshold.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

# Allow relative import when executed from repository root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.append(SCRIPT_DIR)
    sys.path.append(os.path.dirname(SCRIPT_DIR))

from calc_min_balance import calculate  # type: ignore  # pylint: disable=wrong-import-position
from monitor_common import env_default  # type: ignore  # pylint: disable=wrong-import-position

DEFAULT_MARGIN = 0.15
DEFAULT_WINDOW = 30


class CliError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    max_gas_price_default = env_default("MAX_GAS_PRICE", int)
    max_gas_limit_default = env_default("MAX_GAS_LIMIT", int)
    verification_gas_default = env_default("VERIFICATION_GAS_VALUE", int)
    margin_default = env_default("MIN_BALANCE_MARGIN", float)
    window_default = env_default("MIN_BALANCE_WINDOW", int)

    parser = argparse.ArgumentParser(
        description="Собрать ключевые view-данные Supra dVRF и вывести JSON"
    )
    parser.add_argument("--profile", default=os.environ.get("PROFILE"), help="имя профиля Supra CLI")
    parser.add_argument(
        "--lottery-addr",
        default=os.environ.get("LOTTERY_ADDR"),
        help="адрес контракта лотереи (0x...)",
    )
    parser.add_argument(
        "--deposit-addr",
        default=os.environ.get("DEPOSIT_ADDR"),
        help="адрес модуля deposit (0x...)",
    )
    parser.add_argument(
        "--client-addr",
        default=os.environ.get("CLIENT_ADDR"),
        help="адрес клиента dVRF (по умолчанию совпадает с профилем/контрактом)",
    )
    parser.add_argument(
        "--supra-cli-bin",
        default=os.environ.get("SUPRA_CLI_BIN", "/supra/supra"),
        help="путь к бинарнику Supra CLI",
    )
    parser.add_argument(
        "--supra-config",
        default=os.environ.get("SUPRA_CONFIG"),
        help="путь к YAML-конфигу, будет передан через SUPRA_CONFIG",
    )
    parser.add_argument(
        "--max-gas-price",
        type=int,
        default=max_gas_price_default,
        help="max_gas_price для расчёта минимального депозита",
    )
    parser.add_argument(
        "--max-gas-limit",
        type=int,
        default=max_gas_limit_default,
        help="max_gas_limit для расчёта минимального депозита",
    )
    parser.add_argument(
        "--verification-gas",
        type=int,
        default=verification_gas_default,
        help="verification_gas_value для расчёта",
    )
    parser.add_argument(
        "--margin",
        type=float,
        default=margin_default if margin_default is not None else DEFAULT_MARGIN,
        help="запас к минимальному балансу (доля)",
    )
    parser.add_argument(
        "--window",
        type=int,
        default=window_default if window_default is not None else DEFAULT_WINDOW,
        help="окно запросов для формулы min_balance",
    )
    parser.add_argument(
        "--fail-on-low",
        action="store_true",
        help="возвращать код 1, если баланс ниже расчётного min_balance",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="печать отформатированного JSON (иначе одна строка)",
    )
    args = parser.parse_args()

    if not args.profile:
        parser.error("Требуется --profile или переменная окружения PROFILE")
    if not args.lottery_addr:
        parser.error("Требуется --lottery-addr или переменная LOTTERY_ADDR")
    if not args.deposit_addr:
        parser.error("Требуется --deposit-addr или переменная DEPOSIT_ADDR")
    if args.max_gas_price is None or args.max_gas_limit is None or args.verification_gas is None:
        parser.error(
            "Нужны max_gas_price, max_gas_limit и verification_gas (через аргументы или переменные окружения)"
        )
    if args.margin < 0:
        parser.error("margin не может быть отрицательным")
    if args.window <= 0:
        parser.error("window должно быть положительным")

    if not args.client_addr:
        # По умолчанию используем адрес контракта
        args.client_addr = args.lottery_addr
    return args


def run_cli(args: argparse.Namespace, extra: List[str]) -> Dict[str, Any]:
    env = os.environ.copy()
    if args.supra_config:
        env["SUPRA_CONFIG"] = args.supra_config
    cmd = [args.supra_cli_bin] + extra
    try:
        completed = subprocess.run(
            cmd,
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        raise CliError(
            f"Ошибка Supra CLI ({' '.join(cmd)}): {exc.stderr or exc.stdout}"
        ) from exc

    output = completed.stdout.strip()
    if not output:
        raise CliError(f"Пустой вывод Supra CLI для команды: {' '.join(cmd)}")
    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        raise CliError(f"Неверный JSON от Supra CLI: {output}") from exc


def move_view(args: argparse.Namespace, function_id: str, call_args: Optional[List[str]] = None) -> Any:
    cli_args = [
        "move",
        "tool",
        "view",
        "--profile",
        args.profile,
        "--function-id",
        function_id,
    ]
    if call_args:
        cli_args.append("--args")
        cli_args.extend(call_args)
    data = run_cli(args, cli_args)
    return data.get("result")


def flatten_single_value(value: Any) -> Any:
    if isinstance(value, list) and len(value) == 1:
        return value[0]
    return value


def gather_data(args: argparse.Namespace) -> Dict[str, Any]:
    calculation = calculate(
        args.max_gas_price,
        args.max_gas_limit,
        args.verification_gas,
        args.margin,
        args.window,
    )

    lottery_prefix = f"{args.lottery_addr}::main_v2"
    deposit_prefix = f"{args.deposit_addr}::deposit"

    lottery_status = move_view(args, f"{lottery_prefix}::get_lottery_status")
    vrf_config = move_view(args, f"{lottery_prefix}::get_vrf_request_config")
    whitelist_status = move_view(args, f"{lottery_prefix}::get_whitelist_status")

    deposit_balance = move_view(
        args,
        f"{deposit_prefix}::checkClientFund",
        [f"address:{args.client_addr}"],
    )
    min_balance_on_chain = move_view(
        args,
        f"{deposit_prefix}::checkMinBalanceClient",
        [f"address:{args.client_addr}"],
    )
    min_balance_reached = move_view(
        args,
        f"{deposit_prefix}::isMinimumBalanceReached",
        [f"address:{args.client_addr}"],
    )
    contract_details = move_view(
        args,
        f"{deposit_prefix}::getContractDetails",
        [f"address:{args.lottery_addr}"],
    )
    subscription_info = move_view(
        args,
        f"{deposit_prefix}::getSubscriptionInfoByClient",
        [f"address:{args.client_addr}"],
    )

    whitelisted_contracts = move_view(
        args,
        f"{deposit_prefix}::listAllWhitelistedContractByClient",
        [f"address:{args.client_addr}"],
    )

    max_gas_price_on_chain = move_view(
        args,
        f"{deposit_prefix}::checkMaxGasPriceClient",
        [f"address:{args.client_addr}"],
    )
    max_gas_limit_on_chain = move_view(
        args,
        f"{deposit_prefix}::checkMaxGasLimitClient",
        [f"address:{args.client_addr}"],
    )

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "profile": args.profile,
        "lottery_addr": args.lottery_addr,
        "deposit_addr": args.deposit_addr,
        "client_addr": args.client_addr,
        "calculation": calculation.to_json(),
        "lottery": {
            "status": lottery_status,
            "vrf_request_config": vrf_config,
            "whitelist_status": whitelist_status,
        },
        "deposit": {
            "balance": flatten_single_value(deposit_balance),
            "min_balance": flatten_single_value(min_balance_on_chain),
            "min_balance_reached": flatten_single_value(min_balance_reached),
            "contract_details": contract_details,
            "subscription_info": subscription_info,
            "whitelisted_contracts": whitelisted_contracts,
            "max_gas_price": flatten_single_value(max_gas_price_on_chain),
            "max_gas_limit": flatten_single_value(max_gas_limit_on_chain),
        },
    }


def main() -> None:
    args = parse_args()
    try:
        report = gather_data(args)
    except CliError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(2)

    output = json.dumps(report, indent=2 if args.pretty else None, ensure_ascii=False)
    print(output)

    if args.fail_on_low:
        balance = int(report["deposit"]["balance"])
        min_balance = int(report["calculation"]["min_balance"])
        if balance < min_balance:
            print(
                f"[error] баланс {balance} ниже расчётного min_balance {min_balance}",
                file=sys.stderr,
            )
            sys.exit(1)


if __name__ == "__main__":
    main()
