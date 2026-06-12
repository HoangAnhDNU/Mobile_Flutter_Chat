from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..schemas.chat import (
    CreateDirectChatRequest, 
    CreateGroupChatRequest,
    UpdateGroupRequest,
    AddParticipantsRequest,
    ChatResponse,
    ChatListResponse
)
from ..schemas.message import (
    SendMessageRequest,
    EditMessageRequest,
    AddReactionRequest,
    MessageResponse,
    MessageListResponse
)
from ..services.chat_service import ChatService
from ..services.message_service import MessageService
from ..dependencies import get_current_user
from ..models.user import User
from ..socket_instance import sio

router = APIRouter()


# ==================== CHAT ROUTES ====================

@router.get("", response_model=ChatListResponse)
async def get_chats(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách chats"""
    chats, total = await ChatService.get_chats(
        db=db,
        user_id=current_user.id,
        page=page,
        limit=limit
    )
    
    return ChatListResponse(
        chats=[ChatResponse(**c.to_dict(current_user_id=current_user.id)) for c in chats],
        total=total
    )


@router.get("/{chat_id}", response_model=dict)
async def get_chat(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy chi tiết một chat"""
    chat = await ChatService.get_chat_by_id(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id
    )
    
    return {"chat": chat.to_dict(current_user_id=current_user.id)}


@router.post("/direct", response_model=dict)
async def create_direct_chat(
    request: CreateDirectChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tạo chat 1-1"""
    chat = await ChatService.create_direct_chat(
        db=db,
        user_id=current_user.id,
        target_user_id=int(request.user_id)
    )
    
    return {
        "chat": chat.to_dict(current_user_id=current_user.id),
        "message": "Tạo cuộc hội thoại thành công"
    }


@router.post("/group", response_model=dict)
async def create_group_chat(
    request: CreateGroupChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tạo nhóm chat"""
    chat = await ChatService.create_group_chat(
        db=db,
        user_id=current_user.id,
        name=request.name,
        participant_ids=[int(pid) for pid in request.participant_ids],
        avatar_url=request.avatar_url
    )
    
    return {
        "chat": chat.to_dict(current_user_id=current_user.id),
        "message": "Tạo nhóm thành công"
    }


@router.post("/{chat_id}/participants", response_model=dict)
async def add_participants(
    request: AddParticipantsRequest,
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Thêm thành viên vào nhóm"""
    await ChatService.add_participants(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id,
        new_user_ids=[int(uid) for uid in request.user_ids]
    )
    
    return {"message": "Thêm thành viên thành công"}


@router.delete("/{chat_id}/participants/{user_id}", response_model=dict)
async def remove_participant(
    chat_id: int = Path(...),
    user_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xóa thành viên khỏi nhóm"""
    await ChatService.remove_participant(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id,
        target_user_id=user_id
    )
    
    return {"message": "Xóa thành viên thành công"}


@router.post("/{chat_id}/leave", response_model=dict)
async def leave_group(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Rời khỏi nhóm"""
    await ChatService.leave_group(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id
    )
    
    return {"message": "Rời khỏi nhóm thành công"}


@router.post("/{chat_id}/pin", response_model=dict)
async def toggle_pin(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Ghim/bỏ ghim chat"""
    is_pinned = await ChatService.toggle_pin(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id
    )
    
    return {
        "is_pinned": is_pinned,
        "message": "Ghim chat" if is_pinned else "Bỏ ghim chat"
    }


@router.post("/{chat_id}/mute", response_model=dict)
async def toggle_mute(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tắt/bật thông báo"""
    is_muted = await ChatService.toggle_mute(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id
    )
    
    return {
        "is_muted": is_muted,
        "message": "Tắt thông báo" if is_muted else "Bật thông báo"
    }


# ==================== MESSAGE ROUTES ====================

@router.get("/{chat_id}/messages", response_model=MessageListResponse)
async def get_messages(
    chat_id: int = Path(...),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy tin nhắn của chat"""
    messages, total, has_more = await MessageService.get_messages(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id,
        page=page,
        limit=limit
    )
    
    return MessageListResponse(
        messages=[MessageResponse(**m.to_dict()) for m in messages],
        total=total,
        has_more=has_more
    )


@router.post("/{chat_id}/messages", response_model=dict)
async def send_message(
    request: SendMessageRequest,
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Gửi tin nhắn"""
    message = await MessageService.send_message(
        db=db,
        chat_id=chat_id,
        sender_id=current_user.id,
        content=request.content,
        message_type=request.type,
        reply_to_id=int(request.reply_to_id) if request.reply_to_id else None,
        media_url=request.media_url,
    )

    message_data = message.to_dict()

    # Phát tin nhắn realtime tới tất cả thành viên đang ở trong phòng chat.
    await sio.emit(
        "new_message",
        {
            "chatId": chat_id,
            "senderUid": str(current_user.id),
            "senderName": current_user.display_name,
            "message": message_data,
        },
        room=f"chat_{chat_id}",
    )

    return {
        "message": message_data,
    }


@router.put("/messages/{message_id}", response_model=dict)
async def edit_message(
    request: EditMessageRequest,
    message_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Sửa tin nhắn"""
    message = await MessageService.edit_message(
        db=db,
        message_id=message_id,
        user_id=current_user.id,
        new_content=request.content
    )
    
    return {
        "message": message.to_dict(),
    }


@router.delete("/messages/{message_id}", response_model=dict)
async def delete_message(
    message_id: int = Path(...),
    for_everyone: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xóa tin nhắn"""
    chat_id = await MessageService.delete_message(
        db=db,
        message_id=message_id,
        user_id=current_user.id,
        delete_for_everyone=for_everyone
    )

    # Phát realtime để các thành viên ẩn/cập nhật tin nhắn ngay.
    if for_everyone:
        await sio.emit(
            "message_deleted",
            {"chatId": chat_id, "messageId": str(message_id)},
            room=f"chat_{chat_id}",
        )

    return {"message": "Xóa tin nhắn thành công"}


@router.post("/{chat_id}/messages/{message_id}/pin", response_model=dict)
async def toggle_pin_message(
    chat_id: int = Path(...),
    message_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Ghim/bỏ ghim một tin nhắn (tối đa 3 tin mỗi chat)."""
    cid, is_pinned = await MessageService.toggle_pin(
        db=db,
        message_id=message_id,
        user_id=current_user.id,
    )
    await sio.emit(
        "pin_update",
        {"chatId": cid, "messageId": str(message_id), "isPinned": is_pinned},
        room=f"chat_{cid}",
    )
    return {"is_pinned": is_pinned, "message": "Đã ghim" if is_pinned else "Đã bỏ ghim"}


@router.get("/{chat_id}/pinned", response_model=dict)
async def get_pinned_messages(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Danh sách tin nhắn đã ghim."""
    messages = await MessageService.get_pinned_messages(
        db=db, chat_id=chat_id, user_id=current_user.id
    )
    return {"messages": [m.to_dict() for m in messages], "total": len(messages)}


@router.post("/messages/{message_id}/reactions", response_model=dict)
async def add_reaction(
    request: AddReactionRequest,
    message_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Thêm reaction"""
    message = await MessageService.add_reaction(
        db=db,
        message_id=message_id,
        user_id=current_user.id,
        emoji=request.emoji
    )

    message_data = message.to_dict()

    # Phát realtime để các thành viên thấy reaction cập nhật ngay.
    await sio.emit(
        "reaction_update",
        {"chatId": message.chat_id, "message": message_data},
        room=f"chat_{message.chat_id}",
    )

    return {
        "message": message_data,
    }


@router.delete("/messages/reactions/{reaction_id}", response_model=dict)
async def remove_reaction(
    reaction_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xóa reaction"""
    await MessageService.remove_reaction(
        db=db,
        reaction_id=reaction_id,
        user_id=current_user.id
    )
    
    return {"message": "Xóa reaction thành công"}


@router.post("/{chat_id}/read", response_model=dict)
async def mark_as_read(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Đánh dấu đã đọc"""
    await MessageService.mark_as_read(
        db=db,
        chat_id=chat_id,
        user_id=current_user.id
    )
    
    return {"message": "Đã đánh dấu đã đọc"}


@router.get("/{chat_id}/search", response_model=dict)
async def search_messages(
    chat_id: int = Path(...),
    q: str = Query(..., min_length=1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Tìm kiếm tin nhắn theo từ khóa trong một cuộc trò chuyện."""
    from sqlalchemy import select, and_, desc
    from sqlalchemy.orm import selectinload
    from ..models.message import Message, MessageReaction
    from ..models.chat import ChatParticipant

    # Verify participant
    check = (await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
            )
        )
    )).scalar_one_or_none()
    if not check:
        raise HTTPException(status_code=403, detail="Bạn không có quyền xem tin nhắn này")

    result = await db.execute(
        select(Message)
        .where(
            and_(
                Message.chat_id == chat_id,
                Message.is_deleted == False,  # noqa: E712
                Message.content.ilike(f"%{q}%"),
            )
        )
        .options(
            selectinload(Message.sender),
            selectinload(Message.reactions).selectinload(MessageReaction.user),
        )
        .order_by(desc(Message.created_at))
    )
    messages = list(result.scalars().unique().all())
    return {"messages": [m.to_dict() for m in messages], "total": len(messages)}


@router.delete("/{chat_id}/messages", response_model=dict)
async def clear_chat_history(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xóa toàn bộ tin nhắn trong một cuộc trò chuyện."""
    from sqlalchemy import select, and_, delete
    from ..models.message import Message
    from ..models.chat import ChatParticipant

    check = (await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
            )
        )
    )).scalar_one_or_none()
    if not check:
        raise HTTPException(status_code=403, detail="Bạn không có quyền với cuộc trò chuyện này")

    await db.execute(delete(Message).where(Message.chat_id == chat_id))
    await db.commit()
    await sio.emit("history_cleared", {"chatId": chat_id}, room=f"chat_{chat_id}")
    return {"message": "Đã xóa toàn bộ lịch sử trò chuyện"}
