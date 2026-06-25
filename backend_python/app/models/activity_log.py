from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class ActivityLog(Base):
    """Model ActivityLog - ghi lại hành động admin"""
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    admin_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action = Column(String(100), nullable=False)  # e.g. "lock_user", "delete_user", "delete_group"
    target_type = Column(String(50), nullable=True)  # "user", "group", "message"
    target_id = Column(Integer, nullable=True)
    details = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    admin = relationship("User", foreign_keys=[admin_id])

    def to_dict(self):
        return {
            "id": str(self.id),
            "admin_id": str(self.admin_id) if self.admin_id else None,
            "admin_name": self.admin.display_name if self.admin else None,
            "action": self.action,
            "target_type": self.target_type,
            "target_id": str(self.target_id) if self.target_id else None,
            "details": self.details,
            "ip_address": self.ip_address,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
