from datetime import datetime, timezone
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from supra.tools.incident_log import IncidentEntry, update_log_text


@pytest.fixture
def base_log() -> str:
    return """# Журнал операций и инцидентов lottery_multi

| Дата/время (UTC) | Тип события | Описание | Ответственные | Ссылки |
|------------------|-------------|----------|---------------|--------|
| ____ | Релиз | | | |
| ____ | Инцидент | | | |

## Руководство по заполнению
1. Каждое событие должно содержать ссылку на PR, задачу или страницу runbook.
"""


def make_entry(ts: str, event_type: str) -> IncidentEntry:
    return IncidentEntry(
        timestamp=datetime.strptime(ts, "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc),
        event_type=event_type,
        description="Тестовое событие",
        responsible="RootAdmin",
        links="[PR](https://example.com/pr/1)",
    )


def test_append_replaces_placeholders(base_log: str) -> None:
    entry = make_entry("2025-11-30 10:15", "Релиз")
    updated = update_log_text(base_log, entry)
    assert "____" not in updated
    assert "2025-11-30 10:15" in updated
    assert updated.count("Релиз") == 1


def test_entries_sorted_descending(base_log: str) -> None:
    first = make_entry("2025-11-30 10:15", "Релиз")
    intermediate = update_log_text(base_log, first)
    second = make_entry("2025-11-29 09:00", "Инцидент")
    updated = update_log_text(intermediate, second)
    table_section = updated.split("## Руководство по заполнению")[0]
    lines = [
        line
        for line in table_section.splitlines()
        if line.startswith("|") and "----" not in line and "Дата/время" not in line
    ]
    assert lines[0].startswith("| 2025-11-30 10:15")
    assert lines[1].startswith("| 2025-11-29 09:00")


def test_preserves_following_sections(base_log: str) -> None:
    entry = make_entry("2025-11-30 10:15", "Dry-run")
    updated = update_log_text(base_log, entry)
    assert updated.endswith("1. Каждое событие должно содержать ссылку на PR, задачу или страницу runbook.\n")
