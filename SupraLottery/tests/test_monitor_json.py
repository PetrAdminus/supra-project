"""Unit tests for testnet_monitor_json script."""

from __future__ import annotations

import io
import json
import os
import sys
import unittest
from argparse import Namespace
from typing import Any, Dict
from unittest.mock import patch

from supra.scripts import testnet_monitor_json as monitor
from supra.scripts.lib import monitoring

try:  # pragma: no cover - allow importing via script shim
    import lib.monitoring as monitor_lib  # type: ignore
except ImportError:  # pragma: no cover
    monitor_lib = monitoring


class FakeCalculation:
    """Helper object mimicking calc_min_balance.CalculationResult."""

    def __init__(self, payload: Dict[str, Any]):
        self._payload = payload

    def to_json(self) -> Dict[str, Any]:
        return self._payload


class MonitorJsonTests(unittest.TestCase):
    """Tests for higher level helpers inside testnet_monitor_json."""

    def setUp(self) -> None:  # pylint: disable=invalid-name
        self.args = Namespace(
            profile="my_new_profile",
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
        )

    def test_gather_data_aggregates_all_views(self) -> None:
        """gather_data should combine CLI results and calculation output."""

        mapping: Dict[str, Any] = {
            "0xabc::main_v2::get_lottery_status": {"tickets": 5},
            "0xabc::main_v2::get_vrf_request_config": {"rng_count": 1},
            "0xabc::main_v2::get_whitelist_status": {"aggregators": ["0xagg"]},
            "0xabc::main_v2::get_ticket_price": "100",
            "0xabc::main_v2::get_registered_tickets": ["0x111", "0x222"],
            "0xabc::main_v2::get_client_whitelist_snapshot": {
                "max_gas_price": "1000",
                "max_gas_limit": "500000",
                "min_balance_limit": "7500000000",
            },
            "0xabc::main_v2::get_min_balance_limit_snapshot": "7500000000",
            "0xabc::main_v2::get_consumer_whitelist_snapshot": {
                "callback_gas_price": "50",
                "callback_gas_limit": "250000",
            },
            "0xabc::treasury_v1::get_config": [2000, 3000, 2500, 2500, 0, 0, 0],
            "0xabc::treasury_v1::get_recipients": [
                "0xtreasury",
                "0xmarketing",
                "0xcommunity",
                "0xteam",
                "0xpartners",
            ],
            "0xabc::treasury_v1::treasury_balance": ["123456"],
            "0xabc::treasury_v1::total_supply": "987654321",
            "0xabc::treasury_v1::metadata_summary": {
                "name": "Lottery Token",
                "symbol": "LOT",
                "decimals": 6,
            },
            "0xdef::deposit::checkClientFund": ["600"],
            "0xdef::deposit::checkMinBalanceClient": ["500"],
            "0xdef::deposit::isMinimumBalanceReached": [True],
            "0xdef::deposit::getContractDetails": {"callback_gas_limit": "500000"},
            "0xdef::deposit::getSubscriptionInfoByClient": {"active": True},
            "0xdef::deposit::listAllWhitelistedContractByClient": ["0xabc"],
            "0xdef::deposit::checkMaxGasPriceClient": ["1000"],
            "0xdef::deposit::checkMaxGasLimitClient": ["500000"],
        }

        def fake_run_cli(args: Namespace, command: Any) -> Dict[str, Any]:  # pylint: disable=unused-argument
            try:
                function_idx = command.index("--function-id") + 1
            except ValueError as exc:  # pragma: no cover - defensive branch
                raise AssertionError(f"Missing --function-id in {command}") from exc
            function_id = command[function_idx]
            if function_id not in mapping:
                raise AssertionError(f"Unexpected function id: {function_id}")
            return {"result": mapping[function_id]}

        calc_payload = {
            "max_gas_price": "1000",
            "max_gas_limit": "500000",
            "verification_gas_value": "25000",
            "per_request_fee": "12500000000",
            "min_balance": "375000000000",
            "recommended_deposit": "412500000000",
            "margin_ratio": 0.1,
            "request_window": 30,
        }

        config = monitor_lib.monitor_config_from_namespace(self.args)

        with patch.object(monitor_lib, "run_cli", side_effect=fake_run_cli), patch.object(
            monitor_lib, "calculate", return_value=FakeCalculation(calc_payload)
        ):
            report = monitor.gather_data(config)

        self.assertEqual(report["profile"], "my_new_profile")
        self.assertEqual(report["deposit"]["balance"], "600")
        self.assertEqual(report["deposit"]["min_balance"], "500")
        self.assertTrue(report["deposit"]["min_balance_reached"])
        self.assertEqual(report["calculation"], calc_payload)
        self.assertEqual(report["lottery"]["status"], {"tickets": 5})
        self.assertEqual(
            report["lottery"]["client_whitelist_snapshot"],
            {
                "max_gas_price": "1000",
                "max_gas_limit": "500000",
                "min_balance_limit": "7500000000",
            },
        )
        self.assertEqual(
            report["lottery"]["consumer_whitelist_snapshot"],
            {"callback_gas_price": "50", "callback_gas_limit": "250000"},
        )
        self.assertEqual(report["lottery"]["min_balance_snapshot"], "7500000000")
        self.assertEqual(
            report["treasury"],
            {
                "config": [2000, 3000, 2500, 2500, 0, 0, 0],
                "recipients": [
                    "0xtreasury",
                    "0xmarketing",
                    "0xcommunity",
                    "0xteam",
                    "0xpartners",
                ],
                "balance": "123456",
                "total_supply": "987654321",
                "metadata": {
                    "name": "Lottery Token",
                    "symbol": "LOT",
                    "decimals": 6,
                },
            },
        )

    def test_main_exits_with_error_when_balance_low(self) -> None:
        args = Namespace(
            pretty=False,
            fail_on_low=True,
            profile="profile",
            lottery_addr="0xabc",
            deposit_addr="0xdef",
            client_addr="0xabc",
            supra_cli_bin="/supra/supra",
            supra_config=None,
            max_gas_price=1,
            max_gas_limit=1,
            verification_gas=1,
            margin=0.1,
            window=30,
        )
        data = {
            "deposit": {"balance": "100"},
            "calculation": {"min_balance": "200"},
        }

        with patch.object(monitor, "parse_args", return_value=args), patch.object(
            monitor, "gather_data", return_value=data
        ), self.assertRaises(SystemExit) as exc, patch("sys.stdout", new=io.StringIO()):
            monitor.main()

        self.assertEqual(exc.exception.code, 1)

    def test_main_prints_json_on_success(self) -> None:
        args = Namespace(
            pretty=True,
            fail_on_low=True,
            profile="profile",
            lottery_addr="0xabc",
            deposit_addr="0xdef",
            client_addr="0xabc",
            supra_cli_bin="/supra/supra",
            supra_config=None,
            max_gas_price=1,
            max_gas_limit=1,
            verification_gas=1,
            margin=0.1,
            window=30,
        )
        data = {
            "deposit": {"balance": "300"},
            "calculation": {"min_balance": "200"},
        }

        stdout = io.StringIO()
        with patch.object(monitor, "parse_args", return_value=args), patch.object(
            monitor, "gather_data", return_value=data
        ), patch("sys.stdout", new=stdout):
            monitor.main()

        output = stdout.getvalue()
        self.assertTrue(output.strip())
        parsed = json.loads(output)
        self.assertEqual(parsed["deposit"]["balance"], "300")

    def test_parse_args_uses_environment_defaults(self) -> None:
        env = {
            "PROFILE": "env_profile",
            "LOTTERY_ADDR": "0xlottery",
            "DEPOSIT_ADDR": "0xdepo",
            "MAX_GAS_PRICE": "123",
            "MAX_GAS_LIMIT": "456",
            "VERIFICATION_GAS_VALUE": "789",
            "MIN_BALANCE_MARGIN": "0.25",
            "MIN_BALANCE_WINDOW": "20",
        }

        with patch.dict(os.environ, env, clear=True), patch.object(sys, "argv", ["monitor"]):
            args = monitor.parse_args()

        self.assertEqual(args.profile, "env_profile")
        self.assertEqual(args.lottery_addr, "0xlottery")
        self.assertEqual(args.deposit_addr, "0xdepo")
        self.assertEqual(args.client_addr, "0xlottery")
        self.assertEqual(args.max_gas_price, 123)
        self.assertEqual(args.max_gas_limit, 456)
        self.assertEqual(args.verification_gas, 789)
        self.assertAlmostEqual(args.margin, 0.25)
        self.assertEqual(args.window, 20)


if __name__ == "__main__":
    unittest.main()
