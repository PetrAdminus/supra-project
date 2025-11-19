#!/usr/bin/env python3
"""Encode LegacyAutomationBot snapshots and optionally run the import entry."""

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON AutomationRegistry snapshot, encode it as vector<LegacyAutomationBot> "
            "and optionally execute lottery_data::automation::import_existing_bots."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with AutomationRegistry data. Expected format: "
            '{"bots": [{"operator": "0x...", "allowed_actions": [1], "timelock_secs": 0, '
            '"max_failures": 0, "failure_count": 0, "success_streak": 0, "reputation_score": 0, '
            '"pending_action_hash": "0x", "pending_execute_after": 0, "expires_at": 0, '
            '"cron_spec": "* * * * *", "last_action_ts": 0, "last_action_hash": "0x"}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/automation_registry_import.bcs",
        help="Where to write the encoded vector<LegacyAutomationBot> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::automation::import_existing_bots",
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


def load_bots(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "bots" not in payload:
        raise ValueError("Snapshot must be an object with a 'bots' array")
    bots = payload["bots"]
    if not isinstance(bots, list) or not bots:
        raise ValueError("The 'bots' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, bot in enumerate(bots):
        if not isinstance(bot, dict):
            raise ValueError(f"bots[{idx}] must be an object")
        normalized.append(bot)
    return normalized


def encode_vector_length(length: int) -> bytearray:
    if length < 0:
        raise ValueError("Vector length must be non-negative")
    remaining = length
    buffer = bytearray()
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


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_vector_u64(values: Any, field: str) -> bytearray:
    if not isinstance(values, list):
        raise ValueError(f"Field '{field}' must be an array")
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(values)))
    for idx, value in enumerate(values):
        buffer.extend(encode_u64(value, f"{field}[{idx}]"))
    return buffer


def parse_hex_bytes(value: Any, field: str) -> bytes:
    if value is None:
        return b""
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a string")
    normalized = value.lower()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    if len(normalized) == 0:
        return b""
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    return bytes.fromhex(normalized)


def ensure_ascii_bytes(value: Any, field: str) -> bytes:
    if value is None:
        return b""
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a string")
    if not value.isascii():
        raise ValueError(f"Field '{field}' must contain only ASCII characters")
    return value.encode("ascii")


def encode_vector_bytes(data: bytes) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(data)))
    buffer.extend(data)
    return buffer


def encode_bot(bot: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    prefix = f"bots[{index}]"
    buffer.extend(encode_address(bot.get("operator"), f"{prefix}.operator"))
    buffer.extend(encode_vector_u64(bot.get("allowed_actions"), f"{prefix}.allowed_actions"))
    buffer.extend(encode_u64(bot.get("timelock_secs"), f"{prefix}.timelock_secs"))
    buffer.extend(encode_u64(bot.get("max_failures"), f"{prefix}.max_failures"))
    buffer.extend(encode_u64(bot.get("failure_count"), f"{prefix}.failure_count"))
    buffer.extend(encode_u64(bot.get("success_streak"), f"{prefix}.success_streak"))
    buffer.extend(encode_u64(bot.get("reputation_score"), f"{prefix}.reputation_score"))
    buffer.extend(
        encode_vector_bytes(parse_hex_bytes(bot.get("pending_action_hash"), f"{prefix}.pending_action_hash"))
    )
    buffer.extend(encode_u64(bot.get("pending_execute_after"), f"{prefix}.pending_execute_after"))
    buffer.extend(encode_u64(bot.get("expires_at"), f"{prefix}.expires_at"))
    buffer.extend(encode_vector_bytes(ensure_ascii_bytes(bot.get("cron_spec"), f"{prefix}.cron_spec")))
    buffer.extend(encode_u64(bot.get("last_action_ts"), f"{prefix}.last_action_ts"))
    buffer.extend(
        encode_vector_bytes(parse_hex_bytes(bot.get("last_action_hash"), f"{prefix}.last_action_hash"))
    )
    return buffer


def encode_bots(bots: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(bots)))
    for idx, bot in enumerate(bots):
        buffer.extend(encode_bot(bot, idx))
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
    bots = load_bots(snapshot_path)
    payload = encode_bots(bots)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(bots)} automation bot(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to run the import or manually call:\n"
            f"supra move run --config {args.config} --function {args.function} "
            f"--args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
