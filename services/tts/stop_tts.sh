#!/bin/bash

# XTTS TTS Service Stop Script

LOG_DIR="/home/ay/Desktop/app/oo1/logs/tts"

echo "Stopping XTTS TTS server..."

if [ -f "${LOG_DIR}/tts.pid" ]; then
    pid=$(cat "${LOG_DIR}/tts.pid")
    if kill -0 $pid 2>/dev/null; then
        kill $pid
        echo "Stopped TTS server (PID: $pid)"
    fi
    rm "${LOG_DIR}/tts.pid"
fi

echo "TTS server stopped."
