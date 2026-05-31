# Mô Tả Chi Tiết Từng Màn Hình Ứng Dụng Chat Flutter

## 1. Màn hình Splash Screen (Màn hình khởi động)

### Mục đích
- Hiển thị khi ứng dụng mới mở, trong khi đang kiểm tra trạng thái đăng nhập và khởi tạo Firebase.

### Chức năng
- Hiển thị logo/app name, có thể có animation nhẹ.
- Kiểm tra token đăng nhập (nếu đã đăng nhập trước đó).
- Tự động chuyển hướng:
  - Nếu đã đăng nhập → màn hình Chat List.
  - Nếu chưa đăng nhập → màn hình Login.

### Thành phần giao diện
- Logo/ảnh app icon ở giữa.
- Tên ứng dụng bên dưới logo.
- Loading indicator (vòng tròn xoay) ở phía dưới.

### Logic chính
- Khi bắt đầu: khởi tạo Firebase (`Firebase.initializeApp()`).
- Kiểm tra trạng thái xác thực từ `FirebaseAuth`.
- Sử dụng `Future.delayed` để tạo độ trễ 1–2 giây (tạo cảm giác chuyên nghiệp).

---

## 2. Màn hình Login (Đăng nhập)

### Mục đích
- Cho phép người dùng đăng nhập vào ứng dụng bằng email và mật khẩu.

### Chức năng
- Nhập email và mật khẩu.
- Nút "Đăng nhập".
- **Chuyển nhanh tài khoản**: Hiển thị danh sách tài khoản đã đăng nhập trước đó (lưu trong SharedPreferences), tap để đăng nhập ngay mà không cần nhập lại. Có nút X để xóa tài khoản đã lưu.
- Link "Quên mật khẩu?" (tùy chọn).
- Link "Chưa có tài khoản? Đăng ký" → chuyển sang màn hình Register.
- Nút đăng nhập nhanh qua Google (tùy chọn).

### Thành phần giao diện
- TextField email (keyboard type: email).
- TextField mật khẩu (obscureText: true, có nút hiện/ẩn mật khẩu).
- Nút đăng nhập (primary button).
- Text link register và forgot password.
- Thông báo lỗi (email sai, mật khẩu sai, mạng lỗi).

### Logic chính
- Validate input:
  - Email không được trống và phải đúng định dạng.
  - Mật khẩu không được trống (có thể yêu cầu độ dài tối thiểu 6 ký tự).
- Gọi `FirebaseAuth.signInWithEmailAndPassword()`.
- Nếu thành công → chuyển sang Chat List.
- Nếu thất bại → hiển thị thông báo lỗi (snackbar hoặc dialog).

---

## 3. Màn hình Register (Đăng ký)

### Mục đích
- Cho phép người dùng tạo tài khoản mới.

### Chức năng
- Nhập email, mật khẩu, xác nhận mật khẩu.
- (Tùy chọn) Nhập tên hiển thị.
- Nút "Đăng ký".
- Link "Đã có tài khoản? Đăng nhập" → chuyển sang Login.

### Thành phần giao diện
- TextField email.
- TextField mật khẩu (obscureText: true).
- TextField xác nhận mật khẩu (obscureText: true).
- TextField tên hiển thị (tùy chọn).
- Nút đăng ký.
- Link quay lại login.
- Thông báo lỗi (email đã tồn tại, mật khẩu không khớp, v.v.).

### Logic chính
- Validate:
  - Email đúng định dạng.
  - Mật khẩu và xác nhận mật khẩu phải giống nhau.
  - Mật khẩu tối thiểu 8 ký tự.
- Gọi `FirebaseAuth.createUserWithEmailAndPassword()`.
- (Tùy chọn) Lưu thông tin người dùng vào Firestore (userId, email, displayName, avatarUrl).
- Nếu thành công → có thể tự động đăng nhập và chuyển sang Chat List.
- Nếu thất bại → hiển thị thông báo lỗi.

---

## 4. Màn hình Chat List (Danh sách cuộc trò chuyện)

