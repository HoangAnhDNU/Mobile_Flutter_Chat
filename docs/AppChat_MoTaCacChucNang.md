# Mô Tả Các Chức Năng Hệ Thống – AppChat Mobile

> **Tham khảo:** WhatsApp, Zalo, Facebook Messenger, Telegram  
> **Nền tảng:** Flutter (Mobile) + Node.js Backend + MySQL + Socket.IO  
> **Phiên bản tài liệu:** 1.0

---

## I. Tổng Quan Phân Quyền

Hệ thống AppChat có **2 vai trò (role)** chính:

| Role | Tên hiển thị | Mô tả |
|---|---|---|
| `admin` | Quản trị viên | Quản lý toàn bộ người dùng, dữ liệu, hoạt động của hệ thống |
| `user` | Người dùng | Sử dụng ứng dụng để nhắn tin, tạo nhóm, tùy chỉnh cá nhân |

---

## II. Chức Năng Dành Cho ADMIN (Quản Trị Viên)

Admin truy cập hệ thống thông qua **giao diện quản trị (Admin Panel)**, tách biệt với ứng dụng người dùng thông thường.

---

### 1. Đăng Nhập Quản Trị

| Chức năng | Mô tả |
|---|---|
| Đăng nhập Admin | Đăng nhập bằng tài khoản có role `admin`, truy cập trang quản trị riêng |
| Xác thực 2 bước | Yêu cầu mã OTP hoặc mã PIN khi đăng nhập (bảo mật nâng cao) |
| Đăng xuất | Hủy phiên làm việc, xóa token khỏi hệ thống |

---

### 2. Quản Lý Người Dùng (User Management)

Đây là chức năng cốt lõi của Admin, tương tự cách **Zalo OA** quản lý danh sách khách hàng và **Facebook Pages** quản lý thành viên.

#### 2.1. Xem Danh Sách Người Dùng

- Xem toàn bộ danh sách tài khoản trong hệ thống
- Tìm kiếm người dùng theo: tên, email, UID
- Lọc người dùng theo: trạng thái online/offline, ngày tạo tài khoản, trạng thái bị khóa
- Phân trang danh sách người dùng
- Xem thông tin chi tiết của từng người dùng (avatar, email, tên, ngày tạo, lần cuối hoạt động)

#### 2.2. Thêm Người Dùng Mới

- Tạo tài khoản người dùng thủ công (không cần tự đăng ký)
- Nhập thông tin: tên hiển thị, email, mật khẩu tạm thời
- Gán role mặc định là `user`
- Gửi thông báo hoặc email chào mừng (nếu có email service)

#### 2.3. Chỉnh Sửa Thông Tin Người Dùng

- Cập nhật tên hiển thị
- Thay đổi hoặc đặt lại avatar
- Cập nhật email (cần xác minh tránh trùng lặp)
- Ghi chú nội bộ về người dùng (chỉ Admin thấy)

#### 2.4. Xóa Người Dùng

- Xóa vĩnh viễn tài khoản người dùng khỏi hệ thống
- Tự động xóa toàn bộ dữ liệu liên quan: tin nhắn, file media, thành viên nhóm
- Hiện hộp thoại xác nhận trước khi thực hiện xóa
- Lưu log hành động xóa (ai xóa, xóa lúc nào)

#### 2.5. Khóa / Mở Khóa Tài Khoản

- Khóa tài khoản người dùng vi phạm (tương tự tính năng **ban** của Telegram)
- Người dùng bị khóa không thể đăng nhập, nhận thông báo lý do bị khóa
- Admin có thể mở khóa lại tài khoản bất cứ lúc nào
- Tùy chọn: khóa tạm thời (có thời hạn) hoặc khóa vĩnh viễn

#### 2.6. Đặt Lại Mật Khẩu

- Admin có thể đặt lại mật khẩu của người dùng (ví dụ khi người dùng quên mật khẩu mà chưa có email service)
- Gửi mật khẩu tạm thời hoặc yêu cầu người dùng đổi mật khẩu lần đăng nhập kế tiếp

---

### 3. Quản Lý Nhóm Chat (Group Management)

Tham khảo từ các chức năng **Super Admin** trên Telegram và tính năng **Group Admin** trên WhatsApp.

