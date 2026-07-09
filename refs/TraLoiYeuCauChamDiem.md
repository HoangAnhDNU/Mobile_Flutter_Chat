# Trả lời Yêu cầu Chấm Điểm — AppChat Mobile

## 1. UI/UX của ứng dụng

### Màn hình chính
- **Splash Screen** (`lib/features/auth/screens/splash_screen.dart`): Kiểm tra phiên đăng nhập, tự điều hướng về Login hoặc Chat List.
- **Chat List** (`lib/features/chat/screens/chat_list_screen.dart`): Danh sách cuộc trò chuyện, hiển thị avatar, tên, tin nhắn cuối, thời gian, số tin chưa đọc. Hỗ trợ swipe-to-delete, ghim chat, tìm kiếm.
- **Chat Detail** (`lib/features/chat/screens/chat_detail_screen.dart`): Màn hình chat chính — hiển thị tin nhắn (text, ảnh, voice, file), thanh nhập tin nhắn với nút "+" (chọn ảnh/thư viện/ghi âm), AppBar có nút gọi thoại/video, menu 3 chấm (tìm kiếm, mute, ghim, xóa, tự xóa, chặn).
- **Profile** (`lib/features/profile/screens/profile_screen.dart`): Thông tin cá nhân, đổi tên/avatar, cài đặt (dark mode, ngôn ngữ, cỡ chữ, thông báo).
- **Admin Dashboard** (`lib/features/admin/screens/admin_dashboard_screen.dart`): Thống kê, quản lý người dùng/nhóm.
- **Friends** (`lib/features/friends/screens/friends_screen.dart`): Danh sách bạn bè, tìm kiếm, chặn/bỏ chặn.
- **Group Settings** (`lib/features/chat/screens/group_settings_screen.dart`): Quản lý nhóm — đổi tên, avatar, thêm/xóa thành viên, chuyển admin, giải tán.
- **Call Screen** (`lib/features/chat/screens/call_screen.dart`): Giao diện gọi thoại/video WebRTC.

### Luồng người dùng
```
Splash → (có token) → Chat List → Chat Detail
                    → Profile → Settings
                    → Friends
                    → Admin Dashboard (nếu admin)
       → (không token) → Login → Register → Forgot Password
```

### Cách bố trí chức năng
- **Thanh nhập tin nhắn**: Nút "+" bên trái hiển thị popup menu (thư viện, camera, ghi âm). Nút gửi bên phải. Nút ghi âm giữ để ghi âm, thả để gửi.
- **AppBar chat**: Nút gọi thoại, gọi video (chat 1-1), menu 3 chấm chứa tất cả tùy chọn (tìm kiếm, mute, ghim, xóa, tự xóa, chặn/bỏ chặn).
- **Message bubble**: Swipe để reply, long-press để hiển thị menu (reply, edit, delete, pin, copy, forward, reaction). Hiển thị nhãn phân loại ảnh và fake news bên dưới ảnh.

### Trải nghiệm sử dụng
- Hỗ trợ dark mode/light mode, điều chỉnh cỡ chữ.
- Đa ngôn ngữ (Vietnamese/English) qua `AppLocalizations`.
- Thông báo in-app (overlay banner) khi nhận tin nhắn nhưng không đang ở trong chat.
- Local notifications qua `flutter_local_notifications`.
- Realtime: typing indicator, online/offline, trạng thái gửi/nhận/đọc.
- Foreground service (`KeepAliveService`) để giữ socket khi app background.

---

## 2. API / Model AI được áp dụng ở đâu

### App gọi API nào
Tất cả API calls đi qua `ApiService` (`lib/core/services/api_service.dart`), backend FastAPI tại `http://<host>:3000/api`:

