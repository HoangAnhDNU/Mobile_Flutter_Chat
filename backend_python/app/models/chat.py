from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
from ..database import Base


class Chat(Base):
    """Model Chat/Conversation"""
    __tablename__ = "chats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=True)  # Null cho chat 1-1
    avatar_url = Column(LONGTEXT, nullable=True)
    is_group = Column(Boolean, default=False)
    creator_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    
    # Relationships
    creator = relationship("User", foreign_keys=[creator_id])
    participants = relationship("ChatParticipant", back_populates="chat", cascade="all, delete-orphan")
    messages = relationship("Message", back_populates="chat", cascade="all, delete-orphan")
    
    def to_dict(self, current_user_id: int = None, include_participants: bool = True, current_participant=None, deleted_message_ids: set = None) -> dict:
        """Chuyển đổi sang dictionary"""
        data = {
            "id": str(self.id),
            "name": self.name,
            "avatar_url": self.avatar_url,
            "is_group": self.is_group,
            "creator_id": str(self.creator_id) if self.creator_id else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
        
        if include_participants:
            try:
                data["participants"] = [p.user.to_dict(include_email=False) for p in self.participants if p.user]
            except Exception:
                data["participants"] = []
        
        # Last message (include recalled messages, show "Tin nhắn đã thu hồi")
        try:
            # Resolve participant for current user to apply per-user filters
            _participant = current_participant
            if _participant is None and current_user_id is not None:
                try:
                    _participant = next((p for p in self.participants if p.user_id == current_user_id), None)
                except Exception:
                    pass

            # Build cutoff from cleared_at only (auto_delete handled via DeletedMessage)
            cutoff = None
            if _participant:
                cleared = getattr(_participant, 'messages_cleared_at', None)
                cutoff = cleared

            visible_messages = [m for m in self.messages if (cutoff is None or (m.created_at and m.created_at > cutoff)) and (deleted_message_ids is None or m.id not in deleted_message_ids)]
            latest = max(visible_messages, key=lambda m: m.created_at or datetime.min) if visible_messages else None
            if latest is not None:
                sender_name = None
                try:
                    sender_name = latest.sender.display_name if latest.sender else None
                except Exception:
                    pass
                data["last_message"] = {
                    "id": str(latest.id),
                    "content": "Tin nhắn đã thu hồi" if latest.is_deleted else latest.content,
                    "sender_id": str(latest.sender_id) if latest.sender_id else None,
                    "sender_name": sender_name,
                    "created_at": latest.created_at.isoformat() if latest.created_at else None,
                    "is_deleted": latest.is_deleted,
                    "forwarded": latest.forwarded,
                    "type": latest.type,
                }
            else:
                data["last_message"] = None
        except Exception:
            data["last_message"] = None
        
        return data


class ChatParticipant(Base):
    """Model ChatParticipant - bảng liên kết user và chat"""
    __tablename__ = "chat_participants"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    chat_id = Column(Integer, ForeignKey("chats.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), default="member")  # admin, member
    is_muted = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False)
    is_archived = Column(Boolean, default=False)
    is_hidden = Column(Boolean, default=False)
    messages_cleared_at = Column(DateTime, nullable=True)
    auto_delete_days = Column(Integer, nullable=True)  # 1, 7, 14; NULL = off
    joined_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    chat = relationship("Chat", back_populates="participants")
    user = relationship("User", back_populates="chat_participations")
