"""
Routes quản lý bạn bè: gửi lời mời (qua email), chấp nhận/từ chối,
danh sách bạn bè, danh sách lời mời đang chờ.
"""
from fastapi import APIRouter, Depends, Path, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from pydantic import BaseModel

from ..database import get_db
from ..dependencies import get_current_user
from ..models.user import User
from ..models.friendship import Friendship

router = APIRouter()


class SendFriendRequest(BaseModel):
    email: str


async def _friendship_between(db: AsyncSession, a: int, b: int) -> Friendship | None:
    """Tìm quan hệ kết bạn (bất kể chiều) giữa 2 user."""
    return (await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.requester_id == a, Friendship.addressee_id == b),
                and_(Friendship.requester_id == b, Friendship.addressee_id == a),
            )
        )
    )).scalar_one_or_none()


@router.post("/request", response_model=dict)
async def send_friend_request(
    request: SendFriendRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Gửi lời mời kết bạn theo email."""
    email = request.email.strip().lower()
    target = (await db.execute(
        select(User).where(User.email == email)
    )).scalar_one_or_none()

    if not target:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng với email này")
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail="Không thể tự kết bạn với chính mình")

    existing = await _friendship_between(db, current_user.id, target.id)
    if existing:
        if existing.status == "accepted":
            raise HTTPException(status_code=400, detail="Hai bạn đã là bạn bè")
        raise HTTPException(status_code=400, detail="Đã tồn tại lời mời kết bạn")

    db.add(Friendship(requester_id=current_user.id, addressee_id=target.id, status="pending"))
    await db.commit()
    return {"message": f"Đã gửi lời mời kết bạn tới {target.display_name}"}


@router.post("/{friendship_id}/accept", response_model=dict)
async def accept_request(
    friendship_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Chấp nhận lời mời kết bạn (chỉ người nhận)."""
    fr = (await db.execute(
        select(Friendship).where(Friendship.id == friendship_id)
    )).scalar_one_or_none()
    if not fr:
        raise HTTPException(status_code=404, detail="Không tìm thấy lời mời")
    if fr.addressee_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bạn không có quyền với lời mời này")
    fr.status = "accepted"
    await db.commit()
    return {"message": "Đã chấp nhận lời mời kết bạn"}


@router.post("/{friendship_id}/reject", response_model=dict)
async def reject_request(
    friendship_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Từ chối / hủy lời mời (người nhận hoặc người gửi đều xóa được)."""
    fr = (await db.execute(
        select(Friendship).where(Friendship.id == friendship_id)
    )).scalar_one_or_none()
    if not fr:
        raise HTTPException(status_code=404, detail="Không tìm thấy lời mời")
    if current_user.id not in (fr.addressee_id, fr.requester_id):
        raise HTTPException(status_code=403, detail="Bạn không có quyền với lời mời này")
    await db.delete(fr)
    await db.commit()
    return {"message": "Đã xử lý lời mời"}


@router.delete("/{user_id}", response_model=dict)
async def unfriend(
    user_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Hủy kết bạn với một người."""
    fr = await _friendship_between(db, current_user.id, user_id)
    if not fr:
        raise HTTPException(status_code=404, detail="Hai bạn chưa kết bạn")
    await db.delete(fr)
    await db.commit()
    return {"message": "Đã hủy kết bạn"}


@router.get("/list", response_model=dict)
async def list_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Danh sách bạn bè đã kết bạn."""
    rows = (await db.execute(
        select(Friendship).where(
            and_(
                Friendship.status == "accepted",
                or_(
                    Friendship.requester_id == current_user.id,
                    Friendship.addressee_id == current_user.id,
                ),
            )
        )
    )).scalars().all()

    friends = []
    for fr in rows:
        other_id = fr.addressee_id if fr.requester_id == current_user.id else fr.requester_id
        u = (await db.execute(select(User).where(User.id == other_id))).scalar_one_or_none()
        if u:
            friends.append(u.to_dict(include_email=True))
    return {"friends": friends, "total": len(friends)}


@router.get("/requests", response_model=dict)
async def list_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Danh sách lời mời kết bạn đang chờ mình xử lý."""
    rows = (await db.execute(
        select(Friendship).where(
            and_(
                Friendship.status == "pending",
                Friendship.addressee_id == current_user.id,
            )
        )
    )).scalars().all()

    requests = []
    for fr in rows:
        u = (await db.execute(select(User).where(User.id == fr.requester_id))).scalar_one_or_none()
        if u:
            d = u.to_dict(include_email=True)
            d["friendship_id"] = str(fr.id)
            requests.append(d)
    return {"requests": requests, "total": len(requests)}
