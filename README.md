# Mobile Flutter Chat

Ứng dụng chat realtime xây dựng bằng Flutter (Clean Architecture) + Python FastAPI + MySQL.

## ✨ Tính năng

- 🔐 Đăng nhập / Đăng ký với JWT
- 💬 Chat 1-1 và nhóm (text, ảnh)
- ⚡ WebSocket real-time messaging
- ✓✓ Delivery & read receipts
- 💭 Reply / Quote messages
- 😊 Emoji reactions
- 🔍 Tìm kiếm tin nhắn
- 📌 Pin / Delete for me / Delete for everyone
- 🔕 Mute / Archive chats
- 🚫 Block / Unblock users
- 🔗 Link preview
- 🌙 Dark mode / Light mode

## 🛠️ Công nghệ sử dụng

| Thành phần | Công nghệ |
|-----------|-----------|
| **Frontend** | Flutter 3.12+, Dart |
| **Architecture** | Clean Architecture (Domain/Data/Presentation) |
| **State Management** | Provider + ChangeNotifier |
| **Dependency Injection** | GetIt |
| **Backend** | Python 3.10, FastAPI, Socket.IO |
| **Database** | MySQL 8.0 với SQLAlchemy (async) |
| **Auth** | JWT (JSON Web Token) |
| **Realtime** | WebSocket (python-socketio) |

## 📋 Yêu cầu hệ thống

- **Flutter SDK** >= 3.12.0 (đã cài tại `C:\ThanhTung\flutter\bin`)
- **Anaconda/Miniconda** (để quản lý môi trường Python)
- **Python** >= 3.10 (cài tự động qua Conda)
- **MySQL** >= 8.0
- **Chrome** (để chạy Flutter web)

---

## 🚀 Hướng dẫn cài đặt và chạy

### ⚡ Cách nhanh nhất (Quick Start)

**Lần đầu tiên:**
```bash
# 1. Chạy setup tự động
AppChat_QuickStart.bat

# 2. Mở file backend_python\.env và cập nhật:
#    - DB_PASSWORD=your_mysql_password
#    - JWT_SECRET_KEY=random_secret_key

# 3. Chạy dự án
AppChat_RunProject.bat
```

### 📝 Cách chi tiết từng bước

#### Lần đầu tiên:

**Bước 1: Cài đặt Flutter dependencies**
```bash
flutter pub get
```

**Bước 2: Cài đặt Python Backend**
```bash
AppChat_SetupPython.bat
```

**Bước 3: Cấu hình file `.env`**

Mở `backend_python\.env` và cập nhật:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password    # ← Đổi thành mật khẩu MySQL của bạn
DB_NAME=mobile_chat

JWT_SECRET_KEY=your-super-secret-key-change-in-production  # ← Đặt chuỗi bất kỳ
SERVER_HOST=0.0.0.0
SERVER_PORT=3000
```

**Bước 4: Chạy dự án**
```bash
AppChat_RunProject.bat
```

File này sẽ tự động:
- ✅ Kích hoạt conda environment "AppChat"
- ✅ Cài đặt/cập nhật thư viện Python
- ✅ Khởi động Backend tại http://localhost:3000
- ✅ Tạo database MySQL (nếu chưa có)
- ✅ Khởi động Flutter App trên Chrome

#### Chạy hàng ngày:

```bash
# Chỉ cần chạy 1 file duy nhất
AppChat_RunProject.bat
```

---

## 📁 Cấu trúc dự án

### Flutter (Clean Architecture)

```
lib/
├── core/                        # Core utilities
│   ├── error/                   # Failures & Exceptions
│   │   ├── failures.dart        # ServerFailure, NetworkFailure, etc.
│   │   └── exceptions.dart      # ServerException, CacheException, etc.
│   ├── network/
│   │   └── network_info.dart    # Kiểm tra kết nối mạng
│   ├── usecases/
│   │   └── usecase.dart         # Abstract UseCase class
│   ├── constants/
│   │   ├── app_config.dart      # ⚠️ CẤU HÌNH SERVER TẠI ĐÂY
│   │   ├── app_colors.dart      # Bảng màu ứng dụng
│   │   └── app_routes.dart      # Định nghĩa routes
│   ├── services/
│   │   ├── api_service.dart     # HTTP client
│   │   └── socket_service.dart  # WebSocket client
│   └── themes/                  # Light/Dark theme
│
├── features/
│   ├── auth/
│   │   ├── domain/              # Business Logic Layer
│   │   │   ├── entities/        # UserEntity
│   │   │   ├── repositories/    # AuthRepository interface
│   │   │   └── usecases/        # LoginUseCase, RegisterUseCase, etc.
│   │   ├── data/                # Data Layer
│   │   │   ├── models/          # UserModel (JSON serialization)
│   │   │   ├── datasources/     # Remote & Local data sources
│   │   │   └── repositories/    # AuthRepositoryImpl
│   │   ├── presentation/        # Presentation Layer
│   │   │   ├── providers/       # AuthNotifier (ChangeNotifier)
│   │   │   ├── screens/         # Login, Register, Splash
│   │   │   └── widgets/         # Auth-specific widgets
│   │
│   ├── chat/
│   │   ├── domain/
│   │   │   ├── entities/        # ChatEntity, MessageEntity
│   │   │   ├── repositories/    # ChatRepository, MessageRepository
│   │   │   └── usecases/        # GetChatsUseCase, SendMessageUseCase
│   │   ├── data/
│   │   │   ├── models/          # ChatModel, MessageModel
│   │   │   ├── datasources/     # Chat remote data source
│   │   │   └── repositories/    # Repository implementations
│   │   └── presentation/
│   │       ├── providers/       # ChatNotifier, MessageNotifier
│   │       ├── screens/         # ChatList, ChatDetail, CreateChat
│   │       └── widgets/         # MessageBubble, ChatTile, etc.
│   │
│   └── profile/
│       └── screens/             # ProfileScreen
│
├── widgets/                     # Shared widgets
│   └── loading_overlay.dart
│
├── injection_container.dart     # Dependency Injection (GetIt)
└── main.dart                    # Entry point
```

### Python Backend (FastAPI)

```
backend_python/
├── app/
│   ├── __init__.py
│   ├── config.py                # Configuration (database, JWT, server)
│   ├── database.py              # SQLAlchemy async setup
│   ├── dependencies.py          # FastAPI dependencies (get_current_user)
│   ├── main.py                  # FastAPI app + Socket.IO
│   │
│   ├── models/                  # SQLAlchemy ORM Models
│   │   ├── __init__.py
│   │   ├── user.py              # User model
│   │   ├── chat.py              # Chat, ChatParticipant models
│   │   └── message.py           # Message, Reaction, ReadStatus models
│   │
│   ├── schemas/                 # Pydantic Schemas (Request/Response)
│   │   ├── __init__.py
│   │   ├── auth.py              # LoginRequest, RegisterRequest, AuthResponse
│   │   ├── user.py              # UserResponse, UpdateProfileRequest
│   │   ├── chat.py              # CreateChatRequest, ChatResponse
│   │   └── message.py           # SendMessageRequest, MessageResponse
│   │
│   ├── services/                # Business Logic
│   │   ├── __init__.py
│   │   ├── auth_service.py      # Register, login, JWT
│   │   ├── chat_service.py      # CRUD chats, participants
│   │   └── message_service.py   # CRUD messages, reactions
│   │
│   └── routes/                  # API Endpoints
│       ├── __init__.py
│       ├── auth.py              # /api/auth/* endpoints
│       ├── user.py              # /api/user/* endpoints
│       └── chat.py              # /api/chat/* endpoints
│
├── requirements.txt             # Python dependencies
├── run.py                       # Server entry point
├── .env.example                 # Environment template
└── README.md
```

### Database

```
database/
├── TaoCoSoDuLieu.sql           # Schema đầy đủ (users, chats, messages, etc.)
└── ThemDuLieuMau.sql           # Dữ liệu mẫu
```

---

## 🔌 API Endpoints

### Authentication
- `POST /api/auth/register` — Đăng ký tài khoản mới
- `POST /api/auth/login` — Đăng nhập và nhận JWT token
- `POST /api/auth/logout` — Đăng xuất
- `GET /api/auth/me` — Lấy thông tin user hiện tại

### User
- `GET /api/user/me` — Thông tin profile
- `PUT /api/user/me` — Cập nhật profile
- `GET /api/user/search?q=keyword` — Tìm kiếm users
- `GET /api/user/{user_id}` — Lấy thông tin một user

### Chat
- `GET /api/chat` — Danh sách chats (phân trang)
- `GET /api/chat/{chat_id}` — Chi tiết một chat
- `POST /api/chat/direct` — Tạo chat 1-1
- `POST /api/chat/group` — Tạo nhóm chat
- `POST /api/chat/{chat_id}/participants` — Thêm thành viên
- `DELETE /api/chat/{chat_id}/participants/{user_id}` — Xóa thành viên
- `POST /api/chat/{chat_id}/leave` — Rời khỏi nhóm
- `POST /api/chat/{chat_id}/pin` — Ghim/bỏ ghim chat
- `POST /api/chat/{chat_id}/mute` — Tắt/bật thông báo

### Messages
- `GET /api/chat/{chat_id}/messages` — Danh sách tin nhắn (phân trang)
- `POST /api/chat/{chat_id}/messages` — Gửi tin nhắn
- `PUT /api/chat/messages/{message_id}` — Sửa tin nhắn
- `DELETE /api/chat/messages/{message_id}` — Xóa tin nhắn
- `POST /api/chat/messages/{message_id}/reactions` — Thêm reaction
- `DELETE /api/chat/messages/reactions/{reaction_id}` — Xóa reaction
- `POST /api/chat/{chat_id}/read` — Đánh dấu đã đọc

---

## 🔄 WebSocket Events

### Client → Server
- `connect` — Kết nối với token
- `join_chat` — Tham gia phòng chat
- `leave_chat` — Rời phòng chat
- `new_message` — Gửi tin nhắn mới
- `typing` — Trạng thái đang nhập
- `message_read` — Đánh dấu đã đọc

### Server → Client
- `new_message` — Tin nhắn mới
- `typing` — Ai đó đang nhập
- `message_read` — Ai đó đã đọc
- `user_online` — User online
- `user_offline` — User offline

---

## 📚 Tài liệu liên quan

- [HUONG_DAN_CHAY_DU_AN.md](HUONG_DAN_CHAY_DU_AN.md) — Hướng dẫn chi tiết
- [docs/ChucNang.md](docs/ChucNang.md) — Danh sách chức năng
- [docs/CheckList.md](docs/CheckList.md) — Checklist phát triển
- [docs/ChiTietManHinh.md](docs/ChiTietManHinh.md) — Chi tiết các màn hình

---

## 🧪 Kiểm tra Backend

Sau khi chạy backend, mở trình duyệt:

- **API Root**: http://localhost:3000
- **Health Check**: http://localhost:3000/health
- **Swagger UI**: http://localhost:3000/docs (Test API trực tiếp)
- **ReDoc**: http://localhost:3000/redoc (Documentation)

---

## 🛠️ Các lệnh hữu ích

### Flutter
```bash
# Cài đặt dependencies
flutter pub get

# Chạy app
flutter run -d chrome

# Build APK
flutter build apk

# Clean project
flutter clean
```

### Python Backend
```bash
# Kích hoạt conda environment
conda activate AppChat

# Chạy server
cd backend_python
python run.py

# Cài đặt dependencies mới
pip install package_name
pip freeze > requirements.txt
```

### Database
```bash
# Kết nối MySQL
mysql -u root -p

# Import database
mysql -u root -p < database\TaoCoSoDuLieu.sql
mysql -u root -p < database\ThemDuLieuMau.sql

# Backup database
mysqldump -u root -p mobile_chat > backup.sql
```

---

## 🎯 Clean Architecture Benefits

**Separation of Concerns**: Mỗi layer có trách nhiệm riêng
- **Domain**: Business logic thuần túy, không phụ thuộc framework
- **Data**: Xử lý dữ liệu từ API, database, cache
- **Presentation**: UI và state management

**Testability**: Dễ dàng unit test từng layer độc lập

**Maintainability**: Dễ bảo trì, mở rộng, thay đổi implementation

**Dependency Rule**: Dependencies chỉ đi từ ngoài vào trong (Presentation → Data → Domain)

---

## ⚠️ Troubleshooting

### Lỗi Conda
```bash
# Nếu conda không được nhận diện
# Sử dụng Anaconda Prompt thay vì CMD thông thường
```

### Lỗi kết nối Backend
1. Kiểm tra Backend đang chạy tại http://localhost:3000
2. Kiểm tra file `backend_python\.env` đã cấu hình đúng
3. Kiểm tra MySQL đang chạy
4. Xem logs trong terminal Backend để biết lỗi cụ thể

### Lỗi Flutter không kết nối được API
1. Kiểm tra `lib/core/constants/app_config.dart`
2. Nếu chạy trên Chrome: dùng `localhost` hoặc `127.0.0.1`
3. Nếu chạy trên thiết bị: dùng IP LAN của máy tính (xem bằng `ipconfig`)
4. Nếu chạy trên emulator: dùng `10.0.2.2`

### Database errors
```bash
# Tạo lại database từ đầu
mysql -u root -p
DROP DATABASE IF EXISTS mobile_chat;
exit

# Chạy lại scripts
mysql -u root -p < database\TaoCoSoDuLieu.sql
mysql -u root -p < database\ThemDuLieuMau.sql
```

### Port 3000 đã được sử dụng
```bash
# Tìm process đang dùng port 3000
netstat -ano | findstr :3000

# Kill process (thay PID bằng số từ lệnh trên)
taskkill /PID <PID> /F

# Hoặc thay đổi SERVER_PORT trong .env
```

---

## 📝 Ghi chú quan trọng

- **Backend phải chạy trước Flutter** — app cần API server để hoạt động
- **MySQL phải đang chạy** — Backend không thể khởi động nếu không kết nối được database
- **Conda environment "AppChat"** — Luôn kích hoạt trước khi chạy Python code
- **File .bat tự động hóa** — Sử dụng `AppChat_RunProject.bat` để khởi động tất cả

---

## 👥 Tác giả

- **Lưu Thanh Tùng**
- **Lớp**: KHMT 1701  
- **MSSV**: 1771040029
- **Email**: dnu.khmt.1701.1771040029@gmail.com

---

## 📄 License

Dự án này được phát triển cho mục đích học tập.

---

## 🙏 Acknowledgments

- Flutter Team - Framework tuyệt vời
- FastAPI Team - Python web framework hiện đại
- Clean Architecture - Robert C. Martin
- Anaconda - Python environment management
