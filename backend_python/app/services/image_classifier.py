import os
import numpy as np
from PIL import Image
import onnxruntime as ort
from typing import Tuple, Dict

# Mapping từ class index sang label (cần cập nhật theo model thực tế)
CLASS_LABELS = {
    0: "classroom",
    1: "computerroom",
    2: "library",
    3: "corridor",
    4: "office",
}

class ImageClassifier:
    def __init__(self, model_path: str = None):
        if model_path is None:
            model_path = os.path.join(os.path.dirname(__file__), "../../ref/student_mobilenet_kd_A50_T20_E50.onnx")
        
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found at {model_path}")
        
        self.session = ort.InferenceSession(model_path)
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name
        
        # Lấy input shape (thường là [1, 3, 224, 224] cho MobileNet)
        input_shape = self.session.get_inputs()[0].shape
        self.input_size = (input_shape[2], input_shape[3])  # (height, width)
    
    def preprocess_image(self, image_path: str) -> np.ndarray:
        """Load và preprocess ảnh theo yêu cầu của MobileNet"""
        img = Image.open(image_path).convert('RGB')
        img = img.resize(self.input_size, Image.BILINEAR)
        
        # Convert to numpy array và normalize [0, 255] -> [0, 1]
        img_array = np.array(img, dtype=np.float32) / 255.0
        
        # MobileNet normalization: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
        img_array = (img_array - mean) / std
        
        # Add batch dimension: [H, W, C] -> [1, C, H, W]
        img_array = np.transpose(img_array, (2, 0, 1))
        img_array = np.expand_dims(img_array, axis=0)
        
        return img_array
    
    def predict(self, image_path: str, top_k: int = 1) -> Dict[str, float]:
        """Predict label cho ảnh, trả về {label: probability}"""
        try:
            img_array = self.preprocess_image(image_path)
            
            # Run inference
            outputs = self.session.run([self.output_name], {self.input_name: img_array})
            predictions = outputs[0][0]  # Remove batch dimension
            
            # Apply softmax if not already applied
            exp_preds = np.exp(predictions - np.max(predictions))
            probabilities = exp_preds / np.sum(exp_preds)
            
            # Get top-k predictions
            top_indices = np.argsort(probabilities)[::-1][:top_k]
            
            results = {}
            for idx in top_indices:
                label = CLASS_LABELS.get(int(idx), f"class_{idx}")
                results[label] = float(probabilities[idx])
            
            return results
        except Exception as e:
            raise RuntimeError(f"Prediction failed: {str(e)}")

# Singleton instance
_classifier_instance = None

def get_classifier() -> ImageClassifier:
    global _classifier_instance
    if _classifier_instance is None:
        model_path = os.path.join(os.path.dirname(__file__), "../../ref/student_mobilenet_kd_A50_T20_E50.onnx")
        _classifier_instance = ImageClassifier(model_path)
    return _classifier_instance
