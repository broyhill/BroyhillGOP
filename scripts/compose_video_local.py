#!/usr/bin/env python3
"""
AI VIDEO COMPOSER - Using LOCAL Chatterbox + RunPod OmniAvatar
"""
import subprocess
import base64
import requests
import time
import os
import sys
sys.path.insert(0, '/opt/e49/venv/lib/python3.12/site-packages')

# RunPod for video only
RUNPOD_API_KEY = os.environ.get("RUNPOD_API_KEY", "")
VIDEO_ENDPOINT = 'ju6mx6fnseu7hi'  # OmniAvatar

# Jeff Zenger assets
REFERENCE_IMAGE = '/opt/e49/jeff_zenger/jeff_reference.jpg'
VOICE_SAMPLE = '/opt/e49/jeff_zenger/jeff_voice_cloned.wav'
OUTPUT_DIR = '/opt/e49/jeff_zenger/output'

def generate_voice_local(text, output_path):
    """Generate voice using LOCAL Chatterbox"""
    print(f'Generating voice locally: {text[:50]}...')
    
    # Write text to temp file
    with open('/tmp/tts_text.txt', 'w') as f:
        f.write(text)
    
    # Call Chatterbox via Python
    script = f'''
import sys
sys.path.insert(0, '/opt/e49/venv/lib/python3.12/site-packages')
from chatterbox.tts import ChatterboxTTS
import torchaudio

model = ChatterboxTTS.from_pretrained(device="cuda")
text = open('/tmp/tts_text.txt').read()
wav = model.generate(text, exaggeration=0.3, cfg_weight=0.5)
torchaudio.save('{output_path}', wav, model.sr)
print('Voice saved!')
'''
    
    result = subprocess.run(
        ['/opt/e49/venv/bin/python3', '-c', script],
        capture_output=True, text=True, timeout=120
    )
    
    if os.path.exists(output_path):
        print(f'Voice saved: {output_path}')
        return output_path
    else:
        print(f'Voice error: {result.stderr}')
        return None

def generate_video(image_path, audio_path, output_path):
    """Generate video using OmniAvatar on RunPod"""
    print(f'Generating video with OmniAvatar...')
    
    with open(image_path, 'rb') as f:
        image_b64 = base64.b64encode(f.read()).decode()
    with open(audio_path, 'rb') as f:
        audio_b64 = base64.b64encode(f.read()).decode()
    
    url = f'https://api.runpod.ai/v2/{VIDEO_ENDPOINT}/run'
    headers = {
        'Authorization': f'Bearer {RUNPOD_API_KEY}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'input': {
            'image_base64': image_b64,
            'audio_base64': audio_b64,
            'prompt': 'professional politician giving sincere thank you, warm smile',
            'num_steps': 25,
            'guidance_scale': 3.0,
            'audio_scale': 5.0
        }
    }
    
    print('Submitting to RunPod...')
    response = requests.post(url, headers=headers, json=payload, timeout=60)
    result = response.json()
    job_id = result.get('id')
    print(f'Job ID: {job_id}')
    
    # Poll for completion
    status_url = f'https://api.runpod.ai/v2/{VIDEO_ENDPOINT}/status/{job_id}'
    for i in range(60):  # 5 min timeout
        time.sleep(5)
        status = requests.get(status_url, headers=headers).json()
        print(f'Status: {status.get("status")}')
        if status.get('status') == 'COMPLETED':
            video_b64 = status['output'].get('video_base64')
            if video_b64:
                with open(output_path, 'wb') as f:
                    f.write(base64.b64decode(video_b64))
                print(f'Video saved: {output_path}')
                return output_path
        elif status.get('status') in ['FAILED', 'CANCELLED']:
            print(f'Job failed: {status}')
            return None
    
    print('Timeout waiting for video')
    return None

def compose_thank_you(donor_name, amount, issue='conservative values'):
    script = f'''Hi {donor_name},

I just received your generous gift of {amount} dollars, and I had to personally thank you.

Because of supporters like you, we can keep fighting for {issue}.

Your investment is already making a difference. Thank you for believing in our campaign.

Together, we are going to win this. God bless you and your family.'''
    
    print('='*60)
    print('AI VIDEO COMPOSER - THANK YOU VIDEO')
    print(f'Donor: {donor_name} | Amount: ')
    print('='*60)
    
    timestamp = time.strftime('%Y%m%d_%H%M%S')
    audio_path = f'{OUTPUT_DIR}/thankyou_{timestamp}.wav'
    video_path = f'{OUTPUT_DIR}/thankyou_{timestamp}.mp4'
    
    # Step 1: Voice
    voice = generate_voice_local(script, audio_path)
    if not voice:
        return None
    
    # Step 2: Video
    video = generate_video(REFERENCE_IMAGE, audio_path, video_path)
    
    print('='*60)
    if video:
        print(f'SUCCESS: {video_path}')
    else:
        print('Video generation pending or failed')
    print('='*60)
    
    return video_path

if __name__ == '__main__':
    compose_thank_you('John', 1000, 'border security')

