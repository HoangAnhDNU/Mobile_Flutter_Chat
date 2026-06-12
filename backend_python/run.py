"""
Entry point để chạy server
Chạy: python run.py
"""
import uvicorn
from app.config import settings

if __name__ == "__main__":
    uvicorn.run(
        "app.main:socket_app",  # Sử dụng socket_app để có WebSocket
        host=settings.server_host,
        port=settings.server_port,
        reload=True,  # Hot reload trong development
        log_level="info"
    )
