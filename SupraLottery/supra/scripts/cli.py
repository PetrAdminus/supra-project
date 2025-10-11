"""Единая точка входа для вспомогательных скриптов SupraLottery."""
from __future__ import annotations

import argparse
import importlib
import sys
from typing import Dict, Iterable, List, Tuple

# Имя команды -> (python модуль, описание)
COMMAND_MAP: Dict[str, Tuple[str, str]] = {
    "calc-min-balance": (
        "supra.scripts.calc_min_balance",
        "Рассчитать минимальный депозит и комиссию Supra dVRF",
    ),
    "monitor-json": (
        "supra.scripts.testnet_monitor_json",
        "Собрать JSON-отчёт о подписке и проверить лимиты",
    ),
    "monitor-slack": (
        "supra.scripts.testnet_monitor_slack",
        "Отправить отчёт в Slack/webhook на базе monitor_json",
    ),
    "monitor-prometheus": (
        "supra.scripts.testnet_monitor_prometheus",
        "Экспортировать метрики мониторинга в Prometheus/Pushgateway",
    ),
    "draw-readiness": (
        "supra.scripts.testnet_draw_readiness",
        "Проверить готовность контракта к manual_draw",
    ),
    "manual-draw": (
        "supra.scripts.testnet_manual_draw",
        "Выполнить manual_draw с предварительной проверкой",
    ),
    "auto-draw": (
        "supra.automation.auto_draw_runner",
        "Проверить готовность и при необходимости выполнить manual_draw",
    ),
    "set-minimum-balance": (
        "supra.scripts.set_minimum_balance",
        "Обновить минимальный баланс клиента dVRF",
    ),
    "configure-treasury-distribution": (
        "supra.scripts.configure_treasury_distribution",
        "Настроить распределение призовых долей",
    ),
    "configure-vrf-gas": (
        "supra.scripts.configure_vrf_gas",
        "Обновить лимиты газа для подписки dVRF",
    ),
    "configure-vrf-request": (
        "supra.scripts.configure_vrf_request",
        "Настроить параметры запроса случайности",
    ),
    "remove-subscription": (
        "supra.scripts.remove_subscription",
        "Удалить контракт лотереи из подписки Supra dVRF",
    ),
    "move-test": (
        "supra.scripts.move_tests",
        "Запустить Move-тесты supra/move_workspace через Supra/Aptos/Move CLI",
    ),
    "vrf-audit": (
        "supra.scripts.testnet_vrf_audit",
        "Выгрузить события VRF и состояние раунда для панели честности",
    ),
}


def iter_commands() -> Iterable[Tuple[str, str, str]]:
    """Итерирует команды в алфавитном порядке."""
    for name in sorted(COMMAND_MAP):
        module, description = COMMAND_MAP[name]
        yield name, module, description


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Унифицированный CLI для скриптов SupraLottery", add_help=True
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="показать доступные команды и выйти",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=sorted(COMMAND_MAP.keys()),
        help="имя подкоманды (используйте --list для вывода полного перечня)",
    )
    parser.add_argument(
        "command_args",
        nargs=argparse.REMAINDER,
        help="аргументы, передаваемые выбранной подкоманде (начните с -- для разделения)",
    )
    return parser


def run_module(module_name: str, argv: List[str]) -> None:
    """Импортирует модуль и запускает его функцию main с подменой sys.argv."""
    module = importlib.import_module(module_name)
    main = getattr(module, "main", None)
    if main is None:
        raise SystemExit(f"Модуль {module_name} не содержит функцию main")

    old_argv = sys.argv
    sys.argv = [module_name] + argv
    try:
        main()  # type: ignore[call-arg]
    finally:
        sys.argv = old_argv


def main(argv: List[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list:
        for name, module, description in iter_commands():
            print(f"{name:<18} -> {module}\n    {description}")
        return

    if not args.command:
        parser.error("Нужно указать команду или флаг --list")

    command_args: List[str] = list(args.command_args or [])
    if command_args and command_args[0] == "--":
        command_args = command_args[1:]

    module_name = COMMAND_MAP[args.command][0]
    run_module(module_name, command_args)


if __name__ == "__main__":
    main()
