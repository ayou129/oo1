#!/usr/bin/env python3
"""
Faster-Whisper ASR Server - Simplified for Docker
"""
import os
import json
import tempfile
from pathlib import Path

try:
    from fastapi import FastAPI, UploadFile, File, HTTPException
    import uvicorn
except ImportError:
    os.system('pip install fastapi uvicorn python-multipart -q')
    from fastapi import FastAPI, UploadFile, File, HTTPException
    import uvicorn

try:
    from faster_whisper import WhisperModel
except ImportError:
    os.system('pip install faster-whisper -q')
    from faster_whisper import WhisperModel

app = FastAPI(title="OO1 ASR Service")

MODEL_SIZE = os.getenv("ASR_MODEL", "small")
COMPUTE_TYPE = os.getenv("COMPUTE_TYPE", "int8")
LANGUAGE = os.getenv("ASR_LANGUAGE", "zh")
PORT = int(os.getenv("ASR_PORT", 8003))

print(f"Loading Faster-Whisper model: {MODEL_SIZE}")
model = WhisperModel(MODEL_SIZE, device="cuda", compute_type=COMPUTE_TYPE)

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{"id": f"faster-whisper-{MODEL_SIZE}", "object": "model", "owned_by": "openai-compatible"}]
    }

@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile = File(...), language: str = None):
    try:
        audio_data = await file.read()
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name

        try:
            segments, info = model.transcribe(tmp_path, language=language or LANGUAGE)
            text = "".join([segment.text for segment in segments])
            return {"text": text, "language": info.language, "duration": info.duration}
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_SIZE}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
