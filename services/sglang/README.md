# SGLang Service for OO1 Robot

Two-model deployment using SGLang inference engine:
- **VL-8B (Eyes)**: Qwen3-VL-8B-Instruct-FP8 - Vision understanding
- **32B (Brain)**: Qwen3-32B-FP8 - Decision making & instruction generation

## Files

- `start_sglang.sh` - Start both servers
- `stop_sglang.sh` - Stop both servers
- `sglang_config.yaml` - Configuration file
- `test_sglang.py` - Test script
- `README.md` - This file

## Quick Start

### 1. Prerequisites

Make sure you have:
- SGLang container running (from jetson-containers)
- Models downloaded to `/home/ay/Desktop/app/oo1/models/Qwen/`

### 2. Start Servers

```bash
cd /home/ay/Desktop/app/oo1
bash services/sglang/start_sglang.sh
```

Servers will start on:
- VL-8B: `http://localhost:8001/v1`
- 32B: `http://localhost:8002/v1`

### 3. Test Servers

In another terminal:

```bash
cd /home/ay/Desktop/app/oo1
python3 services/sglang/test_sglang.py
```

Expected output:
```
✓ Both servers are ready!
✓ VL-8B Model: PASS
✓ 32B Model: PASS
```

### 4. Stop Servers

```bash
bash services/sglang/stop_sglang.sh
```

## API Usage

### Vision Model (Port 8001)

```bash
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "描述这张图片"}
    ],
    "max_tokens": 512,
    "temperature": 0.3
  }'
```

### Brain Model (Port 8002)

```bash
curl http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "生成 ROS2 移动命令，距离1米"}
    ],
    "max_tokens": 1024,
    "temperature": 0.7
  }'
```

## Python Client Example

```python
import requests

# Vision model
vl_response = requests.post(
    "http://localhost:8001/v1/chat/completions",
    json={
        "messages": [{"role": "user", "content": "你看到了什么?"}],
        "max_tokens": 512
    }
)
print(vl_response.json())

# Brain model
llm_response = requests.post(
    "http://localhost:8002/v1/chat/completions",
    json={
        "messages": [{"role": "user", "content": "生成 JSON 指令"}],
        "max_tokens": 1024
    }
)
print(llm_response.json())
```

## Logs

Check server logs:

```bash
# VL-8B logs
tail -f /home/ay/Desktop/app/oo1/logs/sglang/vl-8b.log

# 32B logs
tail -f /home/ay/Desktop/app/oo1/logs/sglang/llm-32b.log
```

## Configuration

Edit `sglang_config.yaml` to adjust:
- `mem_fraction_static`: GPU memory usage (0.8-0.9)
- `max_running_requests`: Concurrent request limit
- `temperature`: Response randomness
- `max_tokens`: Maximum output length

## Troubleshooting

### Servers not starting
```bash
# Check if ports are in use
lsof -i :8001
lsof -i :8002

# Kill existing processes if needed
kill -9 <PID>
```

### Out of memory
- Reduce `mem_fraction_static` in config
- Reduce `max_running_requests`
- Stop other services

### Slow responses
- Check GPU utilization: `nvidia-smi`
- Reduce `max_tokens`
- Enable `enable_flashinfer: true` (already enabled)

## Integration with ROS2

See `../bridge/` directory for ROS2 integration examples.
