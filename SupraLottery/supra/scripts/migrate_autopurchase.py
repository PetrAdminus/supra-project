#!/usr/bin/env python3
"""Encode LegacyAutopurchasePlan payloads and optionally submit the import entry."""

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
            "Validate a JSON autopurchase snapshot, encode it as "
            "vector<LegacyAutopurchasePlan> and optionally call "
            "lottery_rewards_engine::autopurchase::import_existing_plans."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with autopurchase plans. Expected format: "
            '{"plans": [{"lottery_id": 1, "player": "0x...", "balance": 100, '
            '"tickets_per_draw": 2, "active": true}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/autopurchase_plans_import.bcs",
        help="Where to write the encoded vector<LegacyAutopurchasePlan> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_rewards_engine::autopurchase::import_existing_plans",
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


def load_plans(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "plans" not in payload:
        raise ValueError("Snapshot must be an object with a 'plans' array")
    plans = payload["plans"]
    if not isinstance(plans, list) or not plans:
        raise ValueError("The 'plans' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, plan in enumerate(plans):
        if not isinstance(plan, dict):
            raise ValueError(f"plans[{idx}] must be an object")
        normalized.append(plan)
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


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray((1 if value else 0,))


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_plan(plan: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(plan.get("lottery_id"), f"plans[{index}].lottery_id"))
    buffer.extend(encode_address(plan.get("player"), f"plans[{index}].player"))
    buffer.extend(encode_u64(plan.get("balance"), f"plans[{index}].balance"))
    buffer.extend(encode_u64(plan.get("tickets_per_draw"), f"plans[{index}].tickets_per_draw"))
    buffer.extend(encode_bool(plan.get("active"), f"plans[{index}].active"))
    return buffer


def encode_plans(plans: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(plans)))
    for idx, plan in enumerate(plans):
        buffer.extend(encode_plan(plan, idx))
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
    plans = load_plans(snapshot_path)
    payload = encode_plans(plans)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(plans)} autopurchase plan(s) to {output_path} (size={len(payload)} bytes)",
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
