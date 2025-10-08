"""Вспомогательные функции для аудита VRF и панели честности."""
from __future__ import annotations

from dataclasses import dataclass
from collections.abc import Iterable, Mapping
from typing import Any, Dict, List, Optional

from .monitoring import CliError, MonitorConfig, extract_optional, move_view, run_cli

DEFAULT_EVENT_LIMIT = 50
MAX_EVENT_LIMIT = 500


@dataclass(slots=True)
class EventStream:
    """Описание набора событий, связанных с конкретным типом."""

    address: str
    event_type: str
    events: List[Dict[str, Any]]


def _normalize_event(raw: Any) -> Dict[str, Any]:
    if isinstance(raw, dict):
        event = dict(raw)
    else:
        event = {"raw": raw}
        return event

    data = event.get("data")
    if isinstance(data, dict):
        normalized_data = dict(data)
        event["data"] = normalized_data
        lottery_id = _parse_int(normalized_data.get("lottery_id"))
        if lottery_id is not None:
            event["lottery_id"] = lottery_id
    return event


def _parse_int(value: Any) -> Optional[int]:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        base = 16 if text.startswith("0x") else 10
        try:
            return int(text, base)
        except ValueError:
            return None
    return None


def _filter_by_lottery(events: Iterable[Any], lottery_id: int) -> List[Dict[str, Any]]:
    filtered: List[Dict[str, Any]] = []
    for raw in events:
        event = _normalize_event(raw)
        lottery_value = event.get("lottery_id")
        if lottery_value is None:
            lottery_value = _parse_int(
                event.get("data", {}).get("lottery_id") if isinstance(event.get("data"), Mapping) else None
            )
            if lottery_value is not None:
                event["lottery_id"] = lottery_value
        if lottery_value == lottery_id:
            filtered.append(event)
    return filtered


def events_list(
    config: MonitorConfig,
    *,
    address: str,
    event_type: Optional[str] = None,
    limit: int = DEFAULT_EVENT_LIMIT,
) -> List[Any]:
    limit = max(1, min(limit, MAX_EVENT_LIMIT))

    args: List[str] = [
        "move",
        "tool",
        "events",
        "list",
        "--profile",
        config.profile,
        "--address",
        address,
        "--limit",
        str(limit),
    ]
    if event_type:
        args.extend(["--event-type", event_type])

    response = run_cli(config, args)
    result = response.get("result")
    if result is None:
        return []
    if not isinstance(result, list):
        raise CliError(
            "Supra CLI вернул неожиданный формат для events list: ожидается список"
        )
    return result


def gather_vrf_log(config: MonitorConfig, lottery_id: int, limit: int = DEFAULT_EVENT_LIMIT) -> Dict[str, Any]:
    if lottery_id <= 0:
        raise ValueError("lottery_id должен быть положительным")
    limit = max(1, min(limit, MAX_EVENT_LIMIT))

    rounds_prefix = config.rounds_prefix
    hub_prefix = config.hub_prefix

    round_address = config.lottery_addr
    hub_address = config.hub_addr or config.lottery_addr

    round_requests = _filter_by_lottery(
        events_list(
            config,
            address=round_address,
            event_type=f"{rounds_prefix}::DrawRequestIssuedEvent",
            limit=limit,
        ),
        lottery_id,
    )
    round_fulfillments = _filter_by_lottery(
        events_list(
            config,
            address=round_address,
            event_type=f"{rounds_prefix}::DrawFulfilledEvent",
            limit=limit,
        ),
        lottery_id,
    )
    hub_requests = _filter_by_lottery(
        events_list(
            config,
            address=hub_address,
            event_type=f"{hub_prefix}::RandomnessRequestedEvent",
            limit=limit,
        ),
        lottery_id,
    )
    hub_fulfillments = _filter_by_lottery(
        events_list(
            config,
            address=hub_address,
            event_type=f"{hub_prefix}::RandomnessFulfilledEvent",
            limit=limit,
        ),
        lottery_id,
    )

    round_snapshot = extract_optional(
        move_view(config, f"{rounds_prefix}::get_round_snapshot", [f"u64:{lottery_id}"])
    )
    pending_request = extract_optional(
        move_view(config, f"{rounds_prefix}::pending_request_id", [f"u64:{lottery_id}"])
    )

    return {
        "lottery_id": lottery_id,
        "limit": limit,
        "round": {
            "snapshot": round_snapshot,
            "pending_request_id": pending_request,
            "requests": round_requests[:limit],
            "fulfillments": round_fulfillments[:limit],
        },
        "hub": {
            "requests": hub_requests[:limit],
            "fulfillments": hub_fulfillments[:limit],
        },
    }


__all__ = [
    "EventStream",
    "events_list",
    "gather_vrf_log",
]
