#!/bin/bash

# SGLang Server Stop Script

LOG_DIR="/home/ay/Desktop/app/oo1/logs/sglang"

echo "Stopping SGLang servers..."

# Stop VL model
if [ -f "${LOG_DIR}/vl-8b.pid" ]; then
    pid=$(cat "${LOG_DIR}/vl-8b.pid")
    if kill -0 $pid 2>/dev/null; then
        kill $pid
        echo "Stopped VL-8B server (PID: $pid)"
    fi
    rm "${LOG_DIR}/vl-8b.pid"
fi

# Stop LLM model
if [ -f "${LOG_DIR}/llm-32b.pid" ]; then
    pid=$(cat "${LOG_DIR}/llm-32b.pid")
    if kill -0 $pid 2>/dev/null; then
        kill $pid
        echo "Stopped LLM-32B server (PID: $pid)"
    fi
    rm "${LOG_DIR}/llm-32b.pid"
fi

echo "All servers stopped."
