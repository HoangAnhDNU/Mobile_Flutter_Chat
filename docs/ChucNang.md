# Ứng dụng Chat Đơn Giản bằng Flutter – Môn Lập Trình Mobile

## 1. Công cụ và công nghệ sử dụng

### Framework & Ngôn ngữ
- **Flutter**: Framework UI đa nền tảng của Google để xây dựng ứng dụng mobile [web:1]
- **Dart**: Ngôn ngữ lập trình chính dùng để viết code Flutter [web:1]

### Công cụ phát triển
- **Flutter SDK**: Bộ công cụ phát triển Flutter chính thức
- **Android Studio** hoặc **VS Code**: IDE để viết code, debug và chạy ứng dụng [web:1]
- **Flutter CLI**: Dòng lệnh để tạo project, chạy, build app (`flutter create`, `flutter run`, `flutter build`)
- **Emulator**: Android Emulator hoặc iOS Simulator để test ứng dụng
- **Git + GitHub/GitLab**: Quản lý phiên bản code

### Backend & Dịch vụ (cho tính năng chat thời gian thực)
- **Firebase Firestore** hoặc **Firebase Realtime Database**: Cơ sở dữ liệu thời gian thực, dễ tích hợp với Flutter [web:2]
- **Firebase Authentication**: Xác thực người dùng (email/password, Google, v.v.)
- **Firebase Cloud Messaging (FCM)**: Gửi thông báo đẩy (push notification) khi có tin nhắn mới
- **(Tùy chọn) Backend tự xây dựng**: Node.js + Socket.io + MongoDB nếu muốn tự làm server

### Package Flutter quan trọng
- `firebase_core`: Khởi tạo Firebase
- `cloud_firestore` hoặc `firebase_database`: Truy cập database thời gian thực
- `firebase_auth`: Xác thực người dùng
- `flutter_local_notifications` hoặc `firebase_messaging`: Xử lý push notification
- `provider` hoặc `riverpod`: Quản lý trạng thái (state management)
- `intl`: Định dạng ngày giờ, ngôn ngữ
- `cached_network_image`: Tăng tốc load ảnh avatar
- `shared_preferences`: Lưu cài đặt đơn giản (Local Storage) dạng key-value (token, chế độ tối/sáng, tài khoản đã lưu, v.v.)

## 2. Chức năng chính (Functional Requirements)

### 2.1. Quản lý người dùng
- Đăng ký tài khoản (email + mật khẩu, hoặc đăng nhập qua Google)
- Đăng nhập / Đăng xuất
- **Chuyển nhanh tài khoản** (Quick Account Switch): Lưu tài khoản đã đăng nhập vào SharedPreferences, cho phép chuyển tài khoản bằng một lần tap mà không cần nhập lại email/mật khẩu
- Hiển thị thông tin người dùng: tên, avatar, trạng thái (online/offline)

### 2.2. Chat thời gian thực
- Tạo và tham gia phòng chat (1–1:1 hoặc nhóm)
- Gửi và nhận tin nhắn ngay lập tức (real-time)
- Hiển thị danh sách tin nhắn theo thời gian:
  - Nội dung tin nhắn
  - Thời gian gửi
  - Người gửi
  - Trạng thái: đã gửi, đã gửi thành công, đã xem
- Hỗ trợ:
  - Tin nhắn văn bản
  - Gửi ảnh (từ thư viện hoặc chụp ảnh)
  - (Tùy chọn) Gửi emoji, sticker
- **Xóa tin nhắn đơn lẻ**: long-press → xóa tin nhắn của chính mình (CRUD Delete)
- **Chỉnh sửa tin nhắn**: long-press → sửa nội dung văn bản, hiển thị nhãn `(đã chỉnh sửa)` (CRUD Update)

### 2.3. Quản lý cuộc hội thoại
- Danh sách cuộc trò chuyện (chat list)
- Tìm kiếm tin nhắn hoặc người dùng
- Xóa/ẩn cuộc trò chuyện (cục bộ)
- Hiển thị người đang nhập (typing indicator) – tùy chọn

### 2.4. Quản lý nhóm (CRUD Conversation cho nhóm)
- **Update**: Chỉnh sửa tên nhóm và ảnh đại diện nhóm (chỉ admin)
- **Thêm thành viên**: Chọn người dùng từ danh sách để mời vào nhóm
- **Xóa thành viên**: Admin có thể loại thành viên khỏi nhóm
- **Rời nhóm**: Mọi thành viên có thể tự rời; admin tự động chuyển quyền nếu rời sau cùng
- Xem danh sách thành viên trong màn hình Group Settings

### 2.5. Xác thực nâng cao
- **Quên mật khẩu**: Gửi email đặt lại mật khẩu qua `FirebaseAuth.sendPasswordResetEmail()`

