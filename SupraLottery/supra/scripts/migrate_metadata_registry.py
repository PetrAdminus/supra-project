#!/usr/bin/env python3
"""Prepare LegacyMetadataImport payloads and optionally execute the import entry."""
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a JSON metadata snapshot into LegacyMetadataImport payloads "
            "and run lottery_utils::metadata::import_existing_metadata_batch."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with metadata entries. Expected format: "
            "{\"entries\": [{\"lottery_id\": 1, \"title\": \"...\", \"description\": \"...\", \"image_uri\": \"...\", "
            "\"website_uri\": \"...\", \"rules_uri\": \"...\"}, ...]}"
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/metadata_import_payload.bcs",
        help="Where to write the encoded vector<LegacyMetadataImport> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_utils::metadata::import_existing_metadata_batch",
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
        help="Docker Compose service name that hosts the supra CLI (defaults to supra_cli).",
    )
    return parser.parse_args()


def load_entries(path: Path) -> List[dict]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "entries" not in payload:
        raise ValueError("Snapshot must be an object with an 'entries' array")
    entries = payload["entries"]
    if not isinstance(entries, list) or not entries:
        raise ValueError("The 'entries' array must be non-empty")
    normalized = []
    for idx, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ValueError(f"Entry #{idx} must be an object")
        normalized.append(entry)
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


def encode_u64(value: int) -> bytearray:
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError("lottery_id must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_vector_bytes(data: bytes) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(data)))
    buffer.extend(data)
    return buffer


def ensure_ascii(field: str, value: str) -> bytes:
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a string")
    if not value.isascii():
        raise ValueError(f"Field '{field}' must contain only ASCII characters")
    return value.encode("ascii")


def encode_metadata(entry: dict) -> bytearray:
    metadata = bytearray()
    metadata.extend(encode_vector_bytes(ensure_ascii("title", entry.get("title", ""))))
    metadata.extend(encode_vector_bytes(ensure_ascii("description", entry.get("description", ""))))
    metadata.extend(encode_vector_bytes(ensure_ascii("image_uri", entry.get("image_uri", ""))))
    metadata.extend(encode_vector_bytes(ensure_ascii("website_uri", entry.get("website_uri", ""))))
    metadata.extend(encode_vector_bytes(ensure_ascii("rules_uri", entry.get("rules_uri", ""))))
    return metadata


def encode_legacy_metadata_import(entry: dict) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_u64(int(entry.get("lottery_id", -1))))
    buffer.extend(encode_metadata(entry))
    return buffer


def encode_entries(entries: Sequence[dict]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(entries)))
    for entry in entries:
        buffer.extend(encode_legacy_metadata_import(entry))
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
    entries = load_entries(snapshot_path)
    payload = encode_entries(entries)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(entries)} metadata entries to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing import via supra move run...", flush=True)
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
