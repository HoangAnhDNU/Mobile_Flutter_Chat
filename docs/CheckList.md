# Checklist Dự Án App Chat Flutter

> Đánh dấu `[x]` khi hoàn thành. Ưu tiên làm theo thứ tự giai đoạn.

---

## Giai đoạn 1 – Thiết lập & Xác thực

### Thiết lập dự án
- [x] Cấu hình Firebase project trên Firebase Console
- [x] Thêm `google-services.json` vào `android/app/`
- [x] Thêm dependencies vào `pubspec.yaml`: `firebase_core`, `firebase_auth`, `cloud_firestore`, `provider`
- [x] Khởi tạo Firebase trong `main.dart` (`Firebase.initializeApp()`)
- [x] Bật Firestore Offline Persistence (`persistenceEnabled: true`)
- [x] Thiết lập cấu trúc thư mục: `core/`, `features/`, `services/`, `widgets/`
- [x] Định nghĩa named routes trong `main.dart`
- [x] Cấu hình Google Services plugin trong `android/settings.gradle.kts` và `android/app/build.gradle.kts`
- [x] Set `minSdk = 23` cho Android

### Màn hình Splash Screen
- [x] Giao diện: logo, tên app, loading indicator
- [x] Logic: kiểm tra `FirebaseAuth.currentUser`
- [x] Điều hướng: đã đăng nhập → Chat List, chưa → Login

### Màn hình Login
- [x] Giao diện: TextField email, TextField mật khẩu (hiện/ẩn), nút đăng nhập
- [x] Validate: email đúng định dạng, mật khẩu không trống
- [x] Gọi `FirebaseAuth.signInWithEmailAndPassword()`
- [x] Xử lý lỗi: hiển thị SnackBar (sai email/mật khẩu, lỗi mạng)
- [x] Link chuyển sang Register
- [x] Link chuyển sang Forgot Password
- [x] **Quick Account Switch**: Lưu tài khoản đã đăng nhập, hiển thị danh sách chuyển nhanh
- [x] Hỗ trợ dark mode (sử dụng theme color thay vì hardcoded)

### Màn hình Register
- [x] Giao diện: TextField email, mật khẩu, xác nhận mật khẩu, tên hiển thị
- [x] Validate: email, mật khẩu ≥ 8 ký tự, mật khẩu khớp
- [x] Gọi `FirebaseAuth.createUserWithEmailAndPassword()`
- [x] Lưu thông tin người dùng vào Firestore collection `users` (userId, email, displayName, avatarUrl)
- [x] Xử lý lỗi: email đã tồn tại, v.v.
- [x] Link quay lại Login

### Màn hình Forgot Password
- [x] Giao diện: TextField email, nút gửi, text hướng dẫn
- [x] Validate email
- [x] Gọi `FirebaseAuth.sendPasswordResetEmail()`
- [x] Hiển thị thông báo thành công / lỗi
- [x] Vô hiệu hóa nút gửi sau khi gửi thành công (chống spam)

---

## Giai đoạn 2 – Chat cơ bản (CRUD)

### Màn hình Chat List
- [x] Giao diện: AppBar, ListView danh sách chat, FAB tạo chat mới
- [x] Mỗi item: avatar, tên, tin nhắn cuối, thời gian, badge chưa đọc
- [x] **BottomNavigationBar**: 3 tab – Chats | Calls (tùy chọn) | **People** (danh sách người dùng, trạng thái online, tap để chat)
- [x] Lắng nghe real-time từ Firestore collection `chats` (onSnapshot) – sort local để tránh composite index
- [x] Xử lý lỗi Firestore (hiển thị thông báo lỗi khi query thất bại)
- [x] Bấm item → Navigator.push sang Chat Detail
- [x] Bấm FAB → Navigator.push sang Create Chat
- [x] Menu icon → Navigator.push sang Profile/Settings

### Màn hình Chat Detail – Gửi tin nhắn (Create)
- [x] Giao diện: AppBar (avatar, tên, trạng thái, **icon gọi điện** (tùy chọn), **PopupMenu 3 chấm** (Cài đặt nhóm, Xóa lịch sử chat)), ListView tin nhắn, bottom bar (TextField, nút gửi)
- [x] Message bubble: phải (mình gửi), trái (người khác)
- [x] Hiển thị: nội dung, thời gian, trạng thái gửi
- [x] Validate tin nhắn không trống
- [x] Ghi tin nhắn vào Firestore `chats/{chatId}/messages`
- [x] Cập nhật `lastMessage`, `lastMessageTime` trong `chats/{chatId}`
- [x] Lắng nghe tin nhắn real-time

### Màn hình Chat Detail – Xóa tin nhắn (Delete)
- [x] Long-press tin nhắn → hiện bottom sheet/menu
- [x] Kiểm tra `senderId == currentUserId`
- [x] Xóa document `chats/{chatId}/messages/{messageId}`
- [x] Cập nhật lại `lastMessage` nếu xóa tin cuối

### Màn hình Chat Detail – Sửa tin nhắn (Update)
- [x] Long-press → chọn "Chỉnh sửa"
- [x] Điền nội dung cũ vào TextField, đổi nút gửi → nút "Lưu"
- [x] Cập nhật `text`, `isEdited: true`, `editedAt` trong Firestore
- [x] Hiển thị nhãn `(đã chỉnh sửa)` bên cạnh thời gian

