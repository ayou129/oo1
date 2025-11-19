#!/bin/bash

# vLLM Model Warmup Script
# Preheats GPU/memory/cache with 50 random prompts before benchmark testing

MODEL_PATH="${MODEL_PATH:-Qwen/Qwen3-32B-FP8}"

echo "================================"
echo "vLLM Model Warmup"
echo "================================"
echo "模型: $MODEL_PATH"
echo "方法: 50个随机提示预热 (2048 input tokens, 128 output tokens)"
echo ""

# Wait for vLLM server to be ready
echo "等待vLLM服务启动..."
for i in {1..30}; do
  if curl -s http://localhost:8000/v1/models > /dev/null 2>&1; then
    echo "✓ vLLM服务已就绪"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "✗ vLLM服务启动超时"
    exit 1
  fi
  sleep 2
done

echo ""
echo "开始预热模型（这可能需要2-5分钟）..."
echo ""

# Run warmup benchmark
python3 /opt/vllm/vllm-src/benchmarks/benchmark_serving.py \
  --model "$MODEL_PATH" \
  --dataset-name random \
  --num-prompts 50 \
  --random-input-len 2048 \
  --random-output-len 128 \
  --percentile-metrics ttft,tpot,itl,e2el \
  --max-concurrency 1

WARMUP_STATUS=$?

echo ""
if [ $WARMUP_STATUS -eq 0 ]; then
  echo "✓ 预热完成，模型已准备好接收请求"
else
  echo "✗ 预热失败，但vLLM服务仍在运行"
fi

echo ""
