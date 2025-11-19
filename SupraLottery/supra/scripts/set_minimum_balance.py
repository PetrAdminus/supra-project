"""Set minimum balance for the Supra lottery via Supra CLI."""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from .monitor_common import MonitorError, add_monitor_arguments
from .lib.monitoring import ConfigError, gather_data, monitor_config_from_namespace
from .lib.transactions import execute_move_tool_run


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Запустить lottery::set_minimum_balance и обновить per_request_fee/min_balance",
    )
    add_monitor_arguments(parser, include_fail_on_low=False)
    parser.add_argument(
        "--expected-min-balance",
        type=int,
        default=None,
        help="ожидаемое значение min_balance (u128), используемое для валидации перед транзакцией",
    )
    parser.add_argument(
        "--expected-max-gas-fee",
        type=int,
        default=None,
        help="ожидаемое значение per_request_fee/max_gas_fee (u64), сверяется с расчётом",
    )
    parser.add_argument(
        "--assume-yes",
        action="store_true",
        help="передать --assume-yes в Supra CLI, чтобы избежать интерактивного подтверждения",
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
            "<lottery_addr>::core_main_v2::set_minimum_balance"
        ),
    )
    return parser


def _parse_int(value: object) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        try:
            return int(value)
        except (TypeError, ValueError):  # pragma: no cover - defensive
            return None
    if isinstance(value, str):
        value = value.strip()
        if not value:
            return None
        try:
            return int(value)
        except ValueError:
            return None
    return None


def _expected_values(ns: argparse.Namespace) -> Tuple[int, int]:
    try:
        config = monitor_config_from_namespace(ns)
    except ConfigError as exc:
        raise MonitorError(str(exc)) from exc

    report = gather_data(config)
    calculation = report.get("calculation") or {}
    deposit = report.get("deposit") or {}

    per_request = _parse_int(calculation.get("per_request_fee"))
    min_balance_calculated = _parse_int(calculation.get("min_balance"))
    min_balance_on_chain = _parse_int(deposit.get("min_balance"))

    if per_request is None:
        raise MonitorError(
            "Не удалось получить расчёт per_request_fee из monitor_json. Проверьте параметры CLI и доступ к Supra CLI.",
        )

    min_balance = min_balance_on_chain if min_balance_on_chain is not None else min_balance_calculated
    if min_balance is None:
        raise MonitorError(
            "Не удалось определить min_balance из мониторинга Supra. Убедитесь, что deposit::checkMinBalanceClient доступен.",
        )

    return min_balance, per_request


def target_function_id(ns: argparse.Namespace) -> str:
    if ns.function_id:
        return str(ns.function_id)
    if not ns.lottery_addr:
        raise MonitorError("Нужно указать адрес контракта лотереи (--lottery-addr)")
    return f"{ns.lottery_addr}::core_main_v2::set_minimum_balance"


def _validate_expectations(
    ns: argparse.Namespace,
    *,
    min_balance: int,
    per_request: int,
) -> None:
    expected_min = getattr(ns, "expected_min_balance", None)
    if expected_min is not None and int(expected_min) != min_balance:
        raise MonitorError(
            "Ожидаемое значение min_balance не совпадает с расчётом Supra CLI. "
            f"Передано {expected_min}, расчёт {min_balance}. Обновите настройки VRF и повторите."
        )

    expected_fee = getattr(ns, "expected_max_gas_fee", None)
    if expected_fee is not None and int(expected_fee) != per_request:
        raise MonitorError(
            "Ожидаемое значение max_gas_fee не совпадает с расчётом Supra CLI. "
            f"Передано {expected_fee}, расчёт {per_request}. Обновите настройки VRF и повторите."
        )


def execute(ns: argparse.Namespace, *, now: Optional[datetime] = None) -> Dict[str, object]:
    min_balance, per_request = _expected_values(ns)
    _validate_expectations(ns, min_balance=min_balance, per_request=per_request)

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

    payload = dict(result)
    payload["expected_min_balance"] = min_balance
    payload["expected_max_gas_fee"] = per_request
    return payload


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
    "execute",
    "main",
    "target_function_id",
]