### Màn hình Chat Detail – Sao chép tin nhắn
- [x] Long-press → chọn "Sao chép"
- [x] Copy nội dung vào clipboard

### Màn hình Chọn Người Dùng (Create Chat)
- [x] Giao diện: AppBar, TextField tìm kiếm, ListView người dùng, nút tạo chat
- [x] Lấy danh sách từ Firestore `users` (lọc bỏ chính mình)
- [x] Tìm kiếm theo tên/email
- [x] Tạo document mới trong `chats` với `participants`, `createdAt`, `createdBy`
- [x] Navigator.push sang Chat Detail với `chatId` mới

---

## Giai đoạn 3 – Tính năng nâng cao

### Gửi ảnh trong Chat Detail
- [x] Icon đính kèm → chọn ảnh từ thư viện / chụp ảnh
- [x] Encode ảnh thành Base64, lưu trực tiếp trong Firestore (không cần Firebase Storage plan Blaze)
- [x] Ghi tin nhắn với `type: 'image'`, `imageBase64`
- [x] Hiển thị ảnh trong bubble (hỗ trợ cả base64 và URL)

### Xóa/ẩn cuộc trò chuyện
- [x] Swipe hoặc long-press trên Chat List → xóa cục bộ

### Profile / Cài đặt
- [x] Giao diện: avatar lớn (icon camera để đổi), TextField tên, text email (chỉ đọc)
- [x] Đọc thông tin từ `FirebaseAuth.currentUser` + Firestore `users/{userId}`
- [x] Đổi tên hiển thị → cập nhật Firestore
- [x] Đổi avatar → encode Base64 → lưu vào Firestore
- [x] Switch bật/tắt thông báo → lưu `shared_preferences`
- [x] Chế độ tối/sáng → lưu `shared_preferences`
- [x] Nút đăng xuất → `FirebaseAuth.signOut()` → quay về Login
- [x] Nút xóa tài khoản → dialog xác nhận → xóa user

### Typing Indicator
- [x] Khi gõ → cập nhật `typingUser` trong Firestore
- [x] Hiển thị "đang nhập..." ở Chat Detail

### Push Notification (tùy chọn)
- [ ] Thêm `firebase_messaging` vào dependencies
- [ ] Cấu hình FCM trên Firebase Console
- [ ] Nhận notification khi app ở nền / đóng
- [ ] Hiển thị thông báo trên màn hình khóa

---

## Giai đoạn 4 – Nhóm & Quản lý nâng cao (tùy chọn)

### Tạo nhóm chat
- [x] Multi-select người dùng ở màn hình Create Chat
- [x] Dialog nhập tên nhóm
- [x] Tạo document `chats` với `participants` (nhiều userId), `groupName`, `groupAvatar`

### Màn hình Group Settings (CRUD Conversation)
- [x] Giao diện: ảnh nhóm, TextField tên nhóm, danh sách thành viên
- [x] **Read**: Hiển thị thông tin nhóm + danh sách thành viên (avatar, tên, badge Admin)
- [x] **Update**: Đổi tên nhóm → cập nhật `groupName` (chỉ admin)
- [x] **Update**: Đổi ảnh nhóm → upload Storage → cập nhật `groupAvatar` (chỉ admin)
- [x] **Thêm thành viên** → `FieldValue.arrayUnion()` (chỉ admin)
- [x] **Xóa thành viên** → dialog xác nhận → `FieldValue.arrayRemove()` (chỉ admin)
- [x] **Rời nhóm** → dialog xác nhận → xóa userId khỏi `participants`, chuyển quyền admin nếu cần

### Màn hình Chi tiết Người dùng
- [ ] Giao diện: avatar lớn, tên, email, trạng thái online/offline (bỏ qua – không cần thiết cho BTL)

---

## Giai đoạn 5 – Hoàn thiện & Báo cáo

### Tối ưu & Xử lý lỗi
- [x] Xử lý lỗi mạng (hiển thị thông báo, retry) – `NetworkUtils` + try-catch
- [x] Loading overlay khi đăng nhập, đăng ký, gửi ảnh – `LoadingOverlay` widget
- [ ] Kiểm tra app chạy mượt trên emulator / thiết bị thật
- [x] Firestore Offline Persistence đã bật (`persistenceEnabled: true`)

### Giao diện
- [x] Thống nhất theme (màu sắc, font, spacing) – `AppTheme` light + dark
- [x] Responsive trên nhiều kích thước màn hình – `MediaQuery`, `Expanded`, `SingleChildScrollView`
- [x] Dùng `cached_network_image` cho avatar

### Báo cáo BTL
- [ ] Vẽ sơ đồ Widget tree
- [ ] Mô tả Navigator flow (sơ đồ LIFO giữa các màn hình)
- [ ] Giải thích State management (setState vs Provider)
- [ ] Mô tả cấu trúc Firestore (collections, documents, fields)
- [ ] Screenshots các màn hình chính
- [ ] Viết hướng dẫn cài đặt & chạy project
