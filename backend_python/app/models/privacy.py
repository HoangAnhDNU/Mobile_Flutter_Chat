from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class UserPrivacy(Base):
    """Model UserPrivacy - cài đặt quyền riêng tư"""
    __tablename__ = "user_privacy"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    show_last_seen = Column(String(20), default="everyone")  # everyone, friends, nobody
    show_avatar = Column(String(20), default="everyone")  # everyone, friends, nobody
    show_read_receipts = Column(Boolean, default=True)
    disappearing_messages = Column(Integer, default=0)  # 0=off, 86400=24h, 604800=7d, 7776000=90d (seconds)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", foreign_keys=[user_id])

    def to_dict(self):
        return {
            "user_id": str(self.user_id),
            "show_last_seen": self.show_last_seen,
            "show_avatar": self.show_avatar,
            "show_read_receipts": self.show_read_receipts,
            "disappearing_messages": self.disappearing_messages,
        }
