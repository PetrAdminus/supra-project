"""SQLAlchemy-таблицы real-time сервиса (чат и объявления)."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import JSON, Integer, String, Text
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column

from ..accounts.tables import Base
from ..lib.sqlalchemy import MetadataAliasMixin


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ChatMessage(MetadataAliasMixin, Base):
    """Сообщение в глобальном или лотерейном чате."""

    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room: Mapped[str] = mapped_column(String(64), index=True)
    sender_address: Mapped[str] = mapped_column(String(80), index=True)
    body: Mapped[str] = mapped_column(Text)
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )
    created_at: Mapped[datetime] = mapped_column(default=_utcnow, index=True)


class Announcement(MetadataAliasMixin, Base):
    """Объявление о новой лотерее или результате."""

    __tablename__ = "lottery_announcements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(Text)
    lottery_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )
    created_at: Mapped[datetime] = mapped_column(default=_utcnow, index=True)


__all__ = ["ChatMessage", "Announcement"]
