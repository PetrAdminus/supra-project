import argparse
import json
import shlex
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a JSON snapshot of lottery runtimes, encode it as "
            "vector<LegacyLotteryRuntime> and optionally call "
            "lottery_data::lottery_state::import_existing_lotteries."
        )
    )
    parser.add_argument(
        "snapshot",
        help=(
            "Path to JSON file. Expected format: "
            '{"lotteries": [{"lottery_id": 1, "ticket_price": 10, "jackpot_amount": 1000, '
            '"participants": ["0x..."], "next_ticket_id": 5, "draw_scheduled": false, '
            '"auto_draw_threshold": 0, "pending_request_id": null, '
            '"last_request_payload_hash": "deadbeef" | null, "last_requester": "0x..." | null, '
            '"gas": {...}, "vrf_stats": {...}, "whitelist": {...}, "request_config": {...|null}}]}'
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to supra move CLI config (forwarded to supra move run).",
    )
    parser.add_argument(
        "--output-bcs",
        default="tmp/lottery_runtimes_import.bcs",
        help="Where to write the encoded vector<LegacyLotteryRuntime> payload.",
    )
    parser.add_argument(
        "--function",
        default="lottery_data::lottery_state::import_existing_lotteries",
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


def load_lotteries(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or "lotteries" not in payload:
        raise ValueError("Snapshot must be an object with a 'lotteries' array")
    lotteries = payload["lotteries"]
    if not isinstance(lotteries, list) or not lotteries:
        raise ValueError("The 'lotteries' array must be a non-empty list")
    normalized: List[Dict[str, Any]] = []
    for idx, lottery in enumerate(lotteries):
        if not isinstance(lottery, dict):
            raise ValueError(f"lotteries[{idx}] must be an object")
        normalized.append(lottery)
    return normalized


def encode_uleb128(value: int) -> bytearray:
    if value < 0:
        raise ValueError("Length must be non-negative")
    buffer = bytearray()
    remaining = value
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


def encode_bool(value: Any, field: str) -> bytearray:
    if not isinstance(value, bool):
        raise ValueError(f"Field '{field}' must be a boolean")
    return bytearray(b"\x01" if value else b"\x00")


def encode_u8(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFF:
        raise ValueError(f"Field '{field}' must fit into u8")
    return bytearray(value.to_bytes(1, byteorder="little", signed=False))


def encode_u64(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u64")
    return bytearray(value.to_bytes(8, byteorder="little", signed=False))


def encode_u128(value: Any, field: str) -> bytearray:
    if not isinstance(value, int):
        raise ValueError(f"Field '{field}' must be an integer")
    if value < 0 or value > 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:
        raise ValueError(f"Field '{field}' must fit into u128")
    return bytearray(value.to_bytes(16, byteorder="little", signed=False))


def encode_bytes(value: Any, field: str) -> bytearray:
    if not isinstance(value, str):
        raise ValueError(f"Field '{field}' must be a hex string")
    normalized = value.lower()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    if len(normalized) % 2 == 1:
        normalized = "0" + normalized
    data = bytes.fromhex(normalized)
    return encode_uleb128(len(data)) + bytearray(data)


def encode_address(value: Any, field: str) -> bytearray:
    return bytearray(parse_address(value, field))


def encode_option(content: Any, encoder, field: str) -> bytearray:
    if content is None:
        return bytearray(b"\x00")
    return bytearray(b"\x01") + encoder(content, field)


def encode_vector(items: Sequence[Any], encoder, field: str) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_uleb128(len(items)))
    for idx, item in enumerate(items):
        buffer.extend(encoder(item, f"{field}[{idx}]"))
    return buffer


def encode_gas_budget(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    required = [
        "max_fee",
        "max_gas_price",
        "max_gas_limit",
        "callback_gas_price",
        "callback_gas_limit",
        "verification_gas_value",
    ]
    for key in required:
        if key not in data:
            raise ValueError(f"Field '{field}.{key}' is required")
    buffer = bytearray()
    buffer.extend(encode_u64(data["max_fee"], f"{field}.max_fee"))
    buffer.extend(encode_u128(data["max_gas_price"], f"{field}.max_gas_price"))
    buffer.extend(encode_u128(data["max_gas_limit"], f"{field}.max_gas_limit"))
    buffer.extend(encode_u128(data["callback_gas_price"], f"{field}.callback_gas_price"))
    buffer.extend(encode_u128(data["callback_gas_limit"], f"{field}.callback_gas_limit"))
    buffer.extend(encode_u128(data["verification_gas_value"], f"{field}.verification_gas_value"))
    return buffer


def encode_vrf_stats(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    required = ["request_count", "response_count", "next_client_seed"]
    for key in required:
        if key not in data:
            raise ValueError(f"Field '{field}.{key}' is required")
    buffer = bytearray()
    buffer.extend(encode_u64(data["request_count"], f"{field}.request_count"))
    buffer.extend(encode_u64(data["response_count"], f"{field}.response_count"))
    buffer.extend(encode_u64(data["next_client_seed"], f"{field}.next_client_seed"))
    return buffer


def encode_client_whitelist(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    required = ["max_gas_price", "max_gas_limit", "min_balance_limit"]
    for key in required:
        if key not in data:
            raise ValueError(f"Field '{field}.{key}' is required")
    buffer = bytearray()
    buffer.extend(encode_u128(data["max_gas_price"], f"{field}.max_gas_price"))
    buffer.extend(encode_u128(data["max_gas_limit"], f"{field}.max_gas_limit"))
    buffer.extend(encode_u128(data["min_balance_limit"], f"{field}.min_balance_limit"))
    return buffer


def encode_consumer_whitelist(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    required = ["callback_gas_price", "callback_gas_limit"]
    for key in required:
        if key not in data:
            raise ValueError(f"Field '{field}.{key}' is required")
    buffer = bytearray()
    buffer.extend(encode_u128(data["callback_gas_price"], f"{field}.callback_gas_price"))
    buffer.extend(encode_u128(data["callback_gas_limit"], f"{field}.callback_gas_limit"))
    return buffer


def encode_whitelist(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    buffer = bytearray()
    buffer.extend(encode_option(data.get("callback_sender"), encode_address, f"{field}.callback_sender"))
    consumers = data.get("consumers", [])
    if not isinstance(consumers, list):
        raise ValueError(f"Field '{field}.consumers' must be an array")
    buffer.extend(encode_vector(consumers, encode_address, f"{field}.consumers"))
    buffer.extend(
        encode_option(
            data.get("client_snapshot"),
            encode_client_whitelist,
            f"{field}.client_snapshot",
        )
    )
    buffer.extend(
        encode_option(
            data.get("consumer_snapshot"),
            encode_consumer_whitelist,
            f"{field}.consumer_snapshot",
        )
    )
    return buffer


def encode_request_config(data: Dict[str, Any], field: str) -> bytearray:
    if not isinstance(data, dict):
        raise ValueError(f"Field '{field}' must be an object")
    required = ["rng_count", "num_confirmations", "client_seed"]
    for key in required:
        if key not in data:
            raise ValueError(f"Field '{field}.{key}' is required")
    buffer = bytearray()
    buffer.extend(encode_u8(data["rng_count"], f"{field}.rng_count"))
    buffer.extend(encode_u64(data["num_confirmations"], f"{field}.num_confirmations"))
    buffer.extend(encode_u64(data["client_seed"], f"{field}.client_seed"))
    return buffer


def encode_lottery_runtime(record: Dict[str, Any], index: int) -> bytearray:
    required_fields = [
        "lottery_id",
        "ticket_price",
        "jackpot_amount",
        "participants",
        "next_ticket_id",
        "draw_scheduled",
        "auto_draw_threshold",
        "pending_request_id",
        "last_request_payload_hash",
        "last_requester",
        "gas",
        "vrf_stats",
        "whitelist",
        "request_config",
    ]
    for field in required_fields:
        if field not in record:
            raise ValueError(f"lotteries[{index}].{field} is required")
    buffer = bytearray()
    buffer.extend(encode_u64(record["lottery_id"], f"lotteries[{index}].lottery_id"))
    buffer.extend(encode_u64(record["ticket_price"], f"lotteries[{index}].ticket_price"))
    buffer.extend(encode_u64(record["jackpot_amount"], f"lotteries[{index}].jackpot_amount"))
    participants = record["participants"]
    if not isinstance(participants, list):
        raise ValueError(f"lotteries[{index}].participants must be an array")
    buffer.extend(encode_vector(participants, encode_address, f"lotteries[{index}].participants"))
    buffer.extend(encode_u64(record["next_ticket_id"], f"lotteries[{index}].next_ticket_id"))
    buffer.extend(encode_bool(record["draw_scheduled"], f"lotteries[{index}].draw_scheduled"))
    buffer.extend(encode_u64(record["auto_draw_threshold"], f"lotteries[{index}].auto_draw_threshold"))
    buffer.extend(
        encode_option(
            record.get("pending_request_id"), encode_u64, f"lotteries[{index}].pending_request_id"
        )
    )
    buffer.extend(
        encode_option(
            record.get("last_request_payload_hash"),
            encode_bytes,
            f"lotteries[{index}].last_request_payload_hash",
        )
    )
    buffer.extend(
        encode_option(
            record.get("last_requester"), encode_address, f"lotteries[{index}].last_requester"
        )
    )
    buffer.extend(encode_gas_budget(record["gas"], f"lotteries[{index}].gas"))
    buffer.extend(encode_vrf_stats(record["vrf_stats"], f"lotteries[{index}].vrf_stats"))
    buffer.extend(encode_whitelist(record["whitelist"], f"lotteries[{index}].whitelist"))
    buffer.extend(
        encode_option(
            record.get("request_config"),
            encode_request_config,
            f"lotteries[{index}].request_config",
        )
    )
    return buffer


def encode_lotteries(records: Sequence[Dict[str, Any]]) -> bytearray:
    buffer = bytearray()
    buffer.extend(encode_uleb128(len(records)))
    for idx, record in enumerate(records):
        buffer.extend(encode_lottery_runtime(record, idx))
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
    lotteries = load_lotteries(snapshot_path)

    payload = encode_lotteries(lotteries)
    output_path = Path(args.output_bcs)
    write_payload(output_path, payload)
    print(
        f"Encoded {len(lotteries)} lottery runtime(s) to {output_path} (size={len(payload)} bytes)",
        flush=True,
    )

    if args.execute:
        print("Executing supra move run…", flush=True)
        run_import(args.config, args.function, args.docker_service, output_path)
    else:
        print(
            "Dry run complete. Use --execute to submit or run manually via:\n"
            f"supra move run --config {args.config} --function {args.function} --args-bytes-file {output_path}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
