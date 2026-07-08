from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class SendMessageRequest(BaseModel):
    """Schema gửi tin nhắn"""
    content: Optional[str] = Field(None)  # None cho voice/image, text cho text message
    reply_to_id: Optional[str] = None
    type: str = "text"
    media_url: Optional[str] = None
    mentions: Optional[List[str]] = None
    voice_duration: Optional[int] = None


class EditMessageRequest(BaseModel):
    """Schema sửa tin nhắn"""
    content: str = Field(..., min_length=1)


class AddReactionRequest(BaseModel):
    """Schema thêm reaction"""
    emoji: str = Field(..., min_length=1, max_length=50)


class ReactionResponse(BaseModel):
    """Schema response Reaction"""
    id: str
    user_id: str
    user_name: Optional[str] = None
    emoji: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    """Schema response Message"""
    id: str
    chat_id: str
    sender_id: Optional[str] = None
    sender_name: Optional[str] = None
    sender_avatar: Optional[str] = None
    content: str
    type: str = "text"
    status: str = "sent"
    media_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    reply_to_id: Optional[str] = None
    reactions: List[ReactionResponse] = []
    is_deleted: bool = False
    is_pinned: bool = False
    forwarded: bool = False
    image_label: Optional[str] = None
    voice_duration: Optional[int] = None
    fake_news_label: Optional[str] = None
    mentions: List[str] = []
    created_at: Optional[datetime] = None
    edited_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MessageListResponse(BaseModel):
    """Schema danh sách messages"""
    messages: List[MessageResponse]
    total: int
    has_more: bool
