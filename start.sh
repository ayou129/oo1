#!/bin/bash

# OO1 Robot AI Stack - Quick Start Script

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "OO1 Robot AI Stack - Startup"
echo "=========================================="
echo "Project directory: ${PROJECT_DIR}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose."
    exit 1
fi

echo "✓ Docker and Docker Compose found"

# Check models
if [ ! -d "${PROJECT_DIR}/models/Qwen/Qwen3-VL-8B-Instruct-FP8" ]; then
    echo "❌ Model not found: models/Qwen/Qwen3-VL-8B-Instruct-FP8"
    echo "   Please download the model to: ${PROJECT_DIR}/models/Qwen/"
    exit 1
fi

if [ ! -d "${PROJECT_DIR}/models/Qwen/Qwen3-32B-FP8" ]; then
    echo "❌ Model not found: models/Qwen/Qwen3-32B-FP8"
    echo "   Please download the model to: ${PROJECT_DIR}/models/Qwen/"
    exit 1
fi

echo "✓ Models found"
echo ""

# Check GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  nvidia-smi not found. GPU may not be available."
else
    echo "GPU Status:"
    nvidia-smi -L | head -5
    echo ""
fi

# Start services
echo "Starting all services..."
cd "${PROJECT_DIR}"

docker-compose up -d

echo ""
echo "=========================================="
echo "Services started successfully!"
echo "=========================================="
echo ""
echo "Service Status:"
docker-compose ps

echo ""
echo "API Endpoints:"
echo "  SGLang VL-8B:      http://localhost:8001/v1"
echo "  SGLang 32B:        http://localhost:8002/v1"
echo "  Faster-Whisper:    http://localhost:8003/v1"
echo "  XTTS TTS:          http://localhost:8004/v1"
echo ""
echo "Useful commands:"
echo "  View logs:         docker-compose logs -f"
echo "  Stop services:     docker-compose down"
echo "  Restart service:   docker-compose restart <service>"
echo "  Enter container:   docker-compose exec <service> bash"
echo ""
echo "For more info, see: DEPLOYMENT.md"
echo "=========================================="