- Xem danh sách tất cả các nhóm trong hệ thống
- Xem thành viên của từng nhóm
- Xem lịch sử tin nhắn trong nhóm (để kiểm duyệt khi cần)
- Giải tán (xóa) một nhóm chat nếu vi phạm
- Thêm hoặc xóa thành viên khỏi nhóm bất kỳ
- Chuyển quyền admin nhóm cho thành viên khác

---

### 4. Quản Lý Tin Nhắn & Nội Dung

- Xem lịch sử tin nhắn của bất kỳ cuộc trò chuyện nào (để kiểm tra vi phạm)
- Xóa tin nhắn vi phạm trong bất kỳ cuộc chat nào
- Xem và quản lý danh sách file media đã upload lên hệ thống
- Xóa media không phù hợp

---

### 5. Quản Lý Hệ Thống

- **Dashboard tổng quan**: tổng số người dùng, số cuộc trò chuyện, số tin nhắn trong ngày, số người đang online
- **Thống kê hoạt động**: biểu đồ người dùng mới theo ngày/tuần/tháng, số tin nhắn gửi đi theo thời gian
- **Kiểm tra trạng thái server**: API `/health` trả về trạng thái backend, kết nối database
- **Quản lý cấu hình hệ thống**: giới hạn kích thước file upload, thời hạn JWT token, cấu hình CORS

---

### 6. Nhật Ký Hành Động (Activity Log)

- Ghi lại toàn bộ hành động của Admin: ai đã thêm/xóa/khóa người dùng nào, lúc nào
- Lưu log đăng nhập Admin (thời gian, địa chỉ IP)
- Tham khảo: Telegram ghi lại **Admin Recent Actions** trong nhóm, cho phép Super Admin kiểm tra lịch sử hành động

---

### 7. Phân Quyền Admin Nhiều Cấp *(Nâng cao – tham khảo Zalo OA)*

Tham khảo từ **Zalo OA** cho phép tối đa 100 admin với các quyền khác nhau:

| Cấp độ | Quyền hạn |
|---|---|
| **Super Admin** | Toàn quyền, bao gồm tạo/xóa admin khác |
| **Content Admin** | Chỉ xem và chỉnh sửa nội dung, không thể xóa người dùng |
| **Support Admin** | Chỉ xem thông tin người dùng để hỗ trợ, không thể chỉnh sửa |

> *Trong phạm vi đồ án học phần, có thể đơn giản hóa thành một cấp Admin duy nhất.*

---

## III. Chức Năng Dành Cho USER (Người Dùng)

Người dùng truy cập qua **ứng dụng Flutter**. Chức năng được chia thành các nhóm màn hình.

---

### 1. Xác Thực & Tài Khoản

#### 1.1. Đăng Ký Tài Khoản
- Nhập tên hiển thị, email, mật khẩu, xác nhận mật khẩu
- Kiểm tra định dạng email hợp lệ
- Mật khẩu tối thiểu 8 ký tự
- Sau khi đăng ký thành công, tự động đăng nhập và vào màn hình chính
- *Tham khảo: WhatsApp yêu cầu số điện thoại; Zalo yêu cầu số điện thoại hoặc email*

#### 1.2. Đăng Nhập
- Đăng nhập bằng email và mật khẩu
- Lưu phiên đăng nhập (JWT) — không cần đăng nhập lại mỗi lần mở app
- Đăng nhập nhanh từ danh sách tài khoản đã lưu trên thiết bị
- Hiển thị thông báo lỗi rõ ràng khi sai email hoặc mật khẩu

#### 1.3. Quên Mật Khẩu
- Nhập email để yêu cầu đặt lại mật khẩu
- Nhận email có link hoặc mã OTP để xác nhận *(chức năng cần email service)*

#### 1.4. Đăng Xuất
- Xóa token và thông tin phiên khỏi thiết bị
- Cập nhật trạng thái offline trên server

---

### 2. Hồ Sơ Cá Nhân (Profile)

Tham khảo từ **WhatsApp** và **Zalo** cho phép người dùng kiểm soát hoàn toàn thông tin cá nhân hiển thị với người khác.

| Chức năng | Mô tả |
|---|---|
| Xem hồ sơ | Xem avatar, tên, email, trạng thái |
| Đổi tên hiển thị | Cập nhật tên hiển thị bất kỳ lúc nào |
| Đổi avatar | Chọn ảnh từ thư viện, nén ảnh tự động trước khi upload |
| Trạng thái cá nhân (Bio) | Viết dòng giới thiệu ngắn hiển thị với bạn bè *(tham khảo WhatsApp "About")* |
| Xem email | Hiển thị email đang dùng (không cho phép đổi email tự do) |
| Đổi mật khẩu | Nhập mật khẩu cũ + mật khẩu mới để cập nhật |

