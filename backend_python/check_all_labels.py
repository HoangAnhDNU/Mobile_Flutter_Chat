import asyncio
from app.database import async_session_maker
from sqlalchemy import text

async def check_all_labels():
    async with async_session_maker() as db:
        result = await db.execute(text('SELECT DISTINCT image_label FROM messages WHERE image_label IS NOT NULL'))
        rows = result.fetchall()
        print("Distinct image_labels:")
        for row in rows:
            print(f"  {row[0]}")

asyncio.run(check_all_labels())
