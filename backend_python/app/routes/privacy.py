from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional

from ..database import get_db
from ..dependencies import get_current_user
from ..models.user import User
from ..models.privacy import UserPrivacy

router = APIRouter(prefix="/privacy", tags=["Privacy"])


class PrivacyUpdateRequest(BaseModel):
    show_last_seen: Optional[str] = None  # everyone, friends, nobody
    show_avatar: Optional[str] = None  # everyone, friends, nobody
    show_read_receipts: Optional[str] = None  # everyone, friends, nobody (stored as bool for now)
    disappearing_messages: Optional[int] = None  # 0, 86400, 604800, 7776000


@router.get("", response_model=dict)
async def get_privacy_settings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy cài đặt quyền riêng tư"""
    result = await db.execute(
        select(UserPrivacy).where(UserPrivacy.user_id == current_user.id)
    )
    privacy = result.scalar_one_or_none()
    if not privacy:
        # Create default
        privacy = UserPrivacy(user_id=current_user.id)
        db.add(privacy)
        await db.flush()
        await db.refresh(privacy)
        await db.commit()
    return {"privacy": privacy.to_dict()}


@router.put("", response_model=dict)
async def update_privacy_settings(
    request: PrivacyUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Cập nhật cài đặt quyền riêng tư"""
    result = await db.execute(
        select(UserPrivacy).where(UserPrivacy.user_id == current_user.id)
    )
    privacy = result.scalar_one_or_none()
    if not privacy:
        privacy = UserPrivacy(user_id=current_user.id)
        db.add(privacy)
        await db.flush()
        await db.refresh(privacy)

    if request.show_last_seen is not None:
        privacy.show_last_seen = request.show_last_seen
    if request.show_avatar is not None:
        privacy.show_avatar = request.show_avatar
    if request.show_read_receipts is not None:
        # Accept both bool and string for backward compat
        rr = request.show_read_receipts
        if isinstance(rr, bool):
            privacy.show_read_receipts = rr
        elif isinstance(rr, str):
            privacy.show_read_receipts = rr != 'nobody'
    if request.disappearing_messages is not None:
        privacy.disappearing_messages = request.disappearing_messages

    await db.commit()
    return {"privacy": privacy.to_dict()}
