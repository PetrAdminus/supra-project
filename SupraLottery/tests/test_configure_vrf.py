from datetime import datetime, timezone
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from supra.scripts import configure_vrf_gas, configure_vrf_request, remove_subscription
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
            "callback_gas_price": 900,
            "callback_gas_limit": 1_500,
            "verification_gas": 5_000,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(
            configure_vrf_gas.build_command_args(ns),
            ["u128:1000", "u128:2000", "u128:900", "u128:1500", "u128:5000"],
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
            function_id="0xlottery::core_main_v2::configure_vrf_gas",
            args=["u128:1000", "u128:2000", "u128:900", "u128:1500", "u128:5000"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )

    def test_callback_price_must_not_exceed_max(self) -> None:
        ns = self.make_ns(callback_gas_price=1_500)
        with self.assertRaises(MonitorError):
            configure_vrf_gas.build_command_args(ns)

    def test_callback_limit_must_not_exceed_max(self) -> None:
        ns = self.make_ns(callback_gas_limit=3_500)
        with self.assertRaises(MonitorError):
            configure_vrf_gas.build_command_args(ns)


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
            "num_confirmations": 5,
            "client_seed": 99,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(
            configure_vrf_request.build_command_args(ns),
            ["u8:7", "u64:5", "u64:99"],
        )

    def test_num_confirmations_must_be_positive(self) -> None:
        ns = self.make_ns(num_confirmations=0)
        with self.assertRaises(MonitorError):
            configure_vrf_request.build_command_args(ns)

    def test_num_confirmations_must_not_exceed_limit(self) -> None:
        ns = self.make_ns(num_confirmations=21)
        with self.assertRaises(MonitorError):
            configure_vrf_request.build_command_args(ns)

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
            function_id="0xlottery::core_main_v2::configure_vrf_request",
            args=["u8:7", "u64:5", "u64:99"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )


class RemoveSubscriptionTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": False,
            "dry_run": False,
            "function_id": None,
            "allow_pending_request": False,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_target_function_requires_lottery(self) -> None:
        ns = self.make_ns(lottery_addr=None)
        with self.assertRaises(MonitorError):
            remove_subscription.target_function_id(ns)

    @patch("supra.scripts.remove_subscription.gather_data")
    @patch("supra.scripts.remove_subscription.monitor_config_from_namespace")
    def test_execute_blocks_pending_request(self, config_mock, gather_mock) -> None:  # type: ignore[no-untyped-def]
        config_mock.return_value = SimpleNamespace()
        gather_mock.return_value = {
            "lotteries": [
                {
                    "lottery_id": 7,
                    "round": {
                        "pending_request_id": 3,
                        "snapshot": {"has_pending_request": False},
                    },
                }
            ]
        }
        ns = self.make_ns()
        with self.assertRaises(MonitorError):
            remove_subscription.execute(ns)

    @patch("supra.scripts.remove_subscription.execute_move_tool_run")
    @patch("supra.scripts.remove_subscription.gather_data")
    @patch("supra.scripts.remove_subscription.monitor_config_from_namespace")
    def test_execute_invokes_cli_without_pending(
        self,
        config_mock,
        gather_mock,
        exec_mock,
    ) -> None:  # type: ignore[no-untyped-def]
        config_mock.return_value = SimpleNamespace()
        gather_mock.return_value = {"lotteries": []}
        exec_mock.return_value = {"returncode": 0}
        now = datetime(2024, 5, 1, tzinfo=timezone.utc)
        ns = self.make_ns(assume_yes=True)
        remove_subscription.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::core_main_v2::remove_subscription",
            args=[],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )

