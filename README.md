# Mobile Flutter Chat

Ứng dụng chat realtime xây dựng bằng Flutter + Node.js + MySQL.

## Tính năng

- Đăng nhập / Đăng ký / Quên mật khẩu
- Chat 1-1 và nhóm (text, ảnh, voice)
- WebSocket real-time messaging
- Delivery & read receipts (✓ / ✓✓ / ✓✓ xanh)
- Reply / Quote messages
- Emoji reactions
- Tìm kiếm tin nhắn
- Pin / Delete for me / Delete for everyone
- Mute / Archive chats
- Block / Unblock users
- Link preview
- Dark mode / Light mode

## Cài đặt

### Backend

```bash
cd backend
cp template.env .env   # Sửa thông tin trong .env
npm install
mysql -u root < database/schema.sql
mysql -u root < database/migration_v2.sql
npm run dev
```

### Flutter

```bash
flutter pub get
flutter run
```

## Công nghệ

- **Frontend**: Flutter, Provider, WebSocket
- **Backend**: Node.js, Express, Socket.IO
- **Database**: MySQL
- **Auth**: JWT
