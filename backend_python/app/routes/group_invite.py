from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
import secrets

from ..database import get_db
from ..dependencies import get_current_user
from ..models.user import User
from ..models.chat import Chat, ChatParticipant
from ..models.group_invite import GroupInvite

router = APIRouter(prefix="/invite", tags=["Group Invite"])


@router.post("/{chat_id}", response_model=dict)
async def create_invite_link(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tạo link mời nhóm (chỉ admin nhóm)"""
    # Check admin of group
    result = await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
                ChatParticipant.role == "admin"
            )
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Chỉ admin nhóm mới tạo được link mời")

    # Deactivate old invites
    old_invites = await db.execute(
        select(GroupInvite).where(
            and_(GroupInvite.chat_id == chat_id, GroupInvite.is_active == True)
        )
    )
    for invite in old_invites.scalars().all():
        invite.is_active = False

    # Create new
    invite = GroupInvite(
        chat_id=chat_id,
        code=secrets.token_urlsafe(16),
        created_by=current_user.id,
    )
    db.add(invite)
    await db.flush()
    await db.refresh(invite)
    return {"invite": invite.to_dict()}


@router.get("/{chat_id}", response_model=dict)
async def get_invite_link(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy link mời hiện tại của nhóm"""
    result = await db.execute(
        select(GroupInvite).where(
            and_(GroupInvite.chat_id == chat_id, GroupInvite.is_active == True)
        )
    )
    invite = result.scalar_one_or_none()
    if not invite:
        return {"invite": None}
    return {"invite": invite.to_dict()}


@router.delete("/{chat_id}", response_model=dict)
async def revoke_invite_link(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Vô hiệu hóa link mời"""
    result = await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
                ChatParticipant.role == "admin"
            )
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Chỉ admin nhóm")

    invites = await db.execute(
        select(GroupInvite).where(
            and_(GroupInvite.chat_id == chat_id, GroupInvite.is_active == True)
        )
    )
    for invite in invites.scalars().all():
        invite.is_active = False
    return {"message": "Đã vô hiệu hóa link mời"}


@router.post("/join/{code}", response_model=dict)
async def join_via_invite(
    code: str = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tham gia nhóm qua link mời"""
    result = await db.execute(
        select(GroupInvite).where(
            and_(GroupInvite.code == code, GroupInvite.is_active == True)
        )
    )
    invite = result.scalar_one_or_none()
    if not invite:
        raise HTTPException(status_code=404, detail="Link mời không hợp lệ hoặc đã hết hạn")

    # Check already member
    existing = await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == invite.chat_id,
                ChatParticipant.user_id == current_user.id
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Bạn đã là thành viên nhóm này")

    participant = ChatParticipant(
        chat_id=invite.chat_id,
        user_id=current_user.id,
        role="member"
    )
    db.add(participant)
    return {"message": "Đã tham gia nhóm", "chat_id": str(invite.chat_id)}
