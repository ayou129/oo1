# vLLM LLM Service (大脑 Brain)

基于NVIDIA官方vLLM容器部署的Qwen3大语言模型服务，运行在NVIDIA Thor GPU上。

## 模型组织结构

模型需放在 `./models` 目录下，支持任意子目录结构。容器将 `./models` 挂载到 `/models`：

```
./models/
├── Qwen/
│   ├── Qwen3-32B-FP8/                    # MODEL_PATH: Qwen/Qwen3-32B-FP8
│   ├── Qwen3-VL-8B-Instruct-FP8/         # MODEL_PATH: Qwen/Qwen3-VL-8B-Instruct-FP8
│   └── ...
└── RedHatAI/
    ├── Qwen3-30B-A3B-quantized.w4a16/    # MODEL_PATH: RedHatAI/Qwen3-30B-A3B-quantized.w4a16
    └── ...
```

## 支持的模型格式

- Qwen3-32B-FP8 (默认)
- Qwen3-30B-A3B-quantized.w4a16
- Qwen3 AWQ量化模型
- Qwen3 GGUF格式模型
- 其他使用vLLM支持的模型

## 环境变量

- `MODEL_PATH`: 模型相对路径 (相对于./models)
  - 默认: `Qwen/Qwen3-32B-FP8`
  - 示例: `Qwen/Qwen3-32B-FP8` 或 `RedHatAI/Qwen3-30B-A3B-quantized.w4a16`

## API端点

基础URL: `http://127.0.0.1:8000/v1`

### 1. 获取模型列表 (获取模型ID)

**重要：** 先执行此命令查看容器识别的模型ID，然后在其他请求中使用该ID

```bash
curl http://127.0.0.1:8000/v1/models
```

响应示例：
```json
{
  "object": "list",
  "data": [
    {
      "id": "Qwen/Qwen3-32B-FP8",
      "object": "model",
      "created": 1700000000,
      "owned_by": "vllm"
    }
  ]
}
```

注：`id` 字段值即为后续API请求中应使用的 `model` 值

### 2. 聊天完成 (Chat Completions)

```bash
# 将 <MODEL_ID> 替换为从 /v1/models 获取的模型ID
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<MODEL_ID>",
    "messages": [
      {"role": "user", "content": "你好，告诉我你是谁"}
    ],
    "temperature": 0.7,
    "max_tokens": 1024,
    "top_p": 0.9
  }'
```

示例（假设模型ID为 `Qwen/Qwen3-32B-FP8`）：
```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B-FP8",
    "messages": [
      {"role": "user", "content": "你好，告诉我你是谁"}
    ],
    "temperature": 0.7,
    "max_tokens": 1024,
    "top_p": 0.9
  }'
```

响应示例：
```json
{
  "id": "cmpl-xxx",
  "object": "text_completion",
  "created": 1700000000,
  "model": "Qwen3-32B-FP8",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "你好！我是Qwen3-32B，一个大型语言模型..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 50,
    "total_tokens": 60
  }
}
```

### 3. 流式聊天完成 (Streaming Chat Completions)

```bash
# 将 <MODEL_ID> 替换为从 /v1/models 获取的模型ID
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<MODEL_ID>",
    "messages": [
      {"role": "system", "content": "你是一个有用的助手"},
      {"role": "user", "content": "写一个Hello World的Python程序"}
    ],
    "temperature": 0.8,
    "max_tokens": 512,
    "stream": true
  }'
```

### 4. 文本完成 (Text Completion)

```bash
# 将 <MODEL_ID> 替换为从 /v1/models 获取的模型ID
curl http://127.0.0.1:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<MODEL_ID>",
    "prompt": "Python中的装饰器是",
    "temperature": 0.7,
    "max_tokens": 256,
    "top_p": 0.9
  }'
```

## 常用参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `model` | - | 模型名称 (必需) |
| `messages` | - | 聊天消息列表 (Chat API) |
| `prompt` | - | 文本提示 (Completion API) |
| `temperature` | 1.0 | 生成多样性 (0-2), 越低越确定 |
| `max_tokens` | 512 | 最大生成token数 |
| `top_p` | 1.0 | 核采样 (0-1) |
| `top_k` | -1 | Top-K采样 |
| `stream` | false | 是否流式输出 |
| `frequency_penalty` | 0.0 | 频率惩罚 (-2 to 2) |
| `presence_penalty` | 0.0 | 存在惩罚 (-2 to 2) |

## Python示例

### 使用 OpenAI Python SDK

```python
from openai import OpenAI

client = OpenAI(
    api_key="token-abc123",
    base_url="http://127.0.0.1:8000/v1",
)

# 将 "Qwen/Qwen3-32B-FP8" 替换为实际的模型ID（从 /v1/models 获取）
response = client.chat.completions.create(
    model="Qwen/Qwen3-32B-FP8",
    messages=[
        {"role": "user", "content": "用Python实现快速排序算法"}
    ],
    temperature=0.7,
    max_tokens=1024,
)

print(response.choices[0].message.content)
```

### 流式响应

```python
from openai import OpenAI

client = OpenAI(
    api_key="token-abc123",
    base_url="http://127.0.0.1:8000/v1",
)

# 将 "Qwen/Qwen3-32B-FP8" 替换为实际的模型ID（从 /v1/models 获取）
stream = client.chat.completions.create(
    model="Qwen/Qwen3-32B-FP8",
    messages=[
        {"role": "user", "content": "描述一下人工智能的发展前景"}
    ],
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end='', flush=True)
```

## 故障排除

### 模型加载缓慢

- 首次加载模型可能需要2-5分钟
- 查看容器日志: `docker logs oo1_llm`

### 显存不足 (OOM)

- 减少`--max-num-seqs`参数
- 使用更小的模型或更多量化
- 增加`--swap-space`值

### 推理速度慢

- 确认GPU利用率: `nvidia-smi`
- 检查`--gpu-memory-utilization`设置 (通常0.80较优)
- 验证模型量化方式是否正确

## 相关文件

- `start_llm.sh` - 启动脚本
- `README.md` - 本文件

## 更多信息

- [vLLM 官方文档](https://docs.vllm.ai/)
- [Qwen3 模型卡片](https://huggingface.co/Qwen/Qwen3-32B-FP8)
- [OpenAI API 兼容性](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html)
