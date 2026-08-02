"""WebSocket endpoint for instant message push."""

from __future__ import annotations

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from jose import JWTError, jwt

from app.config import get_settings
from app.services.websocket_manager import manager

router = APIRouter(tags=["websocket"])

settings = get_settings()


def _decode_token(token: str) -> int | None:
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.algorithm],
        )
        user_id = payload.get("sub")
        if user_id is None:
            return None
        return int(user_id)
    except (JWTError, ValueError, TypeError):
        return None


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """Authenticated WebSocket connection for real-time messages."""
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id = _decode_token(token)
    if user_id is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(user_id, websocket)
    try:
        while True:
            # Keep the connection alive; clients may send ping/ack messages
            data = await websocket.receive_text()
            # Echo back a simple ack for future extension
            await websocket.send_text('{"type":"ack"}')
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception:
        manager.disconnect(user_id, websocket)
