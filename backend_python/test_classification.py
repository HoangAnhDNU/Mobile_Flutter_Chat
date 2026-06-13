import base64
import requests
import json

# Create a simple test image (1x1 red pixel)
# In real scenario, you would use an actual image file
def create_test_image_base64():
    # This is a minimal 1x1 PNG image in base64
    return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

# Test the classification endpoint
def test_classification():
    url = "http://localhost:3000/api/image/classify"
    
    # Create a simple test file
    test_image_base64 = create_test_image_base64()
    image_data = base64.b64decode(test_image_base64)
    
    files = {'file': ('test.png', image_data, 'image/png')}
    
    try:
        response = requests.post(url, files=files)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_classification()
