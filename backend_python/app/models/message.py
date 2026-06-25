from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Enum
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base
import enum


class MessageType(str, enum.Enum):
    TEXT = "text"
    IMAGE = "image"
    VIDEO = "video"
    FILE = "file"
    AUDIO = "audio"
    LOCATION = "location"
    SYSTEM = "system"


class MessageStatus(str, enum.Enum):
    SENDING = "sending"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"


class Message(Base):
    """Model Message"""
    __tablename__ = "messages"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    chat_id = Column(Integer, ForeignKey("chats.id", ondelete="CASCADE"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    content = Column(Text, nullable=False)
    type = Column(String(20), default=MessageType.TEXT.value)
    status = Column(String(20), default=MessageStatus.SENT.value)
    media_url = Column(LONGTEXT, nullable=True)
    thumbnail_url = Column(LONGTEXT, nullable=True)
    reply_to_id = Column(Integer, ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    is_deleted = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False, nullable=False)
    image_label = Column(String(50), nullable=True)
    expires_at = Column(DateTime, nullable=True)  # Disappearing messages
    created_at = Column(DateTime, server_default=func.now())
    edited_at = Column(DateTime, nullable=True)
    
    # Relationships
    chat = relationship("Chat", back_populates="messages")
    sender = relationship("User", back_populates="sent_messages", foreign_keys=[sender_id])
    reply_to = relationship("Message", remote_side=[id], foreign_keys=[reply_to_id])
    reactions = relationship("MessageReaction", back_populates="message", cascade="all, delete-orphan")
    read_statuses = relationship("MessageReadStatus", back_populates="message", cascade="all, delete-orphan")
    
    def to_dict(self, include_sender: bool = True, include_reactions: bool = True) -> dict:
        """Chuyển đổi sang dictionary"""
        data = {
            "id": str(self.id),
            "chat_id": str(self.chat_id),
            "sender_id": str(self.sender_id) if self.sender_id else None,
            "content": self.content,
            "type": self.type,
            "status": self.status,
            "media_url": self.media_url,
            "thumbnail_url": self.thumbnail_url,
            "reply_to_id": str(self.reply_to_id) if self.reply_to_id else None,
            "is_deleted": self.is_deleted,
            "is_pinned": self.is_pinned,
            "image_label": self.image_label,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "edited_at": self.edited_at.isoformat() if self.edited_at else None,
        }
        
        if include_sender and self.sender:
            data["sender_name"] = self.sender.display_name
            data["sender_avatar"] = self.sender.avatar_url
        
        if include_reactions:
            data["reactions"] = [r.to_dict() for r in self.reactions]
        
        return data


class MessageReaction(Base):
    """Model MessageReaction"""
    __tablename__ = "message_reactions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    emoji = Column(String(50), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    message = relationship("Message", back_populates="reactions")
    user = relationship("User", back_populates="reactions")
    
    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "user_name": self.user.display_name if self.user else None,
            "emoji": self.emoji,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class MessageReadStatus(Base):
    """Model MessageReadStatus - theo dõi ai đã đọc tin nhắn"""
    __tablename__ = "message_read_status"

    id = Column(Integer, primary_key=True, autoincrement=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    read_at = Column(DateTime, server_default=func.now())

    # Relationships
    message = relationship("Message", back_populates="read_statuses")


class DeletedMessage(Base):
    """Model DeletedMessage - theo dõi tin nhắn bị xóa bởi user nào (delete for me)"""
    __tablename__ = "deleted_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    deleted_at = Column(DateTime, server_default=func.now())

    # Relationships
    message = relationship("Message")
    user = relationship("User")
