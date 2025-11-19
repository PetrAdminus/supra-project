"""BCS-энкодер LegacyCancellationRecord и обёртка supra move run для импортера отмен."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON CancellationLedger snapshot, encode it as vector<LegacyCancellationRecord> "
            "and optionally execute lottery_data::cancellations::import_existing_cancellations."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with cancellation data. Expected format: "
            "{\"records\": [{\"lottery_id\": 1, \"reason_code\": 1, \"canceled_ts\": 0, ...}, ...]}"
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/cancellation_records_import.bcs",
        help="Where to write the encoded vector<LegacyCancellationRecord> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::cancellations::import_existing_cancellations",
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


def load_records(path: Path) -> Sequence[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "records" not in payload:
        raise ValueError("Snapshot must be an object with a 'records' array")
    records = payload["records"]
    if not isinstance(records, list) or not records:
        raise ValueError("The 'records' array must be a non-empty list")
    normalized = []
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


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_u8(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFF:
        raise ValueError(f"Field '{field}' must fit into u8")
    return bytearray((value,))


def encode_record(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"records[{index}].lottery_id"))
    buffer.extend(encode_u8(record.get("reason_code"), f"records[{index}].reason_code"))
    buffer.extend(encode_u64(record.get("canceled_ts"), f"records[{index}].canceled_ts"))
    buffer.extend(encode_u8(record.get("previous_status"), f"records[{index}].previous_status"))
    buffer.extend(encode_u64(record.get("tickets_sold"), f"records[{index}].tickets_sold"))
    buffer.extend(encode_u64(record.get("proceeds_accum"), f"records[{index}].proceeds_accum"))
    buffer.extend(encode_u64(record.get("jackpot_locked"), f"records[{index}].jackpot_locked"))
    buffer.extend(
        encode_u64(
            record.get("pending_tickets_cleared"),
            f"records[{index}].pending_tickets_cleared",
        )
    )
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
        f"Encoded {len(records)} cancellation record(s) to {output_path} (size={len(payload)} bytes)",
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
