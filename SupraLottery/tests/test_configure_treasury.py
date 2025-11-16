from datetime import datetime, timezone
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from supra.scripts import configure_treasury_distribution
from supra.scripts.monitor_common import MonitorError


class ConfigureTreasuryDistributionTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": True,
            "dry_run": False,
            "bp_jackpot": 2000,
            "bp_prize": 3000,
            "bp_treasury": 2500,
            "bp_marketing": 2500,
            "bp_community": 0,
            "bp_team": 0,
            "bp_partners": 0,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args_converts_to_u64(self) -> None:
        ns = self.make_ns()
        self.assertEqual(
            configure_treasury_distribution.build_command_args(ns),
            ["u64:2000", "u64:3000", "u64:2500", "u64:2500", "u64:0", "u64:0", "u64:0"],
        )

    def test_build_command_args_validates_basis_points(self) -> None:
        ns = self.make_ns(bp_treasury=2001)
        with self.assertRaises(MonitorError):
            configure_treasury_distribution.build_command_args(ns)

    def test_target_function_requires_lottery(self) -> None:
        ns = self.make_ns(lottery_addr=None)
        with self.assertRaises(MonitorError):
            configure_treasury_distribution.target_function_id(ns)

    @patch("supra.scripts.configure_treasury_distribution.execute_move_tool_run")
    def test_execute_invokes_cli_with_expected_payload(self, exec_mock) -> None:  # type: ignore[no-untyped-def]
        exec_mock.return_value = {"returncode": 0}
        ns = self.make_ns()
        now = datetime(2024, 6, 1, tzinfo=timezone.utc)
        configure_treasury_distribution.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::treasury::set_config",
            args=["u64:2000", "u64:3000", "u64:2500", "u64:2500", "u64:0", "u64:0", "u64:0"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )

