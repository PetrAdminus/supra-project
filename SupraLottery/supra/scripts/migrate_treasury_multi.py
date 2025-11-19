"""Encode LegacyMultiTreasuryState/Lottery payloads and optionally execute the import."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON snapshot for lottery_data::treasury_multi, encode the BCS "
            "payloads for LegacyMultiTreasuryState and vector<LegacyMultiTreasuryLottery>, "
            "and optionally invoke the corresponding entry functions."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with 'state' and/or 'lotteries' sections. "
            "'state' must contain jackpot_recipient, operations_recipient and jackpot_balance. "
            "'lotteries' must be an array of objects with lottery_id, *_bps and *_balance fields."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--state-output-bcs",
        default="tmp/multi_treasury_state_import.bcs",
        help="Where to write the LegacyMultiTreasuryState payload (if state is provided).",
    )
    parser.add_argument(
        "--lotteries-output-bcs",
        default="tmp/multi_treasury_lotteries_import.bcs",
        help="Where to write the vector<LegacyMultiTreasuryLottery> payload (if lotteries exist).",
    )
    parser.add_argument(
        "--state-function",
        default="lottery_data::treasury_multi::import_existing_state",
        help="Entry function used for the state payload (defaults to import_existing_state).",
    )
    parser.add_argument(
        "--lotteries-function",
        default="lottery_data::treasury_multi::import_existing_lotteries",
        help="Entry function used for the lotteries payload (defaults to the batch importer).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help=(
            "If set, execute supra move run for every produced payload instead of dry-run only."
        ),
    )
    parser.add_argument(
        "--docker-service",
        default="supra_cli",
        help="Docker Compose service exposing the supra CLI (defaults to supra_cli).",
    )
    return parser.parse_args()


def load_snapshot(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("Snapshot must be a JSON object")
    state = payload.get("state")
    if state is not None and not isinstance(state, dict):
        raise ValueError("'state' section must be an object when provided")
    lotteries_raw = payload.get("lotteries", [])
    lotteries: List[Dict[str, Any]] = []
    if lotteries_raw is None:
        lotteries_raw = []
    if not isinstance(lotteries_raw, list):
        raise ValueError("'lotteries' must be an array when provided")
    for index, record in enumerate(lotteries_raw):
        if not isinstance(record, dict):
            raise ValueError(f"lotteries[{index}] must be an object")
        lotteries.append(record)
    return {"state": state, "lotteries": lotteries}


def encode_vector_length(length: int) -> bytearray:
    if length < 0:
        raise ValueError("Vector length must be non-negative")
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
    if not normalized:
        raise ValueError(f"Field '{field}' must not be empty")
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


def encode_state(state: Dict[str, Any]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(state.get("jackpot_recipient"), "state.jackpot_recipient"))
    buffer.extend(
        encode_address(state.get("operations_recipient"), "state.operations_recipient")
    )
    buffer.extend(encode_u64(state.get("jackpot_balance"), "state.jackpot_balance"))
    return buffer


def encode_lottery(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    prefix = f"lotteries[{index}]"
    buffer.extend(encode_u64(record.get("lottery_id"), f"{prefix}.lottery_id"))
    buffer.extend(encode_u64(record.get("prize_bps"), f"{prefix}.prize_bps"))
    buffer.extend(encode_u64(record.get("jackpot_bps"), f"{prefix}.jackpot_bps"))
    buffer.extend(encode_u64(record.get("operations_bps"), f"{prefix}.operations_bps"))
    buffer.extend(encode_u64(record.get("prize_balance"), f"{prefix}.prize_balance"))
    buffer.extend(encode_u64(record.get("operations_balance"), f"{prefix}.operations_balance"))
    return buffer


def encode_lotteries(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for index, record in enumerate(records):
        buffer.extend(encode_lottery(record, index))
    return buffer


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_import(config: str, function_name: str, docker_service: str, payload_path: Path) -> None:
    cli_command = (
        f"supra move run --config {shlex.quote(config)} --function {shlex.quote(function_name)} "
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


def maybe_process_state(
    state: Optional[Dict[str, Any]],
    output_path: Path,
    function_name: str,
    args: argparse.Namespace,
) -> bool:
    if state is None:
        print("No 'state' section supplied — skipping state payload", flush=True)
        return False
    payload = encode_state(state)
    write_payload(output_path, payload)
    print(
        f"Encoded LegacyMultiTreasuryState payload (size={len(payload)} bytes) to {output_path}",
        flush=True,
    )
    if args.execute:
        print("Executing supra move run for state payload…", flush=True)
        run_import(args.config, function_name, args.docker_service, output_path)
    else:
        print(
            "Dry run complete for state payload. Use --execute to submit the transaction.",
            flush=True,
        )
    return True


def maybe_process_lotteries(
    lotteries: Sequence[Dict[str, Any]],
    output_path: Path,
    function_name: str,
    args: argparse.Namespace,
) -> bool:
    if not lotteries:
        print("No lotteries supplied — skipping lottery payload", flush=True)
        return False
    payload = encode_lotteries(lotteries)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(lotteries)} LegacyMultiTreasuryLottery record(s) "
        f"(size={len(payload)} bytes) to {output_path}",
        flush=True,
    )
    if args.execute:
        print("Executing supra move run for lotteries payload…", flush=True)
        run_import(args.config, function_name, args.docker_service, output_path)
    else:
        print(
            "Dry run complete for lotteries payload. Use --execute to submit the transaction.",
            flush=True,
        )
    return True


def main() -> int:
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    snapshot = load_snapshot(snapshot_path)

    has_state = maybe_process_state(
        snapshot["state"],
        Path(args.state_output_bcs),
        args.state_function,
        args,
    )
    has_lotteries = maybe_process_lotteries(
        snapshot["lotteries"],
        Path(args.lotteries_output_bcs),
        args.lotteries_function,
        args,
    )

    if not (has_state or has_lotteries):
        raise ValueError("Snapshot must include 'state' and/or at least one lottery record")

    return 0


if __name__ == "__main__":
    sys.exit(main())
