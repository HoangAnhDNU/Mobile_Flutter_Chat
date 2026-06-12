# Speech-to-Text API Documentation

API chuyển đổi giọng nói tiếng Việt thành văn bản, sử dụng model **faster-whisper** (OpenAI Whisper tối ưu).

---

## Tổng quan

| Thuộc tính | Giá trị |
|---|---|
| Model | OpenAI Whisper (faster-whisper) |
| Model size | `small` (~461MB, tải tự động lần đầu) |
| Ngôn ngữ | Tiếng Việt (`vi`) |
| Compute type | `float32` (CPU) |
| Framework | CTranslate2 |
| Miễn phí | ✅ Hoàn toàn miễn phí, chạy offline |

---

## Yêu cầu hệ thống

- **Python** >= 3.8
- **RAM** >= 2GB (cho model `small`)
- **Dung lượng ổ đĩa** >= 500MB (cho model)

---

## Cài đặt

```bash
cd speech_to_text
pip install -r requirements.txt
```

---

## Chạy Service

```bash
cd speech_to_text
python app.py
```

Service sẽ chạy tại `http://localhost:5000` (hoặc `http://0.0.0.0:5000` cho mạng LAN)

### Biến môi trường (tùy chọn)

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `WHISPER_MODEL` | `small` | Kích thước model: `tiny`, `base`, `small`, `medium`, `large` |
| `WHISPER_COMPUTE` | `float32` | Kiểu tính toán: `int8`, `float32` |
| `STT_HOST` | `0.0.0.0` | Host |
| `STT_PORT` | `5000` | Port |

---

## API Endpoints

### 1. Health Check

Kiểm tra trạng thái service.

```
GET /health
```

**Response (200):**
```json
{
  "status": "ok",
  "model": "small",
  "compute_type": "float32"
}
```

---

### 2. Chuyển âm thanh → JSON text

Endpoint chính để tích hợp vào app chat.

```
POST /transcribe
Content-Type: multipart/form-data
```

**Request:**
- Field: `audio` — file âm thanh (.wav, .mp3, .m4a, .ogg, .flac)

**Response (200):**
```json
{
  "text": "Xin chào, tôi muốn gửi tin nhắn",
  "segments": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "Xin chào"
    },
    {
      "start": 2.5,
      "end": 4.8,
      "text": "tôi muốn gửi tin nhắn"
    }
  ],
  "language": "vi",
  "language_probability": 0.98,
  "duration_seconds": 4.8,
  "processing_time_seconds": 1.23
}
```

**Response (400):**
```json
{
  "error": "Không tìm thấy file audio. Gửi file với field name 'audio'"
}
```

**Ví dụ curl:**
```bash
curl -X POST http://localhost:5000/transcribe \
  -F "audio=@your_audio_file.wav"
```

**Ví dụ Python:**
```python
import requests

with open("your_audio_file.wav", "rb") as f:
    response = requests.post(
        "http://localhost:5000/transcribe",
        files={"audio": f}
    )
    result = response.json()
    print(result["text"])
```

---

### 3. Chuyển âm thanh → File .txt

Endpoint để tải về file text (không dùng cho app chat real-time).

```
POST /transcribe-to-file
Content-Type: multipart/form-data
```

**Request:**
- Field: `audio` — file âm thanh (.wav, .mp3, .m4a, .ogg, .flac)

**Response (200):**
- File `.txt` chứa nội dung đã chuyển đổi (download tự động)

**Ví dụ curl:**
```bash
curl -X POST http://localhost:5000/transcribe-to-file \
  -F "audio=@your_audio_file.wav" \
  -o result.txt
```

---

## Tích hợp vào Flutter App

### Cấu hình

Trong `lib/core/constants/app_config.dart`:

```dart
class AppConfig {
  static const String serverHost = '192.168.x.x'; // IP máy chạy STT
  static const int sttPort = 5000;
  static const String sttUrl = 'http://$serverHost:$sttPort';
}
```

### Gọi API

Sử dụng `http` package với `MultipartRequest`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> transcribeAudio(String filePath) async {
  final uri = Uri.parse('${AppConfig.sttUrl}/transcribe');
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('audio', filePath));

  final streamedResponse = await request.send().timeout(
    const Duration(seconds: 60),
  );
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['text'] as String;
  } else {
    final error = jsonDecode(response.body);
    throw Exception(error['error'] ?? 'Lỗi chuyển giọng nói');
  }
}
```

### Workflow trong Chat App

1. **Ghi âm** — dùng package `record` để ghi file `.wav` vào thư mục tạm
2. **Upload** — gọi API `/transcribe` với file vừa ghi
3. **Nhận text** — lấy `data['text']` từ response
4. **Điền vào input** — set text vào `TextEditingController` để người dùng chỉnh sửa
5. **Gửi tin nhắn** — user nhấn Send → gửi text qua backend chat API

---

## Lưu ý quan trọng

- **Lần đầu chạy** sẽ tự động tải model (~461MB), cần internet
- **Sau khi tải xong**, service chạy **hoàn toàn offline**
- **Định dạng audio hỗ trợ**: `.wav`, `.mp3`, `.m4a`, `.ogg`, `.flac`
- **Chất lượng audio**: càng rõ tiếng, ít nhiễu → kết quả càng chính xác
- **Timeout**: nên đặt timeout 60s cho request vì AI xử lý mất thời gian
- **File tạm**: sau khi transcribe xong nên xóa file audio tạm để tiết kiệm bộ nhớ

---

## Cấu trúc thư mục

```
speech_to_text/
├── app.py              # Flask server + API endpoints
├── requirements.txt    # Python dependencies
├── README.md           # Tài liệu API (file này)
└── uploads/            # Thư mục tạm (tự tạo, tự xóa sau xử lý)
```
