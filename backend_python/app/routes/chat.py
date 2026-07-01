from fastapi import APIRouter, Depends, Query, Path, Body
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
from ..services.privacy_service import PrivacyService
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
    
    # Get deleted message IDs for current user
    from sqlalchemy import select as sa_select
    from ..models.message import DeletedMessage
    del_result = await db.execute(
        sa_select(DeletedMessage.message_id).where(DeletedMessage.user_id == current_user.id)
    )
    deleted_ids = set(mid for (mid,) in del_result.all())
    
    chats_data = []
    for c in chats:
        cd = c.to_dict(current_user_id=current_user.id, deleted_message_ids=deleted_ids)
        # Apply privacy filtering to participants
        if "participants" in cd:
            filtered = []
            for p in cd["participants"]:
                pid = int(p.get("id", 0))
                if pid != current_user.id:
                    try:
                        p = await PrivacyService.filter_user_dict(db, current_user.id, p, pid)
                    except Exception:
                        pass
                filtered.append(p)
            cd["participants"] = filtered
        chats_data.append(ChatResponse(**cd))
    
    return ChatListResponse(
        chats=chats_data,
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
    
    chat_dict = chat.to_dict(current_user_id=current_user.id)
    # Apply privacy filtering to each participant
    if "participants" in chat_dict:
        filtered = []
        for p in chat_dict["participants"]:
            pid = int(p.get("id", 0))
            try:
                p = await PrivacyService.filter_user_dict(db, current_user.id, p, pid)
            except Exception:
                pass
            filtered.append(p)
        chat_dict["participants"] = filtered
    
    return {"chat": chat_dict}


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
    
    # Eager-load messages to avoid greenlet error in to_dict
    from sqlalchemy import select as sa_select
    from sqlalchemy.orm import selectinload
    from ..models.chat import Chat, ChatParticipant
    from ..models.message import Message
    eager_result = await db.execute(
        sa_select(Chat)
        .options(
            selectinload(Chat.participants).selectinload(ChatParticipant.user),
            selectinload(Chat.messages).selectinload(Message.sender),
        )
        .where(Chat.id == chat.id)
    )
    chat = eager_result.scalar_one()
    
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

    # Emit to each participant's personal room (covers both chat detail and chat list screens).
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    participants_result = await db.execute(
        sa_select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id)
    )
    participant_ids = [uid for (uid,) in participants_result.all()]

    for uid in participant_ids:
        if uid != current_user.id:
            await sio.emit(
                "new_message",
                {
                    "chatId": chat_id,
                    "senderUid": str(current_user.id),
                    "senderName": current_user.display_name,
                    "message": message_data,
                },
                room=f"user_{uid}",
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

    message_data = message.to_dict()

    # Phát realtime tới phòng chat và personal rooms
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    participants_result = await db.execute(
        sa_select(ChatParticipant.user_id).where(ChatParticipant.chat_id == message.chat_id)
    )
    for (uid,) in participants_result.all():
        await sio.emit(
            "message_edited",
            {"chatId": message.chat_id, "message": message_data},
            room=f"user_{uid}",
        )

    return {
        "message": message_data,
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
            {"chatId": chat_id, "messageId": str(message_id), "isDeleted": True},
            room=f"chat_{chat_id}",
        )
        # Also emit to personal rooms so chat list updates
        from sqlalchemy import select as sa_select
        from ..models.chat import ChatParticipant
        participants_result = await db.execute(
            sa_select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id)
        )
        for (uid,) in participants_result.all():
            await sio.emit(
                "message_deleted",
                {"chatId": chat_id, "messageId": str(message_id), "isDeleted": True},
                room=f"user_{uid}",
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
    # Emit to all participants via user rooms
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    participants_result = await db.execute(
        sa_select(ChatParticipant.user_id).where(ChatParticipant.chat_id == cid)
    )
    for (uid,) in participants_result.all():
        if uid != current_user.id:
            await sio.emit(
                "pin_update",
                {"chatId": cid, "messageId": str(message_id), "isPinned": is_pinned},
                room=f"user_{uid}",
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

    # Emit to all participants via user rooms
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    participants_result = await db.execute(
        sa_select(ChatParticipant.user_id).where(ChatParticipant.chat_id == message.chat_id)
    )
    for (uid,) in participants_result.all():
        if uid != current_user.id:
            await sio.emit(
                "reaction_update",
                {"chatId": message.chat_id, "message": message_data},
                room=f"user_{uid}",
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


@router.delete("/{chat_id}", response_model=dict)
async def delete_chat(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xóa cuộc trò chuyện cho phía người dùng hiện tại (ẩn + xóa nội dung, không ảnh hưởng bên kia)."""
    from sqlalchemy import select, and_
    from ..models.chat import ChatParticipant
    from datetime import datetime

    participant = (await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
            )
        )
    )).scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=403, detail="Bạn không có quyền với cuộc trò chuyện này")

    participant.is_hidden = True
    participant.messages_cleared_at = datetime.utcnow()
    await db.commit()
    return {"message": "Đã xóa cuộc trò chuyện"}


# ==================== FORWARD MESSAGE ====================

@router.post("/messages/{message_id}/forward", response_model=dict)
async def forward_message(
    message_id: int = Path(...),
    payload: dict = Body(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Chuyển tiếp tin nhắn sang chat khác"""
    from sqlalchemy import select, and_
    from ..models.message import Message
    from ..models.chat import ChatParticipant
    from fastapi import HTTPException

    target_chat_id = int(payload.get("target_chat_id", 0))
    # Get original message
    original = (await db.execute(
        select(Message).where(Message.id == message_id)
    )).scalar_one_or_none()
    if not original:
        raise HTTPException(status_code=404, detail="Tin nhắn không tồn tại")

    # Check user is participant of target chat
    check = (await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == target_chat_id,
                ChatParticipant.user_id == current_user.id,
            )
        )
    )).scalar_one_or_none()
    if not check:
        raise HTTPException(status_code=403, detail="Bạn không phải thành viên chat đích")

    # Create forwarded message
    forwarded = Message(
        chat_id=target_chat_id,
        sender_id=current_user.id,
        content=original.content,
        type=original.type,
        media_url=original.media_url,
        thumbnail_url=original.thumbnail_url,
        forwarded=True,
    )
    db.add(forwarded)
    await db.flush()
    await db.refresh(forwarded, attribute_names=["sender", "reactions", "created_at", "edited_at", "status", "is_pinned", "is_deleted", "forwarded", "image_label"])

    message_data = forwarded.to_dict()
    await sio.emit("new_message", {
        "chatId": target_chat_id,
        "senderUid": str(current_user.id),
        "senderName": current_user.display_name,
        "message": message_data,
    }, room=f"chat_{target_chat_id}")

    return {"message": message_data}


# ==================== ARCHIVE ====================

@router.post("/{chat_id}/archive", response_model=dict)
async def toggle_archive(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lưu trữ / bỏ lưu trữ chat"""
    participant = (await db.execute(
        select(ChatParticipant).where(
            and_(
                ChatParticipant.chat_id == chat_id,
                ChatParticipant.user_id == current_user.id,
            )
        )
    )).scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=403, detail="Bạn không phải thành viên")

    participant.is_archived = not participant.is_archived
    return {
        "is_archived": participant.is_archived,
        "message": "Đã lưu trữ" if participant.is_archived else "Đã bỏ lưu trữ"
    }


# ==================== LINK PREVIEW (OpenGraph) ====================

@router.get("/og/preview", response_model=dict)
async def get_link_preview(
    url: str = Query(..., min_length=1),
    current_user: User = Depends(get_current_user),
):
    """Fetch OpenGraph metadata for a URL (proxy to avoid CORS)."""
    import httpx
    import re
    from urllib.parse import urlparse

    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        return {"title": None, "description": None, "image": None, "siteName": None}

    try:
        async with httpx.AsyncClient(timeout=8, follow_redirects=True) as client:
            resp = await client.get(url, headers={"User-Agent": "Mozilla/5.0 (compatible; LinkPreview/1.0)"})
            html = resp.text[:50000]  # Only parse first 50KB

        def extract_meta(prop: str) -> str | None:
            m = re.search(rf'<meta[^>]+(?:property|name)=["\']({prop})["\'][^>]+content=["\']([^"\']*)["\']', html, re.IGNORECASE)
            if m:
                return m.group(2).strip()
            m2 = re.search(rf'<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']({prop})["\']', html, re.IGNORECASE)
            if m2:
                return m2.group(1).strip()
            return None

        title = extract_meta("og:title") or extract_meta("twitter:title")
        description = extract_meta("og:description") or extract_meta("twitter:description") or extract_meta("description")
        image = extract_meta("og:image") or extract_meta("twitter:image")
        site_name = extract_meta("og:site_name")

        if not title:
            t = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
            if t:
                title = t.group(1).strip()

        if image and not image.startswith("http"):
            base = f"{parsed.scheme}://{parsed.netloc}"
            image = base + (image if image.startswith("/") else "/" + image)

        return {
            "title": title,
            "description": description,
            "image": image,
            "siteName": site_name or parsed.netloc,
        }
    except Exception:
        return {"title": None, "description": None, "image": None, "siteName": None}


@router.get("/{chat_id}/auto-delete")
async def get_auto_delete(
    chat_id: int = Path(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    from fastapi import HTTPException
    result = await db.execute(
        sa_select(ChatParticipant).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == current_user.id,
        )
    )
    participant = result.scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")
    return {"auto_delete_days": participant.auto_delete_days}


@router.put("/{chat_id}/auto-delete")
async def set_auto_delete(
    chat_id: int = Path(...),
    days: int = Body(..., embed=True),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select as sa_select
    from ..models.chat import ChatParticipant
    from fastapi import HTTPException
    result = await db.execute(
        sa_select(ChatParticipant).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == current_user.id,
        )
    )
    participant = result.scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")
    participant.auto_delete_days = days if days and days > 0 else None
    await db.commit()
    return {"auto_delete_days": participant.auto_delete_days}
