#!/bin/bash

# vLLM LLM Service Startup Script
# Serves Qwen models with vLLM on NVIDIA Thor

MODEL_PATH="${MODEL_PATH:-Qwen/Qwen3-32B-FP8}"

# Determine quantization based on model name/path
if [[ "$MODEL_PATH" == *"FP8"* ]]; then
  QUANTIZATION="fp8"
elif [[ "$MODEL_PATH" == *"w4a16"* ]] || [[ "$MODEL_PATH" == *"A3B"* ]]; then
  QUANTIZATION="compressed-tensors"
elif [[ "$MODEL_PATH" == *"AWQ"* ]]; then
  QUANTIZATION="awq"
elif [[ "$MODEL_PATH" == *"GGUF"* ]]; then
  QUANTIZATION="gguf"
else
  QUANTIZATION="auto"
fi

echo "================================"
echo "vLLM LLM Service (Brain)"
echo "================================"
echo "模型路径: $MODEL_PATH"
echo "量化方式: $QUANTIZATION"
echo ""

echo "清空系统缓存中..."
sync && echo 3 | tee /proc/sys/vm/drop_caches > /dev/null
echo ""

export VLLM_DISABLED_KERNELS=MacheteLinearKernel
export VLLM_ATTENTION_BACKEND=FLASH_ATTN

echo "启动vLLM服务..."
echo ""

vllm serve "/models/$MODEL_PATH" \
  --host 0.0.0.0 \
  --port 8000 \
  --swap-space 16 \
  --quantization "$QUANTIZATION" \
  --max-seq-len 3000 \
  --max-model-len 3000 \
  --tensor-parallel-size 1 \
  --max-num-seqs 1024 \
  --dtype auto \
  --gpu-memory-utilization 0.80 \
  --trust-remote-code
