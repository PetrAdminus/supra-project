"""Unit tests for the Slack/webhook monitor wrapper."""

from __future__ import annotations

import io
import json
import unittest
from argparse import Namespace
from subprocess import CompletedProcess
from typing import List
from unittest.mock import Mock, patch

from supra.scripts import testnet_monitor_slack as slack


class MonitorSlackTests(unittest.TestCase):
    """Behaviour verification for helper functions in testnet_monitor_slack."""

    def build_namespace(self, **overrides) -> Namespace:
        """Create a namespace with sensible defaults for the Slack script."""

        base = dict(
            webhook_url="https://example.com/hook",
            webhook_type="slack",
            title="Supra alert",
            dry_run=True,
            include_json=False,
            profile="my_new_profile",
            lottery_addr="0xlottery",
            deposit_addr="0xdeposit",
            client_addr="0xclient",
            supra_cli_bin="/supra/supra",
            supra_config=None,
            max_gas_price=1_000,
            max_gas_limit=500_000,
            verification_gas=25_000,
            margin=0.1,
            window=30,
            fail_on_low=True,
        )
        base.update(overrides)
        return Namespace(**base)

    def test_build_monitor_args_includes_all_known_flags(self) -> None:
        """All populated namespace fields should produce CLI flags."""

        ns = self.build_namespace()
        args = slack.build_monitor_args(ns)

        expected: List[str] = [
            "--profile",
            ns.profile,
            "--lottery-addr",
            ns.lottery_addr,
            "--deposit-addr",
            ns.deposit_addr,
            "--client-addr",
            ns.client_addr,
            "--supra-cli-bin",
            ns.supra_cli_bin,
            "--max-gas-price",
            str(ns.max_gas_price),
            "--max-gas-limit",
            str(ns.max_gas_limit),
            "--verification-gas",
            str(ns.verification_gas),
            "--margin",
            str(ns.margin),
            "--window",
            str(ns.window),
            "--fail-on-low",
        ]

        self.assertEqual(args, expected)

    def test_run_monitor_raises_when_cli_fails(self) -> None:
        """Unexpected return codes or empty output must raise MonitorError."""

        ns = self.build_namespace()
        bad_process = CompletedProcess(args=["python"], returncode=2, stdout="", stderr="boom")

        with patch("subprocess.run", return_value=bad_process):
            with self.assertRaises(slack.MonitorError):
                slack.run_monitor(ns)

    def test_format_message_warns_on_low_balance(self) -> None:
        """When баланс ниже минимума, в сообщении появляется предупреждение."""

        ns = self.build_namespace(title="Alert", profile="lottery_admin")
        report = {
            "deposit": {
                "balance": "100",
                "min_balance": "200",
                "min_balance_reached": False,
                "max_gas_price": "1000",
                "max_gas_limit": "500000",
            },
            "calculation": {"min_balance": "200"},
            "lotteries": [
                {
                    "lottery_id": 1,
                    "registration": {"active": True},
                    "round": {
                        "snapshot": {
                            "draw_scheduled": True,
                            "has_pending_request": False,
                            "ticket_count": 5,
                        },
                        "pending_request_id": None,
                    },
                }
            ],
        }

        message = slack.format_message(ns, report, monitor_rc=1)

        self.assertIn("⚠️", message)
        self.assertIn("Баланс депозита: 100", message)
        self.assertIn("scheduled=True", message)
        self.assertIn("Баланс ниже минимального лимита", message)

    def test_main_dry_run_outputs_message_and_exit_code(self) -> None:
        """При dry-run сообщение печатается, а код возврата совпадает с CLI."""

        ns = self.build_namespace(include_json=True)
        report = {
            "deposit": {
                "balance": "500",
                "min_balance": "400",
                "min_balance_reached": True,
                "max_gas_price": "1000",
                "max_gas_limit": "500000",
            },
            "calculation": {"min_balance": "400"},
            "lottery": {"status": {"draw_scheduled": True, "pending_request": False, "ticket_count": 6}},
        }
        process = CompletedProcess(args=["python"], returncode=0, stdout=json.dumps(report))

        parser_mock = Mock()
        parser_mock.parse_args.return_value = ns
        parser_mock.error.side_effect = AssertionError  # should not be called

        with patch.object(slack, "build_parser", return_value=parser_mock), patch.object(
            slack, "run_monitor", return_value=process
        ), patch("sys.stdout", new=io.StringIO()) as stdout, self.assertRaises(SystemExit) as exc:
            slack.main()

        output = stdout.getvalue()
        self.assertIn("```", output)  # include_json добавляет кодовый блок
        self.assertIn("Баланс депозита: 500", output)
        self.assertEqual(exc.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
