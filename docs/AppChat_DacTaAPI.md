# AppChat — Đặc tả API

Tài liệu mô tả tổng quan các endpoint REST và sự kiện Socket.IO của backend FastAPI. Chi tiết đầy đủ (request body, response mẫu, mã lỗi từng endpoint) có thể tra cứu trong mã nguồn tại `backend_python/app/routes/`. Mọi endpoint đều yêu cầu JWT token qua header `Authorization: Bearer <token>` (trừ đăng ký và đăng nhập).

---

## 1. Tổng quan kiến trúc API

API được thiết kế theo phong cách RESTful, trả dữ liệu dạng JSON. Xác thực dùng JWT HS256 với thời hạn 24 giờ. Mật khẩu được băm bằng bcrypt. Realtime được xử lý qua Socket.IO với hai loại phòng: phòng cá nhân `user_{id}` cho thông báo riêng, và phòng cuộc trò chuyện `chat_{id}` cho sự kiện nhóm.

Base path cho REST: `/api`

---

## 2. Các nhóm endpoint chính

### 2.1. Xác thực — `/api/auth`

Nhóm này gồm bốn endpoint phục vụ vòng đời tài khoản.

**Đăng ký** `POST /api/auth/register` tạo tài khoản mới với email, mật khẩu và tên hiển thị, trả về JWT token ngay để client lưu lại. **Đăng nhập** `POST /api/auth/login` xác thực email và mật khẩu, trả về cùng cấu trúc. **Đăng xuất** `POST /api/auth/logout` đánh dấu offline và cập nhật `last_seen`. **Lấy thông tin** `GET /api/auth/me` trả thông tin người dùng hiện tại từ JWT.

### 2.2. Người dùng — `/api/users`

Nhóm này phục vụ hồ sơ cá nhân và tìm kiếm.

`PUT /api/users/me` cập nhật tên hiển thị và ảnh đại diện. `POST /api/users/change-password` yêu cầu mật khẩu cũ đúng trước khi đổi. `GET /api/users/search` tìm người dùng theo tên hoặc email, loại trừ người dùng hiện tại và áp dụng lọc quyền riêng tư. `GET /api/users/{user_id}` xem thông tin người khác, dữ liệu được lọc theo cài đặt quyền riêng tư của họ.

### 2.3. Cuộc trò chuyện — `/api/chats`

Đây là nhóm lớn nhất, gồm quản lý cuộc trò chuyện và toàn bộ thao tác tin nhắn.

Về cuộc trò chuyện: `GET /api/chats` trả danh sách kèm tin nhắn cuối cùng và số tin nhắn chưa đọc. `POST /api/chats/direct` tạo hoặc trả về cuộc trò chuyện giữa hai người. `POST /api/chats/group` tạo nhóm chat mới. `POST /api/chats/{id}/participants` và `DELETE /api/chats/{id}/participants/{user_id}` thêm hoặc xóa thành viên (chỉ admin nhóm). `POST /api/chats/{id}/leave` rời nhóm. `POST /api/chats/{id}/pin` ghim hoặc bỏ ghim cuộc trò chuyện. `POST /api/chats/{id}/mute` tắt hoặc bật thông báo. `POST /api/chats/{id}/archive` lưu trữ hoặc bỏ lưu trữ. `DELETE /api/chats/{id}` xóa cuộc trò chuyện phía mình (không ảnh hưởng người khác).

Về tin nhắn: `GET /api/chats/{id}/messages` trả danh sách có phân trang. `POST /api/chats/{id}/messages` gửi tin nhắn, hỗ trợ loại (`text`, `image`, `video`, `file`, `audio`, `location`), reply (`reply_to_id`), đề cập (`mentions`), và gửi realtime tới các thành viên qua Socket.IO. `PUT /api/chats/messages/{id}` sửa tin nhắn (chỉ người gửi, trong giới hạn thời gian). `DELETE /api/chats/messages/{id}?for_everyone=true/false` xóa phía mình hoặc thu hồi cho mọi người, realtime cập nhật tới các thành viên. `POST /api/chats/{id}/messages/{id}/pin` ghim hoặc bỏ ghim một tin nhắn (tối đa 3 mỗi cuộc trò chuyện). `POST /api/chats/messages/{id}/reactions` thả biểu cảm, `DELETE /api/chats/messages/reactions/{id}` xóa. `POST /api/chats/{id}/read` đánh dấu đã đọc. `GET /api/chats/{id}/search` tìm tin nhắn theo từ khóa trong cuộc trò chuyện. `DELETE /api/chats/{id}/messages` xóa toàn bộ lịch sử phía mình. `POST /api/chats/messages/{id}/forward` chuyển tiếp tin nhắn sang cuộc trò chuyện khác. `GET /api/chats/og/preview` xem trước liên kết qua Open Graph. `GET/PUT /api/chats/{id}/auto-delete` xem và đặt thời gian tin nhắn tự xóa.

### 2.4. Bạn bè — `/api/friend`

`POST /api/friend/request` gửi lời mời kết bạn theo email. `POST /api/friend/{id}/accept` chấp nhận, `POST /api/friend/{id}/reject` từ chối hoặc hủy. `DELETE /api/friend/{user_id}` hủy kết bạn. `GET /api/friend/list` lấy danh sách bạn bè đã kết bạn. `GET /api/friend/requests` lấy lời mời đang chờ.

