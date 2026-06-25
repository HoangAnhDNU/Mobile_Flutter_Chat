"""Service xử lý quyền riêng tư."""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from ..models.privacy import UserPrivacy
from ..models.friendship import Friendship


class PrivacyService:
    """Service kiểm tra quyền riêng tư."""

    @staticmethod
    async def get_privacy(db: AsyncSession, user_id: int) -> UserPrivacy:
        """Lấy privacy settings của user, tạo default nếu chưa có."""
        result = await db.execute(
            select(UserPrivacy).where(UserPrivacy.user_id == user_id)
        )
        privacy = result.scalar_one_or_none()
        if not privacy:
            privacy = UserPrivacy(user_id=user_id)
            db.add(privacy)
            await db.flush()
            await db.refresh(privacy)
        return privacy

    @staticmethod
    async def are_friends(db: AsyncSession, user_id: int, other_id: int) -> bool:
        """Kiểm tra hai user có phải là bạn bè (accepted)."""
        if user_id == other_id:
            return True
        result = await db.execute(
            select(Friendship).where(
                and_(
                    Friendship.status == "accepted",
                    or_(
                        and_(
                            Friendship.requester_id == user_id,
                            Friendship.addressee_id == other_id,
                        ),
                        and_(
                            Friendship.requester_id == other_id,
                            Friendship.addressee_id == user_id,
                        ),
                    ),
                )
            )
        )
        return result.scalar_one_or_none() is not None

    @staticmethod
    async def can_see(
        db: AsyncSession,
        viewer_id: int,
        target_id: int,
        field: str,
    ) -> bool:
        """Kiểm tra viewer có được xem field (last_seen/avatar) của target không.

        field: 'show_last_seen' hoặc 'show_avatar'
        """
        if viewer_id == target_id:
            return True

        privacy = await PrivacyService.get_privacy(db, target_id)
        setting = getattr(privacy, field, "everyone")

        if setting == "everyone":
            return True
        elif setting == "friends":
            return await PrivacyService.are_friends(db, viewer_id, target_id)
        else:  # nobody
            return False

    @staticmethod
    async def filter_user_dict(
        db: AsyncSession,
        viewer_id: int,
        user_dict: dict,
        target_id: int,
    ) -> dict:
        """Lọc user dict theo privacy settings của target."""
        try:
            can_see_last_seen = await PrivacyService.can_see(db, viewer_id, target_id, "show_last_seen")
            can_see_avatar = await PrivacyService.can_see(db, viewer_id, target_id, "show_avatar")
        except Exception:
            return user_dict

        if not can_see_last_seen:
            user_dict["last_seen"] = None
        if not can_see_avatar:
            user_dict["avatar_url"] = None
        return user_dict
