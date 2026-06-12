from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
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
    
    def to_dict(self, current_user_id: int = None, include_participants: bool = True) -> dict:
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
            data["participants"] = [p.user.to_dict(include_email=False) for p in self.participants if p.user]
        
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
    joined_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    chat = relationship("Chat", back_populates="participants")
    user = relationship("User", back_populates="chat_participations")
