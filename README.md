# Mobile Flutter Chat

Ứng dụng chat realtime xây dựng bằng Flutter + Node.js + MySQL.

## Tính năng

- Đăng nhập / Đăng ký
- Chat 1-1 và nhóm (text, ảnh)
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

## Công nghệ sử dụng

| Thành phần | Công nghệ |
|-----------|-----------|
| Frontend | Flutter 3.x, Dart, Provider (state management) |
| Backend | Node.js, Express.js, Socket.IO |
| Database | MySQL 8.0 |
| Auth | JWT (JSON Web Token) |
| Realtime | WebSocket (web_socket_channel) |

## Yêu cầu hệ thống

- **Flutter SDK** >= 3.0
- **Node.js** >= 18.x
- **MySQL** >= 8.0
- **Android Studio** hoặc VS Code với Flutter extension
- **Thiết bị Android** (thật hoặc emulator)

---

## Hướng dẫn cài đặt và chạy

### Bước 1: Clone dự án

```bash
git clone <repo_url>
cd mobile_flutter_chat
```

### Bước 2: Cài đặt Backend

```bash
cd backend
npm install
```

### Bước 3: Cấu hình file `.env`

```bash
cp template.env .env
```

Mở `backend/.env` và sửa thông tin MySQL:

```env
PORT=3000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password    # ← Đổi thành mật khẩu MySQL của bạn
DB_NAME=mobile_flutter_chat
JWT_SECRET=any_random_string_here  # ← Đặt chuỗi bất kỳ
```

### Bước 4: Tạo Database

Mở **MySQL Workbench** (hoặc terminal MySQL), chạy lần lượt 2 file SQL:

```sql
-- File 1: Tạo database + bảng cơ bản
source C:/đường_dẫn_đến_project/backend/database/schema.sql;

-- File 2: Thêm các cột mới (reactions, pin, reply, v.v.)
source C:/đường_dẫn_đến_project/backend/database/migration_v2.sql;
```

Hoặc dùng menu **File → Open SQL Script** trong MySQL Workbench, chọn từng file và nhấn Execute (⚡).

### Bước 5: Chạy Backend

```bash
cd backend
npm run dev
```

Nếu thành công sẽ thấy:
```
Server running on port 3000
WebSocket ready on port 3000
```

### Bước 6: Cấu hình IP cho Flutter

Mở file `lib/core/constants/app_config.dart` và đổi `serverHost`:

```dart
class AppConfig {
  // Thiết bị thật: dùng IP LAN của máy chạy backend
  // Emulator: dùng '10.0.2.2'
  static const String serverHost = '192.168.x.x'; // ← Đổi thành IP máy bạn
  static const int serverPort = 3000;
}
```

**Cách tìm IP LAN:**
- Windows: chạy `ipconfig` → lấy IPv4 Address (thường là 192.168.x.x)
- Mac: chạy `ifconfig | grep inet`

### Bước 7: Chạy Flutter

```bash
flutter pub get
flutter run
```

### Ghi chú quan trọng

- **Backend phải chạy trước Flutter** — app cần API server để hoạt động.
- Nếu dùng **emulator**, đổi `serverHost` thành `'10.0.2.2'`.
- Nếu dùng **thiết bị thật**, điện thoại và máy tính phải **cùng mạng WiFi**.
- Khi đổi mạng WiFi, cần cập nhật lại IP trong `app_config.dart`.

---

## Cấu trúc dự án

```
mobile_flutter_chat/
├── backend/                    # Backend Node.js
│   ├── config/
│   │   └── database.js         # Kết nối MySQL pool
│   ├── database/
│   │   ├── schema.sql          # Schema tạo bảng ban đầu
│   │   └── migration_v2.sql    # Migration thêm tính năng mới
│   ├── models/
│   │   ├── User.js             # Model user (CRUD, online status)
│   │   ├── Chat.js             # Model chat (tạo, tìm, participants)
│   │   └── Message.js          # Model message (gửi, sửa, xóa)
│   ├── routes/
│   │   ├── auth.js             # API đăng ký, đăng nhập, logout
│   │   ├── chat.js             # API chat, tin nhắn, reactions, pin
│   │   └── user.js             # API user, block, online status
│   ├── server.js               # Entry point + Socket.IO setup
│   ├── template.env            # Mẫu file .env
│   └── package.json            # Dependencies
│
├── lib/                        # Frontend Flutter
│   ├── main.dart               # Entry point app
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_config.dart # ⚠️ CẤU HÌNH IP SERVER TẠI ĐÂY
│   │   │   ├── app_colors.dart # Bảng màu ứng dụng
│   │   │   └── app_routes.dart # Định nghĩa route names
│   │   ├── services/
│   │   │   ├── api_service.dart    # Tất cả HTTP calls đến backend
│   │   │   └── socket_service.dart # WebSocket client
│   │   └── themes/             # Light/Dark theme
│   ├── features/
│   │   ├── auth/
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart  # State quản lý auth
│   │   │   └── screens/
│   │   │       ├── splash_screen.dart  # Màn hình chờ + check auth
│   │   │       ├── login_screen.dart   # Đăng nhập
│   │   │       └── register_screen.dart # Đăng ký
│   │   ├── chat/
│   │   │   ├── screens/
│   │   │   │   ├── chat_list_screen.dart    # DS chat + tab People
│   │   │   │   ├── chat_detail_screen.dart  # Màn hình chat chính
│   │   │   │   ├── create_chat_screen.dart  # Tạo chat/nhóm mới
│   │   │   │   └── group_settings_screen.dart # Cài đặt nhóm
│   │   │   └── widgets/
│   │   │       └── message_bubble.dart # Widget hiển thị tin nhắn
│   │   └── profile/
│   │       └── screens/
│   │           └── profile_screen.dart # Trang cá nhân
│   └── widgets/                # Widgets dùng chung
│
├── android/                    # Android config
└── ios/                        # iOS config
```

