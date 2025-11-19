#!/usr/bin/env python3
"""Encode ReferralState snapshots for lottery_rewards_engine::referrals."""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON snapshot for lottery_rewards_engine::referrals, encode "
            "vector<LegacyReferralLottery> and/or vector<LegacyReferralRegistration> "
            "payloads, and optionally call the corresponding entry functions."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with optional 'lotteries' and 'registrations' arrays. "
            "Each lottery must contain lottery_id, referrer_bps, referee_bps, "
            "rewarded_purchases, total_referrer_rewards, total_referee_rewards. "
            "Each registration must contain player and referrer addresses."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--lotteries-output-bcs",
        default="tmp/referrals_lotteries_import.bcs",
        help="Where to write the vector<LegacyReferralLottery> payload (if lotteries exist).",
    )
    parser.add_argument(
        "--registrations-output-bcs",
        default="tmp/referrals_registrations_import.bcs",
        help=(
            "Where to write the vector<LegacyReferralRegistration> payload (if registrations exist)."
        ),
    )
    parser.add_argument(
        "--lotteries-function",
        default="lottery_rewards_engine::referrals::import_existing_lotteries",
        help="Entry function used for the lottery payload (defaults to the batch importer).",
    )
    parser.add_argument(
        "--registrations-function",
        default="lottery_rewards_engine::referrals::import_existing_registrations",
        help="Entry function used for the registrations payload (defaults to the batch importer).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help=(
            "If set, run supra move with every produced payload instead of just writing the BCS files."
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

    lotteries_raw = payload.get("lotteries", [])
    if lotteries_raw is None:
        lotteries_raw = []
    if not isinstance(lotteries_raw, list):
        raise ValueError("'lotteries' must be an array when provided")
    lotteries: List[Dict[str, Any]] = []
    for index, record in enumerate(lotteries_raw):
        if not isinstance(record, dict):
            raise ValueError(f"lotteries[{index}] must be an object")
        lotteries.append(record)

    registrations_raw = payload.get("registrations", [])
    if registrations_raw is None:
        registrations_raw = []
    if not isinstance(registrations_raw, list):
        raise ValueError("'registrations' must be an array when provided")
    registrations: List[Dict[str, Any]] = []
    for index, record in enumerate(registrations_raw):
        if not isinstance(record, dict):
            raise ValueError(f"registrations[{index}] must be an object")
        registrations.append(record)

    if not lotteries and not registrations:
        raise ValueError("Snapshot must include at least one lottery or registration record")

    return {"lotteries": lotteries, "registrations": registrations}


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


def encode_lottery(record: Dict[str, Any], index: int) -> bytearray:
    prefix = f"lotteries[{index}]"
    buffer = bytearray()
    buffer.extend(encode_u64(record.get("lottery_id"), f"{prefix}.lottery_id"))
    buffer.extend(encode_u64(record.get("referrer_bps"), f"{prefix}.referrer_bps"))
    buffer.extend(encode_u64(record.get("referee_bps"), f"{prefix}.referee_bps"))
    buffer.extend(
        encode_u64(record.get("rewarded_purchases"), f"{prefix}.rewarded_purchases")
    )
    buffer.extend(
        encode_u64(record.get("total_referrer_rewards"), f"{prefix}.total_referrer_rewards")
    )
    buffer.extend(
        encode_u64(record.get("total_referee_rewards"), f"{prefix}.total_referee_rewards")
    )
    return buffer


def encode_lotteries(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for index, record in enumerate(records):
        buffer.extend(encode_lottery(record, index))
    return buffer


def encode_registration(record: Dict[str, Any], index: int) -> bytearray:
    prefix = f"registrations[{index}]"
    buffer = bytearray()
    buffer.extend(encode_address(record.get("player"), f"{prefix}.player"))
    buffer.extend(encode_address(record.get("referrer"), f"{prefix}.referrer"))
    return buffer


def encode_registrations(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_vector_length(len(records)))
    for index, record in enumerate(records):
        buffer.extend(encode_registration(record, index))
    return buffer


def write_payload(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)


def run_cli(docker_service: str, config_path: Path, function: str, bcs_path: Path) -> None:
    command = [
        "docker",
        "compose",
        "run",
        "--rm",
        docker_service,
        "supra",
        "move",
        "run",
        "--function-id",
        function,
        "--args",
        bcs_path.as_posix(),
        "--json",
        f"--config={config_path}",
    ]
    print(f"Executing: {' '.join(command)}")
    subprocess.check_call(command)


def main() -> int:
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    config_path = Path(args.config)
    docker_service = args.docker_service

    snapshot = load_snapshot(snapshot_path)
    lotteries = snapshot["lotteries"]
    registrations = snapshot["registrations"]

    if lotteries:
        lotteries_payload = encode_lotteries(lotteries)
        lotteries_bcs_path = Path(args.lotteries_output_bcs)
        write_payload(lotteries_bcs_path, lotteries_payload)
        print(f"Wrote {len(lotteries_payload)} bytes to {lotteries_bcs_path}")
        if args.execute:
            run_cli(docker_service, config_path, args.lotteries_function, lotteries_bcs_path)

    if registrations:
        registrations_payload = encode_registrations(registrations)
        registrations_bcs_path = Path(args.registrations_output_bcs)
        write_payload(registrations_bcs_path, registrations_payload)
        print(f"Wrote {len(registrations_payload)} bytes to {registrations_bcs_path}")
        if args.execute:
            run_cli(
                docker_service,
                config_path,
                args.registrations_function,
                registrations_bcs_path,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