---

### 3. Cài Đặt Giao Diện & Ngôn Ngữ

| Chức năng | Mô tả |
|---|---|
| Chế độ sáng / tối | Bật/tắt Dark Mode, lưu vào SharedPreferences |
| Chọn ngôn ngữ | Tiếng Việt hoặc English, thay đổi ngôn ngữ toàn bộ giao diện |
| Cỡ chữ | Tùy chỉnh cỡ chữ hiển thị tin nhắn *(tham khảo WhatsApp)* |
| Bật/tắt thông báo | Bật hoặc tắt âm thanh thông báo tin nhắn mới |

---

### 4. Quản Lý Bạn Bè & Liên Hệ

Tham khảo từ **Zalo** cho phép thêm bạn qua số điện thoại hoặc QR code; **WhatsApp** đồng bộ danh bạ.

| Chức năng | Mô tả |
|---|---|
| Xem danh sách người dùng | Xem tất cả người dùng trong hệ thống để bắt đầu chat |
| Tìm kiếm người dùng | Tìm theo tên hiển thị hoặc email |
| Xem hồ sơ người khác | Xem avatar, tên, trạng thái online của người dùng khác |
| Chặn người dùng | Ngăn người dùng đó nhắn tin cho mình *(tham khảo WhatsApp Blocked Contacts)* |
| Bỏ chặn | Gỡ chặn để người dùng đó có thể liên lạc lại |
| Xem danh sách đã chặn | Xem và quản lý những người đã bị chặn |

---

### 5. Chat 1-1 (Nhắn Tin Cá Nhân)

Đây là chức năng cốt lõi, tham khảo đầy đủ từ **WhatsApp**, **Zalo**, **Messenger**.

#### 5.1. Danh Sách Cuộc Trò Chuyện
- Hiển thị danh sách chat đã có theo thứ tự tin nhắn gần nhất
- Hiển thị: avatar, tên người/nhóm, nội dung tin nhắn cuối, thời gian, số tin chưa đọc
- Kéo sang trái để xóa một cuộc trò chuyện
- Lưu trữ (archive) cuộc trò chuyện *(tham khảo WhatsApp Archived Chats)*
- Tắt thông báo cho một cuộc trò chuyện (Mute)
- Tìm kiếm trong danh sách chat

#### 5.2. Tạo Chat Mới
- Chọn người dùng từ danh sách để bắt đầu chat
- Nếu đã có cuộc trò chuyện, tự động vào chat cũ thay vì tạo mới

#### 5.3. Gửi & Nhận Tin Nhắn Văn Bản
- Gửi tin nhắn chữ thời gian thực (realtime qua Socket.IO)
- Hỗ trợ định dạng văn bản: in đậm, in nghiêng *(tham khảo WhatsApp text formatting)*
- Nhận tin nhắn ngay khi có — hiển thị thông báo trong app
- Hiển thị trạng thái: **đã gửi ✓**, **đã nhận ✓✓**, **đã đọc ✓✓ (xanh)** *(tham khảo WhatsApp blue ticks)*
- Xem dấu thời gian của từng tin nhắn

#### 5.4. Gửi Media

| Loại media | Mô tả |
|---|---|
| Ảnh từ thư viện | Chọn ảnh từ bộ nhớ thiết bị |
| Chụp ảnh trực tiếp | Mở camera và chụp ảnh ngay trong app |
| File âm thanh (Voice) | Chọn hoặc ghi âm file âm thanh *(định dạng: m4a, mp3, wav, aac)* |
| Ghi âm giọng nói | Giữ nút mic để ghi âm, thả để gửi *(tham khảo WhatsApp voice notes)* |

#### 5.5. Thao Tác Với Tin Nhắn

