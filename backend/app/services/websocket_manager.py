"""In-memory WebSocket connection manager for instant message push."""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from fastapi import WebSocket


class ConnectionManager:
    """Manage user_id -> WebSocket connections mapping."""

    def __init__(self) -> None:
        # user_id -> list of WebSocket connections
        self._connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, []).append(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        connections = self._connections.get(user_id, [])
        if websocket in connections:
            connections.remove(websocket)
        if not connections:
            self._connections.pop(user_id, None)

    async def send_to_user(self, user_id: int, payload: Any) -> None:
        connections = self._connections.get(user_id, [])
        if not connections:
            return
        text = json.dumps(payload, default=str)
        # Send to all active connections of the user
        for connection in connections[:]:
            try:
                await connection.send_text(text)
            except Exception:
                # Clean up stale connections lazily
                self.disconnect(user_id, connection)

    async def send_to_users(self, user_ids: List[int], payload: Any) -> None:
        for user_id in user_ids:
            await self.send_to_user(user_id, payload)


manager = ConnectionManager()