### Mục đích
- Hiển thị danh sách các cuộc trò chuyện (1–1 hoặc nhóm) mà người dùng đã tham gia.

### Chức năng
- Hiển thị danh sách chat:
  - Avatar người dùng/phòng chat.
  - Tên người dùng/tên nhóm.
  - Tin nhắn cuối cùng.
  - Thời gian tin nhắn cuối.
  - Số lượng tin nhắn chưa đọc (badge).
- Kéo để làm mới (pull-to-refresh).
- Nút tạo chat mới (floating action button) → chọn người dùng để tạo chat 1–1 hoặc tạo nhóm.
- Thanh tìm kiếm (tùy chọn).
- Menu cài đặt (icon ở góc) → chuyển sang màn hình Profile/Cài đặt.

### Thành phần giao diện
- AppBar: tiêu đề "Tin nhắn", icon menu/cài đặt.
- ListView/ListView.builder: danh sách chat items.
- Mỗi item chat:
  - CircleAvatar (avatar).
  - Column chứa tên, tin nhắn cuối, thời gian.
  - Badge số tin chưa đọc (nếu > 0).
- FloatingActionButton: icon compose (+) để tạo chat mới.
- **BottomNavigationBar**: 3 tab – **Chats** (danh sách chat) | **Calls** (lịch sử cuộc gọi – tùy chọn) | **People** (danh sách người dùng với trạng thái online/offline, tap để bắt đầu chat).

### Logic chính
- Lấy danh sách cuộc trò chuyện từ Firestore:
  - Có thể lưu collection `chats` với các trường:
    - `participants`: danh sách userId.
    - `lastMessage`, `lastMessageTime`.
- Lắng nghe thay đổi thời gian thực (onSnapshot) để cập nhật tin nhắn cuối.
- Bấm vào item → chuyển sang màn hình Chat Detail với `chatId`.
- Bấm FAB → mở màn hình chọn người dùng / tạo nhóm.

---

## 5. Màn hình Chat Detail (Chi tiết cuộc trò chuyện)

### Mục đích
- Hiển thị và tham gia vào một cuộc trò chuyện cụ thể (1–1 hoặc nhóm).

### Chức năng
- Hiển thị danh sách tin nhắn theo thời gian.
- Gửi tin nhắn văn bản.
- Gửi ảnh (từ thư viện hoặc chụp).
- Hiển thị thời gian, tên người gửi (trong nhóm).
- Hiển thị trạng thái tin nhắn (gửi, đã gửi, đã xem).
- Hiển thị người đang nhập (typing indicator) – tùy chọn.
- Bấm vào avatar/tên → xem thông tin người dùng (profile nhỏ).
- **PopupMenu 3 chấm** (góc) →:
  - **Cài đặt nhóm** → chuyển sang màn hình Group Settings.
  - **Xóa lịch sử chat** → xóa tất cả tin nhắn trong cuộc trò chuyện (có dialog xác nhận).
- **Long-press vào tin nhắn** → hiện bottom sheet/menu:
  - **Xóa tin nhắn** (chỉ tin của chính mình, hoặc admin với tin nhắn nhóm).
  - **Chỉnh sửa tin nhắn** (chỉ tin văn bản của chính mình, hiển thị `(đã chỉnh sửa)`).
  - Sao chép nội dung.

### Thành phần giao diện
- AppBar:
  - Avatar phòng chat (hoặc avatar người kia trong chat 1–1).
  - Tên người dùng/tên nhóm.
  - Trạng thái (online/offline, đang nhập).
  - Icon gọi điện (tùy chọn).
  - Icon 3 chấm → menu.
- ListView ngược (tin nhắn mới nhất ở dưới):
  - Mỗi tin nhắn hiển thị dưới dạng bubble:
    - Bubble bên phải: tin do chính mình gửi.
    - Bubble bên trái: tin từ người khác.
    - Hiển thị nội dung, thời gian, trạng thái.
- Bottom bar:
  - TextField nhập tin nhắn.
  - Icon đính kèm (ảnh, file).
  - Icon emoji (tùy chọn).
  - Nút gửi (miễn là có nội dung).

