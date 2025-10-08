#!/usr/bin/env python3
"""Shared helpers for Supra dVRF monitoring scripts."""
from __future__ import annotations

import os
import subprocess
import sys
from argparse import ArgumentParser, Namespace
from pathlib import Path
from typing import List, Optional

MONITOR_SCRIPT = Path(__file__).with_name("testnet_monitor_json.py")


class MonitorError(RuntimeError):
    """Raised when Supra CLI or monitor wrapper fails."""


def env_default(name: str, cast: Optional[type] = None):
    """Read environment variable and optionally cast it."""

    value = os.environ.get(name)
    if value is None or cast is None:
        return value
    try:
        return cast(value)
    except ValueError as exc:  # pragma: no cover - defensive conversion guard
        raise MonitorError(f"Не удалось преобразовать переменную {name} к {cast.__name__}") from exc


def add_monitor_arguments(parser: ArgumentParser, include_fail_on_low: bool = True) -> ArgumentParser:
    """Append common Supra CLI arguments to ``argparse`` parser."""

    parser.add_argument("--profile", default=os.environ.get("PROFILE"), help="имя профиля Supra CLI")
    parser.add_argument(
        "--lottery-addr",
        default=os.environ.get("LOTTERY_ADDR"),
        help="адрес контракта лотереи (0x...)",
    )
    parser.add_argument(
        "--hub-addr",
        default=os.environ.get("HUB_ADDR"),
        help="адрес VRF-хаба (по умолчанию совпадает с контрактом)",
    )
    parser.add_argument(
        "--factory-addr",
        default=os.environ.get("FACTORY_ADDR"),
        help="адрес фабрики лотерей (по умолчанию совпадает с контрактом)",
    )
    parser.add_argument(
        "--deposit-addr",
        default=os.environ.get("DEPOSIT_ADDR"),
        help="адрес модуля deposit (0x...)",
    )
    parser.add_argument(
        "--client-addr",
        default=os.environ.get("CLIENT_ADDR"),
        help="адрес клиента dVRF (по умолчанию совпадает с контрактом)",
    )
    parser.add_argument(
        "--supra-cli-bin",
        default=os.environ.get("SUPRA_CLI_BIN", "/supra/supra"),
        help="путь к бинарнику Supra CLI",
    )
    parser.add_argument(
        "--supra-config",
        default=os.environ.get("SUPRA_CONFIG"),
        help="путь к YAML-конфигу Supra CLI",
    )
    parser.add_argument(
        "--max-gas-price",
        type=int,
        default=env_default("MAX_GAS_PRICE", int),
        help="max_gas_price для расчёта min_balance",
    )
    parser.add_argument(
        "--max-gas-limit",
        type=int,
        default=env_default("MAX_GAS_LIMIT", int),
        help="max_gas_limit для расчёта min_balance",
    )
    parser.add_argument(
        "--verification-gas",
        type=int,
        default=env_default("VERIFICATION_GAS_VALUE", int),
        help="verification_gas_value для расчёта min_balance",
    )
    parser.add_argument(
        "--margin",
        type=float,
        default=env_default("MIN_BALANCE_MARGIN", float),
        help="запас к минимальному балансу (доля)",
    )
    parser.add_argument(
        "--window",
        type=int,
        default=env_default("MIN_BALANCE_WINDOW", int),
        help="окно запросов для формулы min_balance",
    )
    parser.add_argument(
        "--lottery-ids",
        default=os.environ.get("LOTTERY_IDS"),
        help="список идентификаторов лотерей (через запятую или JSON)",
    )
    if include_fail_on_low:
        parser.add_argument(
            "--fail-on-low",
            action="store_true",
            help="возвращать код 1, если баланс ниже min_balance (передаётся monitor_json)",
        )
    return parser


def append_arg(args: List[str], name: str, value: Optional[str]) -> None:
    if value is None:
        return
    args.extend([name, value])


def build_monitor_args(ns: Namespace, include_fail_on_low: bool = True) -> List[str]:
    """Convert namespace into CLI arguments for ``testnet_monitor_json.py``."""

    monitor_args: List[str] = []
    append_arg(monitor_args, "--profile", getattr(ns, "profile", None))
    append_arg(monitor_args, "--lottery-addr", getattr(ns, "lottery_addr", None))
    append_arg(monitor_args, "--hub-addr", getattr(ns, "hub_addr", None))
    append_arg(monitor_args, "--factory-addr", getattr(ns, "factory_addr", None))
    append_arg(monitor_args, "--deposit-addr", getattr(ns, "deposit_addr", None))
    append_arg(monitor_args, "--client-addr", getattr(ns, "client_addr", None))
    append_arg(monitor_args, "--supra-cli-bin", getattr(ns, "supra_cli_bin", None))
    append_arg(monitor_args, "--supra-config", getattr(ns, "supra_config", None))
    if getattr(ns, "max_gas_price", None) is not None:
        append_arg(monitor_args, "--max-gas-price", str(ns.max_gas_price))
    if getattr(ns, "max_gas_limit", None) is not None:
        append_arg(monitor_args, "--max-gas-limit", str(ns.max_gas_limit))
    if getattr(ns, "verification_gas", None) is not None:
        append_arg(monitor_args, "--verification-gas", str(ns.verification_gas))
    if getattr(ns, "margin", None) is not None:
        append_arg(monitor_args, "--margin", str(ns.margin))
    if getattr(ns, "window", None) is not None:
        append_arg(monitor_args, "--window", str(ns.window))
    append_arg(monitor_args, "--lottery-ids", getattr(ns, "lottery_ids", None))
    if include_fail_on_low and getattr(ns, "fail_on_low", False):
        monitor_args.append("--fail-on-low")
    return monitor_args


def run_monitor(ns: Namespace, include_fail_on_low: bool = True) -> subprocess.CompletedProcess[str]:
    """Execute ``testnet_monitor_json.py`` and return its CompletedProcess."""

    cmd = [sys.executable, str(MONITOR_SCRIPT)] + build_monitor_args(ns, include_fail_on_low=include_fail_on_low)
    env = os.environ.copy()
    supra_config = getattr(ns, "supra_config", None)
    if supra_config:
        env["SUPRA_CONFIG"] = supra_config
    process = subprocess.run(cmd, text=True, capture_output=True, env=env)
    if process.returncode not in (0, 1) or not process.stdout.strip():
        raise MonitorError(
            "Не удалось получить отчёт от testnet_monitor_json.py. "
            f"Код возврата: {process.returncode}, stderr: {process.stderr.strip()}"
        )
    return process


__all__ = [
    "MonitorError",
    "env_default",
    "add_monitor_arguments",
    "build_monitor_args",
    "run_monitor",
]
