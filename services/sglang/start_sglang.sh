#!/bin/bash

# SGLang Server Startup Script for OO1 Robot
# Deploys two Qwen3 FP8 models as separate API endpoints

set -e

# Configuration
PROJECT_DIR="/home/ay/Desktop/app/oo1"
MODELS_DIR="${PROJECT_DIR}/models/Qwen"
LOG_DIR="${PROJECT_DIR}/logs/sglang"

# Model paths
VL_MODEL_PATH="${MODELS_DIR}/Qwen3-VL-8B-Instruct-FP8"
LLM_MODEL_PATH="${MODELS_DIR}/Qwen3-32B-FP8"

# Server ports
VL_PORT=8001
LLM_PORT=8002

# GPU configuration
CUDA_VISIBLE_DEVICES="0"

# Create log directory
mkdir -p ${LOG_DIR}

echo "=========================================="
echo "SGLang Server Startup"
echo "=========================================="
echo "VL Model: ${VL_MODEL_PATH}"
echo "LLM Model: ${LLM_MODEL_PATH}"
echo "VL Port: ${VL_PORT}"
echo "LLM Port: ${LLM_PORT}"
echo "Log Dir: ${LOG_DIR}"
echo "=========================================="

# Function to start server
start_server() {
    local model_path=$1
    local port=$2
    local model_name=$3
    local log_file="${LOG_DIR}/${model_name}.log"

    echo "[${model_name}] Starting SGLang server on port ${port}..."

    python3 -m sglang.launch_server \
        --model-path "${model_path}" \
        --port ${port} \
        --mem-fraction-static 0.8 \
        --tp 1 \
        --enable-flashinfer \
        --enable-dp-attention \
        --quantization fp8 \
        --log-level info \
        > ${log_file} 2>&1 &

    local pid=$!
    echo "[${model_name}] Server started with PID: ${pid}"
    echo ${pid} > "${LOG_DIR}/${model_name}.pid"
}

# Start VL model server
start_server "${VL_MODEL_PATH}" "${VL_PORT}" "vl-8b"

# Wait a bit for VL server to initialize
sleep 5

# Start LLM model server
start_server "${LLM_MODEL_PATH}" "${LLM_PORT}" "llm-32b"

# Wait for both servers to be ready
echo ""
echo "Waiting for servers to be ready..."
sleep 10

# Health check
echo ""
echo "=========================================="
echo "Health Check"
echo "=========================================="

check_server() {
    local port=$1
    local model_name=$2

    echo -n "[${model_name}] "
    if curl -s http://localhost:${port}/v1/models | grep -q "id"; then
        echo "✓ Server is ready"
        return 0
    else
        echo "✗ Server not responding yet"
        return 1
    fi
}

# Try health check (with retries)
for i in {1..5}; do
    echo "Attempt $i..."
    check_server ${VL_PORT} "VL-8B" || true
    check_server ${LLM_PORT} "LLM-32B" || true
    sleep 2
done

echo ""
echo "=========================================="
echo "SGLang Servers Started Successfully!"
echo "=========================================="
echo ""
echo "API Endpoints:"
echo "  VL-8B (Vision):    http://localhost:${VL_PORT}/v1"
echo "  LLM-32B (Brain):   http://localhost:${LLM_PORT}/v1"
echo ""
echo "Example requests:"
echo "  curl http://localhost:${VL_PORT}/v1/models"
echo "  curl http://localhost:${LLM_PORT}/v1/models"
echo ""
echo "Logs:"
echo "  tail -f ${LOG_DIR}/vl-8b.log"
echo "  tail -f ${LOG_DIR}/llm-32b.log"
echo ""
echo "To stop servers, run: bash services/sglang/stop_sglang.sh"
echo "=========================================="

# Keep script running
wait
