"""FastAPI-маршруты real-time сервиса (чат и объявления)."""
from __future__ import annotations

from typing import Any, Dict, Iterator, List

from fastapi import APIRouter, Depends, Query, WebSocket
from starlette.websockets import WebSocketDisconnect
from fastapi.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from ..accounts.config import get_config_from_env
from ..accounts.db import get_session, init_engine
from .manager import connection_manager
from .schemas import (
    AnnouncementPayload,
    AnnouncementView,
    ChatMessagePayload,
    ChatMessageView,
)
from .service import AnnouncementInput, MessageInput, RealtimeService

router = APIRouter(prefix="/chat", tags=["chat"])


def _model_dump(payload: Any, *, mode: str | None = None) -> Dict[str, Any]:
    """Вернуть словарь из Pydantic-модели или готового словаря."""

    if hasattr(payload, "model_dump"):
        dumper = getattr(payload, "model_dump")
        if mode is None:
            return dumper()
        return dumper(mode=mode)

    if hasattr(payload, "dict"):
        return getattr(payload, "dict")()

    if isinstance(payload, dict):
        return payload

    msg = f"Unsupported payload type for model dump: {type(payload)!r}"
    raise TypeError(msg)


def _ensure_engine() -> None:
    try:
        with get_session():
            return
    except RuntimeError:
        config = get_config_from_env()
        init_engine(config)


def _session_dependency() -> Iterator[Session]:
    _ensure_engine()
    with get_session() as session:
        yield session


@router.get("/messages", response_model=List[ChatMessageView])
async def list_messages(
    room: str = Query("global", description="Комната чата"),
    limit: int = Query(50, ge=1, le=200, description="Количество сообщений"),
    session: Session = Depends(_session_dependency),
) -> List[ChatMessageView]:
    service = RealtimeService(session)
    messages = await run_in_threadpool(service.list_messages, room, limit)
    return [ChatMessageView.model_validate(message) for message in messages]


@router.post("/messages", response_model=ChatMessageView, status_code=201)
async def post_message(
    payload: ChatMessagePayload,
    session: Session = Depends(_session_dependency),
) -> ChatMessageView:
    service = RealtimeService(session)
    message = await run_in_threadpool(
        service.create_message,
        MessageInput(
            address=payload.address,
            body=payload.body,
            room=payload.room,
            metadata=payload.metadata,
        ),
    )
    await run_in_threadpool(session.commit)
    view = ChatMessageView.model_validate(message)
    connection_manager.broadcast(view.room, _model_dump(view, mode="json"))
    return view


@router.get("/announcements", response_model=List[AnnouncementView])
async def list_announcements(
    limit: int = Query(20, ge=1, le=100, description="Количество объявлений"),
    lottery_id: str | None = Query(None, description="Фильтр по лотерее"),
    session: Session = Depends(_session_dependency),
) -> List[AnnouncementView]:
    service = RealtimeService(session)
    announcements = await run_in_threadpool(service.list_announcements, limit, lottery_id)
    return [AnnouncementView.model_validate(item) for item in announcements]


@router.post("/announcements", response_model=AnnouncementView, status_code=201)
async def post_announcement(
    payload: AnnouncementPayload,
    session: Session = Depends(_session_dependency),
) -> AnnouncementView:
    service = RealtimeService(session)
    announcement = await run_in_threadpool(
        service.create_announcement,
        AnnouncementInput(
            title=payload.title,
            body=payload.body,
            lottery_id=payload.lottery_id,
            metadata=payload.metadata,
        ),
    )
    await run_in_threadpool(session.commit)
    view = AnnouncementView.model_validate(announcement)
    connection_manager.broadcast("announcements", _model_dump(view, mode="json"))
    return view


@router.websocket("/ws/{room}")
async def websocket_endpoint(websocket: WebSocket, room: str) -> None:
    _ensure_engine()
    await connection_manager.connect(websocket, room)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await connection_manager.disconnect(websocket, room)


__all__ = ["router"]
