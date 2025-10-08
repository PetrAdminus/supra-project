"""Сервисный слой real-time коммуникаций."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List, Optional

from sqlalchemy import Select, desc, select
from sqlalchemy.orm import Session

from .tables import Announcement, ChatMessage


def _normalize_room(room: str | None) -> str:
    value = (room or "global").strip()
    if not value:
        return "global"
    return value.lower()


def _normalize_address(address: str) -> str:
    normalized = address.strip()
    if not normalized:
        raise ValueError("Адрес отправителя не может быть пустым")
    return normalized.lower()


@dataclass(slots=True)
class MessageInput:
    address: str
    body: str
    room: str | None = None
    metadata: dict | None = None


@dataclass(slots=True)
class AnnouncementInput:
    title: str
    body: str
    lottery_id: str | None = None
    metadata: dict | None = None


class RealtimeService:
    """Работа с чат-сообщениями и объявлениями."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def create_message(self, payload: MessageInput) -> ChatMessage:
        message = ChatMessage(
            room=_normalize_room(payload.room),
            sender_address=_normalize_address(payload.address),
            body=payload.body.strip(),
            metadata=dict(payload.metadata or {}),
        )
        self._session.add(message)
        self._session.flush()
        return message

    def list_messages(self, room: str, limit: int = 50) -> List[ChatMessage]:
        stmt: Select[tuple[ChatMessage]] = (
            select(ChatMessage)
            .where(ChatMessage.room == _normalize_room(room))
            .order_by(desc(ChatMessage.id))
            .limit(max(1, min(limit, 200)))
        )
        rows: Iterable[ChatMessage] = self._session.execute(stmt).scalars()
        items = list(rows)
        items.reverse()
        return items

    def create_announcement(self, payload: AnnouncementInput) -> Announcement:
        announcement = Announcement(
            title=payload.title.strip(),
            body=payload.body.strip(),
            lottery_id=payload.lottery_id.strip() if payload.lottery_id else None,
            metadata=dict(payload.metadata or {}),
        )
        self._session.add(announcement)
        self._session.flush()
        return announcement

    def list_announcements(self, limit: int = 20, lottery_id: Optional[str] = None) -> List[Announcement]:
        stmt: Select[tuple[Announcement]] = select(Announcement)
        if lottery_id:
            stmt = stmt.where(Announcement.lottery_id == lottery_id.strip())
        stmt = stmt.order_by(desc(Announcement.id)).limit(max(1, min(limit, 100)))
        rows: Iterable[Announcement] = self._session.execute(stmt).scalars()
        items = list(rows)
        items.reverse()
        return items


__all__ = [
    "RealtimeService",
    "MessageInput",
    "AnnouncementInput",
]
