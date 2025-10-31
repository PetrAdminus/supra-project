#!/usr/bin/env python3
"""Calculate Supra dVRF gas economics for Lottery contract.

Given gas price, gas limits and verification gas value the script
reproduces formulas from lottery::core_main_v2::{calculate_per_request_gas_fee,
calculate_min_balance} and outputs suggested deposit with optional margin.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from typing import Any, Dict

QUANTS_IN_SUPRA = 10 ** 9  # decimals = 9


def parse_u128(value: str) -> int:
    try:
        return int(value.replace("_", ""), 10)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"РќРµРІРµСЂРЅРѕРµ С†РµР»РѕРµ С‡РёСЃР»Рѕ: {value}") from exc


def format_amount(amount: int) -> str:
    supra = amount / QUANTS_IN_SUPRA
    return f"{amount:,} quants (~{supra:.6f} SUPRA)".replace(",", " ")


@dataclass
class CalculationResult:
    max_gas_price: int
    max_gas_limit: int
    verification_gas_value: int
    per_request_fee: int
    min_balance: int
    recommended_deposit: int
    margin_ratio: float
    request_window: int = 30

    def to_json(self) -> Dict[str, Any]:
        return {
            "max_gas_price": str(self.max_gas_price),
            "max_gas_limit": str(self.max_gas_limit),
            "verification_gas_value": str(self.verification_gas_value),
            "per_request_fee": str(self.per_request_fee),
            "min_balance": str(self.min_balance),
            "recommended_deposit": str(self.recommended_deposit),
            "margin_ratio": self.margin_ratio,
            "request_window": self.request_window,
        }


def calculate(max_gas_price: int, max_gas_limit: int, verification_gas_value: int, margin: float, window: int) -> CalculationResult:
    gas_sum = max_gas_limit + verification_gas_value
    per_request_fee = max_gas_price * gas_sum
    min_balance = window * per_request_fee
    recommended = int(min_balance * (1 + margin))
    return CalculationResult(
        max_gas_price=max_gas_price,
        max_gas_limit=max_gas_limit,
        verification_gas_value=verification_gas_value,
        per_request_fee=per_request_fee,
        min_balance=min_balance,
        recommended_deposit=recommended,
        margin_ratio=margin,
        request_window=window,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Р’С‹С‡РёСЃР»РёС‚СЊ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ РґРµРїРѕР·РёС‚ Supra dVRF РїРѕ С„РѕСЂРјСѓР»Рµ РєРѕРЅС‚СЂР°РєС‚Р° Lottery")
    parser.add_argument("--max-gas-price", required=True, type=parse_u128, help="max_gas_price (u128)" )
    parser.add_argument("--max-gas-limit", required=True, type=parse_u128, help="max_gas_limit (u128)")
    parser.add_argument("--verification-gas", required=True, type=parse_u128, help="verification_gas_value (u128)")
    parser.add_argument("--margin", type=float, default=0.15, help="Р·Р°РїР°СЃ Рє РјРёРЅРёРјР°Р»СЊРЅРѕРјСѓ РґРµРїРѕР·РёС‚Сѓ (РґРѕР»СЏ, РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ 0.15 = 15%)")
    parser.add_argument("--window", type=int, default=30, help="РѕРєРЅРѕ Р·Р°РїСЂРѕСЃРѕРІ (MIN_REQUEST_WINDOW_U128, РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ 30)")
    parser.add_argument("--json", action="store_true", help="РІС‹РІРµСЃС‚Рё JSON")

    args = parser.parse_args()
    if args.margin < 0:
        parser.error("margin РЅРµ РјРѕР¶РµС‚ Р±С‹С‚СЊ РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Рј")
    if args.window <= 0:
        parser.error("window РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ РїРѕР»РѕР¶РёС‚РµР»СЊРЅС‹Рј")

    result = calculate(args.max_gas_price, args.max_gas_limit, args.verification_gas, args.margin, args.window)

    if args.json:
        print(json.dumps(result.to_json(), indent=2, ensure_ascii=False))
        return

    print("РџР°СЂР°РјРµС‚СЂС‹ Supra dVRF:")
    print(f"  max_gas_price: {result.max_gas_price:,}".replace(",", " "))
    print(f"  max_gas_limit: {result.max_gas_limit:,}".replace(",", " "))
    print(f"  verification_gas_value: {result.verification_gas_value:,}".replace(",", " "))
    print()
    print("Р Р°СЃС‡С‘С‚ РїРѕ С„РѕСЂРјСѓР»Рµ lottery::core_main_v2::calculate_min_balance:")
    print(f"  per_request_fee = max_gas_price * (max_gas_limit + verification_gas_value) = {format_amount(result.per_request_fee)}")
    print(f"  min_balance = window({result.request_window}) * per_request_fee = {format_amount(result.min_balance)}")
    if args.margin:
        print(f"  СЂРµРєРѕРјРµРЅРґРѕРІР°РЅРЅС‹Р№ РґРµРїРѕР·РёС‚ (Р·Р°РїР°СЃ {args.margin * 100:.1f}%): {format_amount(result.recommended_deposit)}")
    else:
        print("  СЂРµРєРѕРјРµРЅРґРѕРІР°РЅРЅС‹Р№ РґРµРїРѕР·РёС‚ СЃРѕРІРїР°РґР°РµС‚ СЃ min_balance (margin = 0)")


if __name__ == "__main__":
    main()