### Logic chính
- Khi vào màn hình:
  - Lấy `chatId` từ route arguments.
  - Lắng nghe danh sách tin nhắn từ Firestore collection `chats/{chatId}/messages` theo thời gian thực.
- Khi người dùng nhập và gửi:
  - Validate tin nhắn không được trống.
  - Ghi tin nhắn vào Firestore với:
    - `text`, `senderId`, `senderName`, `timestamp`, `type` (text/image).
  - Cập nhật `lastMessage`, `lastMessageTime` trong document `chats/{chatId}`.
- Khi gửi ảnh:
  - Upload ảnh lên Firebase Storage.
  - Lấy URL ảnh và ghi tin nhắn với `type: 'image'`, `imageUrl`.
- Hiển thị "đang nhập":
  - Khi người dùng gõ trong TextField, cập nhật trường `typingUser` trong Firestore.
  - Lắng nghe và hiển thị text "User đang nhập..." nếu có.
- **Khi xóa tin nhắn** (long-press → Xóa):
  - Kiểm tra `senderId == currentUserId`.
  - Xóa document tin nhắn trong `chats/{chatId}/messages/{messageId}`.
  - Nếu là tin nhắn cuối cùng, cập nhật lại `lastMessage` của `chats/{chatId}`.
- **Khi chỉnh sửa tin nhắn** (long-press → Chỉnh sửa):
  - Điền nội dung cũ vào TextField, đổi nút gửi thành nút "Lưu".
  - Cập nhật trường `text` và thêm trường `isEdited: true`, `editedAt` vào document tin nhắn.
  - Hiển thị nhãn `(đã chỉnh sửa)` nhỏ bên cạnh thời gian.

---

## 6. Màn hình Chọn Người Dùng (Create Chat)

### Mục đích
- Cho phép người dùng chọn một hoặc nhiều người để tạo cuộc trò chuyện mới.

### Chức năng
- Hiển thị danh sách người dùng (trừ chính mình).
- Tìm kiếm người dùng theo tên/email.
- Chọn người dùng (single select cho chat 1–1, multi select cho nhóm).
- Nút "Tạo chat" hoặc "Tạo nhóm".
- Nhập tên nhóm (nếu tạo nhóm).

### Thành phần giao diện
- AppBar: tiêu đề "새 chat" hoặc "Tạo nhóm".
- TextField tìm kiếm.
- ListView danh sách người dùng:
  - Avatar.
  - Tên, email (tùy chọn).
  - Checkbox hoặc icon tích chọn.
- FAB hoặc nút "Tạo chat/Tạo nhóm".
- Dialog nhập tên nhóm (nếu tạo nhóm).

### Logic chính
- Lấy danh sách người dùng từ Firestore collection `users`.
- Lọc bỏ người dùng hiện tại.
- Lắng nghe thay đổi thời gian thực (tùy chọn).
- Khi bấm "Tạo chat":
  - Tạo document mới trong `chats`:
    - `participants`: [userId1, userId2]
    - `createdAt`, `createdBy`.
  - Chuyển sang màn hình Chat Detail với `chatId` mới.
- Khi tạo nhóm:
  - `participants`: danh sách nhiều userId.
  - `groupName`, `groupAvatar` (tùy chọn).

---

## 7. Màn hình Profile / Cài đặt (Profile & Settings)

### Mục đích
- Hiển thị và chỉnh sửa thông tin cá nhân, cài đặt ứng dụng.

### Chức năng
- Hiển thị thông tin:
  - Avatar.
  - Tên hiển thị.
  - Email.
  - Trạng thái (online/offline).
- Chỉnh sửa:
  - Đổi tên hiển thị.
  - Đổi avatar (chọn từ thư viện/chụp ảnh).
  - Đổi mật khẩu (tùy chọn).
- Cài đặt:
  - Bật/tắt thông báo.
  - Đổi ngôn ngữ (tùy chọn).
  - Chế độ tối/sáng (nếu có).
