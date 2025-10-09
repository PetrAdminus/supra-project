import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
SUPRA_LOTTERY_ROOT = PROJECT_ROOT / "SupraLottery"

# Ensure the embedded SupraLottery package is importable as `supra`
if SUPRA_LOTTERY_ROOT.exists():
    supra_path = str(SUPRA_LOTTERY_ROOT)
    if supra_path not in sys.path:
        sys.path.insert(0, supra_path)
