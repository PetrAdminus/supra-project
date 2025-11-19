#!/usr/bin/env python3
"""Проверяет таблицу миграции и формирует сводку статусов."""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

ALLOWED_STATUSES = {"Запланировано", "В работе", "Готово", "Не требуется"}
STATUS_COLUMN_INDEX = 6  # колонка «Статус» в markdown-таблице после split("|")
TARGET_PACKAGE_COLUMN_INDEX = 3


def _is_separator_row(cells: Sequence[str]) -> bool:
    return all(not cell or set(cell) <= {"-"} for cell in cells)


def parse_rows(lines: Iterable[str]) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for raw_line in lines:
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) <= STATUS_COLUMN_INDEX:
            continue
        if _is_separator_row(cells):
            continue
        first_cell = cells[0].lower()
        if first_cell.startswith("старый модуль") or first_cell.startswith("старый пакет"):
            continue
        if cells[STATUS_COLUMN_INDEX].lower() == "статус":
            continue
        status = cells[STATUS_COLUMN_INDEX]
        target_package = cells[TARGET_PACKAGE_COLUMN_INDEX] if len(cells) > TARGET_PACKAGE_COLUMN_INDEX else ""
        rows.append({"status": status, "target_package": target_package, "raw": raw_line.rstrip("\n")})
    return rows


def summarize_statuses(rows: Sequence[Dict[str, str]]) -> Counter:
    counter: Counter = Counter()
    for row in rows:
        status = row.get("status", "")
        counter[status] += 1
    return counter


def parse_status_summary(lines: Iterable[str]) -> Counter:
    """Извлекает сводку статусов из буллетов раздела «Сводка статусов».

    Ожидаемый формат строк: `- **N** ... `STATUS``.
    Возвращает Counter с количеством по статусу.
    """

    pattern = re.compile(r"^-\s*\*\*(?P<count>\d+)\*\*[^`]+`(?P<status>[^`]+)`", re.I)
    summary: Counter = Counter()

    for line in lines:
        match = pattern.search(line.strip())
        if not match:
            continue
        status = match.group("status").strip()
        count = int(match.group("count"))
        summary[status] += count

    return summary


def compare_status_summaries(documented: Counter, actual: Counter) -> List[str]:
    messages: List[str] = []
    all_statuses = set(documented) | set(actual)
    for status in sorted(all_statuses):
        documented_value = documented.get(status, 0)
        actual_value = actual.get(status, 0)
        if documented_value != actual_value:
            messages.append(
                f"Статус `{status}`: в документе {documented_value}, по таблице {actual_value}"
            )
    return messages


def collect_missing_packages(rows: Sequence[Dict[str, str]], available_packages: Sequence[str]) -> Dict[str, List[str]]:
    if not available_packages:
        return {}
    available = set(available_packages)
    missing: Dict[str, List[str]] = defaultdict(list)
    for row in rows:
        target = row.get("target_package", "")
        if not target:
            continue
        for pkg in {part.strip().strip("`") for part in target.split("/") if part.strip()}:
            if not pkg or pkg == "—" or pkg.lower().startswith("целевой пакет"):
                continue
            if pkg not in available:
                missing[pkg].append(row["raw"])
    return missing


def load_inventory_packages(path: Path) -> List[str]:
    data = json.loads(path.read_text())
    packages = data.get("packages", [])
    names: List[str] = []
    for pkg in packages:
        name = pkg.get("package")
        if isinstance(name, str):
            names.append(name)
    return names


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mapping-path",
        type=Path,
        default=Path("docs/architecture/move_migration_mapping.md"),
        help="Путь к markdown-файлу с таблицей миграции.",
    )
    parser.add_argument(
        "--inventory-json",
        type=Path,
        help="Необязательный путь к JSON-инвентаризации Move (из export_move_inventory.py) для сверки целевых пакетов.",
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        help="Необязательный путь к JSON-файлу со сводкой статусов и предупреждениями.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Возвращать код выхода 1 при наличии предупреждений (неизвестные статусы, отсутствующие пакеты, расхождение сводок).",
    )
    args = parser.parse_args()

    mapping_text = args.mapping_path.read_text().splitlines()
    rows = parse_rows(mapping_text)

    status_summary = summarize_statuses(rows)

    invalid_status_rows = [row for row in rows if row["status"] and row["status"] not in ALLOWED_STATUSES]

    missing_packages: Dict[str, List[str]] = {}
    inventory_packages: List[str] = []
    if args.inventory_json:
        inventory_packages = load_inventory_packages(args.inventory_json)
        missing_packages = collect_missing_packages(rows, inventory_packages)

    documented_summary = parse_status_summary(mapping_text)
    summary_mismatches = compare_status_summaries(documented_summary, status_summary)

    print("Итоговая сводка статусов:")
    for status in sorted(status_summary.keys()):
        print(f"- {status or '⟂ пусто'}: {status_summary[status]}")
    total_rows = sum(status_summary.values())
    print(f"Всего строк таблицы: {total_rows}")

    if documented_summary:
        print("\nСводка в документе:")
        for status in sorted(documented_summary.keys()):
            print(f"- {status or '⟂ пусто'}: {documented_summary[status]}")
    else:
        print("\n⚠️ Не удалось найти сводку статусов в документе")

    if invalid_status_rows:
        print("\n⚠️ Неизвестные статусы (нужно поправить таблицу):")
        for row in invalid_status_rows:
            print(f"- {row['status']}: {row['raw']}")

    if summary_mismatches:
        print("\n⚠️ Сводка статусов не совпадает с таблицей:")
        for msg in summary_mismatches:
            print(f"- {msg}")

    if args.inventory_json:
        print("\nСверка с инвентаризацией пакетов:")
        if not inventory_packages:
            print("- ⚠️ не удалось прочитать список пакетов из JSON")
        elif missing_packages:
            print("- ⚠️ найденные отсутствующие пакеты:")
            for pkg, occurrences in sorted(missing_packages.items()):
                print(f"  - {pkg}: {len(occurrences)} строк")
        else:
            print("- ✅ все целевые пакеты найдены в JSON-инвентаризации")

    if args.json_output:
        args.json_output.write_text(
            json.dumps(
                {
                    "mapping_path": str(args.mapping_path),
                    "status_summary": status_summary,
                    "invalid_status_rows": invalid_status_rows,
                    "inventory_packages": inventory_packages,
                    "missing_packages": missing_packages,
                    "documented_summary": documented_summary,
                    "summary_mismatches": summary_mismatches,
                },
                indent=2,
                ensure_ascii=True,
            )
            + "\n"
        )

    has_warnings = bool(invalid_status_rows or missing_packages or summary_mismatches)
    if has_warnings and args.strict:
        sys.exit(1)


if __name__ == "__main__":
    main()
