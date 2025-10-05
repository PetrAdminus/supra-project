"""Tests for the auto_draw_runner helper."""

from __future__ import annotations

import argparse
import json
import subprocess
import unittest
from unittest.mock import patch

from supra.automation import auto_draw_runner


def _completed(stdout: str, returncode: int = 0, stderr: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=["python"], returncode=returncode, stdout=stdout, stderr=stderr)


def _build_namespace(*extra: str) -> argparse.Namespace:
    parser = auto_draw_runner.build_parser()
    argv = [
        "--profile",
        "admin",
        "--lottery-addr",
        "0xabc",
        "--deposit-addr",
        "0xdef",
    ] + list(extra)
    return parser.parse_args(argv)


class AutoDrawRunnerTests(unittest.TestCase):
    def test_not_ready_produces_not_ready_status(self) -> None:
        summary = json.dumps({"ready": False, "reasons": ["low tickets"], "report": {"lottery": {}}})
        ns = _build_namespace()

        with patch.object(auto_draw_runner, "subprocess") as mocked_subprocess:
            mocked_subprocess.run.side_effect = [
                _completed(summary, returncode=1),
            ]
            entry, exit_code = auto_draw_runner.run(ns)

        self.assertEqual(exit_code, 0)
        self.assertEqual(entry["status"], "not_ready")
        self.assertEqual(entry["readiness_exit_code"], 1)
        self.assertIsNone(entry["manual_draw"])
        self.assertIn("report", entry["readiness"])  # вложенный отчёт сохраняется
        mocked_subprocess.run.assert_called_once()

    def test_ready_dry_run_skips_manual_draw(self) -> None:
        summary = json.dumps({"ready": True, "reasons": []})
        ns = _build_namespace()

        with patch.object(auto_draw_runner, "subprocess") as mocked_subprocess:
            mocked_subprocess.run.side_effect = [
                _completed(summary),
            ]
            entry, exit_code = auto_draw_runner.run(ns)

        self.assertEqual(exit_code, 0)
        self.assertEqual(entry["status"], "ready_dry_run")
        self.assertIsNone(entry["manual_draw"])
        mocked_subprocess.run.assert_called_once()

    def test_execute_runs_manual_draw(self) -> None:
        readiness = json.dumps({"ready": True, "reasons": []})
        manual = json.dumps({"executed": True, "returncode": 0})
        ns = _build_namespace("--execute")

        with patch.object(auto_draw_runner, "subprocess") as mocked_subprocess:
            mocked_subprocess.run.side_effect = [
                _completed(readiness),
                _completed(manual),
            ]
            entry, exit_code = auto_draw_runner.run(ns)

        self.assertEqual(exit_code, 0)
        self.assertEqual(entry["status"], "executed")
        self.assertEqual(entry["manual_draw"]["executed"], True)
        self.assertEqual(mocked_subprocess.run.call_count, 2)

    def test_readiness_command_includes_report_flag(self) -> None:
        readiness = json.dumps({"ready": True, "reasons": []})
        ns = _build_namespace()

        with patch.object(auto_draw_runner, "subprocess") as mocked_subprocess:
            mocked_subprocess.run.side_effect = [
                _completed(readiness),
            ]
            auto_draw_runner.run(ns)

        cmd_args = mocked_subprocess.run.call_args_list[0].args[0]
        self.assertIn("--include-report", cmd_args)

    def test_execute_reports_failure(self) -> None:
        readiness = json.dumps({"ready": True, "reasons": []})
        manual = json.dumps({"executed": True, "returncode": 2})
        ns = _build_namespace("--execute")

        with patch.object(auto_draw_runner, "subprocess") as mocked_subprocess:
            mocked_subprocess.run.side_effect = [
                _completed(readiness),
                _completed(manual, returncode=2),
            ]
            entry, exit_code = auto_draw_runner.run(ns)

        self.assertEqual(exit_code, 2)
        self.assertEqual(entry["status"], "manual_draw_failed")
        self.assertEqual(entry["manual_draw_exit_code"], 2)


if __name__ == "__main__":
    unittest.main()
