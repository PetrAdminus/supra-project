"""Утилиты для SQLAlchemy-моделей, используемых в скриптах SupraLottery."""
from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Mapped


class MetadataAliasMixin:
    """Сохраняет доступ к колонке ``metadata`` без теней ``Base.metadata``."""

    _metadata: Mapped[dict[str, Any]]

    def __getattribute__(self, name: str):  # type: ignore[override]
        if name == "metadata":
            return object.__getattribute__(self, "_metadata")
        return super().__getattribute__(name)

    def __setattr__(self, name: str, value: Any):  # type: ignore[override]
        if name == "metadata":
            name = "_metadata"
        super().__setattr__(name, value)


__all__ = ["MetadataAliasMixin"]
