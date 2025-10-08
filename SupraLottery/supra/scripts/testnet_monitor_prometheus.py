#!/usr/bin/env python3
"""Generate Prometheus-style metrics from Supra dVRF monitor JSON."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Dict, List, Optional

from . import monitor_common as common

DEFAULT_PREFIX = "supra_dvrf"
DEFAULT_PUSH_METHOD = "POST"
DEFAULT_TIMEOUT = 10.0


class PrometheusError(RuntimeError):
    """Raised when gathering metrics or pushing fails."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Собрать отчёт Supra dVRF и вывести метрики в формате Prometheus",
    )
    parser.add_argument(
        "--metric-prefix",
        default=os.environ.get("METRIC_PREFIX", DEFAULT_PREFIX),
        help="префикс имён метрик (по умолчанию supra_dvrf)",
    )
    parser.add_argument(
        "--label",
        action="append",
        default=[],
        help="добавить статическую метку в формате key=value (можно указывать несколько раз)",
    )
    parser.add_argument(
        "--push-url",
        default=os.environ.get("MONITOR_PUSH_URL"),
        help="если задано — отправить метрики на указанный URL (Prometheus Pushgateway или любой HTTP endpoint)",
    )
    parser.add_argument(
        "--push-method",
        default=os.environ.get("MONITOR_PUSH_METHOD", DEFAULT_PUSH_METHOD),
        help="HTTP-метод при отправке (по умолчанию POST)",
    )
    parser.add_argument(
        "--push-timeout",
        type=float,
        default=float(os.environ.get("MONITOR_PUSH_TIMEOUT", DEFAULT_TIMEOUT)),
        help="таймаут HTTP-запроса в секундах",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="не отправлять метрики даже при заданном push-url",
    )
    common.add_monitor_arguments(parser)
    return parser


def parse_labels(items: Optional[List[str]]) -> Dict[str, str]:
    labels: Dict[str, str] = {}
    if not items:
        return labels
    for raw in items:
        if not raw:
            continue
        if "=" not in raw:
            raise PrometheusError(f"Метка должна быть в формате key=value, получено: {raw}")
        key, value = raw.split("=", 1)
        key = key.strip()
        if not key:
            raise PrometheusError(f"Имя метки не может быть пустым: {raw}")
        labels[key] = value.strip()
    return labels


def escape_label_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\"", "\\\"")


def format_labels(base: Dict[str, str]) -> str:
    return ",".join(f'{key}="{escape_label_value(str(val))}"' for key, val in sorted(base.items()))


def to_int(value: object) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    return int(str(value))


