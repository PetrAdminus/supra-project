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

        config = monitor_lib.monitor_config_from_namespace(self.args)

        def fake_run_cli(args: Namespace, command: Any) -> Dict[str, Any]:  # pylint: disable=unused-argument
            try:
                function_idx = command.index("--function-id") + 1
            except ValueError as exc:  # pragma: no cover - defensive branch
                raise AssertionError(f"Missing --function-id in {command}") from exc
            function_id = command[function_idx]

            if function_id.endswith("::is_initialized"):
                return {"result": [True]}
            if function_id == f"{config.referrals_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.referrals_prefix}::get_lottery_config":
                return {"result": [{"referrer_bps": 300, "referee_bps": 200}]}
            if function_id == f"{config.referrals_prefix}::get_lottery_stats":
                return {
                    "result": [
                        {
                            "rewarded_purchases": 2,
                            "total_referrer_rewards": 60,
                            "total_referee_rewards": 40,
                        }
                    ]
                }
            if function_id == f"{config.hub_prefix}::lottery_count":
                return {"result": [1]}
            if function_id == f"{config.hub_prefix}::peek_next_lottery_id":
                return {"result": ["1"]}
            if function_id == f"{config.hub_prefix}::callback_sender":
                return {"result": ["0xcallback"]}
            if function_id == f"{config.hub_prefix}::get_registration":
                return {"result": [{"owner": "0xowner", "lottery": "0xcontract"}]}
            if function_id == f"{config.factory_prefix}::get_lottery":
                return {
                    "result": [
                        {
                            "owner": "0xowner",
                            "lottery": "0xcontract",
                            "blueprint": {"ticket_price": 100, "jackpot_share_bps": 2000},
                        }
                    ]
                }
            if function_id == f"{config.instances_prefix}::get_lottery_info":
                return {
                    "result": [
                        {
                            "owner": "0xowner",
                            "lottery": "0xcontract",
                            "blueprint": {"ticket_price": 100, "jackpot_share_bps": 2000},
                        }
                    ]
                }
            if function_id == f"{config.instances_prefix}::get_instance_stats":
                return {"result": [{"tickets_sold": 5, "jackpot_accumulated": 42, "active": True}]}
            if function_id == f"{config.rounds_prefix}::get_round_snapshot":
                return {"result": [{"ticket_count": 3, "ticket_price": 100}]}
            if function_id == f"{config.rounds_prefix}::pending_request_id":
                return {"result": [None]}
            if function_id == f"{config.treasury_prefix}::get_config":
                return {"result": [{"prize_bps": 7000, "jackpot_bps": 2000, "operations_bps": 1000}]}
            if function_id == f"{config.treasury_prefix}::get_pool":
                return {"result": [{"prize_balance": 210, "operations_balance": 30}]}
            if function_id == f"{config.treasury_prefix}::jackpot_balance":
                return {"result": [60]}
            if function_id == f"{config.autopurchase_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.autopurchase_prefix}::get_lottery_summary":
                return {
                    "result": [
                        {
                            "total_balance": 300,
                            "total_players": 1,
                            "active_players": 1,
                        }
                    ]
                }
            if function_id == f"{config.autopurchase_prefix}::list_players":
                return {"result": [["0xplayer1"]]}
            if function_id == f"{config.operators_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.operators_prefix}::get_owner":
                return {"result": ["0xmanager"]}
            if function_id == f"{config.operators_prefix}::list_operators":
                return {"result": [["0xoperator1", "0xoperator2"]]}
            if function_id == f"{config.metadata_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.metadata_prefix}::get_metadata":
                return {
                    "result": [
                        {
                            "title": b"Daily Lottery",
                            "description": b"Description",
                            "image_uri": b"https://img/lottery.png",
                            "website_uri": b"https://example/lottery",
                            "rules_uri": b"https://example/lottery/rules",
                        }
                    ]
                }
            if function_id == f"{config.history_prefix}::is_initialized":
                return {"result": [True]}
            if function_id == f"{config.history_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.history_prefix}::get_history":
                return {
                    "result": [
                        [
                            {
                                "request_id": 42,
                                "winner": "0xwinner",
                                "ticket_index": 0,
                                "prize_amount": 140,
                                "random_bytes": [5, 0, 0, 0, 0, 0, 0, 0],
                                "payload": b"log",
                                "timestamp_seconds": 1_234_567_890,
                            }
                        ]
                    ]
                }
            if function_id == f"{config.history_prefix}::latest_record":
                return {
                    "result": [
                        {
                            "request_id": 42,
                            "winner": "0xwinner",
                            "ticket_index": 0,
                            "prize_amount": 140,
                            "random_bytes": [5, 0, 0, 0, 0, 0, 0, 0],
                            "payload": b"log",
                            "timestamp_seconds": 1_234_567_890,
                        }
                    ]
                }
            if function_id == f"{config.vip_prefix}::list_lottery_ids":
                return {"result": [0]}
            if function_id == f"{config.vip_prefix}::get_lottery_summary":
                return {
                    "result": [
                        {
                            "config": {
                                "price": 250,
                                "duration_secs": 1000,
                                "bonus_tickets": 2,
                            },
                            "total_members": 1,
                            "active_members": 1,
                            "total_revenue": 250,
                            "bonus_tickets_issued": 4,
                        }
                    ]
                }
            if function_id == f"{config.vip_prefix}::list_players":
                return {"result": [["0xvip1"]]}
            if function_id == f"{config.treasury_fa_prefix}::treasury_balance":
                return {"result": ["123456"]}
            if function_id == f"{config.treasury_fa_prefix}::total_supply":
                return {"result": "987654321"}
            if function_id == f"{config.treasury_fa_prefix}::metadata_summary":
                return {
                    "result": {
                        "name": "Lottery Token",
                        "symbol": "LOT",
                        "decimals": 6,
                    }
                }
            if function_id == f"{config.deposit_prefix}::checkClientFund":
                return {"result": ["600"]}
            if function_id == f"{config.deposit_prefix}::checkMinBalanceClient":
                return {"result": ["500"]}
            if function_id == f"{config.deposit_prefix}::isMinimumBalanceReached":
                return {"result": [True]}
            if function_id == f"{config.deposit_prefix}::getContractDetails":
                return {"result": {"callback_gas_limit": "500000"}}
            if function_id == f"{config.deposit_prefix}::getSubscriptionInfoByClient":
                return {"result": {"active": True}}
            if function_id == f"{config.deposit_prefix}::listAllWhitelistedContractByClient":
                return {"result": ["0xabc"]}
            if function_id == f"{config.deposit_prefix}::checkMaxGasPriceClient":
                return {"result": ["1000"]}
            if function_id == f"{config.deposit_prefix}::checkMaxGasLimitClient":
                return {"result": ["500000"]}
            if function_id == f"{config.hub_prefix}::get_registration":
                return {"result": [{"owner": "0xowner", "lottery": "0xcontract"}]}

            raise AssertionError(f"Unexpected function id: {function_id}")

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

        with patch.object(monitor_lib, "run_cli", side_effect=fake_run_cli), patch.object(
            monitor_lib, "calculate", return_value=FakeCalculation(calc_payload)
        ):
            report = monitor.gather_data(config)

        self.assertEqual(report["profile"], "my_new_profile")
        self.assertEqual(report["deposit"]["balance"], "600")
        self.assertEqual(report["deposit"]["min_balance"], "500")
        self.assertTrue(report["deposit"]["min_balance_reached"])
        self.assertEqual(report["calculation"], calc_payload)
        self.assertEqual(report["hub"]["configured_lottery_ids"], [0])
        self.assertEqual(len(report["lotteries"]), 1)
        self.assertEqual(report["lotteries"][0]["lottery_id"], 0)
        self.assertEqual(report["lotteries"][0]["registration"], {"owner": "0xowner", "lottery": "0xcontract"})
        self.assertEqual(report["lotteries"][0]["round"]["snapshot"], {"ticket_count": 3, "ticket_price": 100})
        self.assertEqual(
            report["lotteries"][0]["metadata"],
            {
                "title": b"Daily Lottery",
                "description": b"Description",
                "image_uri": b"https://img/lottery.png",
                "website_uri": b"https://example/lottery",
                "rules_uri": b"https://example/lottery/rules",
            },
        )
        self.assertEqual(
            report["lotteries"][0]["latest_history"],
            {
                "request_id": 42,
                "winner": "0xwinner",
                "ticket_index": 0,
                "prize_amount": 140,
                "random_bytes": [5, 0, 0, 0, 0, 0, 0, 0],
                "payload": b"log",
                "timestamp_seconds": 1_234_567_890,
            },
        )
        self.assertEqual(report["treasury"]["token_balance"], "123456")
        self.assertEqual(report["treasury"]["metadata"], {"name": "Lottery Token", "symbol": "LOT", "decimals": 6})
        self.assertEqual(
            report["autopurchase"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "summary": {
                            "total_balance": 300,
                            "total_players": 1,
                            "active_players": 1,
                        },
                        "players": ["0xplayer1"],
                    }
                ],
            },
        )
        self.assertEqual(
            report["metadata"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "metadata": {
                            "title": b"Daily Lottery",
                            "description": b"Description",
                            "image_uri": b"https://img/lottery.png",
                            "website_uri": b"https://example/lottery",
                            "rules_uri": b"https://example/lottery/rules",
                        },
                    }
                ],
            },
        )
        self.assertEqual(
            report["operators"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "owner": "0xmanager",
                        "operators": ["0xoperator1", "0xoperator2"],
                    }
                ],
            },
        )
        self.assertEqual(
            report["history"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "records": [
                            {
                                "request_id": 42,
                                "winner": "0xwinner",
                                "ticket_index": 0,
                                "prize_amount": 140,
                                "random_bytes": [5, 0, 0, 0, 0, 0, 0, 0],
                                "payload": b"log",
                                "timestamp_seconds": 1_234_567_890,
                            }
                        ],
                    }
                ],
            },
        )
        self.assertEqual(
            report["referrals"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "config": {"referrer_bps": 300, "referee_bps": 200},
                        "stats": {
                            "rewarded_purchases": 2,
                            "total_referrer_rewards": 60,
                            "total_referee_rewards": 40,
                        },
                    }
                ],
            },
        )
        self.assertEqual(
            report["vip"],
            {
                "initialized": True,
                "lotteries": [
                    {
                        "lottery_id": 0,
                        "summary": {
                            "config": {
                                "price": 250,
                                "duration_secs": 1000,
                                "bonus_tickets": 2,
                            },
                            "total_members": 1,
                            "active_members": 1,
                            "total_revenue": 250,
                            "bonus_tickets_issued": 4,
                        },
                        "players": ["0xvip1"],
                    }
                ],
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
