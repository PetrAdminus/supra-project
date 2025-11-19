"""Record consumer whitelist snapshot via Supra CLI."""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional

from .monitor_common import MonitorError, add_monitor_arguments, env_default
from .lib.transactions import execute_move_tool_run


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Записать снапшот consumer whitelist через Supra CLI",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--callback-gas-price",
        type=int,
        default=env_default("CALLBACK_GAS_PRICE", int),
        help="callback_gas_price для consumer whitelist",
    )
    parser.add_argument(
        "--callback-gas-limit",
        type=int,
        default=env_default("CALLBACK_GAS_LIMIT", int),
        help="callback_gas_limit для consumer whitelist",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="передать --assume-yes в Supra CLI",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="только вывести команду без выполнения",
    )
    parser.add_argument(
        "--function-id",
        default=None,
        help=(
            "переопределить идентификатор функции. По умолчанию используется "
            "<lottery_addr>::core_main_v2::record_consumer_whitelist_snapshot"
        ),
    )
    return parser


def _require_int(ns: argparse.Namespace, name: str) -> int:
    value = getattr(ns, name, None)
    if value is None:
        raise MonitorError(f"Нужно указать {name.replace('_', '-')} для вызова команды")
    return int(value)


def build_command_args(ns: argparse.Namespace) -> List[str]:
    callback_gas_price = _require_int(ns, "callback_gas_price")
    callback_gas_limit = _require_int(ns, "callback_gas_limit")
    return [f"u128:{callback_gas_price}", f"u128:{callback_gas_limit}"]


def target_function_id(ns: argparse.Namespace) -> str:
    if ns.function_id:
        return str(ns.function_id)
    if not ns.lottery_addr:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")
    return f"{ns.lottery_addr}::core_main_v2::record_consumer_whitelist_snapshot"


def execute(ns: argparse.Namespace, *, now: Optional[datetime] = None) -> Dict[str, object]:
    command_args = build_command_args(ns)
    return execute_move_tool_run(
        supra_cli_bin=ns.supra_cli_bin,
        profile=ns.profile,
        function_id=target_function_id(ns),
        args=command_args,
        supra_config=ns.supra_config,
        assume_yes=ns.assume_yes,
        dry_run=ns.dry_run,
        now=now,
    )


def main(argv: Optional[List[str]] | None = None) -> None:
    parser = build_parser()
    ns = parser.parse_args(argv)

    try:
        result = execute(ns)
    except MonitorError as exc:
        parser.error(str(exc))
        return

    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(result.get("returncode", 0) or 0)


__all__ = [
    "build_parser",
    "build_command_args",
    "execute",
    "main",
]
