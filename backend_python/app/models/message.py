from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Enum, LargeBinary
from sqlalchemy.dialects.mysql import LONGTEXT, LONGBLOB, MEDIUMBLOB, VARBINARY
from sqlalchemy import JSON
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

    # ---------- Media luu dang BLOB nhi phan trong MySQL ----------
    # media_data: file nhi phan tho (audio m4a, image jpg/png, ...). Toi da 4GB.
    # media_mime: kieu MIME de client hien thi dung, vi du "audio/m4a" / "image/png".
    # Khi gui qua API, backend encode base64 thanh data URI de nhung trong JSON.
    media_data = Column(LONGBLOB, nullable=True)         # 4GB max
    media_mime = Column(String(50), nullable=True)       # "audio/m4a", "image/png", ...
    media_size = Column(Integer, nullable=True)          # bytes
    media_url = Column(String(500), nullable=True)       # (legacy/optional) URL ngoai, fallback
    thumbnail_data = Column(MEDIUMBLOB, nullable=True)   # 16MB - anh thumb nho
    thumbnail_mime = Column(String(50), nullable=True)

    reply_to_id = Column(Integer, ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    is_deleted = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False, nullable=False)
    forwarded = Column(Boolean, default=False, nullable=False)
    image_label = Column(String(50), nullable=True)
    expires_at = Column(DateTime, nullable=True)  # Disappearing messages
    voice_duration = Column(Integer, nullable=True)  # Duration in milliseconds
    fake_news_label = Column(String(50), nullable=True)  # 6-way fake news label
    mentions = Column(JSON, nullable=True)  # List of mentioned user IDs, or ["all"]
    created_at = Column(DateTime, server_default=func.now())
    edited_at = Column(DateTime, nullable=True)
    
    # Relationships
    chat = relationship("Chat", back_populates="messages")
    sender = relationship("User", back_populates="sent_messages", foreign_keys=[sender_id])
    reply_to = relationship("Message", remote_side=[id], foreign_keys=[reply_to_id])
    reactions = relationship("MessageReaction", back_populates="message", cascade="all, delete-orphan")
    read_statuses = relationship("MessageReadStatus", back_populates="message", cascade="all, delete-orphan")
    
    def to_dict(self, include_sender: bool = True, include_reactions: bool = True) -> dict:
        """Chuyển đổi sang dictionary. media_data LONGBLOB -> base64 data URI."""
        # Neu co media_data thi encode thanh data URI (de client hien thi truc tiep).
        # Neu khong co ma co media_url (legacy) thi giu nguyen.
        media_data_uri = None
        thumbnail_data_uri = None
        if not self.is_deleted and self.media_data is not None and self.media_mime:
            try:
                import base64
                media_data_uri = f"data:{self.media_mime};base64,{base64.b64encode(self.media_data).decode()}"
            except Exception:
                media_data_uri = None
        if not self.is_deleted and self.thumbnail_data is not None and self.thumbnail_mime:
            try:
                import base64
                thumbnail_data_uri = f"data:{self.thumbnail_mime};base64,{base64.b64encode(self.thumbnail_data).decode()}"
            except Exception:
                thumbnail_data_uri = None

        # Uu tien media_data (BLOB noi sinh), fallback media_url (URL ngoai)
        if self.is_deleted:
            media_url_out = None
            thumbnail_url_out = None
        elif media_data_uri:
            media_url_out = media_data_uri
            thumbnail_url_out = thumbnail_data_uri
        else:
            media_url_out = self.media_url
            thumbnail_url_out = None

        data = {
            "id": str(self.id),
            "chat_id": str(self.chat_id),
            "sender_id": str(self.sender_id) if self.sender_id else None,
            "content": "" if self.is_deleted else self.content,
            "type": self.type,
            "status": self.status,
            "media_url": media_url_out,
            "media_mime": None if self.is_deleted else self.media_mime,
            "media_size": None if self.is_deleted else self.media_size,
            "thumbnail_url": thumbnail_url_out,
            "reply_to_id": str(self.reply_to_id) if self.reply_to_id else None,
            "is_deleted": self.is_deleted,
            "is_pinned": self.is_pinned,
            "forwarded": self.forwarded,
            "image_label": None if self.is_deleted else self.image_label,
            "voice_duration": self.voice_duration,
            "fake_news_label": None if self.is_deleted else self.fake_news_label,
            "mentions": self.mentions if self.mentions else [],
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "edited_at": self.edited_at.isoformat() if self.edited_at else None,
        }
        
        if include_sender and self.sender:
            data["sender_name"] = self.sender.display_name
            data["sender_avatar"] = self.sender.avatar_url
        
        if self.reply_to_id and self.reply_to:
            data["reply_to_text"] = "Tin nhắn đã thu hồi" if self.reply_to.is_deleted else self.reply_to.content
            reply_sender_name = None
            try:
                reply_sender_name = self.reply_to.sender.display_name if self.reply_to.sender else None
            except Exception:
                pass
            data["reply_to_sender"] = reply_sender_name
        else:
            data["reply_to_text"] = None
            data["reply_to_sender"] = None
        
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
