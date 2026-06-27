from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from typing import Optional

from ..database import get_db
from ..dependencies import get_current_user
from ..models.user import User
from ..models.block import BlockedUser
from ..models.friendship import Friendship

router = APIRouter(prefix="/block", tags=["Block"])


class BlockRequest(BaseModel):
    user_id: str
    report_reason: Optional[str] = None


@router.post("", response_model=dict)
async def block_user(
    request: BlockRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Chặn người dùng (kèm optional report)"""
    blocked_id = int(request.user_id)
    if blocked_id == current_user.id:
        raise HTTPException(status_code=400, detail="Không thể chặn chính mình")

    # Check already blocked
    existing = await db.execute(
        select(BlockedUser).where(
            and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id == blocked_id)
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Đã chặn người dùng này rồi")

    block = BlockedUser(
        blocker_id=current_user.id,
        blocked_id=blocked_id,
        report_reason=request.report_reason,
    )
    db.add(block)

    # Hủy kết bạn nếu có
    friendship = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.requester_id == current_user.id, Friendship.addressee_id == blocked_id),
                and_(Friendship.requester_id == blocked_id, Friendship.addressee_id == current_user.id),
            )
        )
    )
    fr = friendship.scalar_one_or_none()
    if fr:
        await db.delete(fr)

    await db.commit()
    return {"message": "Đã chặn người dùng", "block": {"id": str(block.id), "blocked_id": str(block.blocked_id)}}


@router.delete("/{user_id}", response_model=dict)
async def unblock_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Bỏ chặn người dùng"""
    result = await db.execute(
        select(BlockedUser).where(
            and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id == user_id)
        )
    )
    block = result.scalar_one_or_none()
    if not block:
        raise HTTPException(status_code=404, detail="Chưa chặn người dùng này")

    await db.delete(block)
    await db.commit()
    return {"message": "Đã bỏ chặn người dùng"}


@router.get("", response_model=dict)
async def get_blocked_users(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách người dùng đã chặn"""
    result = await db.execute(
        select(BlockedUser)
        .where(BlockedUser.blocker_id == current_user.id)
        .options(selectinload(BlockedUser.blocked))
    )
    blocks = result.scalars().all()
    return {"blocked_users": [b.to_dict() for b in blocks]}


@router.get("/check/{user_id}", response_model=dict)
async def check_block_status(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Kiểm tra trạng thái chặn giữa current user và user_id"""
    # Did current user block user_id?
    i_blocked = await db.execute(
        select(BlockedUser).where(
            and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id == user_id)
        )
    )
    # Did user_id block current user?
    they_blocked = await db.execute(
        select(BlockedUser).where(
            and_(BlockedUser.blocker_id == user_id, BlockedUser.blocked_id == current_user.id)
        )
    )
    return {
        "i_blocked_them": i_blocked.scalar_one_or_none() is not None,
        "they_blocked_me": they_blocked.scalar_one_or_none() is not None,
    }
