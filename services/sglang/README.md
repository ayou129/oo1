```bash
curl http://127.0.0.1:8000/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
    "model": "/models/Qwen/Qwen3-8B-AWQ",
    "messages": [
    {"role": "user", "content": "你好"}
    ],
    "max_tokens": 512,
    "enable_thinking": false
}'
```