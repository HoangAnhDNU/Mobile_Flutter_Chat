from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
import pymysql
from .config import settings


def create_database_if_not_exists():
    """Tạo database nếu chưa tồn tại"""
    # Parse database URL
    # Format: mysql+aiomysql://user:password@host:port/dbname
    db_url = settings.database_url
    db_url = db_url.replace("mysql+aiomysql://", "")
    user_pass, host_db = db_url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = host_db.split("/")
    host = host_port.split(":")[0]
    port = int(host_port.split(":")[1]) if ":" in host_port else 3306
    
    try:
        # Kết nối MySQL server (không chỉ định database)
        conn = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            charset='utf8mb4',
        )
        cursor = conn.cursor()
        
        # Kiểm tra database tồn tại
        cursor.execute(f"SHOW DATABASES LIKE '{dbname}'")
        result = cursor.fetchone()
        
        if not result:
            # Tạo database mới
            print(f"📦 Database '{dbname}' không tồn tại. Đang tạo...")
            cursor.execute(
                f"CREATE DATABASE {dbname} "
                f"CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
            print(f"✅ Đã tạo database: {dbname}")
        else:
            print(f"✅ Database '{dbname}' đã tồn tại")
        
        conn.commit()
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Lỗi khi tạo database: {e}")
        raise


# Async Engine
engine = create_async_engine(
    settings.database_url,
    echo=True,  # Set False in production
    pool_pre_ping=True,
    pool_recycle=3600,
)

# Async Session Factory
async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class cho tất cả models"""
    pass


async def get_db() -> AsyncSession:
    """Dependency để inject database session"""
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """Khởi tạo database và tables"""
    # Bước 1: Tạo database nếu chưa tồn tại
    create_database_if_not_exists()
    
    # Bước 2: Tạo tables từ models
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Bước 3: Migration nhẹ - thêm cột mới vào bảng cũ (create_all không tự ALTER).
    from sqlalchemy import text
    migrations = [
        "ALTER TABLE messages ADD COLUMN is_pinned TINYINT(1) NOT NULL DEFAULT 0",
        "CREATE TABLE IF NOT EXISTS deleted_messages (id INT AUTO_INCREMENT PRIMARY KEY, message_id INT NOT NULL, user_id INT NOT NULL, deleted_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE, FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE)",
        "ALTER TABLE messages ADD COLUMN image_label VARCHAR(50) NULL",
        "ALTER TABLE messages ADD COLUMN expires_at DATETIME NULL",
        "ALTER TABLE messages ADD COLUMN forwarded TINYINT(1) NOT NULL DEFAULT 0",
    ]
    async with engine.begin() as conn:
        for stmt in migrations:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass  # Cột/bảng đã tồn tại -> bỏ qua
