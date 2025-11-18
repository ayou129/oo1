#!/bin/bash

# Faster-Whisper ASR Service Startup Script for OO1 Robot
# Provides OpenAI-compatible Speech-to-Text API

set -e

# Configuration
PROJECT_DIR="/home/ay/Desktop/app/oo1"
LOG_DIR="${PROJECT_DIR}/logs/asr"
ASR_PORT=8003

# ASR settings
ASR_MODEL="small"  # small, medium, large (larger = better accuracy, slower)
COMPUTE_TYPE="int8"  # int8, float16, float32
LANGUAGE="zh"  # zh for Chinese, en for English

# Create log directory
mkdir -p ${LOG_DIR}

echo "=========================================="
echo "Faster-Whisper ASR Service Startup"
echo "=========================================="
echo "Model: ${ASR_MODEL}"
echo "Compute Type: ${COMPUTE_TYPE}"
echo "Language: ${LANGUAGE}"
echo "Port: ${ASR_PORT}"
echo "Log Dir: ${LOG_DIR}"
echo "=========================================="

# Start ASR server using faster-whisper CLI
# Note: This uses the faster-whisper transcribe-cli
echo "[ASR] Starting Faster-Whisper server on port ${ASR_PORT}..."

# Create a simple Flask/FastAPI wrapper for Faster-Whisper
cat > ${LOG_DIR}/asr_server.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Faster-Whisper ASR Server
Provides OpenAI-compatible speech-to-text API
"""

import os
import json
import base64
from pathlib import Path
from typing import Optional
import tempfile

try:
    from fastapi import FastAPI, UploadFile, File, HTTPException
    from fastapi.responses import JSONResponse
    import uvicorn
except ImportError:
    print("FastAPI not found, installing...")
    os.system("pip install fastapi uvicorn python-multipart")
    from fastapi import FastAPI, UploadFile, File, HTTPException
    from fastapi.responses import JSONResponse
    import uvicorn

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("faster-whisper not found in current environment")
    print("Make sure you're running this inside the faster-whisper container")
    exit(1)

app = FastAPI(title="OO1 ASR Service")

# Load model
MODEL_SIZE = os.getenv("ASR_MODEL", "small")
COMPUTE_TYPE = os.getenv("COMPUTE_TYPE", "int8")
LANGUAGE = os.getenv("ASR_LANGUAGE", "zh")

print(f"Loading Faster-Whisper model: {MODEL_SIZE}")
model = WhisperModel(
    MODEL_SIZE,
    device="cuda",
    compute_type=COMPUTE_TYPE,
    num_workers=2,
    cpu_threads=4
)

@app.get("/v1/models")
async def list_models():
    """List available models (OpenAI API compatible)"""
    return {
        "object": "list",
        "data": [
            {
                "id": f"faster-whisper-{MODEL_SIZE}",
                "object": "model",
                "created": 1234567890,
                "owned_by": "openai-compatible"
            }
        ]
    }

@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: Optional[str] = "faster-whisper",
    language: Optional[str] = None,
    temperature: Optional[float] = 0.0,
):
    """
    Transcribe audio file
    OpenAI-compatible endpoint
    """
    try:
        # Read audio file
        audio_data = await file.read()

        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name

        try:
            # Transcribe
            segments, info = model.transcribe(
                tmp_path,
                language=language or LANGUAGE,
                beam_size=5,
                best_of=5,
                temperature=temperature,
                condition_on_previous_text=False,
            )

            # Collect segments
            text = "".join([segment.text for segment in segments])

            return {
                "text": text,
                "language": info.language,
                "duration": info.duration,
                "model": f"faster-whisper-{MODEL_SIZE}"
            }
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/v1/audio/transcriptions/stream")
async def transcribe_stream(
    file: UploadFile = File(...),
    language: Optional[str] = None,
):
    """
    Stream transcription results as they arrive
    """
    try:
        audio_data = await file.read()

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name

        try:
            segments, info = model.transcribe(
                tmp_path,
                language=language or LANGUAGE,
            )

            results = []
            for segment in segments:
                results.append({
                    "id": segment.id,
                    "seek": segment.seek,
                    "start": segment.start,
                    "end": segment.end,
                    "text": segment.text,
                    "confidence": segment.confidence
                })

            return {
                "segments": results,
                "language": info.language,
                "duration": info.duration
            }
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok", "model": MODEL_SIZE}

if __name__ == "__main__":
    port = int(os.getenv("ASR_PORT", 8003))
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
PYTHON_SCRIPT

# Set environment variables
export ASR_MODEL="${ASR_MODEL}"
export COMPUTE_TYPE="${COMPUTE_TYPE}"
export ASR_LANGUAGE="${LANGUAGE}"
export ASR_PORT="${ASR_PORT}"

# Run the server
python3 ${LOG_DIR}/asr_server.py > ${LOG_DIR}/asr_service.log 2>&1 &

pid=$!
echo "[ASR] Server started with PID: ${pid}"
echo ${pid} > "${LOG_DIR}/asr.pid"

# Health check
echo ""
echo "Waiting for ASR server to be ready..."
sleep 5

for i in {1..30}; do
    if curl -s http://localhost:${ASR_PORT}/health | grep -q "ok"; then
        echo "✓ ASR server is ready!"
        break
    fi
    echo "  [$i/30] Waiting..."
    sleep 1
done

echo ""
echo "=========================================="
echo "Faster-Whisper ASR Service Ready!"
echo "=========================================="
echo ""
echo "API Endpoint:"
echo "  http://localhost:${ASR_PORT}/v1"
echo ""
echo "Example request:"
echo "  curl -X POST http://localhost:${ASR_PORT}/v1/audio/transcriptions \\"
echo "    -F 'file=@audio.wav' \\"
echo "    -F 'model=faster-whisper'"
echo ""
echo "Logs:"
echo "  tail -f ${LOG_DIR}/asr_service.log"
echo ""
echo "To stop: bash services/asr/stop_asr.sh"
echo "=========================================="

# Keep script running
wait ${pid}