| API Endpoint | Chức năng |
|---|---|
| `POST /auth/login` | Đăng nhập, trả JWT token |
| `POST /auth/register` | Đăng ký tài khoản |
| `GET /chat?page=&limit=` | Danh sách chat |
| `GET /chat/{id}/messages?page=&limit=` | Lấy tin nhắn phân trang |
| `POST /chat/{id}/messages` | Gửi tin nhắn (text/image/voice/file) |
| `PUT /chat/messages/{id}` | Sửa tin nhắn |
| `DELETE /chat/messages/{id}` | Xóa tin nhắn |
| `DELETE /chat/{id}` | Xóa cuộc trò chuyện (ẩn + clear tin nhắn phía mình) |
| `GET /chat/{id}/search?q=` | Tìm kiếm tin nhắn |
| `POST /chat/{id}/read` | Đánh dấu đã đọc |
| `POST /chat/messages/{id}/reactions` | Thêm reaction |
| `POST /chat/{id}/messages/{id}/pin` | Ghim tin nhắn |
| `GET /chat/{id}/pinned` | Lấy tin nhắn ghim |
| `POST /chat/direct` | Tạo chat 1-1 |
| `POST /chat/group` | Tạo chat nhóm |
| `GET /user/{uid}` | Lấy thông tin user |
| `PUT /user/me` | Cập nhật profile |
| `POST /user/change-password` | Đổi mật khẩu |
| `GET /user/search?q=` | Tìm kiếm user |
| `POST /block/{uid}` | Chặn user |
| `DELETE /block/{uid}` | Bỏ chặn |
| `GET /block/status/{uid}` | Kiểm tra trạng thái chặn |
| `POST /image/classify` | Phân loại ảnh (ONNX MobileNet) |
| `GET /chat/{id}/auto-delete` | Lấy cài đặt tự xóa |
| `PUT /chat/{id}/auto-delete` | Cập nhật tự xóa |
| Socket.IO events | Realtime: `new_message`, `user_typing`, `presence_update`, `delivery_update`, `reaction_update`, `message_deleted`, `message_edited`, `pin_update`, `call_offer/answer/ice/end/reject`, `mention_notification` |

### Dữ liệu lấy từ đâu
- **Backend**: FastAPI + SQLAlchemy async + MySQL (`mobile_flutter_chat` database).
- **Realtime**: Socket.IO qua `SocketService` (`lib/core/services/socket_service.dart`), kết nối WebSocket tới `ws://<host>:3000`.
- **Local storage**: `SharedPreferences` lưu token, uid, email, displayName, avatarUrl, role, cài đặt (thông báo, theme, ngôn ngữ).

### Model AI dùng cho chức năng nào

#### Model 1: Image Classification (ONNX MobileNet)
- **File model**: `ref/student_mobilenet_kd_A50_T20_E50.onnx`
- **Backend**: `app/services/image_classifier.py` — dùng ONNX Runtime
- **Chức năng**: Phân loại ảnh chat thành 5 nhãn: `classroom`, `computerroom`, `library`, `corridor`, `office`
- **Cách hoạt động**: Khi user gửi ảnh, backend tự động classify và lưu `image_label` vào database. Kết quả hiển thị dưới ảnh trong message bubble.
- **API riêng**: `POST /image/classify` (upload ảnh, trả về nhãn + xác suất)

#### Model 2: Fake News Detection (MobileNetV2 PyTorch)
- **File model**: `ref/best_mobilenetv2_student.pt`
- **Backend**: `app/services/fake_news_classifier.py` — dùng PyTorch + MobileNetV2
- **Chức năng**: Phân loại ảnh tin tức thành 3 nhãn (3-way classification theo Fakeddit dataset):
  - `True` (index 0): Tin thật
  - `Satire/Clickbait` (index 1): Tin châm biếm/giật tít
  - `Fake` (index 2): Tin giả
- **Cách hoạt động**: Khi user gửi ảnh, backend tự động chạy cả 2 model. Kết quả `fake_news_label` lưu vào database và hiển thị dưới ảnh.

