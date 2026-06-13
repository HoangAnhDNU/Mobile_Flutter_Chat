from fastapi import APIRouter

from .auth import router as auth_router
from .user import router as user_router
from .chat import router as chat_router
from .admin import router as admin_router
from .friend import router as friend_router
from .image import router as image_router

api_router = APIRouter()

api_router.include_router(auth_router, prefix="/auth", tags=["Authentication"])
api_router.include_router(user_router, prefix="/user", tags=["User"])
api_router.include_router(chat_router, prefix="/chat", tags=["Chat"])
api_router.include_router(admin_router, prefix="/admin", tags=["Admin"])
api_router.include_router(friend_router, prefix="/friend", tags=["Friend"])
api_router.include_router(image_router)
