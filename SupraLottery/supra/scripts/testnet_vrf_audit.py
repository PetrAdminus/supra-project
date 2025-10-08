"""Выгрузка событий VRF для панели честности и аудита."""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict

from .monitor_common import add_monitor_arguments
from .lib.monitoring import CliError, ConfigError, MonitorConfig, monitor_config_from_namespace
from .lib.vrf_audit import gather_vrf_log


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Собрать события VRF и состояние раунда для заданной лотереи",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--lottery-id",
        type=int,
        required=True,
        help="идентификатор лотереи в VRF-хабе",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="максимальное число событий на тип (1-500)",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="печать форматированного JSON",
    )
    return parser


def _sanitize_limit(raw: int) -> int:
    if raw <= 0:
        raise ValueError("limit должен быть положительным")
    if raw > 500:
        raise ValueError("limit не может превышать 500")
    return raw


def gather_from_namespace(ns: argparse.Namespace) -> Dict[str, Any]:
    try:
        config: MonitorConfig = monitor_config_from_namespace(ns)
    except ConfigError as exc:  # pragma: no cover - обрабатывается в main
        raise SystemExit(f"[error] {exc}") from exc

    limit = _sanitize_limit(getattr(ns, "limit", 50))
    lottery_id = getattr(ns, "lottery_id")
    try:
        report = gather_vrf_log(config, lottery_id=lottery_id, limit=limit)
    except (ValueError, CliError) as exc:
        raise SystemExit(f"[error] {exc}") from exc
    return report


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        report = gather_from_namespace(args)
    except SystemExit as exc:
        if exc.code == 0:
            raise
        print(exc.args[0], file=sys.stderr)
        sys.exit(2)

    formatted = json.dumps(report, indent=2 if args.pretty else None, ensure_ascii=False)
    print(formatted)


if __name__ == "__main__":  # pragma: no cover
    main()
