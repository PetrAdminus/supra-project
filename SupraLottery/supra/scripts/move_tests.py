"""Helper to run Move tests or checks via Supra or vanilla Move CLI.

The migration runbook requires automated execution of
`supra move tool test` for the workspace `supra/move_workspace`.  When the
Supra CLI binary is unavailable in a developer environment, the helper offers
graceful fallbacks:

1. Try running `supra move tool <mode> --package-dir <package>`.
2. As a last resort, use the plain Move CLI (`move <mode>`).

The module integrates with the main Supra CLI entry point
(`python -m supra.scripts.cli move-test`) and accepts arguments that control
the workspace path, target package, and extra parameters forwarded to the
underlying command.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence, Tuple, TextIO

if sys.version_info >= (3, 11):
    import tomllib
else:  # pragma: no cover - Python <3.11 fallback
    import tomli as tomllib  # type: ignore[import-not-found]


DEFAULT_JSON_REPORT = Path("tmp/move-test-report.json")
DEFAULT_JUNIT_REPORT = Path("tmp/move-test-report.xml")
DEFAULT_LOG_PATH = Path("tmp/unittest.log")


# Default workspace path: SupraLottery/supra/move_workspace
DEFAULT_WORKSPACE = Path(__file__).resolve().parent.parent / "move_workspace"


class MoveCliNotFoundError(RuntimeError):
    """Raised when no Move CLI binary can be located."""


def _classify_cli(executable: str) -> str:
    """Classifies CLI flavour (supra / move) by executable name."""

    name = Path(executable).name.lower()
    if "supra" in name:
        return "supra"
    if "aptos" in name:
        return "aptos"
    return "move"


def _iter_candidate_cli(preferred: str | None) -> Iterable[str]:
    """Yields CLI candidates, starting with the preferred one if provided."""

    if preferred:
        yield preferred
        return

    for candidate in ("supra", "aptos", "move"):
        yield candidate


def _resolve_cli(preferred: str | None) -> Tuple[str, str]:
    """Resolves an available CLI and returns ``(path, flavour)``.

    :raises MoveCliNotFoundError: when no CLI binary is available.
    """

    for candidate in _iter_candidate_cli(preferred):
        path = shutil.which(candidate) if os.path.sep not in candidate else candidate
        if path and Path(path).exists():
            flavour = _classify_cli(path)
            return path, flavour

    raise MoveCliNotFoundError(
        "Could not find Supra CLI (`supra`) or Move CLI (`move`). "
        "Install Supra CLI or pass an explicit path via --cli."
    )


def _build_command(
    cli_path: str,
    flavour: str,
    workspace: Path,
    package_name: str | None,
    action: str,
    extra_args: Sequence[str],
    named_address_args: Sequence[str],
) -> List[str]:
    """Constructs the final command to run tests or checks."""

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
        target = package_dir if package_name else workspace_path
        aptos_action = "compile" if action == "check" else action
        base_cmd = [
            cli_path,
            "move",
            aptos_action,
            "--package-dir",
            str(target),
            "--skip-fetch-latest-git-deps",
        ]
    else:
        # Vanilla Move CLI expects `--package-dir` that points to the package root.
        target = package_dir if package_name else workspace_path
        base_cmd = [
            cli_path,
            action,
            "--package-dir",
            str(target),
        ]

    return [*base_cmd, *named_address_args, *extra_args]


def _resolve_move_config_path(workspace: Path, explicit: str | None) -> Path | None:
    """Returns the resolved path to `.move/config` (if any)."""

    if explicit:
        candidate = Path(explicit).expanduser()
        if candidate.is_dir():
            candidate = candidate / "config"
        if not candidate.exists():
            raise SystemExit(f"Move config {candidate} was not found")
        return candidate.resolve()

    for base in (workspace, *workspace.parents):
        candidate = base / ".move" / "config"
        if candidate.exists():
            return candidate.resolve()
    return None


def _load_named_addresses(config_path: Path) -> Dict[str, str]:
    """Parses `[addresses]` from `.move/config`."""

    with config_path.open("rb") as stream:
        data = tomllib.load(stream)

    raw_addresses = data.get("addresses", {})
    if not isinstance(raw_addresses, dict):
        return {}

    addresses: Dict[str, str] = {}
    for key, value in raw_addresses.items():
        name = str(key)
        addresses[name] = str(value)
    return addresses


def _format_named_addresses(addresses: Mapping[str, str]) -> str:
    """Formats named addresses for CLI consumption."""

    return ",".join(f"{name}={value}" for name, value in sorted(addresses.items()))


def _has_named_addresses(extra_args: Sequence[str]) -> bool:
    """Checks whether `--named-addresses` is already provided."""

    for arg in extra_args:
        if arg == "--named-addresses" or arg.startswith("--named-addresses"):
            return True
    return False


def discover_packages(workspace: Path) -> List[str]:
    """Returns a sorted list of packages within the workspace."""

    packages: List[str] = []
    for entry in workspace.iterdir():
        if not entry.is_dir():
            continue
        if (entry / "Move.toml").exists():
            packages.append(entry.name)

    return sorted(packages, key=str.lower)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run SupraLottery Move tests via Supra or Move CLI",
    )
    parser.add_argument(
        "--workspace",
        default=str(DEFAULT_WORKSPACE),
        help="path to the Move workspace (defaults to supra/move_workspace)",
    )
    parser.add_argument(
        "--package",
        help="package subdirectory inside the workspace (for example, lottery)",
    )
    parser.add_argument(
        "--mode",
        choices=("test", "check"),
        default="test",
        help="Move CLI action: test (default) or check",
    )
    parser.add_argument(
        "--all-packages",
        action="store_true",
        help="run the command sequentially for every package in the workspace",
    )
    parser.add_argument(
        "--list-packages",
        action="store_true",
        help="print the list of available packages and exit",
    )
    parser.add_argument(
        "--cli",
        help="path to the preferred CLI binary (supra or move)",
    )
    parser.add_argument(
        "--cli-flavour",
        choices=("supra", "aptos", "move"),
        help="explicit CLI flavour hint when --dry-run is used without a binary",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the command without executing it",
    )
    parser.add_argument(
        "--report-json",
        default=str(DEFAULT_JSON_REPORT),
        help=(
            "save execution results to a JSON file (defaults to tmp/move-test-report.json); "
            "use '-' to disable"
        ),
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="do not stop after the first failure (propagates the first failing exit code)",
    )
    parser.add_argument(
        "--report-junit",
        default=str(DEFAULT_JUNIT_REPORT),
        help=(
            "save execution results to JUnit XML (defaults to tmp/move-test-report.xml); "
            "use '-' to disable"
        ),
    )
    parser.add_argument(
        "--report-log",
        default=str(DEFAULT_LOG_PATH),
        help=(
            "store combined CLI stdout/stderr in a log (defaults to tmp/unittest.log); "
            "use '-' to disable"
        ),
    )
    parser.add_argument(
        "--move-config",
        help="path to .move/config file (auto-discovered when omitted)",
    )
    parser.add_argument(
        "--no-auto-named-addresses",
        action="store_true",
        help="disable automatic --named-addresses injection from .move/config",
    )
    parser.add_argument(
        "extra",
        nargs=argparse.REMAINDER,
        help="additional arguments forwarded to the CLI (start with --)",
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
        raise SystemExit(f"Workspace {workspace} was not found")

    if args.list_packages:
        packages = discover_packages(workspace)
        for name in packages:
            print(name)
        return 0

    if args.all_packages and args.package:
        parser.error("Cannot combine --package and --all-packages")

    packages_to_run: List[str | None]
    if args.all_packages:
        packages = discover_packages(workspace)
        if not packages:
            raise SystemExit("No packages with Move.toml were found in the workspace")
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
            "[move-test] Warning: CLI was not found, dry-run relies on flavour"
            f" `{flavour}`",
            file=sys.stderr,
        )
    extra_args = _normalize_extra(args.extra)
    config_path = None
    named_address_args: List[str] = []
    named_address_assignments: str | None = None
    if not args.no_auto_named_addresses:
        config_path = _resolve_move_config_path(workspace, args.move_config)
        if config_path is None and args.move_config:
            raise SystemExit(f"Move config {args.move_config} was not found")
        if config_path is not None and not _has_named_addresses(extra_args):
            addresses = _load_named_addresses(config_path)
            if addresses:
                named_address_assignments = _format_named_addresses(addresses)
                named_address_args = ["--named-addresses", named_address_assignments]

    json_report_path = _prepare_report_target(args.report_json)
    junit_report_path = _prepare_report_target(args.report_junit)
    log_path = _prepare_report_target(args.report_log)
    log_stream = log_path.open("w", encoding="utf-8") if log_path else None
    if log_stream is not None:
        log_stream.write("[move-test] Session start\n")
        log_stream.flush()
        if named_address_assignments:
            log_stream.write(
                f"[move-test] Injecting named addresses from {config_path}: {named_address_assignments}\n"
            )
            log_stream.flush()
    if named_address_assignments:
        print(
            f"[move-test] Injecting named addresses from {config_path}: {named_address_assignments}"
        )
    last_return_code = 0
    first_failure_code = 0
    results: List[dict[str, object]] = []

    action = args.mode

    try:
        for package_name in packages_to_run:
            package_dir = workspace if package_name is None else workspace / package_name

            if not package_dir.exists():
                raise SystemExit(f"Package {package_dir} does not exist")
            if package_name and not (package_dir / "Move.toml").exists():
                raise SystemExit(f"Package {package_name} does not contain Move.toml")

            command = _build_command(
                cli_path,
                flavour,
                workspace.resolve(),
                package_name,
                action,
                extra_args,
                named_address_args,
            )
            quoted = " ".join(shlex.quote(part) for part in command)
            package_label = package_name or "workspace"
            print(
                f"[move-test] Using CLI `{Path(cli_path).name}` ({flavour}) - package {package_label}: {quoted}"
            )

            result_entry = {
                "package": package_label,
                "command": command,
                "flavour": flavour,
                "cli": cli_path,
            }
            if named_address_assignments:
                result_entry["named_addresses"] = named_address_assignments

            if args.dry_run:
                if log_stream is not None:
                    log_stream.write(f"[move-test] Package {package_label}: skipped (dry-run)\n")
                    log_stream.flush()
                result_entry.update({"status": "skipped", "return_code": None, "duration_seconds": 0.0})
                results.append(result_entry)
                continue

            started_at = time.time()
            if log_stream is not None:
                log_stream.write(f"[move-test] Package {package_label}: {quoted}\n")
                log_stream.flush()
            last_return_code = _run_with_streaming(command, log_stream)
            duration = time.time() - started_at
            status = "passed" if last_return_code == 0 else "failed"
            if status == "failed" and first_failure_code == 0:
                first_failure_code = last_return_code
            result_entry.update({"status": status, "return_code": last_return_code, "duration_seconds": duration})
            results.append(result_entry)
            if last_return_code != 0 and not args.keep_going:
                break
    finally:
        if log_stream is not None:
            log_stream.write("[move-test] Completed.\n")
            log_stream.close()

    if json_report_path:
        report_path = json_report_path
        payload = {
            "workspace": str(workspace),
            "cli_path": cli_path,
            "cli_flavour": flavour,
            "results": results,
        }
        report_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")

    if junit_report_path:
        report_path = junit_report_path
        _write_junit_report(report_path, workspace, cli_path, flavour, results)

    if first_failure_code:
        return first_failure_code
    return last_return_code


def _run_with_streaming(command: Sequence[str], log_stream: TextIO | None) -> int:
    """Runs the command while streaming stdout/stderr to console and log."""

    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert process.stdout is not None
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        if log_stream is not None:
            log_stream.write(line)
            log_stream.flush()
    process.stdout.close()
    return process.wait()


def _prepare_report_target(value: str | None) -> Path | None:
    if not value or value == "-":
        return None
    path = Path(value).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    return path.resolve()


def _write_junit_report(
    report_path: Path,
    workspace: Path,
    cli_path: str,
    flavour: str,
    results: Sequence[dict[str, object]],
) -> None:
    """Saves execution results in JUnit XML format."""

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
                failure.text = f"Command: {command_str}"
        elif status == "skipped":
            ET.SubElement(testcase, "skipped")

    tree = ET.ElementTree(suite)
    tree.write(report_path, encoding="utf-8", xml_declaration=True)


def main() -> None:
    try:
        exit_code = run()
    except MoveCliNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(2)
    except SystemExit as exc:
        # Propagate the exit code while keeping the CLI container shutdown clean.
        raise exc
    except Exception as exc:  # pragma: no cover - unexpected error
        print(f"Unexpected error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
