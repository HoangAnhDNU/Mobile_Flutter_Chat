from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class CreateDirectChatRequest(BaseModel):
    """Schema tạo chat 1-1"""
    user_id: str


class CreateGroupChatRequest(BaseModel):
    """Schema tạo nhóm chat"""
    name: str = Field(..., min_length=1, max_length=100)
    participant_ids: List[str]
    avatar_url: Optional[str] = None


class UpdateGroupRequest(BaseModel):
    """Schema cập nhật nhóm"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    avatar_url: Optional[str] = None


class AddParticipantsRequest(BaseModel):
    """Schema thêm thành viên"""
    user_ids: List[str]


class ChatResponse(BaseModel):
    """Schema response Chat"""
    id: str
    name: Optional[str] = None
    avatar_url: Optional[str] = None
    is_group: bool
    creator_id: Optional[str] = None
    participants: List[dict] = []
    last_message: Optional[dict] = None
    unread_count: int = 0
    is_pinned: bool = False
    is_muted: bool = False
    is_archived: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChatListResponse(BaseModel):
    """Schema danh sách chats"""
    chats: List[ChatResponse]
    total: int