### 2.5. Chặn — `/api/block`

`POST /api/block` chặn người dùng kèm báo cáo lý do (tự động hủy kết bạn nếu có). `DELETE /api/block/{user_id}` bỏ chặn. `GET /api/block` lấy danh sách đang chặn. `GET /api/block/check/{user_id}` kiểm tra xem có đang chặn nhau hay không.

### 2.6. Quyền riêng tư — `/api/privacy`

`GET /api/privacy` lấy bốn cài đặt hiện tại: ai xem lần cuối truy cập (`show_last_seen`), ai xem ảnh đại diện (`show_avatar`), hiển thị đã xem hay không (`show_read_receipts`), và thời gian tin nhắn tự biến mất (`disappearing_messages`). `PUT /api/privacy` cập nhật một hoặc nhiều cài đặt.

### 2.7. Liên kết mời nhóm — `/api/invite`

`POST /api/invite/{chat_id}` tạo liên kết mời ngẫu nhiên, vô hiệu hóa liên kết cũ. `GET /api/invite/{chat_id}` lấy liên kết hiện tại. `DELETE /api/invite/{chat_id}` thu hồi liên kết (chỉ admin nhóm). `POST /api/invite/join/{code}` tham gia nhóm qua mã liên kết.

### 2.8. Phân loại ảnh — `/api/image`

`POST /api/image/classify` nhận file ảnh, phân loại bằng mô hình ONNX MobileNet, trả nhãn và xác suất. Không yêu cầu xác thực. Giới hạn file 10 MB, chỉ chấp nhận `image/*`.

### 2.9. Quản trị — `/api/admin`

Tất cả endpoint đều yêu cầu tài khoản `role == "admin"`.

`GET /api/admin/stats` trả thống kê tổng quan: tổng người dùng, online, bị khóa, nhóm, tin nhắn, và biểu đồ cột 7 ngày cho tin nhắn và người dùng mới. `GET /api/admin/users` danh sách người dùng có phân trang và tìm kiếm. `POST /api/admin/users` tạo tài khoản (chọn vai trò `user` hoặc `admin`). `PUT /api/admin/users/{id}` sửa thông tin và vai trò. `POST /api/admin/users/{id}/lock` khóa, `POST /api/admin/users/{id}/unlock` mở khóa. `POST /api/admin/users/{id}/reset-password` đặt lại mật khẩu. `DELETE /api/admin/users/{id}` xóa người dùng (không tự xóa được). Tương tự cho nhóm: `GET /api/admin/groups`, `GET /api/admin/groups/{id}`, `PUT /api/admin/groups/{id}`, `POST /api/admin/groups/{id}/members`, `DELETE /api/admin/groups/{id}/members/{user_id}`, `DELETE /api/admin/groups/{id}` giải tán nhóm. `GET /api/admin/activity-log` lấy nhật ký hành động quản trị có phân trang.

---

## 3. Sự kiện Socket.IO

### 3.1. Kết nối

Client kết nối kèm JWT qua trường `auth`:

```javascript
const socket = io("http://<host>", {
  auth: { token: "<jwt_token>" }
});
```

### 3.2. Các sự kiện chính

**Từ server tới client** (phòng `user_{id}`):

- `new_message` — có tin nhắn mới, kèm `chatId`, `senderUid`, `message`.
- `mention_notification` — có người nhắc tên mình, kèm thông tin người gửi và tin nhắn.
- `message_edited` — tin nhắn đã được sửa.
- `message_deleted` — tin nhắn đã bị thu hồi.
- `pin_update` — trạng thái ghim của một tin nhắn thay đổi.
- `reaction_update` — biểu cảm trên tin nhắn thay đổi.

**Từ client tới server** (vào phòng `chat_{id}`):

- `join_chat` — tham gia phòng cuộc trò chuyện để nhận sự kiện nhóm.
- `typing` — tín hiệu đang nhập tin nhắn.

**Cuộc gọi WebRTC**:

- `call_offer`, `call_answer`, `call_ice_candidate` — báo hiệu WebRTC.
- `call_end` — kết thúc cuộc gọi.
- `call_reject` — từ chối cuộc gọi.

---

## 4. Bảng tổng hợp mã lỗi

| Mã | Ý nghĩa |
|----|----------|
| `200` | Thành công |
| `201` | Tài nguyên đã được tạo |
| `400` | Dữ liệu đầu vào không hợp lệ |
| `401` | Chưa xác thực hoặc token hết hạn |
| `403` | Không có quyền thực hiện |
| `404` | Tài nguyên không tìm thấy |
| `422` | Dữ liệu không đúng định dạng Pydantic |
| `500` | Lỗi phía server |

Phản hồi lỗi chuẩn: `{"detail": "Mô tả lỗi bằng tiếng Việt"}`.

---

## 5. Ánh xạ màn hình Flutter

| Màn hình | Nhóm endpoint |
|----------|--------------|
| `LoginScreen`, `RegisterScreen` | Auth |
| `ChatListScreen` | Chat |
| `ChatDetailScreen` | Chat, Message |
| `CreateChatScreen` | Chat |
| `JoinGroupScreen` | Group Invite |
| `ProfileScreen` | User |
| `PrivacySettingsScreen` | Privacy |
| `FriendsScreen` | Friend |
| `BlockedUsersScreen` | Block |
| `AdminDashboardScreen` và 4 tab | Admin |