### Kết quả AI hiển thị/xử lý trong app
- **`image_label`**: Hiển thị text nghiêng dưới ảnh trong `MessageBubble` (`lib/features/chat/widgets/message_bubble.dart:255-267`).
- **`fake_news_label`**: Hiển thị với icon và màu sắc (`message_bubble.dart:268-298`):
  - `True`: Icon ✓ xanh lá, text xanh — tin thật
  - `Satire/Clickbait` / `Fake`: Icon ⚠️ cam, text cam — cảnh báo tin giả
- Dữ liệu truyền từ backend qua `ApiService._adaptMessage()` → `msg['image_label']` và `msg['fake_news_label']` → `MessageBubble` widget.

---

## 3. CRUD và lưu trữ dữ liệu

### Thêm, sửa, xóa, hiển thị dữ liệu ở đâu

| Thao tác | Vị trí | Chi tiết |
|---|---|---|
| **Create** tin nhắn | `ChatDetailScreen._sendMessage()` | Gọi `ApiService.sendMessage()`, backend lưu vào MySQL, emit socket `new_message` |
| **Read** tin nhắn | `ChatDetailScreen._loadMessages()` | Gọi `ApiService.getMessages()`, phân trang 30 tin/trang |
| **Update** tin nhắn | `ChatDetailScreen._editMessage()` | Gọi `ApiService.updateMessage()`, socket emit `message_edited` |
| **Delete** tin nhắn | `ChatDetailScreen._deleteMessage()` | Gọi `ApiService.deleteMessage()`, socket emit `message_deleted` |
| **Delete** chat | `ChatDetailScreen._showClearChatConfirm()` | Gọi `ApiService.deleteChat()` — ẩn chat + set `messages_cleared_at` |
| **Create** chat | `CreateChatScreen` | Gọi `ApiService.createChat()` (direct hoặc group) |
| **Create** user | `RegisterScreen` | Gọi `ApiService.register()` |
| **Update** profile | `ProfileScreen._updateDisplayName()` | Gọi `ApiService.updateUser()` |
| **Block/Unblock** | `FriendsScreen` | Gọi `ApiService.blockUser()` / `unblockUser()` |
| **Pin message** | `ChatDetailScreen._showMessageOptions()` | Gọi `ApiService.pinMessage()` |
| **Reaction** | `ChatDetailScreen._addReaction()` | Gọi `ApiService.addReaction()` |

### Dữ liệu lưu ở đâu
- **Database (MySQL)**: Tin nhắn, chat, user, chat_participants, reactions, blocks, friendships, group_invites, notification_settings, privacy, activity_logs, deleted_messages.
- **Local (SharedPreferences)**: Token JWT, uid, email, displayName, avatarUrl, role, cài đặt người dùng (thông báo, theme, ngôn ngữ, cỡ chữ).
- **Không dùng Firebase** — toàn bộ dữ liệu qua API/database riêng.

### Cách tổ chức dữ liệu trong app
- Dữ liệu từ backend trả về dạng JSON, `ApiService` adapt (chuyển đổi) từ snake_case (backend) sang format mà UI đọc được (camelCase + snake_case).
- Tin nhắn lưu trong list `_messages` (in-memory) của `ChatDetailScreen`, cập nhật realtime qua Socket.IO streams.
- Token lưu trong `SharedPreferences` + biến static `_token` trong `ApiService`.

---

## 4. Quản lý trạng thái

### Nhóm dùng công cụ gì
- **Provider** (`ChangeNotifierProvider`): Quản lý trạng thái toàn cục — `AuthProvider` (đăng nhập/đăng xuất/user data) và `ThemeProvider` (dark mode/ngôn ngữ/cỡ chữ).
- **setState**: Quản lý trạng thái cục bộ trong từng màn hình (vd: `ChatDetailScreen` quản lý `_messages`, `_isSearching`, `_isGroup`, `_peerOnline`, `_isRecording`, v.v.).
- **StreamController + StreamSubscription**: `SocketService` dùng broadcast streams cho realtime events (`onMessage`, `onTyping`, `onPresence`, v.v.), các màn hình subscribe để cập nhật UI.

