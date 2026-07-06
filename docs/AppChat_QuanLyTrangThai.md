# AppChat — Quản lý trạng thái

Tài liệu trả lời ba câu hỏi: dùng công cụ nào để quản lý trạng thái, trạng thái được quản lý ở màn hình nào, và cách giao diện cập nhật khi dữ liệu thay đổi.

---

## 1. Công cụ quản lý trạng thái

Dự án dùng ba công cụ quản lý trạng thái, phân theo hai nhóm:

### 1.1. Provider (`ChangeNotifier`)

Dự án dùng gói `provider` với `ChangeNotifier` làm nền tảng chính. Không có BLoC, Riverpod, hay GetX.

| Công cụ | Package | Số lượng | Trạng thái |
|---------|---------|----------|-------------|
| `ChangeNotifier` | `provider` | 4 class | Đang dùng |

**Các class ChangeNotifier trong dự án:**

| Class | File | Vai trò |
|-------|------|---------|
| `ThemeProvider` | `core/themes/theme_provider.dart` | Chế độ sáng/tối, ngôn ngữ (vi/en), cỡ chữ |
| `AuthProvider` | `features/auth/providers/auth_provider.dart` | Thông tin user hiện tại (uid, email, displayName, avatar, role), đăng nhập/đăng xuất |
| `ChatNotifier` | `features/chat/presentation/providers/chat_provider.dart` | Danh sách chat, phân trang, ghim/lưu trữ |
| `MessageNotifier` | `features/chat/presentation/providers/message_provider.dart` | Tin nhắn trong một chat, gửi/nhận tin nhắn |

`ChatNotifier` và `MessageNotifier` có cấu trúc theo Clean Architecture (gọi UseCase → Repository → DataSource), nhưng **hiện chưa được đăng ký vào widget tree** trong `main.dart`. Chúng tồn tại như code mẫu tham khảo.

### 1.2. `setState` trong `StatefulWidget`

Phần lớn màn hình dùng `StatefulWidget` với `setState` để quản lý trạng thái cục bộ. Các biến `_messages`, `_chats`, `_users`, `_friends`, `_isLoading` được khai báo trực tiếp trong `State` class và cập nhật qua `setState`.

### 1.3. Socket.IO Stream (realtime)

Dữ liệu realtime được quản lý qua `SocketService` — một singleton dùng `StreamController.broadcast` để phát các stream như `onMessage`, `onTyping`, `onReaction`, `onDelete`, `onPin`, `onPresence`, `onMention`, `onEdit`, và các sự kiện WebRTC. Các màn hình đăng ký listener và gọi `setState` khi nhận sự kiện.

---

## 2. Trạng thái được quản lý ở màn hình nào

### 2.1. Màn hình dùng `ChangeNotifier` (Provider)

| Màn hình | Provider | Công cụ phụ |
|----------|----------|-------------|
| Toàn bộ app | `ThemeProvider` | `Consumer<ThemeProvider>` trong `MaterialApp` |
| `LoginScreen` | `AuthProvider` | `context.read<AuthProvider>()` |
| `RegisterScreen` | `AuthProvider` | `context.read<AuthProvider>()` |
| `ProfileScreen` | `AuthProvider` | `context.read<AuthProvider>()` |
| `AdminDashboardScreen` | `AuthProvider` | `context.read<AuthProvider>().signOut()` |

### 2.2. Màn hình dùng `setState` cục bộ

| Màn hình | Biến state chính |
|----------|-----------------|
| `ChatListScreen` | `_chats`, `_isLoading`, `_isSearching`, `_pendingMessages` |
| `ChatDetailScreen` | `_messages`, `_pinnedMessages`, `_isLoading`, `_isEditing`, `_replyingTo`, `_groupParticipants`, `_isMuted`, `_isPeerTyping`, `_isRecording` |
| `AdminUsersTab` | `_users`, `_isLoading` |
| `AdminGroupsTab` | Danh sách nhóm, trạng thái loading |
| `AdminStatsTab` | Dữ liệu thống kê |
| `AdminActivityLogTab` | Nhật ký hoạt động |
| `FriendsScreen` | `_friends`, `_requests`, `_blockedIds`, `_isLoading` |
| `CallScreen` | `_callState`, `_duration`, `_muted`, `_cameraOff`, `_speakerOn` |

### 2.3. Tóm tắt phân bố

| Mô hình | Số màn hình | Tỷ lệ |
|---------|-------------|--------|
| `setState` cục bộ trong `StatefulWidget` | ~10 màn hình | ~70% |
| `ChangeNotifier` (`AuthProvider`) | 3 màn hình | ~20% |
| `ChangeNotifier` (`ThemeProvider`) | Toàn app | 100% |

Phần lớn màn hình (chat, admin, friends, call) dùng `setState` cục bộ. Chỉ có màn hình liên quan đến xác thực và theme mới dùng Provider. `ChatNotifier` và `MessageNotifier` tuy đã xây đầy đủ nhưng chưa được kích hoạt.

---

## 3. Cách cập nhật giao diện khi dữ liệu thay đổi

Dự án có ba cơ chế cập nhật giao diện, tùy loại dữ liệu.

