"""Helper to run Move tests or checks via Supra CLI with graceful fallbacks.

The Supra alignment plan (этап F2) требует автоматизировать запуск
`supra move tool test` для рабочей области `supra/move_workspace`.  В
разработческой среде Supra CLI может отсутствовать, поэтому модуль
предоставляет последовательность запасных вариантов:

1. Попытаться запустить `supra move tool <mode> --package-dir <package>`.
2. Если Supra CLI недоступен, использовать `aptos move <mode>`.
3. В крайнем случае попробовать «ванильный» Move CLI (`move <mode>`).

Модуль интегрируется в общий Supra CLI (`python -m supra.scripts.cli
move-test`) и принимает аргументы для выбора рабочего каталога,
конкретного пакета и дополнительных параметров, пробрасываемых в
подлежащую команду.
"""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
import json
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


# Путь по умолчанию: SupraLottery/supra/move_workspace
DEFAULT_WORKSPACE = Path(__file__).resolve().parent.parent / "move_workspace"


class MoveCliNotFoundError(RuntimeError):
    """Выбрасывается, если не удалось найти ни одной Move CLI."""


def _classify_cli(executable: str) -> str:
    """Определяет flavour CLI (supra / aptos / move) по имени файла."""

    name = Path(executable).name.lower()
    if "supra" in name:
        return "supra"
    if "aptos" in name:
        return "aptos"
    return "move"


def _iter_candidate_cli(preferred: str | None) -> Iterable[str]:
    """Возвращает кандидатов CLI, начиная с предпочитаемого."""

    if preferred:
        yield preferred
        return

    for candidate in ("supra", "aptos", "move"):
        yield candidate


def _resolve_cli(preferred: str | None) -> Tuple[str, str]:
    """Находит доступный CLI и возвращает `(path, flavour)`.

    :raises MoveCliNotFoundError: если ничего не найдено.
    """

    for candidate in _iter_candidate_cli(preferred):
        path = shutil.which(candidate) if os.path.sep not in candidate else candidate
        if path and Path(path).exists():
            flavour = _classify_cli(path)
            return path, flavour

    raise MoveCliNotFoundError(
        "Не удалось найти Supra CLI (`supra`), Aptos CLI (`aptos`) или Move CLI (`move`). "
        "Установите Supra CLI или укажите путь через --cli."
    )


def _build_command(
    cli_path: str,
    flavour: str,
    workspace: Path,
    package_name: str | None,
    action: str,
    extra_args: Sequence[str],
) -> List[str]:
    """Формирует итоговую команду для запуска тестов или проверок."""

    workspace_path = workspace.resolve()
    package_dir = workspace_path if package_name is None else workspace_path / package_name

    if flavour == "supra":
        base_cmd = [
            cli_path,
            "move",
            "tool",
            action,
            "--package-dir",
            str(package_dir),
        ]
    elif flavour == "aptos":
        base_cmd = [
            cli_path,
            "move",
            action,
            "--package-dir",
            str(package_dir),
        ]
    else:
        if action == "test":
            base_cmd = [
                cli_path,
                action,
                "--package-path",
                str(workspace_path),
            ]
            if package_name:
                base_cmd.extend(["--package", package_name])
        else:
            # Vanilla Move CLI использует `move check --package-path <dir>` без `--package`.
            target = package_dir if package_name else workspace_path
            base_cmd = [
                cli_path,
                action,
                "--package-path",
                str(target),
            ]

    return [*base_cmd, *extra_args]


def discover_packages(workspace: Path) -> List[str]:
    """Возвращает отсортированный список пакетов внутри workspace."""

    packages: List[str] = []
    for entry in workspace.iterdir():
        if not entry.is_dir():
            continue
        if (entry / "Move.toml").exists():
            packages.append(entry.name)

    return sorted(packages, key=str.lower)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Запустить Move-тесты SupraLottery через Supra/Aptos/Move CLI",
    )
    parser.add_argument(
        "--workspace",
        default=str(DEFAULT_WORKSPACE),
        help="путь к Move workspace (по умолчанию supra/move_workspace)",
    )
    parser.add_argument(
        "--package",
        help="подкаталог пакета внутри workspace (например, lottery)",
    )
    parser.add_argument(
        "--mode",
        choices=("test", "check"),
        default="test",
        help="тип операции Move CLI: test (по умолчанию) или check",
    )
    parser.add_argument(
        "--all-packages",
        action="store_true",
        help="последовательно прогнать тесты для всех пакетов workspace",
    )
    parser.add_argument(
        "--list-packages",
        action="store_true",
        help="вывести список доступных пакетов и завершиться",
    )
    parser.add_argument(
        "--cli",
        help="путь к предпочтительной CLI (supra, aptos или move)",
    )
    parser.add_argument(
        "--cli-flavour",
        choices=("supra", "aptos", "move"),
        help="подсказать flavour CLI при --dry-run, если бинарь недоступен",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="только вывести команду без запуска",
    )
    parser.add_argument(
        "--report-json",
        help="сохранить результаты выполнения в JSON-файл (подходит для CI-логов)",
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="не останавливать прогон после первого провала (возвращает код первого провала)",
    )
    parser.add_argument(
        "--report-junit",
        help="сохранить результаты выполнения в JUnit XML (для интеграции с CI)",
    )
    parser.add_argument(
        "extra",
        nargs=argparse.REMAINDER,
        help="дополнительные аргументы, передаваемые CLI (начните с --)",
    )
    return parser


def _normalize_extra(extra: Sequence[str] | None) -> List[str]:
    if not extra:
        return []
    if extra and extra[0] == "--":
        return list(extra[1:])
    return list(extra)


