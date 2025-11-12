"""Утилита для подготовки данных к `history_backfill.sh`.

Скрипт принимает файл с BCS-сводкой (в бинарном виде или в hex-представлении)
и рассчитывает sha3-256 хэш, который требуется передать в on-chain функцию
`history::import_legacy_summary_admin`. Одновременно он выводит hex-строку,
которую можно использовать в аргументах CLI, и при наличии идентификатора
лотереи формирует подсказку по запуску `history_backfill.sh import`.

Пример использования::

    python -m supra.tools.history_backfill_dry_run legacy_summary.bcs --lottery-id 42 \
        --hex-output legacy_summary.hex

В дополнение к выводу в stdout hex-строку и хэш можно записать в файл, чтобы
использовать её в CI/CD или передать команде миграции.
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from hashlib import sha3_256
from pathlib import Path
from textwrap import wrap
from typing import Iterable

_HEX_DIGITS = set("0123456789abcdefABCDEF")


@dataclass(frozen=True)
class SummaryArtifacts:
    """Результат подготовки сводки для импорта."""

    summary_bytes: bytes
    summary_hex: str
    expected_hash: str

    @property
    def size(self) -> int:
        return len(self.summary_bytes)


def _normalize_hex_string(value: str) -> str | None:
    trimmed = value.strip()
    if not trimmed:
        return ""
    if trimmed.startswith("0x") or trimmed.startswith("0X"):
        trimmed = trimmed[2:]
    trimmed = trimmed.replace("_", "")
    if any(ch not in _HEX_DIGITS for ch in trimmed):
        return None
    if len(trimmed) % 2 == 1:
        trimmed = "0" + trimmed
    return trimmed.lower()


def read_summary_bytes(path: Path) -> bytes:
    """Загружает сводку из файла, поддерживая бинарный и hex-формат."""

    data = path.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data

    normalized = _normalize_hex_string(text)
    if normalized is None:
        return data
    if not normalized:
        return b""
    return bytes.fromhex(normalized)


def compute_artifacts(summary_bytes: bytes) -> SummaryArtifacts:
    summary_hex = "0x" + summary_bytes.hex()
    expected_hash = "0x" + sha3_256(summary_bytes).hexdigest()
    return SummaryArtifacts(summary_bytes=summary_bytes, summary_hex=summary_hex, expected_hash=expected_hash)


def _format_preview(hex_value: str, limit: int = 80) -> str:
    if len(hex_value) <= limit:
        return hex_value
    return f"{hex_value[:limit]}… (total {len(hex_value) - 2} hex chars)"


def _build_command(args: argparse.Namespace, artifacts: SummaryArtifacts) -> str | None:
    lottery_id = args.lottery_id
    if lottery_id is None:
        return None
    config = args.config or os.environ.get("SUPRA_HISTORY_BACKFILL_CONFIG") or "<supra_config.yaml>"
    script = args.script or "./supra/scripts/history_backfill.sh"
    parts: list[str] = [script, config, "import", str(lottery_id), artifacts.summary_hex, artifacts.expected_hash]
    return " ".join(parts)


def _write_optional(path: Path | None, content: str) -> None:
    if path is None:
        return
    path.write_text(content + "\n", encoding="utf-8")


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Рассчитать хэш и hex-строку BCS-сводки для history_backfill.sh",
    )
    parser.add_argument(
        "summary",
        type=Path,
        help="Путь к BCS-файлу или файлу с hex-представлением",
    )
    parser.add_argument(
        "--lottery-id",
        type=int,
        help="Идентификатор лотереи: при указании формируется подсказка команды import",
    )
    parser.add_argument(
        "--config",
        type=str,
        default=os.environ.get("SUPRA_HISTORY_BACKFILL_CONFIG"),
        help="Путь к Supra CLI config для подсказки команды",
    )
    parser.add_argument(
        "--script",
        type=str,
        default="./supra/scripts/history_backfill.sh",
        help="Путь к скрипту history_backfill.sh для подсказки команды",
    )
    parser.add_argument(
        "--hex-output",
        type=Path,
        help="Сохранить полную hex-строку в файл",
    )
    parser.add_argument(
        "--hash-output",
        type=Path,
        help="Сохранить sha3-256 хэш в файл",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Вывести только подсказку команды (для использования в скриптах)",
    )
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    summary_bytes = read_summary_bytes(args.summary)
    artifacts = compute_artifacts(summary_bytes)

    _write_optional(args.hex_output, artifacts.summary_hex)
    _write_optional(args.hash_output, artifacts.expected_hash)

    if not args.quiet:
        print(f"Summary size: {artifacts.size} bytes")
        print(f"Summary hex preview: {_format_preview(artifacts.summary_hex)}")
        wrapped_hash = "\n".join(wrap(artifacts.expected_hash, 80))
        print(f"Expected hash: {wrapped_hash}")

    command = _build_command(args, artifacts)
    if command:
        if args.quiet:
            print(command)
        else:
            print("Suggested import command:")
            print(f"  {command}")

    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
