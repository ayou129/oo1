curl http://127.0.0.1:8000/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
    "messages": [
    {"role": "user", "content": "你叫什么名字"}
    ],
    "max_tokens": 512,
    "chat_template_kwargs": {
    "enable_thinking": false
    }
}'