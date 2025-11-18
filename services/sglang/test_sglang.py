#!/usr/bin/env python3
"""
SGLang Server Test Script for OO1 Robot
Tests both VL-8B and 32B models
"""

import requests
import json
import sys
import time
from typing import Dict, Any

# API endpoints
VL_ENDPOINT = "http://localhost:8001/v1"
LLM_ENDPOINT = "http://localhost:8002/v1"

class SGLangClient:
    def __init__(self, endpoint: str, timeout: int = 30):
        self.endpoint = endpoint
        self.timeout = timeout
        self.session = requests.Session()

    def health_check(self) -> bool:
        """Check if server is responding"""
        try:
            response = self.session.get(
                f"{self.endpoint}/models",
                timeout=self.timeout
            )
            return response.status_code == 200
        except Exception as e:
            print(f"Health check failed: {e}")
            return False

    def get_models(self) -> Dict[str, Any]:
        """Get list of available models"""
        try:
            response = self.session.get(
                f"{self.endpoint}/models",
                timeout=self.timeout
            )
            return response.json()
        except Exception as e:
            print(f"Failed to get models: {e}")
            return None

    def text_completion(self, prompt: str, max_tokens: int = 512) -> str:
        """Generate text completion"""
        try:
            response = self.session.post(
                f"{self.endpoint}/completions",
                json={
                    "prompt": prompt,
                    "max_tokens": max_tokens,
                    "temperature": 0.7,
                    "top_p": 0.9,
                },
                timeout=self.timeout
            )
            result = response.json()
            if "choices" in result and len(result["choices"]) > 0:
                return result["choices"][0].get("text", "")
            return "No response"
        except Exception as e:
            print(f"Completion failed: {e}")
            return None

    def chat_completion(self, messages: list, max_tokens: int = 1024) -> str:
        """Generate chat completion"""
        try:
            response = self.session.post(
                f"{self.endpoint}/chat/completions",
                json={
                    "messages": messages,
                    "max_tokens": max_tokens,
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "stream": False,
                },
                timeout=self.timeout
            )
            result = response.json()
            if "choices" in result and len(result["choices"]) > 0:
                content = result["choices"][0].get("message", {}).get("content", "")
                return content
            return "No response"
        except Exception as e:
            print(f"Chat completion failed: {e}")
            return None

def test_vl_model():
    """Test VL-8B vision model"""
    print("\n" + "="*60)
    print("Testing VL-8B Vision Model")
    print("="*60)

    client = SGLangClient(VL_ENDPOINT)

    # Health check
    print("\n[1/3] Health check...")
    if not client.health_check():
        print("✗ VL server not responding")
        return False
    print("✓ VL server is healthy")

    # Get models
    print("\n[2/3] Getting available models...")
    models = client.get_models()
    if models:
        print(f"✓ Models: {json.dumps(models, indent=2)}")

    # Test chat completion
    print("\n[3/3] Testing chat completion...")
    messages = [
        {
            "role": "user",
            "content": "你是一个有帮助的助手。请简短地介绍一下自己。"
        }
    ]
    response = client.chat_completion(messages)
    if response:
        print(f"✓ Response: {response[:200]}...")
        return True
    return False

def test_llm_model():
    """Test 32B brain model"""
    print("\n" + "="*60)
    print("Testing 32B Brain Model")
    print("="*60)

    client = SGLangClient(LLM_ENDPOINT)

    # Health check
    print("\n[1/3] Health check...")
    if not client.health_check():
        print("✗ LLM server not responding")
        return False
    print("✓ LLM server is healthy")

    # Get models
    print("\n[2/3] Getting available models...")
    models = client.get_models()
    if models:
        print(f"✓ Models: {json.dumps(models, indent=2)}")

    # Test chat completion with JSON output
    print("\n[3/3] Testing ROS2 JSON instruction generation...")
    messages = [
        {
            "role": "user",
            "content": '生成一个 ROS2 机器人控制命令，让机器人向前移动1米。返回 JSON 格式: {"action": "move", "distance": 1, "direction": "forward"}'
        }
    ]
    response = client.chat_completion(messages)
    if response:
        print(f"✓ Response: {response}")
        # Try to parse as JSON
        try:
            json_data = json.loads(response)
            print(f"✓ Valid JSON: {json.dumps(json_data, indent=2, ensure_ascii=False)}")
        except json.JSONDecodeError:
            print("⚠ Response is not valid JSON (might need post-processing)")
        return True
    return False

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("OO1 Robot - SGLang Server Tests")
    print("="*60)

    # Wait for servers to be ready
    print("\nWaiting for servers to be ready...")
    for i in range(30):
        vl_ready = SGLangClient(VL_ENDPOINT).health_check()
        llm_ready = SGLangClient(LLM_ENDPOINT).health_check()

        if vl_ready and llm_ready:
            print("✓ Both servers are ready!")
            break

        print(f"  [{i+1}/30] VL: {'✓' if vl_ready else '✗'}, LLM: {'✓' if llm_ready else '✗'}")
        time.sleep(1)

    # Run tests
    vl_ok = test_vl_model()
    llm_ok = test_llm_model()

    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    print(f"VL-8B Model:  {'✓ PASS' if vl_ok else '✗ FAIL'}")
    print(f"32B Model:    {'✓ PASS' if llm_ok else '✗ FAIL'}")
    print("="*60)

    return 0 if (vl_ok and llm_ok) else 1

if __name__ == "__main__":
    sys.exit(main())
