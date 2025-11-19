#!/usr/bin/env python3
"""Encode LegacyHistoryRecord payloads and optionally submit the import entry."""

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
            "Validate a JSON history snapshot, encode it as vector<LegacyHistoryRecord> "
            "and optionally call lottery_utils::history::import_existing_history_batch."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with history records. Expected format: "
            '{"records": [{"lottery_id": 1, "request_id": 10, "winner": "0x...", '
            '"ticket_index": 5, "prize_amount": 100, "random_bytes": "0x01", '
            '"payload": "0x02", "timestamp_seconds": 1700000000}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/history_import.bcs",
        help="Where to write the encoded vector<LegacyHistoryRecord> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_utils::history::import_existing_history_batch",
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


def load_records(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "records" not in payload:
        raise ValueError("Snapshot must be an object with a 'records' array")
    records = payload["records"]
    if not isinstance(records, list) or not records:
        raise ValueError("The 'records' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"records[{idx}] must be an object")
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


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_bytes(value: Any, field: str) -> bytearray:
    if isinstance(value, str):
        normalized = value.lower()
        if normalized.startswith("0x"):
            normalized = normalized[2:]
        if len(normalized) % 2 == 1:
            normalized = "0" + normalized
        try:
            data = bytes.fromhex(normalized)
        except ValueError as exc:  # noqa: PERF203
            raise ValueError(f"Field '{field}' must be hex-encoded: {exc}") from exc
        return bytearray(encode_vector_length(len(data)) + data)

    if isinstance(value, list):
        byte_values: List[int] = []
        for idx, item in enumerate(value):
            if not isinstance(item, int) or item < 0 or item > 255:
                raise ValueError(f"{field}[{idx}] must be an integer in range 0..255")
            byte_values.append(item)
        data = bytes(byte_values)
        return bytearray(encode_vector_length(len(data)) + data)

    raise ValueError(f"Field '{field}' must be a hex string or an array of bytes")


def encode_record(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"records[{index}].lottery_id"))
    buffer.extend(encode_u64(record.get("request_id"), f"records[{index}].request_id"))
    buffer.extend(encode_address(record.get("winner"), f"records[{index}].winner"))
    buffer.extend(encode_u64(record.get("ticket_index"), f"records[{index}].ticket_index"))
    buffer.extend(encode_u64(record.get("prize_amount"), f"records[{index}].prize_amount"))
    buffer.extend(encode_bytes(record.get("random_bytes"), f"records[{index}].random_bytes"))
    buffer.extend(encode_bytes(record.get("payload"), f"records[{index}].payload"))
    buffer.extend(encode_u64(record.get("timestamp_seconds"), f"records[{index}].timestamp_seconds"))
    return buffer


def encode_records(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_record(record, idx))
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
    records = load_records(snapshot_path)
    payload = encode_records(records)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(records)} history record(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit the transaction or run manually:\n"
            f"supra move run --config {args.config} --function {args.function} "
            f"--args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
