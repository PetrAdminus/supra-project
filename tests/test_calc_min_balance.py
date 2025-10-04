"""Unit tests for supra.scripts.calc_min_balance."""
from __future__ import annotations

import argparse
import unittest

from supra.scripts import calc_min_balance


class CalcMinBalanceTest(unittest.TestCase):
    """Validate helper formulas used for Supra dVRF deposit calculations."""

    def test_calculate_matches_contract_formula(self) -> None:
        result = calc_min_balance.calculate(
            max_gas_price=1_000,
            max_gas_limit=500_000,
            verification_gas_value=25_000,
            margin=0.2,
            window=30,
        )
        self.assertEqual(result.per_request_fee, 1_000 * (500_000 + 25_000))
        self.assertEqual(result.min_balance, 30 * result.per_request_fee)
        self.assertEqual(result.recommended_deposit, int(result.min_balance * 1.2))

    def test_parse_u128_accepts_underscored_numbers(self) -> None:
        value = calc_min_balance.parse_u128("1_234_567_890")
        self.assertEqual(value, 1_234_567_890)

    def test_parse_u128_rejects_invalid_number(self) -> None:
        with self.assertRaises(argparse.ArgumentTypeError):
            calc_min_balance.parse_u128("abc")

    def test_format_amount_includes_supra_conversion(self) -> None:
        amount = 2_500_000_000
        formatted = calc_min_balance.format_amount(amount)
        self.assertIn("2 500 000 000", formatted)
        supra_value = amount / calc_min_balance.QUANTS_IN_SUPRA
        self.assertIn(f"~{supra_value:.6f} SUPRA", formatted)


if __name__ == "__main__":
    unittest.main()
