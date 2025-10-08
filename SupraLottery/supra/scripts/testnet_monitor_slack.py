#!/usr/bin/env python3
"""Send Supra dVRF monitor report to a webhook (Slack/Teams compatible).

The script reuses ``testnet_monitor_json.py`` to collect data, then formats
an alert message and posts it to the configured webhook. It is intended for
cron/CI/AutoFi jobs that already export the same environment variables as the
other monitoring helpers.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Optional

from . import monitor_common as common

DEFAULT_TITLE = "Supra dVRF статус"
DEFAULT_WEBHOOK_TYPE = "slack"


MonitorError = common.MonitorError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Собрать отчёт Supra dVRF и отправить уведомление в Slack/webhook",
    )
    parser.add_argument(
        "--webhook-url",
        default=os.environ.get("MONITOR_WEBHOOK_URL"),
        help="URL входящего webhook (Slack/Teams/произвольный JSON)",
    )
    parser.add_argument(
        "--webhook-type",
        choices=("slack", "generic"),
        default=os.environ.get("MONITOR_WEBHOOK_TYPE", DEFAULT_WEBHOOK_TYPE),
        help="Формат payload: slack (поле text) или generic (raw JSON)",
    )
    parser.add_argument(
        "--title",
        default=os.environ.get("MONITOR_TITLE", DEFAULT_TITLE),
        help="Заголовок сообщения",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Не отправлять webhook, а только вывести сообщение",
    )
    parser.add_argument(
        "--include-json",
        action="store_true",
        help="Добавить JSON-отчёт в тело сообщения (кодовый блок Slack)",
    )
    common.add_monitor_arguments(parser)
    return parser


build_monitor_args = common.build_monitor_args
run_monitor = common.run_monitor


def _truthy(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


def _pick_primary_lottery(report: dict) -> Optional[dict]:
    lotteries = report.get("lotteries")
    if not isinstance(lotteries, list):
        return None
    # Сначала выбираем активную лотерею, если есть соответствующая регистрация
    for entry in lotteries:
        registration = entry.get("registration") if isinstance(entry, dict) else None
        if isinstance(registration, dict) and _truthy(registration.get("active")):
            return entry
    return lotteries[0] if lotteries else None


def format_message(ns: argparse.Namespace, report: dict, monitor_rc: int) -> str:
    balance = int(report["deposit"]["balance"])
    min_balance = int(report["calculation"]["min_balance"])
    status_emoji = "✅" if balance >= min_balance else "⚠️"
    primary_lottery = _pick_primary_lottery(report)
    draw_summary = ""
    if isinstance(primary_lottery, dict):
        lottery_id = primary_lottery.get("lottery_id")
        round_section = primary_lottery.get("round")
        if isinstance(round_section, dict):
            snapshot = round_section.get("snapshot")
            pending = round_section.get("pending_request_id")
        else:
            snapshot = None
            pending = None
        parts = []
        if lottery_id is not None:
            parts.append(f"lottery_id={lottery_id}")
        if isinstance(snapshot, dict):
            parts.append(f"tickets={snapshot.get('ticket_count')}")
            parts.append(f"scheduled={snapshot.get('draw_scheduled')}")
            parts.append(f"has_pending={snapshot.get('has_pending_request')}")
        if pending is not None:
            parts.append(f"pending_request_id={pending}")
        draw_summary = " | ".join(filter(None, (str(item) for item in parts)))
    profile = ns.profile or "<не задан>"
    base = (
        f"{status_emoji} {ns.title}\n"
        f"Профиль: {profile}\n"
        f"Баланс депозита: {balance}\n"
        f"min_balance (с учётом запаса): {min_balance}\n"
        f"Лимиты газа: price={report['deposit']['max_gas_price']} | limit={report['deposit']['max_gas_limit']}\n"
        f"Минимальный баланс достигнут: {report['deposit']['min_balance_reached']}\n"
    )
    if draw_summary:
        base += f"Статус лотереи: {draw_summary}\n"
    if monitor_rc == 1:
        base += "⚠️ Баланс ниже минимального лимита!\n"
    return base


def post_webhook(ns: argparse.Namespace, payload: dict | str) -> None:
    data = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
    body = data.encode("utf-8")
    request = urllib.request.Request(
        ns.webhook_url,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            if response.status >= 300:
                raise MonitorError(f"Webhook вернул статус {response.status}")
    except urllib.error.URLError as exc:
        raise MonitorError(f"Не удалось отправить webhook: {exc}") from exc


def main() -> None:
    parser = build_parser()
    ns = parser.parse_args()

    if not ns.webhook_url:
        parser.error("Не указан webhook URL (параметр --webhook-url или переменная MONITOR_WEBHOOK_URL)")

    if ns.max_gas_price is None or ns.max_gas_limit is None or ns.verification_gas is None:
        parser.error("Нужно задать max_gas_price, max_gas_limit и verification_gas (аргументы или переменные окружения)")

    try:
        process = run_monitor(ns)
        report = json.loads(process.stdout)
    except (MonitorError, json.JSONDecodeError) as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(2)

    message = format_message(ns, report, process.returncode)

    if ns.include_json:
        pretty = json.dumps(report, indent=2, ensure_ascii=False)
        message = f"{message}\n```\n{pretty}\n```"

    if ns.dry_run:
        print(message)
        sys.exit(process.returncode)

    if ns.webhook_type == "slack":
        payload = {"text": message}
    else:
        payload = {"message": message, "data": report, "status": process.returncode}

    try:
        post_webhook(ns, payload)
    except MonitorError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(2)

    print(message)
    sys.exit(process.returncode)


if __name__ == "__main__":
    main()
