"""Unit tests for Prometheus exporter script."""
from __future__ import annotations

import io
import json
import unittest
from argparse import Namespace
from typing import Dict
from unittest.mock import Mock, patch

from supra.scripts import testnet_monitor_prometheus as prom


class MonitorPrometheusTests(unittest.TestCase):
    """Behaviour tests for helper functions inside the Prometheus exporter."""

    def build_namespace(self, **overrides) -> Namespace:
        base: Dict[str, object] = dict(
            metric_prefix="supra_dvrf",
            label=[],
            push_url=None,
            push_method="POST",
            push_timeout=5.0,
            dry_run=True,
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
            fail_on_low=False,
        )
        base.update(overrides)
        return Namespace(**base)

    def sample_report(self) -> Dict[str, object]:
        return {
            "deposit": {
                "balance": "600",
                "min_balance_reached": True,
                "max_gas_price": "1000",
                "max_gas_limit": "500000",
                "subscription_info": {"active": True},
            },
            "calculation": {
                "min_balance": "500",
                "recommended_deposit": "550",
                "per_request_fee": "50",
                "request_window": 30,
            },
            "lottery": {
                "status": {
                    "draw_scheduled": True,
                    "pending_request": False,
                    "ticket_count": 7,
                },
                "vrf_request_config": {"rng_count": 1},
            },
        }

    def test_parse_labels_accepts_multiple_entries(self) -> None:
        labels = prom.parse_labels(["env=test", "region=eu"])
        self.assertEqual(labels, {"env": "test", "region": "eu"})

    def test_format_metrics_contains_expected_lines(self) -> None:
        ns = self.build_namespace()
        metrics = prom.format_metrics(ns, self.sample_report(), monitor_rc=0, extra_labels={"env": "test"})

        self.assertIn('supra_dvrf_deposit_balance_quants{', metrics)
        self.assertIn('supra_dvrf_min_balance_quants', metrics)
        self.assertIn('balance_ratio', metrics)
        self.assertIn('monitor_exit_code', metrics)
        self.assertIn('env="test"', metrics)

    def test_main_push_failure_returns_error(self) -> None:
        ns = self.build_namespace(push_url="https://metrics", dry_run=False)
        report = self.sample_report()

        parser_mock = Mock()
        parser_mock.parse_args.return_value = ns
        parser_mock.error.side_effect = AssertionError

        with patch.object(prom, "build_parser", return_value=parser_mock), patch.object(
            prom, "run_monitor", return_value=Namespace(report=report, returncode=0)
        ), patch.object(prom, "parse_labels", return_value={}), patch.object(
            prom, "push_metrics", side_effect=prom.PrometheusError("failed")
        ), patch("sys.stdout", new=io.StringIO()), patch("sys.stderr", new=io.StringIO()) as stderr:
            with self.assertRaises(SystemExit) as exc:
                prom.main()

        self.assertEqual(exc.exception.code, 2)
        self.assertIn("failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
