"""
Seed dữ liệu mẫu vào database (Code First Approach)
Chạy: python -m app.seed_data
"""
import asyncio
import base64
import os
from datetime import datetime, timedelta
from passlib.context import CryptContext
from sqlalchemy import select, text

from .database import async_session_maker, init_db
from .models import User, Chat, ChatParticipant, Message, MessageReaction, MessageReadStatus

# Password hasher (giảm rounds để tránh lỗi)
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=10  # Giảm từ default 12 xuống 10
)

# Thư mục chứa ảnh avatar mẫu (ở gốc repo: images_avatar/)
AVATAR_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "images_avatar")
)


def load_avatar_data_uri(filename: str) -> str | None:
    """Đọc file ảnh PNG và chuyển thành data URI base64.

    Flutter đã hỗ trợ hiển thị ảnh dạng 'data:image/...;base64,...' nên lưu
    thẳng vào avatar_url là cách gọn nhất, không cần serve file tĩnh.
    """
    path = os.path.join(AVATAR_DIR, filename)
    if not os.path.isfile(path):
        print(f"⚠️  Không tìm thấy avatar: {path}")
        return None
    with open(path, "rb") as f:
        encoded = base64.b64encode(f.read()).decode("utf-8")
    return f"data:image/png;base64,{encoded}"


async def seed_users(session):
    """Tạo 4 user mẫu"""
    print("📝 Đang tạo users...")
    
    users_data = [
        {
            "email": "admin@gmail.com",
            "password": "Admin123",
            "display_name": "Quản trị viên",
            "avatar": None,
            "role": "admin",
            "is_online": False,
            "last_seen": datetime.now(),
        },
        {
            "email": "thanhtung@gmail.com",
            "password": "ThanhTung",
            "display_name": "Thanh Tùng",
            "avatar": "ThanhTung.png",
            "role": "user",
            "is_online": False,
            "last_seen": datetime.now(),
        },
        {
            "email": "haiphong@gmail.com",
            "password": "HaiPhong",
            "display_name": "Hải Phong",
            "avatar": "HaiPhong.png",
            "role": "user",
            "is_online": False,
            "last_seen": datetime.now(),
        },
        {
            "email": "linhtran@gmail.com",
            "password": "LinhTran",
            "display_name": "Linh Trần",
            "avatar": None,
            "role": "user",
            "is_online": False,
            "last_seen": datetime.now() - timedelta(minutes=12),
        },
        {
            "email": "minhnguyen@gmail.com",
            "password": "MinhNguyen",
            "display_name": "Minh Nguyễn",
            "avatar": "NhatMinh.png",
            "role": "user",
            "is_online": False,
            "last_seen": datetime.now() - timedelta(hours=1),
        },
    ]
    
    users = []
    for data in users_data:
        # Hash password
        password_hash = pwd_context.hash(data["password"])
        avatar_url = load_avatar_data_uri(data["avatar"]) if data.get("avatar") else None
        
        user = User(
            email=data["email"],
            password_hash=password_hash,
            display_name=data["display_name"],
            avatar_url=avatar_url,
            role=data.get("role", "user"),
            is_online=data["is_online"],
            last_seen=data["last_seen"],
            created_at=datetime.now(),
        )
        session.add(user)
        users.append(user)
    
    await session.flush()  # Lấy ID của users
    print(f"✅ Đã tạo {len(users)} users")
    return users