### 3.1. Cập nhật khi gọi API (HTTP)

Khi màn hình cần dữ liệu từ server, một hàm bất đồng bộ được gọi. Sau khi nhận kết quả, `setState` được gọi để rebuild widget:

- **`AuthProvider.login()`** → gọi `ApiService.login()` → nhận kết quả → gọi `notifyListeners()` → mọi `Consumer<AuthProvider>` trong widget tree tự động rebuild
- **`ChatListScreen.loadData()`** → gọi `ApiService.getChats()` → nhận kết quả → `setState(() { _chats = ... })` → widget rebuild
- **`AdminUsersTab.loadUsers()`** → gọi `ApiService.adminGetUsers()` → nhận kết quả → `setState(() { _users = ...; _isLoading = false; })`

### 3.2. Cập nhật realtime (Socket.IO)

Khi server phát sự kiện qua Socket.IO, `SocketService` đẩy dữ liệu vào `StreamController`. Màn hình đã đăng ký listener sẽ nhận được và gọi `setState` để cập nhật giao diện tức thì:

- **`ChatDetailScreen`** — lắng nghe 8 stream: `onMessage` (tin nhắn mới), `onTyping` (đang nhập), `onReaction` (reaction thay đổi), `onDelete` (tin nhắn bị xóa), `onPin` (ghim/bỏ ghim), `onPresence` (user online/offline), `onConnect` (kết nối khôi phục), `onMention` (được nhắc tên)
- **`ChatListScreen`** — lắng nghe 3 stream: `onMessage` (cập nhật preview tin nhắn cuối), `onDelete` (hiển thị "[Tin nhắn đã thu hồi]"), `onEdit` (cập nhật nội dung preview)
- **`AdminUsersTab`** — lắng nghe `onPresence` để reload danh sách khi user online/offline
- **`CallScreen`** — lắng nghe `onCallAnswer`, `onCallIceCandidate`, `onCallEnd`, `onCallReject` để cập nhật trạng thái cuộc gọi
- **`CallHandler`** (widget toàn cục trong `MaterialApp`) — lắng nghe `onCallOffer` (hiện dialog cuộc gọi đến), `onMessage` (hiện thông báo), `onCallEnd`/`onCallReject` (đóng dialog)

### 3.3. Cập nhật trạng thái cục bộ (UI)

Các tương tác không cần gọi server được cập nhật trực tiếp qua `setState`:

- Toggle dark/light mode → `ThemeProvider.toggleTheme()` → `notifyListeners()` → `MaterialApp` rebuild
- Thay đổi ngôn ngữ → `ThemeProvider.setLanguage()` → `notifyListeners()` → app rebuild với locale mới
- Bật/tắt camera, tắt tiếng trong cuộc gọi → `setState` trong `CallScreen`
- Mở/đóng bàn phím sửa tin nhắn → `setState` trong `ChatDetailScreen`
- Hiện/ẩn danh sách @mention → `setState` trong `ChatDetailScreen`

### 3.4. Tóm tắt luồng cập nhật

```
Dữ liệu thay đổi
├── Từ server (HTTP response)
│   ├── AuthProvider → notifyListeners() → Consumer rebuild
│   └── Screen.setState() → Widget rebuild
├── Từ server (Socket.IO event)
│   └── SocketService Stream → Screen setState() → Widget rebuild
└── Từ tương tác người dùng (cục bộ)
    ├── ThemeProvider → notifyListeners() → Consumer rebuild
    └── Screen.setState() → Widget rebuild
```

---

## 4. Sơ đồ tổng hợp

```
┌─────────────────────────────────────────────────────────┐
│                     MaterialApp                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │ MultiProvider                                       │    │
│  │                                                     │    │
│  │  ThemeProvider  ──► toàn app (Consumer trong       │    │
│  │  (ChangeNotifier)    MaterialApp builder)          │    │
│  │                                                     │    │
│  │  AuthProvider  ───► LoginScreen, RegisterScreen,   │    │
│  │  (ChangeNotifier)   ProfileScreen, AdminDashboard  │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │ CallHandler (widget toàn cục)                    │    │
│  │  └── SocketService.instance.onCallOffer.listen()  │    │
│  │      SocketService.instance.onMessage.listen()    │    │
│  │      SocketService.instance.onPresence.listen()   │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ChatDetailScreen (StatefulWidget)                       │
│                                                          │
│  State: _messages, _chats, _isLoading, _isEditing...    │
│                                                          │
│  HTTP:  ApiService.getMessages() → setState(() { ... }) │
│                                                          │
│  Socket:                                                 │
│  ├─ onMessage   → setState(() { _messages.insert(...) }) │
│  ├─ onTyping    → setState(() { _isPeerTyping = true }) │
│  ├─ onReaction  → setState(() { _messages.update(...) }) │
│  ├─ onDelete    → setState(() { _messages.remove(...) }) │
│  ├─ onPin       → setState(() { _pinnedMessages... })   │
│  ├─ onPresence  → setState(() { _peerOnline = ... })   │
│  ├─ onMention   → hiện notification overlay            │
│  └─ onConnect   → reload data                           │
└─────────────────────────────────────────────────────────┘
```
