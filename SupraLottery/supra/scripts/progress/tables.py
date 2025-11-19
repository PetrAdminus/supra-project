"""ORM-модели прогресса: чек-листы и достижения."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import Boolean, ForeignKey, Integer, JSON, String
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..accounts.tables import Base
from ..lib.sqlalchemy import MetadataAliasMixin


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ChecklistTask(MetadataAliasMixin, Base):
    """Определение задания ежедневного чек-листа."""

    __tablename__ = "checklist_tasks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(240))
    description: Mapped[str] = mapped_column(String(1024))
    day_index: Mapped[int] = mapped_column(Integer, default=0, index=True)
    reward_kind: Mapped[str] = mapped_column(String(64), default="none")
    reward_value: Mapped[dict[str, Any]] = mapped_column(
        MutableDict.as_mutable(JSON), default=dict
    )
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(default=_utcnow, onupdate=_utcnow)

    progress_entries: Mapped[list["ChecklistProgress"]] = relationship(
        back_populates="task", cascade="all, delete-orphan"
    )

class ChecklistProgress(MetadataAliasMixin, Base):
    """Статус выполнения задания чек-листа пользователем."""

    __tablename__ = "checklist_progress"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    address: Mapped[str] = mapped_column(String(80), index=True)
    task_id: Mapped[int] = mapped_column(ForeignKey("checklist_tasks.id"), index=True)
    completed_at: Mapped[datetime] = mapped_column(default=_utcnow)
    reward_claimed: Mapped[bool] = mapped_column(Boolean, default=False)
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )

    task: Mapped[ChecklistTask] = relationship(
        back_populates="progress_entries", lazy="joined"
    )

class Achievement(MetadataAliasMixin, Base):
    """Определение достижения пользователя."""

    __tablename__ = "achievements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(240))
    description: Mapped[str] = mapped_column(String(1024))
    points: Mapped[int] = mapped_column(Integer, default=0)
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(default=_utcnow, onupdate=_utcnow)

    progress_entries: Mapped[list["AchievementProgress"]] = relationship(
        back_populates="achievement", cascade="all, delete-orphan", lazy="selectin"
    )

class AchievementProgress(MetadataAliasMixin, Base):
    """Статус выполнения достижения пользователем."""

    __tablename__ = "achievement_progress"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    address: Mapped[str] = mapped_column(String(80), index=True)
    achievement_id: Mapped[int] = mapped_column(ForeignKey("achievements.id"), index=True)
    progress_value: Mapped[int] = mapped_column(Integer, default=0)
    unlocked_at: Mapped[datetime | None] = mapped_column(default=None)
    _metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", MutableDict.as_mutable(JSON), default=dict
    )

    achievement: Mapped[Achievement] = relationship(
        back_populates="progress_entries", lazy="joined"
    )



__all__ = [
    "ChecklistTask",
    "ChecklistProgress",
    "Achievement",
    "AchievementProgress",
]
