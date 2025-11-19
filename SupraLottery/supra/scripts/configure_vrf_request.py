"""Настройка параметров VRF-запроса через Supra CLI."""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional

from .monitor_common import MonitorError, add_monitor_arguments, env_default
from .lib.transactions import execute_move_tool_run

MIN_CONFIRMATIONS = 1
MAX_CONFIRMATIONS = 20


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Настроить rng_count, num_confirmations и client_seed для Supra VRF",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--rng-count",
        type=int,
        default=env_default("RNG_COUNT", int),
        help="количество случайных чисел (u8) для configure_vrf_request",
    )
    parser.add_argument(
        "--num-confirmations",
        type=int,
        default=env_default("NUM_CONFIRMATIONS", int),
        help="число подтверждений (u64) для configure_vrf_request",
    )
    parser.add_argument(
        "--client-seed",
        type=int,
        default=env_default("CLIENT_SEED", int),
        help="seed (u64) для configure_vrf_request",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="передать --assume-yes в команду Supra CLI",
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
            "<lottery_addr>::core_main_v2::configure_vrf_request"
        ),
    )
    return parser


def _require_int(ns: argparse.Namespace, name: str) -> int:
    value = getattr(ns, name, None)
    if value is None:
        raise MonitorError(f"Нужно указать {name.replace('_', '-')} для вызова команды")
    return int(value)


def build_command_args(ns: argparse.Namespace) -> List[str]:
    rng_count = _require_int(ns, "rng_count")
    num_confirmations = _require_int(ns, "num_confirmations")
    client_seed = _require_int(ns, "client_seed")

    if num_confirmations < MIN_CONFIRMATIONS:
        raise MonitorError(
            "num-confirmations должен быть не меньше 1 согласно требованиям Supra dVRF"
        )
    if num_confirmations > MAX_CONFIRMATIONS:
        raise MonitorError(
            "num-confirmations не может превышать 20 (лимит Supra dVRF на подтверждения)"
        )

    return [
        f"u8:{rng_count}",
        f"u64:{num_confirmations}",
        f"u64:{client_seed}",
    ]


def target_function_id(ns: argparse.Namespace) -> str:
    if ns.function_id:
        return str(ns.function_id)
    if not ns.lottery_addr:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")
    return f"{ns.lottery_addr}::core_main_v2::configure_vrf_request"


def execute(ns: argparse.Namespace, *, now: Optional[datetime] = None) -> Dict[str, object]:
    command_args = build_command_args(ns)
    result = execute_move_tool_run(
        supra_cli_bin=ns.supra_cli_bin,
        profile=ns.profile,
        function_id=target_function_id(ns),
        args=command_args,
        supra_config=ns.supra_config,
        assume_yes=ns.assume_yes,
        dry_run=ns.dry_run,
        now=now,
    )
    return result


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
    "target_function_id",
    "execute",
    "main",
]
