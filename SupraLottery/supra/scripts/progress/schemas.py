"""Pydantic-схемы прогресса пользователей."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class ChecklistTaskPayload(BaseModel):
    title: str = Field(..., description="Заголовок задания")
    description: str = Field(..., description="Описание шага чек-листа")
    day_index: int = Field(0, ge=0, description="Номер дня чек-листа (0 = первый день)")
    reward_kind: str = Field("none", description="Тип награды: none, ticket, bonus и т.п.")
    reward_value: dict[str, Any] | None = Field(
        default_factory=dict, description="Параметры награды"
    )
    metadata: dict[str, Any] | None = Field(
        default_factory=dict, description="Дополнительные параметры задания"
    )
    is_active: bool = Field(True, description="Признак активности задания")


class ChecklistTaskResponse(ChecklistTaskPayload):
    code: str = Field(..., description="Мнемоника задания")
    created_at: datetime
    updated_at: datetime


class ChecklistProgressResponse(BaseModel):
    task: ChecklistTaskResponse
    completed: bool
    completed_at: datetime | None
    reward_claimed: bool
    metadata: dict[str, Any] | None = None


class ChecklistStatusResponse(BaseModel):
    address: str
    tasks: list[ChecklistProgressResponse]


class ChecklistCompleteRequest(BaseModel):
    metadata: dict[str, Any] | None = Field(default=None, description="Произвольные данные выполнения")
    reward_claimed: bool | None = Field(
        default=None,
        description="Флаг, что награда выдана (для отложенных операций)",
    )


class AchievementPayload(BaseModel):
    title: str
    description: str
    points: int = Field(0, ge=0)
    metadata: dict[str, Any] | None = Field(default_factory=dict)
    is_active: bool = True


class AchievementResponse(AchievementPayload):
    code: str
    created_at: datetime
    updated_at: datetime


class AchievementProgressResponse(BaseModel):
    achievement: AchievementResponse
    unlocked: bool
    unlocked_at: datetime | None
    progress_value: int
    metadata: dict[str, Any] | None = None


class AchievementStatusResponse(BaseModel):
    address: str
    achievements: list[AchievementProgressResponse]


class AchievementUnlockRequest(BaseModel):
    progress_value: int | None = Field(default=None, ge=0)
    metadata: dict[str, Any] | None = Field(default=None)


__all__ = [
    "ChecklistTaskPayload",
    "ChecklistTaskResponse",
    "ChecklistProgressResponse",
    "ChecklistStatusResponse",
    "ChecklistCompleteRequest",
    "AchievementPayload",
    "AchievementResponse",
    "AchievementProgressResponse",
    "AchievementStatusResponse",
    "AchievementUnlockRequest",
]
