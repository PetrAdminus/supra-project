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
    """Конфигурация мониторинга мульти-лотерей и VRF-хаба."""

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
    hub_addr: Optional[str] = None
    factory_addr: Optional[str] = None
    lottery_ids: Optional[List[int]] = None

    def __post_init__(self) -> None:
        if not self.profile:
            raise ConfigError("Supra CLI profile is required")
        if not self.lottery_addr:
            raise ConfigError("Lottery contract address is required")
        if not self.deposit_addr:
            raise ConfigError("Deposit module address is required")
        if self.client_addr is None or self.client_addr == "":
            self.client_addr = self.lottery_addr
        if not self.hub_addr:
            self.hub_addr = self.lottery_addr
        if not self.factory_addr:
            self.factory_addr = self.lottery_addr
        if self.margin < 0:
            raise ConfigError("Margin cannot be negative")
        if self.window <= 0:
            raise ConfigError("Window must be positive")
        if self.lottery_ids is None:
            self.lottery_ids = []

    @property
    def hub_prefix(self) -> str:
        return f"{self.hub_addr}::hub"

    @property
    def factory_prefix(self) -> str:
        return f"{self.factory_addr}::registry"

    @property
    def instances_prefix(self) -> str:
        return f"{self.lottery_addr}::instances"

    @property
    def rounds_prefix(self) -> str:
        return f"{self.lottery_addr}::rounds"

    @property
    def deposit_prefix(self) -> str:
        return f"{self.deposit_addr}::deposit"

    @property
    def treasury_prefix(self) -> str:
        return f"{self.lottery_addr}::treasury_multi"

    @property
    def treasury_fa_prefix(self) -> str:
        return f"{self.lottery_addr}::treasury"

    @property
    def autopurchase_prefix(self) -> str:
        return f"{self.lottery_addr}::autopurchase"

    @property
    def referrals_prefix(self) -> str:
        return f"{self.lottery_addr}::referrals"

    @property
    def vip_prefix(self) -> str:
        return f"{self.lottery_addr}::vip"

    @property
    def metadata_prefix(self) -> str:
        return f"{self.lottery_addr}::metadata"

    @property
    def operators_prefix(self) -> str:
        return f"{self.lottery_addr}::operators"

    @property
    def history_prefix(self) -> str:
        return f"{self.lottery_addr}::history"

    @property
    def health_prefix(self) -> str:
        return f"{self.lottery_addr}::health"


