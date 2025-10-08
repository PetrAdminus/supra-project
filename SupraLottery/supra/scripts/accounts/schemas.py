"""Pydantic-схемы для API аккаунтов."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class AvatarPayload(BaseModel):
    """Описание аватара пользователя."""

    kind: str = Field(description="Тип аватара: internal, external, crystara и т.п.")
    value: Optional[str] = Field(
        default=None, description="Значение (URL, идентификатор NFT и т.д.)"
    )


class AccountProfileUpdate(BaseModel):
    """Поля для обновления профиля."""

    nickname: Optional[str] = Field(default=None, description="Отображаемое имя")
    avatar: Optional[AvatarPayload] = Field(default=None, description="Информация об аватаре")
    telegram: Optional[str] = Field(default=None, description="Ник Telegram")
    twitter: Optional[str] = Field(default=None, description="Ник Twitter/X")
    settings: Optional[dict[str, Any]] = Field(
        default=None, description="Дополнительные настройки (JSON)"
    )


class AccountProfile(BaseModel):
    """Полная информация о профиле."""

    model_config = ConfigDict(from_attributes=True)

    address: str = Field(description="Блокчейн-адрес пользователя")
    nickname: Optional[str] = Field(default=None, description="Отображаемое имя")
    avatar_kind: str = Field(description="Тип аватара")
    avatar_value: Optional[str] = Field(default=None, description="Данные аватара")
    telegram: Optional[str] = Field(default=None, description="Ник Telegram")
    twitter: Optional[str] = Field(default=None, description="Ник Twitter")
    settings: dict[str, Any] = Field(default_factory=dict, description="Дополнительные настройки")
    created_at: datetime = Field(description="Метка создания")
    updated_at: datetime = Field(description="Метка обновления")


__all__ = ["AvatarPayload", "AccountProfileUpdate", "AccountProfile"]
