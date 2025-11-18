#!/bin/bash

# OO1 Robot AI Stack - Stop Script

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "OO1 Robot AI Stack - Stopping"
echo "=========================================="
echo ""

cd "${PROJECT_DIR}"

echo "Stopping all services..."
docker-compose down

echo ""
echo "=========================================="
echo "All services stopped."
echo "=========================================="
echo ""
echo "To start again, run:"
echo "  bash start.sh"
echo ""