async def seed_chats(session, users):
    """Tạo 2 chats mẫu"""
    print("📝 Đang tạo chats...")
    
    # Chat 1-1 giữa Thanh Tùng và Hải Phong
    chat1 = Chat(
        name=None,  # Chat 1-1 không có tên
        is_group=False,
        creator_id=users[0].id,
        created_at=datetime.now() - timedelta(days=15),
    )
    session.add(chat1)
    
    # Chat nhóm: Nhóm đồ án môn mobile
    chat2 = Chat(
        name="Nhóm đồ án môn mobile",
        is_group=True,
        creator_id=users[0].id,
        created_at=datetime.now() - timedelta(days=5),
    )
    session.add(chat2)
    
    await session.flush()
    
    # Thêm participants cho chat 1
    session.add(ChatParticipant(
        chat_id=chat1.id,
        user_id=users[0].id,
        role="admin",
        joined_at=datetime.now() - timedelta(days=15),
    ))
    session.add(ChatParticipant(
        chat_id=chat1.id,
        user_id=users[1].id,
        role="member",
        joined_at=datetime.now() - timedelta(days=15),
    ))
    
    # Thêm participants cho chat 2
    session.add(ChatParticipant(
        chat_id=chat2.id,
        user_id=users[0].id,
        role="admin",
        joined_at=datetime.now() - timedelta(days=5),
    ))
    session.add(ChatParticipant(
        chat_id=chat2.id,
        user_id=users[1].id,
        role="member",
        is_muted=True,
        joined_at=datetime.now() - timedelta(days=5),
    ))
    session.add(ChatParticipant(
        chat_id=chat2.id,
        user_id=users[2].id,
        role="member",
        joined_at=datetime.now() - timedelta(days=4),
    ))
    session.add(ChatParticipant(
        chat_id=chat2.id,
        user_id=users[3].id,
        role="member",
        joined_at=datetime.now() - timedelta(days=4),
    ))
    
    await session.flush()
    print(f"✅ Đã tạo 2 chats với participants")
    return [chat1, chat2]


async def seed_messages(session, chats, users):
    """Tạo messages mẫu"""
    print("📝 Đang tạo messages...")
    
    # Messages cho chat 1 (Thanh Tùng <-> Hải Phong)
    msg1 = Message(
        chat_id=chats[0].id,
        sender_id=users[0].id,
        content="Xin chào Phong, tôi vừa cập nhật API media UUID.",
        type="text",
        status="read",
        created_at=datetime.now() - timedelta(minutes=45),
    )
    session.add(msg1)
    await session.flush()
    
    msg2 = Message(
        chat_id=chats[0].id,
        sender_id=users[1].id,
        content="Tuyệt vời, gửi mình ảnh giao diện mới nhé.",
        type="text",
        status="read",
        reply_to_id=msg1.id,
        created_at=datetime.now() - timedelta(minutes=40),
    )
    session.add(msg2)
    await session.flush()
    
    msg3 = Message(
        chat_id=chats[0].id,
        sender_id=users[0].id,
        content="Đây là ảnh demo giao diện mới",
        type="image",
        status="delivered",
        created_at=datetime.now() - timedelta(minutes=35),
    )
    session.add(msg3)
    await session.flush()
    
    msg4 = Message(
        chat_id=chats[0].id,
        sender_id=users[1].id,
        content="Tôi đã gửi tài liệu cho bạn rồi nhé",
        type="text",
        status="sent",
        created_at=datetime.now() - timedelta(minutes=3),
    )
    session.add(msg4)
    
    # Messages cho chat 2 (Nhóm)
    msg5 = Message(
        chat_id=chats[1].id,
        sender_id=users[3].id,
        content="Mình đã cập nhật màn hình profile",
        type="text",
        status="sent",
        edited_at=datetime.now() - timedelta(minutes=10),
        created_at=datetime.now() - timedelta(minutes=12),
    )
    session.add(msg5)
    await session.flush()
    
    msg6 = Message(
        chat_id=chats[1].id,
        sender_id=users[2].id,
        content="OK, tôi sẽ test lại trên web và Android.",
        type="text",
        status="sent",
        reply_to_id=msg5.id,
        created_at=datetime.now() - timedelta(minutes=9),
    )
    session.add(msg6)
    
    msg7 = Message(
        chat_id=chats[1].id,
        sender_id=users[0].id,
        content="Nhớ check thêm typing icon và Enter-to-send.",
        type="text",
        status="sent",
        created_at=datetime.now() - timedelta(minutes=7),
    )
    session.add(msg7)
    
    await session.flush()
    
    # Thêm reactions
    session.add(MessageReaction(
        message_id=msg1.id,
        user_id=users[1].id,
        emoji="👍",
        created_at=datetime.now() - timedelta(minutes=39),
    ))
    session.add(MessageReaction(
        message_id=msg3.id,
        user_id=users[1].id,
        emoji="🔥",
        created_at=datetime.now() - timedelta(minutes=33),
    ))
    session.add(MessageReaction(
        message_id=msg5.id,
        user_id=users[0].id,
        emoji="✅",
        created_at=datetime.now() - timedelta(minutes=8),
    ))
    
    # Thêm read status
    session.add(MessageReadStatus(
        message_id=msg1.id,
        user_id=users[1].id,
        read_at=datetime.now() - timedelta(minutes=39),
    ))
    session.add(MessageReadStatus(
        message_id=msg2.id,
        user_id=users[0].id,
        read_at=datetime.now() - timedelta(minutes=38),
    ))
    
    await session.flush()
    print(f"✅ Đã tạo 7 messages với reactions và read status")


