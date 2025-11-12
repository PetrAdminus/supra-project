"""Утилиты для автоматизированного ведения журнала операций lottery_multi.

Модуль предоставляет CLI, который добавляет записи в таблицу
`docs/handbook/operations/incident_log.md`, сохраняя обратный
хронологический порядок и убирая плейсхолдеры. Логика вынесена в функции,
чтобы её можно было покрыть тестами.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List

TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M"


@dataclass
class IncidentEntry:
    """Структура для новой записи журнала."""

    timestamp: datetime
    event_type: str
    description: str
    responsible: str
    links: str

    @property
    def formatted_timestamp(self) -> str:
        return self.timestamp.strftime(TIMESTAMP_FORMAT)


def _parse_timestamp(value: str) -> datetime:
    try:
        return datetime.strptime(value, TIMESTAMP_FORMAT).replace(tzinfo=timezone.utc)
    except ValueError as exc:  # pragma: no cover - передаётся в CLI
        raise argparse.ArgumentTypeError(
            f"Ожидается формат времени '{TIMESTAMP_FORMAT}', получено: {value!r}"
        ) from exc


def _split_table_cells(row: str) -> List[str]:
    parts = [cell.strip() for cell in row.strip().strip("|").split("|")]
    return [cell.replace("\\|", "|") for cell in parts]


def _join_table_cells(cells: Iterable[str]) -> str:
    encoded = [cell.replace("|", "\\|") for cell in cells]
    return "| " + " | ".join(encoded) + " |"


def _extract_existing_entries(lines: List[str], table_start: int) -> List[IncidentEntry]:
    entries: List[IncidentEntry] = []
    idx = table_start + 2  # пропускаем заголовок и строку-разделитель
    while idx < len(lines):
        line = lines[idx].rstrip()
        if not line.startswith("|"):
            break
        cells = _split_table_cells(line)
        if len(cells) != 5:
            break
        timestamp_raw = cells[0]
        if timestamp_raw == "____" or not timestamp_raw:
            idx += 1
            continue
        timestamp = datetime.strptime(timestamp_raw, TIMESTAMP_FORMAT).replace(tzinfo=timezone.utc)
        entries.append(
            IncidentEntry(
                timestamp=timestamp,
                event_type=cells[1],
                description=cells[2],
                responsible=cells[3],
                links=cells[4],
            )
        )
        idx += 1
    return entries


def update_log_text(content: str, entry: IncidentEntry) -> str:
    """Добавляет запись в markdown-таблицу и возвращает обновлённый текст."""

    lines = content.splitlines()
    table_start = -1
    for idx, line in enumerate(lines):
        if line.startswith("| Дата/время (UTC)"):
            table_start = idx
            break
    if table_start == -1:
        raise ValueError("В файле не найдена таблица журнала инцидентов")

    existing_entries = _extract_existing_entries(lines, table_start)
    existing_entries.append(entry)
    existing_entries.sort(key=lambda item: item.timestamp, reverse=True)

    header = lines[: table_start + 2]
    footer = lines[table_start + 2 :]

    # Удаляем старые строки таблицы (до первой строки, не начинающейся с |)
    while footer and footer[0].startswith("|"):
        footer.pop(0)

    table_lines = [_join_table_cells(
        [
            item.formatted_timestamp,
            item.event_type,
            item.description,
            item.responsible,
            item.links,
        ]
    ) for item in existing_entries]

    new_lines = header + table_lines + footer
    return "\n".join(new_lines) + "\n"


def write_entry(path: Path, entry: IncidentEntry) -> str:
    content = path.read_text(encoding="utf-8")
    updated = update_log_text(content, entry)
    path.write_text(updated, encoding="utf-8")
    return updated


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Добавить запись в журнал операций lottery_multi"
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=Path("docs/handbook/operations/incident_log.md"),
        help="Путь к файлу журнала (по умолчанию operations/incident_log.md)",
    )
    parser.add_argument(
        "--timestamp",
        type=_parse_timestamp,
        default=datetime.now(tz=timezone.utc).replace(second=0, microsecond=0),
        help=f"Метка времени в UTC в формате '{TIMESTAMP_FORMAT}' (по умолчанию текущее время)",
    )
    parser.add_argument("--type", required=True, help="Тип события (Релиз, Инцидент, Dry-run и т.д.)")
    parser.add_argument("--description", required=True, help="Краткое описание события")
    parser.add_argument(
        "--responsible",
        required=True,
        help="Ответственные за операцию/реакцию",
    )
    parser.add_argument(
        "--links",
        required=True,
        help="Связанные ссылки (PR, задачи, дашборды)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Не записывать изменения, вывести обновлённую таблицу",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    entry = IncidentEntry(
        timestamp=args.timestamp,
        event_type=args.type,
        description=args.description,
        responsible=args.responsible,
        links=args.links,
    )

    if args.dry_run:
        content = args.log.read_text(encoding="utf-8")
        updated = update_log_text(content, entry)
        print(updated, end="")
    else:
        write_entry(args.log, entry)


if __name__ == "__main__":  # pragma: no cover
    main()
