"""Real-time коммуникации: чат и объявления."""

from .router import router
from .manager import connection_manager

__all__ = ["router", "connection_manager"]
