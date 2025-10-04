#!/usr/bin/env python3
"""Автоматизированный запуск manual_draw с проверкой готовности."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any, Dict, List

from . import testnet_draw_readiness as readiness
from .monitor_common import (
    MonitorError,
    add_monitor_arguments,
    run_monitor,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Запустить manual_draw для лотереи Supra dVRF"
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--min-tickets",
        type=int,
        default=readiness.DEFAULT_MIN_TICKETS,
        help="минимальное число билетов перед розыгрышем (по умолчанию 5)",
    )
    parser.add_argument(
        "--skip-readiness",
        action="store_true",
        help="пропустить проверку готовности и сразу вызвать manual_draw",
    )
    parser.add_argument(
        "--skip-draw-scheduled",
        action="store_true",
        help="не проверять draw_scheduled в readiness",
    )
    parser.add_argument(
        "--allow-pending-request",
        action="store_true",
        help="разрешить активный pending_request",
    )
    parser.add_argument(
        "--skip-min-balance",
        action="store_true",
        help="не проверять достижение минимального баланса депозита",
    )
    parser.add_argument(
        "--require-aggregator",
        action="store_true",
        help="убедиться, что whitelist агрегаторов не пуст",
    )
    parser.add_argument(
        "--expect-aggregator",
        action="append",
        default=None,
        help="конкретный адрес агрегатора, который должен быть в whitelist",
    )
    parser.add_argument(
        "--print-json",
        action="store_true",
        help="вывести отчёт readiness в JSON перед вызовом manual_draw",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="передать --assume-yes в команду Supra CLI",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="только вывести команду manual_draw без выполнения",
    )
    parser.add_argument(
        "--function-id",
        default=None,
        help=(
            "переопределить целевую функцию manual_draw; по умолчанию"
            " используется <lottery_addr>::main_v2::manual_draw"
        ),
    )
    return parser


def readiness_report(ns: argparse.Namespace) -> Dict[str, Any]:
    """Получить отчёт monitor_json для проверки готовности."""

    process = run_monitor(ns, include_fail_on_low=False)
    try:
        return json.loads(process.stdout)
    except json.JSONDecodeError as exc:  # pragma: no cover - диагностический случай
        raise MonitorError(f"Не удалось разобрать JSON отчёта readiness: {exc}") from exc


def build_manual_draw_command(ns: argparse.Namespace) -> List[str]:
    """Сформировать команду Supra CLI для вызова manual_draw."""

    if not ns.profile:
        raise MonitorError("Нужно указать профиль Supra CLI (--profile)")
    if not ns.lottery_addr and not ns.function_id:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")

    function_id = ns.function_id or f"{ns.lottery_addr}::main_v2::manual_draw"
    cmd = [ns.supra_cli_bin, "move", "tool", "run", "--profile", ns.profile, "--function-id", function_id]
    if ns.assume_yes:
        cmd.append("--assume-yes")
    return cmd


def main() -> None:
    parser = build_parser()
    ns = parser.parse_args()

    report: Dict[str, Any] = {}
    if not ns.skip_readiness:
        try:
            report = readiness_report(ns)
        except MonitorError as exc:
            parser.error(str(exc))

        reasons = readiness.evaluate(report, ns)
        if reasons:
            print("❌ manual_draw не запущен: контракт не готов")
            for reason in reasons:
                print(f" - {reason}")
            if ns.print_json:
                print(json.dumps(report, ensure_ascii=False, indent=2))
            raise SystemExit(1)

        print("✅ Контракт прошёл проверку готовности, выполняем manual_draw")
        if ns.print_json:
            print(json.dumps(report, ensure_ascii=False, indent=2))

    try:
        cmd = build_manual_draw_command(ns)
    except MonitorError as exc:
        parser.error(str(exc))

    print("Команда Supra CLI:", " ".join(cmd))
    if ns.dry_run:
        print("--dry-run: вызов manual_draw пропущен")
        raise SystemExit(0)

    env = os.environ.copy()
    if ns.supra_config:
        env["SUPRA_CONFIG"] = ns.supra_config

    process = subprocess.run(cmd, text=True, capture_output=True, env=env)

    if process.returncode != 0:
        print("❌ manual_draw завершился с ошибкой", file=sys.stderr)
        if process.stdout:
            print(process.stdout.strip(), file=sys.stderr)
        if process.stderr:
            print(process.stderr.strip(), file=sys.stderr)
        raise SystemExit(process.returncode or 1)

    print("✅ manual_draw выполнен успешно")
    if process.stdout:
        print(process.stdout.strip())

    raise SystemExit(0)


if __name__ == "__main__":
    main()
