"""Управление автоматическим запуском manual_draw на основе готовности контракта."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

from ..scripts import testnet_draw_readiness as readiness
from ..scripts.monitor_common import add_monitor_arguments, build_monitor_args


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Проверить готовность и при необходимости запустить manual_draw",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--min-tickets",
        type=int,
        default=readiness.DEFAULT_MIN_TICKETS,
        help="минимальное число билетов перед розыгрышем",
    )
    parser.add_argument(
        "--skip-draw-scheduled",
        action="store_true",
        help="не проверять draw_scheduled при оценке готовности",
    )
    parser.add_argument(
        "--allow-pending-request",
        action="store_true",
        help="разрешить активный pending_request",
    )
    parser.add_argument(
        "--skip-min-balance",
        action="store_true",
        help="не проверять min_balance",
    )
    parser.add_argument(
        "--require-aggregator",
        action="store_true",
        help="проверять, что whitelist агрегаторов не пуст",
    )
    parser.add_argument(
        "--expect-aggregator",
        action="append",
        default=None,
        help="адрес агрегатора, который обязан присутствовать в whitelist",
    )
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--execute",
        action="store_true",
        help="выполнить manual_draw при готовности",
    )
    mode_group.add_argument(
        "--dry-run",
        action="store_true",
        help="только проверить готовность без вызова manual_draw",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="пробросить флаг --assume-yes в Supra CLI",
    )
    parser.add_argument(
        "--function-id",
        default=None,
        help="переопределить идентификатор функции manual_draw",
    )
    return parser


def _monitor_env(ns: argparse.Namespace) -> Dict[str, str]:
    env = os.environ.copy()
    if getattr(ns, "supra_config", None):
        env["SUPRA_CONFIG"] = ns.supra_config
    return env


def _build_readiness_command(ns: argparse.Namespace) -> List[str]:
    args = [
        sys.executable,
        "-m",
        "supra.scripts.testnet_draw_readiness",
        "--json-summary",
        "--include-report",
    ]
    args += build_monitor_args(ns, include_fail_on_low=False)
    args.extend(["--min-tickets", str(ns.min_tickets)])
    if ns.skip_draw_scheduled:
        args.append("--skip-draw-scheduled")
    if ns.allow_pending_request:
        args.append("--allow-pending-request")
    if ns.skip_min_balance:
        args.append("--skip-min-balance")
    if ns.require_aggregator:
        args.append("--require-aggregator")
    if ns.expect_aggregator:
        for value in ns.expect_aggregator:
            args.extend(["--expect-aggregator", value])
    return args


def _build_manual_draw_command(ns: argparse.Namespace, execute: bool) -> List[str]:
    args = [
        sys.executable,
        "-m",
        "supra.scripts.testnet_manual_draw",
        "--json-result",
        "--min-tickets",
        str(ns.min_tickets),
    ]
    args += build_monitor_args(ns, include_fail_on_low=False)
    if ns.skip_draw_scheduled:
        args.append("--skip-draw-scheduled")
    if ns.allow_pending_request:
        args.append("--allow-pending-request")
    if ns.skip_min_balance:
        args.append("--skip-min-balance")
    if ns.require_aggregator:
        args.append("--require-aggregator")
    if ns.expect_aggregator:
        for value in ns.expect_aggregator:
            args.extend(["--expect-aggregator", value])
    if ns.assume_yes:
        args.append("--assume-yes")
    if ns.function_id:
        args.extend(["--function-id", ns.function_id])
    if not execute:
        args.append("--dry-run")
    return args


def _run_command(cmd: List[str], env: Dict[str, str]) -> Tuple[int, str, str]:
    process = subprocess.run(cmd, text=True, capture_output=True, env=env)
    return process.returncode, process.stdout.strip(), process.stderr.strip()


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def run(ns: argparse.Namespace) -> Tuple[Dict[str, Any], int]:
    execute = bool(ns.execute and not ns.dry_run)

    readiness_cmd = _build_readiness_command(ns)
    ready_code, ready_stdout, ready_stderr = _run_command(readiness_cmd, _monitor_env(ns))

    entry: Dict[str, Any] = {
        "timestamp": _timestamp(),
        "execute": execute,
        "commands": {"readiness": readiness_cmd},
        "readiness": None,
        "manual_draw": None,
        "status": "error",
        "stderr": ready_stderr,
        "readiness_exit_code": ready_code,
    }

    if not ready_stdout:
        entry["error"] = "empty readiness output"
        return entry, ready_code or 1

    try:
        readiness_summary = json.loads(ready_stdout)
    except json.JSONDecodeError as exc:
        entry["error"] = f"failed to parse readiness JSON: {exc}"
        return entry, ready_code or 1

    entry["readiness"] = readiness_summary
    entry["status"] = "ready" if readiness_summary.get("ready") else "not_ready"

    if not readiness_summary.get("ready"):
        entry["exit_code"] = 0
        return entry, 0

    if not execute:
        entry["status"] = "ready_dry_run"
        entry["exit_code"] = 0
        return entry, 0

    manual_cmd = _build_manual_draw_command(ns, execute=True)
    entry["commands"]["manual_draw"] = manual_cmd

    code, stdout, stderr = _run_command(manual_cmd, _monitor_env(ns))
    manual_result: Dict[str, Any]

    try:
        manual_result = json.loads(stdout) if stdout else {}
    except json.JSONDecodeError as exc:
        manual_result = {
            "error": f"failed to parse manual_draw JSON: {exc}",
            "stdout": stdout,
            "stderr": stderr,
            "returncode": code,
        }

    entry["manual_draw"] = manual_result or None
    entry["manual_draw_exit_code"] = code
    entry["stderr"] = stderr

    if code == 0:
        entry["status"] = "executed"
        entry["exit_code"] = 0
        return entry, 0

    entry["status"] = "manual_draw_failed"
    entry["exit_code"] = code or 1
    return entry, code or 1


def main(argv: List[str] | None = None) -> None:
    parser = build_parser()
    ns = parser.parse_args(argv)
    entry, exit_code = run(ns)
    print(json.dumps(entry, ensure_ascii=False))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
