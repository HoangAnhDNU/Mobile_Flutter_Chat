import asyncio
from app.database import async_session_maker
from sqlalchemy import text

async def check_labels():
    async with async_session_maker() as db:
        result = await db.execute(text('SELECT id, image_label FROM messages WHERE type="image" ORDER BY id DESC LIMIT 10'))
        rows = result.fetchall()
        print("ID | image_label")
        print("---|-----------")
        for row in rows:
            print(f"{row[0]} | {row[1]}")

asyncio.run(check_labels())
