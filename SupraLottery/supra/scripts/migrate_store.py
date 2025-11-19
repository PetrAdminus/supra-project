"""Encode LegacyStoreItem snapshots and optionally call the import entry."""

import argparse
import json
import shlex
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON store snapshot, encode it as vector<LegacyStoreItem> "
            "and optionally run lottery_rewards_engine::store::import_existing_items."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with store data. Expected format: "
            '{"items": [{"lottery_id": 1, "item_id": 1, "price": 1, "metadata": "...", '
            '"available": true, "stock": null, "sold": 0}, ...]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/store_items_import.bcs",
        help="Where to write the encoded vector<LegacyStoreItem> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_rewards_engine::store::import_existing_items",
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


def load_items(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "items" not in payload:
        raise ValueError("Snapshot must be an object with an 'items' array")
    items = payload["items"]
    if not isinstance(items, list) or not items:
        raise ValueError("The 'items' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f"items[{idx}] must be an object")
        normalized.append(item)
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
    else:
        raise ValueError(
            f"Field '{field}' must be ASCII text, 0x-prefixed hex or an array of integers"
        )
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(data)))
    buffer.extend(data)
    return buffer


def encode_item(item: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(item.get("lottery_id"), f"items[{index}].lottery_id"))
    buffer.extend(encode_u64(item.get("item_id"), f"items[{index}].item_id"))
    buffer.extend(encode_u64(item.get("price"), f"items[{index}].price"))
    buffer.extend(encode_bytes(item.get("metadata", ""), f"items[{index}].metadata"))
    buffer.extend(encode_bool(item.get("available"), f"items[{index}].available"))
    buffer.extend(encode_option_u64(item.get("stock"), f"items[{index}].stock"))
    buffer.extend(encode_u64(item.get("sold"), f"items[{index}].sold"))
    return buffer


def encode_items(items: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(items)))
    for idx, item in enumerate(items):
        buffer.extend(encode_item(item, idx))
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
    items = load_items(snapshot_path)
    payload = encode_items(items)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(items)} store item(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run with the encoded payload...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry-run mode: payload written to disk. Pass --execute to submit the transaction.",
            flush=True,
        )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
