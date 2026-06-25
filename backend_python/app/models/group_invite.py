from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base
import secrets


class GroupInvite(Base):
    """Model GroupInvite - link mời tham gia nhóm"""
    __tablename__ = "group_invites"

    id = Column(Integer, primary_key=True, autoincrement=True)
    chat_id = Column(Integer, ForeignKey("chats.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(32), unique=True, nullable=False, default=lambda: secrets.token_urlsafe(16))
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    expires_at = Column(DateTime, nullable=True)

    chat = relationship("Chat", foreign_keys=[chat_id])
    creator = relationship("User", foreign_keys=[created_by])

    def to_dict(self):
        return {
            "id": str(self.id),
            "chat_id": str(self.chat_id),
            "code": self.code,
            "is_active": self.is_active,
            "created_by": str(self.created_by) if self.created_by else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }
