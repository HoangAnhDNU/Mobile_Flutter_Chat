from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio
from contextlib import asynccontextmanager

from .config import settings
from .database import init_db
from .routes import api_router
from .socket_instance import sio


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events"""
    # Startup
    await init_db()
    # Reset toàn bộ trạng thái online về offline (tránh kẹt online cũ sau restart)
    try:
        from .database import async_session_maker
        from sqlalchemy import update
        from .models.user import User
        async with async_session_maker() as session:
            await session.execute(update(User).values(is_online=False))
            await session.commit()
    except Exception:
        pass
    yield
    # Shutdown
    print("Shutting down...")


# FastAPI app
app = FastAPI(
    title="Mobile Flutter Chat API",
    description="API Backend cho ứng dụng chat Flutter - Viết bằng Python/FastAPI",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(api_router, prefix="/api")


# ==================== SOCKET.IO EVENTS ====================

# Store connected users
connected_users: dict = {}


@sio.event
async def connect(sid, environ, auth):
    """Handle user connection"""
    # Client có thể gửi token qua auth; nếu có thì set online ngay.
    token = auth.get('token') if auth else None
    if token:
        from .services.auth_service import AuthService
        user_id = AuthService.decode_token(token)
        if user_id:
            await _set_user_online(sid, user_id, True)

    # Send current online users to the newly connected client
    online_uids = set(connected_users.values())
    for uid in online_uids:
        await sio.emit('presence_update', {'uid': str(uid), 'is_online': True}, to=sid)


async def _set_user_online(sid, user_id, online: bool):
    """Cập nhật trạng thái online trong DB và phát sự kiện presence_update."""
    from .database import async_session_maker
    from .models.user import User
    from sqlalchemy import select

    try:
        uid_int = int(user_id)
    except (TypeError, ValueError):
        return

    if online:
        connected_users[sid] = uid_int
        await sio.enter_room(sid, f"user_{uid_int}")

    try:
        async with async_session_maker() as session:
            result = await session.execute(select(User).where(User.id == uid_int))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = online
                from datetime import datetime
                user.last_seen = datetime.utcnow()
                await session.commit()
    except Exception:
        pass

    # Phát cho toàn bộ client (admin + user) biết thay đổi trạng thái
    await sio.emit('presence_update', {'uid': str(uid_int), 'is_online': online})


@sio.event
async def user_online(sid, data):
    """Client báo đã đăng nhập/online (gửi uid)."""
    uid = data.get('uid') if isinstance(data, dict) else data
    if uid is not None:
        await _set_user_online(sid, uid, True)
        # Send current online users to the newly online client
        online_uids = set(connected_users.values())
        for online_uid in online_uids:
            await sio.emit('presence_update', {'uid': str(online_uid), 'is_online': True}, to=sid)


@sio.event
async def disconnect(sid):
    """Handle user disconnection"""
    user_id = connected_users.pop(sid, None)
    if user_id is not None:
        # Báo ngừng soạn tin để tránh kẹt "đang soạn tin"
        await sio.emit('user_typing', {'uid': str(user_id), 'isTyping': False})
        # Chỉ set offline nếu không còn connection nào khác của user này
        still_connected = any(uid == user_id for uid in connected_users.values())
        if not still_connected:
            await _set_user_online(sid, user_id, False)


@sio.event
async def join_chat(sid, data):
    """Join a chat room"""
    chat_id = data.get('chat_id') if isinstance(data, dict) else data
    if chat_id:
        await sio.enter_room(sid, f"chat_{chat_id}")


@sio.event
async def leave_chat(sid, data):
    """Leave a chat room"""
    chat_id = data.get('chat_id') if isinstance(data, dict) else data
    if chat_id:
        # Khi rời phòng, báo cho đối phương biết đã ngừng soạn tin
        uid = connected_users.get(sid)
        if uid is not None:
            await sio.emit('user_typing', {
                'chatId': chat_id,
                'uid': str(uid),
                'isTyping': False,
            }, room=f"chat_{chat_id}", skip_sid=sid)
        await sio.leave_room(sid, f"chat_{chat_id}")



# new_message is handled by the API route which emits to all participants.
# No socket handler needed here to avoid duplicate emissions.


@sio.event
async def typing(sid, data):
    """Broadcast typing indicator"""
    if not isinstance(data, dict):
        return
    chat_id = data.get('chatId') or data.get('chat_id')
    uid = data.get('uid') or connected_users.get(sid)
    is_typing = data.get('isTyping')
    if is_typing is None:
        is_typing = data.get('is_typing', True)
    if chat_id is not None and uid is not None:
        # Phát lại theo định dạng camelCase mà Flutter đang lắng nghe
        await sio.emit('user_typing', {
            'chatId': chat_id,
            'uid': uid,
            'isTyping': is_typing,
        }, room=f"chat_{chat_id}", skip_sid=sid)


@sio.event
async def message_read(sid, data):
    """Notify message read"""
    chat_id = data.get('chat_id')
    message_id = data.get('message_id')
    user_id = connected_users.get(sid)
    if chat_id and user_id:
        await sio.emit('message_read', {
            'chat_id': chat_id,
            'message_id': message_id,
            'user_id': user_id
        }, room=f"chat_{chat_id}", skip_sid=sid)


# Mount Socket.IO
socket_app = socketio.ASGIApp(sio, app)


# ==================== WEBRTC CALL SIGNALING ====================

@sio.event
async def call_offer(sid, data):
    """Caller sends SDP offer to callee."""
    if not isinstance(data, dict):
        return
    target_uid = data.get('targetUid')
    caller_uid = connected_users.get(sid)
    if target_uid and caller_uid:
        payload = {
            'fromUid': str(caller_uid),
            'toUid': str(target_uid),
            'isVideo': data.get('isVideo', False),
            'callerName': data.get('callerName', ''),
            'callerAvatar': data.get('callerAvatar'),
            'sdp': data.get('sdp'),
        }
        await sio.emit('call_offer', payload, room=f"user_{target_uid}")
    # else: missing target_uid or caller_uid


@sio.event
async def call_answer(sid, data):
    """Callee sends SDP answer back to caller."""
    if not isinstance(data, dict):
        return
    target_uid = data.get('targetUid')
    callee_uid = connected_users.get(sid)
    if target_uid and callee_uid:
        target_sids = [s for s, uid in connected_users.items() if str(uid) == str(target_uid)]
        payload = {'fromUid': str(callee_uid), 'sdp': data.get('sdp')}
        for target_sid in target_sids:
            await sio.emit('call_answer', payload, to=target_sid)


@sio.event
async def call_ice_candidate(sid, data):
    """Exchange ICE candidates between peers."""
    if not isinstance(data, dict):
        return
    target_uid = data.get('targetUid')
    sender_uid = connected_users.get(sid)
    if target_uid and sender_uid:
        target_sids = [s for s, uid in connected_users.items() if str(uid) == str(target_uid)]
        payload = {'fromUid': str(sender_uid), 'candidate': data.get('candidate')}
        for target_sid in target_sids:
            await sio.emit('call_ice_candidate', payload, to=target_sid)


@sio.event
async def call_end(sid, data):
    """Either party ends the call."""
    if not isinstance(data, dict):
        return
    target_uid = data.get('targetUid')
    sender_uid = connected_users.get(sid)
    if target_uid and sender_uid:
        target_sids = [s for s, uid in connected_users.items() if str(uid) == str(target_uid)]
        payload = {'fromUid': str(sender_uid)}
        for target_sid in target_sids:
            await sio.emit('call_end', payload, to=target_sid)

@sio.event
async def call_reject(sid, data):
    """Callee rejects the incoming call."""
    if not isinstance(data, dict):
        return
    target_uid = data.get('targetUid')
    sender_uid = connected_users.get(sid)
    if target_uid and sender_uid:
        target_sids = [s for s, uid in connected_users.items() if str(uid) == str(target_uid)]
        payload = {'fromUid': str(sender_uid)}
        for target_sid in target_sids:
            await sio.emit('call_reject', payload, to=target_sid)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Mobile Flutter Chat API",
        "version": "2.0.0",
        "framework": "FastAPI",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}
