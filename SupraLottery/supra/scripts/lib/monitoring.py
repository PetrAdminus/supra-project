"""Reusable Supra CLI helpers for monitoring and HTTP services."""
from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Mapping, Optional, Sequence

try:  # pragma: no cover - import shim for both package and script usage
    from ..calc_min_balance import calculate  # type: ignore[import]
    from ..monitor_common import MonitorError, env_default  # type: ignore[import]
except ImportError:  # pragma: no cover - fallback when executed as a script
    from calc_min_balance import calculate  # type: ignore[import,no-redef]
    from monitor_common import MonitorError, env_default  # type: ignore[import,no-redef]

DEFAULT_MARGIN = 0.15
DEFAULT_WINDOW = 30


class CliError(MonitorError):
    """Raised when Supra CLI returns an error or malformed payload."""


class ConfigError(ValueError):
    """Raised when monitor configuration is missing required fields."""


@dataclass(slots=True)
class MonitorConfig:
    """Configuration required to gather Supra lottery status."""

    profile: str
    lottery_addr: str
    deposit_addr: str
    max_gas_price: int
    max_gas_limit: int
    verification_gas: int
    client_addr: Optional[str] = None
    supra_cli_bin: str = "/supra/supra"
    supra_config: Optional[str] = None
    margin: float = DEFAULT_MARGIN
    window: int = DEFAULT_WINDOW

    def __post_init__(self) -> None:
        if not self.profile:
            raise ConfigError("Supra CLI profile is required")
        if not self.lottery_addr:
            raise ConfigError("Lottery contract address is required")
        if not self.deposit_addr:
            raise ConfigError("Deposit module address is required")
        if self.client_addr is None or self.client_addr == "":
            self.client_addr = self.lottery_addr
        if self.margin < 0:
            raise ConfigError("Margin cannot be negative")
        if self.window <= 0:
            raise ConfigError("Window must be positive")

    @property
    def lottery_prefix(self) -> str:
        return f"{self.lottery_addr}::main_v2"

    @property
    def deposit_prefix(self) -> str:
        return f"{self.deposit_addr}::deposit"

    @property
    def treasury_prefix(self) -> str:
        return f"{self.lottery_addr}::treasury_v1"


def monitor_config_from_namespace(ns: Any) -> MonitorConfig:
    """Build :class:`MonitorConfig` from argparse namespace."""

    missing_int = [
        name
        for name in ("max_gas_price", "max_gas_limit", "verification_gas")
        if getattr(ns, name, None) is None
    ]
    if missing_int:
        missing = ", ".join(missing_int)
        raise ConfigError(
            f"Недостаточно параметров для расчёта min_balance: {missing}. "
            "Укажите их аргументами CLI или через переменные окружения."
        )

    return MonitorConfig(
        profile=getattr(ns, "profile"),
        lottery_addr=getattr(ns, "lottery_addr"),
        deposit_addr=getattr(ns, "deposit_addr"),
        client_addr=getattr(ns, "client_addr", None),
        supra_cli_bin=getattr(ns, "supra_cli_bin", "/supra/supra"),
        supra_config=getattr(ns, "supra_config", None),
        max_gas_price=int(getattr(ns, "max_gas_price")),
        max_gas_limit=int(getattr(ns, "max_gas_limit")),
        verification_gas=int(getattr(ns, "verification_gas")),
        margin=float(getattr(ns, "margin", DEFAULT_MARGIN)),
        window=int(getattr(ns, "window", DEFAULT_WINDOW)),
    )


