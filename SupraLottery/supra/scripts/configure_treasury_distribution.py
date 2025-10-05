"""Настройка распределения казначейства лотереи через Supra CLI."""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional, Sequence

from .monitor_common import MonitorError, add_monitor_arguments
from .lib.transactions import execute_move_tool_run

BASIS_POINT_DENOMINATOR = 10_000


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Обновить распределение казначейства lottery::treasury_v1::set_config",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--bp-jackpot",
        type=int,
        required=True,
        help="доля джекпота в basis points (u64)",
    )
    parser.add_argument(
        "--bp-prize",
        type=int,
        required=True,
        help="доля призового фонда в basis points (u64)",
    )
    parser.add_argument(
        "--bp-treasury",
        type=int,
        required=True,
        help="доля операционного казначейства в basis points (u64)",
    )
    parser.add_argument(
        "--bp-marketing",
        type=int,
        required=True,
        help="доля маркетингового фонда в basis points (u64)",
    )
    parser.add_argument(
        "--bp-community",
        type=int,
        default=0,
        help="доля community-пула в basis points (u64), по умолчанию 0",
    )
    parser.add_argument(
        "--bp-team",
        type=int,
        default=0,
        help="доля команды в basis points (u64), по умолчанию 0",
    )
    parser.add_argument(
        "--bp-partners",
        type=int,
        default=0,
        help="доля партнёров в basis points (u64), по умолчанию 0",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="передать --assume-yes Supra CLI для пропуска подтверждения",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="вывести команду без выполнения",
    )
    parser.add_argument(
        "--function-id",
        default=None,
        help=(
            "переопределить идентификатор функции. По умолчанию используется "
            "<lottery_addr>::treasury_v1::set_config"
        ),
    )
    return parser


def _normalize_basis_points(values: Sequence[int]) -> List[int]:
    normalized: List[int] = []
    for index, value in enumerate(values):
        if value is None:
            raise MonitorError("Не все доли распределения заданы")
        if value < 0:
            raise MonitorError(
                f"Значение basis points не может быть отрицательным (позиция {index + 1})"
            )
        normalized.append(int(value))

    if sum(normalized) != BASIS_POINT_DENOMINATOR:
        raise MonitorError(
            "Сумма долей должна составлять ровно 10000 basis points. Проверьте введённые значения."
        )

    return normalized


def build_command_args(ns: argparse.Namespace) -> List[str]:
    values = _normalize_basis_points(
        [
            getattr(ns, "bp_jackpot", None),
            getattr(ns, "bp_prize", None),
            getattr(ns, "bp_treasury", None),
            getattr(ns, "bp_marketing", None),
            getattr(ns, "bp_community", None),
            getattr(ns, "bp_team", None),
            getattr(ns, "bp_partners", None),
        ]
    )
    return [f"u64:{value}" for value in values]


def target_function_id(ns: argparse.Namespace) -> str:
    if ns.function_id:
        return str(ns.function_id)
    if not ns.lottery_addr:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")
    return f"{ns.lottery_addr}::treasury_v1::set_config"


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
    "target_function_id",
    "execute",
    "main",
]

