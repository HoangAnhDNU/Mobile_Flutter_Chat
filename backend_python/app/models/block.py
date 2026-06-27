from sqlalchemy import Column, Integer, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class BlockedUser(Base):
    """Model BlockedUser - user A chặn user B"""
    __tablename__ = "blocked_users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    blocker_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    blocked_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    report_reason = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    blocker = relationship("User", foreign_keys=[blocker_id])
    blocked = relationship("User", foreign_keys=[blocked_id])

    def to_dict(self):
        return {
            "id": str(self.id),
            "blocker_id": str(self.blocker_id),
            "blocked_id": str(self.blocked_id),
            "blocked_name": self.blocked.display_name if self.blocked else None,
            "blocked_avatar": self.blocked.avatar_url if self.blocked else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
