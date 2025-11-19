"""Unit-тесты для инструмента проверки карты миграции."""
from importlib import util
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[2] / "docs/architecture/tools/check_migration_mapping.py"
spec = util.spec_from_file_location("check_migration_mapping", MODULE_PATH)
check_migration_mapping = util.module_from_spec(spec)
assert spec and spec.loader  # for mypy
spec.loader.exec_module(check_migration_mapping)


def test_parse_and_compare_summaries_consistent():
    lines = [
        "## 2. Сводка статусов",
        "- **1** ресурс со статусом `Готово` — пример",
        "- **2** ресурса в статусе `В работе` — пример",
        "- **0** ресурсов помечено как `Запланировано`.",
        "- **1** ресурс отмечен как `Не требуется`.",
        "",
        "| Старый модуль | Ресурс | Ключевые поля / назначение | Целевой пакет | Целевой модуль / сущность | Действия миграции | Статус | Комментарии и зависимости |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
        "| core | ResA | f | lottery_data | module | steps | Готово | note |",
        "| core | ResB | f | lottery_engine | module | steps | В работе | note |",
        "| core | ResC | f | lottery_data | module | steps | В работе | note |",
        "| core | ResD | f | unknown_pkg | module | steps | Не требуется | note |",
    ]

    rows = check_migration_mapping.parse_rows(lines)
    assert len(rows) == 4

    status_summary = check_migration_mapping.summarize_statuses(rows)
    assert status_summary["Готово"] == 1
    assert status_summary["В работе"] == 2
    assert status_summary["Не требуется"] == 1

    documented_summary = check_migration_mapping.parse_status_summary(lines)
    assert documented_summary == status_summary

    mismatches = check_migration_mapping.compare_status_summaries(documented_summary, status_summary)
    assert mismatches == []

    missing_packages = check_migration_mapping.collect_missing_packages(rows, ["lottery_data", "lottery_engine"])
    assert missing_packages == {"unknown_pkg": [lines[11]]}
