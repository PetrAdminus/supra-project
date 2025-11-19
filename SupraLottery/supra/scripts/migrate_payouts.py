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
            "Validate a JSON payout snapshot, encode it as "
            "vector<LegacyPayoutRecord> and optionally call "
            "lottery_data::payouts::import_existing_payouts."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with payout records. Expected format: "
            '{"records": [{"payout_id": 1, "lottery_id": 7, "round_number": 3, '
            '"winner": "0x...", "ticket_index": 4, "amount": 5000, "status": 1, '
            '"randomness_hash": "ab..", "payload_hash": "cd..", "refund_recipient": "0x...", '
            '"refund_amount": 0}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/payouts_import.bcs",
        help="Where to write the encoded vector<LegacyPayoutRecord> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::payouts::import_existing_payouts",
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


def parse_hex_bytes(value: Any, field: str) -> bytearray:
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a hex string")
    normalized = value.lower().strip()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    try:
        data = bytes.fromhex(normalized)
    except ValueError as exc:
        raise ValueError(f"Field '{field}' must be valid hex: {exc}") from exc
    return bytearray(data)


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


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_bytes(value: Any, field: str) -> bytearray:
    data = parse_hex_bytes(value, field)
    return encode_vector_length(len(data)) + data


def encode_record(record: Dict[str, Any]) -> bytearray:
    payout_id = encode_u64(record.get("payout_id"), "payout_id")
    lottery_id = encode_u64(record.get("lottery_id"), "lottery_id")
    round_number = encode_u64(record.get("round_number"), "round_number")
    winner = encode_address(record.get("winner"), "winner")
    ticket_index = encode_u64(record.get("ticket_index"), "ticket_index")
    amount = encode_u64(record.get("amount"), "amount")
    status = encode_u8(record.get("status"), "status")
    randomness_hash = encode_bytes(record.get("randomness_hash"), "randomness_hash")
    payload_hash = encode_bytes(record.get("payload_hash"), "payload_hash")
    refund_recipient = encode_address(record.get("refund_recipient"), "refund_recipient")
    refund_amount = encode_u64(record.get("refund_amount"), "refund_amount")

    return (
        payout_id
        + lottery_id
        + round_number
        + winner
        + ticket_index
        + amount
        + status
        + randomness_hash
        + payload_hash
        + refund_recipient
        + refund_amount
    )


def encode_records(records: List[Dict[str, Any]]) -> bytearray:
    payload = bytearray()
    payload += encode_vector_length(len(records))
    for idx, record in enumerate(records):
        try:
            payload += encode_record(record)
        except Exception as exc:  # noqa: BLE001
            raise ValueError(f"Failed to encode records[{idx}]: {exc}") from exc
    return payload


def write_payload(path: Path, payload: bytearray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    print(f"Wrote {len(payload)} bytes to {path}")


def run_entry_function(
    docker_service: str,
    config_path: Path,
    function: str,
    bcs_path: Path,
) -> None:
    cmd = [
        "docker",
        "compose",
        "exec",
        docker_service,
        "supra",
        "move",
        "run",
        "--profile",
        config_path.as_posix(),
        "--function",
        function,
        "--args",
        f"@{bcs_path.as_posix()}",
    ]
    print("Running:", " ".join(shlex.quote(part) for part in cmd))
    subprocess.check_call(cmd)


def main() -> None:
    args = parse_args()
    records = load_records(Path(args.snapshot))
    payload = encode_records(records)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)

    if args.execute:
        run_entry_function(args.docker_service, Path(args.config), args.function, output_path)


if __name__ == "__main__":
    main()
