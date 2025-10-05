"""Compatibility wrappers for running SupraLottery tests from the repository root."""

from importlib import import_module
from pathlib import Path
import sys
from types import ModuleType
from typing import TYPE_CHECKING

_SUPRALOTTERY_PATH = Path(__file__).resolve().parent.parent / "SupraLottery"
if str(_SUPRALOTTERY_PATH) not in sys.path:
    sys.path.insert(0, str(_SUPRALOTTERY_PATH))


def __getattr__(name: str) -> ModuleType:
    try:
        module = import_module(f"SupraLottery.tests.{name}")
    except ModuleNotFoundError as exc:  # pragma: no cover - passthrough for pkg attrs
        raise AttributeError(f"module 'tests' has no attribute {name!r}") from exc

    globals()[name] = module
    return module


if TYPE_CHECKING:  # pragma: no cover - hints only
    from SupraLottery.tests import *  # noqa: F401,F403