def run(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    workspace = Path(args.workspace).expanduser().resolve()
    if not workspace.exists():
        raise SystemExit(f"Workspace {workspace} не найден")

    if args.list_packages:
        packages = discover_packages(workspace)
        for name in packages:
            print(name)
        return 0

    if args.all_packages and args.package:
        parser.error("Нельзя одновременно использовать --package и --all-packages")

    packages_to_run: List[str | None]
    if args.all_packages:
        packages = discover_packages(workspace)
        if not packages:
            raise SystemExit("В workspace не найдено ни одного пакета с Move.toml")
        packages_to_run = packages
    elif args.package:
        packages_to_run = [args.package]
    else:
        packages_to_run = [None]

    try:
        cli_path, flavour = _resolve_cli(args.cli)
    except MoveCliNotFoundError:
        if not args.dry_run:
            raise

        assumed_flavour = args.cli_flavour
        if not assumed_flavour:
            if args.cli:
                assumed_flavour = _classify_cli(args.cli)
            else:
                assumed_flavour = "supra"

        cli_path = args.cli or assumed_flavour
        flavour = assumed_flavour
        print(
            "[move-test] Предупреждение: CLI не найден, dry-run использует flavour"
            f" `{flavour}`",
            file=sys.stderr,
        )
    extra_args = _normalize_extra(args.extra)
    last_return_code = 0
    first_failure_code = 0
    results: List[dict[str, object]] = []

    action = args.mode

    for package_name in packages_to_run:
        package_dir = workspace if package_name is None else workspace / package_name

        if not package_dir.exists():
            raise SystemExit(f"Пакет {package_dir} не существует")
        if package_name and not (package_dir / "Move.toml").exists():
            raise SystemExit(f"Пакет {package_name} не содержит Move.toml")

        command = _build_command(
            cli_path,
            flavour,
            workspace.resolve(),
            package_name,
            action,
            extra_args,
        )
        quoted = " ".join(shlex.quote(part) for part in command)
        package_label = package_name or "workspace"
        print(
            f"[move-test] Используем CLI `{Path(cli_path).name}` ({flavour}) — пакет {package_label}: {quoted}"
        )

        result_entry = {
            "package": package_label,
            "command": command,
            "flavour": flavour,
            "cli": cli_path,
        }

        if args.dry_run:
            result_entry.update({"status": "skipped", "return_code": None, "duration_seconds": 0.0})
            results.append(result_entry)
            continue

        started_at = time.time()
        completed = subprocess.run(command, check=False)
        duration = time.time() - started_at
        last_return_code = completed.returncode
        status = "passed" if last_return_code == 0 else "failed"
        if status == "failed" and first_failure_code == 0:
            first_failure_code = last_return_code
        result_entry.update({"status": status, "return_code": last_return_code, "duration_seconds": duration})
        results.append(result_entry)
        if last_return_code != 0 and not args.keep_going:
            break

    if args.report_json:
        report_path = Path(args.report_json).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "workspace": str(workspace),
            "cli_path": cli_path,
            "cli_flavour": flavour,
            "results": results,
        }
        report_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2))

    if args.report_junit:
        report_path = Path(args.report_junit).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        _write_junit_report(report_path, workspace, cli_path, flavour, results)

    if first_failure_code:
        return first_failure_code
    return last_return_code


def _write_junit_report(
    report_path: Path,
    workspace: Path,
    cli_path: str,
    flavour: str,
    results: Sequence[dict[str, object]],
) -> None:
    """Сохраняет результаты запуска в формате JUnit XML."""

    total_duration = sum(float(entry.get("duration_seconds", 0.0) or 0.0) for entry in results)
    failures = sum(1 for entry in results if entry.get("status") == "failed")
    skipped = sum(1 for entry in results if entry.get("status") == "skipped")

    suite = ET.Element(
        "testsuite",
        attrib={
            "name": "move-test",
            "tests": str(len(results)),
            "failures": str(failures),
            "skipped": str(skipped),
            "time": f"{total_duration:.6f}",
        },
    )

    properties = ET.SubElement(suite, "properties")
    ET.SubElement(properties, "property", name="workspace", value=str(workspace))
    ET.SubElement(properties, "property", name="cli_path", value=str(cli_path))
    ET.SubElement(properties, "property", name="cli_flavour", value=str(flavour))

    for entry in results:
        duration = float(entry.get("duration_seconds", 0.0) or 0.0)
        testcase = ET.SubElement(
            suite,
            "testcase",
            attrib={
                "classname": "move",
                "name": str(entry.get("package")),
                "time": f"{duration:.6f}",
            },
        )

        status = entry.get("status")
        if status == "failed":
            return_code = entry.get("return_code")
            message = f"Return code {return_code}" if return_code is not None else "Failure"
            failure = ET.SubElement(testcase, "failure", message=message)
            command = entry.get("command")
            if isinstance(command, (list, tuple)):
                command_str = " ".join(shlex.quote(str(part)) for part in command)
                failure.text = f"Команда: {command_str}"
        elif status == "skipped":
            ET.SubElement(testcase, "skipped")

    tree = ET.ElementTree(suite)
    tree.write(report_path, encoding="utf-8", xml_declaration=True)


def main() -> None:
    try:
        exit_code = run()
    except MoveCliNotFoundError as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        sys.exit(2)
    except SystemExit as exc:
        # Пробрасываем exit код, но убеждаемся, что CLI-контейнер корректно завершается.
        raise exc
    except Exception as exc:  # pragma: no cover - непредвиденная ошибка
        print(f"Непредвиденная ошибка: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