### 2.6. Giao diện điều hướng
- **BottomNavigationBar** với 3 tab: **Chats** (danh sách chat) | **Calls** (lịch sử cuộc gọi – tùy chọn) | **People** (danh sách người dùng)
- Icon gọi điện trong AppBar của màn hình Chat Detail (tùy chọn)

### 2.7. Thông báo
- Nhận push notification khi có tin nhắn mới khi ứng dụng ở nền hoặc đóng
- Hiển thị thông báo nhanh trên màn hình khóa

## 3. Chức năng phi chức năng (Non-Functional Requirements)

### 3.1. Hiệu năng
- Thời gian phản hồi tin nhắn dưới 1–2 giây (real-time)
- Ứng dụng chạy mượt trên thiết bị cấu hình trung bình
- Tiêu thụ tài nguyên (RAM, CPU) hợp lý, không gây lag

### 3.2. Khả năng mở rộng
- Có thể mở rộng từ chat 1–1 sang chat nhóm
- Có thể thêm nhiều tính năng: gọi thoại/hình ảnh, chia sẻ vị trí, file

### 3.3. Bảo mật
- Xác thực người dùng an toàn (Firebase Auth hoặc backend tự xây dựng)
- Dữ liệu tin nhắn được bảo vệ, chỉ người dùng trong phòng chat mới xem được
- Không lưu mật khẩu dưới dạng plain text

### 3.4. Khả năng sử dụng (Usability)
- Giao diện đơn giản, dễ hiểu, phù hợp với người dùng phổ thông
- Điều hướng dễ dàng giữa các màn hình qua BottomNavigationBar và Navigator
- Hỗ trợ tiếng Việt (hoặc đa ngôn ngữ nếu có thời gian)

### 3.5. Khả năng bảo trì
- Code được tổ chức rõ ràng, chia theo màn hình, service, widget
- Sử dụng state management (provider/riverpod) để dễ quản lý logic
- Có comment và tài liệu cơ bản trong code

### 3.6. Khả năng tương thích
- Chạy được trên Android (API level tối thiểu khoảng 21+)
- Nếu có thời gian: hỗ trợ cả iOS
- Tương thích với nhiều kích thước màn hình điện thoại

### 3.7. Độ tin cậy
- Ít crash, xử lý lỗi mạng (mất kết nối, tái kết nối tự động)
- Tin nhắn không bị mất khi mất mạng tạm thời:
  - Dùng **Firestore Offline Persistence** (`persistenceEnabled: true`) – tự động cache dữ liệu xuống thiết bị, đồng bộ lại khi có mạng; không cần SQLite riêng
  - Dùng **Local Storage** (`shared_preferences`) để lưu trạng thái đăng nhập, cài đặt người dùng (theme, ngôn ngữ)

## 4. Gợi ý cấu trúc dự án Flutter
lib/
├── main.dart
├── core/
│ ├── constants/
│ ├── themes/
│ └── utils/
├── features/
│ ├── auth/
│ │ ├── login_screen.dart
│ │ ├── register_screen.dart
│ │ └── auth_provider.dart
│ ├── chat/
│ │ ├── chat_list_screen.dart
│ │ ├── chat_detail_screen.dart
│ │ ├── message_model.dart
│ │ └── chat_provider.dart
│ └── profile/
│ └── profile_screen.dart
├── services/
│ ├── firebase_service.dart
│ └── notification_service.dart
└── widgets/
├── message_bubble.dart
└── chat_input.dart

### Ghi chú kiến trúc Flutter
- **Widget tree**: Toàn bộ giao diện được xây dựng theo cấu trúc cây widget lồng nhau; mỗi màn hình là một cây con. Cần đưa vào báo cáo BTL.
- **Navigator (LIFO)**: Flutter dùng stack LIFO để quản lý điều hướng giữa các màn hình. Mỗi nút chuyển tiếp dùng `Navigator.push()`, màn hình con luôn có nút quay lại (`Navigator.pop()`). Dự án nên định nghĩa tên route trong `main.dart` để dễ quản lý.
- **State vs Provider**: `setState()` dùng cho UI đơn giản trong 1 widget; `Provider` (hoặc `Riverpod`) được khuyến dùng khi cần chia sẻ state giữa nhiều màn hình (ví dụ: trạng thái đăng nhập, danh sách chat).


## 5. Lộ trình phát triển gợi ý

1. **Giai đoạn 1**: Thiết lập Flutter project, kết nối Firebase, làm màn hình đăng ký/đăng nhập
2. **Giai đoạn 2**: Tạo chat list và màn hình chat 1–1, gửi/nhận tin nhắn text
3. **Giai đoạn 3**: Thêm gửi ảnh, typing indicator, push notification
4. **Giai đoạn 4**: Tối ưu hiệu năng, giao diện, xử lý lỗi, menulis tài liệu demo
5. **Giai đoạn 5**: Viết báo cáo