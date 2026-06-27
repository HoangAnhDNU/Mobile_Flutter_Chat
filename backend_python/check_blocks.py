import asyncio
from app.database import engine
from sqlalchemy import text

async def main():
    async with engine.begin() as conn:
        result = await conn.execute(text("SELECT * FROM blocked_users"))
        rows = result.fetchall()
        for r in rows:
            print(f"blocker_id={r[1]}, blocked_id={r[2]}, report_reason={r[3]}")
        if not rows:
            print("No blocked users found")
    await engine.dispose()

asyncio.run(main())
