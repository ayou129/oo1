#!/usr/bin/env python3
"""
XTTS v2 TTS Service Test Script for OO1 Robot
Tests text-to-speech functionality with voice cloning support
"""

import requests
import json
import sys
import time
import tempfile
from pathlib import Path

TTS_ENDPOINT = "http://localhost:8004/v1"

class TTSClient:
    def __init__(self, endpoint: str, timeout: int = 60):
        self.endpoint = endpoint
        self.timeout = timeout
        self.session = requests.Session()

    def health_check(self) -> bool:
        """Check if server is responding"""
        try:
            response = self.session.get(
                f"{self.endpoint.replace('/v1', '')}/health",
                timeout=self.timeout
            )
            return response.status_code == 200
        except Exception as e:
            print(f"Health check failed: {e}")
            return False

    def get_models(self) -> dict:
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

    def list_voices(self) -> dict:
        """List available voices"""
        try:
            response = self.session.get(
                f"{self.endpoint}/voices",
                timeout=self.timeout
            )
            return response.json()
        except Exception as e:
            print(f"Failed to list voices: {e}")
            return None

    def synthesize(self, text: str, voice: str = "default", language: str = "zh") -> bytes:
        """Synthesize speech"""
        try:
            response = self.session.post(
                f"{self.endpoint}/audio/speech",
                json={
                    "text": text,
                    "voice": voice,
                    "language": language,
                    "speed": 1.0,
                    "stream": False
                },
                timeout=self.timeout
            )

            if response.status_code == 200:
                return response.content
            else:
                print(f"Synthesis failed: {response.status_code}")
                print(response.text)
                return None
        except Exception as e:
            print(f"Synthesis error: {e}")
            return None

    def clone_voice(self, voice_name: str, voice_sample_path: str) -> dict:
        """Register a cloned voice"""
        try:
            response = self.session.post(
                f"{self.endpoint}/voices/clone",
                json={
                    "voice_name": voice_name,
                    "description": f"Cloned voice: {voice_name}"
                },
                timeout=self.timeout
            )

            return response.json()
        except Exception as e:
            print(f"Voice cloning failed: {e}")
            return None

def main():
    """Run TTS tests"""
    print("\n" + "="*60)
    print("OO1 Robot - XTTS v2 TTS Service Tests")
    print("="*60)

    client = TTSClient(TTS_ENDPOINT)

    # Wait for server to be ready
    print("\nWaiting for TTS server to be ready...")
    for i in range(30):
        if client.health_check():
            print("✓ TTS server is ready!")
            break

        print(f"  [{i+1}/30] Waiting...")
        time.sleep(1)
    else:
        print("✗ TTS server not responding after 30 seconds")
        return 1

    # Test 1: Get models
    print("\n[1/4] Getting available models...")
    models = client.get_models()
    if models:
        print(f"✓ Models: {json.dumps(models, indent=2)}")
    else:
        print("✗ Failed to get models")
        return 1

    # Test 2: List voices
    print("\n[2/4] Listing available voices...")
    voices = client.list_voices()
    if voices:
        print(f"✓ Available voices:")
        for voice in voices.get("data", []):
            print(f"  - {voice['id']}: {voice['name']}")
    else:
        print("✗ Failed to list voices")
        return 1

    # Test 3: Synthesize with default voice
    print("\n[3/4] Testing speech synthesis (Chinese)...")
    text = "你好世界，这是一个测试。"
    audio_data = client.synthesize(text, voice="default", language="zh")

    if audio_data:
        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(audio_data)
            temp_file = f.name

        print(f"✓ Synthesized audio: {len(audio_data)} bytes")
        print(f"  Saved to: {temp_file}")
    else:
        print("✗ Failed to synthesize")
        return 1

    # Test 4: Synthesize with English
    print("\n[4/4] Testing speech synthesis (English)...")
    text_en = "Hello, this is a test."
    audio_data_en = client.synthesize(text_en, voice="default", language="en")

    if audio_data_en:
        print(f"✓ Synthesized English audio: {len(audio_data_en)} bytes")
    else:
        print("✗ Failed to synthesize English")
        return 1

    # Summary
    print("\n" + "="*60)
    print("TTS Service Test Summary")
    print("="*60)
    print("✓ Health check: PASS")
    print("✓ Models listing: PASS")
    print("✓ Voice listing: PASS")
    print("✓ Chinese synthesis: PASS")
    print("✓ English synthesis: PASS")
    print("="*60)
    print("\nNote: Voice cloning requires audio samples in:")
    print("  /home/ay/Desktop/app/oo1/voices/")
    print("="*60)

    return 0

if __name__ == "__main__":
    sys.exit(main())