| Thao tác | Mô tả |
|---|---|
| Trả lời tin nhắn | Vuốt hoặc nhấn giữ → trích dẫn tin nhắn gốc *(tham khảo WhatsApp reply)* |
| Chỉnh sửa tin nhắn | Sửa nội dung tin nhắn của chính mình, hiển thị nhãn "(đã chỉnh sửa)" |
| Xóa cho mình | Ẩn tin nhắn chỉ với người đang thao tác |
| Xóa cho tất cả | Xóa tin nhắn với tất cả người trong chat *(tham khảo WhatsApp "Delete for everyone")* |
| Ghim tin nhắn | Ghim tin nhắn quan trọng lên đầu màn hình chat |
| Xem tin nhắn đã ghim | Xem danh sách tất cả tin nhắn đã ghim trong cuộc trò chuyện |
| Copy tin nhắn | Sao chép nội dung tin nhắn vào clipboard |
| Chuyển tiếp tin nhắn | Chuyển tiếp (forward) tin nhắn đến cuộc chat khác *(tham khảo Zalo forward)* |
| Thả cảm xúc (Reaction) | Nhấn giữ để chọn emoji phản hồi: ❤️ 😂 😮 😢 😡 👍 *(tham khảo Messenger reactions)* |

#### 5.6. Tìm Kiếm Tin Nhắn
- Tìm kiếm nội dung tin nhắn trong cuộc trò chuyện theo từ khóa *(tham khảo WhatsApp Search in Chat)*
- Kết quả tìm kiếm hiển thị và có thể nhảy đến tin nhắn tương ứng

#### 5.7. Xóa Lịch Sử Chat
- Xóa toàn bộ tin nhắn trong cuộc trò chuyện
- Có hộp thoại xác nhận trước khi thực hiện

---

### 6. Trạng Thái Realtime

Tham khảo từ **WhatsApp** và **Zalo** cho hiển thị trạng thái người dùng theo thời gian thực.

| Chức năng | Mô tả |
|---|---|
| Online / Offline | Hiển thị trạng thái đang online hoặc offline ở màn hình chat |
| Lần cuối online | Hiển thị thời gian lần cuối người dùng truy cập app *(tham khảo WhatsApp "Last seen")* |
| Đang soạn tin... | Hiển thị thông báo "... đang soạn tin" khi người kia đang nhập *(tham khảo WhatsApp typing indicator)* |
| Trạng thái gửi/nhận/đọc | Cập nhật realtime qua Socket.IO |

---

### 7. Chat Nhóm (Group Chat)

Tham khảo đầy đủ từ **WhatsApp Group**, **Zalo Group**, **Telegram Group**.

#### 7.1. Tạo Nhóm
- Chọn nhiều người dùng (tối thiểu 2 người ngoài người tạo)
- Đặt tên nhóm bắt buộc
- Người tạo nhóm tự động trở thành **Admin nhóm**

#### 7.2. Nhắn Tin Trong Nhóm
- Tất cả chức năng nhắn tin cá nhân (mục 5) đều áp dụng cho nhóm
- Tin nhắn gửi realtime đến tất cả thành viên đang online
- Hiển thị tên người gửi và avatar nhỏ bên cạnh tin nhắn của người khác

#### 7.3. Quản Lý Nhóm (Admin Nhóm)

Tham khảo quyền **Group Admin** trên WhatsApp và **Super Admin** trên Telegram:

| Chức năng | Ai dùng được |
|---|---|
| Đổi tên nhóm | Chỉ Admin nhóm |
| Đổi avatar nhóm | Chỉ Admin nhóm |
| Thêm thành viên | Chỉ Admin nhóm |
| Xóa thành viên | Chỉ Admin nhóm |
| Chuyển quyền Admin | Admin nhóm chuyển quyền cho người khác *(tham khảo WhatsApp "Make Group Admin")* |
| Giải tán nhóm | Chỉ Admin nhóm |
| Rời nhóm | Tất cả thành viên (nếu Admin rời, quyền chuyển cho thành viên tiếp theo) |

#### 7.4. Liên Kết Mời Nhóm *(Nâng cao)*
- Tạo link mời để chia sẻ cho người ngoài tham gia nhóm *(tham khảo WhatsApp Group Invite Link)*
- Admin có thể vô hiệu hóa link mời bất kỳ lúc nào

---

### 8. Cuộc Gọi *(Nâng cao – tham khảo WhatsApp, Zalo)*

| Chức năng | Mô tả |
|---|---|
| Gọi thoại 1-1 | Gọi âm thanh qua internet (VoIP) |
| Gọi video 1-1 | Gọi video có hình ảnh |
| Gọi nhóm | Gọi thoại nhóm nhiều người *(WhatsApp hỗ trợ lên đến 32 người)* |
| Chia sẻ màn hình | Chia sẻ màn hình trong cuộc gọi video *(tham khảo WhatsApp screen sharing)* |