### Trạng thái được quản lý ở màn hình nào
- **`AuthProvider`** (`lib/features/auth/providers/auth_provider.dart`): Trạng thái đăng nhập (`isLoggedIn`), thông tin user (`uid`, `email`, `displayName`, `avatarUrl`, `role`), loading state, error message. Gọi `notifyListeners()` khi thay đổi.
- **`ThemeProvider`** (`lib/core/themes/theme_provider.dart`): Dark mode, locale (vi/en), font size.
- **`ChatDetailScreen`**: Quản lý `_messages`, `_isSearching`, `_isGroup`, `_peerUid`, `_peerOnline`, `_peerBlocked`, `_isRecording`, `_isEditing`, `_autoDeleteDays`, `_searchController`, v.v. qua `setState`.
- **`ChatListScreen`**: Quản lý `_chats`, `_isLoading`, `_searchQuery` qua `setState`.
- **`CallHandler`** (`lib/core/widgets/call_handler.dart`): Lắng nghe socket events toàn cục, hiển thị incoming call dialog và in-app notification overlay.

### Cách cập nhật giao diện khi dữ liệu thay đổi
- **Provider + Consumer**: `MyApp` dùng `Consumer<ThemeProvider>` để rebuild toàn bộ app khi theme/locale đổi.
- **setState**: Gọi `setState()` trong màn hình khi dữ liệu cục bộ thay đổi (vd: nhận tin nhắn mới → thêm vào `_messages` → `setState()`).
- **Stream listener**: `ChatDetailScreen` subscribe `SocketService.instance.onMessage` → khi có tin nhắn mới, thêm vào `_messages` và gọi `setState()`.
- **notifyListeners()**: `AuthProvider` gọi khi login/logout/updateUserData, các widget dùng `context.read<AuthProvider>()` hoặc `Consumer<AuthProvider>` sẽ rebuild.

---

## 5. Cấu trúc Clean Architecture

### Cách chia thư mục

```
lib/
├── main.dart                    # Entry point, khởi tạo services, định nghĩa routes
├── core/                        # Lớp infrastructure (dùng chung)
│   ├── constants/               # AppConfig (env), AppRoutes, AppColors
│   ├── services/                # ApiService, SocketService, NotificationService,
│   │                            # WebRTCCallService, KeepAliveService
│   ├── themes/                  # AppTheme, ThemeProvider
│   ├── utils/                   # AppLocalizations (i18n), helpers
│   ├── widgets/                 # CallHandler (widget wrapper toàn cục)
│   ├── error/                   # Exceptions, Failure
│   ├── network/                 # Network info
│   └── usecases/                # Base usecase
├── features/                    # Feature-first modules
│   ├── auth/
│   │   ├── data/                # datasource, models, repository impl
│   │   ├── domain/              # entities, repositories (abstract), usecases
│   │   ├── presentation/        # widgets
│   │   ├── providers/           # AuthProvider (ChangeNotifier)
│   │   └── screens/             # SplashScreen, LoginScreen, RegisterScreen, ForgotPasswordScreen
│   ├── chat/
│   │   ├── data/                # datasource, models, repository impl
│   │   ├── domain/              # entities, repositories (abstract), usecases
│   │   ├── screens/             # ChatListScreen, ChatDetailScreen, CreateChatScreen,
│   │   │                        # GroupSettingsScreen, CallScreen, JoinGroupScreen, v.v.
│   │   └── widgets/             # MessageBubble, VoiceMessagePlayer, v.v.
│   ├── profile/
│   │   └── screens/             # ProfileScreen, NotificationSettingsScreen, PrivacySettingsScreen
│   ├── friends/
│   │   └── screens/             # FriendsScreen
│   └── admin/
│       └── screens/             # AdminDashboard, UserManagement, GroupManagement
└── injection_container.dart     # Dependency injection setup
```

