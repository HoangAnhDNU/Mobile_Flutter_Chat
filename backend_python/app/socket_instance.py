"""
Socket.IO server instance dùng chung cho toàn bộ ứng dụng.

Tách riêng ra file này để các route (ví dụ gửi tin nhắn) có thể import và
phát (broadcast) sự kiện realtime mà không gây import vòng (circular import)
với app.main.
"""
import socketio

# Socket.IO server (ASGI mode)
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
)
