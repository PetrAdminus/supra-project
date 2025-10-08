"""Управление WebSocket-подключениями для real-time событий."""
from __future__ import annotations

import asyncio
from typing import Any, Dict, Set

from fastapi import WebSocket, WebSocketDisconnect


class ConnectionManager:
    """Отвечает за хранение и рассылку сообщений по комнатам."""

    def __init__(self) -> None:
        self._rooms: Dict[str, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, room: str) -> None:
        await websocket.accept()
        async with self._lock:
            connections = self._rooms.setdefault(room, set())
            connections.add(websocket)

    async def disconnect(self, websocket: WebSocket, room: str) -> None:
        async with self._lock:
            connections = self._rooms.get(room)
            if connections and websocket in connections:
                connections.remove(websocket)
                if not connections:
                    self._rooms.pop(room, None)

    async def _broadcast(self, room: str, payload: Dict[str, Any]) -> None:
        async with self._lock:
            connections = list(self._rooms.get(room, set()))
        for websocket in connections:
            try:
                await websocket.send_json(payload)
            except WebSocketDisconnect:
                await self.disconnect(websocket, room)
            except RuntimeError:
                # Соединение уже закрыто
                await self.disconnect(websocket, room)

    def broadcast(self, room: str, payload: Dict[str, Any]) -> None:
        """Запускает асинхронную рассылку в фоновом таске."""

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:  # pragma: no cover - нет активного цикла событий
            return
        loop.create_task(self._broadcast(room, payload))


connection_manager = ConnectionManager()

__all__ = ["connection_manager", "ConnectionManager"]
