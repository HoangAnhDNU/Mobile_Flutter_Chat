from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class User(Base):
    """Model User"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=False)
    avatar_url = Column(LONGTEXT, nullable=True)
    role = Column(String(20), default="user", nullable=False)  # user | admin
    is_locked = Column(Boolean, default=False, nullable=False)
    is_online = Column(Boolean, default=False)
    last_seen = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    
    # Relationships
    sent_messages = relationship("Message", back_populates="sender", foreign_keys="Message.sender_id")
    chat_participations = relationship("ChatParticipant", back_populates="user")
    reactions = relationship("MessageReaction", back_populates="user")
    notification_settings = relationship("UserNotificationSettings", back_populates="user", uselist=False)
    
    def to_dict(self, include_email: bool = True) -> dict:
        """Chuyển đổi sang dictionary"""
        data = {
            "id": str(self.id),
            "display_name": self.display_name,
            "avatar_url": self.avatar_url,
            "role": self.role,
            "is_locked": self.is_locked,
            "is_online": self.is_online,
            "last_seen": self.last_seen.isoformat() if self.last_seen else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if include_email:
            data["email"] = self.email
        return data
