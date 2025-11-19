#!/usr/bin/env python3
"""BCS-энкодер снапшотов FeatureRegistry и обёртка для supra move run."""

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
            "Validate a JSON FeatureRegistry snapshot, encode it as LegacyFeatureRegistry "
            "payload and optionally run lottery_utils::feature_flags::import_existing_registry."
        )
    )
    parser.add_argument("snapshot", help="Path to JSON file with FeatureRegistry data.")
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/feature_registry_import.bcs",
        help="Where to write the encoded LegacyFeatureRegistry payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_utils::feature_flags::import_existing_registry",
        help="Entry function to call (defaults to the registry importer).",
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
    return payload


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


def encode_address(value: Any, field: str) -> bytearray:
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
    return bytearray(b"\x00" * (32 - len(data)) + data)


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray(b"\x01" if value else b"\x00")


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


def encode_feature(feature: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(feature.get("feature_id"), f"features[{index}].feature_id"))
    mode = feature.get("mode")
    if mode not in (0, 1, 2):
        raise ValueError(
            f"features[{index}].mode must be one of 0 (disabled), 1 (all) or 2 (premium only)"
        )
    buffer.extend(encode_u8(mode, f"features[{index}].mode"))
    return buffer


def encode_features(features: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(features)))
    for idx, feature in enumerate(features):
        if not isinstance(feature, dict):
            raise ValueError(f"features[{idx}] must be an object")
        buffer.extend(encode_feature(feature, idx))
    return buffer


def encode_registry(snapshot: Dict[str, Any]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(snapshot.get("admin"), "admin"))
    buffer.extend(encode_bool(snapshot.get("force_enable_devnet", False), "force_enable_devnet"))
    features = snapshot.get("features", [])
    if not isinstance(features, list):
        raise ValueError("Field 'features' must be an array")
    buffer.extend(encode_features(features))
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
    payload = encode_registry(load_snapshot(snapshot_path))
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded FeatureRegistry payload with size {len(payload)} bytes to {output_path}",
        flush=True,
    )

    if args.execute:
        print("Executing import via supra move run...", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit or run manually with:\n"
            f"supra move run --config {args.config} --function {args.function} "
            f"--args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