---

## Giải thích file quan trọng

### Backend

| File | Chức năng |
|------|-----------|
| `server.js` | Khởi tạo Express server, middleware, Socket.IO event handlers (typing, online status, message delivery) |
| `config/database.js` | Tạo MySQL connection pool, đọc .env |
| `routes/auth.js` | `POST /register` (tạo user + hash password + trả JWT), `POST /login`, `POST /logout` |
| `routes/chat.js` | CRUD chat, gửi/sửa/xóa tin nhắn, reactions, pin, search, mute, read receipts |
| `routes/user.js` | Lấy danh sách user, cập nhật profile, online status, block/unblock |
| `models/User.js` | Query MySQL cho bảng `users` |
| `models/Chat.js` | Query cho bảng `chats` + `chat_participants` |
| `models/Message.js` | Query cho bảng `messages` |
| `database/schema.sql` | Tạo 4 bảng: `users`, `chats`, `chat_participants`, `messages` |
| `database/migration_v2.sql` | Thêm: `message_reactions`, `message_read_status`, `blocked_users`, `muted_chats`, `deleted_messages` + các cột mới |

### Flutter

| File | Chức năng |
|------|-----------|
| `app_config.dart` | **⚠️ Quan trọng nhất** — cấu hình IP + port server. Mỗi người phải đổi IP theo máy mình |
| `api_service.dart` | Tất cả HTTP calls (register, login, getChats, sendMessage, reactions, pin, v.v.). Có timeout 10s |
| `socket_service.dart` | WebSocket client — nhận tin nhắn real-time, typing indicator, online status |
| `auth_provider.dart` | State management cho auth (login/register/logout), lưu token vào SharedPreferences |
| `chat_list_screen.dart` | Màn hình chính: Tab Chats (danh sách cuộc trò chuyện) + Tab People (danh sách user online) |
| `chat_detail_screen.dart` | Màn hình chat: gửi/nhận tin nhắn, reply, emoji, pin, search, mute, xóa |
| `message_bubble.dart` | Widget tin nhắn: hiển thị text/ảnh, reactions, reply preview, delivery status, pin indicator |
| `create_chat_screen.dart` | Tạo chat mới: chọn user chat 1-1 hoặc tạo nhóm |
| `group_settings_screen.dart` | Quản lý nhóm: đổi tên, avatar, thêm/xóa thành viên |

---

## API Endpoints chính

### Auth
- `POST /api/auth/register` — Đăng ký (email, password, displayName)
- `POST /api/auth/login` — Đăng nhập
- `POST /api/auth/logout` — Đăng xuất

### Chat
- `GET /api/chat?uid=` — Lấy danh sách chat
- `POST /api/chat` — Tạo chat mới
- `GET /api/chat/:id/messages` — Lấy tin nhắn (kèm reactions)
- `POST /api/chat/:id/messages` — Gửi tin nhắn
- `POST /api/chat/:id/messages/reply` — Gửi tin trả lời

### Message Actions
- `PUT /api/chat/messages/:id/pin` — Ghim/bỏ ghim
- `POST /api/chat/messages/:id/reactions` — Thêm reaction
- `POST /api/chat/messages/:id/delete-for-me` — Xóa cho mình
- `POST /api/chat/messages/:id/delete-for-everyone` — Xóa cho tất cả

### User
- `GET /api/user?uid=` — Danh sách users
- `POST /api/user/:uid/block` — Block user

---

## Troubleshooting

| Vấn đề | Giải pháp |
|--------|-----------|
| `Connection refused` / Timeout | Kiểm tra backend đang chạy, IP trong `app_config.dart` đúng, cùng WiFi |
| `Access denied` MySQL | Kiểm tra `DB_PASSWORD` trong `.env` khớp với mật khẩu MySQL |
| App kẹt ở đăng ký/đăng nhập | Backend không phản hồi — kiểm tra terminal backend có lỗi không |
| Tin nhắn không hiện | Restart backend (`rs` + Enter trong terminal), restart Flutter app |
| `CLEARTEXT communication not permitted` | Đã fix trong AndroidManifest.xml — nếu lỗi, kiểm tra `usesCleartextTraffic="true"` |
