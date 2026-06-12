# Mobile Flutter Chat

Ứng dụng chat realtime xây dựng bằng Flutter + Node.js + MySQL.

## Tính năng

- Đăng nhập / Đăng ký
- Chat 1-1 và nhóm (text, ảnh)
- **Real-time messaging** qua Socket.IO (tin nhắn hiện ngay, không cần reload)
- Delivery & read receipts (✓ / ✓✓ / ✓✓ xanh)
- Reply / Quote messages
- Emoji reactions
- Tìm kiếm tin nhắn
- Pin / Delete for me / Delete for everyone
- Mute / Archive chats
- **Block / Unblock users** (có màn hình chi tiết người dùng)
- Link preview
- Dark mode / Light mode
- **Pull-to-refresh** + **Unread badge** trên chat list
- **Xem ảnh full-screen** (pinch-to-zoom)
- **AI Speech-to-Text tiếng Việt** (nhấn mic → ghi âm → chuyển thành text)
- Banner **mất kết nối** + **tự reconnect**

## Công nghệ sử dụng

| Thành phần | Công nghệ |
|-----------|-----------|
| Frontend | Flutter 3.x, Dart, Provider (state management) |
| Backend | Node.js, Express.js, Socket.IO |
| Database | MySQL 8.0 |
| Auth | JWT (JSON Web Token) |
| Realtime | Socket.IO (`socket_io_client`) |
| AI Model | OpenAI Whisper (faster-whisper) — Speech-to-Text tiếng Việt |
| AI Service | Python 3.8+, Flask, CTranslate2 |

## Yêu cầu hệ thống

- **Flutter SDK** >= 3.0
- **Node.js** >= 18.x
- **MySQL** >= 8.0
- **Python** >= 3.8 (cho AI Speech-to-Text service)
- **Android Studio** hoặc VS Code với Flutter extension
- **Thiết bị Android** (thật hoặc emulator)

---

## Hướng dẫn cài đặt và chạy

### ⚡ Cách chạy nhanh (Windows)

Sau khi cấu hình xong `.env` và IP, **double-click file** `start_all.bat` ở thư mục gốc để tự động mở:
- Terminal Backend (port 3000)
- Terminal STT AI Service (port 5000)

Sau đó chạy Flutter riêng:
```bash
flutter run
```

---

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

### Bước 5.5: Cài đặt và chạy AI Speech-to-Text Service

```bash
pip install -r speech_to_text/requirements.txt
```

> Chỉ cần chạy lần đầu. Sau đó dùng `start_all.bat` hoặc:

```bash
cd speech_to_text
python app.py
```

Nếu thành công sẽ thấy:
```
[STT] Đang tải model 'small' (compute: float32)...
[STT] Model đã sẵn sàng!
[STT] Service chạy tại http://0.0.0.0:5000
```

> **Lưu ý**: Lần đầu chạy tự tải model ~461MB (cần internet). Sau đó chạy **offline hoàn toàn**.

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
├── speech_to_text/              # AI Speech-to-Text Service (Python)
│   ├── app.py                  # Flask server + Whisper model
│   ├── requirements.txt        # Python dependencies
│   ├── README.md               # API documentation
│   └── uploads/                # Thư mục tạm (tự tạo)
│
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
│   │   │   │   ├── group_settings_screen.dart # Cài đặt nhóm
│   │   │   │   └── user_detail_screen.dart  # Chi tiết user + Block
│   │   │   └── widgets/
│   │   │       └── message_bubble.dart # Widget hiển thị tin nhắn
│   │   └── profile/
│   │       └── screens/
│   │           └── profile_screen.dart # Trang cá nhân
│   └── widgets/                # Widgets dùng chung
│
├── start_all.bat               # ⚡ Chạy nhanh Backend + STT cùng lúc
├── android/                    # Android config
└── ios/                        # iOS config
```

---

## Giải thích file quan trọng

### AI Speech-to-Text (Python)

| File | Chức năng |
|------|-----------|
| `speech_to_text/app.py` | Flask server + Whisper model, 3 API endpoints: health, transcribe (→ JSON), transcribe-to-file (→ .txt) |
| `speech_to_text/requirements.txt` | Python dependencies: `faster-whisper`, `flask`, `flask-cors` |
| `speech_to_text/README.md` | Tài liệu API chi tiết, ví dụ curl/Python, hướng dẫn tích hợp Flutter |

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
| `socket_service.dart` | Socket.IO client — real-time messaging, typing, online status, auto-reconnect |
| `auth_provider.dart` | State management cho auth (login/register/logout), lưu token vào SharedPreferences |
| `chat_list_screen.dart` | Màn hình chính: Tab Chats + Tab People, pull-to-refresh, unread badge, connection banner |
| `chat_detail_screen.dart` | Màn hình chat: gửi/nhận real-time, reply, emoji, pin, search, mute, xóa, ghi âm STT |
| `message_bubble.dart` | Widget tin nhắn: text/ảnh (tap xem full-screen), reactions, reply, delivery status, pin |
| `create_chat_screen.dart` | Tạo chat mới: chọn user chat 1-1 hoặc tạo nhóm |
| `group_settings_screen.dart` | Quản lý nhóm: đổi tên, avatar, thêm/xóa thành viên |
| `user_detail_screen.dart` | Chi tiết người dùng: avatar, trạng thái, nút nhắn tin, nút chặn/bỏ chặn |

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

### AI Speech-to-Text (Port 5000)
- `GET /health` — Kiểm tra trạng thái AI service
- `POST /transcribe` — Chuyển file audio tiếng Việt → JSON text
- `POST /transcribe-to-file` — Chuyển file audio → file .txt tải về

---

## Troubleshooting

| Vấn đề | Giải pháp |
|--------|-----------|
| `Connection refused` / Timeout | Kiểm tra backend đang chạy, IP trong `app_config.dart` đúng, cùng WiFi |
| `Access denied` MySQL | Kiểm tra `DB_PASSWORD` trong `.env` khớp với mật khẩu MySQL |
| App kẹt ở đăng ký/đăng nhập | Backend không phản hồi — kiểm tra terminal backend có lỗi không |
| Tin nhắn không hiện real-time | Kiểm tra Socket.IO backend đang chạy, kiểm tra IP trong `app_config.dart` |
| Banner "Đang kết nối lại..." luôn hiện | IP sai hoặc backend chưa chạy |
| `CLEARTEXT communication not permitted` | Đã fix trong AndroidManifest.xml — nếu lỗi, kiểm tra `usesCleartextTraffic="true"` |
| STT model tải chậm lần đầu | Bình thường — model ~461MB tải 1 lần, sau đó cache local |
| STT kết quả không chính xác | Đảm bảo audio rõ tiếng, ít nhiễu. Thử model `medium` nếu cần chính xác hơn |
| Mic không hoạt động trên Android | Kiểm tra quyền `RECORD_AUDIO` đã được cấp trong cài đặt điện thoại |
