import unittest
from unittest import mock

from supra.scripts.lib import vrf_audit
from supra.scripts.lib.monitoring import MonitorConfig


class VrfAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = MonitorConfig(
            profile="test",
            lottery_addr="0x1",
            deposit_addr="0x2",
            max_gas_price=1,
            max_gas_limit=1,
            verification_gas=1,
            hub_addr="0x1",
            factory_addr="0x1",
            lottery_ids=[1, 2, 3],
        )

    def test_events_list_validates_cli_result(self) -> None:
        with mock.patch.object(vrf_audit, "run_cli", return_value={"result": "oops"}):
            with self.assertRaises(vrf_audit.CliError):
                vrf_audit.events_list(self.config, address="0x1")

    def test_gather_vrf_log_filters_and_limits(self) -> None:
        events_side_effect = [
            [
                {"sequence_number": "1", "data": {"lottery_id": 7, "request_id": 10}},
                {"sequence_number": "2", "data": {"lottery_id": 2, "request_id": 11}},
            ],
            [
                {"sequence_number": "3", "data": {"lottery_id": 2, "request_id": 11, "winner": "0xabc"}},
                {"sequence_number": "4", "data": {"lottery_id": 1, "request_id": 5}},
            ],
            [
                {"sequence_number": "5", "data": {"lottery_id": 2, "payload": [1, 2, 3]}},
            ],
            [
                {"sequence_number": "6", "data": {"lottery_id": 2, "randomness": [4, 5, 6]}},
                {"sequence_number": "7", "data": {"lottery_id": 9, "randomness": [7]}},
            ],
        ]

        with mock.patch.object(vrf_audit, "events_list", side_effect=events_side_effect), mock.patch.object(
            vrf_audit, "move_view", side_effect=[[{"tickets": 12}], "0x10"]
        ), mock.patch.object(vrf_audit, "extract_optional", side_effect=lambda value: value):
            report = vrf_audit.gather_vrf_log(self.config, lottery_id=2, limit=2)

        self.assertEqual(report["lottery_id"], 2)
        round_section = report["round"]
        self.assertEqual(len(round_section["requests"]), 1)
        self.assertEqual(len(round_section["fulfillments"]), 1)
        self.assertEqual(round_section["requests"][0]["lottery_id"], 2)
        self.assertEqual(round_section["snapshot"], [{"tickets": 12}])
        self.assertEqual(round_section["pending_request_id"], "0x10")
        hub_section = report["hub"]
        self.assertEqual(len(hub_section["requests"]), 1)
        self.assertEqual(len(hub_section["fulfillments"]), 1)
        self.assertEqual(hub_section["requests"][0]["lottery_id"], 2)

    def test_gather_vrf_log_rejects_invalid_lottery_id(self) -> None:
        with self.assertRaises(ValueError):
            vrf_audit.gather_vrf_log(self.config, lottery_id=0)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
