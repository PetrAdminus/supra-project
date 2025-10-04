"""Unit tests for the testnet_draw_readiness helper."""

from __future__ import annotations

import io
import json
import unittest
from argparse import Namespace
from subprocess import CompletedProcess
from unittest.mock import Mock, patch

from supra.scripts import testnet_draw_readiness as readiness


def build_namespace(**kwargs) -> Namespace:
    defaults = dict(
        profile="lottery_admin",
        lottery_addr="0xabc",
        deposit_addr="0xdef",
        client_addr="0xabc",
        supra_cli_bin="/supra/supra",
        supra_config=None,
        max_gas_price=1000,
        max_gas_limit=500000,
        verification_gas=25000,
        margin=0.1,
        window=30,
        min_tickets=5,
        skip_draw_scheduled=False,
        allow_pending_request=False,
        skip_min_balance=False,
        require_aggregator=False,
        expect_aggregator=None,
        print_json=False,
    )
    defaults.update(kwargs)
    return Namespace(**defaults)


def ready_report(ticket_count: int = 6) -> dict:
    return {
        "lottery": {
            "status": {
                "ticket_count": ticket_count,
                "draw_scheduled": True,
                "pending_request": False,
            },
            "whitelist_status": {"aggregators": ["0xagg"]},
        },
        "deposit": {
            "min_balance_reached": True,
        },
    }


class DrawReadinessEvaluateTests(unittest.TestCase):
    """Tests for the evaluate helper."""

    def test_evaluate_returns_empty_when_ready(self) -> None:
        ns = build_namespace()
        reasons = readiness.evaluate(ready_report(), ns)
        self.assertFalse(reasons)

    def test_evaluate_detects_pending_request(self) -> None:
        report = ready_report()
        report["lottery"]["status"]["pending_request"] = True
        ns = build_namespace()
        reasons = readiness.evaluate(report, ns)
        self.assertIn("pending_request=true", " ".join(reasons))

    def test_evaluate_checks_aggregator_presence(self) -> None:
        report = ready_report()
        report["lottery"]["whitelist_status"]["aggregators"] = []
        ns = build_namespace(require_aggregator=True)
        reasons = readiness.evaluate(report, ns)
        self.assertIn("Whitelist агрегаторов пуст", reasons)

    def test_evaluate_validates_specific_aggregators(self) -> None:
        report = ready_report()
        ns = build_namespace(expect_aggregator=["0xmissing"])
        reasons = readiness.evaluate(report, ns)
        self.assertIn("0xmissing", " ".join(reasons))

    def test_evaluate_requires_ticket_threshold(self) -> None:
        ns = build_namespace(min_tickets=10)
        reasons = readiness.evaluate(ready_report(ticket_count=6), ns)
        self.assertTrue(any("Недостаточно билетов" in r for r in reasons))


class DrawReadinessMainTests(unittest.TestCase):
    """Tests covering the main entry point."""

    def test_main_prints_success_message(self) -> None:
        ns = build_namespace()
        report = ready_report()
        process = CompletedProcess(args=["python"], returncode=0, stdout=json.dumps(report))

        parser_mock = Mock()
        parser_mock.parse_args.return_value = ns
        parser_mock.error.side_effect = AssertionError

        with patch.object(readiness, "build_parser", return_value=parser_mock), patch.object(
            readiness, "run_monitor", return_value=process
        ), patch("sys.stdout", new=io.StringIO()) as stdout, self.assertRaises(SystemExit) as exc:
            readiness.main()

        self.assertEqual(exc.exception.code, 0)
        output = stdout.getvalue()
        self.assertIn("✅", output)
        self.assertIn("draw_scheduled=True", output)

    def test_main_prints_reasons_on_failure(self) -> None:
        ns = build_namespace()
        report = ready_report(ticket_count=1)
        report["deposit"]["min_balance_reached"] = False
        process = CompletedProcess(args=["python"], returncode=0, stdout=json.dumps(report))

        parser_mock = Mock()
        parser_mock.parse_args.return_value = ns
        parser_mock.error.side_effect = AssertionError

        with patch.object(readiness, "build_parser", return_value=parser_mock), patch.object(
            readiness, "run_monitor", return_value=process
        ), patch("sys.stdout", new=io.StringIO()) as stdout, self.assertRaises(SystemExit) as exc:
            readiness.main()

        self.assertEqual(exc.exception.code, 1)
        output = stdout.getvalue()
        self.assertIn("❌", output)
        self.assertIn("Минимальный баланс", output)
        self.assertIn("Недостаточно билетов", output)

    def test_main_reports_cli_errors(self) -> None:
        ns = build_namespace()
        parser_mock = Mock()
        parser_mock.parse_args.return_value = ns
        parser_mock.error.side_effect = SystemExit

        with patch.object(readiness, "build_parser", return_value=parser_mock), patch.object(
            readiness, "run_monitor", side_effect=readiness.MonitorError("boom")
        ):
            with self.assertRaises(SystemExit):
                readiness.main()


if __name__ == "__main__":
    unittest.main()
