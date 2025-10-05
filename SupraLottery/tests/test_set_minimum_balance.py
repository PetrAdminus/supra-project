import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from supra.scripts import set_minimum_balance
from supra.scripts.monitor_common import MonitorError


class SetMinimumBalanceTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "deposit_addr": "0xdeposit",
            "client_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "max_gas_price": 10,
            "max_gas_limit": 20,
            "verification_gas": 30,
            "margin": 0.15,
            "window": 30,
            "assume_yes": True,
            "dry_run": False,
            "function_id": None,
            "expected_min_balance": None,
            "expected_max_gas_fee": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    @patch("supra.scripts.set_minimum_balance.execute_move_tool_run")
    @patch("supra.scripts.set_minimum_balance.gather_data")
    @patch("supra.scripts.set_minimum_balance.monitor_config_from_namespace")
    def test_execute_runs_move_tool_with_defaults(
        self,
        config_mock,
        gather_mock,
        exec_mock,
    ) -> None:  # type: ignore[no-untyped-def]
        config_mock.return_value = SimpleNamespace()
        gather_mock.return_value = {
            "calculation": {"per_request_fee": "123", "min_balance": "456"},
            "deposit": {"min_balance": "789"},
        }
        exec_mock.return_value = {"returncode": 0, "command": ["/supra/supra"], "stdout": "ok"}

        now = datetime(2024, 6, 1, tzinfo=timezone.utc)
        ns = self.make_ns()
        result = set_minimum_balance.execute(ns, now=now)

        self.assertEqual(result["expected_min_balance"], 789)
        self.assertEqual(result["expected_max_gas_fee"], 123)

        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::main_v2::set_minimum_balance",
            args=[],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )

    @patch("supra.scripts.set_minimum_balance.gather_data")
    @patch("supra.scripts.set_minimum_balance.monitor_config_from_namespace")
    def test_raises_when_expectations_do_not_match(self, config_mock, gather_mock) -> None:  # type: ignore[no-untyped-def]
        config_mock.return_value = SimpleNamespace()
        gather_mock.return_value = {
            "calculation": {"per_request_fee": "1000", "min_balance": "5000"},
            "deposit": {"min_balance": "5000"},
        }

        ns = self.make_ns(expected_min_balance=4000)
        with self.assertRaises(MonitorError):
            set_minimum_balance.execute(ns)

        ns = self.make_ns(expected_max_gas_fee=900)
        with self.assertRaises(MonitorError):
            set_minimum_balance.execute(ns)

    def test_target_function_id_uses_override(self) -> None:
        ns = self.make_ns(function_id="custom::call")
        self.assertEqual(set_minimum_balance.target_function_id(ns), "custom::call")

    def test_target_function_id_requires_lottery(self) -> None:
        ns = self.make_ns(lottery_addr="")
        with self.assertRaises(MonitorError):
            set_minimum_balance.target_function_id(ns)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