def monitor_config_from_env(
    env: Mapping[str, str] | None = None,
    overrides: Mapping[str, str] | None = None,
) -> MonitorConfig:
    """Build :class:`MonitorConfig` using environment variables."""

    env = dict(env or os.environ)
    overrides = overrides or {}

    def require(name: str) -> str:
        value = overrides.get(name) or env.get(name)
        if not value:
            raise ConfigError(f"Environment variable {name} is required")
        return value

    def optional(name: str) -> Optional[str]:
        return overrides.get(name) or env.get(name)

    def optional_float(name: str, default: float) -> float:
        raw = overrides.get(name) or env.get(name)
        if raw is None:
            return default
        try:
            return float(raw)
        except ValueError as exc:  # pragma: no cover - validation guard
            raise ConfigError(f"Failed to cast {name} to float") from exc

    def optional_int(name: str, default: int) -> int:
        raw = overrides.get(name) or env.get(name)
        if raw is None:
            return default
        try:
            return int(raw)
        except ValueError as exc:  # pragma: no cover - validation guard
            raise ConfigError(f"Failed to cast {name} to int") from exc

    max_gas_price = env_default("MAX_GAS_PRICE", int)
    max_gas_limit = env_default("MAX_GAS_LIMIT", int)
    verification_gas = env_default("VERIFICATION_GAS_VALUE", int)

    # Allow overrides to take precedence over ``env_default`` values.
    if "MAX_GAS_PRICE" in overrides:
        max_gas_price = optional_int("MAX_GAS_PRICE", 0)
    if "MAX_GAS_LIMIT" in overrides:
        max_gas_limit = optional_int("MAX_GAS_LIMIT", 0)
    if "VERIFICATION_GAS_VALUE" in overrides:
        verification_gas = optional_int("VERIFICATION_GAS_VALUE", 0)

    if max_gas_price is None or max_gas_limit is None or verification_gas is None:
        raise ConfigError(
            "MAX_GAS_PRICE, MAX_GAS_LIMIT и VERIFICATION_GAS_VALUE обязательны для мониторинга"
        )

    margin = optional_float("MIN_BALANCE_MARGIN", DEFAULT_MARGIN)
    window = optional_int("MIN_BALANCE_WINDOW", DEFAULT_WINDOW)

    return MonitorConfig(
        profile=require("PROFILE"),
        lottery_addr=require("LOTTERY_ADDR"),
        deposit_addr=require("DEPOSIT_ADDR"),
        client_addr=optional("CLIENT_ADDR"),
        supra_cli_bin=optional("SUPRA_CLI_BIN") or "/supra/supra",
        supra_config=optional("SUPRA_CONFIG"),
        max_gas_price=int(max_gas_price),
        max_gas_limit=int(max_gas_limit),
        verification_gas=int(verification_gas),
        margin=margin,
        window=window,
    )


def run_cli(config: MonitorConfig, extra: Sequence[str]) -> Dict[str, Any]:
    """Execute Supra CLI command and decode JSON response."""

    env = os.environ.copy()
    if config.supra_config:
        env["SUPRA_CONFIG"] = config.supra_config

    cmd = [config.supra_cli_bin] + list(extra)
    try:
        completed = subprocess.run(
            cmd,
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:  # pragma: no cover - CLI failure path
        raise CliError(
            f"Ошибка Supra CLI ({' '.join(cmd)}): {exc.stderr or exc.stdout}"
        ) from exc

    output = completed.stdout.strip()
    if not output:
        raise CliError(f"Пустой вывод Supra CLI для команды: {' '.join(cmd)}")
    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:  # pragma: no cover - validation guard
        raise CliError(f"Неверный JSON от Supra CLI: {output}") from exc


def move_view(
    config: MonitorConfig,
    function_id: str,
    call_args: Optional[Sequence[str]] = None,
) -> Any:
    """Call Supra ``move tool view`` and return the decoded ``result`` field."""

    cli_args: List[str] = [
        "move",
        "tool",
        "view",
        "--profile",
        config.profile,
        "--function-id",
        function_id,
    ]
    if call_args:
        cli_args.append("--args")
        cli_args.extend(call_args)
    data = run_cli(config, cli_args)
    return data.get("result")


def flatten_single_value(value: Any) -> Any:
    if isinstance(value, list) and len(value) == 1:
        return value[0]
    return value


def gather_data(config: MonitorConfig) -> Dict[str, Any]:
    """Collect Supra lottery and deposit status using CLI view calls."""

    calculation = calculate(
        config.max_gas_price,
        config.max_gas_limit,
        config.verification_gas,
        config.margin,
        config.window,
    )

    lottery_status = move_view(config, f"{config.lottery_prefix}::get_lottery_status")
    vrf_config = move_view(config, f"{config.lottery_prefix}::get_vrf_request_config")
    whitelist_status = move_view(config, f"{config.lottery_prefix}::get_whitelist_status")
    ticket_price = move_view(config, f"{config.lottery_prefix}::get_ticket_price")
    registered_tickets = move_view(
        config,
        f"{config.lottery_prefix}::get_registered_tickets",
    )
    client_whitelist_snapshot = move_view(
        config,
        f"{config.lottery_prefix}::get_client_whitelist_snapshot",
    )
    min_balance_snapshot = move_view(
        config,
        f"{config.lottery_prefix}::get_min_balance_limit_snapshot",
    )
    consumer_whitelist_snapshot = move_view(
        config,
        f"{config.lottery_prefix}::get_consumer_whitelist_snapshot",
    )

    deposit_balance = move_view(
        config,
        f"{config.deposit_prefix}::checkClientFund",
        [f"address:{config.client_addr}"],
    )
    min_balance_on_chain = move_view(
        config,
        f"{config.deposit_prefix}::checkMinBalanceClient",
        [f"address:{config.client_addr}"],
    )
    min_balance_reached = move_view(
        config,
        f"{config.deposit_prefix}::isMinimumBalanceReached",
        [f"address:{config.client_addr}"],
    )
    contract_details = move_view(
        config,
        f"{config.deposit_prefix}::getContractDetails",
        [f"address:{config.lottery_addr}"],
    )
    subscription_info = move_view(
        config,
        f"{config.deposit_prefix}::getSubscriptionInfoByClient",
        [f"address:{config.client_addr}"],
    )

    whitelisted_contracts = move_view(
        config,
        f"{config.deposit_prefix}::listAllWhitelistedContractByClient",
        [f"address:{config.client_addr}"],
    )

    max_gas_price_on_chain = move_view(
        config,
        f"{config.deposit_prefix}::checkMaxGasPriceClient",
        [f"address:{config.client_addr}"],
    )
    max_gas_limit_on_chain = move_view(
        config,
        f"{config.deposit_prefix}::checkMaxGasLimitClient",
        [f"address:{config.client_addr}"],
    )

    treasury_config = move_view(
        config,
        f"{config.treasury_prefix}::get_config",
    )
    treasury_recipients = move_view(
        config,
        f"{config.treasury_prefix}::get_recipients",
    )
    treasury_balance = move_view(
        config,
        f"{config.treasury_prefix}::treasury_balance",
    )
    treasury_total_supply = move_view(
        config,
        f"{config.treasury_prefix}::total_supply",
    )
    treasury_metadata = move_view(
        config,
        f"{config.treasury_prefix}::metadata_summary",
    )

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "profile": config.profile,
        "lottery_addr": config.lottery_addr,
        "deposit_addr": config.deposit_addr,
        "client_addr": config.client_addr,
        "calculation": calculation.to_json(),
        "lottery": {
            "status": lottery_status,
            "vrf_request_config": vrf_config,
            "whitelist_status": whitelist_status,
            "ticket_price": flatten_single_value(ticket_price),
            "registered_tickets": registered_tickets,
            "client_whitelist_snapshot": client_whitelist_snapshot,
            "min_balance_snapshot": flatten_single_value(min_balance_snapshot),
            "consumer_whitelist_snapshot": consumer_whitelist_snapshot,
        },
        "deposit": {
            "balance": flatten_single_value(deposit_balance),
            "min_balance": flatten_single_value(min_balance_on_chain),
            "min_balance_reached": flatten_single_value(min_balance_reached),
            "contract_details": contract_details,
            "subscription_info": subscription_info,
            "whitelisted_contracts": whitelisted_contracts,
            "max_gas_price": flatten_single_value(max_gas_price_on_chain),
            "max_gas_limit": flatten_single_value(max_gas_limit_on_chain),
        },
        "treasury": {
            "config": treasury_config,
            "recipients": treasury_recipients,
            "balance": flatten_single_value(treasury_balance),
            "total_supply": flatten_single_value(treasury_total_supply),
            "metadata": treasury_metadata,
        },
    }


__all__ = [
    "CliError",
    "ConfigError",
    "MonitorConfig",
    "DEFAULT_MARGIN",
    "DEFAULT_WINDOW",
    "monitor_config_from_env",
    "monitor_config_from_namespace",
    "gather_data",
]
