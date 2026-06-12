from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from faster_whisper import WhisperModel
import os
import tempfile
import time

app = Flask(__name__)
CORS(app)

# Cấu hình
MODEL_SIZE = os.getenv("WHISPER_MODEL", "small")
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE", "float32")
HOST = os.getenv("STT_HOST", "0.0.0.0")
PORT = int(os.getenv("STT_PORT", 5000))

UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Load model khi khởi động
print(f"[STT] Đang tải model '{MODEL_SIZE}' (compute: {COMPUTE_TYPE})...")
model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
print(f"[STT] Model đã sẵn sàng!")


@app.route("/health", methods=["GET"])
def health():
    """Kiểm tra trạng thái service"""
    return jsonify({
        "status": "ok",
        "model": MODEL_SIZE,
        "compute_type": COMPUTE_TYPE
    })


@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Chuyển file âm thanh tiếng Việt thành text.
    
    Input: file audio (multipart/form-data, field name: "audio")
    Output: JSON { "text": "...", "segments": [...], "duration": ... }
    """
    if "audio" not in request.files:
        return jsonify({"error": "Không tìm thấy file audio. Gửi file với field name 'audio'"}), 400

    audio_file = request.files["audio"]
    
    if audio_file.filename == "":
        return jsonify({"error": "File rỗng"}), 400

    # Lưu file tạm
    ext = os.path.splitext(audio_file.filename)[1] or ".wav"
    temp_path = os.path.join(UPLOAD_FOLDER, f"temp_{int(time.time())}{ext}")
    
    try:
        audio_file.save(temp_path)
        
        # Transcribe
        start_time = time.time()
        segments, info = model.transcribe(temp_path, language="vi", beam_size=5)
        
        result_segments = []
        full_text = ""
        
        for segment in segments:
            result_segments.append({
                "start": round(segment.start, 2),
                "end": round(segment.end, 2),
                "text": segment.text.strip()
            })
            full_text += segment.text
        
        elapsed = round(time.time() - start_time, 2)
        
        return jsonify({
            "text": full_text.strip(),
            "segments": result_segments,
            "language": info.language,
            "language_probability": round(info.language_probability, 2),
            "duration_seconds": round(info.duration, 2),
            "processing_time_seconds": elapsed
        })
    
    except Exception as e:
        return jsonify({"error": f"Lỗi xử lý: {str(e)}"}), 500
    
    finally:
        # Xóa file tạm
        if os.path.exists(temp_path):
            os.remove(temp_path)


@app.route("/transcribe-to-file", methods=["POST"])
def transcribe_to_file():
    """
    Chuyển file âm thanh thành file text (.txt).
    
    Input: file audio (multipart/form-data, field name: "audio")
    Output: File .txt chứa nội dung đã chuyển đổi
    """
    if "audio" not in request.files:
        return jsonify({"error": "Không tìm thấy file audio. Gửi file với field name 'audio'"}), 400

    audio_file = request.files["audio"]
    
    if audio_file.filename == "":
        return jsonify({"error": "File rỗng"}), 400

    ext = os.path.splitext(audio_file.filename)[1] or ".wav"
    temp_audio = os.path.join(UPLOAD_FOLDER, f"temp_{int(time.time())}{ext}")
    temp_txt = None
    
    try:
        audio_file.save(temp_audio)
        
        segments, info = model.transcribe(temp_audio, language="vi", beam_size=5)
        
        full_text = ""
        for segment in segments:
            full_text += segment.text
        
        # Tạo file text kết quả
        base_name = os.path.splitext(audio_file.filename)[0]
        temp_txt = os.path.join(UPLOAD_FOLDER, f"{base_name}_transcript.txt")
        
        with open(temp_txt, "w", encoding="utf-8") as f:
            f.write(full_text.strip())
        
        return send_file(
            temp_txt,
            mimetype="text/plain; charset=utf-8",
            as_attachment=True,
            download_name=f"{base_name}_transcript.txt"
        )
    
    except Exception as e:
        return jsonify({"error": f"Lỗi xử lý: {str(e)}"}), 500
    
    finally:
        if os.path.exists(temp_audio):
            os.remove(temp_audio)
        if temp_txt and os.path.exists(temp_txt):
            os.remove(temp_txt)


if __name__ == "__main__":
    print(f"[STT] Service chạy tại http://{HOST}:{PORT}")
    print(f"[STT] API docs: http://{HOST}:{PORT}/health")
    app.run(host=HOST, port=PORT, debug=True)
