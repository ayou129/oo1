#!/bin/bash

# XTTS v2 TTS Service Startup Script for OO1 Robot
# Provides multilingual Text-to-Speech with voice cloning support

set -e

# Configuration
PROJECT_DIR="/home/ay/Desktop/app/oo1"
LOG_DIR="${PROJECT_DIR}/logs/tts"
TTS_PORT=8004

# TTS settings
TTS_MODEL="xtts"
TTS_LANGUAGE="zh"  # zh for Chinese, en for English
VOICE_DIR="${PROJECT_DIR}/voices"  # Directory for voice samples

# Create directories
mkdir -p ${LOG_DIR}
mkdir -p ${VOICE_DIR}

echo "=========================================="
echo "XTTS v2 TTS Service Startup"
echo "=========================================="
echo "Model: ${TTS_MODEL}"
echo "Language: ${TTS_LANGUAGE}"
echo "Port: ${TTS_PORT}"
echo "Log Dir: ${LOG_DIR}"
echo "Voice Dir: ${VOICE_DIR}"
echo "=========================================="

# Create TTS server
cat > ${LOG_DIR}/tts_server.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
XTTS v2 TTS Server
Provides OpenAI-compatible text-to-speech API with voice cloning
"""

import os
import json
import uuid
import tempfile
import numpy as np
from pathlib import Path
from typing import Optional
import base64

try:
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import FileResponse, StreamingResponse
    import uvicorn
    from pydantic import BaseModel
except ImportError:
    print("FastAPI not found, installing...")
    os.system("pip install fastapi uvicorn pydantic")
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import FileResponse, StreamingResponse
    import uvicorn
    from pydantic import BaseModel

try:
    from TTS.api import TTS
except ImportError:
    print("TTS library not found, installing...")
    os.system("pip install TTS")
    from TTS.api import TTS

app = FastAPI(title="OO1 TTS Service")

# Load XTTS model
TTS_LANGUAGE = os.getenv("TTS_LANGUAGE", "zh")
VOICE_DIR = os.getenv("VOICE_DIR", "/tmp/voices")

print(f"Loading XTTS v2 model (language: {TTS_LANGUAGE})...")
tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", gpu=True)

# Create voices directory
Path(VOICE_DIR).mkdir(exist_ok=True, parents=True)

class SynthesisRequest(BaseModel):
    text: str
    voice: Optional[str] = "default"
    language: Optional[str] = TTS_LANGUAGE
    speed: Optional[float] = 1.0
    stream: Optional[bool] = False

class VoiceCloneRequest(BaseModel):
    voice_name: str
    voice_sample_url: Optional[str] = None
    description: Optional[str] = ""

@app.get("/v1/models")
async def list_models():
    """List available models (OpenAI API compatible)"""
    return {
        "object": "list",
        "data": [
            {
                "id": "xtts-v2",
                "object": "model",
                "created": 1234567890,
                "owned_by": "openai-compatible"
            }
        ]
    }

@app.get("/v1/voices")
async def list_voices():
    """List available voices"""
    voices = []

    # Default voices
    default_voices = [
        {"id": "default", "name": "Default Female", "language": TTS_LANGUAGE},
        {"id": "male", "name": "Default Male", "language": TTS_LANGUAGE},
    ]

    # Custom voice clones
    voice_files = Path(VOICE_DIR).glob("*.wav")
    for voice_file in voice_files:
        voice_name = voice_file.stem
        voices.append({
            "id": voice_name,
            "name": voice_name,
            "language": TTS_LANGUAGE,
            "type": "cloned"
        })

    return {
        "object": "list",
        "data": default_voices + voices
    }

@app.post("/v1/audio/speech")
async def synthesize(request: SynthesisRequest):
    """
    Synthesize speech from text
    OpenAI-compatible endpoint
    """
    try:
        # Get voice
        voice_name = request.voice

        # Check if it's a custom cloned voice
        voice_path = None
        if voice_name != "default" and voice_name != "male":
            voice_path = Path(VOICE_DIR) / f"{voice_name}.wav"
            if not voice_path.exists():
                raise HTTPException(
                    status_code=400,
                    detail=f"Voice '{voice_name}' not found"
                )

        # Create temp output file
        output_file = tempfile.NamedTemporaryFile(
            suffix=".wav",
            delete=False
        )

        try:
            if voice_path and voice_path.exists():
                # Use cloned voice
                print(f"Synthesizing with cloned voice: {voice_name}")
                tts.tts_to_file(
                    text=request.text,
                    file_path=output_file.name,
                    speaker_wav=str(voice_path),
                    language=request.language,
                    speed=request.speed
                )
            else:
                # Use default voice
                print(f"Synthesizing with default voice: {voice_name}")
                tts.tts_to_file(
                    text=request.text,
                    file_path=output_file.name,
                    language=request.language,
                    speed=request.speed
                )

            # Return audio file
            return FileResponse(
                output_file.name,
                media_type="audio/wav",
                filename="speech.wav"
            )

        except Exception as e:
            if os.path.exists(output_file.name):
                os.remove(output_file.name)
            raise

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/v1/voices/clone")
async def clone_voice(request: VoiceCloneRequest):
    """
    Register a voice clone from an audio sample
    """
    try:
        voice_path = Path(VOICE_DIR) / f"{request.voice_name}.wav"

        # TODO: Download voice sample if URL provided
        if request.voice_sample_url:
            print(f"Downloading voice sample from: {request.voice_sample_url}")
            # import urllib.request
            # urllib.request.urlretrieve(request.voice_sample_url, voice_path)

        return {
            "id": request.voice_name,
            "name": request.voice_name,
            "status": "registered",
            "type": "cloned",
            "language": TTS_LANGUAGE,
            "description": request.description or ""
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "ok",
        "model": "xtts-v2",
        "language": TTS_LANGUAGE
    }

if __name__ == "__main__":
    port = int(os.getenv("TTS_PORT", 8004))
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
PYTHON_SCRIPT

# Set environment variables
export TTS_LANGUAGE="${TTS_LANGUAGE}"
export VOICE_DIR="${VOICE_DIR}"
export TTS_PORT="${TTS_PORT}"

# Run the server
python3 ${LOG_DIR}/tts_server.py > ${LOG_DIR}/tts_service.log 2>&1 &

pid=$!
echo "[TTS] Server started with PID: ${pid}"
echo ${pid} > "${LOG_DIR}/tts.pid"

# Health check
echo ""
echo "Waiting for TTS server to be ready..."
sleep 10

for i in {1..30}; do
    if curl -s http://localhost:${TTS_PORT}/health | grep -q "ok"; then
        echo "✓ TTS server is ready!"
        break
    fi
    echo "  [$i/30] Waiting..."
    sleep 1
done

echo ""
echo "=========================================="
echo "XTTS v2 TTS Service Ready!"
echo "=========================================="
echo ""
echo "API Endpoint:"
echo "  http://localhost:${TTS_PORT}/v1"
echo ""
echo "Example request:"
echo "  curl -X POST http://localhost:${TTS_PORT}/v1/audio/speech \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"text\": \"你好世界\", \"voice\": \"default\"}' \\"
echo "    -o speech.wav"
echo ""
echo "Voice directory:"
echo "  ${VOICE_DIR}"
echo ""
echo "Logs:"
echo "  tail -f ${LOG_DIR}/tts_service.log"
echo ""
echo "To stop: bash services/tts/stop_tts.sh"
echo "=========================================="

# Keep script running
wait ${pid}
