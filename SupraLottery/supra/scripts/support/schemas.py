"""Pydantic-схемы центра поддержки."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class SupportArticleCreate(BaseModel):
    slug: str = Field(description="Уникальный идентификатор статьи")
    title: str = Field(description="Заголовок статьи")
    body: str = Field(description="Markdown-содержимое")
    locale: str = Field(default="ru", description="Локаль статьи (ru/en/…)")
    tags: dict[str, Any] = Field(default_factory=dict, description="Дополнительные метаданные")


class SupportArticleResponse(BaseModel):
    slug: str
    title: str
    body: str
    locale: str
    tags: dict[str, Any]
    created_at: datetime
    updated_at: datetime


class SupportArticleListResponse(BaseModel):
    articles: list[SupportArticleResponse]


class SupportTicketCreate(BaseModel):
    address: str = Field(description="Адрес Supra пользователя")
    email: str | None = Field(default=None, description="Обратный e-mail для ответа")
    subject: str = Field(description="Тема обращения")
    body: str = Field(description="Текст обращения")
    metadata: dict[str, Any] = Field(default_factory=dict, description="Дополнительные данные (например, ID лотереи)")


class SupportTicketResponse(BaseModel):
    id: int
    status: str
    created_at: datetime


__all__ = [
    "SupportArticleCreate",
    "SupportArticleResponse",
    "SupportArticleListResponse",
    "SupportTicketCreate",
    "SupportTicketResponse",
]
