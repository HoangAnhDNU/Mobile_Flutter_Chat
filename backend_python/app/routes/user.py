from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from pydantic import BaseModel, Field

from ..database import get_db
from ..schemas.user import UpdateProfileRequest, UserResponse, UserListResponse
from ..dependencies import get_current_user
from ..models.user import User
from ..services.auth_service import AuthService

router = APIRouter()


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)


@router.get("/me", response_model=dict)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Lấy thông tin profile của user hiện tại"""
    return {"user": current_user.to_dict()}


@router.post("/change-password", response_model=dict)
async def change_password(
    request: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Đổi mật khẩu (cần mật khẩu cũ đúng)."""
    if not AuthService.verify_password(request.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Mật khẩu cũ không đúng")
    current_user.password_hash = AuthService.hash_password(request.new_password)
    await db.commit()
    return {"message": "Đổi mật khẩu thành công"}


@router.put("/me", response_model=dict)
async def update_profile(
    request: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Cập nhật profile"""
    if request.display_name:
        current_user.display_name = request.display_name
    if request.avatar_url is not None:
        current_user.avatar_url = request.avatar_url
    
    await db.commit()
    await db.refresh(current_user)
    
    return {
        "user": current_user.to_dict(),
        "message": "Cập nhật thành công"
    }


@router.get("/search", response_model=UserListResponse)
async def search_users(
    q: str = Query(..., min_length=1),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tìm kiếm users"""
    offset = (page - 1) * limit
    
    query = (
        select(User)
        .where(
            or_(
                User.display_name.ilike(f"%{q}%"),
                User.email.ilike(f"%{q}%")
            ),
            User.id != current_user.id  # Exclude current user
        )
        .offset(offset)
        .limit(limit)
    )
    
    result = await db.execute(query)
    users = result.scalars().all()
    
    return UserListResponse(
        users=[UserResponse(**u.to_dict(include_email=False)) for u in users],
        total=len(users)
    )


@router.get("/{user_id}", response_model=dict)
async def get_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy thông tin một user"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        return {"error": "Không tìm thấy người dùng"}
    
    return {"user": user.to_dict(include_email=False)}
