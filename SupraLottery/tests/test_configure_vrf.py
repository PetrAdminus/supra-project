from datetime import datetime, timezone
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from supra.scripts import configure_vrf_gas, configure_vrf_request
from supra.scripts.monitor_common import MonitorError


class ConfigureVrfGasTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": True,
            "dry_run": False,
            "max_gas_price": 1_000,
            "max_gas_limit": 2_000,
            "callback_gas_price": 3_000,
            "callback_gas_limit": 4_000,
            "verification_gas": 5_000,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(
            configure_vrf_gas.build_command_args(ns),
            ["u128:1000", "u128:2000", "u128:3000", "u128:4000", "u128:5000"],
        )

    def test_target_function_requires_lottery(self) -> None:
        ns = self.make_ns(lottery_addr=None)
        with self.assertRaises(MonitorError):
            configure_vrf_gas.target_function_id(ns)

    @patch("supra.scripts.configure_vrf_gas.execute_move_tool_run")
    def test_execute_invokes_cli_with_expected_args(self, exec_mock) -> None:  # type: ignore[no-untyped-def]
        exec_mock.return_value = {"returncode": 0}
        now = datetime(2024, 3, 1, tzinfo=timezone.utc)
        ns = self.make_ns()
        configure_vrf_gas.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::main_v2::configure_vrf_gas",
            args=["u128:1000", "u128:2000", "u128:3000", "u128:4000", "u128:5000"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )


class ConfigureVrfRequestTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": False,
            "dry_run": False,
            "rng_count": 7,
            "client_seed": 99,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(configure_vrf_request.build_command_args(ns), ["u8:7", "u64:99"])

    def test_target_function_uses_override(self) -> None:
        ns = self.make_ns(function_id="custom::request")
        self.assertEqual(configure_vrf_request.target_function_id(ns), "custom::request")

    @patch("supra.scripts.configure_vrf_request.execute_move_tool_run")
    def test_execute_invokes_cli_with_expected_args(self, exec_mock) -> None:  # type: ignore[no-untyped-def]
        exec_mock.return_value = {"returncode": 0}
        now = datetime(2024, 4, 1, tzinfo=timezone.utc)
        ns = self.make_ns(assume_yes=True)
        configure_vrf_request.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::main_v2::configure_vrf_request",
            args=["u8:7", "u64:99"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )
