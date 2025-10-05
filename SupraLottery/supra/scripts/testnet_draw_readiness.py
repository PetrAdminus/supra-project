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
    parser.add_argument(
        "--json-summary",
        action="store_true",
        help="вывести только машиночитаемое резюме без текстовых строк",
    )
    parser.add_argument(
        "--include-report",
        action="store_true",
        help="вложить полный отчёт monitor_json в JSON-резюме",
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


def build_summary(
    report: Dict[str, Any], ns: argparse.Namespace, reasons: List[str]
) -> Dict[str, Any]:
    """Собрать краткое резюме проверки готовности."""

    lottery = report.get("lottery", {})
    status = lottery.get("status", {})
    whitelist = lottery.get("whitelist_status", {}) or {}
    deposit = report.get("deposit", {}) or {}

    ticket_value = status.get("ticket_count") or status.get("tickets")
    ticket_count: Any
    if ticket_value is None:
        ticket_count = None
    else:
        try:
            ticket_count = _as_int(ticket_value)
        except MonitorError:
            ticket_count = None

    aggregators = list(whitelist.get("aggregators", []) or [])

    summary: Dict[str, Any] = {
        "ready": not reasons,
        "reasons": reasons,
        "ticket_count": ticket_count,
        "min_tickets_required": ns.min_tickets,
        "draw_scheduled": _as_bool(status.get("draw_scheduled", False)),
        "pending_request": _as_bool(status.get("pending_request", False)),
        "min_balance_reached": _as_bool(deposit.get("min_balance_reached", False)),
        "aggregators": [str(value) for value in aggregators],
    }

    if ns.expect_aggregator:
        summary["expected_aggregators"] = list(ns.expect_aggregator)

    return summary


def main() -> None:
    parser = build_parser()
    ns = parser.parse_args()

    if ns.include_report and not ns.json_summary:
        parser.error("--include-report доступен только вместе с --json-summary")

    try:
        process = run_monitor(ns, include_fail_on_low=False)
    except MonitorError as exc:
        parser.error(str(exc))

    try:
        report = json.loads(process.stdout)
    except json.JSONDecodeError as exc:
        parser.error(f"Не удалось разобрать JSON отчёта: {exc}")

    reasons = evaluate(report, ns)
    summary = build_summary(report, ns, reasons)

    exit_code = 0 if summary["ready"] else 1

    if ns.json_summary:
        summary_output = dict(summary)
        if ns.include_report:
            summary_output["report"] = report
        print(json.dumps(summary_output, ensure_ascii=False, indent=2))
        if ns.print_json and not ns.include_report:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        raise SystemExit(exit_code)

    if reasons:
        print("❌ Контракт не готов к manual_draw:")
        for reason in reasons:
            print(f" - {reason}")
    else:
        print(
            "✅ Контракт готов к manual_draw — билеты: {tickets}, draw_scheduled={draw}, pending_request={pending}".format(
                tickets=summary["ticket_count"] if summary["ticket_count"] is not None else "?",
                draw=summary["draw_scheduled"],
                pending=summary["pending_request"],
            )
        )

    if ns.print_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))

    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
