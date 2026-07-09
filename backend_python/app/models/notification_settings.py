from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class UserNotificationSettings(Base):
    """Model UserNotificationSettings - Lưu cài đặt thông báo của user"""
    __tablename__ = "user_notification_settings"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    message_sound = Column(String(100), default="default")
    call_sound = Column(String(100), default="default")
    is_message_vibration = Column(Boolean, default=True)
    is_call_vibration = Column(Boolean, default=True)
    is_message_preview = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="notification_settings")

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "message_sound": self.message_sound,
            "call_sound": self.call_sound,
            "is_message_vibration": self.is_message_vibration,
            "is_call_vibration": self.is_call_vibration,
            "is_message_preview": self.is_message_preview,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


# Available sounds (default list)
AVAILABLE_MESSAGE_SOUNDS = [
    {"id": "default", "name": "Mặc định", "file": "new_message.mp3"},
    {"id": "simple", "name": "Đơn giản", "file": "simple.mp3"},
    {"id": "pop", "name": "Vui vẻ", "file": "pop.mp3"},
    {"id": "chime", "name": "Tiếng chuông", "file": "chime.mp3"},
    {"id": "none", "name": "Không có âm thanh", "file": None},
]

AVAILABLE_CALL_SOUNDS = [
    {"id": "default", "name": "Mặc định", "file": "new_video_call.mp3"},
    {"id": "classic", "name": "Cổ điển", "file": "classic.mp3"},
    {"id": "modern", "name": "Hiện đại", "file": "modern.mp3"},
    {"id": "none", "name": "Không có âm thanh", "file": None},
]