> *Trong phạm vi đồ án học phần, có thể giới hạn ở gọi thoại 1-1 cơ bản.*

---

### 9. Thông Báo (Notifications)

| Chức năng | Mô tả |
|---|---|
| Thông báo trong app | Hiển thị SnackBar / badge khi có tin nhắn mới |
| Push notification | Nhận thông báo kể cả khi đóng app *(cần tích hợp FCM – Firebase Cloud Messaging)* |
| Tắt thông báo từng chat | Mute thông báo riêng cho từng cuộc trò chuyện |
| Tắt thông báo toàn cục | Tắt thông báo toàn bộ app từ màn hình Hồ sơ |

---

### 10. Bảo Mật & Quyền Riêng Tư

Tham khảo **WhatsApp Privacy Settings** và **Zalo quyền riêng tư**:

| Chức năng | Mô tả |
|---|---|
| Kiểm soát "Last seen" | Ai được xem thời gian online gần nhất: Tất cả / Bạn bè / Không ai *(tham khảo WhatsApp)* |
| Kiểm soát avatar | Ai được xem ảnh đại diện: Tất cả / Không ai |
| Tắt trạng thái đọc | Ẩn dấu tick xanh "đã đọc" — nếu tắt, mình cũng không xem được trạng thái đọc của người khác *(tham khảo WhatsApp)* |
| Tin nhắn tự xóa | Cài hẹn giờ tự động xóa tin nhắn sau 24h / 7 ngày / 90 ngày *(tham khảo WhatsApp Disappearing Messages)* |
| Chặn người dùng | Ngăn người cụ thể nhắn tin, gọi điện cho mình |

---

## IV. So Sánh Chức Năng Theo Role

| Nhóm chức năng | Admin | User |
|---|---|---|
| Đăng nhập / Đăng xuất | ✅ | ✅ |
| Quản lý tài khoản toàn hệ thống | ✅ | ❌ |
| Thêm / Sửa / Xóa người dùng | ✅ | ❌ |
| Khóa / Mở khóa tài khoản | ✅ | ❌ |
| Xem toàn bộ nhóm trong hệ thống | ✅ | ❌ |
| Xem dashboard thống kê | ✅ | ❌ |
| Nhắn tin cá nhân | ❌ *(tách biệt)* | ✅ |
| Tạo nhóm chat | ❌ *(tách biệt)* | ✅ |
| Tùy chỉnh hồ sơ cá nhân | ✅ *(hồ sơ admin)* | ✅ |
| Cài đặt giao diện (theme, ngôn ngữ) | ✅ | ✅ |
| Quản lý nhóm mình tạo | N/A | ✅ *(Admin nhóm)* |
| Chặn / Bỏ chặn người dùng khác | ✅ *(cấp hệ thống)* | ✅ *(cấp cá nhân)* |

---

## V. Các Chức Năng Cần Hoàn Thiện

| Chức năng | Hiện trạng | Hướng phát triển |
|---|---|---|
| Gọi thoại / video | Chưa có | Tích hợp WebRTC hoặc thư viện VoIP |
| Push notification | Thông báo trong app | Thêm Firebase Cloud Messaging (FCM) |
| Tin nhắn tự xóa | Chưa có | Thêm trường `expires_at` trong bảng `messages` |
| Quên mật khẩu qua email | Có giao diện, chưa có backend | Tích hợp NodeMailer hoặc SendGrid |
| Ghi âm trực tiếp | Dùng file picker | Tích hợp thư viện ghi âm (flutter_sound) |
| Chuyển tiếp tin nhắn | Chưa có | Thêm API forward message |
| Tin nhắn xem 1 lần | Chưa có | Tham khảo WhatsApp "View Once" |
| Admin Panel | Chưa có giao diện | Xây dựng web dashboard hoặc màn hình admin riêng trong app |
| Đăng nhập 2 bước | Chưa có | Thêm xác thực OTP/PIN cho tài khoản Admin |
| JWT Middleware | Có token nhưng chưa verify ở backend | Thêm middleware xác thực JWT cho tất cả route cần bảo vệ |

---

*Tài liệu này được xây dựng dựa trên tham khảo chức năng của WhatsApp, Zalo, Facebook Messenger và Telegram. Phù hợp cho đề tài học phần Lập trình Mobile.*
