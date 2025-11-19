"""Remove lottery contract from Supra dVRF subscription with safety checks."""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from typing import Any, Dict, Iterable, Optional

from .monitor_common import MonitorError, add_monitor_arguments
from .lib.monitoring import gather_data, monitor_config_from_namespace
from .lib.transactions import execute_move_tool_run


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Удалить контракт лотереи из подписки Supra dVRF",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--allow-pending-request",
        action="store_true",
        help="пропустить проверку pending_request перед вызовом remove_subscription",
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
            "<lottery_addr>::core_main_v2::remove_subscription"
        ),
    )
    return parser


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        text = value.strip().lower()
        return text in {"1", "true", "yes", "y"}
    return False


def _has_pending_request(entry: Dict[str, Any]) -> bool:
    round_section = entry.get("round") or {}
    if isinstance(round_section, dict):
        if round_section.get("pending_request_id") is not None:
            return True
        snapshot = round_section.get("snapshot")
        if isinstance(snapshot, dict):
            if _as_bool(snapshot.get("has_pending_request")):
                return True
            if snapshot.get("pending_request") is not None:
                return True
    return False


def _ensure_no_pending(report: Dict[str, Any]) -> None:
    lotteries = report.get("lotteries")
    if not isinstance(lotteries, Iterable):
        return
    for entry in lotteries:
        if not isinstance(entry, dict):
            continue
        if _has_pending_request(entry):
            lottery_id = entry.get("lottery_id")
            if lottery_id is not None:
                raise MonitorError(
                    "Нельзя удалить контракт из подписки: обнаружен pending_request для lottery_id="
                    f"{lottery_id}"
                )
            raise MonitorError(
                "Нельзя удалить контракт из подписки: обнаружен активный pending_request"
            )


def target_function_id(ns: argparse.Namespace) -> str:
    if ns.function_id:
        return str(ns.function_id)
    lottery_addr = getattr(ns, "lottery_addr", None)
    if not lottery_addr:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")
    return f"{lottery_addr}::core_main_v2::remove_subscription"


def execute(ns: argparse.Namespace, *, now: Optional[datetime] = None) -> Dict[str, Any]:
    config = monitor_config_from_namespace(ns)
    if not ns.allow_pending_request:
        report = gather_data(config)
        _ensure_no_pending(report)

    result = execute_move_tool_run(
        supra_cli_bin=ns.supra_cli_bin,
        profile=ns.profile,
        function_id=target_function_id(ns),
        args=[],
        supra_config=ns.supra_config,
        assume_yes=ns.assume_yes,
        dry_run=ns.dry_run,
        now=now,
    )
    return result


def main(argv: Optional[list[str]] | None = None) -> None:
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
    "execute",
    "main",
    "target_function_id",
]
