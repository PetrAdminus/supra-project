"""Вспомогательные утилиты для моделей SQLAlchemy."""
from __future__ import annotations

from typing import Any, Protocol


class HasMetadataField(Protocol):
    """Протоколоподобный базовый класс для подсказки типов."""

    metadata_: dict[str, Any]


def metadata_property(field_name: str = "metadata_") -> property:
    """Вернуть свойство, делегирующее доступ к JSON-колонке ``metadata``.

    Declarative API резервирует имя ``metadata`` — используем фактическое поле
    ``metadata_`` и пробрасываем его наружу как обычное ``property``.
    """

    def getter(self: HasMetadataField) -> dict[str, Any]:
        return getattr(self, field_name)

    def setter(self: HasMetadataField, value: dict[str, Any]) -> None:
        setattr(self, field_name, value)

    return property(getter, setter)


__all__ = ["metadata_property"]