**Backend Python:**
```
backend_python/
├── app/
│   ├── config.py                # Pydantic Settings (đọc .env)
│   ├── database.py              # SQLAlchemy async engine, migrations
│   ├── dependencies.py          # DI: get_db, get_current_user
│   ├── main.py                  # FastAPI app + Socket.IO app
│   ├── models/                  # SQLAlchemy ORM models (User, Chat, Message, v.v.)
│   ├── routes/                  # API routers (auth, chat, admin, block, friend, image, v.v.)
│   ├── schemas/                 # Pydantic request/response schemas
│   ├── services/                # Business logic (AuthService, ChatService, MessageService,
│   │                            # ImageClassifier, FakeNewsClassifier)
│   └── socket_instance.py       # Socket.IO server instance
├── ref/                         # AI model files (.pt, .onnx)
└── run.py                       # Entry point (uvicorn)
```

### Tách UI, logic xử lý, model, service/repository

| Lớp | Vị trí | Trách nhiệm |
|---|---|---|
| **UI (Presentation)** | `features/*/screens/`, `features/*/widgets/` | Hiển thị giao diện, nhận tương tác user, gọi ApiService/SocketService |
| **State Management** | `features/*/providers/`, `core/themes/theme_provider.dart` | Quản lý trạng thái (Provider + ChangeNotifier) |
| **Service/Adapter** | `core/services/api_service.dart`, `socket_service.dart` | Giao tiếp với backend (HTTP + Socket.IO), adapt dữ liệu |
| **Domain** | `features/*/domain/entities/`, `features/*/domain/repositories/`, `features/*/domain/usecases/` | Định nghĩa entity, repository abstract, usecase |
| **Data** | `features/*/data/datasources/`, `features/*/data/models/`, `features/*/data/repositories/` | Implement repository, model mapping |
| **Config** | `core/constants/app_config.dart` | Đọc .env, cung cấp baseUrl/wsUrl |
| **Backend Services** | `backend_python/app/services/` | Business logic server-side |
| **Backend Models** | `backend_python/app/models/` | ORM models (SQLAlchemy) |
| **Backend Routes** | `backend_python/app/routes/` | API endpoints (FastAPI routers) |

### Luồng xử lý từ UI → xử lý logic → dữ liệu

**Ví dụ: Gửi tin nhắn text**

```
1. UI: ChatDetailScreen → user bấm nút gửi
2. UI gọi: _sendMessage(content, type='text')
3. Service: ApiService.sendMessage(chatId, content, type) 
   → HTTP POST /api/chat/{chatId}/messages (with JWT header)
4. Backend Route: chat.py → receive request
5. Backend Service: MessageService.send_message()
   → Lưu vào MySQL (Message table)
   → Socket.IO emit "new_message" đến tất cả participant trong room "chat_{id}"
6. Backend trả response: {message: {...}}
7. Flutter: ApiService adapt response → thêm vào _messages list
8. UI: setState() → MessageBubble render tin nhắn mới
9. Đồng thời: SocketService.onMessage stream phát event
   → Các thiết bị khác nhận → cập nhật UI realtime
```

**Ví dụ: Gửi ảnh (có AI classification)**

```
1. UI: User chọn ảnh → _sendImage(ImageSource.gallery)
2. UI: Đọc file → base64 encode
3. Service: ApiService.sendMessage(chatId, content, type='image', mediaBase64=...)
4. Backend: MessageService.send_message()
   → Lưu ảnh vào uploads/
   → Chạy ImageClassifier (ONNX) → image_label (classroom/library/...)
   → Chạy FakeNewsClassifier (MobileNetV2 PyTorch) → fake_news_label (True/Fake/...)
   → Lưu message với image_label + fake_news_label vào MySQL
   → Socket.IO emit "new_message"
5. Flutter: Nhận response → adapt → MessageBubble hiển thị ảnh + nhãn
```
