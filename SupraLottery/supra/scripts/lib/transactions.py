"""Helpers for executing Supra CLI transactions from Python scripts."""
from __future__ import annotations

import os
import re
import subprocess
from datetime import datetime, timezone
from typing import Dict, List, Optional, Sequence

try:  # pragma: no cover - import shim for script/package usage
    from ..monitor_common import MonitorError  # type: ignore[import]
except ImportError:  # pragma: no cover - fallback when executed as script
    from monitor_common import MonitorError  # type: ignore[import,no-redef]

_TX_HASH_RE = re.compile(r"0x[a-fA-F0-9]{64}")


def _find_tx_hash(output: str) -> Optional[str]:
    match = _TX_HASH_RE.search(output or "")
    if match:
        return match.group(0)
    return None


def _serialize_command(cmd: Sequence[str]) -> List[str]:
    return list(cmd)


def execute_move_tool_run(
    *,
    supra_cli_bin: str,
    profile: str,
    function_id: str,
    args: Sequence[str],
    supra_config: Optional[str] = None,
    assume_yes: bool = False,
    dry_run: bool = False,
    now: Optional[datetime] = None,
) -> Dict[str, object]:
    """Execute ``move tool run`` and return structured metadata."""

    if not profile:
        raise MonitorError("Нужно указать профиль Supra CLI (--profile)")
    if not function_id:
        raise MonitorError("Не задан идентификатор функции для вызова")

    timestamp = (now or datetime.now(timezone.utc)).isoformat()
    cmd = [
        supra_cli_bin,
        "move",
        "tool",
        "run",
        "--profile",
        profile,
        "--function-id",
        function_id,
    ]

    if args:
        cmd.append("--args")
        cmd.extend(args)

    if assume_yes:
        cmd.append("--assume-yes")

    if dry_run:
        return {
            "command": _serialize_command(cmd),
            "returncode": 0,
            "stdout": "",
            "stderr": "",
            "tx_hash": None,
            "submitted_at": timestamp,
            "dry_run": True,
        }

    env = os.environ.copy()
    if supra_config:
        env["SUPRA_CONFIG"] = supra_config

    process = subprocess.run(  # noqa: S603 - trusted CLI path
        cmd,
        capture_output=True,
        text=True,
        env=env,
    )

    stdout = process.stdout.strip()
    stderr = process.stderr.strip()
    tx_hash = _find_tx_hash(stdout) or _find_tx_hash(stderr)

    return {
        "command": _serialize_command(cmd),
        "returncode": int(process.returncode),
        "stdout": stdout,
        "stderr": stderr,
        "tx_hash": tx_hash,
        "submitted_at": timestamp,
    }


__all__ = ["execute_move_tool_run"]
