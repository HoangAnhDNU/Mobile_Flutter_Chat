# Checklist Dự Án App Chat Flutter

> Đánh dấu `[x]` khi hoàn thành. Ưu tiên làm theo thứ tự giai đoạn.

---

## Giai đoạn 1 – Thiết lập & Xác thực

### Thiết lập dự án
- [x] Tạo Node.js backend project với Express + MySQL
- [x] Thiết lập MySQL database schema (users, chats, messages)
- [x] Thêm dependencies vào `pubspec.yaml`: `http`, `provider`, `web_socket_channel`, `shared_preferences`
- [x] Tạo `ApiService` trong Flutter để gọi REST API
- [x] Tạo `SocketService` trong Flutter để kết nối WebSocket
- [x] Thiết lập cấu trúc thư mục: `core/`, `features/`, `services/`, `widgets/`
- [x] Định nghĩa named routes trong `main.dart`
- [x] Cấu hình backend `.env` (DB_HOST, DB_USER, DB_PASSWORD, JWT_SECRET)
- [x] Set `minSdk = 23` cho Android

### Màn hình Splash Screen
- [x] Giao diện: logo, tên app, loading indicator
- [x] Logic: kiểm tra `ApiService.isLoggedIn` (token trong SharedPreferences)
- [x] Điều hướng: đã đăng nhập → Chat List, chưa → Login

### Màn hình Login
- [x] Giao diện: TextField email, TextField mật khẩu (hiện/ẩn), nút đăng nhập
- [x] Validate: email đúng định dạng, mật khẩu không trống
- [x] Gọi `ApiService.login()` → nhận JWT token
- [x] Xử lý lỗi: hiển thị SnackBar (sai email/mật khẩu, lỗi mạng)
- [x] Link chuyển sang Register
- [x] Link chuyển sang Forgot Password
- [x] **Quick Account Switch**: Lưu tài khoản đã đăng nhập, hiển thị danh sách chuyển nhanh
- [x] Hỗ trợ dark mode (sử dụng theme color thay vì hardcoded)

### Màn hình Register
- [x] Giao diện: TextField email, mật khẩu, xác nhận mật khẩu, tên hiển thị
- [x] Validate: email, mật khẩu ≥ 8 ký tự, mật khẩu khớp
- [x] Gọi `ApiService.register()` → tạo user trong MySQL
- [x] Lưu thông tin người dùng vào MySQL table `users` (uid, email, displayName, avatarUrl)
- [x] Xử lý lỗi: email đã tồn tại, v.v.
- [x] Link quay lại Login

### Màn hình Forgot Password
- [x] Giao diện: TextField email, nút gửi, text hướng dẫn
- [x] Validate email
- [x] Gọi API reset password (cần email service)
- [x] Hiển thị thông báo thành công / lỗi
- [x] Vô hiệu hóa nút gửi sau khi gửi thành công (chống spam)

---

## Giai đoạn 2 – Chat cơ bản (CRUD)

### Màn hình Chat List
- [x] Giao diện: AppBar, ListView danh sách chat, FAB tạo chat mới
- [x] Mỗi item: avatar, tên, tin nhắn cuối, thời gian, badge chưa đọc
- [x] **BottomNavigationBar**: 3 tab – Chats | Calls (tùy chọn) | **People** (danh sách người dùng, trạng thái online, tap để chat)
- [x] Gọi `ApiService.getChats()` để lấy danh sách chat từ MySQL
- [x] Xử lý lỗi API (hiển thị thông báo lỗi khi request thất bại)
- [x] Bấm item → Navigator.push sang Chat Detail
- [x] Bấm FAB → Navigator.push sang Create Chat
- [x] Menu icon → Navigator.push sang Profile/Settings

### Màn hình Chat Detail – Gửi tin nhắn (Create)
- [x] Giao diện: AppBar (avatar, tên, trạng thái, **icon gọi điện** (tùy chọn), **PopupMenu 3 chấm** (Cài đặt nhóm, Xóa lịch sử chat)), ListView tin nhắn, bottom bar (TextField, nút gửi)
- [x] Message bubble: phải (mình gửi), trái (người khác)
- [x] Hiển thị: nội dung, thời gian, trạng thái gửi
- [x] Validate tin nhắn không trống
- [x] Gọi `ApiService.sendMessage()` → lưu vào MySQL `messages` table
- [x] Backend tự cập nhật `lastMessage`, `lastMessageTime` trong `chats` table
- [x] Nhận tin nhắn real-time qua WebSocket

