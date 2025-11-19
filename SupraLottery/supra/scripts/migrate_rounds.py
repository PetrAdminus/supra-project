#!/usr/bin/env python3
"""Encode LegacyRoundRecord and queue payloads for lottery_data::rounds imports."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON snapshot for lottery_data::rounds, encode the BCS payloads "
            "for vector<LegacyRoundRecord>, vector<PendingHistoryRecord> and/or "
            "vector<PendingPurchaseRecord>, and optionally call the corresponding entry functions."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with rounds data. Expected top-level fields: "
            "'rounds', 'pending_history', 'pending_purchases'. Each field is optional but "
            "must be an array when provided."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--rounds-output-bcs",
        default="tmp/round_records_import.bcs",
        help="File to write vector<LegacyRoundRecord> payload (if records exist).",
    )
    parser.add_argument(
        "--history-output-bcs",
        default="tmp/round_history_queue_import.bcs",
        help="File to write vector<PendingHistoryRecord> payload (if records exist).",
    )
    parser.add_argument(
        "--purchase-output-bcs",
        default="tmp/round_purchase_queue_import.bcs",
        help="File to write vector<PendingPurchaseRecord> payload (if records exist).",
    )
    parser.add_argument(
        "--rounds-function",
        default="lottery_data::rounds::import_existing_rounds",
        help="Entry function for round records (defaults to batch importer).",
    )
    parser.add_argument(
        "--history-function",
        default="lottery_data::rounds::import_pending_history_records",
        help="Entry function for pending history records.",
    )
    parser.add_argument(
        "--purchase-function",
        default="lottery_data::rounds::import_pending_purchase_records",
        help="Entry function for pending purchase records.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="If set, run supra move with each produced payload instead of dry-run only.",
    )
    parser.add_argument(
        "--docker-service",
        default="supra_cli",
        help="Docker Compose service hosting the supra CLI (defaults to supra_cli).",
    )
    return parser.parse_args()


def load_snapshot(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("Snapshot must be a JSON object")
    return payload


def ensure_array(payload: Dict[str, Any], field: str) -> List[Dict[str, Any]]:
    value = payload.get(field, [])
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"Field '{field}' must be an array when provided")
    normalized: List[Dict[str, Any]] = []
    for idx, record in enumerate(value):
        if not isinstance(record, dict):
            raise ValueError(f"{field}[{idx}] must be an object")
        normalized.append(record)
    return normalized


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
        raise ValueError(f"Field '{field}' must contain a non-empty hex string")
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    data = bytes.fromhex(normalized)
    if len(data) > 32:
        raise ValueError(f"Field '{field}' exceeds 32 bytes")
    return b"\x00" * (32 - len(data)) + data


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_addresses(values: Sequence[Any], field: str) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(values)))
    for idx, entry in enumerate(values):
        buffer.extend(encode_address(entry, f"{field}[{idx}]"))
    return buffer


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


def encode_option_u64(value: Any, field: str) -> bytearray:
    buffer = bytearray()
    if value is None:
        buffer.append(0)
        return buffer
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer or null")
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
            try:
                data = value.encode("ascii")
            except UnicodeEncodeError as exc:  # pragma: no cover
                raise ValueError(
                    f"Field '{field}' contains non-ASCII characters; use 0x-prefixed hex"
                ) from exc
    elif isinstance(value, list):
        data = bytes(value)
    else:
        raise ValueError(
            f"Field '{field}' must be a string (ASCII or 0x-prefixed hex) or array of integers"
        )
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(data)))
    buffer.extend(data)
    return buffer


def encode_round_record(record: Dict[str, Any], index: int) -> bytearray:
    tickets = record.get("tickets", [])
    if not isinstance(tickets, list):
        raise ValueError(f"records[{index}].tickets must be an array of addresses")
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"records[{index}].lottery_id"))
    buffer.extend(encode_addresses(tickets, f"records[{index}].tickets"))
    buffer.extend(encode_bool(record.get("draw_scheduled"), f"records[{index}].draw_scheduled"))
    buffer.extend(encode_u64(record.get("next_ticket_id"), f"records[{index}].next_ticket_id"))
    buffer.extend(encode_option_u64(record.get("pending_request"), f"records[{index}].pending_request"))
    return buffer


def encode_round_records(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_round_record(record, idx))
    return buffer


def encode_history_record(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"pending_history[{index}].lottery_id"))
    buffer.extend(encode_u64(record.get("request_id"), f"pending_history[{index}].request_id"))
    buffer.extend(encode_address(record.get("winner"), f"pending_history[{index}].winner"))
    buffer.extend(encode_u64(record.get("ticket_index"), f"pending_history[{index}].ticket_index"))
    buffer.extend(encode_u64(record.get("prize_amount"), f"pending_history[{index}].prize_amount"))
    buffer.extend(encode_bytes(record.get("random_bytes", ""), f"pending_history[{index}].random_bytes"))
    buffer.extend(encode_bytes(record.get("payload", ""), f"pending_history[{index}].payload"))
    return buffer


def encode_history_records(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_history_record(record, idx))
    return buffer


def encode_purchase_record(record: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"pending_purchases[{index}].lottery_id"))
    buffer.extend(encode_address(record.get("buyer"), f"pending_purchases[{index}].buyer"))
    buffer.extend(encode_u64(record.get("ticket_count"), f"pending_purchases[{index}].ticket_count"))
    buffer.extend(encode_u64(record.get("paid_amount"), f"pending_purchases[{index}].paid_amount"))
    return buffer


def encode_purchase_records(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_purchase_record(record, idx))
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


def maybe_process_dataset(
    records: Sequence[Dict[str, Any]],
    label: str,
    output_path: Path,
    function_name: str,
    encoder: Callable[[Sequence[Dict[str, Any]]], bytearray],
    args: argparse.Namespace,
) -> Optional[int]:
    if not records:
        return None
    payload = encoder(records)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(records)} {label} record(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )
    if args.execute:
        print(f"Executing supra move run for {label} payload…", flush=True)
        run_import(args.config, function_name, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit or run manually via:\n"
            f"supra move run --config {args.config} --function {function_name} --args-bytes-file {output_path}",
            flush=True,
        )
    return len(records)


def main() -> int:
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    payload = load_snapshot(snapshot_path)
    rounds_array = ensure_array(payload, "rounds")
    history_array = ensure_array(payload, "pending_history")
    purchase_array = ensure_array(payload, "pending_purchases")

    if not (rounds_array or history_array or purchase_array):
        raise ValueError("Snapshot must include at least one non-empty array")

    rounds_count = maybe_process_dataset(
        rounds_array,
        "round",
        Path(args.rounds_output_bcs),
        args.rounds_function,
        encode_round_records,
        args,
    )
    history_count = maybe_process_dataset(
        history_array,
        "pending history",
        Path(args.history_output_bcs),
        args.history_function,
        encode_history_records,
        args,
    )
    purchase_count = maybe_process_dataset(
        purchase_array,
        "pending purchase",
        Path(args.purchase_output_bcs),
        args.purchase_function,
        encode_purchase_records,
        args,
    )

    if rounds_count is None:
        print("No round records supplied", flush=True)
    if history_count is None:
        print("No pending history records supplied", flush=True)
    if purchase_count is None:
        print("No pending purchase records supplied", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
