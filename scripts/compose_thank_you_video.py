#!/usr/bin/env python3
"""
AI VIDEO COMPOSER - Thank You Video for Major Donors
Uses: Chatterbox (voice) + OmniAvatar (video)
Triggered by E20 Brain on donations >= $500
"""
import requests
import base64
import json
import time
import os
from pathlib import Path

# RunPod endpoints
RUNPOD_API_KEY = os.environ.get("RUNPOD_API_KEY", "")
VOICE_ENDPOINT = 'ebctno9p73twoa'  # Chatterbox
VIDEO_ENDPOINT = 'ju6mx6fnseu7hi'  # OmniAvatar 14B

# Jeff Zenger assets
REFERENCE_IMAGE = '/opt/e49/jeff_zenger/jeff_reference.jpg'
OUTPUT_DIR = '/opt/e49/jeff_zenger/output'

def generate_voice(text, output_path):
    """Generate voice using Chatterbox"""
    print(f'Generating voice: {text[:50]}...')
    
    url = f'https://api.runpod.ai/v2/{VOICE_ENDPOINT}/runsync'
    headers = {
        'Authorization': f'Bearer {RUNPOD_API_KEY}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'input': {
            'text': text,
            'exaggeration': 0.3,
            'cfg_weight': 0.5
        }
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=120)
    result = response.json()
    
    if result.get('status') == 'COMPLETED':
        audio_b64 = result['output']['audio_base64']
        with open(output_path, 'wb') as f:
            f.write(base64.b64decode(audio_b64))
        print(f'Voice saved: {output_path}')
        return output_path
    else:
        print(f'Voice error: {result}')
        return None

def generate_video(image_path, audio_path, output_path):
    """Generate video using OmniAvatar"""
    print(f'Generating video with OmniAvatar...')
    
    # Read image and audio as base64
    with open(image_path, 'rb') as f:
        image_b64 = base64.b64encode(f.read()).decode()
    with open(audio_path, 'rb') as f:
        audio_b64 = base64.b64encode(f.read()).decode()
    
    url = f'https://api.runpod.ai/v2/{VIDEO_ENDPOINT}/runsync'
    headers = {
        'Authorization': f'Bearer {RUNPOD_API_KEY}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'input': {
            'image_base64': image_b64,
            'audio_base64': audio_b64,
            'prompt': 'A professional politician giving a sincere thank you message, warm smile, confident posture',
            'num_steps': 30,
            'guidance_scale': 3.0,
            'audio_scale': 5.0
        }
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=600)
    result = response.json()
    
    if result.get('status') == 'COMPLETED':
        video_b64 = result['output']['video_base64']
        with open(output_path, 'wb') as f:
            f.write(base64.b64decode(video_b64))
        print(f'Video saved: {output_path}')
        return output_path
    else:
        print(f'Video error: {result}')
        return None

def compose_thank_you(donor_name, amount, issue='conservative values'):
    """Full pipeline: script -> voice -> video"""
    
    # Personalized script
    script = f'''Hi {donor_name},

I just received your generous gift of {amount} dollars, and I had to personally thank you.

Because of supporters like you, we can keep fighting for {issue} and deliver real results for our community.

Your investment is already making a difference. Thank you for believing in our campaign.

Together, we're going to win this. God bless you and your family.'''
    
    print('='*60)
    print('AI VIDEO COMPOSER - THANK YOU VIDEO')
    print('='*60)
    print(f'Donor: {donor_name}')
    print(f'Amount: ')
    print(f'Issue: {issue}')
    print('='*60)
    
    timestamp = time.strftime('%Y%m%d_%H%M%S')
    audio_path = f'{OUTPUT_DIR}/thankyou_{timestamp}.wav'
    video_path = f'{OUTPUT_DIR}/thankyou_{timestamp}.mp4'
    
    # Step 1: Generate voice
    voice_result = generate_voice(script, audio_path)
    if not voice_result:
        print('FAILED: Voice generation')
        return None
    
    # Step 2: Generate video
    video_result = generate_video(REFERENCE_IMAGE, audio_path, video_path)
    if not video_result:
        print('FAILED: Video generation')
        return None
    
    print('='*60)
    print('SUCCESS! Video ready:')
    print(video_path)
    print('='*60)
    
    return video_path

if __name__ == '__main__':
    # Example: Generate thank you for major donor
    compose_thank_you(
        donor_name='John',
        amount=1000,
        issue='border security and fiscal responsibility'
    )