def _truthy(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


def _pick_primary_lottery(report: Dict[str, object]) -> Optional[Dict[str, object]]:
    lotteries = report.get("lotteries")
    if not isinstance(lotteries, list):
        return None
    for entry in lotteries:
        if not isinstance(entry, dict):
            continue
        registration = entry.get("registration")
        if isinstance(registration, dict) and _truthy(registration.get("active")):
            return entry
    return next((entry for entry in lotteries if isinstance(entry, dict)), None)


def extract_draw_info(report: Dict[str, object]) -> Dict[str, int]:
    lottery = _pick_primary_lottery(report)
    if not isinstance(lottery, dict):
        return {"draw_scheduled": 0, "pending_request": 0, "ticket_count": 0}
    round_section = lottery.get("round")
    if not isinstance(round_section, dict):
        return {"draw_scheduled": 0, "pending_request": 0, "ticket_count": 0}
    snapshot = round_section.get("snapshot")
    pending_id = round_section.get("pending_request_id")
    if not isinstance(snapshot, dict):
        snapshot = {}
    draw_scheduled = _truthy(snapshot.get("draw_scheduled"))
    has_pending = _truthy(snapshot.get("has_pending_request")) or pending_id is not None
    ticket_count = snapshot.get("ticket_count", 0)
    return {
        "draw_scheduled": 1 if draw_scheduled else 0,
        "pending_request": 1 if has_pending else 0,
        "ticket_count": to_int(ticket_count),
    }


def extract_rng_count(report: Dict[str, object]) -> int:
    # В мульти-лотерейной архитектуре параметры VRF управляются через VRF-хаб и payload.
    # Пока отдельной view-функции нет, поэтому возвращаем 0 и оставляем метрику для совместимости.
    return 0


def format_metrics(ns: argparse.Namespace, report: Dict[str, object], monitor_rc: int, extra_labels: Dict[str, str]) -> str:
    if not ns.metric_prefix:
        raise PrometheusError("Префикс метрик не может быть пустым")

    deposit = report.get("deposit", {})
    calculation = report.get("calculation", {})

    balance = to_int(deposit.get("balance", 0))
    min_balance = to_int(calculation.get("min_balance", 0))
    recommended = to_int(calculation.get("recommended_deposit", min_balance))
    per_request_fee = to_int(calculation.get("per_request_fee", 0))
    window = to_int(calculation.get("request_window", 30))

    addresses = report.get("addresses", {}) if isinstance(report.get("addresses"), dict) else {}
    lottery_addr = str(addresses.get("lottery") or ns.lottery_addr or "")
    client_addr = str(addresses.get("client") or ns.client_addr or lottery_addr)
    deposit_addr = str(addresses.get("deposit") or getattr(ns, "deposit_addr", ""))
    hub_addr = addresses.get("hub")

    labels: Dict[str, str] = {
        "profile": ns.profile or "<unknown>",
        "lottery_addr": lottery_addr,
        "client_addr": client_addr,
    }
    if deposit_addr:
        labels["deposit_addr"] = deposit_addr
    if hub_addr:
        labels["hub_addr"] = str(hub_addr)
    labels.update(extra_labels)

    label_string = format_labels(labels)

    metrics: List[str] = []

    def add_metric(name: str, value: object) -> None:
        metrics.append(f"{ns.metric_prefix}_{name}{{{label_string}}} {value}")

    add_metric("deposit_balance_quants", balance)
    add_metric("min_balance_quants", min_balance)
    add_metric("recommended_deposit_quants", recommended)
    add_metric("per_request_fee_quants", per_request_fee)
    add_metric("request_window_requests", window)

    ratio = balance / min_balance if min_balance else 0.0
    add_metric("balance_ratio", f"{ratio:.6f}")

    min_reached = deposit.get("min_balance_reached")
    add_metric("min_balance_reached", 1 if bool(min_reached) else 0)

    add_metric("max_gas_price", to_int(deposit.get("max_gas_price", 0)))
    add_metric("max_gas_limit", to_int(deposit.get("max_gas_limit", 0)))

    draw_info = extract_draw_info(report)
    add_metric("draw_scheduled", draw_info["draw_scheduled"])
    add_metric("pending_request", draw_info["pending_request"])
    add_metric("ticket_count", draw_info["ticket_count"])
    add_metric("rng_count", extract_rng_count(report))

    add_metric("monitor_exit_code", monitor_rc)

    subscription = deposit.get("subscription_info")
    if isinstance(subscription, dict):
        active = subscription.get("active")
        if active is not None:
            add_metric("subscription_active", 1 if bool(active) else 0)

    return "\n".join(metrics) + "\n"


def run_monitor(ns: argparse.Namespace) -> argparse.Namespace:
    process = common.run_monitor(ns)
    try:
        report = json.loads(process.stdout)
    except json.JSONDecodeError as exc:  # pragma: no cover - defensive branch
        raise PrometheusError(f"Неверный JSON от monitor_json: {exc}") from exc
    return argparse.Namespace(report=report, returncode=process.returncode)


def push_metrics(url: str, method: str, metrics: str, timeout: float) -> None:
    request = urllib.request.Request(
        url,
        data=metrics.encode("utf-8"),
        method=method.upper(),
        headers={"Content-Type": "text/plain; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if response.status >= 300:
                raise PrometheusError(f"Push endpoint вернул статус {response.status}")
    except urllib.error.URLError as exc:
        raise PrometheusError(f"Не удалось отправить метрики: {exc}") from exc


def main() -> None:
    parser = build_parser()
    ns = parser.parse_args()

    try:
        extra_labels = parse_labels(ns.label)
    except PrometheusError as exc:
        parser.error(str(exc))

    try:
        monitor_result = run_monitor(ns)
    except common.MonitorError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(2)

    metrics = format_metrics(ns, monitor_result.report, monitor_result.returncode, extra_labels)
    print(metrics, end="")

    if ns.push_url and not ns.dry_run:
        try:
            push_metrics(ns.push_url, ns.push_method, metrics, ns.push_timeout)
        except PrometheusError as exc:
            print(f"[error] {exc}", file=sys.stderr)
            sys.exit(2)

    sys.exit(monitor_result.returncode)


if __name__ == "__main__":
    main()
