from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON factory snapshot, encode it as LegacyFactoryState "
            "and optionally call lottery_factory::registry::import_existing_registry."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON with factory data. Expected keys: "
            "'admin' (0x-address), 'next_lottery_id' (u64), 'lottery_ids' (array of u64) "
            "and 'lotteries' (array of entries with lottery_id, owner, lottery, ticket_price, jackpot_share_bps)."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/factory_state_import.bcs",
        help="Where to write the encoded LegacyFactoryState payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_factory::registry::import_existing_registry",
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


def load_snapshot(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("Snapshot must be a JSON object")
    for field in ("admin", "next_lottery_id", "lottery_ids", "lotteries"):
        if field not in payload:
            raise ValueError(f"Snapshot is missing required field '{field}'")
    return payload


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
        raise ValueError(f"Field '{field}' must be a string with 0x-prefixed hex")
    if not value.startswith("0x") and not value.startswith("0X"):
        raise ValueError(f"Field '{field}' must start with 0x")
    hex_part = value[2:]
    if len(hex_part) == 0:
        raise ValueError(f"Field '{field}' must not be empty")
    if len(hex_part) % 2 == 1:
        hex_part = "0" + hex_part
    data = bytes.fromhex(hex_part)
    if len(data) > 32:
        raise ValueError(f"Field '{field}' exceeds 32 bytes")
    return b"\x00" * (32 - len(data)) + data


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_addresses(values: Sequence[Any], field: str) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(values)))
    for idx, value in enumerate(values):
        buffer.extend(encode_address(value, f"{field}[{idx}]"))
    return buffer


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_u16(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFF:
        raise ValueError(f"Field '{field}' must fit into u16")
    return bytearray(value.to_bytes(2, byteorder="little", signed=False))


def encode_u64_vector(values: Sequence[Any], field: str) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(values)))
    for idx, value in enumerate(values):
        buffer.extend(encode_u64(value, f"{field}[{idx}]"))
    return buffer


def normalize_entries(entries: Any) -> List[Dict[str, Any]]:
    if not isinstance(entries, list) or not entries:
        raise ValueError("Field 'lotteries' must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ValueError(f"lotteries[{idx}] must be an object")
        normalized.append(entry)
    return normalized


def encode_entry(entry: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(entry.get("lottery_id"), f"lotteries[{index}].lottery_id"))
    buffer.extend(encode_address(entry.get("owner"), f"lotteries[{index}].owner"))
    buffer.extend(encode_address(entry.get("lottery"), f"lotteries[{index}].lottery"))
    buffer.extend(encode_u64(entry.get("ticket_price"), f"lotteries[{index}].ticket_price"))
    buffer.extend(encode_u16(entry.get("jackpot_share_bps"), f"lotteries[{index}].jackpot_share_bps"))
    return buffer


def encode_entries(entries: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(entries)))
    for idx, entry in enumerate(entries):
        buffer.extend(encode_entry(entry, idx))
    return buffer


def encode_factory_state(snapshot: Dict[str, Any]) -> bytes:
    lotteries = normalize_entries(snapshot.get("lotteries"))
    lottery_ids = snapshot.get("lottery_ids")
    if not isinstance(lottery_ids, list):
        raise ValueError("Field 'lottery_ids' must be a list")

    buffer = bytearray()
    buffer.extend(encode_address(snapshot.get("admin"), "admin"))
    buffer.extend(encode_u64(snapshot.get("next_lottery_id"), "next_lottery_id"))
    buffer.extend(encode_u64_vector(lottery_ids, "lottery_ids"))
    buffer.extend(encode_entries(lotteries))
    return bytes(buffer)


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_supra_move(
    docker_service: str,
    config_path: Path,
    function: str,
    bcs_payload: Path,
) -> None:
    subprocess.run(
        [
            "docker",
            "compose",
            "run",
            "--rm",
            docker_service,
            "supra",
            "move",
            "run",
            "--assume-yes",
            "--config",
            str(config_path),
            "--function-id",
            function,
            "--args",
            f"0x{bcs_payload.read_bytes().hex()}",
        ],
        check=True,
    )


def main() -> None:
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    config_path = Path(args.config)
    output_path = Path(args.output_bcs)

    snapshot = load_snapshot(snapshot_path)
    payload = encode_factory_state(snapshot)
    write_payload(output_path, payload)

    print(f"Encoded LegacyFactoryState -> {output_path}")
    if args.execute:
        print(
            "Executing entry function via docker compose; this assumes the CLI has access "
            "to the correct signer and network."
        )
        run_supra_move(args.docker_service, config_path, args.function, output_path)
    else:
        print("Skipping on-chain execution because --execute was not provided")


if __name__ == "__main__":
    main()
