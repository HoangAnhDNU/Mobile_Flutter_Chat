"""
Entry point để chạy server
Chạy: python run.py
"""
import uvicorn
from app.config import settings

if __name__ == "__main__":
    # Cho phep nhan payload lon (voice/image base64 co the vai MB).
    # Tang h11_max_incomplete_event_size de socket.io khong cat giu lieu khi emit.
    uvicorn.run(
        "app.main:socket_app",  # Su dung socket_app de co WebSocket
        host=settings.server_host,
        port=settings.server_port,
        reload=True,  # Hot reload trong development
        log_level="info",
        access_log=False,
        timeout_keep_alive=60,
        h11_max_incomplete_event_size=32 * 1024 * 1024,  # 32MB
    )
