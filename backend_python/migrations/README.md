# Migration Media → BLOB

## Tóm tắt

Trước đây voice/image được lưu dưới dạng **base64 string** trong cột `media_url LONGTEXT`,
gây phình DB, query chậm, và phải encode/ decode nhiều lần.

Bây giờ chuyển sang lưu **binary thô** trong cột `media_data LONGBLOB`, kèm metadata:

| Cột mới        | Kiểu        | Mô tả                                          |
|----------------|-------------|------------------------------------------------|
| `media_data`   | LONGBLOB    | File nhị phân (m4a, jpg, png...) — tối đa 4GB  |
| `media_mime`   | VARCHAR(50) | MIME: `audio/wav`, `image/jpeg`, `image/png`...|
| `media_size`   | INT         | Dung lượng (bytes)                             |
| `thumbnail_data` | MEDIUMBLOB | Thumbnail (16MB max)                           |
| `thumbnail_mime` | VARCHAR(50)| MIME thumbnail                                 |
| `media_url`    | VARCHAR(500)| Giữ lại cho URL ngoài (legacy/fallback)        |

Khi trả về JSON, backend tự encode BLOB → **data URI base64** để client dùng trực tiếp:
```
"media_url": "data:image/jpeg;base64,/9j/4AAQ..."
```

## Cách apply

### 1) Database mới (drop cũ, tạo lại)
```bash
mysql -u root -p
DROP DATABASE mobile_flutter_chat;
CREATE DATABASE mobile_flutter_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
exit;
```
Sau đó chạy backend (sẽ tự `init_db`):
```bash
cd backend_python && python run.py
```
Sau đó seed:
```bash
python -m app.seed_data
```

### 2) Database cũ đang có data
```bash
mysql -u root -p mobile_flutter_chat < backend_python/migrations/migration_media_to_blob.sql
```
Lưu ý: lệnh ALTER `MODIFY media_url VARCHAR(500)` sẽ **cắt bỏ** data URI base64 cũ.
Nếu muốn giữ, hãy backup trước hoặc sửa model để không chạy lệnh đó.

## Sample media

Hai file mẫu được seed script đọc từ thư mục `images_avatar/`:

| File                 | Kích thước | MIME         | Nội dung                              |
|----------------------|------------|--------------|---------------------------------------|
| `sample_image.jpg`   | 28 KB      | `image/jpeg` | JPEG thật có gradient + icon + text   |
| `sample_voice.wav`   | 64 KB      | `audio/wav`  | WAV 2s, 16kHz mono (im lặng)          |

## Verify sau migration

```bash
# Login + get messages
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"thanhtung@gmail.com","password":"ThanhTung"}'
# Lấy token, gọi:
curl http://localhost:3000/api/chat/{chat_id}/messages \
  -H "Authorization: Bearer <token>"
```

Kết quả mong đợi:
```json
{
  "id": "19",
  "type": "image",
  "media_url": "data:image/jpeg;base64,/9j/4AAQ...",
  "media_mime": "image/jpeg",
  "media_size": 28347
}
```

## Giới hạn LONGBLOB

- Tối đa 4GB (vượt xa nhu cầu tin nhắn thoại/ảnh chat)
- `max_allowed_packet` của MySQL cần ≥ 16MB để nhận voice ~10 phút
  - Kiểm tra: `SHOW VARIABLES LIKE 'max_allowed_packet';`
  - Sửa trong `my.ini`: `max_allowed_packet=64M`