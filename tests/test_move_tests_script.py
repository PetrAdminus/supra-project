from __future__ import annotations

import json
import subprocess
import tempfile
import io
import xml.etree.ElementTree as ET
from contextlib import redirect_stdout
from pathlib import Path
from unittest import TestCase
from unittest.mock import call, patch

from supra.scripts import move_tests


class MoveTestsScriptTest(TestCase):
    def setUp(self) -> None:
        self._temp_dir = tempfile.TemporaryDirectory()
        self.workspace = Path(self._temp_dir.name)
        (self.workspace / "lottery").mkdir(parents=True, exist_ok=True)
        (self.workspace / "lottery" / "Move.toml").write_text("[package]\nname = \"lottery\"\n")

    def tearDown(self) -> None:
        self._temp_dir.cleanup()

    def test_uses_supra_cli_when_available(self) -> None:
        fake_supra = self.workspace / "supra-cli"
        fake_supra.write_text("#!/bin/sh\n")

        def fake_which(name: str) -> str | None:
            return str(fake_supra) if name == "supra" else None

        with patch("supra.scripts.move_tests.shutil.which", side_effect=fake_which), patch(
            "supra.scripts.move_tests.subprocess.run",
            return_value=subprocess.CompletedProcess(args=[], returncode=0),
        ) as run_mock:
            exit_code = move_tests.run(
                ["--workspace", str(self.workspace), "--package", "lottery", "--", "--filter", "snapshots"]
            )

        self.assertEqual(0, exit_code)
        expected_package = str((self.workspace / "lottery").resolve())
        run_mock.assert_called_once_with(
            [str(fake_supra), "move", "test", "-p", expected_package, "--filter", "snapshots"],
            check=False,
        )

    def test_falls_back_to_aptos(self) -> None:
        fake_aptos = self.workspace / "aptos-cli"
        fake_aptos.write_text("#!/bin/sh\n")

        def fake_which(name: str) -> str | None:
            mapping = {"aptos": str(fake_aptos)}
            return mapping.get(name)

        with patch("supra.scripts.move_tests.shutil.which", side_effect=fake_which), patch(
            "supra.scripts.move_tests.subprocess.run",
            return_value=subprocess.CompletedProcess(args=[], returncode=0),
        ) as run_mock:
            exit_code = move_tests.run(["--workspace", str(self.workspace)])

        self.assertEqual(0, exit_code)
        expected_package = str(self.workspace.resolve())
        run_mock.assert_called_once_with(
            [str(fake_aptos), "move", "test", "--package-dir", expected_package],
            check=False,
        )

    def test_lists_packages(self) -> None:
        (self.workspace / "vrf_hub").mkdir(parents=True, exist_ok=True)
        (self.workspace / "vrf_hub" / "Move.toml").write_text("[package]\nname = \"vrf_hub\"\n")

        buf = io.StringIO()
        with patch("supra.scripts.move_tests.subprocess.run") as run_mock, redirect_stdout(buf):
            exit_code = move_tests.run(["--workspace", str(self.workspace), "--list-packages"])

        self.assertEqual(0, exit_code)
        run_mock.assert_not_called()
        self.assertEqual(["lottery", "vrf_hub"], buf.getvalue().strip().splitlines())

    def test_runs_all_packages(self) -> None:
        (self.workspace / "vrf_hub").mkdir(parents=True, exist_ok=True)
        (self.workspace / "vrf_hub" / "Move.toml").write_text("[package]\nname = \"vrf_hub\"\n")

        fake_cli = self.workspace / "supra-cli"
        fake_cli.write_text("#!/bin/sh\n")

        with patch(
            "supra.scripts.move_tests._resolve_cli", return_value=(str(fake_cli), "supra")
        ), patch("supra.scripts.move_tests.subprocess.run", return_value=subprocess.CompletedProcess(args=[], returncode=0)) as run_mock:
            exit_code = move_tests.run(["--workspace", str(self.workspace), "--all-packages"])

        self.assertEqual(0, exit_code)
        expected_lottery = str((self.workspace / "lottery").resolve())
        expected_vrf_hub = str((self.workspace / "vrf_hub").resolve())
        run_mock.assert_has_calls(
            [
                call([str(fake_cli), "move", "test", "-p", expected_lottery], check=False),
                call([str(fake_cli), "move", "test", "-p", expected_vrf_hub], check=False),
            ]
        )

    def test_raises_when_cli_missing(self) -> None:
        with patch("supra.scripts.move_tests.shutil.which", return_value=None):
            with self.assertRaises(move_tests.MoveCliNotFoundError):
                move_tests._resolve_cli(None)

    def test_dry_run_creates_report(self) -> None:
        report_path = self.workspace / "report.json"
        junit_path = self.workspace / "report.xml"
        fake_cli = self.workspace / "supra-cli"
        fake_cli.write_text("#!/bin/sh\n")

        with patch(
            "supra.scripts.move_tests._resolve_cli", return_value=(str(fake_cli), "supra")
        ), patch("supra.scripts.move_tests.subprocess.run") as run_mock:
            exit_code = move_tests.run(
                [
                    "--workspace",
                    str(self.workspace),
                    "--dry-run",
                    "--report-json",
                    str(report_path),
                    "--report-junit",
                    str(junit_path),
                ]
            )

        self.assertEqual(0, exit_code)
        run_mock.assert_not_called()

        payload = json.loads(report_path.read_text())
        self.assertEqual("supra", payload["cli_flavour"])
        self.assertEqual(str(fake_cli), payload["cli_path"])
        self.assertEqual(str(self.workspace.resolve()), payload["workspace"])
        self.assertEqual(1, len(payload["results"]))
        result = payload["results"][0]
        self.assertEqual("workspace", result["package"])
        self.assertEqual("skipped", result["status"])
        self.assertIsNone(result["return_code"])
        self.assertEqual(0.0, result["duration_seconds"])
        self.assertEqual([], result["command"][5:])  # убедимся, что командный список корректный

        tree = ET.parse(junit_path)
        suite = tree.getroot()
        self.assertEqual("testsuite", suite.tag)
        self.assertEqual("1", suite.attrib["tests"])
        self.assertEqual("0", suite.attrib["failures"])
        self.assertEqual("1", suite.attrib["skipped"])
        testcases = list(suite.findall("testcase"))
        self.assertEqual(1, len(testcases))
        self.assertIsNotNone(testcases[0].find("skipped"))

    def test_dry_run_without_cli_uses_cli_flavour(self) -> None:
        report_path = self.workspace / "report.json"

        with patch(
            "supra.scripts.move_tests._resolve_cli",
            side_effect=move_tests.MoveCliNotFoundError("missing"),
        ):
            exit_code = move_tests.run(
                [
                    "--workspace",
                    str(self.workspace),
                    "--all-packages",
                    "--dry-run",
                    "--cli-flavour",
                    "aptos",
                    "--report-json",
                    str(report_path),
                ]
            )

        self.assertEqual(0, exit_code)
        payload = json.loads(report_path.read_text())
        self.assertEqual("aptos", payload["cli_flavour"])
        self.assertEqual("aptos", payload["cli_path"])
        results = payload["results"]
        self.assertEqual(1, len(results))
        command = results[0]["command"]
        self.assertIn("--package-dir", command)
        self.assertEqual("skipped", results[0]["status"])

    def test_report_includes_failure_details(self) -> None:
        (self.workspace / "vrf_hub").mkdir(parents=True, exist_ok=True)
        (self.workspace / "vrf_hub" / "Move.toml").write_text("[package]\nname = \"vrf_hub\"\n")

        report_path = self.workspace / "report.json"
        fake_cli = self.workspace / "supra-cli"
        fake_cli.write_text("#!/bin/sh\n")

        run_side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0),
            subprocess.CompletedProcess(args=[], returncode=77),
        ]

        with patch(
            "supra.scripts.move_tests._resolve_cli", return_value=(str(fake_cli), "supra")
        ), patch(
            "supra.scripts.move_tests.subprocess.run",
            side_effect=run_side_effect,
        ) as run_mock, patch(
            "supra.scripts.move_tests.time.time",
            side_effect=[100.0, 101.25, 200.0, 201.5],
        ):
            exit_code = move_tests.run(
                [
                    "--workspace",
                    str(self.workspace),
                    "--all-packages",
                    "--report-json",
                    str(report_path),
                ]
            )

        self.assertEqual(77, exit_code)
        self.assertEqual(2, run_mock.call_count)

        payload = json.loads(report_path.read_text())
        results = payload["results"]
        self.assertEqual(2, len(results))
        self.assertEqual("passed", results[0]["status"])
        self.assertAlmostEqual(1.25, results[0]["duration_seconds"], places=5)
        self.assertEqual("failed", results[1]["status"])
        self.assertEqual(77, results[1]["return_code"])
        self.assertAlmostEqual(1.5, results[1]["duration_seconds"], places=5)
        # Убеждаемся, что дополнительные пакеты не запускались после провала
        self.assertTrue(all(entry["package"] in {"lottery", "vrf_hub"} for entry in results))

    def test_keep_going_collects_all_failures(self) -> None:
        (self.workspace / "vrf_hub").mkdir(parents=True, exist_ok=True)
        (self.workspace / "vrf_hub" / "Move.toml").write_text("[package]\nname = \"vrf_hub\"\n")
        (self.workspace / "lottery_factory").mkdir(parents=True, exist_ok=True)
        (self.workspace / "lottery_factory" / "Move.toml").write_text("[package]\nname = \"lottery_factory\"\n")

        report_path = self.workspace / "report.json"
        fake_cli = self.workspace / "supra-cli"
        fake_cli.write_text("#!/bin/sh\n")

        run_side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0),
            subprocess.CompletedProcess(args=[], returncode=12),
            subprocess.CompletedProcess(args=[], returncode=34),
        ]

        with patch(
            "supra.scripts.move_tests._resolve_cli", return_value=(str(fake_cli), "supra")
        ), patch(
            "supra.scripts.move_tests.subprocess.run",
            side_effect=run_side_effect,
        ) as run_mock:
            exit_code = move_tests.run(
                [
                    "--workspace",
                    str(self.workspace),
                    "--all-packages",
                    "--keep-going",
                    "--report-json",
                    str(report_path),
                ]
            )

        self.assertEqual(12, exit_code)
        self.assertEqual(3, run_mock.call_count)

        payload = json.loads(report_path.read_text())
        results = payload["results"]
        self.assertEqual(["lottery", "lottery_factory", "vrf_hub"], [entry["package"] for entry in results])
        self.assertEqual(["passed", "failed", "failed"], [entry["status"] for entry in results])
        self.assertEqual([0, 12, 34], [entry["return_code"] for entry in results])

    def test_junit_report_records_failures(self) -> None:
        (self.workspace / "vrf_hub").mkdir(parents=True, exist_ok=True)
        (self.workspace / "vrf_hub" / "Move.toml").write_text("[package]\nname = \"vrf_hub\"\n")
        (self.workspace / "lottery_factory").mkdir(parents=True, exist_ok=True)
        (self.workspace / "lottery_factory" / "Move.toml").write_text("[package]\nname = \"lottery_factory\"\n")

        junit_path = self.workspace / "report.xml"
        fake_cli = self.workspace / "supra-cli"
        fake_cli.write_text("#!/bin/sh\n")

        run_side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0),
            subprocess.CompletedProcess(args=[], returncode=12),
            subprocess.CompletedProcess(args=[], returncode=34),
        ]

        with patch(
            "supra.scripts.move_tests._resolve_cli", return_value=(str(fake_cli), "supra")
        ), patch(
            "supra.scripts.move_tests.subprocess.run",
            side_effect=run_side_effect,
        ), patch(
            "supra.scripts.move_tests.time.time",
            side_effect=[10.0, 11.5, 20.0, 21.0, 30.0, 32.25],
        ):
            exit_code = move_tests.run(
                [
                    "--workspace",
                    str(self.workspace),
                    "--all-packages",
                    "--keep-going",
                    "--report-junit",
                    str(junit_path),
                ]
            )

        self.assertEqual(12, exit_code)

        tree = ET.parse(junit_path)
        suite = tree.getroot()
        self.assertEqual("3", suite.attrib["tests"])
        self.assertEqual("2", suite.attrib["failures"])
        self.assertEqual("0", suite.attrib["skipped"])
        self.assertEqual("4.750000", suite.attrib["time"])

        testcases = suite.findall("testcase")
        self.assertEqual(3, len(testcases))
        self.assertEqual("lottery", testcases[0].attrib["name"])
        self.assertEqual("1.500000", testcases[0].attrib["time"])
        self.assertIsNone(testcases[0].find("failure"))

        failure_nodes = [tc.find("failure") for tc in testcases[1:]]
        self.assertTrue(all(node is not None for node in failure_nodes))
        self.assertIn("Return code 12", failure_nodes[0].attrib["message"])
        self.assertIn("Return code 34", failure_nodes[1].attrib["message"])
