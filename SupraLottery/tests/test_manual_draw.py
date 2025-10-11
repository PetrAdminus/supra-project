import io
import json
import subprocess
import sys
from unittest import TestCase, mock
from unittest.mock import patch

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

    def _ready_report(
        self,
        *,
        ticket_count: int = 6,
        draw_scheduled: bool = True,
        pending: bool = False,
        min_balance: bool = True,
        aggregators: list[str] | None = None,
    ) -> dict:
        snapshot = {
            "ticket_count": ticket_count,
            "draw_scheduled": draw_scheduled,
            "has_pending_request": pending,
        }
        lottery_entry = {
            "lottery_id": 1,
            "registration": {"active": True},
            "round": {"snapshot": snapshot, "pending_request_id": None},
        }
        return {
            "lotteries": [lottery_entry],
            "deposit": {
                "min_balance_reached": min_balance,
                "whitelisted_contracts": aggregators if aggregators is not None else ["0xfeed"],
            },
        }

    def test_manual_draw_blocks_when_readiness_fails(self) -> None:
        report = self._ready_report(ticket_count=1, draw_scheduled=False, min_balance=False)

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(testnet_manual_draw.subprocess, "run") as mocked_run, mock.patch.object(sys, "argv", self.default_args), patch("sys.stdout", new=io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 1)
        mocked_run.assert_not_called()

    def test_manual_draw_executes_on_success(self) -> None:
        report = self._ready_report()

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(testnet_manual_draw.subprocess, "run", return_value=_completed("ok")) as mocked_run, mock.patch.object(sys, "argv", self.default_args), patch("sys.stdout", new=io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_called_once()
        cmd = mocked_run.call_args.args[0]
        self.assertIn("manual_draw", cmd[-1])

    def test_manual_draw_dry_run_skips_cli(self) -> None:
        args = self.default_args + ["--dry-run", "--skip-readiness"]

        with mock.patch.object(testnet_manual_draw.subprocess, "run") as mocked_run, mock.patch.object(sys, "argv", args), patch("sys.stdout", new=io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_not_called()

    def test_json_result_includes_reasons_on_failure(self) -> None:
        report = self._ready_report(ticket_count=1, draw_scheduled=False, min_balance=False)
        args = self.default_args + ["--json-result"]

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(
            testnet_manual_draw.subprocess,
            "run",
        ) as mocked_run, mock.patch.object(sys, "argv", args), patch("sys.stdout", new=io.StringIO()) as stdout:
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 1)
        mocked_run.assert_not_called()
        payload = json.loads(stdout.getvalue())
        self.assertFalse(payload["ready"])
        self.assertFalse(payload["executed"])
        self.assertIn("Недостаточно билетов", " ".join(payload["readiness"]["reasons"]))

    def test_json_result_dry_run_reports_command(self) -> None:
        report = self._ready_report(ticket_count=10)
        args = self.default_args + ["--json-result", "--dry-run"]

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(
            testnet_manual_draw.subprocess,
            "run",
        ) as mocked_run, mock.patch.object(sys, "argv", args), patch("sys.stdout", new=io.StringIO()) as stdout:
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_not_called()
        payload = json.loads(stdout.getvalue())
        self.assertTrue(payload["ready"])
        self.assertFalse(payload["executed"])
        self.assertIn("manual_draw", payload["command"][-1])

    def test_json_result_on_successful_execution(self) -> None:
        report = self._ready_report(ticket_count=10)
        args = self.default_args + ["--json-result", "--assume-yes"]

        with mock.patch.object(testnet_manual_draw, "run_monitor", return_value=_completed(json.dumps(report))), mock.patch.object(
            testnet_manual_draw.subprocess,
            "run",
            return_value=_completed("ok"),
        ) as mocked_run, mock.patch.object(sys, "argv", args), patch("sys.stdout", new=io.StringIO()) as stdout:
            with self.assertRaises(SystemExit) as ctx:
                testnet_manual_draw.main()

        self.assertEqual(ctx.exception.code, 0)
        mocked_run.assert_called_once()
        payload = json.loads(stdout.getvalue())
        self.assertTrue(payload["executed"])
        self.assertEqual(payload["returncode"], 0)
        self.assertEqual(payload["stdout"], "ok")