- Nút "Đăng xuất".
- Nút "Xóa tài khoản" (tùy chọn, cẩn thận).

### Thành phần giao diện
- AppBar: tiêu đề "Cài đặt" hoặc "Hồ sơ".
- Avatar lớn ở trên, có icon camera để đổi ảnh.
- Các trường thông tin:
  - TextField tên (có thể chỉnh sửa).
  - Text email (chỉ đọc).
  - Switch thông báo.
  - Settings list cho ngôn ngữ, theme.
- Nút "Đăng xuất" (color đỏ hoặc nổi bật).
- Nút "Xóa tài khoản" (tùy chọn, có dialog xác nhận).

### Logic chính
- Lấy thông tin người dùng hiện tại từ:
  - `FirebaseAuth.currentUser`.
  - Document `users/{userId}` trong Firestore.
- Khi lưu thay đổi:
  - Cập nhật Firestore (displayName, avatarUrl).
  - (Tùy chọn) Cập nhật Auth profile.
- Khi bấm đăng xuất:
  - Gọi `FirebaseAuth.signOut()`.
  - Chuyển về màn hình Login.
- Khi xóa tài khoản:
  - Yêu cầu xác nhận qua dialog.
  - Xóa document `users/{userId}`.
  - Xóa tài khoản Auth (cần quyền đặc biệt, có thể bỏ qua cho dự án học).

---

## 10. Màn hình Cài đặt Nhóm (Group Settings)

### Mục đích
- Xem và chỉnh sửa thông tin của một cuộc trò chuyện nhóm; quản lý thành viên.

### Chức năng
- Hiển thị thông tin nhóm:
  - Ảnh đại diện nhóm.
  - Tên nhóm.
  - Số lượng thành viên.
- Chỉnh sửa (chỉ admin/người tạo):
  - Đổi tên nhóm.
  - Đổi ảnh đại diện nhóm.
- Quản lý thành viên:
  - Xem danh sách thành viên (avatar, tên, trạng thái online).
  - Thêm thành viên → mở màn hình Chọn Người Dùng.
  - Xóa thành viên (chỉ admin).
- Nút "Rời nhóm" (cho mọi thành viên).
- Nút "Giải tán nhóm" (chỉ admin, tùy chọn).

### Thành phần giao diện
- AppBar: tiêu đề "Cài đặt nhóm", nút lưu (nếu đang chỉnh sửa).
- Ảnh nhóm lớn ở trên, có icon camera để đổi ảnh.
- TextField tên nhóm (có thể chỉnh sửa nếu là admin).
- Tiêu đề "Thành viên (N người)".
- ListView danh sách thành viên:
  - Avatar, tên, badge "Admin" nếu là trưởng nhóm.
  - Nút xóa (icon trash) hiện với admin.
- Nút "Thêm thành viên".
- Nút "Rời nhóm" (màu đỏ).

### Logic chính
- Nhận `chatId` từ route arguments.
- Lấy thông tin nhóm từ Firestore `chats/{chatId}`.
- **Update tên/ảnh nhóm**:
  - Cập nhật trường `groupName`, `groupAvatar` trong `chats/{chatId}`.
  - Upload ảnh lên Firebase Storage nếu đổi ảnh.
- **Thêm thành viên**:
  - Chuyển sang màn hình Chọn Người Dùng (multi-select).
  - Thêm userId vào mảng `participants` bằng `FieldValue.arrayUnion()`.
- **Xóa thành viên**:
  - Xác nhận qua dialog.
  - Xóa userId khỏi `participants` bằng `FieldValue.arrayRemove()`.
- **Rời nhóm**:
  - Xác nhận qua dialog.
  - Xóa `currentUserId` khỏi `participants`.
  - Nếu là admin và còn thành viên: chuyển quyền admin cho người tiếp theo.
  - Quay về Chat List.

---

## 11. Màn hình Quên Mật Khẩu (Forgot Password)

### Mục đích
- Cho phép người dùng yêu cầu đặt lại mật khẩu qua email.

