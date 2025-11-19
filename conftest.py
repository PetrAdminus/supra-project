import os
import sys
from pathlib import Path

# Ensure the in-repo SupraLottery package is importable when running tests from the
# repository root. This mirrors the editable install but keeps test runs hermetic.
PROJECT_ROOT = Path(__file__).resolve().parent
SUPRA_PACKAGE_ROOT = PROJECT_ROOT / "SupraLottery"

if SUPRA_PACKAGE_ROOT.exists():
    path_str = str(SUPRA_PACKAGE_ROOT)
    if path_str not in sys.path:
        sys.path.insert(0, path_str)
    os.environ["PYTHONPATH"] = os.pathsep.join(
        filter(None, [path_str, os.environ.get("PYTHONPATH")])
    )
