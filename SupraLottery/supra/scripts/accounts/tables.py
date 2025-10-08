"""Определения ORM-таблиц для аккаунтов пользователей."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import JSON, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.ext.mutable import MutableDict


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Account(Base):
    """Профиль пользователя платформы."""

    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    address: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    nickname: Mapped[str | None] = mapped_column(String(120), nullable=True)
    avatar_kind: Mapped[str] = mapped_column(String(32), default="none")
    avatar_value: Mapped[str | None] = mapped_column(String(512), nullable=True)
    telegram: Mapped[str | None] = mapped_column(String(128), nullable=True)
    twitter: Mapped[str | None] = mapped_column(String(128), nullable=True)
    settings: Mapped[dict[str, Any]] = mapped_column(
        MutableDict.as_mutable(JSON), default=dict
    )
    created_at: Mapped[datetime] = mapped_column(default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(default=_utcnow, onupdate=_utcnow)


__all__ = ["Base", "Account"]
