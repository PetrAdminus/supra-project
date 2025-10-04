#!/usr/bin/env python3
"""Проверка готовности контракта лотереи к вызову manual_draw."""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict, List

from .monitor_common import (
    MonitorError,
    add_monitor_arguments,
    run_monitor,
)

DEFAULT_MIN_TICKETS = 5


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    return bool(value)


def _as_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError as exc:  # pragma: no cover - защитный код
            raise MonitorError(f"Не удалось преобразовать значение '{value}' в int") from exc
    raise MonitorError(f"Неизвестный тип для числового значения: {type(value)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Проверить, готов ли контракт к запросу Supra dVRF (manual_draw)"
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--min-tickets",
        type=int,
        default=DEFAULT_MIN_TICKETS,
        help="минимальное количество билетов для розыгрыша (по умолчанию 5)",
    )
    parser.add_argument(
        "--skip-draw-scheduled",
        action="store_true",
        help="не проверять флаг draw_scheduled",
    )
    parser.add_argument(
        "--allow-pending-request",
        action="store_true",
        help="разрешить активный pending_request",
    )
    parser.add_argument(
        "--skip-min-balance",
        action="store_true",
        help="не проверять достижение минимального баланса",
    )
    parser.add_argument(
        "--require-aggregator",
        action="store_true",
        help="требовать, чтобы whitelist агрегаторов был непустым",
    )
    parser.add_argument(
        "--expect-aggregator",
        action="append",
        default=None,
        help="конкретный адрес агрегатора, который должен быть в whitelist (можно указывать несколько раз)",
    )
    parser.add_argument(
        "--print-json",
        action="store_true",
        help="дополнительно вывести полный JSON-отчёт",
    )
    return parser


def evaluate(report: Dict[str, Any], ns: argparse.Namespace) -> List[str]:
    reasons: List[str] = []
    lottery = report.get("lottery", {})
    status = lottery.get("status", {})
    whitelist = lottery.get("whitelist_status", {})
    deposit = report.get("deposit", {})

    ticket_value = status.get("ticket_count") or status.get("tickets")
    if ticket_value is None:
        reasons.append("Не удалось определить количество билетов")
    else:
        ticket_count = _as_int(ticket_value)
        if ticket_count < ns.min_tickets:
            reasons.append(
                f"Недостаточно билетов: требуется >= {ns.min_tickets}, сейчас {ticket_count}"
            )

    if not ns.skip_draw_scheduled and not _as_bool(status.get("draw_scheduled", False)):
        reasons.append("Розыгрыш ещё не запланирован (draw_scheduled=false)")

    if not ns.allow_pending_request and _as_bool(status.get("pending_request", False)):
        reasons.append("Есть активный запрос VRF (pending_request=true)")

    if not ns.skip_min_balance:
        min_reached = deposit.get("min_balance_reached")
        if min_reached is None or not _as_bool(min_reached):
            reasons.append("Минимальный баланс депозита не достигнут")

    aggregators = whitelist.get("aggregators", []) or []
    if ns.require_aggregator and not aggregators:
        reasons.append("Whitelist агрегаторов пуст")

    if ns.expect_aggregator:
        normalized = {str(addr).lower() for addr in aggregators}
        missing = [addr for addr in ns.expect_aggregator if addr.lower() not in normalized]
        if missing:
            reasons.append(
                "Не найдены агрегаторы: " + ", ".join(missing)
            )

    return reasons


def main() -> None:
    parser = build_parser()
    ns = parser.parse_args()

    try:
        process = run_monitor(ns, include_fail_on_low=False)
    except MonitorError as exc:
        parser.error(str(exc))

    try:
        report = json.loads(process.stdout)
    except json.JSONDecodeError as exc:
        parser.error(f"Не удалось разобрать JSON отчёта: {exc}")

    reasons = evaluate(report, ns)

    if reasons:
        print("❌ Контракт не готов к manual_draw:")
        for reason in reasons:
            print(f" - {reason}")
        exit_code = 1
    else:
        status = report.get("lottery", {}).get("status", {})
        ticket_value = status.get("ticket_count") or status.get("tickets")
        ticket_count = _as_int(ticket_value) if ticket_value is not None else "?"
        print(
            "✅ Контракт готов к manual_draw — билеты: {tickets}, draw_scheduled={draw}, pending_request={pending}".format(
                tickets=ticket_count,
                draw=_as_bool(status.get("draw_scheduled", False)),
                pending=_as_bool(status.get("pending_request", False)),
            )
        )
        exit_code = 0

    if ns.print_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))

    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
