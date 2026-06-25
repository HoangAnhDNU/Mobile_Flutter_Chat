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
    print("🚀 Starting Mobile Flutter Chat Backend (Python)...")
    await init_db()
    # Reset toàn bộ trạng thái online về offline (tránh kẹt online cũ sau restart)
    try:
        from .database import async_session_maker
        from sqlalchemy import update
        from .models.user import User
        async with async_session_maker() as session:
            await session.execute(update(User).values(is_online=False))
            await session.commit()
    except Exception as e:
        print(f"⚠️  Không thể reset online status: {e}")
    print("✅ Database initialized")
    yield
    # Shutdown
    print("👋 Shutting down...")


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
    print(f"[SOCKET_CONNECT] sid={sid} auth={auth}")
    # Client có thể gửi token qua auth; nếu có thì set online ngay.
    token = auth.get('token') if auth else None
    if token:
        from .services.auth_service import AuthService
        user_id = AuthService.decode_token(token)
        if user_id:
            await _set_user_online(sid, user_id, True)

    # Send current online users to the newly connected client
    online_uids = set(connected_users.values())
    print(f"[SOCKET_CONNECT] online_uids={online_uids}")
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
    except Exception as e:
        print(f"⚠️  Lỗi cập nhật online status: {e}")

    # Phát cho toàn bộ client (admin + user) biết thay đổi trạng thái
    await sio.emit('presence_update', {'uid': str(uid_int), 'is_online': online})
    print(f"User {uid_int} {'online' if online else 'offline'} (sid {sid})")


@sio.event
async def user_online(sid, data):
    """Client báo đã đăng nhập/online (gửi uid)."""
    uid = data.get('uid') if isinstance(data, dict) else data
    print(f"[USER_ONLINE] sid={sid} data={data} uid={uid}")
    if uid is not None:
        await _set_user_online(sid, uid, True)
        # Send current online users to the newly online client
        online_uids = set(connected_users.values())
        print(f"[USER_ONLINE] connected_users={connected_users} online_uids={online_uids}")
        for online_uid in online_uids:
            await sio.emit('presence_update', {'uid': str(online_uid), 'is_online': True}, to=sid)


@sio.event
async def disconnect(sid):
    """Handle user disconnection"""
    user_id = connected_users.pop(sid, None)
    print(f"[SOCKET_DISCONNECT] sid={sid} user_id={user_id} remaining={connected_users}")
    if user_id is not None:
        # Báo ngừng soạn tin để tránh kẹt "đang soạn tin"
        await sio.emit('user_typing', {'uid': str(user_id), 'isTyping': False})
        # Chỉ set offline nếu không còn connection nào khác của user này
        still_connected = any(uid == user_id for uid in connected_users.values())
        print(f"[SOCKET_DISCONNECT] user_id={user_id} still_connected={still_connected}")
        if not still_connected:
            await _set_user_online(sid, user_id, False)


@sio.event
async def join_chat(sid, data):
    """Join a chat room"""
    chat_id = data.get('chat_id') if isinstance(data, dict) else data
    if chat_id:
        await sio.enter_room(sid, f"chat_{chat_id}")
        print(f"sid {sid} joined chat_{chat_id}")


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



@sio.event
async def new_message(sid, data):
    """Broadcast new message to chat room"""
    chat_id = data.get('chat_id')
    if chat_id:
        await sio.emit('new_message', data, room=f"chat_{chat_id}", skip_sid=sid)


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
