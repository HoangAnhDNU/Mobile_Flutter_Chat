import os
import torch
import torch.nn as nn
from PIL import Image
from typing import Dict
import torchvision.transforms as transforms
from torchvision.models.mobilenetv2 import mobilenet_v2

# 3-way labels theo Fakeddit dataset
FAKE_NEWS_LABELS = {
    0: "True",
    1: "Satire/Clickbait",
    2: "Fake",
}

# Nhãn được coi là tin giả (không phải True)
FAKE_LABELS = {1, 2}


class MobileNetV2Classifier(nn.Module):
    """MobileNetV2 với head classification, tương thích checkpoint best_mobilenetv2_student.pt."""

    def __init__(self, num_classes: int = 3, dropout: float = 0.3):
        super().__init__()
        self.backbone = mobilenet_v2(weights=None)
        # Bỏ classifier gốc của MobileNetV2
        self.backbone.classifier = nn.Identity()
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(1280, num_classes)

    def forward(self, x):
        feat = self.backbone(x)  # [B, 1280]
        feat = self.dropout(feat)
        return self.fc(feat)


class FakeNewsClassifier:
    def __init__(self, model_path: str = None):
        if model_path is None:
            model_path = os.path.join(
                os.path.dirname(__file__), "../../ref/best_mobilenetv2_student.pt"
            )

        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found at {model_path}")

        self.device = torch.device("cpu")
        self.model = MobileNetV2Classifier(num_classes=3, dropout=0.3)
        state_dict = torch.load(model_path, map_location=self.device, weights_only=True)
        self.model.load_state_dict(state_dict)
        self.model.to(self.device)
        self.model.eval()

        self.transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
                ),
            ]
        )

    def preprocess_image(self, image_path: str) -> torch.Tensor:
        img = Image.open(image_path).convert("RGB")
        return self.transform(img).unsqueeze(0).to(self.device)

    def predict(self, image_path: str) -> Dict[str, float]:
        """Predict fake news label cho ảnh, trả về {label: probability}."""
        try:
            tensor = self.preprocess_image(image_path)
            with torch.no_grad():
                logits = self.model(tensor)
                probs = torch.softmax(logits, dim=1)[0]

            top_idx = int(torch.argmax(probs).item())
            label = FAKE_NEWS_LABELS.get(top_idx, f"class_{top_idx}")
            return {label: float(probs[top_idx].item())}
        except Exception as e:
            raise RuntimeError(f"Fake news prediction failed: {str(e)}")


# Singleton instance
_classifier_instance = None


def get_fake_news_classifier() -> FakeNewsClassifier:
    global _classifier_instance
    if _classifier_instance is None:
        model_path = os.path.join(
            os.path.dirname(__file__), "../../ref/best_mobilenetv2_student.pt"
        )
        _classifier_instance = FakeNewsClassifier(model_path)
    return _classifier_instance
