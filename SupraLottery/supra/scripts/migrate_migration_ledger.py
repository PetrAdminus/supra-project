#!/usr/bin/env python3
"""Encode MigrationSnapshot payloads and optionally import them on-chain."""

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON file with migration snapshots, encode each "
            "lottery_utils::migration::MigrationSnapshot as BCS and optionally "
            "call lottery_utils::migration::record_snapshot."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON with a 'snapshots' array. Each element must contain "
            "lottery_id, ticket_count, legacy_next_ticket_id, migrated_next_ticket_id, "
            "legacy_draw_scheduled, migrated_draw_scheduled, legacy_pending_request, "
            "jackpot_amount_migrated, prize_bps, jackpot_bps and operations_bps."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-dir",
        default="tmp/migration_snapshots",
        help="Directory for writing encoded MigrationSnapshot payloads.",
    )
    parser.add_argument(
        "--function",
        default="lottery_utils::migration::record_snapshot",
        help="Entry function to call when --execute is provided.",
    )
    parser.add_argument(
        "--docker-service",
        default="supra_cli",
        help="Docker Compose service that provides the supra CLI.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="If set, call supra move run for each encoded snapshot.",
    )
    return parser.parse_args()


def load_snapshots(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "snapshots" not in payload:
        raise ValueError("Snapshot file must be an object with a 'snapshots' array")
    snapshots = payload["snapshots"]
    if not isinstance(snapshots, list) or not snapshots:
        raise ValueError("'snapshots' must be a non-empty array")
    normalized: List[Dict[str, Any]] = []
    for idx, snapshot in enumerate(snapshots):
        if not isinstance(snapshot, dict):
            raise ValueError(f"snapshots[{idx}] must be an object")
        normalized.append(snapshot)
    return normalized


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray((1 if value else 0,))


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_snapshot(snapshot: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(snapshot.get("lottery_id"), f"snapshots[{index}].lottery_id"))
    buffer.extend(encode_u64(snapshot.get("ticket_count"), f"snapshots[{index}].ticket_count"))
    buffer.extend(
        encode_u64(snapshot.get("legacy_next_ticket_id"), f"snapshots[{index}].legacy_next_ticket_id")
    )
    buffer.extend(
        encode_u64(snapshot.get("migrated_next_ticket_id"), f"snapshots[{index}].migrated_next_ticket_id")
    )
    buffer.extend(
        encode_bool(snapshot.get("legacy_draw_scheduled"), f"snapshots[{index}].legacy_draw_scheduled")
    )
    buffer.extend(
        encode_bool(snapshot.get("migrated_draw_scheduled"), f"snapshots[{index}].migrated_draw_scheduled")
    )
    buffer.extend(
        encode_bool(snapshot.get("legacy_pending_request"), f"snapshots[{index}].legacy_pending_request")
    )
    buffer.extend(
        encode_u64(snapshot.get("jackpot_amount_migrated"), f"snapshots[{index}].jackpot_amount_migrated")
    )
    buffer.extend(encode_u64(snapshot.get("prize_bps"), f"snapshots[{index}].prize_bps"))
    buffer.extend(encode_u64(snapshot.get("jackpot_bps"), f"snapshots[{index}].jackpot_bps"))
    buffer.extend(encode_u64(snapshot.get("operations_bps"), f"snapshots[{index}].operations_bps"))
    return buffer


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


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
    snapshots = load_snapshots(Path(args.snapshot))
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    encoded_paths: List[Path] = []
    for index, snapshot in enumerate(snapshots):
        payload = encode_snapshot(snapshot, index)
        lottery_id = snapshot.get("lottery_id", index)
        output_path = output_dir / f"migration_snapshot_{lottery_id}_{index}.bcs"
        write_payload(output_path, payload)
        encoded_paths.append(output_path)
        print(
            f"Encoded lottery_id={lottery_id} snapshot to {output_path} (size={len(payload)} bytes)",
            flush=True,
        )

    if args.execute:
        for payload_path in encoded_paths:
            print(f"Executing supra move run for {payload_path}...", flush=True)
            run_import(args.config, args.function, args.docker_service, payload_path)
    else:
        example = encoded_paths[0] if encoded_paths else output_dir / "snapshot.bcs"
        print(
            "Dry run complete. Use --execute to submit snapshots or manually run:\n"
            f"supra move run --config {args.config} --function {args.function} "
            f"--args-bytes-file {example}",
            flush=True,
        )

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
