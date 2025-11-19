#!/usr/bin/env python3
"""Encode LegacyJackpotRuntime payloads and optionally run the import entry."""

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
            "Validate a JSON jackpot snapshot, encode it as vector<LegacyJackpotRuntime> "
            "and optionally run lottery_rewards_engine::jackpot::import_existing_jackpots."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with jackpot data. Expected format: "
            '{"jackpots": [{"lottery_id": 1, "tickets": ["0x..."], "draw_scheduled": true, '
            '"pending_request_id": null|123, "pending_payload": null|"0x…"|"ASCII"}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/jackpot_runtime_import.bcs",
        help="Where to write the encoded vector<LegacyJackpotRuntime> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_rewards_engine::jackpot::import_existing_jackpots",
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


def load_jackpots(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "jackpots" not in payload:
        raise ValueError("Snapshot must be an object with a 'jackpots' array")
    jackpots = payload["jackpots"]
    if not isinstance(jackpots, list) or not jackpots:
        raise ValueError("The 'jackpots' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, record in enumerate(jackpots):
        if not isinstance(record, dict):
            raise ValueError(f"jackpots[{idx}] must be an object")
        normalized.append(record)
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


def encode_address_list(addresses: Sequence[Any], field: str) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(addresses)))
    for idx, addr in enumerate(addresses):
        buffer.extend(parse_address(addr, f"{field}[{idx}]"))
    return buffer


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray((1 if value else 0,))


def encode_option_u64(value: Any, field: str) -> bytearray:
    buffer = bytearray()
    if value is None:
        buffer.append(0)
        return buffer
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be null or an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    buffer.append(1)
    buffer.extend(value.to_bytes(8, byteorder="little", signed=False))
    return buffer


def encode_bytes(value: Any, field: str) -> bytearray:
    if isinstance(value, str):
        if value.startswith("0x") or value.startswith("0X"):
            hex_value = value[2:]
            if len(hex_value) % 2 == 1:
                hex_value = "0" + hex_value
            data = bytes.fromhex(hex_value)
        else:
            if not value.isascii():
                raise ValueError(
                    f"Field '{field}' must be ASCII or 0x-prefixed hex when provided as a string"
                )
            data = value.encode("ascii")
    elif isinstance(value, list):
        data = bytes(value)
    elif value is None:
        data = b""
    else:
        raise ValueError(
            f"Field '{field}' must be ASCII, 0x-prefixed hex, a list of integers or null"
        )
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(data)))
    buffer.extend(data)
    return buffer


def encode_option_bytes(value: Any, field: str) -> bytearray:
    buffer = bytearray()
    if value is None:
        buffer.append(0)
        return buffer
    buffer.append(1)
    buffer.extend(encode_bytes(value, field))
    return buffer


def encode_tickets(record: Dict[str, Any], index: int) -> bytearray:
    tickets = record.get("tickets", [])
    if tickets is None:
        tickets = []
    if not isinstance(tickets, list):
        raise ValueError(f"jackpots[{index}].tickets must be an array")
    return encode_address_list(tickets, f"jackpots[{index}].tickets")


def encode_legacy_record(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"jackpots[{index}].lottery_id"))
    buffer.extend(encode_tickets(record, index))
    buffer.extend(encode_bool(record.get("draw_scheduled"), f"jackpots[{index}].draw_scheduled"))
    buffer.extend(encode_option_u64(record.get("pending_request_id"), f"jackpots[{index}].pending_request_id"))
    buffer.extend(encode_option_bytes(record.get("pending_payload"), f"jackpots[{index}].pending_payload"))
    return buffer


def encode_records(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_legacy_record(record, idx))
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
    jackpots = load_jackpots(snapshot_path)
    payload = encode_records(jackpots)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(jackpots)} jackpot runtime record(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit the transaction or run manually via:\n"
            f"supra move run --config {args.config} --function {args.function} "
            f"--args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
