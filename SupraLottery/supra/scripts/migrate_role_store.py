#!/usr/bin/env python3
"""Encode a RoleStore snapshot and run lottery_data::access::import_existing_role_store."""

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
            "Validate a JSON RoleStore snapshot, encode it as LegacyRoleStore payload "
            "and optionally execute lottery_data::access::import_existing_role_store."
        )
    )
    parser.add_argument("snapshot", help="Path to JSON file with RoleStore data.")
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/role_store_import.bcs",
        help="Where to write the encoded LegacyRoleStore payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::access::import_existing_role_store",
        help="Entry function to call (defaults to the LegacyRoleStore importer).",
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


def encode_vector_length(length: int) -> bytearray:
    if length < 0:
        raise ValueError("Vector length must be non-negative")
    remaining = length
    buffer = bytearray()
    while True:
        byte = remaining & 0x7F
        remaining >>= 7
        if remaining == 0:
            buffer.append(byte)
            break
        buffer.append(byte | 0x80)
    return buffer


def encode_option(value: Optional[Any], encoder) -> bytearray:
    if value is None:
        return encode_vector_length(0)
    buffer = bytearray()
    buffer.extend(encode_vector_length(1))
    buffer.extend(encoder(value))
    return buffer


def encode_payout_cap(cap: Dict[str, Any]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(cap.get("holder"), "payout_batch.holder"))
    buffer.extend(encode_u64(cap.get("max_batch_size"), "payout_batch.max_batch_size"))
    buffer.extend(
        encode_u64(
            cap.get("operations_budget_total"),
            "payout_batch.operations_budget_total",
        )
    )
    buffer.extend(
        encode_u64(
            cap.get("operations_budget_used"),
            "payout_batch.operations_budget_used",
        )
    )
    buffer.extend(encode_u64(cap.get("cooldown_secs"), "payout_batch.cooldown_secs"))
    buffer.extend(encode_u64(cap.get("last_batch_at"), "payout_batch.last_batch_at"))
    buffer.extend(encode_u64(cap.get("last_nonce"), "payout_batch.last_nonce"))
    buffer.extend(encode_u64(cap.get("nonce_stride"), "payout_batch.nonce_stride"))
    return buffer


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_partner_cap(cap: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(cap.get("partner"), f"partner_caps[{index}].partner"))
    buffer.extend(
        encode_u64(cap.get("max_total_payout"), f"partner_caps[{index}].max_total_payout")
    )
    buffer.extend(
        encode_u64(cap.get("remaining_payout"), f"partner_caps[{index}].remaining_payout")
    )
    buffer.extend(
        encode_u64(
            cap.get("payout_cooldown_secs"), f"partner_caps[{index}].payout_cooldown_secs"
        )
    )
    buffer.extend(
        encode_u64(cap.get("last_payout_at"), f"partner_caps[{index}].last_payout_at")
    )
    buffer.extend(encode_u64(cap.get("next_nonce"), f"partner_caps[{index}].next_nonce"))
    buffer.extend(encode_u64(cap.get("nonce_stride"), f"partner_caps[{index}].nonce_stride"))
    buffer.extend(encode_u64(cap.get("expires_at"), f"partner_caps[{index}].expires_at"))
    return buffer


def encode_partner_caps(caps: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(caps)))
    for idx, cap in enumerate(caps):
        if not isinstance(cap, dict):
            raise ValueError(f"partner_caps[{idx}] must be an object")
        buffer.extend(encode_partner_cap(cap, idx))
    return buffer


def encode_premium_cap(cap: Dict[str, Any], index: int) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(cap.get("holder"), f"premium_caps[{index}].holder"))
    buffer.extend(encode_u64(cap.get("expires_at"), f"premium_caps[{index}].expires_at"))
    buffer.extend(encode_bool(cap.get("auto_renew"), f"premium_caps[{index}].auto_renew"))
    buffer.extend(
        encode_option(
            cap.get("referrer"),
            lambda addr: bytearray(parse_address(addr, f"premium_caps[{index}].referrer")),
        )
    )
    return buffer


def encode_premium_caps(caps: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(caps)))
    for idx, cap in enumerate(caps):
        if not isinstance(cap, dict):
            raise ValueError(f"premium_caps[{idx}] must be an object")
        buffer.extend(encode_premium_cap(cap, idx))
    return buffer


def encode_role_store(snapshot: Dict[str, Any]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_address(snapshot.get("admin"), "admin"))
    payout_cap = snapshot.get("payout_batch")
    buffer.extend(
        encode_option(
            payout_cap,
            lambda value: encode_payout_cap(assert_dict(value, "payout_batch")),
        )
    )
    partner_caps = snapshot.get("partner_caps", [])
    premium_caps = snapshot.get("premium_caps", [])
    buffer.extend(encode_partner_caps(assert_sequence(partner_caps, "partner_caps")))
    buffer.extend(encode_premium_caps(assert_sequence(premium_caps, "premium_caps")))
    return buffer


def assert_dict(value: Any, field: str) -> Dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"Field '{field}' must be an object")
    return value


def assert_sequence(value: Any, field: str) -> Sequence[Dict[str, Any]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"Field '{field}' must be an array")
    return value


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_import(config: str, entry_fn: str, docker_service: str, payload_path: Path) -> None:
    cli_command = (
        f"supra move run --config {shlex.quote(config)} --function {shlex.quote(entry_fn)} "
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
    payload = encode_role_store(snapshot)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded RoleStore payload with {len(snapshot.get('partner_caps', []))} partner cap(s) "
        f"and {len(snapshot.get('premium_caps', []))} premium cap(s) to {output_path}",
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