def _parse_lottery_ids(raw: Any) -> List[int]:
    """Преобразует строку/список в упорядоченный список идентификаторов лотерей."""

    if raw is None:
        return []

    if isinstance(raw, list | tuple):
        candidates = list(raw)
    else:
        text = str(raw).strip()
        if not text:
            return []
        if text.startswith("["):
            try:
                parsed = json.loads(text)
            except json.JSONDecodeError as exc:  # pragma: no cover - валидация пользовательских данных
                raise ConfigError("Не удалось распарсить LOTTERY_IDS как JSON") from exc
            if not isinstance(parsed, list):
                raise ConfigError("LOTTERY_IDS должен быть списком чисел")
            candidates = parsed
        else:
            candidates = [item.strip() for item in text.split(",") if item.strip()]

    lottery_ids: List[int] = []
    for item in candidates:
        try:
            lottery_ids.append(int(item))
        except (TypeError, ValueError) as exc:  # pragma: no cover - пользовательская ошибка
            raise ConfigError(f"Неверный идентификатор лотереи: {item}") from exc

    # Удаляем дубликаты, сохраняя порядок
    seen: set[int] = set()
    ordered: List[int] = []
    for value in lottery_ids:
        if value not in seen:
            seen.add(value)
            ordered.append(value)
    return ordered


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
        hub_addr=getattr(ns, "hub_addr", None) or getattr(ns, "lottery_addr"),
        factory_addr=getattr(ns, "factory_addr", None) or getattr(ns, "lottery_addr"),
        lottery_ids=_parse_lottery_ids(getattr(ns, "lottery_ids", None)),
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

    lottery_addr = require("LOTTERY_ADDR")
    hub_addr = overrides.get("HUB_ADDR") or env.get("HUB_ADDR") or lottery_addr
    factory_addr = overrides.get("FACTORY_ADDR") or env.get("FACTORY_ADDR") or lottery_addr

    return MonitorConfig(
        profile=require("PROFILE"),
        lottery_addr=lottery_addr,
        deposit_addr=require("DEPOSIT_ADDR"),
        client_addr=optional("CLIENT_ADDR"),
        supra_cli_bin=optional("SUPRA_CLI_BIN") or "/supra/supra",
        supra_config=optional("SUPRA_CONFIG"),
        max_gas_price=int(max_gas_price),
        max_gas_limit=int(max_gas_limit),
        verification_gas=int(verification_gas),
        margin=margin,
        window=window,
        hub_addr=hub_addr,
        factory_addr=factory_addr,
        lottery_ids=_parse_lottery_ids(optional("LOTTERY_IDS")),
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


def extract_optional(value: Any) -> Any:
    """Возвращает None для пустого списка и распаковывает одно значение."""

    if isinstance(value, list):
        if not value:
            return None
        if len(value) == 1:
            return value[0]
    return value


def normalize_int(value: Any) -> Optional[int]:
    """Пытается привести значение (строку/список) к целому числу."""

    collapsed = flatten_single_value(value)
    if isinstance(collapsed, int):
        return collapsed
    if isinstance(collapsed, str):
        text = collapsed.strip()
        if not text:
            return None
        base = 16 if text.startswith("0x") else 10
        try:
            return int(text, base)
        except ValueError:  # pragma: no cover - защита от неожиданного формата CLI
            return None
    if isinstance(collapsed, float):
        return int(collapsed)
    return None


def normalize_bool(value: Any) -> bool:
    """Конвертирует значение Supra CLI в булево."""

    collapsed = flatten_single_value(value)
    if isinstance(collapsed, bool):
        return collapsed
    if isinstance(collapsed, (int, float)):
        return bool(collapsed)
    if isinstance(collapsed, str):
        return collapsed.strip().lower() in {"true", "1", "yes", "on"}
    return False


def normalize_int_list(value: Any) -> List[int]:
    """Пытается привести коллекцию к списку целых чисел."""

    if value is None:
        return []
    if isinstance(value, list):
        result: List[int] = []
        for item in value:
            normalized = normalize_int(item)
            if normalized is not None:
                result.append(normalized)
        return result
    normalized = normalize_int(value)
    return [] if normalized is None else [normalized]


def normalize_address_list(value: Any) -> List[str]:
    """Преобразует коллекцию адресов в список строк."""

    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    collapsed = flatten_single_value(value)
    return [] if collapsed is None else [str(collapsed)]


HEALTH_FIELDS = (
    "storage_ready",
    "queues_ready",
    "treasury_ready",
    "rewards_ready",
    "autopurchase_ready",
    "utils_ready",
    "history_ready",
    "gateway_ready",
    "access_ready",
    "cancellations_ready",
    "automation_ready",
    "vrf_ready",
    "engine_ready",
)


def normalize_health_snapshot(value: Any) -> Dict[str, bool]:
    """Преобразует результат health::snapshot в словарь булевых флагов."""

    snapshot: Dict[str, bool] = {field: False for field in HEALTH_FIELDS}
    payload = extract_optional(value)
    if isinstance(payload, dict):
        for field in snapshot:
            snapshot[field] = bool(payload.get(field, False))
    return snapshot


def gather_data(config: MonitorConfig) -> Dict[str, Any]:
    """Собирает агрегированный отчёт по VRF-хабу и мульти-лотереям."""

    calculation = calculate(
        config.max_gas_price,
        config.max_gas_limit,
        config.verification_gas,
        config.margin,
        config.window,
    )

    hub_lottery_count = move_view(config, f"{config.hub_prefix}::lottery_count")
    hub_next_lottery_id = move_view(config, f"{config.hub_prefix}::peek_next_lottery_id")
    hub_callback_sender = move_view(config, f"{config.hub_prefix}::callback_sender")

    health_raw = move_view(config, f"{config.health_prefix}::snapshot")
    health_snapshot = normalize_health_snapshot(health_raw)

    inferred_next_id = normalize_int(hub_next_lottery_id)
    configured_ids = list(config.lottery_ids or [])
    if not configured_ids and inferred_next_id is not None and inferred_next_id >= 0:
        configured_ids = list(range(inferred_next_id))

    instances_ready = health_snapshot["storage_ready"]
    rounds_ready = health_snapshot["queues_ready"]
    treasury_ready = health_snapshot["treasury_ready"]
    autopurchase_ready = health_snapshot["autopurchase_ready"]
    referrals_ready = normalize_bool(
        move_view(config, f"{config.referrals_prefix}::is_initialized")
    )
    vip_ready = normalize_bool(move_view(config, f"{config.vip_prefix}::is_initialized"))
    metadata_ready = normalize_bool(
        move_view(config, f"{config.metadata_prefix}::is_initialized")
    )
    operators_ready = normalize_bool(move_view(config, f"{config.operators_prefix}::ready"))
    history_ready = health_snapshot["history_ready"]

    lotteries: List[Dict[str, Any]] = []
    for lottery_id in configured_ids:
        registration = extract_optional(
            move_view(config, f"{config.hub_prefix}::get_registration", [f"u64:{lottery_id}"])
        )
        if registration is None:
            continue

        factory_info = extract_optional(
            move_view(config, f"{config.factory_prefix}::get_lottery", [f"u64:{lottery_id}"])
        )

        instance_info = None
        instance_stats = None
        if instances_ready:
            instance_info = extract_optional(
                move_view(config, f"{config.instances_prefix}::get_lottery_info", [f"u64:{lottery_id}"])
            )
            instance_stats = extract_optional(
                move_view(config, f"{config.instances_prefix}::get_instance_stats", [f"u64:{lottery_id}"])
            )

        round_snapshot = None
        pending_request = None
        if rounds_ready:
            round_snapshot = extract_optional(
                move_view(config, f"{config.rounds_prefix}::get_round_snapshot", [f"u64:{lottery_id}"])
            )
            pending_request = extract_optional(
                move_view(config, f"{config.rounds_prefix}::pending_request_id", [f"u64:{lottery_id}"])
            )

        treasury_config = None
        treasury_pool = None
        if treasury_ready:
            treasury_config = extract_optional(
                move_view(config, f"{config.treasury_prefix}::get_config", [f"u64:{lottery_id}"])
            )
            treasury_pool = extract_optional(
                move_view(config, f"{config.treasury_prefix}::get_pool", [f"u64:{lottery_id}"])
            )

        metadata_payload = None
        if metadata_ready:
            metadata_payload = extract_optional(
                move_view(
                    config,
                    f"{config.metadata_prefix}::get_metadata",
                    [f"u64:{lottery_id}"],
                )
            )

        latest_history = None
        if history_ready:
            latest_history = extract_optional(
                move_view(
                    config,
                    f"{config.history_prefix}::latest_record",
                    [f"u64:{lottery_id}"],
                )
            )

        lotteries.append(
            {
                "lottery_id": lottery_id,
                "registration": registration,
                "factory": factory_info,
                "instance": instance_info,
                "stats": instance_stats,
                "round": {
                    "snapshot": round_snapshot,
                    "pending_request_id": pending_request,
                },
                "treasury": {
                    "config": treasury_config,
                    "pool": treasury_pool,
                },
                "metadata": metadata_payload,
                "latest_history": latest_history,
            }
        )

    jackpot_balance = None
    if treasury_ready:
        jackpot_balance = flatten_single_value(
            move_view(config, f"{config.treasury_prefix}::jackpot_balance")
        )

    autopurchase_overview: Dict[str, Any] = {"initialized": autopurchase_ready, "lotteries": []}
    if autopurchase_ready:
        autopurchase_ids_raw = move_view(config, f"{config.autopurchase_prefix}::list_lottery_ids")
        autopurchase_ids = normalize_int_list(autopurchase_ids_raw)
        for lottery_id in autopurchase_ids:
            summary = extract_optional(
                move_view(
                    config,
                    f"{config.autopurchase_prefix}::get_lottery_summary",
                    [f"u64:{lottery_id}"],
                )
            )
            players_raw = extract_optional(
                move_view(
                    config,
                    f"{config.autopurchase_prefix}::list_players",
                    [f"u64:{lottery_id}"],
                )
            )
            autopurchase_overview["lotteries"].append(
                {
                    "lottery_id": lottery_id,
                    "summary": summary,
                    "players": normalize_address_list(players_raw),
                }
            )

    metadata_overview: Dict[str, Any] = {"initialized": metadata_ready, "lotteries": []}
    if metadata_ready:
        metadata_ids_raw = move_view(config, f"{config.metadata_prefix}::list_lottery_ids")
        metadata_ids = normalize_int_list(metadata_ids_raw)
        for lottery_id in metadata_ids:
            payload = extract_optional(
                move_view(
                    config,
                    f"{config.metadata_prefix}::get_metadata",
                    [f"u64:{lottery_id}"],
                )
            )
            metadata_overview["lotteries"].append(
                {"lottery_id": lottery_id, "metadata": payload}
            )

    operators_overview: Dict[str, Any] = {"initialized": operators_ready, "lotteries": []}
    if operators_ready:
        operator_ids_raw = move_view(config, f"{config.operators_prefix}::list_lottery_ids")
        operator_ids = normalize_int_list(operator_ids_raw)
        for lottery_id in operator_ids:
            owner_payload = extract_optional(
                move_view(
                    config,
                    f"{config.operators_prefix}::get_owner",
                    [f"u64:{lottery_id}"],
                )
            )
            operators_payload = extract_optional(
                move_view(
                    config,
                    f"{config.operators_prefix}::list_operators",
                    [f"u64:{lottery_id}"],
                )
            )
            operators_overview["lotteries"].append(
                {
                    "lottery_id": lottery_id,
                    "owner": owner_payload,
                    "operators": normalize_address_list(operators_payload),
                }
            )

    history_overview: Dict[str, Any] = {"initialized": history_ready, "lotteries": []}
    if history_ready:
        history_ids_raw = move_view(config, f"{config.history_prefix}::list_lottery_ids")
        history_ids = normalize_int_list(history_ids_raw)
        for lottery_id in history_ids:
            records_payload = extract_optional(
                move_view(
                    config,
                    f"{config.history_prefix}::get_history",
                    [f"u64:{lottery_id}"],
                )
            )
            history_overview["lotteries"].append(
                {"lottery_id": lottery_id, "records": records_payload}
            )

    referrals_overview: Dict[str, Any] = {"initialized": referrals_ready, "lotteries": []}
    if referrals_ready:
        referral_ids_raw = move_view(config, f"{config.referrals_prefix}::list_lottery_ids")
        referral_ids = normalize_int_list(referral_ids_raw)
        for lottery_id in referral_ids:
            config_payload = extract_optional(
                move_view(
                    config,
                    f"{config.referrals_prefix}::get_lottery_config",
                    [f"u64:{lottery_id}"],
                )
            )
            stats_payload = extract_optional(
                move_view(
                    config,
                    f"{config.referrals_prefix}::get_lottery_stats",
                    [f"u64:{lottery_id}"],
                )
            )
            referrals_overview["lotteries"].append(
                {
                    "lottery_id": lottery_id,
                    "config": config_payload,
                    "stats": stats_payload,
                }
            )

    vip_overview: Dict[str, Any] = {"initialized": vip_ready, "lotteries": []}
    if vip_ready:
        vip_ids_raw = move_view(config, f"{config.vip_prefix}::list_lottery_ids")
        vip_ids = normalize_int_list(vip_ids_raw)
        for lottery_id in vip_ids:
            summary_payload = extract_optional(
                move_view(
                    config,
                    f"{config.vip_prefix}::get_lottery_summary",
                    [f"u64:{lottery_id}"],
                )
            )
            players_payload = extract_optional(
                move_view(
                    config,
                    f"{config.vip_prefix}::list_players",
                    [f"u64:{lottery_id}"],
                )
            )
            vip_overview["lotteries"].append(
                {
                    "lottery_id": lottery_id,
                    "summary": summary_payload,
                    "players": normalize_address_list(players_payload),
                }
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

    treasury_balance = move_view(config, f"{config.treasury_fa_prefix}::treasury_balance")
    treasury_total_supply = move_view(config, f"{config.treasury_fa_prefix}::total_supply")
    treasury_metadata = move_view(config, f"{config.treasury_fa_prefix}::metadata_summary")

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "profile": config.profile,
        "addresses": {
            "lottery": config.lottery_addr,
            "hub": config.hub_addr,
            "factory": config.factory_addr,
            "deposit": config.deposit_addr,
            "client": config.client_addr,
        },
        "health": health_snapshot,
        "calculation": calculation.to_json(),
        "hub": {
            "lottery_count": flatten_single_value(hub_lottery_count),
            "next_lottery_id": flatten_single_value(hub_next_lottery_id),
            "callback_sender": extract_optional(hub_callback_sender),
            "configured_lottery_ids": configured_ids,
        },
        "lotteries": lotteries,
        "autopurchase": autopurchase_overview,
        "metadata": metadata_overview,
        "operators": operators_overview,
        "history": history_overview,
        "referrals": referrals_overview,
        "vip": vip_overview,
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
            "jackpot_balance": jackpot_balance,
            "token_balance": flatten_single_value(treasury_balance),
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
