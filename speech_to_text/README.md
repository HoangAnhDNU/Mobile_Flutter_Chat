# Speech-to-Text Service (AI Vietnamese STT)

Service Python chuyển đổi giọng nói tiếng Việt thành văn bản, sử dụng model **faster-whisper** (OpenAI Whisper tối ưu).

## Thông tin Model AI

| Thuộc tính | Giá trị |
|---|---|
| Model | OpenAI Whisper (faster-whisper) |
| Model size | `small` (~461MB, tải tự động lần đầu) |
| Ngôn ngữ | Tiếng Việt (`vi`) |
| Compute type | `float32` (CPU) |
| Framework | CTranslate2 |
| Miễn phí | ✅ Hoàn toàn miễn phí, chạy offline |

## Yêu cầu hệ thống

- **Python** >= 3.8
- **RAM** >= 2GB (cho model `small`)
- **Dung lượng ổ đĩa** >= 500MB (cho model)

## Cài đặt

```bash
cd speech_to_text
pip install -r requirements.txt
```

## Chạy Service

```bash
cd speech_to_text
python app.py
```

Service sẽ chạy tại `http://localhost:5000`

### Biến môi trường (tùy chọn)

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `WHISPER_MODEL` | `small` | Kích thước model: `tiny`, `base`, `small`, `medium`, `large` |
| `WHISPER_COMPUTE` | `float32` | Kiểu tính toán: `int8`, `float32` |
| `STT_HOST` | `0.0.0.0` | Host |
| `STT_PORT` | `5000` | Port |

## API Endpoints

### 1. Health Check

```
GET /health
```

**Response:**
```json
{
  "status": "ok",
  "model": "small",
  "compute_type": "float32"
}
```

### 2. Chuyển âm thanh → JSON text

```
POST /transcribe
Content-Type: multipart/form-data
```

**Request:**
- Field: `audio` — file âm thanh (.wav, .mp3, .m4a, .ogg, .flac)

**Response (200):**
```json
{
  "text": "Nguyễn Ngọc Hải Băng",
  "segments": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "Nguyễn Ngọc Hải Băng"
    }
  ],
  "language": "vi",
  "language_probability": 0.98,
  "duration_seconds": 2.5,
  "processing_time_seconds": 1.23
}
```

**Response (400):**
```json
{
  "error": "Không tìm thấy file audio. Gửi file với field name 'audio'"
}
```

**Ví dụ gọi bằng curl:**
```bash
curl -X POST http://localhost:5000/transcribe \
  -F "audio=@test.wav"
```

**Ví dụ gọi bằng Python:**
```python
import requests

with open("test.wav", "rb") as f:
    response = requests.post(
        "http://localhost:5000/transcribe",
        files={"audio": f}
    )
    print(response.json()["text"])
```

### 3. Chuyển âm thanh → File .txt

```
POST /transcribe-to-file
Content-Type: multipart/form-data
```

**Request:**
- Field: `audio` — file âm thanh (.wav, .mp3, .m4a, .ogg, .flac)

**Response (200):**
- File `.txt` chứa nội dung đã chuyển đổi (download tự động)

**Ví dụ gọi bằng curl:**
```bash
curl -X POST http://localhost:5000/transcribe-to-file \
  -F "audio=@test.wav" \
  -o result.txt
```

## Test nhanh

```bash
# Kiểm tra service
curl http://localhost:5000/health

# Test với file audio
curl -X POST http://localhost:5000/transcribe -F "audio=@../test.wav"
```

## Cấu trúc thư mục

```
speech_to_text/
├── app.py              # Flask server + API endpoints
├── requirements.txt    # Python dependencies
├── README.md           # Tài liệu API (file này)
└── uploads/            # Thư mục tạm (tự tạo, tự xóa sau xử lý)
```

## Tích hợp với Flutter App

Trong Flutter, gọi API bằng `http` package:

```dart
import 'package:http/http.dart' as http;

Future<String> transcribeAudio(String filePath) async {
  final uri = Uri.parse('http://<IP>:5000/transcribe');
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('audio', filePath));
  
  final response = await request.send();
  final body = await response.stream.bytesToString();
  final data = jsonDecode(body);
  return data['text'];
}
```

## Lưu ý

- Lần đầu chạy sẽ tự động tải model (~461MB), cần internet
- Sau khi tải xong, service chạy **hoàn toàn offline**
- File audio hỗ trợ: `.wav`, `.mp3`, `.m4a`, `.ogg`, `.flac`
- Chất lượng audio càng rõ → kết quả càng chính xác
