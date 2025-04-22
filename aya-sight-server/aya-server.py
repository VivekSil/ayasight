import os
import base64
import mimetypes
from flask import Flask, request, jsonify
from flask_cors import CORS
from openai import OpenAI
from werkzeug.utils import secure_filename

# Get Cohere-compatible key from .env or env variable
api_key = os.getenv("COHERE_API_KEY") or "your-sk-..."

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Initialize Cohere's OpenAI-compatible API client
client = OpenAI(
    base_url="https://api.cohere.ai/compatibility/v1",
    api_key=api_key
)

def analyze_with_aya(base64_img: str, mime_type: str, prompt: str = "Describe this image.") -> str:
    data_url = f"data:{mime_type};base64,{base64_img}"
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": data_url}}
            ]
        }
    ]

    response = client.chat.completions.create(
        model="c4ai-aya-vision-8b",
        messages=messages
    )
    return response.choices[0].message.content


@app.route("/analyze-image", methods=["POST"])
def analyze_image():
    if "image" not in request.files:
        return jsonify({"error": "No image uploaded."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"error": "Empty filename."}), 400

    filename = secure_filename(file.filename)
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)

    try:
        mime_type = mimetypes.guess_type(filepath)[0] or "application/octet-stream"
        with open(filepath, "rb") as f:
            base64_img = base64.b64encode(f.read()).decode("utf-8")

        # Allow optional custom prompt from iOS
        prompt = request.form.get("prompt", "Describe this image.")
        print(f"📥 Received image: {filename} | Prompt: {prompt}")

        result_text = analyze_with_aya(base64_img, mime_type, prompt)

        print("✅ Aya response:", result_text)
        return jsonify({"response": result_text})

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": "Failed to process image"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3057, debug=True)
