"""Encode LegacyVrfDepositLedger payloads and optionally call import_existing_ledger."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
from pathlib import Path
from typing import Any, Dict


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON VRF deposit snapshot, encode it as LegacyVrfDepositLedger "
            "and optionally run lottery_data::vrf_deposit::import_existing_ledger."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with deposit config and status. Expected keys: "
            "admin, config.{min_balance_multiplier_bps,effective_floor}, "
            "status.{total_balance,minimum_balance,effective_balance,required_minimum," \
            "last_update_ts,requests_paused,paused_since_ts}, snapshot_timestamp"
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/vrf_deposit_ledger.bcs",
        help="Where to write the encoded LegacyVrfDepositLedger payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::vrf_deposit::import_existing_ledger",
        help="Entry function to call (defaults to the ledger importer).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="If set, execute supra move with the produced payload instead of only writing the file.",
    )
    parser.add_argument(
        "--docker-service",
        default="supra_cli",
        help="Docker Compose service that exposes the supra CLI (defaults to supra_cli).",
    )
    return parser.parse_args()


def load_snapshot(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("Snapshot must be a JSON object")
    required = ["admin", "config", "status", "snapshot_timestamp"]
    for field in required:
        if field not in payload:
            raise ValueError(f"Snapshot must include '{field}'")
    config = payload["config"]
    status = payload["status"]
    if not isinstance(config, dict):
        raise ValueError("config must be an object with numeric fields")
    if not isinstance(status, dict):
        raise ValueError("status must be an object with numeric/bool fields")
    return {
        "admin": payload["admin"],
        "config": config,
        "status": status,
        "snapshot_timestamp": payload["snapshot_timestamp"],
    }


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray(b"\x01" if value else b"\x00")


def parse_address(value: Any, field: str) -> bytes:
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a string address")
    normalized = value.lower()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    if not normalized:
        raise ValueError(f"Field '{field}' must contain a non-empty hex value")
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    data = bytes.fromhex(normalized)
    if len(data) > 32:
        raise ValueError(f"Field '{field}' exceeds 32 bytes")
    return b"\x00" * (32 - len(data)) + data


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_config(config: Dict[str, Any]) -> bytearray:
    required_fields = ["min_balance_multiplier_bps", "effective_floor"]
    buffer = bytearray()
    for field in required_fields:
        buffer.extend(encode_u64(config.get(field), f"config.{field}"))
    return buffer


def encode_status(status: Dict[str, Any]) -> bytearray:
    required_fields = [
        "total_balance",
        "minimum_balance",
        "effective_balance",
        "required_minimum",
        "last_update_ts",
        "requests_paused",
        "paused_since_ts",
    ]
    buffer = bytearray()
    for field in required_fields:
        if field == "requests_paused":
            buffer.extend(encode_bool(status.get(field), f"status.{field}"))
        else:
            buffer.extend(encode_u64(status.get(field), f"status.{field}"))
    return buffer


def encode_payload(snapshot: Dict[str, Any]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(snapshot["admin"], "admin"))
    buffer.extend(encode_config(snapshot["config"]))
    buffer.extend(encode_status(snapshot["status"]))
    buffer.extend(encode_u64(snapshot["snapshot_timestamp"], "snapshot_timestamp"))
    return buffer


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_import(config_path: str, function: str, docker_service: str, payload_path: Path) -> None:
    cli_command = (
        f"supra move run --config {shlex.quote(config_path)} --function {shlex.quote(function)} "
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
    snapshot = load_snapshot(snapshot_path)
    payload = encode_payload(snapshot)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        (
            f"Encoded LegacyVrfDepositLedger payload (size={len(payload)} bytes) "
            f"to {output_path}"
        ),
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Execution skipped (use --execute to run lottery_data::vrf_deposit::import_existing_ledger)",
            flush=True,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
