from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import Dict
import os
import tempfile
import aiofiles

from ..services.image_classifier import get_classifier

router = APIRouter(prefix="/image", tags=["Image"])

class ClassificationResponse(BaseModel):
    predictions: Dict[str, float]

@router.post("/classify", response_model=ClassificationResponse)
async def classify_image(file: UploadFile = File(...)):
    """
    Classify image using ONNX MobileNet model.
    Returns top prediction label with probability.
    """
    # Validate file type
    if not file.content_type or not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    # Save uploaded file temporarily
    temp_dir = tempfile.gettempdir()
    temp_path = os.path.join(temp_dir, f"temp_{file.filename}")
    
    try:
        async with aiofiles.open(temp_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        # Get classifier and predict
        classifier = get_classifier()
        predictions = classifier.predict(temp_path, top_k=1)
        
        return ClassificationResponse(predictions=predictions)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {str(e)}")
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.remove(temp_path)
