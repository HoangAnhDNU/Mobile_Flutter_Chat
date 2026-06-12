from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    """Schema cơ sở cho User"""
    display_name: str
    avatar_url: Optional[str] = None


class UserResponse(BaseModel):
    """Schema response User"""
    id: str
    email: Optional[str] = None
    display_name: str
    avatar_url: Optional[str] = None
    is_online: bool = False
    last_seen: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UpdateProfileRequest(BaseModel):
    """Schema cập nhật profile"""
    display_name: Optional[str] = Field(None, min_length=2, max_length=100)
    avatar_url: Optional[str] = None


class UserListResponse(BaseModel):
    """Schema danh sách users"""
    users: list[UserResponse]
    total: int
