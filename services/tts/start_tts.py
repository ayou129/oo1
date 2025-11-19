#!/usr/bin/env python3
"""
XTTS v2 TTS Server - Simplified for Docker
"""
import os
import tempfile
from pathlib import Path

try:
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import FileResponse
    import uvicorn
except ImportError:
    os.system('pip install fastapi uvicorn -q')
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import FileResponse
    import uvicorn

try:
    from TTS.api import TTS
except ImportError:
    os.system('pip install TTS -q')
    from TTS.api import TTS

app = FastAPI(title="OO1 TTS Service")

TTS_LANGUAGE = os.getenv("TTS_LANGUAGE", "zh")
VOICE_DIR = os.getenv("VOICE_DIR", "/workspace/voices")
PORT = int(os.getenv("TTS_PORT", 8004))
TTS_DEVICE = os.getenv("TTS_DEVICE", "cuda").lower()
USE_GPU = TTS_DEVICE in ["cuda", "gpu", "true"]

print(f"Loading XTTS v2 model (language: {TTS_LANGUAGE}, device: {TTS_DEVICE})...")
tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", gpu=USE_GPU)

Path(VOICE_DIR).mkdir(exist_ok=True, parents=True)

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{"id": "xtts-v2", "object": "model", "owned_by": "openai-compatible"}]
    }

@app.get("/v1/voices")
async def list_voices():
    voices = [
        {"id": "default", "name": "Default Female", "language": TTS_LANGUAGE},
    ]
    for voice_file in Path(VOICE_DIR).glob("*.wav"):
        voices.append({"id": voice_file.stem, "name": voice_file.stem, "type": "cloned"})
    return {"object": "list", "data": voices}

@app.post("/v1/audio/speech")
async def synthesize(text: str, voice: str = "default", language: str = None, speed: float = 1.0):
    try:
        output_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        voice_path = Path(VOICE_DIR) / f"{voice}.wav" if voice != "default" else None

        if voice_path and voice_path.exists():
            tts.tts_to_file(text=text, file_path=output_file.name, speaker_wav=str(voice_path), language=language or TTS_LANGUAGE, speed=speed)
        else:
            tts.tts_to_file(text=text, file_path=output_file.name, language=language or TTS_LANGUAGE, speed=speed)

        return FileResponse(output_file.name, media_type="audio/wav", filename="speech.wav")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "model": "xtts-v2", "language": TTS_LANGUAGE}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
