from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select as sa_select

from ..database import get_db
from ..models.user import User
from ..models.notification_settings import UserNotificationSettings, AVAILABLE_MESSAGE_SOUNDS, AVAILABLE_CALL_SOUNDS
from ..dependencies import get_current_user

router = APIRouter()


@router.get("/notification-settings")
async def get_notification_settings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy cài đặt thông báo của user hiện tại"""
    result = await db.execute(
        sa_select(UserNotificationSettings).where(
            UserNotificationSettings.user_id == current_user.id
        )
    )
    settings = result.scalar_one_or_none()
    
    if not settings:
        # Tạo settings mặc định nếu chưa có
        settings = UserNotificationSettings(
            user_id=current_user.id,
            message_sound="default",
            call_sound="default",
            is_message_vibration=True,
            is_call_vibration=True,
            is_message_preview=True,
        )
        db.add(settings)
        await db.commit()
        await db.refresh(settings)
    
    return {
        "settings": settings.to_dict(),
        "available_message_sounds": AVAILABLE_MESSAGE_SOUNDS,
        "available_call_sounds": AVAILABLE_CALL_SOUNDS,
    }


@router.put("/notification-settings")
async def update_notification_settings(
    message_sound: str | None = None,
    call_sound: str | None = None,
    is_message_vibration: bool | None = None,
    is_call_vibration: bool | None = None,
    is_message_preview: bool | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Cập nhật cài đặt thông báo của user hiện tại"""
    from datetime import datetime
    
    result = await db.execute(
        sa_select(UserNotificationSettings).where(
            UserNotificationSettings.user_id == current_user.id
        )
    )
    settings = result.scalar_one_or_none()
    
    if not settings:
        settings = UserNotificationSettings(
            user_id=current_user.id,
            message_sound=message_sound or "default",
            call_sound=call_sound or "default",
            is_message_vibration=is_message_vibration if is_message_vibration is not None else True,
            is_call_vibration=is_call_vibration if is_call_vibration is not None else True,
            is_message_preview=is_message_preview if is_message_preview is not None else True,
        )
        db.add(settings)
    else:
        if message_sound is not None:
            settings.message_sound = message_sound
        if call_sound is not None:
            settings.call_sound = call_sound
        if is_message_vibration is not None:
            settings.is_message_vibration = is_message_vibration
        if is_call_vibration is not None:
            settings.is_call_vibration = is_call_vibration
        if is_message_preview is not None:
            settings.is_message_preview = is_message_preview
        settings.updated_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(settings)
    
    return {
        "ok": True,
        "settings": settings.to_dict(),
    }


@router.get("/notification-sounds")
async def get_available_sounds(
    current_user: User = Depends(get_current_user),
):
    """Lấy danh sách các âm thanh có sẵn"""
    return {
        "message_sounds": AVAILABLE_MESSAGE_SOUNDS,
        "call_sounds": AVAILABLE_CALL_SOUNDS,
    }
