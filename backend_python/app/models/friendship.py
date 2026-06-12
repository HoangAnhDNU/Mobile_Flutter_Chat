from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Friendship(Base):
    """Quan hệ kết bạn giữa hai người dùng.

    - requester_id: người gửi lời mời
    - addressee_id: người nhận lời mời
    - status: pending | accepted
    """
    __tablename__ = "friendships"

    id = Column(Integer, primary_key=True, autoincrement=True)
    requester_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    addressee_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), default="pending", nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    requester = relationship("User", foreign_keys=[requester_id])
    addressee = relationship("User", foreign_keys=[addressee_id])

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "requester_id": str(self.requester_id),
            "addressee_id": str(self.addressee_id),
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
