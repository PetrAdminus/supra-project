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
import sys

# Allow relative import when executed from repository root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.append(SCRIPT_DIR)
    sys.path.append(os.path.dirname(SCRIPT_DIR))

from monitor_common import env_default  # type: ignore  # pylint: disable=wrong-import-position
from lib.monitoring import (  # type: ignore  # pylint: disable=wrong-import-position
    DEFAULT_MARGIN,
    DEFAULT_WINDOW,
    CliError,
    ConfigError,
    gather_data,
    monitor_config_from_namespace,
)


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


def main() -> None:
    args = parse_args()
    try:
        config = monitor_config_from_namespace(args)
    except ConfigError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(2)
    try:
        report = gather_data(config)
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
