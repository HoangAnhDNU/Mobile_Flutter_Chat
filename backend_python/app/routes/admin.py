"""
Routes dành cho Quản trị viên (Admin).

Tất cả endpoint đều yêu cầu tài khoản có role 'admin' (qua get_current_admin).
Đơn giản hóa thành một cấp Admin duy nhất theo phạm vi đồ án học phần.
"""
from fastapi import APIRouter, Depends, Query, Path, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, delete

from ..database import get_db
from ..dependencies import get_current_admin
from ..models.user import User
from ..models.chat import Chat, ChatParticipant
from ..models.message import Message
from ..services.auth_service import AuthService
from pydantic import BaseModel, Field
from typing import Optional

router = APIRouter()


# ==================== Schemas ====================

class AdminCreateUserRequest(BaseModel):
    email: str
    password: str = Field(..., min_length=6)
    display_name: str = Field(..., min_length=1)
    role: str = "user"


class AdminUpdateUserRequest(BaseModel):
    display_name: Optional[str] = None
    role: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None


class AdminResetPasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=6)


class AdminUpdateGroupRequest(BaseModel):
    name: Optional[str] = None
    avatar_url: Optional[str] = None


class AdminAddMembersRequest(BaseModel):
    user_ids: list[str]


# ==================== Dashboard ====================

