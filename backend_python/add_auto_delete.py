import asyncio
from app.database import engine
from sqlalchemy import text

async def main():
    async with engine.begin() as conn:
        try:
            await conn.execute(text(
                "ALTER TABLE chat_participants ADD COLUMN auto_delete_days INT NULL"
            ))
            print("✅ Added auto_delete_days column")
        except Exception as e:
            if "Duplicate column" in str(e):
                print("ℹ️ Column already exists")
            else:
                raise
    await engine.dispose()

asyncio.run(main())
