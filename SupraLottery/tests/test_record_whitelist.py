from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from supra.scripts import record_client_whitelist_snapshot as client
from supra.scripts import record_consumer_whitelist_snapshot as consumer
from supra.scripts.lib.transactions import execute_move_tool_run
from supra.scripts.monitor_common import MonitorError


class ExecuteMoveToolRunTests(TestCase):
    def setUp(self) -> None:
        self.base_kwargs = {
            "supra_cli_bin": "/supra/supra",
            "profile": "testnet",
            "function_id": "0x1::main_v2::record",
            "args": ["u128:1"],
        }

    def test_requires_profile(self) -> None:
        with self.assertRaises(MonitorError):
            execute_move_tool_run(profile="", **{k: v for k, v in self.base_kwargs.items() if k != "profile"})

    def test_dry_run_returns_command_metadata(self) -> None:
        result = execute_move_tool_run(dry_run=True, **self.base_kwargs)
        self.assertEqual(result["command"][0], "/supra/supra")
        self.assertTrue(result["dry_run"])  # type: ignore[index]
        self.assertEqual(result["returncode"], 0)

    @patch("supra.scripts.lib.transactions.subprocess.run")
    def test_parses_tx_hash_from_stdout(self, run_mock) -> None:  # type: ignore[no-untyped-def]
        completed = SimpleNamespace(
            stdout="Transaction hash: 0x" + "a" * 64,
            stderr="",
            returncode=0,
        )
        run_mock.return_value = completed
        result = execute_move_tool_run(**self.base_kwargs)
        self.assertTrue(result["tx_hash"].startswith("0x"))


class ClientWhitelistTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": True,
            "dry_run": False,
            "max_gas_price": 100,
            "max_gas_limit": 200,
            "min_balance_limit": 300,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(client.build_command_args(ns), ["u128:100", "u128:200", "u128:300"])

    def test_target_function_id_uses_override(self) -> None:
        ns = self.make_ns(function_id="custom::id")
        self.assertEqual(client.target_function_id(ns), "custom::id")

    @patch("supra.scripts.record_client_whitelist_snapshot.execute_move_tool_run")
    def test_execute_passes_expected_arguments(self, exec_mock) -> None:  # type: ignore[no-untyped-def]
        exec_mock.return_value = {"returncode": 0}
        now = datetime(2024, 1, 1, tzinfo=timezone.utc)
        ns = self.make_ns()
        client.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::core_main_v2::record_client_whitelist_snapshot",
            args=["u128:100", "u128:200", "u128:300"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )


class ConsumerWhitelistTests(TestCase):
    def make_ns(self, **overrides):  # type: ignore[no-untyped-def]
        data = {
            "profile": "testnet",
            "lottery_addr": "0xlottery",
            "supra_cli_bin": "/supra/supra",
            "supra_config": None,
            "assume_yes": False,
            "dry_run": False,
            "callback_gas_price": 111,
            "callback_gas_limit": 222,
            "function_id": None,
        }
        data.update(overrides)
        return SimpleNamespace(**data)

    def test_build_command_args(self) -> None:
        ns = self.make_ns()
        self.assertEqual(consumer.build_command_args(ns), ["u128:111", "u128:222"])

    def test_target_function_requires_lottery(self) -> None:
        ns = self.make_ns(lottery_addr=None)
        with self.assertRaises(MonitorError):
            consumer.target_function_id(ns)

    @patch("supra.scripts.record_consumer_whitelist_snapshot.execute_move_tool_run")
    def test_execute_passes_expected_arguments(self, exec_mock) -> None:  # type: ignore[no-untyped-def]
        exec_mock.return_value = {"returncode": 0}
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        ns = self.make_ns(assume_yes=True)
        consumer.execute(ns, now=now)
        exec_mock.assert_called_once_with(
            supra_cli_bin="/supra/supra",
            profile="testnet",
            function_id="0xlottery::core_main_v2::record_consumer_whitelist_snapshot",
            args=["u128:111", "u128:222"],
            supra_config=None,
            assume_yes=True,
            dry_run=False,
            now=now,
        )

