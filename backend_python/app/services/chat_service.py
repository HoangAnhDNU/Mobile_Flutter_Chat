from typing import List, Optional, Tuple
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from ..models.chat import Chat, ChatParticipant
from ..models.message import Message
from ..models.user import User


class ChatService:
    """Service xử lý chat"""
    
    @staticmethod
    async def get_chats(
        db: AsyncSession,
        user_id: int,
        page: int = 1,
        limit: int = 20
    ) -> Tuple[List[Chat], int]:
        """Lấy danh sách chats của user"""
        offset = (page - 1) * limit
        
        # Query chats mà user tham gia (không hiện chat đã ẩn)
        query = (
            select(Chat)
            .join(ChatParticipant)
            .where(ChatParticipant.user_id == user_id)
            .where(ChatParticipant.is_hidden == False)
            .options(
                selectinload(Chat.participants).selectinload(ChatParticipant.user),
                selectinload(Chat.messages).selectinload(Message.sender)
            )
            .order_by(desc(Chat.updated_at))
            .offset(offset)
            .limit(limit)
        )
        
        result = await db.execute(query)
        chats = result.scalars().unique().all()
        
        # Count total
        count_query = (
            select(func.count(Chat.id))
            .join(ChatParticipant)
            .where(ChatParticipant.user_id == user_id)
            .where(ChatParticipant.is_hidden == False)
        )
        count_result = await db.execute(count_query)
        total = count_result.scalar()
        
        return list(chats), total
    
    @staticmethod
    async def get_chat_by_id(
        db: AsyncSession,
        chat_id: int,
        user_id: int
    ) -> Chat:
        """Lấy chat theo ID"""
        query = (
            select(Chat)
            .join(ChatParticipant)
            .where(
                and_(
                    Chat.id == chat_id,
                    ChatParticipant.user_id == user_id
                )
            )
            .options(
                selectinload(Chat.participants).selectinload(ChatParticipant.user),
                selectinload(Chat.messages).selectinload(Message.sender),
            )
        )
        
        result = await db.execute(query)
        chat = result.scalar_one_or_none()
        
        if not chat:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy cuộc hội thoại"
            )
        
        return chat
    
    @staticmethod
    async def create_direct_chat(
        db: AsyncSession,
        user_id: int,
        target_user_id: int
    ) -> Chat:
        """Tạo chat 1-1 (cho phép tạo ngay cả khi bị chặn — tin nhắn sẽ bị drop silently)"""
        # Kiểm tra target user tồn tại
        target_result = await db.execute(select(User).where(User.id == target_user_id))
        if not target_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy người dùng"
            )
        
        # Kiểm tra đã có chat 1-1 chưa
        existing_query = (
            select(Chat)
            .join(ChatParticipant)
            .where(
                and_(
                    Chat.is_group == False,
                    ChatParticipant.user_id.in_([user_id, target_user_id])
                )
            )
            .options(
                selectinload(Chat.participants).selectinload(ChatParticipant.user)
            )
            .group_by(Chat.id)
            .having(func.count(ChatParticipant.id) == 2)
        )

        existing_result = await db.execute(existing_query)
        existing_chat = existing_result.scalar_one_or_none()

        if existing_chat:
            # Reset is_hidden cho user hiện tại nếu đã ẩn chat trước đó
            needs_update = False
            for p in existing_chat.participants:
                if p.user_id == user_id and p.is_hidden:
                    p.is_hidden = False
                    needs_update = True
            if needs_update:
                await db.commit()
            return existing_chat
        
        # Tạo chat mới
        chat = Chat(is_group=False)
        db.add(chat)
        await db.flush()

        # Thêm participants
        for uid in [user_id, target_user_id]:
            participant = ChatParticipant(chat_id=chat.id, user_id=uid)
            db.add(participant)

        await db.commit()

        # Re-query with eager loading to avoid refresh expiry cycle
        result = await db.execute(
            select(Chat)
            .options(selectinload(Chat.participants).selectinload(ChatParticipant.user))
            .where(Chat.id == chat.id)
        )
        return result.scalar_one()
    
    @staticmethod
    async def create_group_chat(
        db: AsyncSession,
        user_id: int,
        name: str,
        participant_ids: List[int],
        avatar_url: Optional[str] = None
    ) -> Chat:
        """Tạo nhóm chat — chỉ thêm người đã là bạn bè."""
        # Kiểm tra user đã kết bạn với tất cả participant_ids
        from ..models.friendship import Friendship
        for pid in participant_ids:
            if pid == user_id:
                continue
            friend_check = await db.execute(
                select(Friendship).where(
                    and_(
                        Friendship.status == "accepted",
                        or_(
                            and_(Friendship.requester_id == user_id, Friendship.addressee_id == pid),
                            and_(Friendship.requester_id == pid, Friendship.addressee_id == user_id),
                        )
                    )
                )
            )
            if not friend_check.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Người dùng {pid} không có trong danh sách bạn bè. Chỉ có thể tạo nhóm với bạn bè."
                )

        # Tạo chat
        chat = Chat(
            name=name,
            is_group=True,
            creator_id=user_id,
            avatar_url=avatar_url
        )
        db.add(chat)
        await db.flush()
        
        # Thêm creator là admin
        creator_participant = ChatParticipant(
            chat_id=chat.id,
            user_id=user_id,
            role="admin"
        )
        db.add(creator_participant)
        
        # Thêm các participants khác
        for pid in participant_ids:
            if pid != user_id:
                participant = ChatParticipant(
                    chat_id=chat.id,
                    user_id=pid,
                    role="member"
                )
                db.add(participant)
        
        await db.commit()
        await db.refresh(chat)
        
        return chat
    
    @staticmethod
    async def add_participants(
        db: AsyncSession,
        chat_id: int,
        user_id: int,
        new_user_ids: List[int]
    ) -> None:
        """Thêm thành viên vào nhóm — chỉ thêm người đã là bạn bè."""
        # Kiểm tra quyền (phải là admin)
        query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == user_id,
                ChatParticipant.role == "admin"
            )
        )
        result = await db.execute(query)
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền thêm thành viên"
            )
        
        # Kiểm tra bạn bè trước khi thêm
        from ..models.friendship import Friendship
        for uid in new_user_ids:
            # Kiểm tra đã là bạn bè chưa
            friend_check = await db.execute(
                select(Friendship).where(
                    and_(
                        Friendship.status == "accepted",
                        or_(
                            and_(Friendship.requester_id == user_id, Friendship.addressee_id == uid),
                            and_(Friendship.requester_id == uid, Friendship.addressee_id == user_id),
                        )
                    )
                )
            )
            if not friend_check.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Người dùng {uid} không có trong danh sách bạn bè. Chỉ có thể thêm bạn bè vào nhóm."
                )

            # Kiểm tra chưa là thành viên
            check = await db.execute(
                select(ChatParticipant).where(
                    and_(
                        ChatParticipant.chat_id == chat_id,
                        ChatParticipant.user_id == uid
                    )
                )
            )
            if not check.scalar_one_or_none():
                participant = ChatParticipant(chat_id=chat_id, user_id=uid)
                db.add(participant)
        
        await db.commit()
    
    @staticmethod
    async def remove_participant(
        db: AsyncSession,
        chat_id: int,
        user_id: int,
        target_user_id: int
    ) -> None:
        """Xóa thành viên khỏi nhóm"""
        # Kiểm tra quyền
        query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == user_id,
                ChatParticipant.role == "admin"
            )
        )
        result = await db.execute(query)
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền xóa thành viên"
            )
        
        # Xóa participant
        delete_query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == target_user_id
            )
        )
        result = await db.execute(delete_query)
        participant = result.scalar_one_or_none()
        
        if participant:
            await db.delete(participant)
            await db.commit()
    
    @staticmethod
    async def leave_group(
        db: AsyncSession,
        chat_id: int,
        user_id: int
    ) -> None:
        """Rời khỏi nhóm"""
        query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == user_id
            )
        )
        result = await db.execute(query)
        participant = result.scalar_one_or_none()
        
        if participant:
            await db.delete(participant)
            await db.commit()
    
    @staticmethod
    async def toggle_pin(
        db: AsyncSession,
        chat_id: int,
        user_id: int
    ) -> bool:
        """Toggle ghim chat"""
        query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == user_id
            )
        )
        result = await db.execute(query)
        participant = result.scalar_one_or_none()
        
        if participant:
            participant.is_pinned = not participant.is_pinned
            await db.commit()
            return participant.is_pinned
        
        return False
    
    @staticmethod
    async def toggle_mute(
        db: AsyncSession,
        chat_id: int,
        user_id: int
    ) -> bool:
        """Toggle tắt thông báo"""
        query = select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == user_id
            )
        )
        result = await db.execute(query)
        participant = result.scalar_one_or_none()
        
        if participant:
            participant.is_muted = not participant.is_muted
            await db.commit()
            return participant.is_muted
        
        return False