@router.get("/stats", response_model=dict)
async def get_stats(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Thống kê tổng quan cho dashboard."""
    from datetime import datetime, timedelta
    from sqlalchemy import cast, Date

    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    online_users = (await db.execute(
        select(func.count(User.id)).where(User.is_online == True)  # noqa: E712
    )).scalar() or 0
    locked_users = (await db.execute(
        select(func.count(User.id)).where(User.is_locked == True)  # noqa: E712
    )).scalar() or 0
    total_chats = (await db.execute(select(func.count(Chat.id)))).scalar() or 0
    total_groups = (await db.execute(
        select(func.count(Chat.id)).where(Chat.is_group == True)  # noqa: E712
    )).scalar() or 0
    total_messages = (await db.execute(select(func.count(Message.id)))).scalar() or 0

    # Messages per day (last 7 days)
    seven_days_ago = datetime.now() - timedelta(days=7)
    daily_result = await db.execute(
        select(
            cast(Message.created_at, Date).label('day'),
            func.count(Message.id).label('count')
        ).where(Message.created_at >= seven_days_ago)
        .group_by(cast(Message.created_at, Date))
        .order_by(cast(Message.created_at, Date))
    )
    daily_messages = [{"day": str(row.day), "count": row.count} for row in daily_result]

    # New users per day (last 7 days)
    daily_users_result = await db.execute(
        select(
            cast(User.created_at, Date).label('day'),
            func.count(User.id).label('count')
        ).where(User.created_at >= seven_days_ago)
        .group_by(cast(User.created_at, Date))
        .order_by(cast(User.created_at, Date))
    )
    daily_new_users = [{"day": str(row.day), "count": row.count} for row in daily_users_result]

    # New users today
    today = datetime.now().date()
    new_users_today = (await db.execute(
        select(func.count(User.id)).where(
            cast(User.created_at, Date) == today
        )
    )).scalar() or 0

    # New messages today
    new_messages_today = (await db.execute(
        select(func.count(Message.id)).where(
            cast(Message.created_at, Date) == today
        )
    )).scalar() or 0

    # Active users today (users who sent at least 1 message today)
    active_users_today = (await db.execute(
        select(func.count(func.distinct(Message.sender_id))).where(
            cast(Message.created_at, Date) == today
        )
    )).scalar() or 0

    # Messages this week
    messages_this_week = (await db.execute(
        select(func.count(Message.id)).where(Message.created_at >= seven_days_ago)
    )).scalar() or 0

    # Database size (approximate) - for MySQL
    db_size_bytes = 0
    try:
        from sqlalchemy import text
        # Get data length for MySQL using information_schema
        size_result = await db.execute(text("""
            SELECT
                ROUND(SUM(data_length + index_length) / 1024, 2) as size_kb
            FROM information_schema.TABLES
            WHERE table_schema = DATABASE()
        """))
        row = size_result.fetchone()
        if row and row[0]:
            db_size_bytes = int(row[0] * 1024)  # Convert KB to bytes
    except Exception:
        pass

    return {
        "total_users": total_users,
        "online_users": online_users,
        "locked_users": locked_users,
        "total_chats": total_chats,
        "total_groups": total_groups,
        "total_messages": total_messages,
        "daily_messages": daily_messages,
        "daily_new_users": daily_new_users,
        "new_users_today": new_users_today,
        "new_messages_today": new_messages_today,
        "active_users_today": active_users_today,
        "messages_this_week": messages_this_week,
        "db_size_bytes": db_size_bytes,
    }


# ==================== Quản lý người dùng ====================

@router.get("/users", response_model=dict)
async def list_users(
    q: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Danh sách người dùng (có tìm kiếm + phân trang)."""
    offset = (page - 1) * limit
    base = select(User)
    count_q = select(func.count(User.id))

    if q:
        cond = or_(
            User.display_name.ilike(f"%{q}%"),
            User.email.ilike(f"%{q}%"),
        )
        base = base.where(cond)
        count_q = count_q.where(cond)

    total = (await db.execute(count_q)).scalar() or 0
    result = await db.execute(
        base.order_by(User.created_at.desc()).offset(offset).limit(limit)
    )
    users = result.scalars().all()

    return {
        "users": [u.to_dict(include_email=True) for u in users],
        "total": total,
        "page": page,
        "limit": limit,
    }


@router.get("/users/{user_id}", response_model=dict)
async def get_user_detail(
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Chi tiết một người dùng."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    return {"user": user.to_dict(include_email=True)}


@router.post("/users", response_model=dict)
async def create_user(
    request: AdminCreateUserRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Tạo người dùng mới (thủ công)."""
    existing = (await db.execute(select(User).where(User.email == request.email))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Email đã được sử dụng")

    user = User(
        email=request.email,
        password_hash=AuthService.hash_password(request.password),
        display_name=request.display_name,
        role=request.role if request.role in ("user", "admin") else "user",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return {"user": user.to_dict(include_email=True), "message": "Tạo người dùng thành công"}


@router.put("/users/{user_id}", response_model=dict)
async def update_user(
    request: AdminUpdateUserRequest,
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Cập nhật thông tin người dùng (tên hiển thị, role)."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    if request.display_name is not None:
        user.display_name = request.display_name
    if request.role in ("user", "admin"):
        user.role = request.role
    if request.email is not None and request.email.strip():
        # Kiểm tra email trùng với người khác
        dup = (await db.execute(
            select(User).where(User.email == request.email.strip(), User.id != user_id)
        )).scalar_one_or_none()
        if dup:
            raise HTTPException(status_code=400, detail="Email đã được sử dụng bởi người khác")
        user.email = request.email.strip()
    if request.avatar_url is not None:
        user.avatar_url = request.avatar_url

    await db.commit()
    await db.refresh(user)
    return {"user": user.to_dict(include_email=True), "message": "Cập nhật thành công"}


@router.post("/users/{user_id}/lock", response_model=dict)
async def lock_user(
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Khóa tài khoản người dùng."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Không thể tự khóa tài khoản của mình")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.is_locked = True
    user.is_online = False
    await db.commit()
    return {"message": "Đã khóa tài khoản"}


@router.post("/users/{user_id}/unlock", response_model=dict)
async def unlock_user(
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Mở khóa tài khoản người dùng."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.is_locked = False
    await db.commit()
    return {"message": "Đã mở khóa tài khoản"}


@router.post("/users/{user_id}/reset-password", response_model=dict)
async def reset_password(
    request: AdminResetPasswordRequest,
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Đặt lại mật khẩu cho người dùng."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.password_hash = AuthService.hash_password(request.new_password)
    await db.commit()
    return {"message": "Đã đặt lại mật khẩu"}


@router.delete("/users/{user_id}", response_model=dict)
async def delete_user(
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Xóa người dùng (cùng dữ liệu liên quan qua cascade FK)."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Không thể tự xóa tài khoản của mình")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    await db.delete(user)
    await db.commit()
    return {"message": "Đã xóa người dùng"}


# ==================== Quản lý nhóm ====================

@router.get("/groups", response_model=dict)
async def list_groups(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Danh sách tất cả nhóm chat trong hệ thống."""
    result = await db.execute(
        select(Chat).where(Chat.is_group == True).order_by(Chat.created_at.desc())  # noqa: E712
    )
    chats = result.scalars().all()

    groups = []
    for c in chats:
        member_count = (await db.execute(
            select(func.count(ChatParticipant.id)).where(ChatParticipant.chat_id == c.id)
        )).scalar() or 0
        msg_count = (await db.execute(
            select(func.count(Message.id)).where(Message.chat_id == c.id)
        )).scalar() or 0
        groups.append({
            "id": str(c.id),
            "name": c.name,
            "avatar_url": c.avatar_url,
            "creator_id": str(c.creator_id) if c.creator_id else None,
            "member_count": member_count,
            "message_count": msg_count,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        })

    return {"groups": groups, "total": len(groups)}


@router.delete("/groups/{chat_id}", response_model=dict)
async def delete_group(
    chat_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Giải tán (xóa) một nhóm chat."""
    chat = (await db.execute(select(Chat).where(Chat.id == chat_id))).scalar_one_or_none()
    if not chat:
        raise HTTPException(status_code=404, detail="Không tìm thấy nhóm")
    await db.delete(chat)
    await db.commit()
    return {"message": "Đã giải tán nhóm"}


@router.get("/groups/{chat_id}", response_model=dict)
async def get_group_detail(
    chat_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Chi tiết một nhóm: thông tin + danh sách thành viên."""
    chat = (await db.execute(select(Chat).where(Chat.id == chat_id))).scalar_one_or_none()
    if not chat:
        raise HTTPException(status_code=404, detail="Không tìm thấy nhóm")

    # Lấy danh sách thành viên kèm thông tin user
    parts = (await db.execute(
        select(ChatParticipant).where(ChatParticipant.chat_id == chat_id)
    )).scalars().all()

    members = []
    for p in parts:
        u = (await db.execute(select(User).where(User.id == p.user_id))).scalar_one_or_none()
        if u:
            d = u.to_dict(include_email=True)
            d["role_in_group"] = p.role
            members.append(d)

    return {
        "group": {
            "id": str(chat.id),
            "name": chat.name,
            "avatar_url": chat.avatar_url,
            "creator_id": str(chat.creator_id) if chat.creator_id else None,
            "created_at": chat.created_at.isoformat() if chat.created_at else None,
        },
        "members": members,
    }


@router.put("/groups/{chat_id}", response_model=dict)
async def update_group(
    request: AdminUpdateGroupRequest,
    chat_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Cập nhật tên / avatar nhóm."""
    chat = (await db.execute(select(Chat).where(Chat.id == chat_id))).scalar_one_or_none()
    if not chat:
        raise HTTPException(status_code=404, detail="Không tìm thấy nhóm")
    if request.name is not None and request.name.strip():
        chat.name = request.name.strip()
    if request.avatar_url is not None:
        chat.avatar_url = request.avatar_url
    await db.commit()
    return {"message": "Cập nhật nhóm thành công"}


@router.post("/groups/{chat_id}/members", response_model=dict)
async def add_group_members(
    request: AdminAddMembersRequest,
    chat_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Thêm thành viên vào nhóm."""
    chat = (await db.execute(select(Chat).where(Chat.id == chat_id))).scalar_one_or_none()
    if not chat:
        raise HTTPException(status_code=404, detail="Không tìm thấy nhóm")

    added = 0
    for uid in request.user_ids:
        try:
            uid_int = int(uid)
        except (TypeError, ValueError):
            continue
        # Bỏ qua nếu đã là thành viên
        existing = (await db.execute(
            select(ChatParticipant).where(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == uid_int,
            )
        )).scalar_one_or_none()
        if existing:
            continue
        # Chỉ thêm nếu user tồn tại
        user = (await db.execute(select(User).where(User.id == uid_int))).scalar_one_or_none()
        if not user:
            continue
        db.add(ChatParticipant(chat_id=chat_id, user_id=uid_int, role="member"))
        added += 1

    await db.commit()
    return {"message": f"Đã thêm {added} thành viên", "added": added}


@router.delete("/groups/{chat_id}/members/{user_id}", response_model=dict)
async def remove_group_member(
    chat_id: int = Path(...),
    user_id: int = Path(...),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Xóa một thành viên khỏi nhóm."""
    part = (await db.execute(
        select(ChatParticipant).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == user_id,
        )
    )).scalar_one_or_none()
    if not part:
        raise HTTPException(status_code=404, detail="Thành viên không thuộc nhóm")
    await db.delete(part)
    await db.commit()
    return {"message": "Đã xóa thành viên khỏi nhóm"}


# ==================== Activity Log ====================

@router.get("/activity-log", response_model=dict)
async def get_activity_log(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Lấy nhật ký hành động admin"""
    from ..models.activity_log import ActivityLog
    from sqlalchemy.orm import selectinload

    offset = (page - 1) * limit
    result = await db.execute(
        select(ActivityLog)
        .options(selectinload(ActivityLog.admin))
        .order_by(ActivityLog.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    logs = result.scalars().all()

    total = (await db.execute(select(func.count(ActivityLog.id)))).scalar() or 0
    return {
        "logs": [log.to_dict() for log in logs],
        "total": total,
        "has_more": (page * limit) < total,
    }
