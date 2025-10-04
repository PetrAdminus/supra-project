import json
import subprocess
import sys
from unittest import TestCase, mock

from supra.scripts import testnet_manual_draw


def _completed(stdout: str, returncode: int = 0) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=["supra"], returncode=returncode, stdout=stdout, stderr="")


class ManualDrawTests(TestCase):
    def setUp(self) -> None:
        super().setUp()
        self.default_args = [
            "prog",
            "--profile",
            "admin",
            "--lottery-addr",
            "0xabc",
            "--deposit-addr",
            "0xdep",
        ]

    def test_manual_draw_blocks_when_readiness_fails(self) -> None:
        report = {
            "lottery": {"status": {"ticket_count": 1, "draw_scheduled": False}},
            "deposit": {"min_balance_reached": False},
        }

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(testnet_manual_draw.subprocess, "run") as mocked_run, mock.patch.object(sys, "argv", self.default_args):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 1)
        mocked_run.assert_not_called()

    def test_manual_draw_executes_on_success(self) -> None:
        report = {
            "lottery": {
                "status": {
                    "ticket_count": 6,
                    "draw_scheduled": True,
                    "pending_request": False,
                },
                "whitelist_status": {"aggregators": ["0xfeed"]},
            },
            "deposit": {"min_balance_reached": True},
        }

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(testnet_manual_draw.subprocess, "run", return_value=_completed("ok")) as mocked_run, mock.patch.object(sys, "argv", self.default_args):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_called_once()
        cmd = mocked_run.call_args.args[0]
        self.assertIn("manual_draw", cmd[-1])

    def test_manual_draw_dry_run_skips_cli(self) -> None:
        args = self.default_args + ["--dry-run", "--skip-readiness"]

        with mock.patch.object(testnet_manual_draw.subprocess, "run") as mocked_run, mock.patch.object(sys, "argv", args):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_not_called()