### Chức năng
- Nhập địa chỉ email đã đăng ký.
- Nút "Gửi email đặt lại mật khẩu".
- Thông báo thành công / lỗi.
- Link quay lại màn hình Login.

### Thành phần giao diện
- AppBar: tiêu đề "Quên mật khẩu", nút back.
- Text hướng dẫn ngắn ("Nhập email của bạn, chúng tôi sẽ gửi link đặt lại mật khẩu.").
- TextField email (keyboard type: email).
- Nút "Gửi" (primary button).
- Thông báo thành công (SnackBar hoặc text xanh lá).
- Thông báo lỗi (email không tồn tại, định dạng sai).

### Logic chính
- Validate email đúng định dạng và không trống.
- Gọi `FirebaseAuth.sendPasswordResetEmail(email)`.
- Nếu thành công → hiển thị thông báo "Email đặt lại mật khẩu đã được gửi" và vô hiệu hóa nút gửi để tránh spam.
- Nếu thất bại → hiển thị lỗi tương ứng (email không tồn tại, v.v.).
- Link quay lại Login.

---

## 8. Màn hình Chi tiết Người dùng (User Detail) – tùy chọn

### Mục đích
- Hiển thị thông tin chi tiết của một người dùng khác (khi bấm vào avatar trong chat list hoặc chat detail).

### Chức năng
- Hiển thị:
  - Avatar lớn.
  - Tên hiển thị.
  - Email (có thể ẩn một phần).
  - Trạng thái (online/offline).
  - Giới thiệu ngắn (bio) – tùy chọn.
- Nút "Gửi tin nhắn" → chuyển sang Chat Detail (tạo chat mới nếu chưa có).
- Nút "Bỏ theo dõi"/"Chặn" (tùy chọn).

### Thành phần giao diện
- AppBar: quay lại.
- Avatar lớn ở giữa trên.
- Tên, email, bio bên dưới.
- Trạng thái online/offline (dot màu xanh/đỏ).
- Nút "Gửi tin nhắn" (primary button).

### Logic chính
- Nhận `userId` từ route arguments.
- Lấy thông tin từ Firestore `users/{userId}`.
- Lắng nghe trạng thái online/offline (có thể dùng `onDisconnect` trong Realtime Database hoặc trường `lastSeen` trong Firestore).
- Bấm "Gửi tin nhắn":
  - Kiểm tra xem đã có chat giữa 2 người chưa.
  - Nếu chưa → tạo chat mới.
  - Chuyển sang Chat Detail.

---

## 9. Màn hình Thông báo / Dialog lỗi (khác)

### Các loại thông báo thường dùng

- **SnackBar**:
  - Hiển thị thông báo ngắn: lỗi đăng nhập, lỗi gửi tin, thành công.
  - Xuất hiện ở dưới, tự ẩn sau 2–3 giây.

- **Dialog**:
  - Xác nhận đăng xuất.
  - Xác nhận xóa tài khoản.
  - Xác nhận rời nhóm.
  - Nhập tên nhóm mới.

- **Loading overlay**:
  - Hiển thị khi đang đăng ký, đăng nhập, tải ảnh, tạo chat.
  - Chặn tương tác trong khi chờ.

---

## Tóm tắt số lượng màn hình tối thiểu cho dự án đơn giản

Tối thiểu (bắt buộc):
1. Splash Screen
2. Login
3. Register
4. Chat List
5. Chat Detail
6. Profile/Settings (có thể gộp đơn giản)

Tùy chọn (nếu có thời gian):
- Chọn Người Dùng (Create Chat)
- Chi tiết Người dùng
- Màn hình tạo nhóm
- Màn hình tìm kiếm người dùng/tin nhắn
- Cài đặt Nhóm (Group Settings) – **CRUD Update/Delete cho Conversation**
- Quên Mật Khẩu (Forgot Password)

> **Lưu ý CRUD tin nhắn**: Chức năng **xóa** và **chỉnh sửa** tin nhắn đơn lẻ được xử lý trực tiếp trong màn hình Chat Detail thông qua long-press gesture, không cần màn hình riêng.