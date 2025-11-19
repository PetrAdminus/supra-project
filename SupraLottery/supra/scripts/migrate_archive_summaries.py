import argparse
import json
import shlex
import subprocess
from hashlib import sha3_256
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate legacy archive summaries, encode them as "
            "vector<LegacyArchiveImport> and optionally call "
            "lottery_utils::history::import_existing_legacy_summaries."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file with a 'summaries' array matching LotterySummary fields."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/archive_imports.bcs",
        help="Where to write the encoded vector<LegacyArchiveImport> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_utils::history::import_existing_legacy_summaries",
        help="Entry function to call (defaults to the batch legacy importer).",
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
    except ValueError as exc:  # pragma: no cover - validated by callers
        raise ValueError(f"Field '{field}' must be valid hex: {exc}") from exc
    return bytearray(data)


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 2**64 - 1:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_u8(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 255:
        raise ValueError(f"Field '{field}' must fit into u8")
    return bytearray([value])


def encode_bytes(data: bytearray) -> bytearray:
    encoded = bytearray()
    encoded.extend(encode_vector_length(len(data)))
    encoded.extend(data)
    return encoded


def encode_summary(summary: Dict[str, Any]) -> bytearray:
    fields = [
        ("lottery_id", encode_u64),
        ("event_slug", parse_hex_bytes),
        ("series_code", parse_hex_bytes),
        ("run_id", encode_u64),
        ("tickets_sold", encode_u64),
        ("proceeds_accum", encode_u64),
        ("total_allocated", encode_u64),
        ("total_prize_paid", encode_u64),
        ("total_operations_paid", encode_u64),
        ("vrf_status", encode_u8),
        ("primary_type", encode_u8),
        ("tags_mask", encode_u64),
        ("snapshot_hash", parse_hex_bytes),
        ("slots_checksum", parse_hex_bytes),
        ("winners_batch_hash", parse_hex_bytes),
        ("checksum_after_batch", parse_hex_bytes),
        ("payout_round", encode_u64),
        ("created_at", encode_u64),
        ("closed_at", encode_u64),
        ("finalized_at", encode_u64),
    ]
    encoded = bytearray()
    for name, encoder in fields:
        value = summary.get(name)
        if encoder is parse_hex_bytes:
            encoded.extend(encode_bytes(encoder(value, name)))
        else:
            encoded.extend(encoder(value, name))
    return encoded


def encode_archive_import(summary: Dict[str, Any]) -> bytearray:
    encoded_summary = encode_summary(summary)
    computed_hash = sha3_256(encoded_summary).digest()
    expected_override = summary.get("expected_hash")
    if expected_override is None:
        expected_hash = bytearray(computed_hash)
    else:
        expected_hash_bytes = parse_hex_bytes(expected_override, "expected_hash")
        if bytes(expected_hash_bytes) != computed_hash:
            raise ValueError("expected_hash does not match computed sha3_256(summary_bcs)")
        expected_hash = expected_hash_bytes

    encoded = bytearray()
    encoded.extend(encode_u64(summary.get("lottery_id"), "lottery_id"))
    encoded.extend(encode_bytes(bytearray(encoded_summary)))
    encoded.extend(encode_bytes(expected_hash))
    return encoded


def encode_payload(summaries: Sequence[Dict[str, Any]]) -> bytes:
    encoded = bytearray()
    encoded.extend(encode_vector_length(len(summaries)))
    for summary in summaries:
        encoded.extend(encode_archive_import(summary))
    return bytes(encoded)


def load_summaries(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "summaries" not in payload:
        raise ValueError("Snapshot must be an object with a 'summaries' array")
    summaries = payload["summaries"]
    if not isinstance(summaries, list) or not summaries:
        raise ValueError("The 'summaries' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, summary in enumerate(summaries):
        if not isinstance(summary, dict):
            raise ValueError(f"summaries[{idx}] must be an object")
        normalized.append(summary)
    return normalized


def write_payload(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def run_cli(
    function: str,
    config_path: Path,
    payload_path: Path,
    docker_service: str,
) -> None:
    command = " ".join(
        [
            "docker",
            "compose",
            "run",
            "--rm",
            docker_service,
            "supra",
            "move",
            "run",
            "--function",
            shlex.quote(function),
            "--config",
            shlex.quote(str(config_path)),
            "--args-bcs",
            shlex.quote(str(payload_path)),
        ]
    )
    print(f"Executing: {command}")
    subprocess.run(command, shell=True, check=True)


if __name__ == "__main__":
    args = parse_args()
    snapshot_path = Path(args.snapshot)
    summaries = load_summaries(snapshot_path)
    payload = encode_payload(summaries)

    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(f"Wrote {len(payload)} bytes to {output_path}")

    if args.execute:
        run_cli(args.function, Path(args.config), output_path, args.docker_service)