### Màn hình Chat Detail – Xóa tin nhắn (Delete)
- [x] Long-press tin nhắn → hiện bottom sheet/menu
- [x] Kiểm tra `senderId == currentUserId`
- [x] Gọi `ApiService.deleteMessage(messageId)` → xóa từ MySQL
- [x] Cập nhật lại `lastMessage` nếu xóa tin cuối

### Màn hình Chat Detail – Sửa tin nhắn (Update)
- [x] Long-press → chọn "Chỉnh sửa"
- [x] Điền nội dung cũ vào TextField, đổi nút gửi → nút "Lưu"
- [x] Gọi `ApiService.updateMessage()` → cập nhật `text`, `is_edited`, `edited_at` trong MySQL
- [x] Hiển thị nhãn `(đã chỉnh sửa)` bên cạnh thời gian

### Màn hình Chat Detail – Sao chép tin nhắn
- [x] Long-press → chọn "Sao chép"
- [x] Copy nội dung vào clipboard

### Màn hình Chọn Người Dùng (Create Chat)
- [x] Giao diện: AppBar, TextField tìm kiếm, ListView người dùng, nút tạo chat
- [x] Gọi `ApiService.getUsers()` → lấy danh sách users từ MySQL (lọc bỏ chính mình)
- [x] Tìm kiếm theo tên/email
- [x] Gọi `ApiService.createChat()` → tạo record mới trong `chats` + `chat_participants`
- [x] Navigator.push sang Chat Detail với `chatId` mới

---

## Giai đoạn 3 – Tính năng nâng cao

### Gửi ảnh trong Chat Detail
- [x] Icon đính kèm → chọn ảnh từ thư viện / chụp ảnh
- [x] Encode ảnh thành Base64, gửi qua API lưu vào MySQL
- [x] Ghi tin nhắn với `type: 'image'`, `imageBase64`
- [x] Hiển thị ảnh trong bubble (hỗ trợ cả base64 và URL)

### Xóa/ẩn cuộc trò chuyện
- [x] Swipe hoặc long-press trên Chat List → xóa cục bộ

### Profile / Cài đặt
- [x] Giao diện: avatar lớn (icon camera để đổi), TextField tên, text email (chỉ đọc)
- [x] Đọc thông tin từ `AuthProvider` (lấy từ API khi login)
- [x] Đổi tên hiển thị → gọi `ApiService.updateUser()`
- [x] Đổi avatar → encode Base64 → gọi `ApiService.updateUser()`
- [x] Switch bật/tắt thông báo → lưu `shared_preferences`
- [x] Chế độ tối/sáng → lưu `shared_preferences`
- [x] Nút đăng xuất → `AuthProvider.signOut()` → xóa token → quay về Login
- [x] Nút xóa tài khoản → dialog xác nhận → xóa user

### Typing Indicator
- [x] Khi gõ → gửi typing event qua WebSocket / API
- [x] Hiển thị "đang nhập..." ở Chat Detail

### Push Notification (tùy chọn)
- [ ] Thêm `flutter_local_notifications` vào dependencies
- [ ] Hiển thị local notification khi nhận tin nhắn qua WebSocket
- [ ] Nhận notification khi app ở nền
- [ ] Hiển thị thông báo trên màn hình khóa

---

## Giai đoạn 4 – Nhóm & Quản lý nâng cao (tùy chọn)

### Tạo nhóm chat
- [x] Multi-select người dùng ở màn hình Create Chat
- [x] Dialog nhập tên nhóm
- [x] Gọi `ApiService.createChat()` với nhiều participants + chatName

### Màn hình Group Settings (CRUD Conversation)
- [x] Giao diện: ảnh nhóm, TextField tên nhóm, danh sách thành viên
- [x] **Read**: Hiển thị thông tin nhóm + danh sách thành viên (avatar, tên, badge Admin)
- [x] **Update**: Đổi tên nhóm → gọi API update (chỉ admin)
- [x] **Update**: Đổi ảnh nhóm → encode Base64 → gọi API update (chỉ admin)
- [x] **Thêm thành viên** → gọi API add participant (chỉ admin)
- [x] **Xóa thành viên** → dialog xác nhận → gọi API remove participant (chỉ admin)
- [x] **Rời nhóm** → dialog xác nhận → gọi API leave group, chuyển quyền admin nếu cần

### Màn hình Chi tiết Người dùng
- [ ] Giao diện: avatar lớn, tên, email, trạng thái online/offline (bỏ qua – không cần thiết cho BTL)

