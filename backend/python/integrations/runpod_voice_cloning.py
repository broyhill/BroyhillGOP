"""
Quick Test: RunPod Chatterbox Voice Cloning
============================================
Run this locally to verify your endpoint works.

Usage:
    python test_runpod_local.py
"""

import requests
import time
import base64
import os

# Your RunPod credentials - USE ENVIRONMENT VARIABLES
ENDPOINT_ID = os.getenv("RUNPOD_ENDPOINT_ID", "YOUR_ENDPOINT_ID")
API_KEY = os.getenv("RUNPOD_API_KEY", "YOUR_API_KEY")

def test_endpoint():
    print("=" * 60)
    print("🎤 RUNPOD CHATTERBOX TEST")
    print("=" * 60)
    
    if API_KEY == "YOUR_API_KEY":
        print("\n⚠️  Set RUNPOD_API_KEY environment variable first!")
        print("   export RUNPOD_API_KEY='your_key_here'")
        return
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    
    # Step 1: Check health
    print("\n1️⃣ Checking endpoint health...")
    health_url = f"https://api.runpod.ai/v2/{ENDPOINT_ID}/health"
    
    try:
        response = requests.get(health_url, headers=headers)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"   Error: {e}")

if __name__ == "__main__":
    test_endpoint()
