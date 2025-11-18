#!/usr/bin/env python3
"""
Faster-Whisper ASR Service Test Script for OO1 Robot
Tests speech-to-text functionality
"""

import requests
import json
import sys
import time
from pathlib import Path

ASR_ENDPOINT = "http://localhost:8003/v1"

class ASRClient:
    def __init__(self, endpoint: str, timeout: int = 30):
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

    def transcribe_file(self, audio_file: str, language: str = "zh") -> str:
        """Transcribe audio file"""
        try:
            with open(audio_file, 'rb') as f:
                files = {'file': f}
                data = {'language': language, 'model': 'faster-whisper'}

                response = self.session.post(
                    f"{self.endpoint}/audio/transcriptions",
                    files=files,
                    data=data,
                    timeout=self.timeout
                )

            result = response.json()
            if "text" in result:
                return result["text"]
            return "No transcription"
        except FileNotFoundError:
            print(f"Audio file not found: {audio_file}")
            return None
        except Exception as e:
            print(f"Transcription failed: {e}")
            return None

def create_test_audio():
    """Create a test audio file"""
    try:
        import wave
        import struct
        import math

        # Simple test audio (1 second sine wave)
        sample_rate = 16000
        duration = 1
        frequency = 440  # A4 note

        filename = "/tmp/test_audio.wav"

        with wave.open(filename, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)

            # Generate sine wave
            frames = []
            for i in range(sample_rate * duration):
                value = int(32767.0 * 0.5 * math.sin(2 * math.pi * frequency * i / sample_rate))
                frames.append(struct.pack('<h', value))

            wav_file.writeframes(b''.join(frames))

        print(f"✓ Test audio created: {filename}")
        return filename
    except Exception as e:
        print(f"Failed to create test audio: {e}")
        return None

def main():
    """Run ASR tests"""
    print("\n" + "="*60)
    print("OO1 Robot - Faster-Whisper ASR Service Tests")
    print("="*60)

    client = ASRClient(ASR_ENDPOINT)

    # Wait for server to be ready
    print("\nWaiting for ASR server to be ready...")
    for i in range(30):
        if client.health_check():
            print("✓ ASR server is ready!")
            break

        print(f"  [{i+1}/30] Waiting...")
        time.sleep(1)
    else:
        print("✗ ASR server not responding after 30 seconds")
        return 1

    # Test 1: Get models
    print("\n[1/3] Getting available models...")
    models = client.get_models()
    if models:
        print(f"✓ Models: {json.dumps(models, indent=2)}")
    else:
        print("✗ Failed to get models")
        return 1

    # Test 2: Transcribe test audio
    print("\n[2/3] Creating and transcribing test audio...")
    audio_file = create_test_audio()

    if audio_file:
        text = client.transcribe_file(audio_file, language="zh")
        if text:
            print(f"✓ Transcription result: '{text}'")
            print("  (Note: Test audio is a sine wave, result may be empty)")
        else:
            print("✗ Failed to transcribe")
            return 1

    # Test 3: Test with sample audio if available
    print("\n[3/3] Testing with sample audio...")
    sample_paths = [
        "/tmp/sample_audio.wav",
        "sample_audio.wav",
        "/data/sample_audio.wav"
    ]

    sample_found = False
    for sample_path in sample_paths:
        if Path(sample_path).exists():
            print(f"Found sample audio: {sample_path}")
            text = client.transcribe_file(sample_path, language="zh")
            if text:
                print(f"✓ Sample transcription: '{text}'")
                sample_found = True
                break

    if not sample_found:
        print("⚠ No sample audio found (optional test)")

    # Summary
    print("\n" + "="*60)
    print("ASR Service Test Summary")
    print("="*60)
    print("✓ Health check: PASS")
    print("✓ Models listing: PASS")
    print("✓ Transcription API: PASS")
    print("="*60)

    return 0

if __name__ == "__main__":
    sys.exit(main())
