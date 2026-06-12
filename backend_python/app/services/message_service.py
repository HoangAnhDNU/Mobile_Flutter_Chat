from typing import List, Tuple, Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from ..models.message import Message, MessageReaction, MessageReadStatus
from ..models.chat import ChatParticipant, Chat
from ..models.user import User


class MessageService:
    """Service xử lý messages"""
    
    @staticmethod
    async def get_messages(
        db: AsyncSession,
        chat_id: int,
        user_id: int,
        page: int = 1,
        limit: int = 50
    ) -> Tuple[List[Message], int, bool]:
        """Lấy tin nhắn của chat"""
        # Verify user là participant
        check = await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == chat_id,
                    ChatParticipant.user_id == user_id
                )
            )
        )
        if not check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền xem tin nhắn này"
            )
        
        offset = (page - 1) * limit
        
        query = (
            select(Message)
            .where(Message.chat_id == chat_id)
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user)
            )
            .order_by(desc(Message.created_at))
            .offset(offset)
            .limit(limit + 1)  # Lấy thêm 1 để check has_more
        )
        
        result = await db.execute(query)
        messages = list(result.scalars().unique().all())
        
        has_more = len(messages) > limit
        if has_more:
            messages = messages[:limit]
        
        # Count total
        count_query = select(func.count(Message.id)).where(Message.chat_id == chat_id)
        count_result = await db.execute(count_query)
        total = count_result.scalar()
        
        return messages, total, has_more
    
    @staticmethod
    async def send_message(
        db: AsyncSession,
        chat_id: int,
        sender_id: int,
        content: str,
        message_type: str = "text",
        reply_to_id: Optional[int] = None,
        media_url: Optional[str] = None
    ) -> Message:
        """Gửi tin nhắn"""
        # Verify sender là participant
        check = await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == chat_id,
                    ChatParticipant.user_id == sender_id
                )
            )
        )
        if not check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền gửi tin nhắn"
            )
        
        message = Message(
            chat_id=chat_id,
            sender_id=sender_id,
            content=content,
            type=message_type,
            reply_to_id=reply_to_id,
            media_url=media_url,
        )
        db.add(message)
        
        # Cập nhật updated_at của chat
        chat_result = await db.execute(select(Chat).where(Chat.id == chat_id))
        chat = chat_result.scalar_one_or_none()
        if chat:
            chat.updated_at = datetime.utcnow()
        
        await db.commit()

        # Load lại message kèm sender và reactions để tránh lazy-load
        # trong context async (gây MissingGreenlet khi gọi to_dict()).
        reload_result = await db.execute(
            select(Message)
            .where(Message.id == message.id)
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
            )
        )
        message = reload_result.scalar_one()

        return message
    
    @staticmethod
    async def edit_message(
        db: AsyncSession,
        message_id: int,
        user_id: int,
        new_content: str
    ) -> Message:
        """Sửa tin nhắn"""
        result = await db.execute(
            select(Message).where(Message.id == message_id)
        )
        message = result.scalar_one_or_none()
        
        if not message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy tin nhắn"
            )
        
        if message.sender_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền sửa tin nhắn này"
            )
        
        message.content = new_content
        message.edited_at = datetime.utcnow()
        
        await db.commit()

        # Load lại kèm sender và reactions để tránh lazy-load async.
        reload_result = await db.execute(
            select(Message)
            .where(Message.id == message.id)
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
            )
        )
        message = reload_result.scalar_one()
        
        return message
    
    @staticmethod
    async def delete_message(
        db: AsyncSession,
        message_id: int,
        user_id: int,
        delete_for_everyone: bool = False
    ) -> int:
        """Xóa tin nhắn. Trả về chat_id để phát realtime."""
        result = await db.execute(
            select(Message).where(Message.id == message_id)
        )
        message = result.scalar_one_or_none()
        
        if not message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy tin nhắn"
            )
        
        chat_id = message.chat_id
        if delete_for_everyone:
            if message.sender_id != user_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Bạn không có quyền xóa tin nhắn này cho mọi người"
                )
            message.is_deleted = True
            message.content = "Tin nhắn đã bị xóa"
            message.is_pinned = False
        else:
            # Soft delete for this user only - thêm vào bảng deleted_messages
            pass
        
        await db.commit()
        return chat_id

    @staticmethod
    async def toggle_pin(
        db: AsyncSession,
        message_id: int,
        user_id: int,
        max_pins: int = 3,
    ) -> tuple[int, bool]:
        """Ghim/bỏ ghim tin nhắn (tối đa max_pins mỗi chat).

        Trả về (chat_id, is_pinned_mới).
        """
        message = (await db.execute(
            select(Message).where(Message.id == message_id)
        )).scalar_one_or_none()
        if not message:
            raise HTTPException(status_code=404, detail="Không tìm thấy tin nhắn")

        # Verify participant
        check = (await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == message.chat_id,
                    ChatParticipant.user_id == user_id,
                )
            )
        )).scalar_one_or_none()
        if not check:
            raise HTTPException(status_code=403, detail="Bạn không có quyền ghim tin nhắn")

        if not message.is_pinned:
            # Đếm số tin đã ghim trong chat
            pinned_count = (await db.execute(
                select(func.count(Message.id)).where(
                    and_(Message.chat_id == message.chat_id, Message.is_pinned == True)  # noqa: E712
                )
            )).scalar() or 0
            if pinned_count >= max_pins:
                raise HTTPException(
                    status_code=400,
                    detail=f"Chỉ được ghim tối đa {max_pins} tin nhắn",
                )
            message.is_pinned = True
        else:
            message.is_pinned = False

        await db.commit()
        return message.chat_id, message.is_pinned

    @staticmethod
    async def get_pinned_messages(
        db: AsyncSession,
        chat_id: int,
        user_id: int,
    ) -> List[Message]:
        """Danh sách tin nhắn đã ghim của chat."""
        check = (await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == chat_id,
                    ChatParticipant.user_id == user_id,
                )
            )
        )).scalar_one_or_none()
        if not check:
            raise HTTPException(status_code=403, detail="Bạn không có quyền xem tin nhắn này")

        result = await db.execute(
            select(Message)
            .where(and_(Message.chat_id == chat_id, Message.is_pinned == True))  # noqa: E712
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
            )
            .order_by(desc(Message.created_at))
        )
        return list(result.scalars().unique().all())
    
    @staticmethod
    async def add_reaction(
        db: AsyncSession,
        message_id: int,
        user_id: int,
        emoji: str
    ) -> Message:
        """Thả/bỏ reaction (toggle). Trả về message kèm reactions đã nạp sẵn."""
        # Check message exists
        msg_result = await db.execute(select(Message).where(Message.id == message_id))
        message = msg_result.scalar_one_or_none()

        if not message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy tin nhắn"
            )

        # Verify user is participant
        check = await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == message.chat_id,
                    ChatParticipant.user_id == user_id
                )
            )
        )
        if not check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền thả reaction"
            )

        # Toggle: nếu user đã thả đúng emoji này thì gỡ ra, ngược lại thêm mới.
        existing = (await db.execute(
            select(MessageReaction).where(
                and_(
                    MessageReaction.message_id == message_id,
                    MessageReaction.user_id == user_id,
                    MessageReaction.emoji == emoji
                )
            )
        )).scalar_one_or_none()

        if existing:
            await db.delete(existing)
        else:
            db.add(MessageReaction(message_id=message_id, user_id=user_id, emoji=emoji))

        await db.commit()

        # Nạp lại message kèm sender + reactions(+user) để to_dict không lazy-load.
        reload_result = await db.execute(
            select(Message)
            .where(Message.id == message_id)
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
            )
        )
        return reload_result.scalar_one()
    
    @staticmethod
    async def remove_reaction(
        db: AsyncSession,
        reaction_id: int,
        user_id: int
    ) -> None:
        """Xóa reaction"""
        result = await db.execute(
            select(MessageReaction).where(MessageReaction.id == reaction_id)
        )
        reaction = result.scalar_one_or_none()
        
        if not reaction:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy reaction"
            )
        
        if reaction.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền xóa reaction này"
            )
        
        await db.delete(reaction)
        await db.commit()
    
    @staticmethod
    async def mark_as_read(
        db: AsyncSession,
        chat_id: int,
        user_id: int
    ) -> None:
        """Đánh dấu đã đọc"""
        # Get unread messages
        messages_result = await db.execute(
            select(Message)
            .where(
                and_(
                    Message.chat_id == chat_id,
                    Message.sender_id != user_id
                )
            )
        )
        messages = messages_result.scalars().all()
        
        for message in messages:
            # Check if already marked
            existing = await db.execute(
                select(MessageReadStatus).where(
                    and_(
                        MessageReadStatus.message_id == message.id,
                        MessageReadStatus.user_id == user_id
                    )
                )
            )
            if not existing.scalar_one_or_none():
                read_status = MessageReadStatus(
                    message_id=message.id,
                    user_id=user_id
                )
                db.add(read_status)
        
        await db.commit()
