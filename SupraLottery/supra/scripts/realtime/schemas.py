"""Pydantic-схемы для real-time API."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel, Field


class ChatMessagePayload(BaseModel):
    address: str = Field(description="Адрес отправителя сообщения")
    body: str = Field(description="Текст сообщения", min_length=1, max_length=2000)
    room: str | None = Field(default="global", description="Комната чата")
    metadata: Dict[str, Any] | None = Field(default=None, description="Дополнительные поля")


class ChatMessageView(BaseModel):
    id: int
    room: str
    sender_address: str
    body: str
    metadata: Dict[str, Any]
    created_at: datetime

    model_config = {"from_attributes": True}


class AnnouncementPayload(BaseModel):
    title: str = Field(description="Заголовок объявления", min_length=1, max_length=200)
    body: str = Field(description="Текст объявления", min_length=1)
    lottery_id: Optional[str] = Field(default=None, description="Идентификатор лотереи, если применимо")
    metadata: Dict[str, Any] | None = Field(default=None)


class AnnouncementView(BaseModel):
    id: int
    title: str
    body: str
    lottery_id: Optional[str]
    metadata: Dict[str, Any]
    created_at: datetime

    model_config = {"from_attributes": True}


__all__ = [
    "ChatMessagePayload",
    "ChatMessageView",
    "AnnouncementPayload",
    "AnnouncementView",
]
