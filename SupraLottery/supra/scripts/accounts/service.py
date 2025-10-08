"""Сервисный слой для работы с профилями пользователей."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from .tables import Account


def _normalize_address(address: str) -> str:
    normalized = address.strip()
    if not normalized:
        raise ValueError("Адрес не может быть пустым")
    return normalized.lower()


@dataclass(slots=True)
class AvatarUpdate:
    kind: Optional[str] = None
    value: Optional[str] = None


@dataclass(slots=True)
class ProfileUpdate:
    nickname: Optional[str] = None
    avatar: Optional[AvatarUpdate] = None
    telegram: Optional[str] = None
    twitter: Optional[str] = None
    settings: Optional[dict[str, Any]] = None


class AccountsService:
    """Инкапсулирует операции над профилями."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get_account(self, address: str) -> Account | None:
        stmt = select(Account).where(Account.address == _normalize_address(address))
        return self._session.execute(stmt).scalar_one_or_none()

    def upsert_account(self, address: str, update: ProfileUpdate) -> Account:
        normalized = _normalize_address(address)
        stmt = select(Account).where(Account.address == normalized)
        account = self._session.execute(stmt).scalar_one_or_none()

        if account is None:
            account = Account(address=normalized)
            self._session.add(account)

        if update.nickname is not None:
            account.nickname = update.nickname.strip() or None
        if update.avatar is not None:
            if update.avatar.kind is not None:
                account.avatar_kind = update.avatar.kind
            if update.avatar.value is not None:
                account.avatar_value = update.avatar.value
        if update.telegram is not None:
            account.telegram = update.telegram.strip() or None
        if update.twitter is not None:
            account.twitter = update.twitter.strip() or None
        if update.settings is not None:
            account.settings = dict(update.settings)

        self._session.flush()
        return account


__all__ = ["AccountsService", "ProfileUpdate", "AvatarUpdate"]