---

## Giai đoạn 5 – Tính năng nâng cao v2

### WebSocket Real-time
- [x] Thiết lập Socket.IO trên backend server
- [x] Tạo SocketService trong Flutter (connect, disconnect, reconnect)
- [x] Real-time messaging: nhận tin nhắn mới qua WebSocket
- [x] Real-time typing indicator qua WebSocket
- [x] Real-time online presence qua WebSocket

### Message Delivery & Read Receipts
- [x] Backend: delivery_status column (sent/delivered/read)
- [x] Backend: message_read_status table
- [x] API: POST /:chatId/read (mark messages as read)
- [x] Flutter UI: Hiển thị ✓ / ✓✓ / ✓✓ xanh trong bubble

### Reply/Quote Messages
- [x] Backend: reply_to_id, reply_to_text, reply_to_sender columns
- [x] API: POST /:chatId/messages/reply
- [x] Flutter UI: Swipe để reply, hiển thị quoted message trong bubble

### Message Reactions (Emoji)
- [x] Backend: message_reactions table
- [x] API: POST/DELETE/GET reactions
- [x] Flutter UI: Long-press → emoji picker, hiển thị reactions dưới bubble

### Search Messages
- [x] Backend: GET /:chatId/search?query=
- [x] Flutter UI: Search bar trong chat detail

### Block/Mute Users
- [x] Backend: blocked_users table
- [x] API: POST/DELETE /:uid/block, GET /:uid/blocked
- [x] Backend: muted_chats (is_muted in chat_participants)
- [x] API: PUT /:chatId/mute
- [ ] Flutter UI: Block/Unblock trong profile người dùng
- [x] Flutter UI: Mute/Unmute trong chat options

### Delete for Me / Delete for Everyone
- [x] Backend: deleted_messages table + is_deleted_for_everyone column
- [x] API: POST /messages/:id/delete-for-me, POST /messages/:id/delete-for-everyone
- [x] Flutter UI: Long-press → chọn kiểu xóa

### Pin Messages
- [x] Backend: is_pinned column
- [x] API: PUT /messages/:id/pin, GET /:chatId/pinned
- [x] Flutter UI: Long-press → Pin, hiển thị pinned messages banner

### Archive Chats
- [x] Backend: is_archived in chat_participants
- [x] API: PUT /:chatId/archive
- [ ] Flutter UI: Swipe để archive, tab archived chats

### Voice Messages
- [x] Backend: voice_base64, voice_duration columns
- [x] Flutter UI: Voice bubble UI (player placeholder)

### Link Preview
- [x] Flutter UI: Detect URLs, hiển thị preview card

### AI Speech-to-Text (Chuyển giọng nói → văn bản)
- [x] Chọn model AI: OpenAI Whisper (faster-whisper, `small`, miễn phí)
- [x] Tạo Python Flask service (`speech_to_text/app.py`)
- [x] API `GET /health` — kiểm tra trạng thái service
- [x] API `POST /transcribe` — chuyển audio tiếng Việt → JSON text
- [x] API `POST /transcribe-to-file` — chuyển audio → file .txt tải về
- [x] Viết `requirements.txt` cho Python dependencies
- [x] Viết tài liệu API (`speech_to_text/README.md`)
- [ ] Tích hợp gọi API từ Flutter (ghi âm → gửi audio → hiển thị text)

---

## Giai đoạn 6 – Hoàn thiện & Báo cáo

### Tối ưu & Xử lý lỗi
- [x] Xử lý lỗi mạng (hiển thị thông báo, retry) – `NetworkUtils` + try-catch
- [x] Loading overlay khi đăng nhập, đăng ký, gửi ảnh – `LoadingOverlay` widget
- [ ] Kiểm tra app chạy mượt trên emulator / thiết bị thật

### Giao diện
- [x] Thống nhất theme (màu sắc, font, spacing) – `AppTheme` light + dark
- [x] Responsive trên nhiều kích thước màn hình – `MediaQuery`, `Expanded`, `SingleChildScrollView`
- [x] Dùng `cached_network_image` cho avatar

### Báo cáo BTL
- [ ] Vẽ sơ đồ Widget tree
- [ ] Mô tả Navigator flow (sơ đồ LIFO giữa các màn hình)
- [ ] Giải thích State management (setState vs Provider)
- [ ] Mô tả cấu trúc MySQL (tables, relationships)
- [ ] Screenshots các màn hình chính
- [ ] Viết hướng dẫn cài đặt & chạy project
