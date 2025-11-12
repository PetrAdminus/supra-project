from __future__ import annotations

import json
import os
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

ROOT_DIR = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT_DIR / "supra" / "tools" / "history_backfill_dry_run.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("history_backfill_dry_run", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("failed to load history_backfill_dry_run module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)  # type: ignore[assignment]
    return module


history_backfill = _load_module()
compute_artifacts = history_backfill.compute_artifacts
read_summary_bytes = history_backfill.read_summary_bytes


@pytest.fixture()
def tmp_hex_file(tmp_path: Path) -> Path:
    path = tmp_path / "summary.hex"
    path.write_text("0xdeadbeef", encoding="utf-8")
    return path


def test_read_summary_bytes_from_hex(tmp_hex_file: Path) -> None:
    data = read_summary_bytes(tmp_hex_file)
    assert data == bytes.fromhex("deadbeef")


def test_read_summary_bytes_binary(tmp_path: Path) -> None:
    path = tmp_path / "summary.bcs"
    payload = b"\x00\x01\x02"
    path.write_bytes(payload)
    data = read_summary_bytes(path)
    assert data == payload


def test_compute_artifacts_matches_sha3() -> None:
    payload = bytes.fromhex("cafebabe")
    artifacts = compute_artifacts(payload)
    assert artifacts.summary_hex == "0xcafebabe"
    from hashlib import sha3_256

    assert artifacts.expected_hash == "0x" + sha3_256(payload).hexdigest()


@pytest.mark.parametrize(
    "payload",
    [b"", bytes.fromhex("01"), bytes.fromhex("0102")],
)
def test_cli_generates_command(payload: bytes, tmp_path: Path) -> None:
    summary_path = tmp_path / "summary.bcs"
    summary_path.write_bytes(payload)
    env = os.environ.copy()
    env["PYTHONPATH"] = os.pathsep.join(filter(None, [env.get("PYTHONPATH"), str(Path.cwd())]))
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "supra.tools.history_backfill_dry_run",
            str(summary_path),
            "--lottery-id",
            "7",
            "--config",
            "/supra/config.yaml",
            "--script",
            "./supra/scripts/history_backfill.sh",
        ],
        capture_output=True,
        check=True,
        env=env,
        text=True,
    )
    assert "Suggested import command" in result.stdout
    assert "history_backfill.sh /supra/config.yaml import 7" in result.stdout


def _prepare_env() -> dict[str, str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = os.pathsep.join(filter(None, [env.get("PYTHONPATH"), str(Path.cwd())]))
    return env


def test_cli_json_quiet(tmp_path: Path) -> None:
    summary_path = tmp_path / "legacy_summary.bcs"
    summary_path.write_bytes(bytes.fromhex("00"))
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "supra.tools.history_backfill_dry_run",
            str(summary_path),
            "--lottery-id",
            "11",
            "--config",
            "/supra/config.yaml",
            "--json",
            "--quiet",
        ],
        capture_output=True,
        check=True,
        env=_prepare_env(),
        text=True,
    )
    payload = json.loads(result.stdout)
    assert payload["lottery_id"] == 11
    assert payload["summary_hex"].startswith("0x")
    assert payload["expected_hash"].startswith("0x")
    assert payload["suggested_command"].startswith("./supra/scripts/history_backfill.sh")


def test_cli_json_output_file(tmp_path: Path) -> None:
    summary_path = tmp_path / "legacy_summary.bcs"
    summary_path.write_bytes(bytes.fromhex("0102"))
    json_path = tmp_path / "artifacts.json"
    subprocess.run(
        [
            sys.executable,
            "-m",
            "supra.tools.history_backfill_dry_run",
            str(summary_path),
            "--lottery-id",
            "22",
            "--json-output",
            str(json_path),
            "--json",
            "--quiet",
        ],
        capture_output=True,
        check=True,
        env=_prepare_env(),
        text=True,
    )
    saved = json.loads(json_path.read_text(encoding="utf-8"))
    assert saved["lottery_id"] == 22
    assert saved["summary_path"].endswith("legacy_summary.bcs")