async def clear_all_data(session):
    """Xóa toàn bộ dữ liệu cũ"""
    print("🗑️  Đang xóa dữ liệu cũ...")
    
    # Xóa theo thứ tự (foreign keys)
    await session.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
    
    for model in [MessageReadStatus, MessageReaction, Message, ChatParticipant, Chat, User]:
        await session.execute(text(f"DELETE FROM {model.__tablename__}"))
    
    await session.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
    await session.commit()
    print("✅ Đã xóa toàn bộ dữ liệu cũ")


async def migrate_longtext_columns(session):
    """Đổi các cột lưu ảnh base64 sang LONGTEXT.

    Code First (create_all) không tự sửa kiểu cột của bảng đã tồn tại,
    nên cần ALTER thủ công để chứa được ảnh base64 lớn (> 64KB).
    """
    print("🔧 Đang nâng cấp cột ảnh sang LONGTEXT...")
    alters = [
        "ALTER TABLE users MODIFY avatar_url LONGTEXT NULL",
        "ALTER TABLE chats MODIFY avatar_url LONGTEXT NULL",
        "ALTER TABLE messages MODIFY media_url LONGTEXT NULL",
        "ALTER TABLE messages MODIFY thumbnail_url LONGTEXT NULL",
        # Thêm cột phân quyền/khóa tài khoản nếu chưa có
        "ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'user'",
        "ALTER TABLE users ADD COLUMN is_locked TINYINT(1) NOT NULL DEFAULT 0",
    ]
    for stmt in alters:
        try:
            await session.execute(text(stmt))
        except Exception as e:
            print(f"⚠️  Bỏ qua ALTER ({stmt}): {e}")
    await session.commit()
    print("✅ Đã nâng cấp cột ảnh")


async def seed_all():
    """Chạy toàn bộ seed process"""
    print("\n" + "="*60)
    print("🌱 BẮT ĐẦU SEED DỮ LIỆU MẪU (CODE FIRST)")
    print("="*60 + "\n")
    
    # 1. Tạo tables (nếu chưa có)
    print("📦 Đang khởi tạo database tables...")
    await init_db()
    print("✅ Database tables đã sẵn sàng\n")
    
    # 2. Seed dữ liệu
    async with async_session_maker() as session:
        try:
            # Xóa dữ liệu cũ
            await clear_all_data(session)
            
            # Nâng cấp cột ảnh sang LONGTEXT (để chứa avatar base64)
            await migrate_longtext_columns(session)
            
            # Tạo dữ liệu mới
            users = await seed_users(session)
            # users[0] là admin, các chat/message mẫu dùng 4 user thường còn lại
            normal_users = users[1:]
            chats = await seed_chats(session, normal_users)
            await seed_messages(session, chats, normal_users)
            
            # Commit tất cả
            await session.commit()
            
            print("\n" + "="*60)
            print("🎉 SEED DỮ LIỆU THÀNH CÔNG!")
            print("="*60)
            print("\n📊 Thống kê:")
            print(f"  - Users: 5 (1 admin + 4 user)")
            print(f"  - Chats: 2 (1 chat 1-1, 1 nhóm)")
            print(f"  - Messages: 7")
            print(f"  - Reactions: 3")
            print(f"  - Read Status: 2")
            print("\n🔑 Tài khoản test:")
            print("  - admin@gmail.com / Admin123  (Quản trị viên)")
            print("  - thanhtung@gmail.com / ThanhTung")
            print("  - haiphong@gmail.com / HaiPhong")
            print("  - linhtran@gmail.com / LinhTran")
            print("  - minhnguyen@gmail.com / MinhNguyen")
            print("\n✅ Bạn có thể đăng nhập bằng bất kỳ tài khoản nào ở trên!")
            print("="*60 + "\n")
            
        except Exception as e:
            await session.rollback()
            print(f"\n❌ LỖI: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(seed_all())
