from typing import List, Tuple, Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, desc, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from ..models.message import Message, MessageReaction, MessageReadStatus, DeletedMessage
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
        participant_result = await db.execute(
            select(ChatParticipant).where(
                and_(
                    ChatParticipant.chat_id == chat_id,
                    ChatParticipant.user_id == user_id
                )
            )
        )
        participant = participant_result.scalar_one_or_none()
        if not participant:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền xem tin nhắn này"
            )
        
        offset = (page - 1) * limit

        # Subquery để lấy message_id đã bị xóa bởi user này
        deleted_subquery = (
            select(DeletedMessage.message_id)
            .where(DeletedMessage.user_id == user_id)
        )

        # Build query conditions
        conditions = [
            Message.chat_id == chat_id,
            ~Message.id.in_(deleted_subquery),
        ]
        if participant.messages_cleared_at is not None:
            conditions.append(Message.created_at > participant.messages_cleared_at)

        # Auto-delete: actually delete (insert DeletedMessage) old messages for this user
        if participant.auto_delete_days:
            from datetime import timedelta
            cutoff = datetime.utcnow() - timedelta(days=participant.auto_delete_days)
            # Find messages older than cutoff that user hasn't already deleted
            old_msgs_result = await db.execute(
                select(Message.id).where(
                    and_(
                        Message.chat_id == chat_id,
                        Message.created_at < cutoff,
                        ~Message.id.in_(deleted_subquery),
                    )
                )
            )
            old_msg_ids = [mid for (mid,) in old_msgs_result.all()]
            if old_msg_ids:
                for mid in old_msg_ids:
                    db.add(DeletedMessage(message_id=mid, user_id=user_id))
                await db.commit()

        query = (
            select(Message)
            .where(and_(*conditions))
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
                selectinload(Message.reply_to).selectinload(Message.sender),
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
        count_conditions = [Message.chat_id == chat_id, ~Message.id.in_(deleted_subquery)]
        if participant.messages_cleared_at is not None:
            count_conditions.append(Message.created_at > participant.messages_cleared_at)
        count_query = select(func.count(Message.id)).where(and_(*count_conditions))
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
        media_url: Optional[str] = None,
        mentions: Optional[list] = None,
        voice_duration: Optional[int] = None,
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
        
        # Check block: if this is a 1-1 chat, check block in both directions
        from ..models.block import BlockedUser
        is_group_result = await db.execute(
            select(Chat.is_group).where(Chat.id == chat_id)
        )
        is_group = is_group_result.scalar_one_or_none()
        _silently_drop = False
        if not is_group:
            # Get the other participant
            other_result = await db.execute(
                select(ChatParticipant.user_id).where(
                    and_(
                        ChatParticipant.chat_id == chat_id,
                        ChatParticipant.user_id != sender_id
                    )
                )
            )
            other_uid = other_result.scalar_one_or_none()
            if other_uid:
                # Check if either party blocked the other -> reject
                block_check = await db.execute(
                    select(BlockedUser).where(
                        or_(
                            and_(BlockedUser.blocker_id == other_uid, BlockedUser.blocked_id == sender_id),
                            and_(BlockedUser.blocker_id == sender_id, BlockedUser.blocked_id == other_uid),
                        )
                    )
                )
                if block_check.scalars().first():
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Không thể gửi tin nhắn do quan hệ chặn"
                    )
        
        # Classify image if type is image and has image data
        image_label = None
        if message_type == "image" and media_url:
            try:
                from .image_classifier import get_classifier
                import tempfile
                import os
                import base64
                
                classifier = get_classifier()
                
                # Handle base64 data (from Flutter)
                if media_url.startswith('data:image'):
                    # Extract base64 part
                    base64_data = media_url.split(',')[1]
                    image_data = base64.b64decode(base64_data)
                    
                    # Save to temp file
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as temp_file:
                        temp_file.write(image_data)
                        temp_path = temp_file.name
                    
                    try:
                        predictions = classifier.predict(temp_path, top_k=1)
                        if predictions:
                            predicted_label = list(predictions.keys())[0]
                            # Only save label if it's one of the 5 allowed labels
                            allowed_labels = {'classroom', 'computerroom', 'library', 'corridor', 'office'}
                            if predicted_label in allowed_labels:
                                image_label = predicted_label
                    finally:
                        os.unlink(temp_path)
                else:
                    # Assume it's a local file path
                    predictions = classifier.predict(media_url, top_k=1)
                    if predictions:
                        predicted_label = list(predictions.keys())[0]
                        # Only save label if it's one of the 5 allowed labels
                        allowed_labels = {'classroom', 'computerroom', 'library', 'corridor', 'office'}
                        if predicted_label in allowed_labels:
                            image_label = predicted_label
            except Exception:
                pass
        
        message = Message(
            chat_id=chat_id,
            sender_id=sender_id,
            content=content,
            type=message_type,
            reply_to_id=reply_to_id,
            media_url=media_url,
            image_label=image_label,
            voice_duration=voice_duration,
            mentions=mentions if mentions else None,
        )
        db.add(message)
        
        # Cập nhật updated_at của chat (dùng update trực tiếp để tránh lazy-load greenlet)
        from sqlalchemy import update as sa_update
        await db.execute(
            sa_update(Chat).where(Chat.id == chat_id).values(updated_at=datetime.utcnow())
        )
        
        await db.commit()

        # Load lại message kèm sender và reactions để tránh lazy-load
        # trong context async (gây MissingGreenlet khi gọi to_dict()).
        reload_result = await db.execute(
            select(Message)
            .where(Message.id == message.id)
            .options(
                selectinload(Message.sender),
                selectinload(Message.reactions).selectinload(MessageReaction.user),
                selectinload(Message.reply_to).selectinload(Message.sender),
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
                selectinload(Message.reply_to).selectinload(Message.sender),
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
            message.is_pinned = False
        else:
            # Soft delete for this user only - thêm vào bảng deleted_messages
            deleted_msg = DeletedMessage(message_id=message_id, user_id=user_id)
            db.add(deleted_msg)

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
                selectinload(Message.reply_to).selectinload(Message.sender),
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
                selectinload(Message.reply_to).selectinload(Message.sender),
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
