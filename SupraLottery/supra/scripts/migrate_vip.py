#!/usr/bin/env python3
"""Encode LegacyVipLottery payloads and optionally call the Move entry."""
from __future__ import annotations

import argparse
import json
import shlex
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON snapshot of VIP lotteries, encode it as "
            "vector<LegacyVipLottery> and optionally call "
            "lottery_rewards_engine::vip::import_existing_lotteries."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with VIP lotteries. Expected format: "
            '{"lotteries": [{"lottery_id": 1, "config": {"price": 50, "duration_secs": 3600, "bonus_tickets": 2}, '
            '"total_revenue": 1000, "bonus_tickets_issued": 20, "members": ["0x..."], "subscriptions": '
            '[{"player": "0x...", "expiry_ts": 1000, "bonus_tickets": 1}]}]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/vip_lotteries_import.bcs",
        help="Where to write the encoded vector<LegacyVipLottery> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_rewards_engine::vip::import_existing_lotteries",
        help="Entry function to call (defaults to the batch importer).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="If set, run supra move with the produced payload instead of only writing the file.",
    )
    parser.add_argument(
        "--docker-service",
        default="supra_cli",
        help="Docker Compose service that hosts the supra CLI (defaults to supra_cli).",
    )
    return parser.parse_args()


def load_lotteries(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "lotteries" not in payload:
        raise ValueError("Snapshot must be an object with a 'lotteries' array")
    lotteries = payload["lotteries"]
    if not isinstance(lotteries, list) or not lotteries:
        raise ValueError("The 'lotteries' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, lottery in enumerate(lotteries):
        if not isinstance(lottery, dict):
            raise ValueError(f"lotteries[{idx}] must be an object")
        normalized.append(lottery)
    return normalized


def encode_vector_length(length: int) -> bytearray:
    if length < 0:
        raise ValueError("Length must be non-negative")
    buffer = bytearray()
    remaining = length
    while True:
        byte = remaining & 0x7F
        remaining >>= 7
        if remaining == 0:
            buffer.append(byte)
            break
        buffer.append(byte | 0x80)
    return buffer


def parse_address(value: Any, field: str) -> bytes:
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a string address")
    normalized = value.lower()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    if len(normalized) == 0:
        raise ValueError(f"Field '{field}' must contain a non-empty hex value")
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    data = bytes.fromhex(normalized)
    if len(data) > 32:
        raise ValueError(f"Field '{field}' exceeds 32 bytes")
    return b"\x00" * (32 - len(data)) + data


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_config(config: Any, index: int) -> bytearray:
    if not isinstance(config, dict):
        raise ValueError(f"lotteries[{index}].config must be an object")
    buffer = bytearray()
    buffer.extend(encode_u64(config.get("price"), f"lotteries[{index}].config.price"))
    buffer.extend(encode_u64(config.get("duration_secs"), f"lotteries[{index}].config.duration_secs"))
    buffer.extend(encode_u64(config.get("bonus_tickets"), f"lotteries[{index}].config.bonus_tickets"))
    return buffer


def encode_members(members: Any, index: int) -> bytearray:
    if not isinstance(members, list):
        raise ValueError(f"lotteries[{index}].members must be an array")
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(members)))
    for member_idx, member in enumerate(members):
        buffer.extend(encode_address(member, f"lotteries[{index}].members[{member_idx}]"))
    return buffer


def encode_subscription(subscription: Any, lottery_idx: int, subscription_idx: int) -> bytearray:
    if not isinstance(subscription, dict):
        raise ValueError(
            f"lotteries[{lottery_idx}].subscriptions[{subscription_idx}] must be an object"
        )
    buffer = bytearray()
    buffer.extend(
        encode_address(
            subscription.get("player"),
            f"lotteries[{lottery_idx}].subscriptions[{subscription_idx}].player",
        )
    )
    buffer.extend(
        encode_u64(
            subscription.get("expiry_ts"),
            f"lotteries[{lottery_idx}].subscriptions[{subscription_idx}].expiry_ts",
        )
    )
    buffer.extend(
        encode_u64(
            subscription.get("bonus_tickets"),
            f"lotteries[{lottery_idx}].subscriptions[{subscription_idx}].bonus_tickets",
        )
    )
    return buffer


def encode_subscriptions(subscriptions: Any, lottery_idx: int) -> bytearray:
    if not isinstance(subscriptions, list):
        raise ValueError(f"lotteries[{lottery_idx}].subscriptions must be an array")
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(subscriptions)))
    for sub_idx, subscription in enumerate(subscriptions):
        buffer.extend(encode_subscription(subscription, lottery_idx, sub_idx))
    return buffer


def encode_lottery(lottery: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(lottery.get("lottery_id"), f"lotteries[{index}].lottery_id"))
    buffer.extend(encode_config(lottery.get("config"), index))
    buffer.extend(encode_u64(lottery.get("total_revenue"), f"lotteries[{index}].total_revenue"))
    buffer.extend(
        encode_u64(
            lottery.get("bonus_tickets_issued"), f"lotteries[{index}].bonus_tickets_issued"
        )
    )
    buffer.extend(encode_members(lottery.get("members"), index))
    buffer.extend(encode_subscriptions(lottery.get("subscriptions"), index))
    return buffer


def encode_lotteries(lotteries: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(lotteries)))
    for idx, lottery in enumerate(lotteries):
        buffer.extend(encode_lottery(lottery, idx))
    return buffer


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_import(config: str, function: str, docker_service: str, payload_path: Path) -> None:
    cli_command = (
        f"supra move run --config {shlex.quote(config)} --function {shlex.quote(function)} "
        f"--args-bytes-file {shlex.quote(str(payload_path))}"
    )
    command = [
        "docker",
        "compose",
        "run",
        "--rm",
        "--entrypoint",
        "bash",
        docker_service,
        "-lc",
        cli_command,
    ]
    subprocess.check_call(command)


def main() -> int:
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    lotteries = load_lotteries(snapshot_path)
    payload = encode_lotteries(lotteries)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(lotteries)} VIP lottery snapshot(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit the transaction or run manually:\n"
            f"supra move run --config {args.config} --function {args.function} --args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
