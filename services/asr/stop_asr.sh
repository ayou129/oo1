#!/bin/bash

# Faster-Whisper ASR Service Stop Script

LOG_DIR="/home/ay/Desktop/app/oo1/logs/asr"

echo "Stopping Faster-Whisper ASR server..."

if [ -f "${LOG_DIR}/asr.pid" ]; then
    pid=$(cat "${LOG_DIR}/asr.pid")
    if kill -0 $pid 2>/dev/null; then
        kill $pid
        echo "Stopped ASR server (PID: $pid)"
    fi
    rm "${LOG_DIR}/asr.pid"
fi

echo "ASR server stopped."
