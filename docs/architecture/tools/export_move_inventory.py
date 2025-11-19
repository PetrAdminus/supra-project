#!/usr/bin/env python3
"""Экспорт структур Move в markdown-отчёт."""
from __future__ import annotations

import argparse
import datetime
import json
import re
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

STRUCT_PATTERN = re.compile(
    r"(?P<attrs>(?:#\[[^\]]+\]\s*)*)struct\s+(?P<name>[A-Za-z0-9_]+(?:\s*<[^>]+>)?)\s+has\s+(?P<abilities>[^{}]+?)\{(?P<body>[^{}]*)\}",
    re.S,
)

COMMENT_BLOCK = re.compile(r"/\*.*?\*/", re.S)
COMMENT_LINE = re.compile(r"//.*")


def strip_comments(text: str) -> str:
    text = COMMENT_BLOCK.sub("", text)
    return "\n".join(COMMENT_LINE.sub("", line) for line in text.splitlines())


def split_fields(body: str) -> Sequence[str]:
    parts: List[str] = []
    current: List[str] = []
    depth: int = 0
    bracket_pairs = {"<": ">", "(": ")", "[": "]", "{": "}"}
    closing = {v: k for k, v in bracket_pairs.items()}

    for char in body:
        if char == "," and depth == 0:
            part = "".join(current).strip()
            if part:
                parts.append(part)
            current = []
            continue

        current.append(char)

        if char in bracket_pairs:
            depth += 1
        elif char in closing and depth > 0:
            depth -= 1

    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def iter_structs(text: str) -> Iterable[Tuple[str, str, str, List[Tuple[str, str]]]]:
    for match in STRUCT_PATTERN.finditer(text):
        attrs = match.group("attrs") or ""
        name = " ".join(match.group("name").split())
        abilities = ", ".join(part.strip() for part in match.group("abilities").split(",") if part.strip())
        body = match.group("body").strip()
        fields: List[Tuple[str, str]] = []
        if body:
            for part in split_fields(body):
                if ":" in part:
                    field_name, field_type = part.split(":", 1)
                    fields.append((field_name.strip(), " ".join(field_type.split())))
        yield attrs.lower(), name, abilities, fields


def format_table(entries: List[Tuple[str, str, str, str]]) -> List[str]:
    if not entries:
        return ["> В этом модуле структур с `struct ... has ...` не найдено.", ""]
    lines = ["| Категория | Структура | Способности | Поля |", "| --- | --- | --- | --- |"]
    for category, name, abilities, field_repr in entries:
        lines.append(f"| {category} | `{name}` | {abilities or '—'} | {field_repr} |")
    lines.append("")
    return lines


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workspace-root",
        default=Path("SupraLottery/supra/move_workspace"),
        type=Path,
        help="Корень Move-workspace SupraLottery.",
    )
    parser.add_argument(
        "--output",
        default=Path("docs/architecture/move_struct_inventory.md"),
        type=Path,
        help="Путь к markdown-файлу с итоговой инвентаризацией.",
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        default=None,
        help="Необязательный путь к JSON-файлу со структурированным инвентаризационным отчётом.",
    )
    args = parser.parse_args()

    root = args.workspace_root
    packages = sorted(p for p in root.iterdir() if (p / "sources").is_dir())

    now_utc = datetime.datetime.now(datetime.timezone.utc)

    output_lines: List[str] = [
        "# Инвентаризация структур Move",
        "",
        f"> Последнее обновление: {now_utc.date()} (UTC)",
        "",
        "Документ автоматически собирает все структуры, ресурсы и события из текущего Move-workspace SupraLottery. "
        "Данные используются как исходная точка для планирования миграции в новую архитектуру.",
        "",
        "**Как читать документ:** разделы разбиты по пакетам и модулям. Для каждой структуры указаны способности (`has …`) "
        "и ключевые поля. Категория помогает быстро отличить ресурсы (`Ресурс`), события (`Событие`) и вспомогательные структуры (`Структура`).",
        "",
        "**Как обновлять:** запустите `python docs/architecture/tools/export_move_inventory.py` из корня репозитория. "
        "При необходимости можно указать иные пути через аргументы `--workspace-root` и `--output`.",
        "",
    ]

    inventory: List[dict] = []

    for pkg in packages:
        pkg_entry = {"package": pkg.name, "modules": []}
        output_lines.append(f"## Пакет `{pkg.name}`")
        output_lines.append("")
        for source in sorted((pkg / "sources").glob("*.move")):
            text = strip_comments(source.read_text())
            module_match = re.search(r"module\s+([^\s\{]+)\s*\{", text)
            module_name = module_match.group(1) if module_match else f"{pkg.name}::<unknown>"
            output_lines.append(f"### Модуль `{module_name}` (`{source.as_posix()}`)")
            output_lines.append("")

            rows: List[Tuple[str, str, str, str]] = []
            module_structs: List[dict] = []
            for attrs, name, abilities, fields in iter_structs(text):
                ability_tokens = {token.strip() for token in abilities.split(",") if token.strip()}
                if "event" in attrs:
                    category = "Событие"
                elif "key" in ability_tokens:
                    category = "Ресурс"
                else:
                    category = "Структура"
                field_repr = "—" if not fields else "<br>".join(f"`{fname}`: {ftype}" for fname, ftype in fields)
                rows.append((category, name, abilities, field_repr))
                module_structs.append(
                    {
                        "category": category,
                        "name": name,
                        "abilities": sorted(ability_tokens),
                        "fields": [{"name": fname, "type": ftype} for fname, ftype in fields],
                        "attributes": attrs.strip().split(),
                    }
                )
            output_lines.extend(format_table(rows))
            pkg_entry["modules"].append(
                {
                    "name": module_name,
                    "source": source.as_posix(),
                    "structs": module_structs,
                }
            )
        output_lines.append("")
        inventory.append(pkg_entry)

    args.output.write_text("\n".join(output_lines) + "\n")

    if args.json_output:
        json_payload = {
            "generated_at": now_utc.isoformat(),
            "workspace_root": str(root),
            "packages": inventory,
        }
        args.json_output.write_text(json.dumps(json_payload, indent=2, ensure_ascii=True) + "\n")


if __name__ == "__main__":
    main()
