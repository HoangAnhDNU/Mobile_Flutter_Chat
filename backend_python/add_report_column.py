import asyncio
from app.database import engine
from sqlalchemy import text

async def main():
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE blocked_users ADD COLUMN report_reason TEXT NULL"))
            print("Added report_reason column to blocked_users")
        except Exception as e:
            print(f"Column may already exist: {e}")
    await engine.dispose()

asyncio.run(main())
